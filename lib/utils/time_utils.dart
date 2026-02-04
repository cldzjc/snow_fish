/// 时间格式化工具
class TimeUtils {
  /// 将 DateTime 转换为相对时间字符串
  /// 例如: "5小时前", "23分钟前", "2天前"
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // 处理未来时间
    if (difference.isNegative) {
      return '刚刚';
    }

    final seconds = difference.inSeconds;
    final minutes = difference.inMinutes;
    final hours = difference.inHours;
    final days = difference.inDays;
    final weeks = (days / 7).floor();
    final months = (days / 30).floor();
    final years = (days / 365).floor();

    if (seconds < 60) {
      return '刚刚';
    } else if (minutes < 60) {
      return '$minutes分钟前';
    } else if (hours < 24) {
      return '$hours小时前';
    } else if (days < 7) {
      return '$days天前';
    } else if (weeks < 4) {
      return '$weeks周前';
    } else if (months < 12) {
      return '$months个月前';
    } else {
      return '$years年前';
    }
  }

  /// 格式化时间为 "HH:mm" 格式（当天显示时间，往前显示日期+时间）
  static String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday =
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.month}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 完整日期时间格式 "yyyy-MM-dd HH:mm:ss"
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
