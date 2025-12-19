// 配置：切换到本地演示模式或 Supabase 模式
const bool USE_LOCAL_DATA = false; // true=使用本地模拟数据，false=使用 Supabase

// 本地示例数据（仅在 USE_LOCAL_DATA = true 时使用）
List<Map<String, dynamic>> localProducts = [
  {
    'id': 'local-1',
    'title': '示例滑雪板 A',
    'price': 1200.0,
    'image': 'https://picsum.photos/seed/local1/500/500',
    'location': '北京',
    'selleravatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=LocalA',
    'sellername': '示例用户A',
    // 新增字段
    'category': '运动户外',
    'condition': '九成新',
    'description': '专业滑雪板，使用半年，保存完好',
    'brand': 'Burton',
    'size': '160cm',
    'usage_time': '使用半年',
    'transaction_methods': '当面交易',
    'negotiable': true,
  },
  {
    'id': 'local-2',
    'title': '示例雪镜 B',
    'price': 200.0,
    'image': 'https://picsum.photos/seed/local2/500/500',
    'location': '上海',
    'selleravatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=LocalB',
    'sellername': '示例用户B',
    // 新增字段
    'category': '运动户外',
    'condition': '全新',
    'description': '全新雪镜，未开封，支持防雾功能',
    'brand': 'Oakley',
    'size': 'M',
    'usage_time': '全新未使用',
    'transaction_methods': '当面交易,邮寄',
    'negotiable': false,
  },
];
