# 🔍 Edge Function JWT 解析失败 - 完整诊断

## 问题
```
Failed to parse JWT: Failed to decode base64
```

这通常表示 JWT payload 的 base64 编码有问题。

---

## 可能的根本原因

### 1️⃣ **Supabase Project 配置不正确**

检查你的 Supabase 项目设置：

1. 打开 Supabase 控制台
2. 进入 **Settings** → **General**
3. 确认你看到：
   - ✅ Project ID
   - ✅ API URL
   - ✅ Anon Key / Service Role Key

4. 回到 **Auth** 设置
5. 检查 **JWT Settings**：
   - JWT Secret 是否配置？
   - Token Expiry 是否合理？

### 2️⃣ **Flutter 中的 Supabase 初始化**

检查 `lib/supabase_client.dart` 或 `lib/main.dart`：

```dart
await Supabase.initialize(
  url: 'https://YOUR_PROJECT_ID.supabase.co',  // ✓ 必须与 console 中的 URL 一致
  anonKey: 'YOUR_ANON_KEY',                     // ✓ 必须与 console 中的密钥一致
  authFlowType: AuthFlowType.pkce,
);
```

**关键检查**：
- URL 和 anonKey 是否与 Supabase 控制台完全相同？
- 是否有多余的空格或换行符？

### 3️⃣ **浏览器/模拟器缓存问题**

有时候旧的认证信息会导致 token 格式错误：

```bash
# 清理 Flutter 缓存
flutter clean

# 清理依赖
rm -rf pubspec.lock
flutter pub get

# 重新运行
flutter run
```

---

## 🧪 快速验证步骤

### Step 1: 在 Flutter 应用中打印 token

编辑 `lib/pages/edit_profile_page.dart`，在 `_getUploadInfo()` 中：

```dart
// 添加这几行来打印完整 token
final accessToken = session.accessToken;
debugPrint('🔍 Full token: $accessToken');
debugPrint('🔍 Token parts: ${accessToken.split('.').map((p) => p.length).toList()}');
```

运行应用并记下 token 的 3 部分长度。应该看起来像：
```
Token parts: [header长度, payload长度, signature长度]
```

### Step 2: 检查 Edge Function 的新日志

部署后，重新上传并查看 Supabase Logs。

**如果看到**：
```
🔧 Token parts: header length=..., payload length=..., signature length=...
```

说明至少 token 被正确识别了。

**如果看到**：
```
📄 JWT Payload keys: [所有字段名]
```

说明 base64 解码成功了！现在应该能找到用户 ID。

---

## 🚀 完整修复步骤（按顺序）

### Step 1: 部署改进的函数

```bash
cd e:\flutter_projects\snow_fish
supabase functions deploy get-oss-upload-url
```

等待看到：
```
✓ Function deployed: get-oss-upload-url
```

### Step 2: 在 Supabase 控制台验证环境变量

Functions → `get-oss-upload-url` → Settings

确保这 4 个变量存在：
```
☐ OSS_ACCESS_KEY_ID       (必须有值)
☐ OSS_ACCESS_KEY_SECRET   (必须有值)
☐ OSS_BUCKET              (必须有值)
☐ OSS_REGION              (必须有值)
```

### Step 3: Flutter 中完全清理

```bash
flutter clean
rm pubspec.lock
flutter pub get
flutter run -v
```

### Step 4: 在应用中测试

1. 登录应用
2. 进入 Edit Profile
3. 选择头像上传
4. 等待 1-2 秒
5. **立即打开 Supabase 控制台查看 Logs**

### Step 5: 分析新的日志输出

根据新日志，告诉我看到的信息。特别是：
- 是否看到 `🔧 Token parts:`？
- 是否看到 `📄 JWT Payload keys:`？
- payload 中有哪些字段？

---

## 📋 最可能的修复

如果你已经：
- ✅ 关闭了 "Verify JWT with legacy secret"
- ✅ 部署了改进的函数
- ✅ 配置了 OSS 环境变量
- ✅ 清理了缓存

那么问题最可能是 **Supabase 配置不一致**。

检查这两个地方是否完全相同：
1. **Supabase 控制台** → Settings → General → API URL 和 Anon Key
2. **Flutter 应用** → `lib/main.dart` 或 `lib/supabase_client.dart` 中的 URL 和 Key

---

## 🆘 如果仍然失败

收集以下信息：

1. **Supabase 控制台的完整 Logs 输出**（最后 50 行）
2. **Flutter 应用的完整调试日志**（flutter run -v 的输出）
3. **Supabase 项目 ID**（可以隐藏部分）
4. **Edge Function Code** 的当前状态

---

**最后更新**: 2026年2月4日
