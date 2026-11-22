import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/geo.dart';
import '../media_service.dart';
import '../models/base_entity.dart';
import '../models/media_model.dart';
import '../services/entity_service.dart';
import '../services/publish_draft_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/app_icons.dart';
import 'login_page.dart';

class PublishPostPage extends StatefulWidget {
  const PublishPostPage({super.key, this.initialPost, this.initialEntityType});

  final BaseEntity? initialPost;
  final String? initialEntityType;

  @override
  State<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends State<PublishPostPage> {
  final EntityService _entityService = EntityService();
  final MediaService _mediaService = MediaService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _resortController = TextEditingController();
  final TextEditingController _startAtController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  late final String _entityType;
  late final bool _isActivity;
  late final String _draftKey;
  late List<MediaModel> _existingMedia;

  String _region = '';
  List<PlatformFile> _picked = <PlatformFile>[];
  bool _loading = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final post = widget.initialPost;
    _entityType = post?.entityType ?? widget.initialEntityType ?? 'post';
    _isActivity = _entityType != 'post';
    _draftKey = post?.id ?? 'new:$_entityType';
    _existingMedia = List<MediaModel>.from(post?.media ?? const []);

    if (post != null) {
      _titleController.text = post.title == '动态' ? '' : post.title;
      _contentController.text = post.content ?? '';
      final extra = post.extraData;
      _region = extra['region_id']?.toString() ?? '';
      _resortController.text = extra['resort_id']?.toString() ?? '';
      _startAtController.text = _prettyTime(extra['start_at']?.toString());
      _deadlineController.text = _prettyTime(
        extra['join_deadline']?.toString(),
      );
      _maxController.text = extra['max_participants']?.toString() ?? '';
    } else {
      final draft = PublishDraftStore.read(_draftKey);
      if (draft != null) {
        _titleController.text = draft['title'] ?? '';
        _contentController.text = draft['content'] ?? '';
        _region = draft['region_id'] ?? '';
        _resortController.text = draft['resort_id'] ?? '';
        _startAtController.text = draft['start_at'] ?? '';
        _deadlineController.text = draft['join_deadline'] ?? '';
        _maxController.text = draft['max_participants'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _saveDraft();
    _titleController.dispose();
    _contentController.dispose();
    _resortController.dispose();
    _startAtController.dispose();
    _deadlineController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    if (_submitted || widget.initialPost != null) return;
    PublishDraftStore.save(_draftKey, <String, String>{
      'title': _titleController.text,
      'content': _contentController.text,
      'region_id': _region,
      'resort_id': _resortController.text,
      'start_at': _startAtController.text,
      'join_deadline': _deadlineController.text,
      'max_participants': _maxController.text,
    });
  }

  bool get _isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  String get _pageTitle {
    if (widget.initialPost != null) {
      return _isActivity ? '编辑活动' : '编辑动态';
    }
    if (!_isActivity) return '发布动态';
    return switch (_entityType) {
      'activity_ski' => '发起约滑',
      'activity_photo' => '发起约拍',
      'activity_food' => '发起约饭',
      'activity_gear' => '发起约装备',
      _ => '发起活动',
    };
  }

  String _prettyTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _picked = <PlatformFile>[..._picked, ...result.files]);
  }

  Future<void> _publish() async {
    if (!_isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted) return;
      if (!_isLoggedIn) {
        _toast('需要登录后才能发布');
        return;
      }
    }

    if (_contentController.text.trim().isEmpty) {
      _toast('请填写正文');
      return;
    }

    Map<String, dynamic>? extraData;
    if (_isActivity) {
      if (_region.trim().isEmpty) {
        _toast('请选择活动地区');
        return;
      }
      final max = _maxController.text.trim();
      final maxValue = max.isEmpty ? null : int.tryParse(max);
      if (max.isNotEmpty && (maxValue == null || maxValue < 1)) {
        _toast('参与人数需要是大于 0 的整数');
        return;
      }
      final startRaw = _startAtController.text.trim();
      final deadlineRaw = _deadlineController.text.trim();
      final startAt = startRaw.isEmpty ? null : DateTime.tryParse(startRaw);
      final deadline = deadlineRaw.isEmpty
          ? null
          : DateTime.tryParse(deadlineRaw);
      if (startRaw.isNotEmpty && startAt == null) {
        _toast('开始时间格式不正确，例如 2026-12-12 09:00');
        return;
      }
      if (deadlineRaw.isNotEmpty && deadline == null) {
        _toast('报名截止格式不正确，例如 2026-12-11 18:00');
        return;
      }
      if (startAt != null && startAt.isBefore(DateTime.now())) {
        _toast('开始时间不能早于当前时间');
        return;
      }
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        _toast('报名截止不能早于当前时间');
        return;
      }
      if (startAt != null && deadline != null && deadline.isAfter(startAt)) {
        _toast('报名截止不能晚于开始时间');
        return;
      }

      final base = Map<String, dynamic>.from(
        widget.initialPost?.extraData ?? const <String, dynamic>{},
      );
      base['activity_type'] = _entityType.replaceFirst('activity_', '');
      base['region_id'] = _region.trim();
      final resort = _resortController.text.trim();
      if (resort.isEmpty) {
        base.remove('resort_id');
      } else {
        base['resort_id'] = resort;
      }
      if (startAt == null) {
        base.remove('start_at');
      } else {
        base['start_at'] = startAt.toUtc().toIso8601String();
      }
      if (deadline == null) {
        base.remove('join_deadline');
      } else {
        base['join_deadline'] = deadline.toUtc().toIso8601String();
      }
      if (maxValue == null) {
        base.remove('max_participants');
      } else {
        base['max_participants'] = maxValue;
      }
      base['activity_status'] =
          base['activity_status']?.toString() ?? 'recruiting';
      extraData = base;
    }

    setState(() => _loading = true);
    try {
      final title = _titleController.text.trim().isEmpty
          ? (_isActivity ? _pageTitle.replaceFirst('发起', '') : '动态')
          : _titleController.text.trim();

      final post = widget.initialPost == null
          ? await _entityService.createEntity(
              entityType: _entityType,
              title: title,
              content: _contentController.text.trim(),
              extraData: extraData ?? const <String, dynamic>{},
            )
          : await _entityService.updateEntity(
              entityId: widget.initialPost!.id,
              title: title,
              content: _contentController.text.trim(),
              extraData: extraData,
            );

      if (_picked.isNotEmpty) {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        try {
          for (final file in _picked) {
            await _mediaService.uploadMediaFile(
              file: file,
              userId: userId,
              entityId: post.id,
            );
          }
        } catch (e) {
          if (widget.initialPost == null) {
            await _entityService.deleteEntity(post.id);
          }
          if (e is UnsupportedVideoException) {
            _toast(e.message);
            return;
          }
          rethrow;
        }
      }

      _submitted = true;
      PublishDraftStore.clear(_draftKey);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      final message = e.toString();
      if (message.contains('network:')) {
        _toast('网络连接失败，内容未发布');
      } else if (message.contains('permission:')) {
        _toast('没有发布权限，请确认登录状态');
      } else {
        _toast('发布失败：$e');
      }
      debugPrint('发布失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeExistingMedia(MediaModel media) async {
    try {
      await _mediaService.deleteMedia(media.id);
      if (!mounted) return;
      setState(() => _existingMedia.remove(media));
    } catch (_) {
      if (mounted) _toast('媒体删除失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          AppSpace.xxxl,
        ),
        children: [
          Text(
            _isActivity ? '把时间地点说清楚，雪友就能报名。' : '分享此刻的雪上日常。',
            style: AppText.bodySmall.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpace.xl),
          _buildMediaSection(),
          if (_existingMedia.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xl),
            _buildExistingMedia(),
          ],
          const SizedBox(height: AppSpace.xl),
          AppField(
            label: '标题',
            note: '可选',
            child: AppTextField(controller: _titleController, hint: '给这一刻起个名字'),
          ),
          const SizedBox(height: AppSpace.lg),
          AppField(
            label: '正文',
            requiredMark: true,
            child: AppTextField(
              controller: _contentController,
              hint: _isActivity ? '说说这次活动的安排…' : '有什么雪上新鲜事？',
              minLines: 5,
              maxLines: 10,
            ),
          ),
          if (_isActivity) ...[
            const SizedBox(height: AppSpace.xxl),
            Divider(color: colors.line, height: 1),
            const SizedBox(height: AppSpace.xl),
            Text('活动信息', style: AppText.title.copyWith(color: colors.ink)),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '活动地区',
              requiredMark: true,
              child: AppDropdown<String>(
                options: [
                  for (final province in GeoData.provinces)
                    AppOption<String>(province, province),
                ],
                value: _region,
                hint: '请选择地区',
                onChanged: (value) => setState(() => _region = value ?? ''),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '雪场',
              note: '可选',
              child: AppTextField(
                controller: _resortController,
                hint: '例如 崇礼·万龙',
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '开始时间',
              note: '格式 2026-12-12 09:00',
              child: AppTextField(
                controller: _startAtController,
                hint: '2026-12-12 09:00',
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '报名截止',
              note: '可选，格式同上',
              child: AppTextField(
                controller: _deadlineController,
                hint: '2026-12-11 18:00',
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '最多参与人数',
              note: '不填则无上限',
              child: AppTextField(
                controller: _maxController,
                hint: '例如 10',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xxxl),
          AppButton(
            label: widget.initialPost == null ? '发布' : '保存修改',
            expand: true,
            loading: _loading,
            onPressed: _publish,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            '未发布退出不会丢失已填内容，本次会话内再次进入可继续编辑。',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('图片 / 视频', style: AppText.label.copyWith(color: colors.muted)),
            const SizedBox(width: AppSpace.sm),
            Text(
              '最多 9 个',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        if (_picked.isEmpty)
          Semantics(
            button: true,
            label: '选择图片或视频',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: _pickMedia,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.line),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.image, size: 22, color: colors.muted),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      '点击选择图片或视频',
                      style: AppText.bodySmall.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _picked.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (context, index) {
                if (index == _picked.length) {
                  return Semantics(
                    button: true,
                    label: '继续添加',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: _pickMedia,
                      child: Container(
                        width: 96,
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.line),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          AppIcons.plus,
                          size: 20,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  );
                }
                final file = _picked[index];
                return _PickedTile(
                  file: file,
                  onRemove: () => setState(() => _picked.removeAt(index)),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildExistingMedia() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已有媒体（编辑时移除会同时删除线上文件）',
          style: AppText.label.copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final media in _existingMedia)
              InputChip(
                label: Text(media.mediaType == 'video' ? '视频' : '图片'),
                labelStyle: AppText.caption.copyWith(color: colors.ink),
                backgroundColor: colors.soft,
                side: BorderSide(color: colors.line),
                onDeleted: () => _removeExistingMedia(media),
                deleteIcon: Icon(AppIcons.close, size: 16, color: colors.muted),
              ),
          ],
        ),
      ],
    );
  }
}

class _PickedTile extends StatelessWidget {
  const _PickedTile({required this.file, required this.onRemove});

  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isImage =
        !(file.name.toLowerCase().endsWith('.mp4') ||
            file.name.toLowerCase().endsWith('.mov'));
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            width: 96,
            height: 96,
            child: isImage && file.bytes != null
                ? Image.memory(file.bytes!, fit: BoxFit.cover)
                : Container(
                    color: colors.soft,
                    alignment: Alignment.center,
                    child: Icon(
                      isImage ? AppIcons.image : AppIcons.video,
                      size: 22,
                      color: colors.muted,
                    ),
                  ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Semantics(
            button: true,
            label: '移除所选媒体',
            child: InkWell(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppRadius.md),
                    bottomLeft: Radius.circular(AppRadius.md),
                  ),
                ),
                child: const Icon(
                  AppIcons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
