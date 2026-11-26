-- 20261128_user_moderation.rollback.sql
--
-- 撤销 20261128_user_moderation.sql：
--   · 去掉互动与报名上的封号拦截触发器
--   · 删掉两个管理 RPC
--
-- 不会动已经写入的 account_status / moderation_status 数据。

begin;

drop trigger if exists block_restricted_interaction_insert on public.interactions;
drop trigger if exists block_restricted_participant_insert on public.activity_participants;

drop function if exists public.admin_suspend_user(uuid, text);
drop function if exists public.admin_restore_user(uuid, text);

commit;
