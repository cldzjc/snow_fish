import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String url;
  const VideoPlayerPage({Key? key, required this.url}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  late Future<void> _initFuture;
  bool _showControls = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🎥 初始化视频播放器: ${widget.url}');
    _controller = VideoPlayerController.network(widget.url);
    _initFuture = _controller
        .initialize()
        .then((_) {
          print('🎥 视频初始化成功');
          print('   分辨率: ${_controller.value.size}');
          print('   时长: ${_controller.value.duration}');
          print('   是否支持: ${_controller.value.isInitialized}');
          setState(() {});
        })
        .catchError((error) {
          print('❌ 视频初始化失败: $error');
          setState(() {
            _errorMessage = '视频初始化失败: $error';
          });
        });
  }

  // 必须dispose，否则会内存泄漏
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('播放视频', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              )
            : FutureBuilder(
                future: _initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return _controller.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_controller),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _showControls = !_showControls,
                                  ),
                                  child: Container(
                                    color: Colors.transparent,
                                    child: _showControls
                                        ? _buildControls()
                                        : null,
                                  ),
                                ),
                                // 播放按钮（当不显示控制栏时）
                                if (!_showControls)
                                  GestureDetector(
                                    onTap: () => _controller.value.isPlaying
                                        ? _controller.pause()
                                        : _controller.play(),
                                    child: const Icon(
                                      Icons.play_circle_fill,
                                      size: 64,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const Text(
                            '视频初始化失败',
                            style: TextStyle(color: Colors.white),
                          );
                  } else {
                    return const CircularProgressIndicator(color: Colors.white);
                  }
                },
              ),
      ),
    );
  }

  Widget _buildControls() {
    final duration = _controller.value.duration;

    // 防null和0
    if (duration == Duration.zero) {
      return const SizedBox.shrink();
    }

    final position = _controller.value.position;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 进度条
            Slider(
              value: position.inSeconds.toDouble(),
              max: duration.inSeconds.toDouble(),
              onChanged: (value) {
                _controller.seekTo(Duration(seconds: value.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  },
                ),
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
