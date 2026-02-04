# ⚠️ Edge Function Logs 为空 - 快速修复指南

## 问题
Edge Function 在 Supabase 控制台的 **Logs** 标签为空，说明函数可能：
- ❌ 没有被部署成功
- ❌ 没有收到任何请求
- ❌ 部署后没有重启

---

## 🚨 最可能的原因（按优先级）

### 1️⃣ **函数未部署** (概率: 70%)

**症状**：
- Supabase 控制台的 Functions 列表中看不到 `get-oss-upload-url`
- 或显示为 "Not deployed" 状态

**快速修复**：
```bash
# 进入项目目录
cd e:\flutter_projects\snow_fish

# 部署函数
supabase functions deploy get-oss-upload-url

# 验证
supabase functions list
```

**预期输出**：
```
✓ get-oss-upload-url (Deployed)
```

---

### 2️⃣ **环境变量配置错误** (概率: 15%)

**症状**：
- 函数已部署，但 Logs 仍为空
- 或者 Logs 显示 "OSS configuration incomplete"

**快速修复**：

1. 打开 Supabase 控制台
2. 进入 **Functions** → **get-oss-upload-url**
3. 点击 **Settings** 标签
4. 确保存在这 4 个环境变量：

```
☐ OSS_ACCESS_KEY_ID       (你的阿里云 Access Key ID)
☐ OSS_ACCESS_KEY_SECRET   (你的阿里云 Secret)
☐ OSS_BUCKET              (你的 bucket 名称)
☐ OSS_REGION              (你的 OSS 区域，如 oss-cn-beijing)
```

如果缺少任何一个，**逐个添加并点击 Save**。

✅ **保存后函数会自动重启**

---

### 3️⃣ **函数没有被调用** (概率: 10%)

**症状**：
- 函数已部署，环境变量已配置
- 但 Logs 仍然为空

**快速修复**：

手动测试函数：
1. 在 Supabase 控制台打开函数
2. 点击 **Invoke** 标签
3. 在请求体中粘贴：

```json
{
  "filename": "test.jpg",
  "contentType": "image/jpeg",
  "owner_type": "user_profiles",
  "owner_id": "test-user-123"
}
```

4. 添加 Header：
```
Authorization: Bearer YOUR_JWT_TOKEN
```

5. 点击 **Send**

**结果**：
- ✅ **Logs 中应该出现请求日志**
- ✅ **返回 uploadUrl** → 函数工作正常
- ❌ **返回 401 错误** → JWT token 问题
- ❌ **返回 "OSS configuration incomplete"** → 环境变量缺失

---

### 4️⃣ **Flutter 客户端没有正确调用** (概率: 5%)

**症状**：
- 函数已部署且工作正常
- 但 Flutter 应用上传时仍然失败

**快速修复**：

检查 `lib/pages/edit_profile_page.dart`：

```dart
// 确保这行存在
final resp = await Supabase.instance.client.functions.invoke(
  'get-oss-upload-url',  // ✓ 函数名必须正确
  body: body,
  headers: {'Authorization': 'Bearer ${session!.accessToken}'},  // ✓ 必须有这个header
);
```

---

## 🎯 完整排查流程 (5分钟)

### Step 1: 检查函数是否存在

打开 Supabase 控制台 → **Functions**

**问题**：看不到 `get-oss-upload-url`
- 👉 **解决**：运行 `supabase functions deploy get-oss-upload-url`

**正常**：看到 `get-oss-upload-url` → 继续 Step 2

---

### Step 2: 检查环境变量

Functions → `get-oss-upload-url` → **Settings**

**问题**：缺少环境变量
- 👉 **解决**：添加所有 4 个环境变量，点击 Save

**正常**：所有 4 个变量都存在 → 继续 Step 3

---

### Step 3: 手动测试函数

Functions → `get-oss-upload-url` → **Invoke**

**问题**：
- 看到 `Invalid JWT` → JWT token 过期，重新登录 Flutter 应用
- 看到 `Missing required fields` → 检查请求体
- 看到 `OSS configuration incomplete` → 回到 Step 2

**正常**：返回 `uploadUrl` → 继续 Step 4

---

### Step 4: Flutter 应用测试

1. 在 Flutter 应用中**退出登录**
2. **关闭应用**
3. **重新打开并登录**
4. 进入 **Edit Profile** 页面
5. 选择**头像**并**上传**

**问题**：仍然 401 错误
- 👉 **解决**：
  - 清理缓存 `flutter clean`
  - 重新运行 `flutter run`
  - 重新登录（获取新 token）

**成功**：✅ 头像上传完成

---

## 📋 快速检查清单

```
部署状态:
☐ Supabase 控制台能看到 get-oss-upload-url 函数
☐ 函数状态显示为 "Deployed"
☐ 函数有实时日志输出

环境变量:
☐ OSS_ACCESS_KEY_ID 已配置
☐ OSS_ACCESS_KEY_SECRET 已配置
☐ OSS_BUCKET 已配置
☐ OSS_REGION 已配置
☐ 所有变量已保存 (点击 Save)

函数测试:
☐ 在 Invoke 标签能成功调用函数
☐ 返回 uploadUrl (不是错误)
☐ Logs 中有请求日志

Flutter 应用:
☐ 已退出并重新登录
☐ 进入 Edit Profile 页面
☐ 选择图片并上传
☐ 检查 Flutter 调试日志 (flutter run -v)
☐ 在 Supabase Logs 中看到请求
```

---

## 🔧 如果仍然不工作

### 核查清单

1. **Supabase 项目 ID 是否正确？**
   ```bash
   supabase projects list
   ```
   应该看到你的项目

2. **项目是否链接？**
   ```bash
   cat .supabase/config.toml | grep project_id
   ```
   应该显示你的项目 ID

3. **网络连接是否正常？**
   ```bash
   supabase functions list
   ```
   应该显示函数列表

4. **Deno 是否安装？**
   ```bash
   deno --version
   ```
   函数使用 Deno 运行时

---

## 🆘 获取帮助

如果以上都检查过还是不工作，收集以下信息：

1. **Supabase Functions 列表** (screenshot)
2. **函数 Logs** 的最后 20 行
3. **Flutter 调试日志** (flutter run -v)
4. **错误完整信息** (包括 status code)

---

## 参考文档

- 📖 [EDGE_FUNCTION_DEPLOYMENT.md](EDGE_FUNCTION_DEPLOYMENT.md) - 完整部署指南
- 📖 [JWT_401_TROUBLESHOOTING.md](JWT_401_TROUBLESHOOTING.md) - 401 错误排查
- 📖 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md) - 项目完整文档

---

**最后更新**: 2026年2月4日
