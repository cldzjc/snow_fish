# 🚀 Edge Function 部署指南

## 快速部署（3 步）

### 步骤 1️⃣: 使用 Supabase CLI 部署

```bash
# 进入项目根目录
cd e:\flutter_projects\snow_fish

# 登录 Supabase（如果未登录）
supabase login

# 链接到你的 Supabase 项目
supabase link --project-ref YOUR_PROJECT_ID

# 部署 Edge Function
supabase functions deploy get-oss-upload-url

# 验证部署
supabase functions list
```

**预期输出**：
```
✓ Function deployed: get-oss-upload-url
```

---

### 步骤 2️⃣: 在 Supabase 控制台配置环境变量

1. 打开 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择你的项目
3. 进入 **Functions** → **get-oss-upload-url**
4. 点击 **Settings** 标签
5. 在 **Environment Variables** 添加以下 4 个变量：

```
OSS_ACCESS_KEY_ID       = your_aliyun_key_id
OSS_ACCESS_KEY_SECRET   = your_aliyun_key_secret
OSS_BUCKET              = your_bucket_name
OSS_REGION              = oss-cn-beijing  (根据你的区域修改)
```

6. 点击 **Save** （函数会自动重启）

---

### 步骤 3️⃣: 测试函数

在 Supabase 控制台 → **Functions** → **get-oss-upload-url** → **Invoke** 标签：

**请求体**：
```json
{
  "filename": "test.jpg",
  "contentType": "image/jpeg",
  "owner_type": "user_profiles",
  "owner_id": "test-user-id"
}
```

**请求头**（添加）：
```
Authorization: Bearer <你的_JWT_token>
```

获取 JWT token 的方法：
1. 在 Flutter 应用中登录
2. 打开 Edit Profile 页面
3. 查看调试日志中的 "Token 长度: xxx"
4. 从 Supabase 控制台登录时的 session token

**预期响应**（成功）：
```json
{
  "uploadUrl": "https://your-bucket.oss-cn-beijing.aliyuncs.com/...",
  "publicUrl": "https://your-bucket.oss-cn-beijing.aliyuncs.com/...",
  "objectKey": "snowfish/..."
}
```

**实际响应**（失败）：
```json
{
  "error": "OSS configuration incomplete"
}
```

---

## 如果部署失败

### 错误 1: "Function already exists"

```bash
# 删除旧函数
supabase functions delete get-oss-upload-url

# 重新部署
supabase functions deploy get-oss-upload-url
```

### 错误 2: "No such file or directory"

确保你在项目根目录运行命令：
```bash
cd e:\flutter_projects\snow_fish
pwd  # 应该显示项目路径
ls functions/  # 应该看到 get-oss-upload-url/
```

### 错误 3: "Connection refused"

登录可能过期：
```bash
supabase logout
supabase login
supabase link --project-ref YOUR_PROJECT_ID
supabase functions deploy get-oss-upload-url
```

---

## 验证部署成功

### 在 Supabase 控制台检查

1. **Functions 列表**：
   - ✅ 应该看到 `get-oss-upload-url` 显示为 "Deployed"

2. **Logs**：
   - 点击函数 → **Logs** 标签
   - 应该看到日志消息（即使没有调用）

3. **Test 调用**：
   - 点击 **Invoke** 标签
   - 发送测试请求
   - 应该在 Logs 中看到请求日志

### 日志应该包含

**成功调用的日志**：
```
📨 [GET-OSS-UPLOAD-URL] Received request at 2026-02-04T...
🔑 Authorization header: Bearer eyJhbGc...
🔐 Token length: 1234
✅ User authenticated: user-id-xyz
📋 Request params: {filename: 'test.jpg', ...}
✅ Successfully generated upload URL
```

**失败的日志示例**：
```
❌ No Bearer authorization header provided
```

---

## 完整清单

部署前确认：
- [ ] 已安装 Supabase CLI（`supabase --version`）
- [ ] 已登录 Supabase（`supabase projects list`）
- [ ] 项目已链接（`supabase projects list` 显示你的项目）

部署时：
- [ ] 运行 `supabase functions deploy get-oss-upload-url`
- [ ] 看到 "✓ Function deployed" 消息
- [ ] 在控制台 Functions 列表中看到该函数

部署后：
- [ ] 配置了 4 个 OSS 环境变量
- [ ] 环境变量保存成功
- [ ] 在 Logs 中能看到请求记录
- [ ] Test 调用返回预期的 uploadUrl

---

## 常见问题

### Q: 部署后 Logs 仍然为空？
A: 说明函数没有被调用。尝试：
1. 在控制台点击 **Invoke** 发送测试请求
2. 在 Flutter 应用中重新尝试上传
3. 查看 Flutter 调试日志看是否有错误

### Q: Invoke 返回 401 错误？
A: Authorization header 可能不正确。确保：
1. Bearer token 是有效的 JWT
2. Token 格式为 `Bearer <token>`（中间有空格）
3. Token 未过期

### Q: 返回 "OSS configuration incomplete"？
A: 检查环境变量：
1. 在 Settings 中确认所有 4 个变量都已保存
2. 变量名称完全匹配（区分大小写）
3. 值不为空

### Q: 返回"Missing required fields"?
A: 检查请求体：
```json
{
  "filename": "...",        // ✓ 必须有
  "contentType": "...",     // ✓ 必须有
  "owner_type": "...",      // ✓ 必须有（或 entity_type）
  "owner_id": "..."         // 可选但推荐
}
```

---

## 文件结构

```
snow_fish/
├── functions/
│   ├── deno.json                    ← 配置文件（新建）
│   ├── get-oss-upload-url/
│   │   └── index.ts                 ← Edge Function 代码
│   └── delete-oss-object/
│       └── index.ts
├── lib/
│   ├── pages/
│   │   └── edit_profile_page.dart   ← 调用 Edge Function
│   └── supabase_client.dart         ← Supabase 初始化
└── pubspec.yaml
```

---

## 下一步

部署成功后：
1. 在 Flutter 应用中重新登录（获取新的 token）
2. 进入 Edit Profile 页面
3. 选择头像并上传
4. 在 Supabase 控制台 Logs 中观察日志

**预期行为**：
- 应该看到上传日志
- 上传完成后得到 uploadUrl
- 头像应该更新成功

---

**最后更新**: 2026年2月4日
