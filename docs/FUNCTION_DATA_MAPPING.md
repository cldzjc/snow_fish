# Snow Fish 功能、代码与 Supabase 映射

> 用于决定哪些表保留、归档或删除。  
> “当前使用”表示现行代码存在直接引用；“历史/非核心”表示代码仍存在，但不符合当前 UGC 产品定位。

## 1. 建议保留的核心表

| Supabase 表 | 当前用途 | 主要代码入口 | 产品判断 |
|---|---|---|---|
| `user_profiles` | 昵称、头像、简介、背景图、角色 | `edit_profile_page.dart`, `profile_page.dart`, `admin_center_page.dart` | **保留** |
| `entities` | 统一内容主表；通过 `entity_type` 区分帖子和闲置雪具 | `entity_service.dart`, `home_page.dart`, `publish_post_page.dart`, `idle_publish_page.dart` | **保留，核心主表** |
| `media` | 内容、用户视频和图片的媒体元数据 | `media_service.dart`, `my_videos_page.dart` | **保留** |
| `comments` | 内容评论、回复、评论作者快照、评论点赞数 | `comment_service.dart`, `post_detail_page.dart`, `product_detail_page.dart` | **保留** |
| `interactions` | 内容点赞/踩、评论点赞等用户互动记录 | `entity_service.dart`, `comment_service.dart` | **保留** |
| `interaction_counters` | 互动计数缓存/汇总 | `entity_service.dart` | **暂保留，需确认触发器和查询是否仍在使用** |

### 核心数据关系

```text
auth.users
  └── user_profiles

user_profiles
  └── entities.user_id

entities
  ├── media.entity_id
  ├── comments.entity_id
  └── interactions.entity_id
```

建议的内容类型：

| `entity_type` | 当前含义 | 备注 |
|---|---|---|
| `post` | 约滑、约饭、经验、讨论等 UGC | 当前产品主线 |
| `product` | C2C 二手雪具内容 | 当前保留，但定位为 UGC 内容类型 |
| `service` | 历史/预留类型 | 暂不扩展，确认无数据后再决定 |

## 2. 与当前方向冲突的表

| Supabase 表 | 当前代码引用 | 对应功能 | 建议 |
|---|---|---|---|
| `orders` | `services/order_service.dart`, `my_orders_page.dart`, `merchant_center_page.dart` | 买卖订单、支付前后状态 | **候选删除/归档** |
| `order_items` | `services/order_service.dart` | 订单明细 | **随 `orders` 一起处理** |
| `order_status_history` | `services/order_service.dart` | 订单状态历史 | **随 `orders` 一起处理** |
| `address_records` | `services/address_service.dart`, `my_addresses_page.dart` | 收货地址 | **候选删除/归档** |

这些表不是“没有代码”，而是“有代码但属于被论文需求带入的交易轨道”。如果决定回到纯 UGC，应该先移除/隐藏对应页面和服务，再处理数据库表。

## 3. 平台治理和历史表

| Supabase 表 | 当前状态 | 建议 |
|---|---|---|
| `admin_actions_bak_20260419` | 名称带备份日期，未发现现行 Dart 代码直接引用 | 先保留并核对是否有历史数据；确认无用后归档或删除 |
| `merchant_applications_bak_20260419` | 名称带备份日期，未发现现行 Dart 代码直接引用 | 当前商户入驻尚未形成产品闭环；先保留，后续设计商户合作专区时重新建模 |
| `migration_logs` | 未发现现行 Dart 代码直接引用 | 仅用于迁移审计；确认无审计要求后可归档，不属于业务表 |

## 4. 发现的代码和 Schema 问题

### `posts` 表引用

`lib/post_service.dart` 直接访问 `posts`，但当前 Supabase public schema 列表中没有 `public.posts`。这有两种可能：

1. `post_service.dart` 已经废弃，现行 UI 应统一到 `EntityService + entities(entity_type='post')`；
2. 仍有遗漏页面依赖旧表，需要先迁移再删除旧服务。

建议下一步先做代码引用确认和运行路径验证，**不要直接创建 `posts` 表**，否则会重新引入两套内容模型。

### RLS

当前 Supabase MCP 读到：

- `comments` 已启用 RLS；
- `user_profiles`、`entities`、`media`、`interactions`、`orders`、`order_items`、`order_status_history`、`address_records` 等未启用 RLS。

在决定删除表之前，应先确认是否有真实用户数据、外部脚本或 Edge Function 依赖。RLS 策略需要按表设计，不能只执行批量 `ENABLE ROW LEVEL SECURITY`。

## 5. 本轮代码收敛结果

已从 Flutter 应用移除交易轨道的页面、服务、模型和组件：

- `order_service.dart`
- `address_service.dart`
- `marketplace_order.dart`
- `address_record.dart`
- `my_orders_page.dart`
- `my_addresses_page.dart`
- `merchant_center_page.dart`
- `product_detail_page.dart`
- `my_listings_page.dart`
- `my_products_page.dart`
- 购买、支付和地址选择组件
- `post_service.dart` 与 `product_service.dart` 历史服务

UGC 主链路现在统一为：

```text
HomePage
  -> PostsListWidget
  -> PostDetailPage
  -> CommentService / PostActionBar

ProfilePage(userId?)
  -> user_profiles
  -> EntityService.fetchUserEntities(type: 'post')
```

## 6. 删除/保留决策表

请按以下选项做决定，后续可以分批执行：

| 编号 | 对象 | 选项 |
|---|---|---|
| A | `entities` / `media` / `user_profiles` / `comments` / `interactions` | 默认保留 |
| B | `interaction_counters` | 保留并核对，或删除相关计数逻辑 |
| C | `orders` / `order_items` / `order_status_history` | 删除交易轨道，或暂时保留但停止扩展 |
| D | `address_records` | 删除，或暂时保留以便未来商城使用 |
| E | `admin_actions_bak_20260419` / `merchant_applications_bak_20260419` / `migration_logs` | 归档/删除，或保留历史审计 |
| F | `lib/post_service.dart` 与 `posts` 旧模型 | 已从 Flutter 代码删除；不创建 `posts` 表 |

可在 Supabase SQL Editor 执行以下脚本，删除交易、平台治理和迁移历史表，
并启用当前 UGC 表的 RLS：

[`docs/supabase_ugc_cleanup_and_rls.sql`](./supabase_ugc_cleanup_and_rls.sql)

该脚本会永久删除以下表：

```text
orders
order_items
order_status_history
address_records
admin_actions_bak_20260419
merchant_applications_bak_20260419
migration_logs
```

脚本不会删除 `user_profiles`、`entities`、`media`、`comments`、
`interactions` 或 `interaction_counters`，而是为这些当前 UGC 表设置 RLS。
Supabase MCP 当前配置为 `read_only=true`，因此本次不会通过 MCP 执行删除或策略变更。
