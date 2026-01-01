// 配置：切换到本地演示模式或 Supabase 模式
const bool USE_LOCAL_DATA = false; // true=使用本地模拟数据，false=使用 Supabase

// 本地示例数据（仅在 USE_LOCAL_DATA = true 时使用）
List<Map<String, dynamic>> localProducts = [
  {
    'id': 'local-1',
    'title': '全新苹果耳机，音质超棒！',
    'price': 1200.0,
    'image': 'https://picsum.photos/400/300?random=1',
    'location': '未知地点',
    'selleravatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=LocalA',
    'sellername': '示例用户A',
    'description': '全新苹果耳机，音质超棒！包装完整，从来没用过。',
  },
  {
    'id': 'local-2',
    'title': '闲置笔记本电脑，性能还不错',
    'price': 2500.0,
    'image': 'https://picsum.photos/400/300?random=2',
    'location': '未知地点',
    'selleravatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=LocalB',
    'sellername': '示例用户B',
    'description': '闲置笔记本电脑，性能还不错，屏幕清晰，运行流畅。',
  },
];
