# Snow Fish - 二手交易平台

一个基于 Flutter + Supabase 构建的现代化二手交易应用。

## 🎯 项目特性

- ✨ **通用实体架构**: 灵活支持多种内容类型（商品、帖子、服务等）
- 🌍 **Supabase 东京节点**: 优化的数据库服务，支持实时功能
- 📱 **跨平台支持**: iOS、Android、Web、macOS、Windows、Linux
- 🖼️ **媒体管理**: 优化的图片/视频上传和缓存
- 👤 **用户系统**: 完整的身份认证和资料管理
- 💬 **互动功能**: 评论、点赞、分享等社交功能

## 📋 最近更新（2026年2月）

### 架构升级 v2.0.0
- ✅ 迁移至通用实体架构
- ✅ 升级到 Supabase 东京节点
- ✅ 完整重构数据模型
- ✅ 改进个人资料页面 UI

**详见**: [PROJECT_COMPLETION_REPORT.md](PROJECT_COMPLETION_REPORT.md)

## 🚀 快速开始

### 前置要求
- Flutter 3.0+
- Dart 2.17+
- iOS 11.0+ / Android 5.0+

### 安装

```bash
# 克隆项目
git clone <repo-url>
cd snow_fish

# 获取依赖
flutter pub get

# 运行应用
flutter run
```

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口
├── supabase_client.dart         # Supabase 配置
├── media_service.dart           # 媒体服务
├── post_service.dart            # 帖子服务
├── product_service.dart         # 商品服务
├── models/                      # 数据模型
│   ├── base_entity.dart         # 通用实体（商品、帖子等）
│   ├── media_model.dart         # 媒体模型
│   ├── user_profile.dart        # 用户资料模型
│   └── index.dart               # 模型导出
├── pages/                       # UI 页面
│   ├── login_page.dart
│   ├── register_page.dart
│   ├── profile_page.dart
│   ├── edit_profile_page.dart
│   ├── home_page.dart
│   └── ...
└── ...
```

## 📚 文档

### 核心文档
- [PROJECT_COMPLETION_REPORT.md](PROJECT_COMPLETION_REPORT.md) - 完成报告和总结
- [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md) - 重构详情和 Schema 说明
- [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) - 开发指南和代码示例
- [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md) - 验证清单和故障排除

## 🏗️ 数据模型

### BaseEntity - 通用实体
用于表示任何内容（商品、帖子等）：

```dart
final product = BaseEntity(
  id: 'uuid',
  userId: 'user-uuid',
  entityType: 'product',
  title: '商品标题',
  content: '商品描述',
  extraData: {
    'price': 1999,
    'location': '北京',
  },
  media: [...],  // 关联媒体
);

// 快速访问扩展字段
print('¥${product.price}');
print(product.location);
```

### 数据库表
- `entities` - 通用实体表
- `media` - 媒体表
- `user_profiles` - 用户资料表
- `comments` - 评论表
- `interactions` - 互动表

详见 [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)

## 🔧 配置

### Supabase
编辑 `lib/supabase_client.dart` 配置：
```dart
const String supabaseUrl = 'https://tjnrilfjbvwyfwjhwmay.supabase.co';
const String supabaseAnonKey = 'your-anon-key';
```

### 依赖包
```yaml
flutter:
  flutter_web_plugins:
    ffibrosa: ^4.0.0

dependencies:
  supabase_flutter: ^1.0.0
  cached_network_image: ^3.2.0
  file_picker: ^4.6.0
  dio: ^5.0.0
  video_player: ^2.4.0
  # ... 其他包
```

## 🧪 测试

```bash
# 运行所有测试
flutter test

# 覆盖率测试
flutter test --coverage
```

## 📊 API 使用示例

### 查询商品
```dart
final response = await Supabase.instance.client
    .from('entities')
    .select('*, media(*)')
    .eq('entity_type', 'product')
    .order('created_at', ascending: false);

final products = response.map((p) => BaseEntity.fromJson(p)).toList();
```

### 上传头像
见 [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) 的"用户资料操作"部分

## 🐛 故障排除

### Supabase 连接失败
- 检查 URL 和 Key 是否正确
- 验证网络连接
- 查看 Supabase 控制台状态

### 图片不显示
- 检查 URL 是否可访问
- 验证 `user_profiles.avatar_url` 和 `background_url` 字段
- 查看控制台日志

详见 [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)

## 📦 部署

### 构建 APK（Android）
```bash
flutter build apk --release
```

### 构建 IPA（iOS）
```bash
flutter build ios --release
```

### 构建 Web
```bash
flutter build web --release
```

## 🤝 贡献

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开设 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 LICENSE 文件

## 📞 联系方式

- 问题和讨论: GitHub Issues
- 功能建议: GitHub Discussions

---

**版本**: 2.0.0 (2026年2月)  
**架构**: 通用实体架构  
**数据库**: Supabase (Tokyo Region)  
**状态**: ✅ 生产就绪
