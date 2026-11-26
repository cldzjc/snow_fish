-- 20261126_circle.sql
--
-- 圈子（板块）功能所需的最小改动：不新建表，只加字段与索引。
--
-- 1) entities.circle_id
--    帖子归属的圈子 id（`地区路径` 或 `地区路径/雪场`）。
--    NULL 表示发在 sk社区；非 NULL 表示发在圈里，不出现在 sk社区。
--
-- 2) user_profiles 的入圈信息
--    和 resident_region / resident_resort（常驻地点）完全独立，
--    改常驻地点不会影响已入的圈。
--
-- 全部使用 IF NOT EXISTS，可重复执行。

begin;

alter table public.entities
  add column if not exists circle_id text;

create index if not exists entities_circle_created_at_idx
  on public.entities (circle_id, created_at desc)
  where circle_id is not null;

alter table public.user_profiles
  add column if not exists circle_region text,
  add column if not exists circle_resort text,
  add column if not exists circle_joined_at timestamp with time zone;

commit;
