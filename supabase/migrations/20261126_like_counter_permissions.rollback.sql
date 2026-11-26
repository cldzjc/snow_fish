-- 20261126_like_counter_permissions.rollback.sql
--
-- 只撤销 20261126_like_counter_permissions.sql 做的改动：
-- 把三个触发器函数还原成「以调用者身份运行」，并重新挂回两个冗余的评论点赞触发器。
--
-- 注意：回滚后点赞会重新开始报 42501，仅在需要回到迁移前状态时使用。

begin;

create or replace function public.interactions_counter_insert()
returns trigger
language plpgsql
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

create or replace function public.update_comment_likes()
returns trigger
language plpgsql
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

drop trigger if exists trigger_increment_comment_likes on public.interactions;
create trigger trigger_increment_comment_likes
  after insert on public.interactions
  for each row
  when (new.interaction_type = 'comment_like')
  execute function increment_comment_likes();

drop trigger if exists trigger_decrement_comment_likes on public.interactions;
create trigger trigger_decrement_comment_likes
  after delete on public.interactions
  for each row
  when (old.interaction_type = 'comment_like')
  execute function decrement_comment_likes();

create or replace function public.update_entity_comment_count()
returns trigger
language plpgsql
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

commit;
