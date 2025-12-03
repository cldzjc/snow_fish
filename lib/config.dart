// 配置：切换到本地演示模式以避免访问 Firebase（适用于无法访问外网时）
const bool USE_LOCAL_DATA = true; // true=使用本地模拟数据，false=使用 Firebase
const bool USE_FIREBASE_EMULATOR = false; // 如果你在本机启动 emulator，可切换为 true
const String FIRESTORE_EMULATOR_HOST = '10.0.2.2';
const int FIRESTORE_EMULATOR_PORT = 8080;

// 本地示例数据（简单 Map 列表），PublishPage 会把发布内容 push 到这里以实现实时演示
List<Map<String, dynamic>> localProducts = [
  {
    'id': 'local-1',
    'title': '示例滑雪板 A',
    'price': 1200.0,
    'image': 'https://picsum.photos/seed/local1/500/500',
    'location': '北京',
    'sellerAvatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=LocalA',
    'sellerName': '示例用户A',
  },
  {
    'id': 'local-2',
    'title': '示例雪镜 B',
    'price': 200.0,
    'image': 'https://picsum.photos/seed/local2/500/500',
    'location': '上海',
    'sellerAvatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=LocalB',
    'sellerName': '示例用户B',
  },
];
