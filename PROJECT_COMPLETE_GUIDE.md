# Snow Fish 二手交易平台 - 完整项目指南

> **最后更新**: 2026年2月4日  
> **项目版本**: v1.0.0+1  
> **文档版本**: v1.0

---

## 📑 目录

1. [项目概述](#项目概述)
2. [技术架构](#技术架构)
3. [数据库设计](#数据库设计)
4. [项目结构](#项目结构)
5. [核心功能模块](#核心功能模块)
6. [数据模型](#数据模型)
7. [核心服务](#核心服务)
8. [页面路由](#页面路由)
9. [API 接口](#api-接口)
10. [Edge Functions](#edge-functions)
11. [开发指南](#开发指南)
12. [部署与配置](#部署与配置)
13. [问题排查](#问题排查)

---

## 项目概述

### 基本信息
- **项目名称**: Snow Fish（雪鱼二手交易平台）
- **项目类型**: 跨平台二手交易社交应用
- **目标用户**: 滑雪爱好者社区
- **开发周期**: 2026年1月-2月
- **项目状态**: MVP 完成，功能迭代中

### 核心特性
- ✨ **通用实体架构**: 灵活支持商品、帖子、服务等多种内容类型
- 🌍 **Supabase 后端**: 使用东京节点，支持实时功能
- 📱 **跨平台支持**: iOS、Android、Web、macOS、Windows、Linux
- 🖼️ **媒体管理**: 图片/视频优化上传、缓存、OSS 存储
- 👤 **用户系统**: JWT 认证、资料管理、权限控制
- 💬 **社交功能**: 评论、点赞、分享等互动

### 项目目标
建立一个以"雪具交易"为主，以"社区讨论"为辅的二手交易平台，帮助滑雪爱好者快速买卖二手装备。

---

## 技术架构

### 前端技术栈

| 组件 | 技术 | 版本 |
|------|------|------|
| 框架 | Flutter | 3.10.0 |
| 语言 | Dart | >=3.10.0 |
| UI | Material Design | 3.0 |
| 状态管理 | StatefulWidget + FutureBuilder | - |
| 路由 | Named Routes | - |

### 后端技术栈

| 组件 | 技术 | 说明 |
|------|------|------|
| BaaS | Supabase | 完全托管的 PostgreSQL + Auth + Real-time |
| 数据库 | PostgreSQL | 15+ 版本 |
| 认证 | Supabase Auth | JWT + OAuth |
| 存储 | 阿里云 OSS | 对象存储 |
| 函数计算 | Edge Functions (Deno) | 服务端逻辑 |

### 核心依赖

```yaml
dependencies:
  # 数据库与认证
  supabase_flutter: ^2.5.2
  supabase: ^2.2.0
  
  # 数据模型
  equatable: ^2.0.5
  
  # UI 组件
  flutter_staggered_grid_view: ^0.7.0
  cached_network_image: ^3.3.0
  photo_view: ^0.14.0
  google_fonts: ^6.1.0
  
  # 文件与媒体
  file_picker: ^10.3.8
  video_player: ^2.5.1
  video_thumbnail: ^0.5.0
  image: ^4.0.17
  mime: ^1.0.2
  
  # HTTP 与上传
  dio: ^5.4.0
  http: ^1.6.0
```

---

## 数据库设计

### 核心表结构

#### 1. **entities** - 通用实体表
统一管理所有业务实体（商品、帖子、服务等）

```sql
CREATE TABLE entities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  entity_type VARCHAR(50) NOT NULL,           -- 'product' | 'post' | 'service'
  title VARCHAR(255) NOT NULL,
  content TEXT,
  extra_data JSONB DEFAULT '{}',              -- 扩展字段：价格、地点等
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  
  -- 索引优化
  INDEX idx_user_id (user_id),
  INDEX idx_entity_type (entity_type),
  INDEX idx_created_at (created_at DESC)
);
```

**字段说明**:
- `id`: 全局唯一标识
- `user_id`: 创建用户的 ID（外键）
- `entity_type`: 实体类型，用于区分业务类型
- `extra_data`: JSON 字段，存储扩展数据（价格、地点、SKU 等）
- `created_at`, `updated_at`: 时间戳

#### 2. **media** - 媒体表
存储与实体关联的图片、视频

```sql
CREATE TABLE media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  media_type VARCHAR(20) NOT NULL,            -- 'image' | 'video'
  display_order INT DEFAULT 0,                -- 显示顺序
  size_bytes BIGINT,                          -- 文件大小
  duration_ms INT,                            -- 视频时长
  created_at TIMESTAMP DEFAULT now(),
  
  INDEX idx_entity_id (entity_id),
  INDEX idx_media_type (media_type)
);
```

#### 3. **user_profiles** - 用户资料表
用户的公开信息和设置

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  nickname VARCHAR(100),
  bio TEXT,
  avatar_url TEXT,
  background_url TEXT,
  
  -- 向后兼容的字段名
  username VARCHAR(100),              -- 旧版本字段
  intro TEXT,                          -- 旧版本字段
  cover_url TEXT,                      -- 旧版本字段
  profile_video_url TEXT,
  
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);
```

#### 4. **posts** - 帖子表（待迁移）
旧架构的帖子表，逐步迁移到 entities

```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  title VARCHAR(255),
  content TEXT NOT NULL,
  media_urls TEXT[],                  -- JSON 数组
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);
```

#### 5. **comments** - 评论表
用户对实体的评论

```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  
  INDEX idx_entity_id (entity_id),
  INDEX idx_user_id (user_id)
);
```

#### 6. **interactions** - 互动表
用户与实体的互动（点赞、收藏、分享）

```sql
CREATE TABLE interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  action_type VARCHAR(20) NOT NULL,          -- 'like' | 'collect' | 'share'
  created_at TIMESTAMP DEFAULT now(),
  
  -- 防止重复点赞
  UNIQUE(entity_id, user_id, action_type),
  INDEX idx_user_id (user_id),
  INDEX idx_action_type (action_type)
);
```

### 数据库策略

| 方面 | 策略 | 说明 |
|------|------|------|
| 行级安全 | RLS 启用 | 用户只能访问自己的数据 |
| 外键约束 | ON DELETE CASCADE | 删除主记录时级联删除关联数据 |
| 时间戳 | 自动更新 | 使用触发器自动维护 updated_at |
| 搜索 | 全文索引 | 对 title、content 建立搜索索引 |

---

## 项目结构

### 完整目录树

```
snow_fish/
│
├── lib/
│   ├── main.dart                           # 应用入口
│   ├── config.dart                         # 配置（本地/远程模式开关）
│   ├── supabase_client.dart                # Supabase 初始化
│   ├── media_service.dart                  # 媒体上传服务
│   ├── post_service.dart                   # 帖子服务（旧版本）
│   ├── product_service.dart                # 商品服务（旧版本）
│   │
│   ├── models/                             # 数据模型
│   │   ├── base_entity.dart                # 通用实体模型
│   │   ├── media_model.dart                # 媒体模型
│   │   ├── user_profile.dart               # 用户资料模型
│   │   └── index.dart                      # 统一导出
│   │
│   ├── services/                           # 核心服务
│   │   └── entity_service.dart             # 统一实体服务（新架构）
│   │
│   └── pages/                              # UI 页面
│       ├── home_tabs.dart                  # 主导航（4个Tab）
│       ├── home_page.dart                  # 首页（双Tab：广场+交易）
│       │
│       ├── login_page.dart                 # 登录页
│       ├── register_page.dart              # 注册页
│       │
│       ├── profile_page.dart               # 个人资料页
│       ├── edit_profile_page.dart          # 编辑资料页
│       ├── my_products_page.dart           # 我的商品列表
│       ├── my_videos_page.dart             # 我的视频列表
│       │
│       ├── publish_page.dart               # 发布商品页
│       ├── publish_post_page.dart          # 发布帖子页
│       │
│       ├── product_detail_page.dart        # 商品详情页
│       ├── posts_list_widget.dart          # 帖子列表组件
│       │
│       ├── chat_page.dart                  # 消息页（占位）
│       ├── image_gallery_page.dart         # 图片库
│       ├── video_player_page.dart          # 视频播放器
│       │
│       └── login_page.dart                 # 登录提示页
│
├── functions/
│   └── get-oss-upload-url/                 # Edge Function
│       ├── index.ts                        # 阿里云 OSS 预签名 URL 生成
│       └── deno.json                       # Deno 配置
│
├── android/                                # Android 项目
├── ios/                                    # iOS 项目
├── web/                                    # Web 项目
├── macos/                                  # macOS 项目
├── windows/                                # Windows 项目
├── linux/                                  # Linux 项目
│
├── pubspec.yaml                            # Flutter 依赖配置
├── analysis_options.yaml                   # Dart 分析配置
├── PROJECT_COMPLETE_GUIDE.md               # 本文档（项目完整指南）
└── README.md                               # 项目简介
```

### 文件分类

#### 核心配置文件
- `lib/config.dart` - 全局配置（本地/远程模式）
- `lib/supabase_client.dart` - Supabase 初始化和 URL 配置
- `pubspec.yaml` - Flutter 依赖管理
- `analysis_options.yaml` - Dart 代码分析规则

#### 数据模型 (lib/models/)
- `base_entity.dart` - 通用实体类（80 行）
- `media_model.dart` - 媒体模型（40 行）
- `user_profile.dart` - 用户资料模型（35 行）
- `index.dart` - 模型统一导出

#### 核心服务 (lib/services/)
- `entity_service.dart` - 统一实体 CRUD 操作（400+ 行）

#### 媒体服务 (lib/目录下)
- `media_service.dart` - 图片/视频上传、压缩、获取

#### 业务逻辑 (lib/目录下)
- `post_service.dart` - 帖子服务（旧版本，逐步迁移）
- `product_service.dart` - 商品服务（旧版本，逐步迁移）

#### UI 页面 (lib/pages/)
- **导航**: `home_tabs.dart`（底部导航）、`home_page.dart`（首页 Tab）
- **认证**: `login_page.dart`、`register_page.dart`
- **个人**: `profile_page.dart`、`edit_profile_page.dart`
- **内容**: `publish_page.dart`、`publish_post_page.dart`
- **列表**: `my_products_page.dart`、`my_videos_page.dart`
- **详情**: `product_detail_page.dart`、`posts_list_widget.dart`
- **播放**: `video_player_page.dart`、`image_gallery_page.dart`
- **占位**: `chat_page.dart`（消息功能占位）

---

## 核心功能模块

### 1. 用户认证模块

**文件**: `lib/pages/login_page.dart`, `lib/pages/register_page.dart`

**功能**:
- ✅ 邮箱密码注册
- ✅ 邮箱密码登录
- ✅ JWT Token 自动管理
- ✅ 会话刷新
- ✅ 登出

**核心 API**:
```dart
// 注册
await Supabase.instance.client.auth.signUp(
  email: email,
  password: password,
);

// 登录
await Supabase.instance.client.auth.signInWithPassword(
  email: email,
  password: password,
);

// 获取当前用户
final user = Supabase.instance.client.auth.currentUser;
final session = Supabase.instance.client.auth.currentSession;

// 登出
await Supabase.instance.client.auth.signOut();
```

### 2. 首页双 Tab 模块

**文件**: `lib/pages/home_page.dart`

**结构**:
```
首页 (HomePage)
├── Tab 1: 广场（PostsListWidget）
│   ├── 帖子流（从 entities[entity_type='post'] 加载）
│   └── 发布帖子按钮
└── Tab 2: 雪具交易（ProductGrid）
    ├── 商品瀑布流（从 entities[entity_type='product'] 加载）
    └── 发布商品按钮
```

**特性**:
- 双 Tab 切换
- 实时数据加载（EntityService）
- 下拉刷新
- 无限滚动

### 3. 商品发布模块

**文件**: `lib/pages/publish_page.dart`

**流程**:
```
选择商品信息
├── 标题、描述、价格输入
├── 地点（目前固定为"未知地点"）
└── 媒体选择
    ├── 图片（最多9张，自动压缩）
    └── 视频（1个，OSS 上传）
        ↓
创建实体（EntityService.createEntity）
        ↓
上传媒体到 OSS
├── 获取预签名 URL (Edge Function)
├── PUT 文件到 OSS
└── 保存媒体记录到 media 表
        ↓
发布成功
```

**关键代码**:
```dart
// 1. 创建商品实体
final entity = await EntityService().createEntity(
  entityType: 'product',
  title: _titleController.text,
  content: _contentController.text,
  extraData: {
    'price': double.tryParse(_priceController.text) ?? 0.0,
    'location': '未知地点',
    'sellerName': sellerName,
  },
);

// 2. 上传媒体
final mediaService = MediaService();
for (final file in _pickedImages) {
  await mediaService.uploadMedia(
    userId: currentUser!.id,
    entityId: entity.id,
    fileType: FileType.image,
  );
}
```

### 4. 个人资料模块

**文件**: `lib/pages/profile_page.dart`, `lib/pages/edit_profile_page.dart`

**Profile 页**:
- 用户头像、昵称、简介展示
- 我的商品、我的视频导航
- 退出登录

**Edit 页**:
- 昵称、简介编辑
- 头像上传（OSS）
- 封面上传（OSS）
- 保存到 user_profiles 表

**上传流程**:
```
选择头像/封面
        ↓
调用 Edge Function（get-oss-upload-url）
        ↓
获取预签名 URL
        ↓
使用 Dio PUT 上传到 OSS
        ↓
保存 publicUrl 到 user_profiles.avatar_url
```

### 5. 商品详情模块

**文件**: `lib/pages/product_detail_page.dart`

**展示内容**:
- 图片轮播（Photo View 放大）
- 视频列表（点击播放）
- 商品信息（标题、价格、位置）
- 卖家信息（头像、名字）
- 商品描述

**数据获取**:
```dart
// 获取实体详情
final product = await EntityService().fetchEntity(productId);

// 获取关联的媒体
final media = await MediaService().getMediaByEntity(productId);
```

### 6. 媒体服务

**文件**: `lib/media_service.dart`

**核心方法**:
```dart
// 上传媒体
Future<void> uploadMedia({
  required String userId,
  required String entityId,
  required FileType fileType,  // image | video
});

// 获取实体的媒体
Future<List<MediaModel>> getMediaByEntity(String entityId);

// 删除媒体
Future<void> deleteMedia(String mediaId);
```

**特性**:
- 自动图片压缩（使用 compute isolate）
- 阿里云 OSS 上传
- 进度反馈
- 错误处理

---

## 数据模型

### BaseEntity - 通用实体模型

**文件**: `lib/models/base_entity.dart`

```dart
class BaseEntity extends Equatable {
  final String id;
  final String? userId;
  final String entityType;              // 'product' | 'post' | 'service'
  final String title;
  final String? content;
  final Map<String, dynamic> extraData; // 扩展字段
  final List<MediaModel> media;         // 关联的媒体
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  const BaseEntity({
    required this.id,
    this.userId,
    required this.entityType,
    required this.title,
    this.content,
    this.extraData = const {},
    this.media = const [],
    this.createdAt,
    this.updatedAt,
  });
  
  // 便捷访问扩展字段
  double? get price => extraData['price'];
  String? get location => extraData['location'];
  String? get sellerName => extraData['sellerName'];
  
  // JSON 序列化
  factory BaseEntity.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

**使用示例**:
```dart
// 创建商品实体
final product = BaseEntity(
  id: 'uuid-123',
  userId: 'user-uuid',
  entityType: 'product',
  title: '全新雪板',
  content: '9成新，包装完整',
  extraData: {
    'price': 1999.0,
    'location': '北京',
    'sellerName': '张三',
  },
  media: [
    MediaModel(id: '1', entityId: 'uuid-123', url: 'https://...', mediaType: 'image'),
  ],
);

// 访问字段
print('¥${product.price}');  // ¥1999.0
print(product.location);     // 北京
```

### MediaModel - 媒体模型

**文件**: `lib/models/media_model.dart`

```dart
class MediaModel extends Equatable {
  final String id;
  final String entityId;
  final String url;
  final String mediaType;  // 'image' | 'video'
  final int displayOrder;  // 显示顺序
  final int? sizeBytes;    // 文件大小
  final int? durationMs;   // 视频时长
  
  const MediaModel({
    required this.id,
    required this.entityId,
    required this.url,
    required this.mediaType,
    this.displayOrder = 0,
    this.sizeBytes,
    this.durationMs,
  });
  
  factory MediaModel.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

### UserProfile - 用户资料模型

**文件**: `lib/models/user_profile.dart`

```dart
class UserProfile extends Equatable {
  final String id;
  final String? nickname;
  final String? bio;
  final String? avatarUrl;
  final String? backgroundUrl;
  final String? profileVideoUrl;
  
  const UserProfile({
    required this.id,
    this.nickname,
    this.bio,
    this.avatarUrl,
    this.backgroundUrl,
    this.profileVideoUrl,
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

---

## 核心服务

### EntityService - 统一实体服务

**文件**: `lib/services/entity_service.dart`

**核心方法**:

#### 1. 获取实体列表
```dart
Future<List<BaseEntity>> fetchEntities({
  String? type,
  int limit = 20,
  int offset = 0,
})
```
- 支持类型过滤（product/post/service）
- 支持分页
- 返回完整实体及关联媒体

#### 2. 获取用户实体
```dart
Future<List<BaseEntity>> fetchUserEntities({
  required String userId,
  String? type,
})
```
- 获取某个用户发布的所有实体
- 按 created_at 倒序

#### 3. 获取单个实体
```dart
Future<BaseEntity?> fetchEntity(String entityId)
```
- 获取实体详情及完整媒体

#### 4. 创建实体
```dart
Future<BaseEntity> createEntity({
  required String entityType,
  required String title,
  String? content,
  Map<String, dynamic> extraData = const {},
})
```

#### 5. 更新实体
```dart
Future<BaseEntity> updateEntity({
  required String entityId,
  String? title,
  String? content,
  Map<String, dynamic>? extraData,
})
```

#### 6. 删除实体
```dart
Future<void> deleteEntity(String entityId)
```
- 级联删除关联媒体

**使用示例**:
```dart
// 获取所有商品
final products = await EntityService().fetchEntities(
  type: 'product',
  limit: 50,
);

// 获取用户的商品
final myProducts = await EntityService().fetchUserEntities(
  userId: userId,
  type: 'product',
);

// 创建商品
final entity = await EntityService().createEntity(
  entityType: 'product',
  title: '二手雪板',
  content: '9成新',
  extraData: {
    'price': 1999.0,
    'location': '北京',
  },
);

// 获取详情
final detail = await EntityService().fetchEntity(entity.id);
```

### MediaService - 媒体服务

**文件**: `lib/media_service.dart`

**核心方法**:

#### 1. 上传媒体
```dart
Future<void> uploadMedia({
  required String userId,
  required String entityId,
  required FileType fileType,
})
```
- 自动获取 OSS 预签名 URL
- 压缩图片（如果是图片）
- PUT 上传到 OSS
- 保存记录到 media 表

#### 2. 获取实体媒体
```dart
Future<List<MediaModel>> getMediaByEntity(String entityId)
```

#### 3. 删除媒体
```dart
Future<void> deleteMedia(String mediaId)
```

**特性**:
- 并发上传限制
- 断点续传支持（Dio）
- 自动重试
- 进度回调

---

## 页面路由

### 完整导航结构

```
├── /
│   └── HomeTabs（主导航）
│       ├── 首页 (HomePage)
│       │   ├── 广场 Tab
│       │   │   └── 帖子列表 (PostsListWidget)
│       │   │       └── 帖子详情
│       │   └── 交易 Tab
│       │       └── 商品瀑布流
│       │           └── 商品详情 (ProductDetailPage)
│       ├── 发布 (PublishPage / PublishPostPage)
│       ├── 消息 (ChatPage) [占位]
│       └── 我的 (ProfilePage)
│           ├── 个人资料展示
│           ├── 编辑资料 (EditProfilePage)
│           ├── 我的商品 (MyProductsPage)
│           │   └── 商品详情
│           ├── 我的视频 (MyVideosPage)
│           │   └── 视频播放 (VideoPlayerPage)
│           └── 退出登录
│
└── /auth
    ├── /login (LoginPage)
    └── /register (RegisterPage)
```

### 页面映射表

| 页面 | 文件 | 功能 |
|------|------|------|
| 主导航 | home_tabs.dart | 4 个 Tab 的底部导航 |
| 首页 | home_page.dart | 双 Tab：广场 + 交易 |
| 登录 | login_page.dart | 邮箱密码登录 |
| 注册 | register_page.dart | 邮箱密码注册 |
| 商品详情 | product_detail_page.dart | 图片、视频、信息展示 |
| 发布商品 | publish_page.dart | 图片、视频、信息输入 |
| 发布帖子 | publish_post_page.dart | 内容、媒体输入 |
| 个人资料 | profile_page.dart | 资料展示和导航 |
| 编辑资料 | edit_profile_page.dart | 上传头像、封面、编辑信息 |
| 我的商品 | my_products_page.dart | 用户商品列表 |
| 我的视频 | my_videos_page.dart | 用户视频列表和管理 |
| 视频播放 | video_player_page.dart | 全屏视频播放 |
| 图库 | image_gallery_page.dart | 图片预览和操作 |
| 帖子列表 | posts_list_widget.dart | 帖子流组件 |
| 消息 | chat_page.dart | 消息功能（占位） |

---

## API 接口

### REST API（通过 Supabase）

#### 实体操作

```bash
# 获取商品列表
GET /rest/v1/entities?entity_type=eq.product&limit=50

# 获取用户的商品
GET /rest/v1/entities?user_id=eq.{userId}&entity_type=eq.product

# 创建商品
POST /rest/v1/entities
{
  "entity_type": "product",
  "title": "商品标题",
  "content": "商品描述",
  "extra_data": {
    "price": 1999,
    "location": "北京"
  }
}

# 获取商品详情及媒体
GET /rest/v1/entities?id=eq.{entityId}&select=*,media(*)

# 更新商品
PATCH /rest/v1/entities?id=eq.{entityId}
{
  "title": "新标题",
  "extra_data": { "price": 2999 }
}

# 删除商品
DELETE /rest/v1/entities?id=eq.{entityId}
```

#### 媒体操作

```bash
# 获取实体的媒体
GET /rest/v1/media?entity_id=eq.{entityId}&order=display_order

# 上传媒体（需要先调用 Edge Function 获取 OSS URL）
PUT {ossUrl}  # 使用 OSS 预签名 URL

# 创建媒体记录
POST /rest/v1/media
{
  "entity_id": "{entityId}",
  "url": "{ossUrl}",
  "media_type": "image",
  "display_order": 0
}

# 删除媒体
DELETE /rest/v1/media?id=eq.{mediaId}
```

#### 用户资料操作

```bash
# 获取用户资料
GET /rest/v1/user_profiles?id=eq.{userId}

# 更新用户资料
PATCH /rest/v1/user_profiles?id=eq.{userId}
{
  "nickname": "新昵称",
  "bio": "个人简介",
  "avatar_url": "https://..."
}
```

### GraphQL 订阅（Realtime）

```graphql
# 订阅实体变化
subscription OnEntityChanged {
  entities_stream(cursor: { initial_value: { created_at: "" } }) {
    id
    title
    entity_type
    created_at
  }
}
```

---

## Edge Functions

### get-oss-upload-url

**路径**: `functions/get-oss-upload-url/index.ts`

**功能**: 生成阿里云 OSS 预签名上传 URL

#### 请求

```bash
POST /functions/v1/get-oss-upload-url
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "filename": "avatar.jpg",
  "contentType": "image/jpeg",
  "owner_type": "user_profiles",
  "owner_id": "{user-uuid}"
}
```

#### 响应

```json
{
  "uploadUrl": "https://bucket.oss-cn-beijing.aliyuncs.com/snowfish/user-id/user_profiles/1706847600000_avatar.jpg?OSSAccessKeyId=xxx&Expires=1706847720&Signature=...",
  "publicUrl": "https://bucket.oss-cn-beijing.aliyuncs.com/snowfish/user-id/user_profiles/1706847600000_avatar.jpg",
  "objectKey": "snowfish/user-id/user_profiles/1706847600000_avatar.jpg"
}
```

#### 环境变量

```
OSS_ACCESS_KEY_ID=your-access-key
OSS_ACCESS_KEY_SECRET=your-secret-key
OSS_BUCKET=your-bucket-name
OSS_REGION=oss-cn-beijing
```

#### 关键特性

- ✅ JWT 认证验证
- ✅ 权限校验（owner_id 与用户匹配）
- ✅ OSS 预签名 URL 生成（HMAC-SHA1）
- ✅ 120 秒有效期
- ✅ 支持 PUT 上传方法
- ✅ 详细的错误处理和日志

#### 实现细节

```typescript
// JWT token 提取与验证
function extractUserIdFromJWT(token: string): string | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const payload = JSON.parse(atob(parts[1]));
  return payload.sub || null;  // 'sub' 是用户 ID
}

// OSS 预签名 URL 生成
async function hmacSha1(key: string, data: string) {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, ...);
  return btoa(String.fromCharCode(...new Uint8Array(signature)));
}
```

---

## 开发指南

### 常见开发任务

#### 1. 添加新的实体类型

**步骤**:
1. 定义实体类型常量（例如 `entity_type='course'`）
2. 在 EntityService 中添加类型过滤
3. 创建对应的发布页面
4. 添加到首页 Tab（如需要）

**示例**: 添加"课程"实体
```dart
// 定义常量
const String ENTITY_TYPE_COURSE = 'course';

// 使用 EntityService
final courses = await EntityService().fetchEntities(
  type: 'course',
);

// 创建课程
await EntityService().createEntity(
  entityType: 'course',
  title: '滑雪基础教程',
  content: '...',
  extraData: {
    'instructor': '教练名字',
    'duration': 120,  // 分钟
  },
);
```

#### 2. 添加新的扩展字段

**步骤**:
1. 通过 `extraData` 字典添加字段
2. 在 BaseEntity 中添加 getter 便捷访问
3. 在相关页面中显示和编辑

**示例**: 为商品添加库存字段
```dart
// 创建时
await EntityService().createEntity(
  entityType: 'product',
  title: '雪板',
  extraData: {
    'price': 1999,
    'stock': 5,  // 新字段
  },
);

// BaseEntity 中添加 getter
int? get stock => extraData['stock'];

// 页面中使用
print('库存: ${product.stock}');
```

#### 3. 获取指定用户的数据

```dart
final userId = Supabase.instance.client.auth.currentUser!.id;

// 获取用户的所有商品
final products = await EntityService().fetchUserEntities(
  userId: userId,
  type: 'product',
);
```

#### 4. 实现点赞功能

```dart
// 点赞
await Supabase.instance.client
  .from('interactions')
  .insert({
    'entity_id': entityId,
    'user_id': userId,
    'action_type': 'like',
  });

// 取消点赞
await Supabase.instance.client
  .from('interactions')
  .delete()
  .eq('entity_id', entityId)
  .eq('user_id', userId)
  .eq('action_type', 'like');

// 获取点赞数
final likes = await Supabase.instance.client
  .from('interactions')
  .select()
  .eq('entity_id', entityId)
  .eq('action_type', 'like');
```

#### 5. 实现评论功能

```dart
// 发表评论
await Supabase.instance.client
  .from('comments')
  .insert({
    'entity_id': entityId,
    'user_id': userId,
    'content': '评论内容',
  });

// 获取评论列表
final comments = await Supabase.instance.client
  .from('comments')
  .select()
  .eq('entity_id', entityId)
  .order('created_at', ascending: false);
```

### 调试技巧

#### 1. 启用日志输出
```dart
// 在 main.dart 中
debugPrint('用户 ID: ${user.id}');
```

#### 2. 查看 Supabase 日志
- 进入 Supabase Dashboard
- 点击 **Functions** → **Logs**
- 查看 Edge Function 执行日志

#### 3. 测试 API
```bash
# 使用 curl 测试
curl -X GET 'https://PROJECT.supabase.co/rest/v1/entities?limit=10' \
  -H 'apikey: ANON_KEY' \
  -H 'Authorization: Bearer JWT_TOKEN'
```

#### 4. 本地模式测试
```dart
// lib/config.dart
const bool USE_LOCAL_DATA = true;  // 切换到本地数据
```

---

## 部署与配置

### 前置要求

- Flutter 3.10.0+
- Dart 3.10.0+
- Supabase 项目（东京节点）
- 阿里云 OSS Bucket
- Supabase CLI

### 环境变量配置

#### 1. Supabase Dashboard 配置

**进入**: Supabase Dashboard → Settings → Edge Functions

**添加环境变量**:
```
OSS_ACCESS_KEY_ID=your-aliyun-access-key
OSS_ACCESS_KEY_SECRET=your-aliyun-secret-key
OSS_BUCKET=your-bucket-name
OSS_REGION=oss-cn-beijing
```

#### 2. Flutter 配置

**编辑** `lib/supabase_client.dart`:
```dart
const String supabaseUrl = 'https://your-project.supabase.co';
const String supabaseAnonKey = 'your-anon-key';
```

### 部署步骤

#### 1. 部署 Edge Function

```bash
# 登录 Supabase
supabase login

# 链接项目
supabase link --project-ref your-project-ref

# 部署函数
supabase functions deploy get-oss-upload-url

# 查看日志
supabase functions logs get-oss-upload-url --tail
```

#### 2. 初始化数据库

执行 SQL 语句创建表（见数据库设计章节）

#### 3. 配置 RLS 策略

```sql
-- 用户只能看到自己的数据
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "用户只能看到自己的资料"
ON user_profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "用户只能更新自己的资料"
ON user_profiles FOR UPDATE
USING (auth.uid() = id);
```

#### 4. 构建 Android APK

```bash
flutter build apk --release
```

输出: `build/app/outputs/flutter-apk/app-release.apk`

#### 5. 构建 iOS IPA

```bash
flutter build ios --release
```

#### 6. 构建 Web

```bash
flutter build web --release
```

输出: `build/web/`

### OSS Bucket 配置

#### 1. 创建 Bucket

```bash
# 在阿里云 OSS 控制台创建 bucket
# 例如: snowfish-bucket
```

#### 2. 配置 CORS

```json
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

#### 3. 设置权限

- **公开读**: 允许直接访问上传的文件
- **私有**: 需要签名 URL 访问

建议: 使用公开读权限，便于图片预览

---

## 问题排查

### 常见问题

#### Q: 登录后无法加载商品列表
**A**: 
1. 检查 Supabase 连接状态
2. 验证 entities 表是否有数据
3. 检查 RLS 策略是否允许读取
```dart
// 测试连接
try {
  final test = await Supabase.instance.client
    .from('entities')
    .select()
    .limit(1);
  print('连接正常');
} catch (e) {
  print('连接失败: $e');
}
```

#### Q: 上传头像失败（401 错误）
**A**:
1. 重新登录刷新 JWT token
2. 检查环境变量是否配置
3. 查看 Edge Function 日志
```dart
// 手动刷新 token
final session = await Supabase.instance.client.auth.refreshSession();
if (session.session != null) {
  print('Token 刷新成功');
}
```

#### Q: 图片无法显示
**A**:
1. 检查 OSS URL 是否可访问
2. 验证 user_profiles.avatar_url 字段值
3. 查看网络请求日志
```dart
// 测试图片 URL
final response = await http.head(Uri.parse(imageUrl));
if (response.statusCode == 200) {
  print('图片可访问');
} else {
  print('图片不可访问: ${response.statusCode}');
}
```

#### Q: Edge Function 超时
**A**:
1. 检查阿里云 OSS 服务状态
2. 验证网络连接
3. 检查函数执行时间（最多 600 秒）

#### Q: 发布商品后媒体未关联
**A**:
1. 确保 entityId 正确
2. 检查 media 表 RLS 策略
3. 验证媒体上传是否成功
```dart
// 检查媒体
final media = await Supabase.instance.client
  .from('media')
  .select()
  .eq('entity_id', entityId);
print('媒体数量: ${media.length}');
```

### 调试清单

- [ ] Supabase 项目 URL 正确
- [ ] Supabase Anon Key 正确
- [ ] 环境变量已配置（OSS 密钥等）
- [ ] 网络连接正常
- [ ] 用户已登录且 JWT 有效
- [ ] 数据库表已创建
- [ ] Edge Function 已部署
- [ ] OSS Bucket 已创建
- [ ] RLS 策略已配置
- [ ] 查看控制台日志输出

---

## 开发规范

### 代码风格

- 遵循 Dart [官方风格指南](https://dart.dev/guides/language/effective-dart)
- 使用 `flutter analyze` 检查代码
- 使用 `dart format` 格式化代码

### 命名约定

| 元素 | 约定 | 示例 |
|------|------|------|
| 类 | PascalCase | `BaseEntity`, `MediaModel` |
| 方法/函数 | camelCase | `fetchEntities()`, `uploadMedia()` |
| 常量 | UPPER_SNAKE_CASE | `ENTITY_TYPE_PRODUCT`, `USE_LOCAL_DATA` |
| 私有成员 | _camelCase | `_titleController`, `_mediaService` |
| 文件 | snake_case | `base_entity.dart`, `media_model.dart` |

### 文件组织

```
lib/
├── models/           # 数据模型（不依赖其他模块）
├── services/         # 业务逻辑服务
├── pages/            # UI 页面和组件
├── utils/            # 工具函数
└── config.dart       # 全局配置
```

### 注释规范

```dart
/// 文件级别注释
/// 说明该文件的目的和主要功能

class MyClass {
  /// 属性说明
  final String name;
  
  /// 方法说明
  /// 
  /// 参数说明:
  /// - [param1]: 参数1说明
  /// 
  /// 返回值说明
  /// 
  /// 使用示例:
  /// ```dart
  /// final result = await myMethod(param1);
  /// ```
  Future<String> myMethod(String param1) async { ... }
}
```

---

## 性能优化

### 图片优化

1. **懒加载**: 使用 `CachedNetworkImage` 的占位图
2. **压缩**: 上传前自动压缩到合理大小
3. **缓存**: 利用本地缓存减少网络请求
4. **CDN**: 通过 OSS CDN 加速

### 数据库优化

1. **索引**: 在常用查询字段建立索引
2. **分页**: 使用 limit + offset 进行分页查询
3. **缓存**: 缓存频繁查询的数据
4. **批量操作**: 使用批量插入而非逐条插入

### UI 优化

1. **虚拟滚动**: 瀑布流自动只渲染可见部分
2. **避免重建**: 使用 const 构造函数
3. **异步加载**: 不在主线程执行耗时操作
4. **图片优化**: 使用合适的图片尺寸和格式

---

## 更新日志

### v1.0.0 (2026-02-04)
- ✅ 完成核心功能开发
- ✅ 修复全局编译错误（129 → 0）
- ✅ 完善 Edge Function 认证
- ✅ 整合所有文档为单一指南

### v0.9.0 (2026-02-03)
- 重写 Edge Function（JWT + OSS）
- 改进 Flutter 客户端认证
- 修复关键 bug

### v0.8.0 (2026-02-01)
- 实现通用实体架构
- 迁移 ProductService → EntityService
- 完成 UI 重构

---

## 许可证

本项目采用 MIT 许可证

---

## 联系方式

**项目维护**: Snow Fish 开发团队  
**文档更新**: 2026年2月4日  
**支持渠道**: GitHub Issues

---

**本文档作为项目的单一真实来源（SSOT），包含所有需要了解的项目信息。**

