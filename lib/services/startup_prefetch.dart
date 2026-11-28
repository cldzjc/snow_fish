import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/base_entity.dart';
import '../theme/app_spacing.dart';
import '../utils/media_url.dart';
import 'circle_repository.dart';
import 'entity_service.dart';
import 'feed_cache.dart';
import 'my_profile_store.dart';
import 'profile_cache.dart';

/// 开屏动画期间把首屏要用的数据先拉回来。
///
/// 首页列表、约约约、圈信息流和作者头像都在这里预热；
/// 任何一个请求失败都只影响它自己，不会拖住启动。
class StartupPrefetch {
  StartupPrefetch._();

  static Future<void>? _task;

  static Future<void> start() => _task ??= _run();

  static Future<void> _run() async {
    final home = _guard(
      FeedCache.load<List<BaseEntity>>(
        FeedCache.homeKey,
        () => EntityService().fetchSkCommunity(limit: 20),
      ),
      const <BaseEntity>[],
    );

    unawaited(
      _guard(
        FeedCache.load<List<BaseEntity>>(
          FeedCache.activitiesKey(),
          () => EntityService().fetchActivities(),
        ),
        const <BaseEntity>[],
      ),
    );

    // 圈信息流要等资料回来才知道看的是哪个圈。
    final circleFeed = () async {
      await _guardVoid(MyProfileStore.load());
      final membership = MyProfileStore.circle;
      if (membership == null) return;
      final scope = CircleRepository.instance.scopeIds(membership.district);
      await _guard(
        FeedCache.load<List<BaseEntity>>(
          FeedCache.circleKey(scope),
          () => EntityService().fetchCirclePosts(circleIds: scope),
        ),
        const <BaseEntity>[],
      );
    }();

    final posts = await home;
    // 作者资料 + 头像先拿好，卡片一出现就是完整状态。
    await _guard(ProfileCache.ensure(posts.map((post) => post.userId)), false);
    _prewarmAvatars(posts);

    await circleFeed;
  }

  static Future<T> _guard<T>(Future<T> future, T fallback) async {
    try {
      return await future;
    } catch (error) {
      debugPrint('开屏预取失败: $error');
      return fallback;
    }
  }

  static Future<void> _guardVoid(Future<void> future) async {
    try {
      await future;
    } catch (error) {
      debugPrint('开屏预取失败: $error');
    }
  }

  /// 把卡片头的头像提前下载进图片缓存，避免首屏一个个闪出来。
  static void _prewarmAvatars(Iterable<BaseEntity> posts) {
    final urls = <String>{};
    for (final post in posts.take(12)) {
      final raw = ProfileCache.get(post.userId)?['avatar_url'] as String?;
      final url = raw?.trim() ?? '';
      // SVG 头像 Flutter 解码不了，卡片里本来也会退化成占位图标。
      if (url.isEmpty || url.toLowerCase().contains('.svg')) continue;
      urls.add(avatarThumb(url, AppSize.avatar));
    }
    for (final url in urls) {
      _preload(url);
    }
  }

  static void _preload(String url) {
    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void done() => stream.removeListener(listener);
    listener = ImageStreamListener((_, _) => done(), onError: (_, _) => done());
    stream.addListener(listener);
  }
}
