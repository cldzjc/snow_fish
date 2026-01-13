# 个人主页与 OSS 上传功能开发记录

**日期**: 2026-01-12
**作者**: GitHub Copilot

## 一句话说明
实现“个人主页 + 编辑主页”功能：支持选择头像/背景/视频，调用 Supabase Edge Function 获取阿里云 OSS 预签名 PUT URL 上传文件，上传完成后更新 `user_profiles` 表；并修复了构建、API 及 DB 字段不匹配的问题。

---

## 变更摘要（按文件）

- `lib/pages/edit_profile_page.dart`
  - 新增头像/背景/视频选择、预览与上传逻辑。
  - 调用 Edge Function `get-oss-upload-url` 获取 `uploadUrl` + `publicUrl`。
  - 使用 `http.put` 上传文件 bytes，上传后更新 DB 中相应字段。
  - 增强错误处理，并对 Function 404（未找到）返回友好提示。

- `lib/pages/profile_page.dart`
  - 显示封面/头像/签名/视频（支持 video_player）。
  - 增加对两套列名的兼容（`username`⇄`nickname`、`intro`⇄`bio`、`cover_url`⇄`background_url`、`video_url`⇄`profile_video_url`）。
  - 为封面图添加 `loadingBuilder` / `errorBuilder` 并在加载失败时写日志，便于排查 403/404 带来的无法加载问题。

- `lib/supabase_client.dart`
  - 使用项目的 `supabaseUrl`，保证调用的 Supabase 项目正确。

- `pubspec.yaml`
  - 升级/调整依赖（`file_picker`, `video_player`, `http`, `mime`, `path` 等），解决依赖冲突并支持桌面/移动端文件选取与视频播放。

---

## 遇到的问题 & 处理方式

1. Kotlin 增量编译错误（构建失败）
   - 原因：Kotlin incremental 在关闭插件缓存时抛错，受不同磁盘根路径影响（项目在 E:, pub cache 在 C:）。
   - 处理：升级插件版本（file_picker、video_player），建议执行 `flutter clean`、停止 Gradle 守护进程，或在 `android/gradle.properties` 临时设置 `kotlin.incremental=false`。

2. Edge Function 404（Function not found）
   - 原因：代码最初调用 `get_upload_url`，实际部署的函数名是 `get-oss-upload-url`。
   - 处理：修改代码调用为 `get-oss-upload-url`，并在 `_getUploadInfo` 中增加错误消息和日志。

3. 数据库字段名不匹配（Update 失败）
   - 发现：你的表里字段为 `nickname`, `background_url`, `profile_video_url`, `bio`，代码最初尝试写入 `cover_url`, `video_url`, `username`, `intro` 等。
   - 处理：把读取改为同时支持两套列名，写入使用你现有列（`nickname`, `bio`, `background_url`, `profile_video_url`）。也提供了 SQL（ALTER TABLE）供选择直接在 DB 增列。

4. 封面加载慢或不显示
   - 处理：在 UI 中增加加载指示和错误回调，同时会打印 `debugPrint` 日志以便用 `flutter run` 查错；并建议用浏览器或 `curl -I <publicUrl>` 验证 publicUrl 是否返回 200/403/404。

---

## 验证步骤（快速清单）

- 验证 Edge Function 返回
  ```bash
  supabase functions invoke get-oss-upload-url --project-ref <project-ref> --body '{"filename":"test.jpg","contentType":"image/jpeg"}'
  ```
  - 期望返回 JSON 包含 `uploadUrl` 与 `publicUrl`。

- 验证 publicUrl 是否可访问
  ```bash
  curl -I "<publicUrl>"
  ```
  - 期望 HTTP 状态 200；若 403/404，检查 OSS 对象权限或 Edge Function 生成的 URL。

- 在 App 内端到端测试
  1. 编辑页面选择文件并保存（确认 Snackbar 提示“已保存”）。
  2. 回主页，确认头像/背景/视频显示正常。
  3. 若封面未显示或报错，查看 `flutter run` 的日志搜索 `Cover image load error:`。

---

## 后续建议（优先级）

1. 确认 OSS 对象是否为公开或正确的访问策略（Edge Function 配置签名是否正确）。
2. 增加上传进度与失败重试按钮提高 UX。  
3. 若愿意，标准化数据库字段名并写迁移脚本（例如把 `background_url` 统一到 `cover_url`）。
4. 编写集成测试来覆盖 Edge Function 返回与上传流程（mock 或真实端）。

---

如果你需要，我可以：
- 把这份文档再格式化到 `README` 或 `CHANGELOG` 中；
- 添加脚本自动化检查 publicUrl 可用性；
- 帮你在 Supabase Console 执行 SQL（需你确认权限或把结果贴过来）。

---

> 备注：本文件为开发内部记录，内容偏实操与排查细节，适合贴到项目 `docs/` 或作为 PR 描述的一部分。