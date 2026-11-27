-- 约约约：手机号私有存储 + 申请审批流
--
-- 背景：活动从「点一下就加入」改为「申请 -> 发起者同意/婉拒」。
-- 手机号是双方沟通的唯一渠道，但 user_profiles 与 entities.extra_data 都
-- 对所有访客可读（RLS qual = true），因此号码必须单独放在私有表里，
-- 只能通过 SECURITY DEFINER 函数在「确实存在申请关系」时取出。

-- ---------------------------------------------------------------------------
-- 1. 私有手机号表
-- ---------------------------------------------------------------------------
create table if not exists public.user_contacts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  phone text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_contacts enable row level security;

drop policy if exists user_contacts_select_self on public.user_contacts;
create policy user_contacts_select_self on public.user_contacts
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists user_contacts_insert_self on public.user_contacts;
create policy user_contacts_insert_self on public.user_contacts
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists user_contacts_update_self on public.user_contacts;
create policy user_contacts_update_self on public.user_contacts
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists user_contacts_delete_self on public.user_contacts;
create policy user_contacts_delete_self on public.user_contacts
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 2. 活动申请
-- ---------------------------------------------------------------------------
create table if not exists public.activity_requests (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references public.entities (id) on delete cascade,
  applicant_id uuid not null references auth.users (id) on delete cascade,
  organiser_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint activity_requests_status_check
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  constraint activity_requests_unique unique (entity_id, applicant_id)
);

create index if not exists activity_requests_entity_idx
  on public.activity_requests (entity_id, status);
create index if not exists activity_requests_organiser_idx
  on public.activity_requests (organiser_id, status);

alter table public.activity_requests enable row level security;

-- 只读：申请人和发起者能看自己相关的记录；写入一律走 RPC。
drop policy if exists activity_requests_select_participants on public.activity_requests;
create policy activity_requests_select_participants on public.activity_requests
  for select to authenticated
  using (
    applicant_id = (select auth.uid())
    or organiser_id = (select auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 3. notifications：关联申请 + 扩展类型
-- ---------------------------------------------------------------------------
alter table public.notifications
  add column if not exists request_id uuid;

alter table public.notifications
  drop constraint if exists notifications_notification_type_check;

alter table public.notifications
  add constraint notifications_notification_type_check
  check (
    notification_type = any (array[
      'content_moderated',
      'account_restricted',
      'report_resolved',
      'comment',
      'reply',
      'like',
      'system',
      'activity_request',
      'activity_accepted',
      'activity_declined',
      'activity_cancelled'
    ])
  );

-- ---------------------------------------------------------------------------
-- 4. 手机号读写
-- ---------------------------------------------------------------------------
create or replace function public.my_phone()
returns text
language sql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
  select phone from public.user_contacts where user_id = auth.uid();
$function$;

create or replace function public.set_my_phone(p_phone text)
returns text
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_phone text;
begin
  if auth.uid() is null then
    raise exception '请先登录';
  end if;
  v_phone := regexp_replace(coalesce(p_phone, ''), '\s', '', 'g');
  if v_phone !~ '^1[3-9][0-9]{9}$' then
    raise exception '请填写正确的 11 位手机号';
  end if;
  insert into public.user_contacts (user_id, phone)
  values (auth.uid(), v_phone)
  on conflict (user_id) do update
    set phone = excluded.phone,
        updated_at = now();
  return v_phone;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 5. 申请参与
-- ---------------------------------------------------------------------------
create or replace function public.activity_request_join(
  p_entity_id uuid,
  p_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_entity public.entities;
  v_joined integer;
  v_limit integer;
  v_start timestamptz;
  v_status text;
  v_id uuid;
  v_actor text;
  v_phone text;
  v_when text;
  v_type text;
begin
  if auth.uid() is null then
    raise exception '请先登录';
  end if;

  if p_phone is not null and btrim(p_phone) <> '' then
    perform public.set_my_phone(p_phone);
  end if;

  select phone into v_phone from public.user_contacts where user_id = auth.uid();
  if v_phone is null then
    raise exception '请先填写手机号，方便双方沟通';
  end if;

  select * into v_entity
  from public.entities
  where id = p_entity_id
    and entity_type in ('activity_ski', 'activity_photo', 'activity_food', 'activity_gear')
    and moderation_status = 'visible'
  for update;

  if not found then
    raise exception '活动不存在或不可参与';
  end if;
  if v_entity.user_id = auth.uid() then
    raise exception '这是你自己发起的活动';
  end if;

  v_status := coalesce(v_entity.extra_data ->> 'activity_status', 'recruiting');
  if v_status = 'full' then
    raise exception '活动人数已满';
  end if;
  if v_status <> 'recruiting' then
    raise exception '活动当前不在招募状态';
  end if;

  begin
    v_start := nullif(v_entity.extra_data ->> 'start_at', '')::timestamptz;
    v_limit := nullif(v_entity.extra_data ->> 'max_participants', '')::integer;
  exception
    when others then
      raise exception '活动时间或人数配置无效';
  end;

  if v_start is not null and v_start <= now() then
    raise exception '活动已开始，无法参与';
  end if;

  select count(*) into v_joined
  from public.activity_participants
  where entity_id = p_entity_id and status = 'joined';

  if v_limit is not null and v_joined >= v_limit then
    raise exception '活动人数已满';
  end if;

  insert into public.activity_requests (entity_id, applicant_id, organiser_id, status)
  values (p_entity_id, auth.uid(), v_entity.user_id, 'pending')
  on conflict (entity_id, applicant_id) do update
    set organiser_id = excluded.organiser_id,
        status = case
          when public.activity_requests.status = 'accepted' then 'accepted'
          else 'pending'
        end,
        updated_at = now()
  returning id into v_id;

  select coalesce(nullif(nickname, ''), '雪友') into v_actor
  from public.user_profiles where id = auth.uid();

  v_when := case
    when v_start is null then '某个时间'
    else to_char(v_start at time zone 'Asia/Shanghai', 'MM"月"DD"日" HH24:MI')
  end;
  v_type := case coalesce(v_entity.extra_data ->> 'activity_type', '')
    when 'ski' then '约滑'
    when 'photo' then '约拍'
    when 'food' then '约饭'
    when 'gear' then '约装备'
    else '约伴'
  end;

  insert into public.notifications (
    recipient_id, actor_id, notification_type, title, body, entity_id, request_id
  ) values (
    v_entity.user_id,
    auth.uid(),
    'activity_request',
    '有雪友想参加你的活动',
    coalesce(v_actor, '雪友') || ' 想参加你 ' || v_when || ' 的' || v_type || '活动',
    p_entity_id,
    v_id
  );

  return v_id;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6. 发起者处理申请
-- ---------------------------------------------------------------------------
create or replace function public.activity_respond_request(
  p_request_id uuid,
  p_accept boolean
)
returns boolean
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_req public.activity_requests;
  v_entity public.entities;
  v_joined integer;
  v_limit integer;
  v_start timestamptz;
  v_when text;
  v_type text;
begin
  if auth.uid() is null then
    raise exception '请先登录';
  end if;

  select * into v_req from public.activity_requests where id = p_request_id for update;
  if not found then
    raise exception '申请不存在';
  end if;
  if v_req.organiser_id <> auth.uid() then
    raise exception '只有发起者可以处理这条申请';
  end if;
  if v_req.status <> 'pending' then
    raise exception '这条申请已经处理过了';
  end if;

  select * into v_entity from public.entities where id = v_req.entity_id;
  if not found then
    raise exception '活动不存在';
  end if;

  begin
    v_start := nullif(v_entity.extra_data ->> 'start_at', '')::timestamptz;
    v_limit := nullif(v_entity.extra_data ->> 'max_participants', '')::integer;
  exception
    when others then
      v_start := null;
      v_limit := null;
  end;

  v_when := case
    when v_start is null then '某个时间'
    else to_char(v_start at time zone 'Asia/Shanghai', 'MM"月"DD"日" HH24:MI')
  end;
  v_type := case coalesce(v_entity.extra_data ->> 'activity_type', '')
    when 'ski' then '约滑'
    when 'photo' then '约拍'
    when 'food' then '约饭'
    when 'gear' then '约装备'
    else '约伴'
  end;

  if p_accept then
    select count(*) into v_joined
    from public.activity_participants
    where entity_id = v_req.entity_id and status = 'joined';

    if v_limit is not null and v_joined >= v_limit then
      raise exception '活动人数已满';
    end if;

    insert into public.activity_participants (entity_id, user_id, status)
    values (v_req.entity_id, v_req.applicant_id, 'joined')
    on conflict (entity_id, user_id) do update
      set status = 'joined', updated_at = now();

    update public.activity_requests
    set status = 'accepted', responded_at = now(), updated_at = now()
    where id = p_request_id;

    select count(*) into v_joined
    from public.activity_participants
    where entity_id = v_req.entity_id and status = 'joined';

    if v_limit is not null and v_joined >= v_limit then
      update public.entities
      set extra_data = coalesce(extra_data, '{}'::jsonb)
            || jsonb_build_object('activity_status', 'full'),
          updated_at = now()
      where id = v_req.entity_id;
    end if;

    insert into public.notifications (
      recipient_id, actor_id, notification_type, title, body, entity_id, request_id
    ) values (
      v_req.applicant_id,
      auth.uid(),
      'activity_accepted',
      '约好时间，马上就到',
      '你已参加 ' || v_when || ' 的' || v_type || '活动，可在活动详情里查看发布者的手机号。',
      v_req.entity_id,
      p_request_id
    );
  else
    update public.activity_requests
    set status = 'declined', responded_at = now(), updated_at = now()
    where id = p_request_id;

    insert into public.notifications (
      recipient_id, actor_id, notification_type, title, body, entity_id, request_id
    ) values (
      v_req.applicant_id,
      auth.uid(),
      'activity_declined',
      '这次没约上',
      '你的参与请求被婉拒了，可以再看看别的活动。',
      v_req.entity_id,
      p_request_id
    );
  end if;

  return true;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 7. 查看对方手机号（仅在存在申请关系时）
-- ---------------------------------------------------------------------------
create or replace function public.activity_contact(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_req public.activity_requests;
  v_phone text;
begin
  if auth.uid() is null then
    raise exception '请先登录';
  end if;

  select * into v_req from public.activity_requests where id = p_request_id;
  if not found then
    raise exception '申请不存在';
  end if;

  if v_req.organiser_id = auth.uid() then
    if v_req.status not in ('pending', 'accepted') then
      raise exception '这条申请已经结束了';
    end if;
    select phone into v_phone from public.user_contacts where user_id = v_req.applicant_id;
  elsif v_req.applicant_id = auth.uid() then
    if v_req.status <> 'accepted' then
      raise exception '对方同意后才能查看手机号';
    end if;
    select phone into v_phone from public.user_contacts where user_id = v_req.organiser_id;
  else
    raise exception '无权查看';
  end if;

  if v_phone is null then
    raise exception '对方还没有填写手机号';
  end if;
  return v_phone;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 8. 撤销申请 / 取消已同意的报名
-- ---------------------------------------------------------------------------
create or replace function public.activity_cancel_request(p_entity_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_req public.activity_requests;
  v_status text;
  v_joined integer;
  v_limit integer;
  v_organiser uuid;
begin
  if auth.uid() is null then
    raise exception '请先登录';
  end if;

  select * into v_req
  from public.activity_requests
  where entity_id = p_entity_id
    and applicant_id = auth.uid()
    and status in ('pending', 'accepted')
  for update;

  if not found then
    return false;
  end if;

  update public.activity_requests
  set status = 'cancelled', updated_at = now()
  where id = v_req.id;

  update public.activity_participants
  set status = 'cancelled', updated_at = now()
  where entity_id = p_entity_id and user_id = auth.uid() and status = 'joined';

  select coalesce(extra_data ->> 'activity_status', 'recruiting'),
         nullif(extra_data ->> 'max_participants', '')::integer
  into v_status, v_limit
  from public.entities where id = p_entity_id;

  if v_status = 'full' then
    select count(*) into v_joined
    from public.activity_participants
    where entity_id = p_entity_id and status = 'joined';
    if v_limit is null or v_joined < v_limit then
      update public.entities
      set extra_data = coalesce(extra_data, '{}'::jsonb)
            || jsonb_build_object('activity_status', 'recruiting'),
          updated_at = now()
      where id = p_entity_id;
    end if;
  end if;

  select user_id into v_organiser from public.entities where id = p_entity_id;
  if v_organiser is not null and v_req.status = 'accepted' then
    insert into public.notifications (
      recipient_id, actor_id, notification_type, title, body, entity_id, request_id
    ) values (
      v_organiser,
      auth.uid(),
      'activity_cancelled',
      '有位雪友退出了活动',
      '对方取消了参加，人数已释放。',
      p_entity_id,
      v_req.id
    );
  end if;

  return true;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 9. 旧接口改为走申请流，避免老客户端绕过审批直接加入
-- ---------------------------------------------------------------------------
create or replace function public.join_activity(p_entity_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
begin
  perform public.activity_request_join(p_entity_id, null);
  return true;
end;
$function$;

create or replace function public.cancel_activity_join(p_entity_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
begin
  return public.activity_cancel_request(p_entity_id);
end;
$function$;

-- ---------------------------------------------------------------------------
-- 10. 清理已取消的报名截止字段
-- ---------------------------------------------------------------------------
update public.entities
set extra_data = extra_data - 'join_deadline'
where entity_type in ('activity_ski', 'activity_photo', 'activity_food', 'activity_gear')
  and extra_data ? 'join_deadline';
