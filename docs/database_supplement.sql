-- ========== Snow Fish 数据库补充脚本 ==========
-- 基于当前 Schema，补充评论系统和性能优化所需的字段和功能

-- ===== 1. 补充 comments 表字段 =====
-- 添加冗余字段（优化查询性能）和软删除支持

ALTER TABLE public.comments
ADD COLUMN author_nickname TEXT,                              -- 冗余：评论者昵称
ADD COLUMN author_avatar TEXT,                                -- 冗余：评论者头像URL
ADD COLUMN like_count INT DEFAULT 0,                          -- 冗余：点赞计数
ADD COLUMN is_deleted BOOLEAN DEFAULT false,                  -- 软删除标记
ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE,               -- 软删除时间
ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(); -- 更新时间

-- ===== 2. 补充 entities 表字段 =====
-- 添加评论统计（避免每次都COUNT查询）

ALTER TABLE public.entities
ADD COLUMN comment_count INT DEFAULT 0,                       -- 评论计数（自动维护）
ADD COLUMN comment_updated_at TIMESTAMP WITH TIME ZONE;       -- 最后评论时间

-- ===== 3. 为性能优化创建索引 =====
-- comments 表索引
CREATE INDEX IF NOT EXISTS idx_comments_entity_id ON public.comments(entity_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON public.comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON public.comments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_is_deleted ON public.comments(is_deleted);

-- entities 表索引
CREATE INDEX IF NOT EXISTS idx_entities_comment_updated_at ON public.entities(comment_updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_entities_user_id ON public.entities(user_id);

-- interactions 表索引
CREATE INDEX IF NOT EXISTS idx_interactions_user_entity ON public.interactions(user_id, entity_id, interaction_type);

-- ===== 4. 创建触发器函数：维护 comment_updated_at =====
-- 每当有评论时，自动更新 comments.updated_at
CREATE OR REPLACE FUNCTION update_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS trigger_update_comments_updated_at ON public.comments;
CREATE TRIGGER trigger_update_comments_updated_at
BEFORE UPDATE ON public.comments
FOR EACH ROW
EXECUTE FUNCTION update_comments_updated_at();

-- ===== 5. 创建触发器函数：维护 entities.comment_count =====
-- 当评论被创建/删除/软删除时，自动更新 entities.comment_count
CREATE OR REPLACE FUNCTION update_entity_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NOT NEW.is_deleted THEN
    -- 新增评论（只计算顶级评论）
    IF NEW.parent_id IS NULL THEN
      UPDATE public.entities 
      SET comment_count = comment_count + 1,
          comment_updated_at = now()
      WHERE id = NEW.entity_id;
    END IF;
  ELSIF TG_OP = 'DELETE' AND NOT OLD.is_deleted THEN
    -- 物理删除评论
    IF OLD.parent_id IS NULL THEN
      UPDATE public.entities 
      SET comment_count = GREATEST(0, comment_count - 1),
          comment_updated_at = now()
      WHERE id = OLD.entity_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' AND OLD.is_deleted != NEW.is_deleted THEN
    -- 软删除或恢复评论
    IF NEW.parent_id IS NULL THEN
      IF NEW.is_deleted THEN
        -- 软删除：减少计数
        UPDATE public.entities 
        SET comment_count = GREATEST(0, comment_count - 1),
            comment_updated_at = now()
        WHERE id = NEW.entity_id;
      ELSE
        -- 恢复：增加计数
        UPDATE public.entities 
        SET comment_count = comment_count + 1,
            comment_updated_at = now()
        WHERE id = NEW.entity_id;
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS trigger_entity_comment_count ON public.comments;
CREATE TRIGGER trigger_entity_comment_count
AFTER INSERT OR DELETE OR UPDATE ON public.comments
FOR EACH ROW
EXECUTE FUNCTION update_entity_comment_count();

-- ===== 6. 创建触发器函数：维护 comment_like_count =====
-- 当评论被点赞/取消点赞时，自动更新 comments.like_count
CREATE OR REPLACE FUNCTION update_comment_likes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.interaction_type = 'comment_like' THEN
    UPDATE public.comments 
    SET like_count = like_count + 1 
    WHERE id = NEW.entity_id;
  ELSIF TG_OP = 'DELETE' AND OLD.interaction_type = 'comment_like' THEN
    UPDATE public.comments 
    SET like_count = GREATEST(0, like_count - 1) 
    WHERE id = OLD.entity_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS trigger_comment_likes ON public.interactions;
CREATE TRIGGER trigger_comment_likes
AFTER INSERT OR DELETE ON public.interactions
FOR EACH ROW
EXECUTE FUNCTION update_comment_likes();

-- ===== 7. 初始化现有评论的计数 =====
-- 执行一次，统计现有评论数
UPDATE public.entities 
SET comment_count = (
  SELECT COUNT(*) FROM public.comments 
  WHERE public.comments.entity_id = public.entities.id 
    AND public.comments.parent_id IS NULL
    AND NOT public.comments.is_deleted
)
WHERE entity_type IN ('post', 'product');

-- ===== 8. 启用 RLS 并设置策略 =====
-- 启用行级安全
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- 允许所有用户读取评论（未删除的）
DROP POLICY IF EXISTS "Enable read comments for all users" ON public.comments;
CREATE POLICY "Enable read comments for all users"
ON public.comments
FOR SELECT
USING (NOT is_deleted);

-- 允许登录用户创建评论
DROP POLICY IF EXISTS "Enable insert comments for authenticated users" ON public.comments;
CREATE POLICY "Enable insert comments for authenticated users"
ON public.comments
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 允许用户编辑自己的评论
DROP POLICY IF EXISTS "Enable update comments for users based on user_id" ON public.comments;
CREATE POLICY "Enable update comments for users based on user_id"
ON public.comments
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 允许用户删除自己的评论
DROP POLICY IF EXISTS "Enable delete comments for users based on user_id" ON public.comments;
CREATE POLICY "Enable delete comments for users based on user_id"
ON public.comments
FOR DELETE
USING (auth.uid() = user_id);

-- ===== 执行完成 ==========
-- 数据库已准备好支持完整的评论系统！
