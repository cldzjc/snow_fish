import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum LegalDocument { terms, privacy }

/// 用户协议 / 隐私政策。
///
/// 内容是面向这个小社区的实际约定，不是模板套话；条款变化时需要同步更新
/// `appVersion`，让用户能从设置里看到「最近更新」。
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.document});

  final LegalDocument document;

  static const String updatedAt = '2026-11-28';

  String get _title => switch (document) {
    LegalDocument.terms => '用户协议',
    LegalDocument.privacy => '隐私政策',
  };

  List<(String, String)> get _sections => switch (document) {
    LegalDocument.terms => _terms,
    LegalDocument.privacy => _privacy,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          AppSpace.huge,
        ),
        children: [
          Text(
            '最近更新：$updatedAt',
            style: AppText.caption.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpace.xl),
          for (final (heading, body) in _sections) ...[
            Text(
              heading,
              style: AppText.title.copyWith(color: colors.ink, fontSize: 15),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              body,
              style: AppText.bodySmall.copyWith(color: colors.muted, height: 1.7),
            ),
            const SizedBox(height: AppSpace.xl),
          ],
        ],
      ),
    );
  }

  static const List<(String, String)> _terms = [
    (
      '一、服务说明',
      'skneo（sk社区）是一个面向滑雪爱好者的内容与约伴社区，提供发布图文、发起与参与滑雪 / 约拍 / 约饭活动、'
          '加入城市与雪场圈子等功能。服务目前免费提供，可能随时调整、暂停或终止。',
    ),
    (
      '二、账号',
      '你使用邮箱验证码登录，一个邮箱对应一个账号。请勿转让、出借账号，也不要与他人共用。'
          '账号下的一切行为视为你本人所为。若发现账号被盗用，请尽快通过设置里的联系方式告知我们。',
    ),
    (
      '三、发布规范',
      '你在社区发布的一切内容（帖子、图片、视频、评论、昵称、头像、活动信息）都由你本人负责。'
          '以下内容不允许发布：\n'
          '· 色情、低俗、暴力、血腥内容\n'
          '· 政治敏感、违法违规内容\n'
          '· 广告引流、代滑接单、私教拉客、加微信 / 加 V 等商业推广\n'
          '· 侵犯他人肖像权、隐私权、著作权的内容\n'
          '· 虚假活动、诈骗、买卖雪票与证件\n'
          '· 针对他人的辱骂、地域攻击、人身攻击',
    ),
    (
      '四、内容审核与处置',
      '我们会对发布的文字与图片进行自动审核，并对可疑内容进行人工复核。'
          '违规内容可能被隐藏或删除，账号可能被限制发布或封禁。'
          '你对处置有异议，可以联系管理员申诉，核实后会恢复。',
    ),
    (
      '五、约伴活动',
      '活动由用户自发发起，发起者与参与者自行约定时间、地点与费用。'
          'skneo 不对活动的安全性、真实性、履约情况承担责任。'
          '参与线下活动请自行评估风险，注意人身与财产安全。',
    ),
    (
      '六、知识产权',
      '你发布的内容著作权归你所有。你授权 skneo 在站内展示、缓存、生成缩略图，'
          '以及为产品展示目的在宣传中使用。删除内容后该授权终止，但已分享出去的链接可能被第三方缓存。',
    ),
    (
      '七、免责',
      '因网络故障、第三方服务（云存储、邮件、数据库）异常、不可抗力导致的服务中断或数据丢失，'
          '我们在能力范围内尽快恢复，但不承担赔偿责任。请对重要内容自行留存备份。',
    ),
    (
      '八、协议变更',
      '协议更新后会在此页展示新的「最近更新」日期，并在版本说明里提示。'
          '继续使用即视为接受更新后的协议。',
    ),
    (
      '九、联系我们',
      '任何问题、申诉、举报，都可以通过设置页的「联系我们」发邮件给我们。',
    ),
  ];

  static const List<(String, String)> _privacy = [
    (
      '一、我们收集什么',
      '· 邮箱地址：注册与登录用，也是账号唯一标识\n'
          '· 手机号（可选）：只在约活动时提供给对方，个人主页不展示\n'
          '· 你主动发布的内容：帖子、图片、视频、评论、昵称、头像、常驻地点\n'
          '· 活动信息：发起或参与的活动、时间、地点、参与状态\n'
          '· 基础日志：发布 / 登录时间，用于排查故障与处理违规',
    ),
    (
      '二、我们不收集什么',
      '不读取你的通讯录、相册（除你主动选择上传的图片）、位置（除你主动填写的常驻地点与活动地点）、'
          '不接入第三方广告 SDK、不做用户画像、不向任何人出售或出租你的信息。',
    ),
    (
      '三、数据存放在哪里',
      '· 账号与文字内容：Supabase（服务器位于日本东京）\n'
          '· 图片与视频：阿里云 OSS（香港节点）\n'
          '· 邮件发送：Resend\n'
          '这意味着你的数据会传输并存储在中国大陆境外。手机号属于个人信息，'
          '我们已把它单独存放在仅本人可读的私有表里，只在你与他人建立活动关系时按需提供。',
    ),
    (
      '四、我们要你的数据做什么',
      '只为提供社区功能本身：登录、展示内容、撮合约伴、处置违规。'
          '不会用于广告投放，也不会提供给数据商。',
    ),
    (
      '五、谁能看到',
      '· 你的昵称、头像、常驻地点、发布的内容：所有访问者可见\n'
          '· 你的邮箱：仅你本人与系统可见\n'
          '· 你的手机号：仅你本人可见；活动申请被同意后，对方可见\n'
          '· 违规内容与处置记录：仅管理员可见',
    ),
    (
      '六、内容审核',
      '为识别违规内容，你发布的文字与图片会被提交给内容安全服务（阿里云内容安全）进行自动检测。'
          '该检测只返回「是否违规」的结论与分类，服务商不会因此获得你的账号信息。',
    ),
    (
      '七、你的权利',
      '· 查看与修改：设置里可以修改昵称、头像、常驻地点与手机号\n'
          '· 删除：可以删除自己发布的内容；删除后原图会一并从对象存储清除\n'
          '· 清除手机号：设置里一键清除\n'
          '· 注销账号：通过「联系我们」提出，我们会在核实身份后删除你的账号与其内容',
    ),
    (
      '八、未成年人',
      '本服务面向 14 周岁以上用户。若你未满 14 周岁，请在监护人同意并陪同下使用。',
    ),
    (
      '九、政策变更',
      '本政策更新后会在此页展示新的「最近更新」日期。'
          '如果变更涉及收集范围扩大，我们会在站内提示。',
    ),
  ];
}
