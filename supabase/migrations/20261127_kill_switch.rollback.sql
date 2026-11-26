-- 20261127_kill_switch.rollback.sql
--
-- 撤销 20261127_kill_switch.sql。
-- 会删掉整张 app_settings 表（关停状态与说明文字一并丢失）。
-- 如果只是要解除关停，不要用这个文件，去「内容治理中心 → 紧急操作」关掉即可。

begin;

drop table if exists public.app_settings;

commit;
