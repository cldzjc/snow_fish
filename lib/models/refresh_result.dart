/// 一次下拉刷新的结果。
class RefreshResult {
  const RefreshResult({this.newCount = 0, this.total = 0, this.failed = false});

  /// 相比刷新前新增的条数（顶部新增）。
  final int newCount;

  /// 刷新后列表里的总条数。
  final int total;

  final bool failed;

  static const RefreshResult failure = RefreshResult(failed: true);

  /// 提示文案。
  String message({required String unit}) {
    if (failed) return '刷新失败，请稍后重试';
    if (newCount <= 0) return '暂时没有新内容';
    return '已刷新 $newCount $unit';
  }
}
