2026年1月8日 - 简化版
## Supabase 数据库更新说明

### ✅ **posts 表已添加 author_name（由你执行）**

你已在 Supabase 控制台执行：
```sql
ALTER TABLE posts ADD COLUMN author_name TEXT;
```

当前设计：
- **posts 表**：新增 `author_name`，用于存储发布人当时的名称（便于显示与历史一致性）
- **products 表**：仅使用核心字段（标题、价格、图片、位置、描述），不需要额外 schema 修改

---

### 📋 Products 表 - 核心字段

简化后仅支持这些字段，已从代码中移除复杂参数：

| 字段 | 类型 | 说明 |
|------|------|------|
| `title` | TEXT | 商品标题 |
| `price` | NUMERIC | 价格 |
| `location` | TEXT | 所在地点 |
| `sellername` | TEXT | 卖家名称 |
| `selleravatar` | TEXT | 卖家头像 URL |
| `user_id` | UUID | 卖家用户 ID |
| `image` | TEXT | 商品图片 URL |
| `description` | TEXT | 商品描述（可选） |
| `created_at` | TIMESTAMP | 创建时间 |

**已删除的参数**（代码中不再支持）：
- ❌ category - 商品类别
- ❌ condition - 商品状态  
- ❌ brand - 品牌
- ❌ size - 尺码
- ❌ usageTime - 使用时长
- ❌ transactionMethods - 交易方式
- ❌ negotiable - 是否可议价
---

### 🔧 **代码变更说明**

#### ProductService (`lib/product_service.dart`)
**改动**：大幅简化 `createProduct()` 参数
- ❌ 移除：category, condition, brand, size, usageTime, transactionMethods, negotiable
- ✅ 保留：title, price, location, sellerName, sellerAvatar, image, description (可选)
- **效果**：商品发布无需复杂字段，避免 schema 错误

#### PostService (`lib/post_service.dart`)
**改动**：回到简洁设计
- ❌ 移除：`nickname` 参数、author_nickname 字段存储
- ✅ 保留：只通过 user_id 关联
- **效果**：帖子表保持简洁

#### PublishPostPage (`lib/pages/publish_post_page.dart`)
**改动**：简化发布逻辑
- ❌ 不再读取或传递昵称
- ✅ 只调用 `PostService.createPost(title, content, mediaUrls)`

#### PostsListWidget (`lib/pages/posts_list_widget.dart`)
**改动**：显示 user_id 标识
- ✅ 显示：user_id 首 8 位（如 "发布人: a1b2c3d4"）
- 📝 例：发布人的 UUID `a1b2c3d4-xxxx-xxxx-xxxx-xxxxxxxxxxxx` → 显示 `a1b2c3d4`

#### EditProfilePage (`lib/pages/edit_profile_page.dart`)
**状态**：保留（可选，用于管理用户昵称/年龄/性别/介绍）
- ✅ 用户可在个人资料页编辑昵称等信息
- 📝 这些数据存储在 `auth.userMetadata`，不影响发布流程

---

### ✅ **部署清单**

1. **无需数据库修改** - 直接部署代码
2. **代码已编译通过** - 全部文件无语法错误
3. **兼容性** - 与现有 products 和 posts 表结构匹配

**测试流程**：
- [ ] 商品发布：标题 → 价格 → 图片 → 发布成功（无错误）
- [ ] 帖子发布：标题 → 内容 → 可选图片 → 发布成功
- [ ] 帖子列表：显示 "发布人: xxxxxxxx"（UUID 截断，无错误）
- [ ] 个人资料：可编辑昵称、年龄、性别、介绍（可选功能）
