import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 把任意异常翻译成能直接给用户看的一句话。
///
/// 后端抛出来的 PostgrestException / 网络异常 / 校验异常都不该原样展示，
/// 这里统一收口：能识别的给出具体原因，认不出来的给一句通用提示，
/// 原始信息只写到日志里。
String friendlyError(Object? error, {String fallback = '出了点问题，请稍后再试'}) {
  if (error == null) return fallback;

  // 数据库里主动 raise 的中文提示，本来就是要给用户看的。
  final raw = _messageOf(error);
  if (raw.isNotEmpty && _isFriendlyMessage(raw)) return raw;

  final text = error.toString();

  if (error is PostgrestException) {
    if (error.code == '42501' ||
        text.contains('row-level security') ||
        text.contains('permission denied')) {
      return '没有权限做这个操作';
    }
    if (error.code == '23505' || text.contains('duplicate key')) {
      return '已经操作过了，不用重复提交';
    }
    if (error.code == '23503' || text.contains('violates foreign key')) {
      return '相关内容已经被删除了';
    }
    if (error.code == 'PGRST116') return '内容不存在或已被删除';
    return fallback;
  }

  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('XMLHttpRequest') ||
      text.contains('TimeoutException') ||
      text.contains('timed out') ||
      text.contains('network:')) {
    return '网络不太好，检查一下网络再试';
  }

  if (text.contains('JWT') || text.contains('not authenticated')) {
    return '登录状态已失效，请重新登录';
  }

  debugPrint('未翻译的异常: $error');
  return fallback;
}

/// 弹一条错误提示，文案已经过 [friendlyError] 处理。
void showErrorToast(
  BuildContext context,
  Object? error, {
  String? action,
  String fallback = '出了点问题，请稍后再试',
}) {
  final message = friendlyError(error, fallback: fallback);
  final text = action == null ? message : '$action：$message';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String _messageOf(Object error) {
  if (error is PostgrestException) return error.message.trim();
  if (error is StateError) return error.message.trim();
  if (error is FormatException) return error.message.trim();
  // 自己 throw Exception('中文提示') 的情况
  final text = error.toString().trim();
  for (final prefix in const <String>['Exception: ', 'Error: ']) {
    if (text.startsWith(prefix)) return text.substring(prefix.length).trim();
  }
  return '';
}

/// 已经是中文人话的提示（数据库 raise / 自己 throw 的），直接放行。
bool _isFriendlyMessage(String message) {
  if (message.isEmpty) return false;
  final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(message);
  if (!hasChinese) return false;
  // 带这些字样的说明是技术细节，不直接展示。
  const techy = <String>[
    'PostgrestException',
    'Exception',
    'error',
    'null',
    'String',
    'code:',
    'details:',
  ];
  for (final word in techy) {
    if (message.contains(word)) return false;
  }
  return message.length <= 60;
}
