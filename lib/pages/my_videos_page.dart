import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:snow_fish/pages/video_player_page.dart';

class MyVideosPage extends StatefulWidget {
  const MyVideosPage({Key? key}) : super(key: key);

  @override
  State<MyVideosPage> createState() => _MyVideosPageState();
}

class _MyVideosPageState extends State<MyVideosPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);

    final res = await _client
        .from('media')
        .select()
        .eq('owner_type', 'user_video')
        .eq('owner_id', user.id)
        .order('sort_order', ascending: true);

    if (res is List) {
      setState(() {
        _videos = List<Map<String, dynamic>>.from(
          res.cast<Map<String, dynamic>>(),
        );
        _loading = false;
      });
      return;
    }

    setState(() {
      _videos = [];
      _loading = false;
    });
  }

  Future<Map<String, dynamic>> _getUploadInfo(
    String filename,
    String contentType,
  ) async {
    final body = jsonEncode({
      'filename': filename,
      'contentType': contentType,
      'field': 'video',
      'owner_type': 'user_video',
      'owner_id': Supabase.instance.client.auth.currentUser!.id,
    });

    final resp = await Supabase.instance.client.functions.invoke(
      'get-oss-upload-url',
      body: body,
    );
    final data = resp.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Edge function returned no data');
    return data;
  }

  Future<void> _uploadFileBytes(
    Uint8List bytes,
    String uploadUrl,
    String contentType,
    String label,
  ) async {
    final dio = Dio();
    final headers = {
      'content-type': contentType,
      'content-length': bytes.length.toString(),
    };

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 上传中...'),
          duration: const Duration(hours: 1),
        ),
      );

      final stream = Stream.fromIterable([bytes]);
      await dio.put(
        uploadUrl,
        data: stream,
        options: Options(headers: headers),
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 上传完成'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      throw Exception('Upload failed: $e');
    }
  }

  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return await File(file.path!).readAsBytes();
    throw Exception('File bytes unavailable for ${file.name}');
  }

  Future<void> _pickAndUpload() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
    final info = await _getUploadInfo(p.basename(file.name), mimeType);
    final uploadUrl = info['uploadUrl'] ?? info['upload_url'];
    final publicUrl = info['publicUrl'] ?? info['public_url'];

    final bytes = await _readFileBytes(file);
    await _uploadFileBytes(bytes, uploadUrl, mimeType, '视频');

    // generate thumbnail (client-side) using video_thumbnail
    String? thumbUrl;
    if (file.path != null) {
      try {
        // import deferred to avoid heavy imports
        final thumbData = await VideoThumbnail.thumbnailData(
          video: file.path!,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
          maxWidth: 320,
        );
        if (thumbData != null) {
          // upload thumbnail
          final thumbInfo = await _getUploadInfo(
            '${DateTime.now().millisecondsSinceEpoch}_thumb.jpg',
            'image/jpeg',
          );
          final thumbUploadUrl =
              thumbInfo['uploadUrl'] ?? thumbInfo['upload_url'];
          final thumbPublicUrl =
              thumbInfo['publicUrl'] ?? thumbInfo['public_url'];
          await _uploadFileBytes(
            thumbData,
            thumbUploadUrl,
            'image/jpeg',
            '缩略图',
          );
          thumbUrl = thumbPublicUrl;
        }
      } catch (e) {
        debugPrint('缩略图生成失败: $e');
      }
    }

    // insert into media table with next sort_order
    final currentMaxOrder = _videos.isEmpty
        ? 0
        : (_videos
              .map((v) => v['sort_order'] as int? ?? 0)
              .reduce((a, b) => a > b ? a : b));
    final newOrder = currentMaxOrder + 1;

    final insertMap = {
      'user_id': user.id,
      'url': publicUrl,
      'media_type': 'video',
      'owner_type': 'user_video',
      'owner_id': user.id,
      'sort_order': newOrder,
    };
    if (thumbUrl != null) insertMap['thumbnail_url'] = thumbUrl;

    await _client.from('media').insert(insertMap).select();

    // refresh list
    await _fetchVideos();
  }

  Future<void> _deleteVideo(String id) async {
    try {
      // attempt to fetch media row to get public URL
      final res = await _client
          .from('media')
          .select()
          .eq('id', id)
          .maybeSingle();
      final row = res as Map<String, dynamic>?;
      String? publicUrl = row != null ? (row['url'] as String?) : null;

      if (publicUrl != null && publicUrl.isNotEmpty) {
        try {
          await _client.functions.invoke(
            'delete-oss-object',
            body: jsonEncode({'publicUrl': publicUrl}),
          );
        } catch (e) {
          // If delete function is not available or fails, ask user whether to continue deleting the DB row
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('无法删除远程文件'),
              content: Text('删除远程文件失败：$e\n是否仍然从数据库中删除该记录？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('继续删除'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      }

      await _client.from('media').delete().eq('id', id).select();
      await _fetchVideos();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除成功')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateOrder() async {
    // Persist current _videos order by setting sort_order according to index
    for (var i = 0; i < _videos.length; i++) {
      final v = _videos[i];
      final id = v['id'];
      final order = i + 1;
      await _client
          .from('media')
          .update({'sort_order': order})
          .eq('id', id)
          .select();
    }
    await _fetchVideos();
  }

  Future<void> _testDeleteFunction() async {
    try {
      debugPrint('【测试】开始调用 delete-oss-object 函数...');

      final resp = await _client.functions.invoke(
        'delete-oss-object',
        body: jsonEncode({
          'publicUrl':
              'https://snow-fish-media.oss-cn-hongkong.aliyuncs.com/users/ab1b9fdc-bda6-4032-b360-95a53d02d979/files/1768307379142.jpg',
          'dryRun': true,
        }),
      );

      debugPrint('【测试】函数返回状态码: ${resp.status}');
      debugPrint('【测试】函数返回数据: ${resp.data}');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('函数调用成功！返回: ${resp.data}')));
      }
    } catch (e) {
      debugPrint('【测试】函数调用失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('函数调用失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的视频')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pickAndUpload,
                        child: const Text('上传视频'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _testDeleteFunction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                        child: const Text('【测试】删除函数'),
                      ),
                      const SizedBox(width: 12),
                      Text('已上传 ${_videos.length}'),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _videos.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _videos.removeAt(oldIndex);
                      _videos.insert(newIndex, item);
                      setState(() {});
                      await _updateOrder();
                    },
                    itemBuilder: (context, index) {
                      final v = _videos[index];
                      final url = v['url'] as String? ?? '';
                      final thumb = v['thumbnail_url'] as String? ?? '';
                      final displayUrl = thumb.isNotEmpty ? thumb : url;
                      final id = v['id'] as String?;
                      return ListTile(
                        key: ValueKey(id),
                        leading: displayUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: displayUrl,
                                width: 96,
                                height: 54,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 96,
                                  height: 54,
                                  color: Colors.grey[200],
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 96,
                                  height: 54,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.videocam),
                                ),
                              )
                            : Container(
                                width: 96,
                                height: 54,
                                color: Colors.grey[200],
                              ),
                        title: Text(p.basename(url)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: id == null ? null : () => _deleteVideo(id),
                        ),
                        onTap: () {
                          if (url.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerPage(url: url),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
