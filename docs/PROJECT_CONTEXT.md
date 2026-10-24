# Snow Fish 项目上下文

> 这是后续开发和排查问题时优先阅读的项目背景与现状摘要。  
> 数据库状态依据 2026-10-20 通过 Supabase MCP 读取的 `public` schema；代码状态依据当前仓库。

## 1. 产品定位

Snow Fish 是面向滑雪人群的垂直内容社区。项目当前阶段的核心不是完整电商，而是通过 UGC 内容吸引雪友：

- 发布约滑、约饭、雪场经验和其他滑雪相关内容；
- 后续可将 C2C 二手雪具重新设计为一种 UGC 内容类型；
- 图片、视频、评论、回复和点赞构成内容互动闭环；
- 平台方负责维护、审核和内容治理；
- 后续再考虑商户合作专区和商城能力。

当前产品优先级：

1. UGC 内容发布、浏览和审核；
2. 用户资料与媒体上传；
3. 评论、回复、点赞等互动；
4. 互动和内容治理；
5. 商户合作专区（规划中）；
6. 交易、支付和订单（当前不属于核心目标）。

## 2. 技术架构

```text
Flutter UI
  -> EntityService / CommentService / MediaService
  -> Supabase Auth + PostgreSQL + Realtime
  -> get-oss-upload-url Edge Function
  -> 阿里云 OSS（图片/视频对象）
```

- 应用入口：`lib/main.dart`
- Supabase 初始化：`lib/supabase_client.dart`
- 本地/线上开关：`lib/config.dart` 中的 `USE_LOCAL_DATA`
- 内容主模型：`lib/models/base_entity.dart`
- 内容服务：`lib/services/entity_service.dart`
- 互动服务：`lib/services/comment_service.dart`
- 媒体服务：`lib/media_service.dart`
- 唯一当前活跃 Edge Function：`get-oss-upload-url`

## 3. 当前已完成的用户能力

### 账号和资料

- 注册、登录、退出和登录态监听；
- 编辑昵称、简介、头像、背景图和个人视频；
- 用户角色字段支持 `user` / `admin`；
- 管理员页面可以查看用户并修改角色。

主要代码：

- `lib/pages/login_page.dart`
- `lib/pages/register_page.dart`
- `lib/pages/profile_page.dart`
- `lib/pages/edit_profile_page.dart`
- `lib/pages/admin_center_page.dart`

### UGC 内容

- 广场内容浏览；
- 发布帖子/社区内容；
- 帖子详情；
- 我的帖子；
- 使用 `entities.entity_type='post'` 表示当前 UGC 动态；
- `extra_data` 保存地点、审核状态等内容扩展字段。

主要代码：

- `lib/pages/home_page.dart`
- `lib/pages/posts_list_widget.dart`
- `lib/pages/publish_post_page.dart`
- `lib/pages/post_detail_page.dart`
- `lib/pages/my_posts_page.dart`
- `lib/services/entity_service.dart`

### C2C 闲置内容

当前已从应用主入口和可运行流程移除。未来如重新加入，应先按 UGC 内容类型重新设计，
不能直接恢复历史商品、订单和支付流程。

### 互动

- 评论；
- 评论回复；
- 评论点赞；
- 内容点赞/踩等互动；
- 评论数量和互动计数的部分冗余字段/函数已存在。

### 媒体

- 图片和视频选择；
- 图片压缩；
- 视频类型检查；
- 通过 Edge Function 获取 OSS 预签名上传地址；
- OSS 上传成功后写入 `media` 表；
- 媒体排序、查询和删除。

## 4. 当前不应当视为核心完成能力的部分

以下功能在代码中存在页面、模型或服务，但与当前 UGC 产品方向不一致，不能当作已经完成的产品闭环：

- 买家/卖家订单；
- 订单状态流转；
- 收货地址；
- 支付确认界面；
- 商家订单发货；
- 商户中心。

这些功能应在后续决策后选择“删除、隐藏、保留为实验功能”之一，不应继续扩展，直到产品方向重新确认。

## 5. 已知技术不一致

- 当前数据库中没有 `public.posts` 表；现行帖子 UI 统一通过 `entities`。
- 数据库中存在订单、地址、备份和迁移日志表，但这不代表它们属于当前产品核心。
- 目前除 `comments` 外，大多数 public 表未启用 RLS。任何删除表或重构前，应先单独设计策略，不能直接执行“只开启 RLS”的脚本。
- `get-oss-upload-url` 当前为 ACTIVE，且 `verify_jwt=false`；这属于后续安全治理重点，不应在本次文档整理中自动修改。

## 6. 后续开发默认原则

1. 新的社区内容优先复用 `entities + media`，不要再创建平行的 `posts` 或 `products` 主表。
2. 只有确实属于用户互动的功能才使用 `comments` / `interactions`。
3. 媒体文件继续走 OSS，数据库只保存元数据和 URL。
4. 平台审核优先通过 `entities.extra_data` 或后续独立审核设计实现，不把订单表当作审核系统。
5. 删除或保留数据库表必须结合代码引用、业务定位、历史数据和迁移依赖共同决定。

## 7. 当前 UGC 功能实现状态

已收敛到应用主入口的功能：

- 动态信息流、动态详情、登录后发布；
- 动态编辑和删除（个人主页的“我发布的动态”）；
- 图片/视频媒体基础能力和 OSS 上传链路；
- 动态点赞/取消点赞；
- 动态收藏/取消收藏；
- 评论、评论删除、评论点赞/取消点赞；
- 评论回复和回复列表；
- 个人资料编辑；
- 查看其他用户主页及其动态；
- 首页作者、详情页作者、评论/回复作者头像和昵称跳转到对应主页；
- 管理员内容审核入口仍保留，用于 UGC 内容治理。

本轮已从 Flutter 应用代码中移除：

- 订单、订单明细、订单状态流转；
- 收货地址；
- 商户中心；
- 支付确认和购买确认；
- 旧 `posts` 服务；
- 独立商品交易页面和旧商品服务。

数据库中的交易遗留表尚未删除。删除数据库表会影响历史数据并属于破坏性操作，必须在确认数据备份和最终表清单后单独执行。
