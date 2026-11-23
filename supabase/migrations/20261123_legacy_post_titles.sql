-- 修复历史帖子的占位标题。
--
-- 背景：早期发布页把标题设为可选，未填时写入 '动态'。
-- 现在标题必填，卡片会把标题展示在最前面，于是这些老帖子都显示成「动态」。
-- 本迁移把 title = '动态' 的帖子改成正文字符串的前 24 个字，
-- 并把原标题保存到 extra_data._legacy_title，便于回滚。
--
-- 只改动 entity_type = 'post' 且标题确实是占位值、正文非空的行，可重复执行。

update public.entities
set title = left(regexp_replace(btrim(content), '\s+', ' ', 'g'), 24),
    extra_data = coalesce(extra_data, '{}'::jsonb)
      || jsonb_build_object('_legacy_title', title),
    updated_at = now()
where entity_type = 'post'
  and title = '动态'
  and coalesce(btrim(content), '') <> '';

-- 回滚（需要时手动执行）：
-- update public.entities
-- set title = extra_data->>'_legacy_title',
--     extra_data = extra_data - '_legacy_title'
-- where extra_data ? '_legacy_title';
