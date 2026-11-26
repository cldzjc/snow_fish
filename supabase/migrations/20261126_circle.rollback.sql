-- 20261126_circle.rollback.sql
--
-- 撤销 20261126_circle.sql。
-- 注意：会一并删除已存在的入圈信息与帖子归属，执行前先确认。

begin;

drop index if exists public.entities_circle_created_at_idx;

alter table public.entities
  drop column if exists circle_id;

alter table public.user_profiles
  drop column if exists circle_region,
  drop column if exists circle_resort,
  drop column if exists circle_joined_at;

commit;
