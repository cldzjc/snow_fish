-- Snow Fish V3.1 核心迁移（第二轮审计修正版）
-- 用法：整段粘贴到 Supabase SQL Editor 执行。
-- 说明：普通 SQL，不含 begin/commit，由 SQL Editor 管理事务。
-- 幂等：可重复执行。

-- =========================================================
-- 1. 用户资料：常驻地区 / 常驻雪场
-- =========================================================
alter table public.user_profiles
  add column if not exists resident_region text,
  add column if not exists resident_resort text;

-- =========================================================
-- 2. entities 置顶字段
-- =========================================================
alter table public.entities
  add column if not exists pinned_at timestamptz,
  add column if not exists pinned_until timestamptz,
  add column if not exists pinned_by uuid references auth.users(id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'entities_pinned_window_check'
      and conrelid = 'public.entities'::regclass
  ) then
    alter table public.entities
      add constraint entities_pinned_window_check
      check (pinned_until is null or pinned_until > pinned_at);
  end if;
end;
$$;

-- =========================================================
-- 3. 活动参与关系
-- 写入只允许通过 SECURITY DEFINER RPC，避免绕过人数/截止校验
-- =========================================================
create table if not exists public.activity_participants (
  entity_id uuid not null references public.entities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'joined'
    check (status in ('joined', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (entity_id, user_id)
);

alter table public.activity_participants enable row level security;

-- 客户端只能读，不能直接插入或修改
revoke all on public.activity_participants from anon, authenticated;
grant select on public.activity_participants to authenticated;

drop policy if exists activity_participants_select_visible on public.activity_participants;
create policy activity_participants_select_visible
on public.activity_participants
for select to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.entities e
    where e.id = activity_participants.entity_id
      and e.moderation_status = 'visible'
  )
);

-- 清理可能存在的旧版本写策略
drop policy if exists activity_participants_insert_self on public.activity_participants;
drop policy if exists activity_participants_update_self on public.activity_participants;

-- =========================================================
-- 4. entities RLS：post + 活动
-- =========================================================
drop policy if exists entities_select_visible_posts on public.entities;
create policy entities_select_visible_posts
on public.entities
for select to anon, authenticated
using (
  (
    entity_type = 'post'
    or entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
  )
  and (
    moderation_status = 'visible'
    or user_id = auth.uid()
    or is_admin()
  )
);

drop policy if exists entities_insert_self on public.entities;
create policy entities_insert_self
on public.entities
for insert to authenticated
with check (
  user_id = auth.uid()
  and (
    entity_type = 'post'
    or entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
  )
);

drop policy if exists entities_update_owner on public.entities;
create policy entities_update_owner
on public.entities
for update to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and (
    entity_type = 'post'
    or entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
  )
);

-- 管理员也需要能更新活动（原策略只允许 post）
drop policy if exists entities_update_admin on public.entities;
create policy entities_update_admin
on public.entities
for update to authenticated
using (is_admin())
with check (
  is_admin()
  and (
    entity_type = 'post'
    or entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
  )
);

-- =========================================================
-- 5. media / comments / interactions：同样支持活动
-- =========================================================
drop policy if exists media_insert_self on public.media;
create policy media_insert_self
on public.media
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.entities e
    where e.id = media.entity_id
      and e.user_id = auth.uid()
      and (
        e.entity_type = 'post'
        or e.entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
      )
  )
);

drop policy if exists comments_insert_self on public.comments;
create policy comments_insert_self
on public.comments
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.entities e
    where e.id = comments.entity_id
      and (
        e.entity_type = 'post'
        or e.entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
      )
  )
  and (
    parent_id is null
    or exists (
      select 1 from public.comments parent
      where parent.id = comments.parent_id
        and parent.entity_id = comments.entity_id
        and coalesce(parent.is_deleted, false) = false
    )
  )
);

drop policy if exists interactions_insert_self on public.interactions;
create policy interactions_insert_self
on public.interactions
for insert to authenticated
with check (
  user_id = auth.uid()
  and (
    (
      target_type = 'entity'
      and interaction_type in ('like','dislike','favorite')
      and exists (
        select 1 from public.entities e
        where e.id = interactions.entity_id
          and (
            e.entity_type = 'post'
            or e.entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
          )
      )
    )
    or (
      target_type = 'comment'
      and interaction_type = 'comment_like'
      and exists (
        select 1 from public.comments c
        where c.id = interactions.entity_id
          and coalesce(c.is_deleted, false) = false
      )
    )
  )
);

-- =========================================================
-- 6. 索引
-- =========================================================
create index if not exists idx_entities_feed
  on public.entities(entity_type, moderation_status, created_at desc);
create index if not exists idx_entities_pinned
  on public.entities(pinned_at desc, pinned_until)
  where pinned_at is not null;
create index if not exists idx_entities_activity_region
  on public.entities((extra_data->>'region_id'), created_at desc)
  where entity_type in ('activity_ski','activity_photo','activity_food','activity_gear');
create index if not exists idx_entities_activity_type_status
  on public.entities((extra_data->>'activity_type'), (extra_data->>'activity_status'), created_at desc)
  where entity_type in ('activity_ski','activity_photo','activity_food','activity_gear');
create index if not exists idx_activity_participants_entity_status
  on public.activity_participants(entity_id, status);
create index if not exists idx_notifications_recipient_unread
  on public.notifications(recipient_id, created_at desc)
  where read_at is null;

-- =========================================================
-- 7. 管理员置顶
-- =========================================================
create or replace function public.set_entity_pinned(
  p_entity_id uuid,
  p_pinned boolean,
  p_until timestamptz default null
) returns public.entities
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_entity public.entities;
begin
  if not public.is_admin() then
    raise exception '仅管理员可以置顶内容';
  end if;
  if p_pinned and p_until is not null and p_until <= now() then
    raise exception '置顶有效期必须晚于当前时间';
  end if;
  update public.entities
  set pinned_at = case when p_pinned then coalesce(pinned_at, now()) else null end,
      pinned_until = case when p_pinned then p_until else null end,
      pinned_by = case when p_pinned then auth.uid() else null end
  where id = p_entity_id
    and (
      entity_type = 'post'
      or entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
    )
  returning * into v_entity;
  if not found then
    raise exception '内容不存在或不支持置顶';
  end if;
  return v_entity;
end;
$$;

revoke all on function public.set_entity_pinned(uuid, boolean, timestamptz) from public, anon;
grant execute on function public.set_entity_pinned(uuid, boolean, timestamptz) to authenticated;

-- =========================================================
-- 8. 活动报名（行锁 + 人数 + 截止 + 开始时间校验）
-- =========================================================
create or replace function public.join_activity(p_entity_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_entity public.entities;
  v_joined integer;
  v_limit integer;
  v_deadline timestamptz;
  v_start timestamptz;
begin
  if auth.uid() is null then
    raise exception '请先登录';
  end if;

  select * into v_entity
  from public.entities
  where id = p_entity_id
    and entity_type in ('activity_ski','activity_photo','activity_food','activity_gear')
    and moderation_status = 'visible'
  for update;

  if not found then
    raise exception '活动不存在或不可参与';
  end if;

  if coalesce(v_entity.extra_data->>'activity_status', 'recruiting') <> 'recruiting' then
    raise exception '活动当前不在招募状态';
  end if;

  begin
    v_start := nullif(v_entity.extra_data->>'start_at', '')::timestamptz;
    v_deadline := nullif(v_entity.extra_data->>'join_deadline', '')::timestamptz;
    v_limit := nullif(v_entity.extra_data->>'max_participants', '')::integer;
  exception
    when others then
      raise exception '活动时间或人数配置无效';
  end;

  if v_start is not null and v_start <= now() then
    raise exception '活动已开始，无法报名';
  end if;
  if v_deadline is not null and v_deadline <= now() then
    raise exception '活动报名已截止';
  end if;
  if v_limit is not null and v_limit < 1 then
    raise exception '活动人数限制无效';
  end if;

  -- 已报名直接返回成功，避免重复点击报“已满”
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

  insert into public.activity_participants(entity_id, user_id, status)
  values (p_entity_id, auth.uid(), 'joined')
  on conflict (entity_id, user_id)
  do update set status = 'joined', updated_at = now();

  return true;
end;
$$;

revoke all on function public.join_activity(uuid) from public, anon;
grant execute on function public.join_activity(uuid) to authenticated;

create or replace function public.cancel_activity_join(p_entity_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
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
$$;

revoke all on function public.cancel_activity_join(uuid) from public, anon;
grant execute on function public.cancel_activity_join(uuid) to authenticated;

-- =========================================================
-- 9. 通知未读数 / 全部已读
-- =========================================================
create or replace function public.get_notification_unread_count()
returns integer
language sql
security definer
set search_path = pg_catalog, public
stable
as $$
  select count(*)::integer
  from public.notifications
  where recipient_id = auth.uid() and read_at is null;
$$;

revoke all on function public.get_notification_unread_count() from public, anon;
grant execute on function public.get_notification_unread_count() to authenticated;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_count integer;
begin
  update public.notifications
  set read_at = coalesce(read_at, now())
  where recipient_id = auth.uid() and read_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.mark_all_notifications_read() from public, anon;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- =========================================================
-- 10. 点赞 / 评论 / 回复通知触发器
-- =========================================================
create or replace function public.create_entity_like_notification()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner uuid;
begin
  if new.interaction_type in ('like','blog_good','product_good')
     and new.target_type = 'entity' then
    select user_id into v_owner from public.entities where id = new.entity_id;
    if v_owner is not null and v_owner <> new.user_id then
      insert into public.notifications(
        recipient_id, actor_id, notification_type, title, body, entity_id
      ) values (
        v_owner, new.user_id, 'like', '收到一个赞',
        '有人点赞了你的动态。', new.entity_id
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trig_create_entity_like_notification on public.interactions;
create trigger trig_create_entity_like_notification
after insert on public.interactions
for each row execute function public.create_entity_like_notification();

create or replace function public.create_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner uuid;
  v_parent_owner uuid;
begin
  select user_id into v_owner from public.entities where id = new.entity_id;
  if new.parent_id is not null then
    select user_id into v_parent_owner from public.comments where id = new.parent_id;
    if v_parent_owner is not null and v_parent_owner <> new.user_id then
      insert into public.notifications(
        recipient_id, actor_id, notification_type, title, body, entity_id, comment_id
      ) values (
        v_parent_owner, new.user_id, 'reply', '收到一条回复',
        '有人回复了你的评论。', new.entity_id, new.id
      );
    end if;
  elsif v_owner is not null and v_owner <> new.user_id then
    insert into public.notifications(
      recipient_id, actor_id, notification_type, title, body, entity_id, comment_id
    ) values (
      v_owner, new.user_id, 'comment', '收到一条评论',
      '有人评论了你的动态。', new.entity_id, new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trig_create_comment_notification on public.comments;
create trigger trig_create_comment_notification
after insert on public.comments
for each row execute function public.create_comment_notification();

-- =========================================================
-- 11. 普通用户不能修改置顶控制字段
-- =========================================================
create or replace function public.protect_v31_entity_control_fields()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if not public.is_admin() then
    new.pinned_at := old.pinned_at;
    new.pinned_until := old.pinned_until;
    new.pinned_by := old.pinned_by;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_v31_entity_control_fields on public.entities;
create trigger protect_v31_entity_control_fields
before update on public.entities
for each row execute function public.protect_v31_entity_control_fields();
