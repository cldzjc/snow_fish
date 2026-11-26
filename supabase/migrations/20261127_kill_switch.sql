-- 20261127_kill_switch.sql
--
-- 全站关停开关。
--
-- 一行配置：管理员在「内容治理中心 → 紧急操作」里打开后，
-- 所有人（包括正在使用的人，客户端每 30 秒轮询一次）都会看到一张白屏 +
-- 一行说明文字，任何页面都进不去。管理员本人可以在白屏上直接解除。
--
-- 只给管理员 UPDATE 权限，普通用户只能读，不能改。
-- 幂等：可重复执行。

begin;

create table if not exists public.app_settings (
  id integer primary key default 1 check (id = 1),
  closed boolean not null default false,
  closed_message text not null default '一双无形的大手关闭了 skneo —— 大手子',
  updated_at timestamp with time zone not null default now(),
  updated_by uuid
);

insert into public.app_settings (id) values (1) on conflict (id) do nothing;

alter table public.app_settings enable row level security;

drop policy if exists app_settings_select_public on public.app_settings;
create policy app_settings_select_public on public.app_settings
  for select to anon, authenticated using (true);

drop policy if exists app_settings_update_admin on public.app_settings;
create policy app_settings_update_admin on public.app_settings
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

commit;
