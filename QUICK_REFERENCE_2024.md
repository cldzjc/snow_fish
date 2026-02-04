# 🎯 Snow Fish 项目速查表

> 快速查看关键信息，详细内容见 [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md)

---

## 📌 项目基本信息

```
名称: Snow Fish (雪鱼)
类型: 二手交易 + 社区平台
框架: Flutter 3.10+ / Dart 3.10+
后端: Supabase (东京)
存储: 阿里云 OSS
版本: v1.0.0+1
```

---

## 🏗️ 核心表结构

```
entities          ← 商品、帖子等主数据
  ├── id (uuid)
  ├── user_id (uuid)
  ├── entity_type ('product'|'post'|'service')
  ├── title (varchar)
  ├── content (text)
  ├── extra_data (jsonb: price, location, ...)
  └── media[] ← 关联媒体

media            ← 图片、视频
  ├── entity_id
  ├── url
  ├── media_type ('image'|'video')
  └── display_order

user_profiles    ← 用户资料
  ├── nickname
  ├── bio
  ├── avatar_url
  └── background_url
```

---

## 🔑 核心 API

### EntityService
```dart
// 获取列表
await EntityService().fetchEntities(type: 'product', limit: 20);

// 获取用户数据
await EntityService().fetchUserEntities(userId: uid, type: 'product');

// 获取详情
await EntityService().fetchEntity(entityId);

// 创建
await EntityService().createEntity(
  entityType: 'product',
  title: '标题',
  extraData: {'price': 1999, 'location': '北京'},
);

// 更新
await EntityService().updateEntity(entityId: id, title: '新标题');

// 删除
await EntityService().deleteEntity(entityId);
```

### MediaService
```dart
// 上传
await MediaService().uploadMedia(
  userId: uid,
  entityId: eid,
  fileType: FileType.image,
);

// 获取
await MediaService().getMediaByEntity(entityId);

// 删除
await MediaService().deleteMedia(mediaId);
```

---

## 📂 关键文件位置

| 功能 | 文件 |
|------|------|
| 数据模型 | `lib/models/base_entity.dart` |
| 统一服务 | `lib/services/entity_service.dart` |
| 媒体服务 | `lib/media_service.dart` |
| 首页 | `lib/pages/home_page.dart` |
| 发布商品 | `lib/pages/publish_page.dart` |
| 发布帖子 | `lib/pages/publish_post_page.dart` |
| 个人资料 | `lib/pages/profile_page.dart` |
| Edge Function | `functions/get-oss-upload-url/index.ts` |

---

## 🚀 常用命令

```bash
# 开发
flutter run

# 分析
flutter analyze

# 测试
flutter test

# 构建 APK
flutter build apk --release

# 部署 Edge Function
supabase functions deploy get-oss-upload-url

# 查看日志
supabase functions logs get-oss-upload-url --tail
```

---

## 🔑 环境变量

### Supabase (lib/supabase_client.dart)
```dart
const String supabaseUrl = 'https://...supabase.co';
const String supabaseAnonKey = 'eyJ...';
```

### Edge Function (Supabase Dashboard)
```
OSS_ACCESS_KEY_ID=xxx
OSS_ACCESS_KEY_SECRET=xxx
OSS_BUCKET=bucket-name
OSS_REGION=oss-cn-beijing
```

---

## 📊 数据流示例

### 发布商品流程
```
输入信息 → 创建实体 → 上传媒体 → 保存记录 → 发布成功
  ↓          ↓          ↓          ↓
标题、    EntityService  MediaService  数据库
价格等    创建entity     调用Edge Fn  保存URL
```

### 查看商品流程
```
用户操作 → 加载数据 → 展示页面
   ↓         ↓         ↓
点击→   EntityService  ProductDetailPage
      fetchEntity()    显示信息和媒体
```

---

## 🎨 页面导航树

```
首页 (HomeTabs)
├── 广场/交易 (HomePage) 
│   ├── 双 Tab 切换
│   └── 发布按钮
├── 发布 (PublishPage/PublishPostPage)
├── 消息 (ChatPage) [占位]
└── 我的 (ProfilePage)
    ├── 编辑资料 (EditProfilePage)
    ├── 我的商品 (MyProductsPage)
    └── 我的视频 (MyVideosPage)

认证
├── 登录 (LoginPage)
└── 注册 (RegisterPage)
```

---

## 🔧 常见操作代码片段

### 获取当前用户
```dart
final user = Supabase.instance.client.auth.currentUser;
final userId = user?.id;
```

### 获取用户的商品
```dart
final products = await EntityService().fetchUserEntities(
  userId: userId,
  type: 'product',
);
```

### 查询商品详情与媒体
```dart
final entity = await EntityService().fetchEntity(entityId);
final media = entity.media;  // 已包含在实体中
```

### 创建新商品
```dart
final entity = await EntityService().createEntity(
  entityType: 'product',
  title: _titleController.text,
  content: _contentController.text,
  extraData: {
    'price': double.parse(_priceController.text),
    'location': '北京',
  },
);
```

### 访问扩展字段
```dart
print('价格: ¥${entity.price}');
print('位置: ${entity.location}');
```

---

## ⚠️ 常见问题

| 问题 | 解决方案 |
|------|---------|
| 登录失败 | 检查 Supabase URL 和 Key |
| 无法上传 | 检查 OSS 环境变量和 JWT token |
| 图片不显示 | 验证 OSS URL 是否可访问 |
| API 超时 | 检查网络和 Supabase 状态 |
| 401 错误 | 重新登录刷新 token |

---

## 📈 性能优化

1. **图片**: 上传前自动压缩
2. **列表**: 使用分页和虚拟滚动
3. **缓存**: CachedNetworkImage 自动缓存
4. **数据库**: 建立适当的索引

---

## 🚀 部署检查清单

- [ ] 环境变量已配置
- [ ] Edge Function 已部署
- [ ] 数据库表已创建
- [ ] RLS 策略已启用
- [ ] OSS Bucket 已创建
- [ ] CORS 已配置
- [ ] 测试流程是否正常

---

## 📚 详细文档位置

- **完整指南**: [PROJECT_COMPLETE_GUIDE.md](PROJECT_COMPLETE_GUIDE.md)
- **文档导航**: [DOCUMENTATION_GUIDE.md](DOCUMENTATION_GUIDE.md)
- **项目简介**: [README.md](README.md)

---

**上次更新**: 2026年2月4日  
**有问题?** 查看 PROJECT_COMPLETE_GUIDE.md 的"问题排查"章节
