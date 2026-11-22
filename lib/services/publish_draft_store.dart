/// 发布草稿（会话级）。
///
/// 仅在当前运行期间保留：未发布就退出发布页时保存，
/// 再次进入同一发布入口时自动恢复，发布成功后清除。
class PublishDraftStore {
  static final Map<String, Map<String, String>> _drafts = {};

  static Map<String, String>? read(String key) {
    final draft = _drafts[key];
    if (draft == null || draft.isEmpty) return null;
    return Map<String, String>.from(draft);
  }

  static void save(String key, Map<String, String> fields) {
    final hasContent = fields.values.any((value) => value.trim().isNotEmpty);
    if (!hasContent) {
      _drafts.remove(key);
      return;
    }
    _drafts[key] = fields;
  }

  static void clear(String key) {
    _drafts.remove(key);
  }
}
