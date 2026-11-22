-- Skneo Club governance follow-up.
-- Run in Supabase SQL Editor after the previously executed content-governance SQL.
-- This migration is intentionally idempotent and does not delete OSS objects.

alter table public.media add column if not exists object_key text;
create index if not exists media_object_key_idx
  on public.media (object_key) where object_key is not null;

create table if not exists public.media_deletion_tasks (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null,
  user_id uuid not null,
  object_key text not null,
  status text not null default 'pending'
    check (status in ('pending', 'failed', 'completed')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create unique index if not exists media_deletion_tasks_media_idx
  on public.media_deletion_tasks (media_id);
create index if not exists media_deletion_tasks_retry_idx
  on public.media_deletion_tasks (status, updated_at);

alter table public.media_deletion_tasks enable row level security;
revoke all on public.media_deletion_tasks from anon, authenticated;

-- Only remove the legacy duplicate-report constraint when its definition
-- exactly matches the old reporter/target uniqueness rule. Keep all other
-- UNIQUE constraints intact.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.reports'::regclass
      and contype = 'u'
      and lower(pg_get_constraintdef(oid)) =
          'unique (reporter_id, target_type, target_id)'
  loop
    execute format('alter table public.reports drop constraint if exists %I', c.conname);
  end loop;
end $$;

create index if not exists reports_reporter_recent_idx
  on public.reports (reporter_id, created_at desc);

create or replace function public.submit_report(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_details text default null
) returns public.reports
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_report public.reports;
  v_owner uuid;
begin
  if auth.uid() is null then
    raise exception '请先登录';
  end if;
  if p_target_type is null
     or p_target_type not in ('entity', 'comment', 'user') then
    raise exception '举报目标无效';
  end if;
  if p_target_id is null then
    raise exception '举报目标无效';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception '请选择举报原因';
  end if;
  if length(trim(coalesce(p_reason, ''))) > 120 then
    raise exception '举报原因不能超过 120 个字符';
  end if;
  if length(coalesce(p_details, '')) > 2000 then
    raise exception '补充说明不能超过 2000 个字符';
  end if;
  if p_target_type = 'entity' then
    select user_id into v_owner from public.entities where id = p_target_id;
  elsif p_target_type = 'comment' then
    select user_id into v_owner from public.comments where id = p_target_id;
  else
    v_owner := p_target_id;
    if not exists (select 1 from auth.users where id = p_target_id) then
      raise exception '被举报用户不存在';
    end if;
  end if;
  if v_owner is null then
    raise exception '举报目标不存在';
  end if;
  if v_owner = auth.uid() then
    raise exception '不能举报自己的内容';
  end if;
  if (
    select count(*)
    from public.reports
    where reporter_id = auth.uid()
      and created_at > now() - interval '10 minutes'
  ) >= 5 then
    raise exception '举报操作过于频繁，请稍后再试';
  end if;

  insert into public.reports (
    reporter_id, target_type, target_id, reason, details
  ) values (
    auth.uid(), p_target_type, p_target_id, trim(p_reason), nullif(trim(p_details), '')
  ) returning * into v_report;

  insert into public.notifications (
    recipient_id, notification_type, title, body, entity_id
  )
  select id, 'system',
         '有新的举报待处理',
         '社区中有新的内容举报，请及时处理。',
         case when p_target_type = 'entity' then p_target_id else null end
  from public.user_profiles
  where role = 'admin'
  on conflict do nothing;
  return v_report;
end;
$$;

create or replace function public.moderate_report(
  p_report_id uuid,
  p_decision text,
  p_note text
) returns public.reports
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_report public.reports;
  v_owner uuid;
  v_status text;
  v_action text;
begin
  if not public.is_admin() then
    raise exception '仅管理员可以处理举报';
  end if;
  if p_decision is null
     or p_decision not in ('dismiss', 'remove') then
    raise exception '处理决定无效';
  end if;
  if length(coalesce(p_note, '')) > 2000 then
    raise exception '处理说明不能超过 2000 个字符';
  end if;
  select * into v_report from public.reports
    where id = p_report_id for update;
  if not found then
    raise exception '举报不存在';
  end if;

  v_status := case when p_decision = 'remove' then 'resolved' else 'dismissed' end;
  v_action := case when p_decision = 'remove' then 'remove_content' else 'dismiss_report' end;

  if v_report.target_type = 'entity' then
    select user_id into v_owner from public.entities where id = v_report.target_id;
    if v_owner is null then
      raise exception '举报目标已不存在';
    end if;
    if p_decision = 'remove' then
      delete from public.interactions
      where (target_type = 'entity' and entity_id = v_report.target_id)
         or (
           target_type = 'comment'
           and entity_id in (
             select id from public.comments
             where entity_id = v_report.target_id
           )
         );
      delete from public.entities where id = v_report.target_id;
      if not found then
        raise exception '举报目标已不存在';
      end if;
    end if;
  elsif v_report.target_type = 'comment' then
    select user_id into v_owner from public.comments where id = v_report.target_id;
    if v_owner is null then
      raise exception '举报目标已不存在';
    end if;
    if p_decision = 'remove' then
      delete from public.interactions
      where target_type = 'comment' and entity_id = v_report.target_id;
      delete from public.comments where id = v_report.target_id;
      if not found then
        raise exception '举报目标已不存在';
      end if;
    end if;
  else
    v_owner := v_report.target_id;
    if not exists (
      select 1 from public.user_profiles where id = v_report.target_id
    ) then
      raise exception '被举报用户不存在';
    end if;
    if p_decision = 'remove' then
      update public.user_profiles
      set account_status = 'suspended',
          account_status_reason = nullif(trim(p_note), ''),
          account_status_until = null
      where id = v_report.target_id;
    end if;
  end if;

  update public.reports
  set status = v_status, resolved_by = auth.uid(),
      resolution_note = nullif(trim(p_note), ''), resolved_at = now()
  where id = p_report_id
  returning * into v_report;

  insert into public.moderation_actions (
    moderator_id, action_type, target_type, target_id, reason
  ) values (
    auth.uid(), v_action, v_report.target_type, v_report.target_id,
    nullif(trim(p_note), '')
  );

  if v_report.reporter_id is not null then
    insert into public.notifications (
      recipient_id, notification_type, title, body, entity_id
    ) values (
      v_report.reporter_id, 'report_resolved', '举报处理结果',
      case when p_decision = 'remove'
        then '感谢你的反馈，相关内容已按社区规则处理。'
        else '感谢你的反馈，本次举报经审核后无需进一步处理。'
      end,
      case
        when p_decision = 'dismiss' and v_report.target_type = 'entity'
          then v_report.target_id
        else null
      end
    );
  end if;
  if p_decision = 'remove' and v_owner is not null and v_owner <> v_report.reporter_id then
    insert into public.notifications (
      recipient_id, notification_type, title, body, entity_id
    ) values (
      v_owner, 'content_moderated', '你的内容已被删除',
      coalesce(nullif(trim(p_note), ''), '该内容违反社区规则。'),
      null
    );
  end if;
  return v_report;
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id and recipient_id = auth.uid();
  if not found then
    raise exception '通知不存在或无权操作';
  end if;
end;
$$;

create or replace function public.restore_moderated_content(
  p_target_type text,
  p_target_id uuid,
  p_note text
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner uuid;
begin
  if not public.is_admin() then
    raise exception '仅管理员可以恢复内容';
  end if;
  if p_target_type = 'entity' then
    update public.entities
    set moderation_status = 'visible',
        moderation_reason = nullif(trim(p_note), ''),
        moderated_by = auth.uid(),
        moderated_at = now()
    where id = p_target_id
    returning user_id into v_owner;
  elsif p_target_type = 'comment' then
    update public.comments
    set moderation_status = 'visible',
        moderation_reason = nullif(trim(p_note), ''),
        moderated_by = auth.uid(),
        moderated_at = now()
    where id = p_target_id
    returning user_id into v_owner;
  else
    raise exception '恢复目标无效';
  end if;
  if v_owner is null then raise exception '内容不存在'; end if;
  insert into public.moderation_actions (
    moderator_id, action_type, target_type, target_id, reason
  ) values (auth.uid(), 'restore_content', p_target_type, p_target_id,
            nullif(trim(p_note), ''));
  insert into public.notifications (
    recipient_id, notification_type, title, body, entity_id
  ) values (
    v_owner, 'content_moderated', '你的内容已恢复',
    coalesce(nullif(trim(p_note), ''), '管理员复核后已恢复该内容。'),
    case when p_target_type = 'entity' then p_target_id else null end
  );
end;
$$;

do $$
declare
  p record;
begin
  -- Only replace policies owned by this migration. Existing policies are
  -- intentionally preserved and must be reviewed in the SQL Editor before
  -- this migration is run, because RLS policies are combined with OR.
  drop policy if exists reports_select_own_or_admin on public.reports;
  drop policy if exists moderation_actions_select_admin on public.moderation_actions;
  drop policy if exists notifications_select_recipient on public.notifications;
  drop policy if exists notifications_update_read_at on public.notifications;
end $$;

create policy reports_select_own_or_admin on public.reports
  for select to authenticated
  using (reporter_id = auth.uid() or public.is_admin());

create policy moderation_actions_select_admin on public.moderation_actions
  for select to authenticated using (public.is_admin());

create policy notifications_select_recipient on public.notifications
  for select to authenticated using (recipient_id = auth.uid());

create policy notifications_update_read_at on public.notifications
  for update to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

revoke insert, update, delete on public.reports from anon, authenticated;
revoke insert, update, delete on public.moderation_actions from anon, authenticated;
revoke insert, delete on public.notifications from anon, authenticated;
revoke update on public.notifications from anon, authenticated;
revoke all on function public.submit_report(text, uuid, text, text) from public, anon;
revoke all on function public.moderate_report(uuid, text, text) from public, anon;
revoke all on function public.mark_notification_read(uuid) from public, anon;
revoke all on function public.restore_moderated_content(text, uuid, text) from public, anon;
grant execute on function public.submit_report(text, uuid, text, text) to authenticated;
grant execute on function public.moderate_report(uuid, text, text) to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.restore_moderated_content(text, uuid, text) to authenticated;

create or replace function public.prevent_direct_control_field_changes()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if not public.is_admin() then
    if tg_table_name = 'user_profiles' then
      new.role := old.role;
      new.account_status := old.account_status;
      new.account_status_reason := old.account_status_reason;
      new.account_status_until := old.account_status_until;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.prevent_notification_field_changes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.is_admin() then
    if new.recipient_id is distinct from old.recipient_id
       or new.title is distinct from old.title
       or new.body is distinct from old.body
       or new.entity_id is distinct from old.entity_id
       or new.created_at is distinct from old.created_at then
      raise exception '只能修改通知已读状态';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_notification_fields on public.notifications;
create trigger protect_notification_fields
before update on public.notifications
for each row execute function public.prevent_notification_field_changes();

drop trigger if exists protect_user_profile_control_fields on public.user_profiles;
create trigger protect_user_profile_control_fields
before update on public.user_profiles
for each row execute function public.prevent_direct_control_field_changes();

create or replace function public.prevent_restricted_user_content()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_status text;
  v_blocked boolean;
begin
  if new.user_id is distinct from auth.uid() and not public.is_admin() then
    raise exception '不能使用其他用户身份发布内容';
  end if;
  select account_status into v_status
  from public.user_profiles where id = auth.uid();
  select exists (
    select 1 from public.user_restrictions
    where user_id = auth.uid() and active = true
      and (ends_at is null or ends_at > now())
      and restriction_type in ('mute', 'suspend')
  ) into v_blocked;
  if v_status in ('muted', 'suspended') or v_blocked then
    raise exception '当前账号暂不能执行此操作';
  end if;
  return new;
end;
$$;

drop trigger if exists block_restricted_entity_insert on public.entities;
create trigger block_restricted_entity_insert
before insert on public.entities
for each row execute function public.prevent_restricted_user_content();

drop trigger if exists block_restricted_comment_insert on public.comments;
create trigger block_restricted_comment_insert
before insert on public.comments
for each row execute function public.prevent_restricted_user_content();
