-- 20261126_circle_lock.rollback.sql
--
-- 撤销 20261126_circle_lock.sql：删掉触发器与锁定字段。
-- 回滚后换圈不再受限制，仅在需要回到迁移前状态时使用。

begin;

drop trigger if exists enforce_circle_lock on public.user_profiles;
drop function if exists public.enforce_circle_lock();

alter table public.user_profiles
  drop column if exists circle_locked_until;

commit;
