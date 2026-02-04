-- ==================== Supabase SQL 脚本 ====================
-- 执行以下SQL语句来创建评论系统所需的表和函数

-- ===== 1. 创建 comments 表 =====
-- 存储帖子和商品的评论，支持嵌套回复
CREATE TABLE IF NOT EXISTS comments (
  -- 基本字段
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id UUID NOT NULL,                    -- 关联的帖子/商品ID（引用 entities.id）
  user_id UUID NOT NULL,                      -- 评论者ID（引用 auth.users.id）
  content TEXT NOT NULL,                      -- 评论内容
  
  -- 嵌套回复
  parent_id UUID,                             -- 父评论ID（自引用，支持嵌套回复）
  
  -- 冗余字段（用于快速显示，避免关联查询）
  author_nickname TEXT,                       -- 评论者昵称（快速显示）
  author_avatar TEXT,                         -- 评论者头像URL（快速显示）
  
  -- 统计字段
  like_count INT DEFAULT 0,                   -- 点赞数（冗余存储，通过触发器维护）
  
  -- 时间戳
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- 约束
  CONSTRAINT fk_comments_entity_id 
    FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE,
  CONSTRAINT fk_comments_user_id 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT fk_comments_parent_id 
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE
);

-- 创建索引以提升查询性能
CREATE INDEX idx_comments_entity_id ON comments(entity_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_created_at ON comments(created_at DESC);

-- ===== 2. 修改 interactions 表（添加 comment_like 支持）=====
-- 既有的 interactions 表结构应该如下：
-- - id UUID (PK)
-- - user_id UUID (FK to auth.users)
-- - entity_id UUID (可以指向 posts, products, 或现在的 comments)
-- - interaction_type TEXT ('blog_good', 'blog_bad', 'product_good', 'product_bad', 'like', 'dislike', 'comment_like')
-- - score NUMERIC (5 或 1)
-- - created_at TIMESTAMP

-- 如果 interactions 表中没有 comment_like 类型的记录，可以安全地添加（无需修改表结构）

-- ===== 3. 创建触发器函数维护评论点赞计数 =====
-- increment_comment_likes 函数
CREATE OR REPLACE FUNCTION increment_comment_likes()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE comments SET like_count = like_count + 1 WHERE id = NEW.entity_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- decrement_comment_likes 函数
CREATE OR REPLACE FUNCTION decrement_comment_likes()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE comments SET like_count = GREATEST(0, like_count - 1) WHERE id = OLD.entity_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器（当评论被点赞时自动更新 like_count）
DROP TRIGGER IF EXISTS trigger_increment_comment_likes ON interactions;
CREATE TRIGGER trigger_increment_comment_likes
AFTER INSERT ON interactions
FOR EACH ROW
WHEN (NEW.interaction_type = 'comment_like')
EXECUTE FUNCTION increment_comment_likes();

DROP TRIGGER IF EXISTS trigger_decrement_comment_likes ON interactions;
CREATE TRIGGER trigger_decrement_comment_likes
AFTER DELETE ON interactions
FOR EACH ROW
WHEN (OLD.interaction_type = 'comment_like')
EXECUTE FUNCTION decrement_comment_likes();

-- ===== 4. 更新 entities 表（可选：添加评论计数冗余字段）=====
-- 如果需要在帖子列表显示评论数，可以添加此字段
-- ALTER TABLE entities ADD COLUMN comment_count INT DEFAULT 0;

-- ===== 5. 为 updated_at 字段创建自动更新触发器 =====
CREATE OR REPLACE FUNCTION update_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_comments_updated_at ON comments;
CREATE TRIGGER trigger_update_comments_updated_at
BEFORE UPDATE ON comments
FOR EACH ROW
EXECUTE FUNCTION update_comments_updated_at();

-- ===== 6. 设置 RLS 策略（行级安全） =====
-- 启用 RLS
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- 允许所有用户读取评论
DROP POLICY IF EXISTS "Enable read for all users" ON comments;
CREATE POLICY "Enable read for all users"
ON comments
FOR SELECT
USING (true);

-- 允许用户创建评论
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON comments;
CREATE POLICY "Enable insert for authenticated users"
ON comments
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 允许用户编辑自己的评论
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON comments;
CREATE POLICY "Enable update for users based on user_id"
ON comments
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 允许用户删除自己的评论
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON comments;
CREATE POLICY "Enable delete for users based on user_id"
ON comments
FOR DELETE
USING (auth.uid() = user_id);
