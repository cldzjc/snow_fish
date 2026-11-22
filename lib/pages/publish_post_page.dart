import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../services/entity_service.dart';
import '../services/publish_draft_store.dart';
import '../media_service.dart';
import '../models/base_entity.dart';
import '../models/media_model.dart';
import 'login_page.dart';

class PublishPostPage extends StatefulWidget {
  final BaseEntity? initialPost;
  final String? initialEntityType;
  final String? initialActivityType;

  const PublishPostPage({
    super.key,
    this.initialPost,
    this.initialEntityType,
    this.initialActivityType,
  });

  @override
  State<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends State<PublishPostPage> {
  final _titleController = TextEditingController(); // 帖子标题（可选）
  final _contentController = TextEditingController(); // 正文内容（必填）
  List<PlatformFile> _pickedImages = []; // 选中的图片文件
  late List<MediaModel> _existingMedia;
  bool _isLoading = false;
  late final TextEditingController _regionController;
  late final TextEditingController _resortController;
  late final TextEditingController _startAtController;
  late final TextEditingController _joinDeadlineController;
  late final TextEditingController _maxParticipantsController;
  late final String _draftKey;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _regionController = TextEditingController();
    _resortController = TextEditingController();
    _startAtController = TextEditingController();
    _joinDeadlineController = TextEditingController();
    _maxParticipantsController = TextEditingController();
    final post = widget.initialPost;
    _draftKey = post?.id ?? 'new:${widget.initialEntityType ?? 'post'}';
    _existingMedia = List<MediaModel>.from(post?.media ?? const []);
    if (post != null) {
      _titleController.text = post.title == '动态' ? '' : post.title;
      _contentController.text = post.content ?? '';
      _regionController.text = post.extraData['region_id']?.toString() ?? '';
      _resortController.text = post.extraData['resort_id']?.toString() ?? '';
      _startAtController.text = post.extraData['start_at']?.toString() ?? '';
      _joinDeadlineController.text =
          post.extraData['join_deadline']?.toString() ?? '';
      _maxParticipantsController.text =
          post.extraData['max_participants']?.toString() ?? '';
    } else {
      final draft = PublishDraftStore.read(_draftKey);
      if (draft != null) {
        _titleController.text = draft['title'] ?? '';
        _contentController.text = draft['content'] ?? '';
        _regionController.text = draft['region_id'] ?? '';
        _resortController.text = draft['resort_id'] ?? '';
        _startAtController.text = draft['start_at'] ?? '';
        _joinDeadlineController.text = draft['join_deadline'] ?? '';
        _maxParticipantsController.text = draft['max_participants'] ?? '';
      }
    }
  }

  void _saveDraft() {
    if (_submitted) return;
    PublishDraftStore.save(_draftKey, {
      'title': _titleController.text,
      'content': _contentController.text,
      'region_id': _regionController.text,
      'resort_id': _resortController.text,
      'start_at': _startAtController.text,
      'join_deadline': _joinDeadlineController.text,
      'max_participants': _maxParticipantsController.text,
    });
  }

  // 检查登录状态
  bool _isLoggedIn() {
    return Supabase.instance.client.auth.currentSession != null;
  }

  // 核心功能：发布帖子
  Future<void> _publishPost() async {
    // 先检查登录状态
    if (!_isLoggedIn()) {
      // 未登录，跳转到登录页
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      // 登录成功后返回，检查是否现在已登录
      if (!_isLoggedIn()) {
        // 如果还是未登录，说明用户取消了登录
        _showSnackbar('需要登录后才能发布帖子', Colors.orange);
        return;
      }
    }

    if (_contentController.text.trim().isEmpty) {
      _showSnackbar('请输入帖子内容', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 创建或更新帖子实体（使用 EntityService）
      final currentUser = Supabase.instance.client.auth.currentUser;
      final entityService = EntityService();
      final entityType =
          widget.initialPost?.entityType ?? widget.initialEntityType ?? 'post';
      final isActivity = entityType != 'post';
      Map<String, dynamic>? extraData;
      if (isActivity) {
        if (_regionController.text.trim().isEmpty) {
          _showSnackbar('请选择或填写活动地区', Colors.orange);
          setState(() => _isLoading = false);
          return;
        }
        final maxParticipants = int.tryParse(
          _maxParticipantsController.text.trim(),
        );
        if (maxParticipants != null && maxParticipants < 1) {
          _showSnackbar('参与人数不能小于1', Colors.orange);
          setState(() => _isLoading = false);
          return;
        }
        final startAt = _startAtController.text.trim();
        final joinDeadline = _joinDeadlineController.text.trim();
        if (startAt.isNotEmpty &&
            (DateTime.tryParse(startAt) == null ||
                DateTime.tryParse(startAt)!.isBefore(DateTime.now()))) {
          _showSnackbar('活动开始时间无效或已过去', Colors.orange);
          setState(() => _isLoading = false);
          return;
        }
        if (joinDeadline.isNotEmpty &&
            (DateTime.tryParse(joinDeadline) == null ||
                DateTime.tryParse(joinDeadline)!.isBefore(DateTime.now()))) {
          _showSnackbar('报名截止时间无效或已过去', Colors.orange);
          setState(() => _isLoading = false);
          return;
        }
        if (startAt.isNotEmpty &&
            joinDeadline.isNotEmpty &&
            DateTime.tryParse(
              joinDeadline,
            )!.isAfter(DateTime.tryParse(startAt)!)) {
          _showSnackbar('报名截止时间不能晚于活动开始时间', Colors.orange);
          setState(() => _isLoading = false);
          return;
        }
        final existingExtra =
            widget.initialPost?.extraData ?? const <String, dynamic>{};
        extraData = {
          ...existingExtra,
          // 存短值 ski/photo/food/gear，与列表筛选保持一致
          'activity_type': entityType.replaceFirst('activity_', ''),
          'region_id': _regionController.text.trim(),
          if (_resortController.text.trim().isNotEmpty)
            'resort_id': _resortController.text.trim(),
          if (_startAtController.text.trim().isNotEmpty)
            'start_at': _startAtController.text.trim(),
          if (_joinDeadlineController.text.trim().isNotEmpty)
            'join_deadline': _joinDeadlineController.text.trim(),
          if (maxParticipants != null) 'max_participants': maxParticipants,
          'activity_status':
              existingExtra['activity_status']?.toString() ?? 'recruiting',
        };
      }
      final post = widget.initialPost == null
          ? await entityService.createEntity(
              entityType: entityType,
              title: _titleController.text.isEmpty
                  ? '动态'
                  : _titleController.text,
              content: _contentController.text,
              extraData: extraData ?? {},
            )
          : await entityService.updateEntity(
              entityId: widget.initialPost!.id,
              title: _titleController.text.isEmpty
                  ? '动态'
                  : _titleController.text,
              content: _contentController.text,
              extraData: extraData,
            );

      // 2. 上传图片到帖子
      if (_pickedImages.isNotEmpty) {
        final mediaService = MediaService();
        try {
          for (final imageFile in _pickedImages) {
            await mediaService.uploadMediaFile(
              file: imageFile,
              userId: currentUser!.id,
              entityId: post.id,
            );
          }
        } catch (e) {
          await entityService.deleteEntity(post.id);
          if (e is UnsupportedVideoException) {
            _showSnackbar(e.message, Colors.orange);
            return;
          }
          rethrow;
        }
      }

      // 3. 成功
      _submitted = true;
      PublishDraftStore.clear(_draftKey);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('network:')) {
        _showSnackbar('网络无法连接，发布失败，请检查网络', Colors.red);
      } else if (msg.contains('permission:')) {
        _showSnackbar('发布被拒绝（权限不足），请检查 Supabase RLS 策略', Colors.red);
      } else {
        _showSnackbar('发布失败: $e', Colors.red);
      }
      print('发布 Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 选择图片
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedImages = result.files;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialPost == null ? '发布动态' : '编辑动态',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialPost == null ? '发布动态' : '编辑动态',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 1. 图片选择
              const Text(
                '选择图片',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              if (_existingMedia.isNotEmpty)
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingMedia.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final media = _existingMedia[index];
                      return InputChip(
                        label: Text('已有媒体 ${index + 1}'),
                        onDeleted: () async {
                          try {
                            await MediaService().deleteMedia(media.id);
                            if (mounted) {
                              setState(() => _existingMedia.removeAt(index));
                            }
                          } catch (_) {
                            if (mounted) {
                              _showSnackbar('媒体删除失败，请稍后重试', Colors.red);
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _pickedImages.isNotEmpty
                    ? ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pickedImages.length,
                        itemBuilder: (context, index) {
                          final file = _pickedImages[index];
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: file.bytes != null
                                      ? Image.memory(
                                          file.bytes!,
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(file.path!),
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _pickedImages.removeAt(index);
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : InkWell(
                        onTap: _pickImages,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 32,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '点击选择图片（支持多图）',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // 2. 标题输入（可选）
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '帖子标题 (可选)',
                  border: OutlineInputBorder(),
                  hintText: '输入帖子标题...',
                ),
              ),
              const SizedBox(height: 16),

              // 3. 正文输入（必填）
              TextField(
                controller: _contentController,
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: '帖子内容 (必填)',
                  border: OutlineInputBorder(),
                  hintText: '分享你的想法...',
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.initialEntityType != null ||
                  widget.initialPost?.entityType.startsWith('activity_') ==
                      true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _regionController,
                  decoration: const InputDecoration(
                    labelText: '活动地区',
                    border: OutlineInputBorder(),
                    hintText: '省份或城市',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _resortController,
                  decoration: const InputDecoration(
                    labelText: '雪场（约滑可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _startAtController,
                  decoration: const InputDecoration(
                    labelText: '活动开始时间',
                    border: OutlineInputBorder(),
                    hintText: 'ISO 8601，例如 2026-12-01T10:00:00+08:00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _joinDeadlineController,
                  decoration: const InputDecoration(
                    labelText: '报名截止时间',
                    border: OutlineInputBorder(),
                    hintText: 'ISO 8601，可留空',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxParticipantsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '最多参与人数',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 30),

              // 发布按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _publishPost,
                  icon: _isLoading
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isLoading
                        ? '保存中...'
                        : widget.initialPost == null
                        ? '发布动态'
                        : '保存修改',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveDraft();
    _titleController.dispose();
    _contentController.dispose();
    _regionController.dispose();
    _resortController.dispose();
    _startAtController.dispose();
    _joinDeadlineController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }
}
