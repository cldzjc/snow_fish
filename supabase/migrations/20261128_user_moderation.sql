-- 20261128_user_moderation.sql
--
-- 让「封号」真正成立，并给管理面板提供两个 RPC。
--
-- 现状问题：
--   1) 封号只拦发帖和评论，挡不住点赞、收藏、活动报名；
--   2) 封号不会隐藏该用户已发布的内容；
--   3) 没有解封入口，只能进 SQL 手改。
--
-- 处置模型（与产品约定一致）：
--   · 「有错」= 删除被举报内容 + 封禁作者 + 隐藏该作者其余全部内容；
--   · 「没错」= 只关闭举报，不处置；
--   · 申诉通过 → admin_restore_user 解封，并把因封号隐藏的内容原样恢复。
--
-- 幂等：可重复执行。

begin;

-- 1. 封号后不能再点赞 / 收藏 / 报名活动
drop trigger if exists block_restricted_interaction_insert on public.interactions;
create trigger block_restricted_interaction_insert
  before insert on public.interactions
  for each row execute function public.prevent_restricted_user_content();

drop trigger if exists block_restricted_participant_insert on public.activity_participants;
create trigger block_restricted_participant_insert
  before insert on public.activity_participants
  for each row execute function public.prevent_restricted_user_content();

-- 2. 封号：置为 suspended，并把其可见内容全部隐藏
create or replace function public.admin_suspend_user(p_user_id uuid, p_reason text)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_entities integer := 0;
  v_comments integer := 0;
  v_note text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if not public.is_admin() then
    raise exception '仅管理员可以封禁用户';
  end if;
  if p_user_id is null then
    raise exception '缺少用户 id';
  end if;

  update public.user_profiles
     set account_status = 'suspended',
         account_status_reason = v_note,
         account_status_until = null
   where id = p_user_id;
  if not found then
    raise exception '用户不存在';
  end if;

  update public.entities
     set moderation_status = 'hidden',
         moderation_reason = 'account_suspended',
         moderated_by = auth.uid(),
         moderated_at = now()
   where user_id = p_user_id
     and moderation_status = 'visible';
  get diagnostics v_entities = row_count;

  update public.comments
     set moderation_status = 'hidden',
         moderation_reason = 'account_suspended',
         moderated_by = auth.uid(),
         moderated_at = now()
   where user_id = p_user_id
     and moderation_status = 'visible';
  get diagnostics v_comments = row_count;

  insert into public.moderation_actions (
    moderator_id, action_type, target_type, target_id, reason
  ) values (
    auth.uid(), 'suspend_user', 'user', p_user_id, v_note
  );

  insert into public.notifications (
    recipient_id, notification_type, title, body
  ) values (
    p_user_id, 'account_restricted', '账号已被限制',
    coalesce(v_note, '你的账号已被限制，暂时不能发布内容和互动。')
  );

  return v_entities + v_comments;
end;
$function$;

-- 3. 解封：恢复账号，并把因封号隐藏的内容放回来
create or replace function public.admin_restore_user(p_user_id uuid, p_note text)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_entities integer := 0;
  v_comments integer := 0;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if not public.is_admin() then
    raise exception '仅管理员可以解封用户';
  end if;
  if p_user_id is null then
    raise exception '缺少用户 id';
  end if;

  update public.user_profiles
     set account_status = 'active',
         account_status_reason = null,
         account_status_until = null
   where id = p_user_id;
  if not found then
    raise exception '用户不存在';
  end if;

  update public.entities
     set moderation_status = 'visible',
         moderation_reason = null,
         moderated_by = null,
         moderated_at = null
   where user_id = p_user_id
     and moderation_status = 'hidden'
     and moderation_reason = 'account_suspended';
  get diagnostics v_entities = row_count;

  update public.comments
     set moderation_status = 'visible',
         moderation_reason = null,
         moderated_by = null,
         moderated_at = null
   where user_id = p_user_id
     and moderation_status = 'hidden'
     and moderation_reason = 'account_suspended';
  get diagnostics v_comments = row_count;

  insert into public.moderation_actions (
    moderator_id, action_type, target_type, target_id, reason
  ) values (
    auth.uid(), 'restore_user', 'user', p_user_id, v_note
  );

  insert into public.notifications (
    recipient_id, notification_type, title, body
  ) values (
    p_user_id, 'account_restricted', '账号已恢复正常',
    coalesce(v_note, '你的账号限制已解除，内容也已恢复。')
  );

  return v_entities + v_comments;
end;
$function$;

commit;
