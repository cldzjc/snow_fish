import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/geo.dart';
import '../media_service.dart';
import '../models/base_entity.dart';
import '../models/circle.dart';
import '../models/media_model.dart';
import '../services/contact_service.dart';
import '../services/entity_service.dart';
import '../services/circle_repository.dart';
import '../services/my_profile_store.dart';
import '../services/publish_draft_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app/activity_form_sheets.dart';
import '../widgets/app/app_avatar.dart';
import '../widgets/app/app_button.dart';
import '../widgets/app/app_field.dart';
import '../widgets/app/app_icons.dart';
import '../widgets/app/geo_picker_sheet.dart';
import 'login_page.dart';

class PublishPostPage extends StatefulWidget {
  const PublishPostPage({
    super.key,
    this.initialPost,
    this.initialEntityType,
    this.circle,
  });

  final BaseEntity? initialPost;
  final String? initialEntityType;

  /// 发到哪个圈；null 表示发到 sk社区。
  final Circle? circle;

  @override
  State<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends State<PublishPostPage> {
  final EntityService _entityService = EntityService();
  final MediaService _mediaService = MediaService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  late final String _entityType;
  late final bool _isActivity;
  late final String _draftKey;
  late List<MediaModel> _existingMedia;

  String _region = '';
  String _resort = '';
  DateTime? _startAt;
  List<PlatformFile> _picked = <PlatformFile>[];
  bool _loading = false;
  bool _submitted = false;
  Map<String, dynamic>? _profile;

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
      _resort = extra['resort_id']?.toString() ?? '';
      _startAt = DateTime.tryParse(
        extra['start_at']?.toString() ?? '',
      )?.toLocal();
      _maxController.text = extra['max_participants']?.toString() ?? '';
    } else {
      final draft = PublishDraftStore.read(_draftKey);
      if (draft != null) {
        _titleController.text = draft['title'] ?? '';
        _contentController.text = draft['content'] ?? '';
        _region = draft['region_id'] ?? _region;
        _resort = draft['resort_id'] ?? '';
        _startAt = DateTime.tryParse(draft['start_at'] ?? '');
        _maxController.text = draft['max_participants'] ?? '';
      }
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final fallback = _currentProfile;
    if (fallback != null && mounted) setState(() => _profile = fallback);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() => _profile = row);
    } catch (_) {
      // 资料读取失败时发布页不显示作者信息，不影响发布。
    }
  }

  /// 已登录用户的最小资料（未拉到线上数据时先用登录态兜底）。
  Map<String, dynamic>? get _currentProfile {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return <String, dynamic>{
      'nickname': user.userMetadata?['nickname'] ?? '',
      'avatar_url': user.userMetadata?['avatar_url'] ?? '',
    };
  }

  @override
  void dispose() {
    _saveDraft();
    _titleController.dispose();
    _contentController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    if (_submitted || widget.initialPost != null) return;
    PublishDraftStore.save(_draftKey, <String, String>{
      'title': _titleController.text,
      'content': _contentController.text,
      'region_id': _region,
      'resort_id': _resort,
      'start_at': _startAt?.toIso8601String() ?? '',
      'max_participants': _maxController.text,
    });
  }

  bool get _isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  /// 发帖归属：活动只能进 sk社区，普通帖按进入发布页时所在的板块决定。
  String? get _targetCircleId {
    if (_isActivity) return null;
    if (widget.initialPost != null) return widget.initialPost!.circleId;
    return widget.circle?.id;
  }

  /// 发布页副标题：明确告诉用户这条内容会去哪里。
  String get _publishTargetLabel {
    if (_isActivity) return '发起活动会通知到同地区的雪友';
    final circle =
        widget.circle ??
        CircleRepository.instance.byId(widget.initialPost?.circleId);
    final circleText = circle == null
        ? 'sk社区，所有人可见'
        : '${circle.label}，只有同圈雪友能看到';
    if (widget.initialPost != null) return '发布在 $circleText';
    return '发布到 $circleText';
  }

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

  Future<void> _pickResort() async {
    final picked = await showResortSheet(
      context,
      // 一次列出全部雪场，输入关键字就地筛选。
      options: resortOptionsFor(''),
      selected: _resort,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      _resort = picked;
      // 区县由雪场反查，展示与筛选都用这份数据。
      _region = GeoRepository.instance.districtPathOfResort(picked) ?? _region;
    });
  }

  Future<void> _pickStartAt() async {
    final picked = await showDateTimeSheet(context, initial: _startAt);
    if (picked == null) return;
    setState(() => _startAt = picked);
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

    if (_titleController.text.trim().isEmpty) {
      _toast('请填写标题');
      return;
    }

    Map<String, dynamic>? extraData;
    if (_isActivity) {
      if (_resort.trim().isEmpty) {
        _toast('请选择活动雪场');
        return;
      }
      final region = GeoRepository.instance.districtPathOfResort(_resort);
      if (region == null || region.isEmpty) {
        _toast('没有找到这个雪场所属的区县');
        return;
      }
      final max = _maxController.text.trim();
      final maxValue = int.tryParse(max);
      if (maxValue == null || maxValue < 1) {
        _toast('请填写最多参与人数');
        return;
      }
      if (_startAt == null) {
        _toast('请选择开始时间');
        return;
      }
      if (!_startAt!.isAfter(DateTime.now())) {
        _toast('开始时间需要晚于现在');
        return;
      }

      // 发起活动必须留手机号，否则雪友同意了也联系不上你。
      final phone = await ContactService().loadMine();
      if (phone == null) {
        if (!mounted) return;
        final saved = await showPhoneSheet(
          context,
          title: '填写手机号',
          hint: '发起活动需要手机号，方便雪友联系你。',
        );
        if (saved == null) return;
      }

      final base = Map<String, dynamic>.from(
        widget.initialPost?.extraData ?? const <String, dynamic>{},
      );
      base['activity_type'] = _entityType.replaceFirst('activity_', '');
      base['region_id'] = region;
      base['resort_id'] = _resort.trim();
      base['start_at'] = _startAt!.toUtc().toIso8601String();
      base.remove('join_deadline');
      base['max_participants'] = maxValue;
      base['activity_status'] =
          base['activity_status']?.toString() ?? 'recruiting';
      extraData = base;
    } else {
      // 普通帖子也记下「发布时所在地点」：卡片右上角展示区县·雪场，
      // 后续圈子板块也按这个归属。老帖子没有这份数据时回退到作者常驻地区。
      final profile = MyProfileStore.value;
      final region =
          (profile?['resident_region'] as String?)?.trim() ?? _region.trim();
      final resort =
          (profile?['resident_resort'] as String?)?.trim() ?? _resort.trim();
      final base = Map<String, dynamic>.from(
        widget.initialPost?.extraData ?? const <String, dynamic>{},
      );
      if (region.isEmpty) {
        base.remove('region_id');
      } else {
        base['region_id'] = region;
      }
      if (resort.isEmpty) {
        base.remove('resort_id');
      } else {
        base['resort_id'] = resort;
      }
      if (base.isNotEmpty) extraData = base;
    }

    setState(() => _loading = true);
    try {
      final title = _titleController.text.trim();

      final post = widget.initialPost == null
          ? await _entityService.createEntity(
              entityType: _entityType,
              title: title,
              content: _contentController.text.trim(),
              extraData: extraData ?? const <String, dynamic>{},
              circleId: _targetCircleId,
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
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.xxxl,
        ),
        children: [
          _buildAuthorRow(),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _titleController,
            hint: _isActivity ? '这次想约什么？' : '给这条动态起个标题',
            style: AppText.display.copyWith(color: colors.ink),
            maxLength: 60,
            borderless: true,
            minLines: 1,
            maxLines: 3,
          ),
          AppTextField(
            controller: _contentController,
            hint: _isActivity ? '说说时间、雪况和安排…' : '有什么雪上新鲜事？',
            minLines: 4,
            maxLines: 12,
            borderless: true,
          ),
          const SizedBox(height: AppSpace.md),
          if (!_isActivity) ...[
            _buildMediaEntry(),
            if (_picked.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              _buildPickedStrip(),
            ],
            if (_existingMedia.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              _buildExistingMedia(),
            ],
          ],
          if (_isActivity) ...[
            const SizedBox(height: AppSpace.xxl),
            Divider(color: colors.line, height: 1),
            const SizedBox(height: AppSpace.xl),
            Text('活动信息', style: AppText.title.copyWith(color: colors.ink)),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '活动雪场',
              requiredMark: true,
              note: '输入关键字自动筛选',
              child: _PickerTile(
                value: _resort,
                hint: '搜索并选择雪场',
                onTap: _pickResort,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '开始时间',
              requiredMark: true,
              child: _PickerTile(
                value: _startAt == null
                    ? ''
                    : _prettyTime(_startAt!.toIso8601String()),
                hint: '选择开始时间',
                onTap: _pickStartAt,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: '最多参与人数',
              requiredMark: true,
              child: AppTextField(
                controller: _maxController,
                hint: '例如 3',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xxl),
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

  /// 头像 + 昵称：和帖子卡片里的作者信息保持一致。
  Widget _buildAuthorRow() {
    final colors = context.colors;
    final nickname = (_profile?['nickname'] as String?)?.trim();
    final name = (nickname == null || nickname.isEmpty)
        ? (_isLoggedIn ? '雪友' : '未登录')
        : nickname;
    return Row(
      children: [
        AppAvatar(url: _profile?['avatar_url'] as String?),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.title.copyWith(color: colors.ink)),
              const SizedBox(height: AppSpace.xs),
              Text(
                _publishTargetLabel,
                style: AppText.caption.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 媒体入口：一行图标，和 Threads 的发布条一致。
  Widget _buildMediaEntry() {
    final colors = context.colors;
    return Row(
      children: [
        _MediaEntryButton(
          icon: AppIcons.image,
          label: '图片',
          onTap: _picked.length >= 9 ? null : _pickMedia,
        ),
        _MediaEntryButton(
          icon: AppIcons.video,
          label: '视频',
          onTap: _picked.length >= 9 ? null : _pickMedia,
        ),
        const Spacer(),
        Text(
          _picked.isEmpty ? '最多 9 个' : '${_picked.length} / 9',
          style: AppText.caption.copyWith(color: colors.muted),
        ),
      ],
    );
  }

  Widget _buildPickedStrip() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _picked.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, index) {
          final file = _picked[index];
          return _PickedTile(
            file: file,
            onRemove: () => setState(() => _picked.removeAt(index)),
          );
        },
      ),
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

class _MediaEntryButton extends StatelessWidget {
  const _MediaEntryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = onTap == null ? colors.line : colors.muted;
    return Semantics(
      button: onTap != null,
      label: '添加$label',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppText.bodySmall.copyWith(color: color)),
            ],
          ),
        ),
      ),
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

/// 表单里的「点击选择」字段：只显示结果，不提供键盘输入。
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = value.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: colors.soft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                filled ? value : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: filled ? colors.ink : colors.muted,
                ),
              ),
            ),
            Icon(AppIcons.chevron, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
}