# Supabase 数据库与内容治理概括

> 更新时间：2026-11-10  
> 项目：Snow Fish / skneo  
> Project ref：`tjnrilfjbvwyfwjhwmay`

## 1. 当前数据库基础结构

当前 `public` schema 的核心业务表：

```text
user_profiles
entities
media
comments
interactions
interaction_counters
```

当前内容模型使用 `entities` 表，帖子通过：

```text
entities.entity_type = 'post'
```

当前没有独立的 `posts` 表。

### 主要关系

```text
auth.users
  └── user_profiles

auth.users
  ├── entities.user_id
  ├── comments.user_id
  ├── media.user_id
  └── interactions.user_id

entities
  ├── media.entity_id
  └── comments.entity_id

comments
  └── comments.parent_id
```

`interactions.entity_id` 同时用于实体或评论目标，但当前没有直接外键约束。

## 2. 本次已执行的内容治理迁移

本次执行的治理 SQL 已从仓库删除，以下内容是根据已执行 SQL 整理的结果。

### 2.1 `entities` 新增治理字段

```text
moderation_status   text    默认 visible
moderation_reason   text
moderated_by        uuid
moderated_at        timestamptz
```

`moderation_status` 允许：

```text
visible
hidden
removed
```

### 2.2 `comments` 新增治理字段

```text
moderation_status   text    默认 visible
moderation_reason   text
moderated_by        uuid
moderated_at        timestamptz
```

### 2.3 `user_profiles` 新增账号状态字段

```text
account_status          text    默认 active
account_status_reason   text
account_status_until    timestamptz
```

`account_status` 允许：

```text
active
muted
suspended
```

## 3. 新增治理表

### `reports`

用于用户举报帖子、评论或用户。

主要字段：

```text
id
reporter_id
target_type       entity / comment / user
target_id
reason
details
status            open / reviewing / resolved / dismissed
resolved_by
resolution_note
created_at
resolved_at
```

同一用户可以对同一目标再次举报，但服务端 RPC 对短时间内的连续举报进行频率限制。

### `user_blocks`

用于用户拉黑其他用户。

```text
blocker_id
blocked_id
created_at
```

`blocker_id` 和 `blocked_id` 不能相同。

### `user_restrictions`

用于管理员记录禁言和封禁。

```text
id
user_id
restriction_type   mute / suspend
reason
starts_at
ends_at
created_by
active
created_at
```

### `moderation_actions`

用于记录管理员治理操作。

支持的操作类型包括：

```text
hide_content
restore_content
remove_content
resolve_report
dismiss_report
mute_user
suspend_user
restore_user
```

### `notifications`

用于站内通知。

支持的通知类型包括：

```text
content_moderated
account_restricted
report_resolved
comment
reply
like
system
```

原治理版本只有通知读取和已读时间记录，没有自动生成通知。后续迁移文件
`docs/supabase_governance_followup.sql` 增加了举报提交、举报处理、通知已读 RPC
以及 OSS 删除失败任务记录；该文件需要在 Supabase SQL Editor 中执行后才会生效。

## 5. 待执行的治理闭环迁移

`docs/supabase_governance_followup.sql` 不会自动执行，且当前代理没有直接修改线上数据库的权限。
执行后会：

- 为 `media` 增加 `object_key`，用于安全定位 OSS 对象；
- 仅在约束定义精确匹配旧举报目标唯一规则时移除该约束，不删除其他 UNIQUE 约束；
- 通过 `submit_report` 校验登录、目标存在和禁止自举报；
- 通过 `moderate_report` 原子更新举报、帖子/评论治理状态、管理员操作记录和用户通知；
- 通过 `mark_notification_read` 限制用户只能修改自己的已读状态；
- 为 OSS 删除失败创建 `media_deletion_tasks` 重试记录；
- 收紧举报、操作记录和通知的直接写权限；
- 保护 `user_profiles.role` 和账号治理字段不被普通用户直接改写。

执行前请先备份数据库，并确认线上 `notifications` 表包含 `entity_id` 字段；如果没有，
需要先按实际字段调整迁移中的通知关联字段。还应检查现有 RLS policy，避免旧的宽泛
策略与新增策略通过 OR 叠加放宽权限。

## 4. 本次新增索引

本次 SQL 添加了以下索引：

```text
reports(status, created_at desc)
reports(target_type, target_id)
user_blocks(blocked_id)
user_restrictions(user_id, active, ends_at)
moderation_actions(target_type, target_id, created_at desc)
notifications(recipient_id, created_at desc)
media(entity_id)
media(user_id)
```

## 5. 本次新增的内容字段保护

新增触发器函数：

```text
public.protect_user_content_fields()
```

普通用户更新自己的内容时，以下字段会保留原值，不能通过普通更新请求修改：

### `entities`

```text
user_id
entity_type
moderation_status
moderation_reason
moderated_by
moderated_at
```

### `comments`

```text
user_id
entity_id
parent_id
like_count
is_deleted
deleted_at
author_nickname
author_avatar
moderation_status
moderation_reason
moderated_by
moderated_at
```

管理员判断使用数据库中原有的：

```text
public.is_admin()
```

本次没有修改 `is_admin()`、Edge Function 或管理员判断函数本身。

## 6. 本次新增和更新的 RLS

新治理表均已启用 RLS。

### `reports`

- 登录用户只能创建 `reporter_id = auth.uid()` 的举报；
- 用户可以读取自己的举报；
- 管理员可以读取全部举报；
- 只有管理员可以更新举报状态和处理结果。

### `user_blocks`

- 用户只能读取自己的拉黑关系；
- 用户只能创建自己的拉黑关系；
- 用户只能删除自己的拉黑关系；
- 不能拉黑自己。

### `user_restrictions`

- 仅管理员可以读写。

### `moderation_actions`

- 仅管理员可以读写；
- 写入时 `moderator_id` 必须是当前登录管理员。

### `notifications`

- 用户只能读取自己的通知；
- 用户只能更新自己的通知，例如设置 `read_at`。

### 帖子和评论公开读取

帖子公开读取条件现在包含：

```text
entity_type = 'post'
and moderation_status = 'visible'
```

用户本人和管理员仍可以读取自己的或被治理的帖子。

评论公开读取条件现在包含：

```text
moderation_status = 'visible'
and is_deleted = false
```

用户本人和管理员仍可以读取自己的或被治理的评论。

## 7. 本次前端已接入的功能

### 普通用户

- 帖子详情页举报帖子；
- 评论菜单举报评论；
- 用户主页拉黑用户；
- 用户主页打开通知页面；
- 通知页面读取自己的通知并标记为已读。

对应代码：

- `lib/services/moderation_service.dart`
- `lib/pages/notifications_page.dart`
- `lib/pages/post_detail_page.dart`
- `lib/widgets/comment_item.dart`
- `lib/pages/profile_page.dart`

### 管理员

管理员用户主页会显示“内容治理中心”入口。

当前管理员中心支持：

- 查看待处理举报；
- 查看举报类型、目标和理由；
- 将举报标记为已处理；
- 驳回举报；
- 填写处理说明。

对应代码：

```text
lib/pages/admin_center_page.dart
```

管理员入口仍由 `user_profiles.role = 'admin'` 控制，真正的数据访问由数据库 RLS 控制。

## 8. 当前尚未实现的部分

以下功能已经有数据库字段或表，但本次还没有完整接入业务流程：

- 管理员确认违规时删除目标帖子；帖子关联评论和媒体数据库记录级联删除，
  互动记录由治理函数显式删除，OSS 媒体由管理员处理流程先行清理；
- 管理员直接处理评论；
- 管理员禁言和封禁操作页面；
- 自动生成内容审核通知；
- 自动生成点赞、评论、回复通知；
- 信息流按 `user_blocks` 过滤；
- 注销时清理 OSS 文件；
- 用户数据导出；
- 用户账号注销和跨系统删除；
- `interactions` 目标外键；
- 评论父评论与当前帖子一致性的数据库约束；
- Edge Function 内部鉴权复核。

## 9. 删除和注销注意事项

数据库级联不能删除阿里云 OSS 文件。

用户注销后如果需要删除全部数据，后续应设计独立流程：

```text
验证当前用户
→ 清理 OSS 文件
→ 清理数据库业务数据
→ 清理 Storage 文件（如果使用）
→ 删除 auth.users
```

当前不要仅执行 `delete from auth.users` 来实现注销。

## 10. 本次变更边界

本次治理迁移：

- 没有删除现有业务表；
- 没有删除现有业务数据；
- 不会无差别删除 UNIQUE 约束或现有 RLS policy；
- 新增了 OSS 删除失败任务表，但不会自动删除 OSS 对象；
- 配套 Edge Function 代码增加了 CORS、上传类型校验、帖子类型校验和删除失败结果；
- 仍不会自动部署 Edge Function 或修改 OSS 控制台配置；
- 治理 RPC 会自动创建举报处理和管理员通知；
- 没有改变用户注销策略；
- 没有解决 `interactions` 缺少目标外键的问题。
