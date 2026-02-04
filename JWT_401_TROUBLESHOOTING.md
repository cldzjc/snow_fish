# 🔐 JWT 401 认证错误诊断指南

## 问题描述
当上传头像/背景时遇到：
```
Exception: Edge Function 调用失败 (401): FunctionException(status: 401, details: {code: 401, message: Invalid JWT})
```

## 根本原因分析

### 可能的原因（按概率排序）

| # | 原因 | 症状 | 解决方案 |
|---|------|------|--------|
| 1 | **Token 已过期** | 登录 > 5 分钟后上传失败 | 退出重新登录 |
| 2 | **Edge Function 未部署** | 总是 401（即使新登录） | 部署函数到 Supabase |
| 3 | **OSS 环境变量缺失** | 函数部署但返回 401 | 配置环境变量 |
| 4 | **Token 格式错误** | Bearer token 格式不对 | 检查 Supabase 配置 |
| 5 | **CORS 问题** | 浏览器/模拟器网络问题 | 重启应用/清理缓存 |

---

## 快速诊断（5 分钟）

### 步骤 1️⃣: 检查 Supabase 控制台

1. 打开 [Supabase Dashboard](https://supabase.com/dashboard)
2. 进入你的项目 → **Functions** 菜单
3. 查看 `get-oss-upload-url` 函数是否存在
4. **点击函数** → **Logs** 标签

**预期**：应该看到实时日志输出

### 步骤 2️⃣: 检查函数日志

在 Logs 标签中寻找：
- ✅ **成功**: `✅ User authenticated: <user_id>`
- ❌ **失败**: `❌ No Bearer authorization header provided` 或 `Failed to extract user ID`

记下最后的错误信息。

### 步骤 3️⃣: 检查环境变量

在 Supabase 控制台：
1. 进入 **Functions** → 选择 `get-oss-upload-url`
2. 点击右上角 **⚙️ Settings**
3. 查看 **Environment Variables** 部分

**必须存在的变量**：
```
OSS_ACCESS_KEY_ID       ← 阿里云 OSS 密钥 ID
OSS_ACCESS_KEY_SECRET   ← 阿里云 OSS 密钥
OSS_BUCKET              ← 阿里云 OSS bucket 名称
OSS_REGION              ← 阿里云区域（如 oss-cn-beijing）
```

**任何一个缺失都会导致 401**

---

## 详细解决方案

### 🔴 原因 1: Token 已过期

**诊断**：
```
登录成功 → 5 分钟内上传 ✅
登录成功 → 15 分钟后上传 ❌
```

**解决**：
```dart
// 编辑 edit_profile_page.dart - Token 刷新逻辑已自动处理
// 如果仍然失败，尝试以下步骤：

1. 退出登录 (Settings 页面)
2. 完全关闭应用
3. 重新打开应用
4. 重新登录
5. 立即尝试上传（新 token 有效期 1 小时）
```

---

### 🔴 原因 2: Edge Function 未部署

**诊断**：
在 Supabase 控制台的 Functions 列表中：
- ❌ 找不到 `get-oss-upload-url`
- 或者显示 "Not deployed"

**解决**：

#### 方案 A: 使用 Supabase CLI 部署

```bash
# 1. 登录 Supabase
supabase login

# 2. 链接到你的项目
supabase link --project-ref <你的项目ID>

# 3. 部署函数
supabase functions deploy get-oss-upload-url

# 4. 查看部署状态
supabase functions list
```

#### 方案 B: 在 Supabase 控制台手动创建

1. 打开 Supabase 控制台 → **Functions** 
2. 点击 **Create a new function**
3. 选择 **TypeScript** 模板
4. 函数名设为 `get-oss-upload-url`
5. 复制 `functions/get-oss-upload-url/index.ts` 的内容到编辑器
6. 点击 **Deploy**

---

### 🔴 原因 3: 缺少环境变量

**诊断**：
在函数日志中看到：
```
❌ OSS environment variables missing
```

**解决**：

1. 在 Supabase 控制台打开函数 Settings
2. 添加以下环境变量：

```
OSS_ACCESS_KEY_ID       = your_aliyun_access_key_id
OSS_ACCESS_KEY_SECRET   = your_aliyun_access_key_secret
OSS_BUCKET              = your_bucket_name
OSS_REGION              = oss-cn-beijing  (根据实际修改)
```

3. 点击 **Save** 
4. 函数会自动重启
5. 再次尝试上传

**获取阿里云凭证**：
1. 登录 [阿里云控制台](https://console.aliyun.com)
2. 进入 **AccessKey 管理**
3. 创建新的 AccessKey（或使用现有的）
4. 记录 AccessKey ID 和 Secret
5. 找到你的 OSS Bucket 名称和所在区域

---

### 🔴 原因 4: Token 格式错误

**诊断**：
在函数日志中看到：
```
❌ Token structure: 2 parts (expected 3)
JWT should have 3 parts (header.payload.signature)
```

**根本原因**：
Supabase SDK 配置错误或初始化失败

**解决**：

检查 `lib/supabase_client.dart`：
```dart
// 确保 URL 和密钥正确
final client = SupabaseClient(
  'https://your-project-id.supabase.co',
  'your-anon-key',
);
```

在 `lib/main.dart` 中确认初始化：
```dart
await Supabase.initialize(
  url: 'https://your-project-id.supabase.co',
  anonKey: 'your-anon-key',
  authFlowType: AuthFlowType.pkce,
);
```

如果还是失败：
```bash
# 1. 清理 flutter
flutter clean

# 2. 重新获取依赖
flutter pub get

# 3. 重新运行
flutter run
```

---

### 🔴 原因 5: CORS 问题（Web/模拟器）

**诊断**：
网络请求被浏览器拦截或模拟器无法访问

**解决**：

对于 **Android 模拟器**：
```bash
# 清理 build
flutter clean

# 清理 Gradle 缓存
cd android && ./gradlew clean && cd ..

# 重新构建
flutter run -v
```

对于 **iOS 模拟器**：
```bash
# 重启模拟器
xcrun simctl erase all

# 或直接重启 Xcode
```

对于 **Web**：
```bash
# 使用 --web-port 启动特定端口
flutter run -d chrome --web-port=7860
```

---

## 完整调试步骤

### 步骤 1: 启用详细日志

编辑 `lib/main.dart`，在 `main()` 函数开头添加：
```dart
void main() async {
  // 启用 Supabase 调试
  Supabase.initialize(
    debugLevel: 0,  // 0 = verbose logging
  );
  
  runApp(const MyApp());
}
```

### 步骤 2: 运行应用并监视日志

```bash
flutter run -v > debug.log 2>&1
```

### 步骤 3: 重现错误

1. 登录应用
2. 进入编辑资料页面
3. 选择头像并上传

### 步骤 4: 分析日志

查看输出的 `debug.log` 文件，寻找：
- `Authorization header` 是否正确
- `Token 长度` 是否合理（通常 > 500 字符）
- Edge Function 返回的具体错误

---

## 完整修复清单

- [ ] 已部署 `get-oss-upload-url` Edge Function
- [ ] Edge Function 中配置了 4 个 OSS 环境变量
- [ ] 重新登录获得新 token
- [ ] 清理应用 cache（`flutter clean`）
- [ ] 在 Supabase 控制台 Logs 中看到成功消息
- [ ] 头像/背景上传成功

---

## 获取帮助

如果以上步骤都失败，请收集以下信息：

### 必须提供的信息：

1. **Supabase 函数日志**：
   - 在控制台 Functions → Logs 中复制最后 10 行

2. **Flutter 调试日志**：
   ```bash
   flutter run -v 2>&1 | grep -E "(Authorization|Token|401|FunctionException)" > logs.txt
   ```

3. **Supabase 项目信息**：
   - 项目 URL（部分可以隐藏）
   - 部署的函数列表（screenshot）

4. **错误完整消息**：
   - 包括堆栈跟踪

---

## 相关文件位置

| 文件 | 目的 | 修改权限 |
|------|------|--------|
| `functions/get-oss-upload-url/index.ts` | Edge Function 主逻辑 | ✏️ 可修改 |
| `lib/pages/edit_profile_page.dart` | 客户端上传逻辑 | ✏️ 可修改 |
| `lib/supabase_client.dart` | Supabase 初始化 | ✏️ 可修改 |
| `lib/main.dart` | 应用入口和全局配置 | ✏️ 可修改 |

---

## 快速参考

### 测试 Edge Function

在 **Supabase 控制台** → **Functions** → `get-oss-upload-url` → **Invoke**：

```json
{
  "filename": "test-image.jpg",
  "contentType": "image/jpeg",
  "owner_type": "user_profiles",
  "owner_id": "your-user-id"
}
```

添加 header：
```
Authorization: Bearer YOUR_JWT_TOKEN
```

**预期响应**（成功）：
```json
{
  "uploadUrl": "https://...",
  "publicUrl": "https://...",
  "objectKey": "..."
}
```

**实际响应**（失败）：
```json
{
  "error": "Invalid JWT token format",
  "code": 401
}
```

---

## 最后一招：完全重置

如果所有方案都失败：

```bash
# 1. 清理所有缓存
flutter clean
rm -rf pubspec.lock
rm -rf .dart_tool

# 2. 重新获取依赖
flutter pub get

# 3. 在 Supabase 控制台删除并重新创建 Edge Function

# 4. 重新启动应用
flutter run
```

---

**最后更新**: 2026年2月4日  
**相关文档**: [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md#edge-functions)
