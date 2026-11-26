-- 20261126_like_counter_permissions.sql
--
-- 目的：修好「点赞失败：new row violates row-level security policy」。
--
-- 两个独立原因：
--   1) 客户端写入的 interaction_type 是 blog_good / product_good，
--      而 interactions_insert_self 只放行 like / dislike / favorite（客户端已改为 like）。
--   2) 计数维护触发器不是 SECURITY DEFINER：
--      · interactions_counter_insert/delete 要写 interaction_counters，
--        而该表只开了 SELECT 策略，以用户身份写入必然 42501；
--      · update_comment_likes 要更新 comments.like_count，
--        而 comments 的 UPDATE 策略限定 user_id = auth.uid()，
--        点赞别人的评论同样必然 42501。
--
-- 另外清理评论点赞重复计数的两个冗余触发器：
--   trigger_comment_likes 已经处理 INSERT/DELETE 的 like_count 增减，
--   trigger_increment_comment_likes / trigger_decrement_comment_likes 会再加一次。
--   客户端那两处 rpc('increment_comment_likes' / 'decrement_comment_likes')
--   调用的是零参触发函数，本来就无法通过 RPC 执行。
--
-- 同时修一个静默错误：update_entity_comment_count 也是以调用者身份更新 entities，
-- 给别人的帖子评论时 UPDATE 被 RLS 的 USING 条件过滤掉（0 行受影响、不报错），
-- 于是别人帖子的 comment_count 永远不涨。
--
-- 幂等：全部使用 CREATE OR REPLACE / DROP TRIGGER IF EXISTS，可重复执行。

begin;

-- 1. 实体点赞计数
create or replace function public.interactions_counter_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if new.interaction_type in ('product_good', 'blog_good', 'like', 'comment_like') then
    insert into public.interaction_counters (target_type, target_id, like_count, dislike_count)
    values (new.target_type, new.entity_id, 1, 0)
    on conflict (target_type, target_id) do update
      set like_count = public.interaction_counters.like_count + 1,
          updated_at = now();
  elsif new.interaction_type in ('product_bad', 'blog_bad', 'dislike') then
    insert into public.interaction_counters (target_type, target_id, like_count, dislike_count)
    values (new.target_type, new.entity_id, 0, 1)
    on conflict (target_type, target_id) do update
      set dislike_count = public.interaction_counters.dislike_count + 1,
          updated_at = now();
  end if;
  return null;
end;
$function$;

create or replace function public.interactions_counter_delete()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if old.interaction_type in ('product_good', 'blog_good', 'like', 'comment_like') then
    update public.interaction_counters
       set like_count = greatest(0, like_count - 1),
           updated_at = now()
     where target_type = old.target_type
       and target_id = old.entity_id;
  elsif old.interaction_type in ('product_bad', 'blog_bad', 'dislike') then
    update public.interaction_counters
       set dislike_count = greatest(0, dislike_count - 1),
           updated_at = now()
     where target_type = old.target_type
       and target_id = old.entity_id;
  end if;
  return null;
end;
$function$;

-- 2. 评论点赞计数（只保留这一条触发器）
create or replace function public.update_comment_likes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if tg_op = 'INSERT' and new.interaction_type = 'comment_like' then
    update public.comments
       set like_count = like_count + 1
     where id = new.entity_id;
  elsif tg_op = 'DELETE' and old.interaction_type = 'comment_like' then
    update public.comments
       set like_count = greatest(0, like_count - 1)
     where id = old.entity_id;
  end if;
  return null;
end;
$function$;

-- 3. 帖子评论数（给别人的帖子评论时也能正确计数）
create or replace function public.update_entity_comment_count()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if tg_op = 'INSERT' and not new.is_deleted then
    if new.parent_id is null then
      update public.entities
         set comment_count = comment_count + 1,
             comment_updated_at = now()
       where id = new.entity_id;
    end if;
  elsif tg_op = 'DELETE' and not old.is_deleted then
    if old.parent_id is null then
      update public.entities
         set comment_count = greatest(0, comment_count - 1),
             comment_updated_at = now()
       where id = old.entity_id;
    end if;
  elsif tg_op = 'UPDATE' and old.is_deleted != new.is_deleted then
    if new.parent_id is null then
      if new.is_deleted then
        update public.entities
           set comment_count = greatest(0, comment_count - 1),
               comment_updated_at = now()
         where id = new.entity_id;
      else
        update public.entities
           set comment_count = comment_count + 1,
               comment_updated_at = now()
         where id = new.entity_id;
      end if;
    end if;
  end if;
  return null;
end;
$function$;

-- 4. 去掉重复计数的冗余触发器
drop trigger if exists trigger_increment_comment_likes on public.interactions;
drop trigger if exists trigger_decrement_comment_likes on public.interactions;

commit;
