-- Snow Fish V3.1 回滚脚本（与 20261121_v31_core.sql 对应）
-- 执行前请确认：activity_participants 中的参与数据不再需要。
-- 本脚本只撤销 20261121_v31_core.sql 新增的对象，并把 RLS 还原为迁移前定义。

-- 1. 触发器与函数
drop trigger if exists protect_v31_entity_control_fields on public.entities;
drop function if exists public.protect_v31_entity_control_fields();

drop trigger if exists trig_create_comment_notification on public.comments;
drop function if exists public.create_comment_notification();

drop trigger if exists trig_create_entity_like_notification on public.interactions;
drop function if exists public.create_entity_like_notification();

drop function if exists public.mark_all_notifications_read();
drop function if exists public.get_notification_unread_count();
drop function if exists public.cancel_activity_join(uuid);
drop function if exists public.join_activity(uuid);
drop function if exists public.set_entity_pinned(uuid, boolean, timestamptz);

-- 2. 活动参与表
drop table if exists public.activity_participants;

-- 3. 索引
drop index if exists public.idx_notifications_recipient_unread;
drop index if exists public.idx_entities_activity_type_status;
drop index if exists public.idx_entities_activity_region;
drop index if exists public.idx_entities_pinned;
drop index if exists public.idx_entities_feed;

-- 4. 新增列（约束随列一起删除）
alter table public.entities
  drop column if exists pinned_at,
  drop column if exists pinned_until,
  drop column if exists pinned_by;

alter table public.user_profiles
  drop column if exists resident_region,
  drop column if exists resident_resort;

-- 5. 还原 entities 的原始 post-only 策略
drop policy if exists entities_select_visible_posts on public.entities;
create policy entities_select_visible_posts
on public.entities
for select to anon, authenticated
using (
  entity_type = 'post'
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
with check (user_id = auth.uid() and entity_type = 'post');

drop policy if exists entities_update_owner on public.entities;
create policy entities_update_owner
on public.entities
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and entity_type = 'post');

drop policy if exists entities_update_admin on public.entities;
create policy entities_update_admin
on public.entities
for update to authenticated
using (is_admin())
with check (entity_type = 'post');

-- 6. 还原 media / comments / interactions 的原始策略
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
      and e.entity_type = 'post'
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
      and e.entity_type = 'post'
  )
  and (
    parent_id is null
    or exists (
      select 1 from public.comments parent
      where parent.id = parent.parent_id
        and parent.entity_id = parent.entity_id
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
          and e.entity_type = 'post'
      )
    )
    or (
      target_type = 'comment'
      and interaction_type = 'comment_like'
      and exists (
        select 1 from public.comments c
        where c.id = c.entity_id
          and coalesce(c.is_deleted, false) = false
      )
    )
  )
);
