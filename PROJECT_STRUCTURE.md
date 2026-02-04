# SNOW_FISH 项目架构文档

## 项目简介
SNOW_FISH 是一个基于 Flutter 和 Supabase 开发的二手雪具交易及滑雪社区平台。项目支持商品发布、帖子展示、视频播放、用户个人资料管理等功能。

## 项目背景与目标
* 项目起源于个人二手雪具交易与滑雪社区的真实需求
* 面向学生和滑雪爱好者，强调低成本、快速迭代、可真实上线
* 目标不是 Demo，而是**具备真实用户、真实数据流的 MVP 应用**
* 在技术选型上优先考虑：
  * 国内可访问性
  * 零运维或极低运维成本
  * 对新手友好，但不限制后期扩展

## 技术栈
* **前端框架**: Flutter
* **后端服务**: Supabase (Database, Auth, Storage, Edge Functions)
* **状态管理**: 主要是基于 `StatefulWidget` 和 `setState` 的原生状态管理
* **数据存储**: Supabase PostgreSQL + 阿里云OSS
* **网络/图片**: `cached_network_image`, `supabase_flutter`

### 技术选型说明
**为什么选择 Flutter**
* 单代码库支持 Android / iOS
* UI 表达能力强，适合内容型 + 媒体型 App
* 社区成熟，生态稳定，适合长期维护

**为什么选择 Supabase**
* 提供完整 Backend-as-a-Service 能力（Auth / DB / Realtime）
* 国内网络可用性优于 Firebase
* 内置 PostgreSQL，数据结构清晰，可控性强
* 支持实时订阅，满足商品/帖子即时刷新需求
* 避免自建后端带来的部署与运维成本

**为什么对象存储使用阿里云 OSS**
* Supabase Storage 容量和带宽有限
* OSS 成本低、稳定性高
* 通过 Supabase Edge Function 实现安全直传
* 前端无需暴露任何云厂商密钥

## 系统整体架构
```
Flutter App (UI / State)
        ↓
Service Layer (Product / Post / Media / Auth)
        ↓
Supabase SDK
   ├─ Auth (用户认证 / Session)
   ├─ Database (PostgreSQL + RLS)
   ├─ Realtime (Stream)
   └─ Edge Functions
           ↓
      阿里云 OSS（图片 / 视频）
```

## 目录结构
- `lib/`: 核心源代码
  - `main.dart`: 应用入口，初始化 Supabase 配置
  - `config.dart`: 全局配置（如 `USE_LOCAL_DATA` 开关及示例数据）
  - `supabase_client.dart`: Supabase 客户端单例管理
  - `product_service.dart`: 商品业务逻辑服务 (CRUD, Realtime Stream)
  - `post_service.dart`: 社区帖子业务逻辑服务
  - `media_service.dart`: 媒体文件（图片、视频）关联管理服务
  - `pages/`: UI 页面
    - `home_tabs.dart`: 底部导航容器 (首页、发布、消息、我的)
    - `home_page.dart`: 首页，包含“广场（帖子）”和“雪具交易（商品）”两个 Tab
    - `posts_list_widget.dart`: 广场帖子列表组件
    - `product_detail_page.dart`: 商品详情页
    - `publish_page.dart`: 商品发布页
    - `publish_post_page.dart`: 帖子发布页
    - `profile_page.dart`: 个人中心，支持视频个人简介
    - `login_page.dart` / `register_page.dart`: 认证页面
    - `chat_page.dart`: 消息/聊天占位页
    - `video_player_page.dart`: 全屏视频播放
- `functions/`: Supabase Edge Functions (Deno/TypeScript)
  - `delete-oss-object/`: 存储文件自动清理函数
- `tools/`: 开发辅助工具
  - `backfill_video_thumbs.dart`: 视频缩略图补全脚本

## 核心功能模块
**1. 用户系统**
* 邮箱 + 密码注册
* 邮箱验证码验证
* 登录态持久化（Supabase Auth）
* 用户资料扩展表 `user_profiles`

**2. 商品系统**
* 商品发布（支持多图）
* 商品实时列表（Realtime Stream）
* 商品详情页（图片轮播 + 全屏查看）
* 商品与用户强关联（user_id）

**3. 社区帖子系统**
* 帖子发布（图 / 视频）
* 实时或准实时展示
* 帖子与用户信息绑定

**4. 媒体系统**
* 统一 media 表
* owner_type + owner_id 进行业务关联
* 支持 image / video
* 支持 OSS 存储与 Supabase 管理元数据

**5. 个人中心**
* 用户资料编辑（头像 / 背景 / 视频）
* 我的商品 / 我的视频
* 登录状态自动切换

## 媒体上传与存储设计
### 上传流程
```
客户端选择文件
→ 本地压缩 / 预处理
→ 请求 Supabase Edge Function
→ 获取 OSS 临时上传 URL
→ 直传 OSS
→ 写入 media 表
→ 业务表通过 owner_id 关联
```

**设计原则**
* 前端永远不接触 OSS 密钥
* 上传失败不污染业务表
* 媒体与业务解耦，可复用

**删除机制**
* 数据删除触发 Edge Function
* 同步清理 OSS 文件，避免垃圾数据

## 核心数据流
1. **认证流**: 通过 `Supabase.instance.client.auth` 管理。在 `home_tabs.dart` 中监听 `onAuthStateChange` 以响应登录/登出。
2. **商品流**: `product_service.dart` 提供 `getProductsWithImagesStream()`，通过 Supabase Realtime 实时推送商品更新，并通过 `media_service` 关联查询图片。
3. **帖子流**: `post_service.dart` 提供 `getPosts()`，目前是单次查询。

## 关键业务逻辑
- **本地模式**: 在 `config.dart` 中设置 `USE_LOCAL_DATA = true` 可以绕过 Supabase 直接运行带有预设数据的 UI。
- **媒体关联**: 商品和用户的图片/视频存储在 `media` 表中，通过 `owner_id` 和 `owner_type` 进行关联。

## 项目阶段划分
**阶段 1：技术验证**
* Flutter 环境搭建
* 模拟器 / 真机调试
* 本地假数据跑通 UI

**阶段 2：后端接入**
* 接入 Supabase
* 建立用户认证
* 商品与帖子持久化

**阶段 3：媒体系统**
* OSS 存储
* Edge Function 直传
* media 表统一管理

**阶段 4：功能完善**
* 多图商品
* 视频管理
* 错误处理与稳定性优化

**当前阶段**
* 已完成 MVP 核心链路
* 架构稳定，可持续扩展

## 开发注意事项
- **State 检查**: 异步操作后必须使用 `if (mounted)` 检查。
- **Late 变量**: `home_tabs.dart` 中的页面列表不应设为 `final` 以便在登录态切换时重建。
- **性能**: 目前 `product_service` 存在 N+1 查询问题，后续建议优化为批量查询。

## 已知问题与技术债务
* 查询性能仍有优化空间（N+1 问题）
* 部分 Realtime 场景需进一步统一
* OSS 文件生命周期管理需更精细
* UI 仍以功能优先，视觉需重构

## Supabase 表结构
-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.media (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  url text NOT NULL,
  media_type text NOT NULL CHECK (media_type = ANY (ARRAY['image'::text, 'video'::text])),
  owner_type text NOT NULL,
  owner_id uuid NOT NULL,
  sort_order integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  thumbnail_url text,
  CONSTRAINT media_pkey PRIMARY KEY (id),
  CONSTRAINT media_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  content text,
  media_urls ARRAY DEFAULT '{}'::text[],
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  author_name text,
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  price numeric,
  location text,
  sellername text,
  selleravatar text,
  image text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  description text,
  user_id uuid,
  status text DEFAULT 'active'::text,
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_profiles (
  id uuid NOT NULL,
  nickname text,
  avatar_url text,
  background_url text,
  profile_video_url text,
  bio text,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);