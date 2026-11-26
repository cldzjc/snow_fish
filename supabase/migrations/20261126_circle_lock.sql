-- 20261126_circle_lock.sql
--
-- 圈子 30 天换圈限制。
--
-- 规则（产品约定）：
--   · 首次入圈不受限制；
--   · 换圈（含把圈子清空）需要距离上次入圈满 30 天；
--   · 管理员可以直接改，用于删圈、并圈等突发处理；
--   · 锁定到期才允许换圈，不做「退圈」入口，避免用退圈绕过期限。
--
-- 必须放在数据库里拦：RLS 只校验「改的是不是自己的行」，
-- 拦不住「自己的行里改 circle_region」，客户端禁用按钮挡不住直接调 REST。
--
-- 幂等：ADD COLUMN IF NOT EXISTS / CREATE OR REPLACE / DROP TRIGGER IF EXISTS。

begin;

alter table public.user_profiles
  add column if not exists circle_locked_until timestamp with time zone;

-- 已经入过圈但没有锁定时间的历史数据，按入圈时间补一个。
update public.user_profiles
   set circle_locked_until = coalesce(circle_joined_at, now()) + interval '30 days'
 where circle_locked_until is null
   and coalesce(btrim(circle_region), '') <> '';

create or replace function public.enforce_circle_lock()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $function$
declare
  v_changed boolean;
begin
  v_changed := new.circle_region is distinct from old.circle_region
            or new.circle_resort is distinct from old.circle_resort;

  if not v_changed then
    -- 圈子没动，保持原来的入圈时间与锁定时间，不要被顺手覆盖。
    new.circle_joined_at := old.circle_joined_at;
    new.circle_locked_until := old.circle_locked_until;
    return new;
  end if;

  -- 管理员强改：删圈、并圈等。
  if public.is_admin() then
    new.circle_joined_at := now();
    new.circle_locked_until := now() + interval '30 days';
    return new;
  end if;

  -- 首次入圈不限。
  if coalesce(btrim(old.circle_region), '') = '' then
    new.circle_joined_at := now();
    new.circle_locked_until := now() + interval '30 days';
    return new;
  end if;

  if old.circle_locked_until is not null and now() < old.circle_locked_until then
    raise exception using
      errcode = '42501',
      message = format(
        '换圈要等到 %s 之后，现在是锁定期内',
        to_char(old.circle_locked_until at time zone 'Asia/Shanghai', 'YYYY-MM-DD')
      );
  end if;

  new.circle_joined_at := now();
  new.circle_locked_until := now() + interval '30 days';
  return new;
end;
$function$;

drop trigger if exists enforce_circle_lock on public.user_profiles;

create trigger enforce_circle_lock
  before update on public.user_profiles
  for each row
  execute function public.enforce_circle_lock();

commit;
