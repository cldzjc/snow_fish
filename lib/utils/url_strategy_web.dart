import 'package:flutter_web_plugins/url_strategy.dart';

/// Web：使用真实路径（/p/<id>），分享出去的链接不带 `#`。
void configureUrlStrategy() {
  usePathUrlStrategy();
}
