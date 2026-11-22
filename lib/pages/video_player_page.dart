import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_typography.dart';
import '../widgets/app/app_icons.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.url});

  final String url;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initFuture = _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          _controller.play();
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(() => _error = error.toString());
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleTextStyle: AppText.pageTitle.copyWith(color: Colors.white),
        title: const Text('播放视频'),
        leading: IconButton(
          tooltip: '关闭',
          icon: const Icon(AppIcons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (_error != null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.alert, color: Colors.white70, size: 34),
                    const SizedBox(height: 16),
                    Text(
                      '视频暂时无法播放',
                      style: AppText.title.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '可能是网络或编码格式问题，可以换一个网络再试。',
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done ||
                !_controller.value.isInitialized) {
              return const CircularProgressIndicator(color: Colors.white);
            }
            final value = _controller.value;
            return GestureDetector(
              onTap: _togglePlay,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: value.aspectRatio == 0
                        ? 16 / 9
                        : value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                  if (!value.isPlaying)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.play,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _error == null
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
