-- 回滚 20261129_activity_flow
-- 注意：会丢弃所有活动申请与私有手机号数据。

drop function if exists public.cancel_activity_join(uuid);
drop function if exists public.join_activity(uuid);
drop function if exists public.activity_cancel_request(uuid);
drop function if exists public.activity_contact(uuid);
drop function if exists public.activity_respond_request(uuid, boolean);
drop function if exists public.activity_request_join(uuid, text);
drop function if exists public.set_my_phone(text);
drop function if exists public.my_phone();

alter table public.notifications drop constraint if exists notifications_notification_type_check;
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
      'system'
    ])
  );
alter table public.notifications drop column if exists request_id;

drop table if exists public.activity_requests;
drop table if exists public.user_contacts;

-- 恢复报名接口的直连语义
create or replace function public.join_activity(p_entity_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_entity public.entities;
  v_joined integer;
  v_limit integer;
  v_start timestamptz;
begin
  if auth.uid() is null then
    raise exception '请先登录';
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

  if coalesce(v_entity.extra_data ->> 'activity_status', 'recruiting') <> 'recruiting' then
    raise exception '活动当前不在招募状态';
  end if;

  v_start := nullif(v_entity.extra_data ->> 'start_at', '')::timestamptz;
  v_limit := nullif(v_entity.extra_data ->> 'max_participants', '')::integer;

  if v_start is not null and v_start <= now() then
    raise exception '活动已开始，无法报名';
  end if;

  if exists (
    select 1 from public.activity_participants
    where entity_id = p_entity_id and user_id = auth.uid() and status = 'joined'
  ) then
    return true;
  end if;

  select count(*) into v_joined
  from public.activity_participants
  where entity_id = p_entity_id and status = 'joined';

  if v_limit is not null and v_joined >= v_limit then
    raise exception '活动人数已满';
  end if;

  insert into public.activity_participants (entity_id, user_id, status)
  values (p_entity_id, auth.uid(), 'joined')
  on conflict (entity_id, user_id) do update
    set status = 'joined', updated_at = now();

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
  if auth.uid() is null then
    raise exception '请先登录';
  end if;
  update public.activity_participants
  set status = 'cancelled', updated_at = now()
  where entity_id = p_entity_id
    and user_id = auth.uid()
    and status = 'joined';
  if not found then
    return false;
  end if;
  return true;
end;
$function$;
