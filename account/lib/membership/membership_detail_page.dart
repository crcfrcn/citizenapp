import 'package:flutter/material.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/creator/creator_money.dart'
    show fenToYuanMoneyLabel;
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 会员详情页：展开某一档（自由/民主/薪火）的**完整权益**（聊天 / 公文 / 文章 / 视频 / 用量额度）。
///
/// 完整权益复用会员卡的展示文案；真实套餐优先，缺少套餐也保留已确认的三档介绍。
/// 展示文案不构造套餐、价格、当前已用量或订阅资格。
/// 订阅动作不在本页实现：点击底部按钮返回会员页并触发原订阅流程（[onSubscribe]），
/// 避免把签名/上链逻辑复制到详情页。
class MembershipDetailPage extends StatelessWidget {
  const MembershipDetailPage({
    super.key,
    required this.memberLevel,
    required this.plan,
    required this.priceFen,
    required this.actionLabel,
    required this.subscribeEnabled,
    required this.onSubscribe,
    this.usageState,
  });

  final String memberLevel;
  final SquareMembershipPlan? plan;
  final SquareMembershipUsageState? usageState;

  /// 本档链上月价（分）；null=链上未设该档价，显示占位「—」。
  final int? priceFen;
  final String actionLabel;
  final bool subscribeEnabled;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final level = memberLevel;
    final plan = this.plan;
    final benefits = membershipBenefits(level, plan);
    final tierColor = _tierColor(level);
    final onTier = _onTierColor(level);
    return Scaffold(
      appBar: AppBar(title: const Text('会员详情'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _header(level, tierColor, onTier),
          SizedBox(height: AppLayout.scaled(context, 16)),
          _section(tierColor, Icons.chat_bubble_outline, '聊天', [
            _row('消息', '文字、表情、贴纸、图片'),
            _row('语音消息', '最长 ${benefits.voice}'),
            _row('视频消息', '最长 ${benefits.videoMessage}'),
            _row('单个附件', '最大 ${benefits.file}'),
            _row('语音通话', benefits.voiceCall),
            _row('视频通话', benefits.videoCall),
          ]),
          SizedBox(height: AppLayout.scaled(context, 12)),
          _section(tierColor, Icons.description_outlined, '公文', [
            _row('文字', '最多 ${benefits.documentText}'),
            _row(
              '图片',
              '${benefits.documentImages} · 最长边 ${benefits.imageDimension}',
            ),
            _row('单图片体积', '最大 ${benefits.imageSize}'),
          ]),
          SizedBox(height: AppLayout.scaled(context, 12)),
          _section(tierColor, Icons.videocam_outlined, '视频', [
            _row('配文', '最多 ${benefits.videoText}'),
            _row(
              '视频',
              '1 个 · ${benefits.videoDuration} · ${benefits.videoQuality}',
            ),
            _row('单视频体积', '最大 ${benefits.videoSize}'),
          ]),
          SizedBox(height: AppLayout.scaled(context, 12)),
          _section(tierColor, Icons.article_outlined, '文章', [
            _row('正文', '最多 ${benefits.articleBody}'),
            _row(
              '配图',
              '${benefits.articleImages}（含首图）· 最长边 ${benefits.imageDimension}',
            ),
            _row('视频', '最多 ${benefits.articleVideos}'),
            _row('标题', benefits.articleTitle),
            _row('首图', '必须有，计入配图数量'),
            _row('图片与视频规格', '与本档公文图片、发布视频相同'),
          ]),
          SizedBox(height: AppLayout.scaled(context, 12)),
          _section(tierColor, Icons.storage_outlined, '用量额度', [
            _row('广场存储空间', benefits.storage),
            _row('聊天附件存储', benefits.attachments),
            _row('重置规则', '存储空间不随每日或订阅周期重置'),
          ]),
          SizedBox(height: AppLayout.scaled(context, 12)),
          _section(tierColor, Icons.today_outlined, '每日会员额度', [
            _row('媒体访问', benefits.mediaRequests),
            _row('媒体下载流量', benefits.downloads),
            _row('聊天附件上传流量', benefits.uploads),
            _row('附件新建额度', benefits.begins),
            _row('重置规则', '同一公民号跨设备累计，UTC 零点重置'),
          ]),
          SizedBox(height: AppLayout.scaled(context, 12)),
          _section(tierColor, Icons.info_outline, '计量说明', [
            _row('容量单位', 'KiB／MiB／GiB／TiB，逐级 1024'),
            _row('单个聊天附件', '按明文大小计算'),
            _row('附件上传与存储', '按密文大小计算'),
          ]),
          if (usageState case final usage?) ...[
            SizedBox(height: AppLayout.scaled(context, 12)),
            _section(tierColor, Icons.data_usage_outlined, '服务端用量快照', [
              _row('已用存储', _meterValue('delivery_bytes', usage.usedBytes)),
              _row(
                '上传预留存储',
                _meterValue('delivery_bytes', usage.reservedBytes),
              ),
              _row('周期发布', '${usage.publishedCount} 条'),
              _row(
                '服务端采样时间',
                usage.observedAt > 0
                    ? DateTime.fromMillisecondsSinceEpoch(
                        usage.observedAt,
                        isUtc: true,
                      ).toIso8601String()
                    : '未知',
              ),
              if (usage.attachment case final stock?) ...[
                if (stock['status'] == 'available') ...[
                  _row(
                    '聊天附件存储',
                    _meterValue('delivery_bytes', stock['bytes'] as int),
                  ),
                ] else
                  _row('聊天附件存量', '暂不可用'),
              ],
              _row(
                '统计日（UTC）',
                DateTime.fromMillisecondsSinceEpoch(
                  usage.dayStart,
                  isUtc: true,
                ).toIso8601String().substring(0, 10),
              ),
              for (final entry in usage.daily.entries.where(
                (entry) => _dailyDisplay.containsKey(entry.key),
              ))
                _row(
                  _dailyDisplay[entry.key]!,
                  _meterValue(entry.key, entry.value),
                ),
            ]),
          ],
          SizedBox(height: AppLayout.scaled(context, 20)),
          _subscribeButton(context, tierColor, onTier),
        ],
      ),
    );
  }

  Widget _header(String level, Color tierColor, Color onTier) {
    // 与三档会员卡一致：自由金底使用主文字色，深色档位使用纯白公民币标志。
    final gmbMarkColor = level == 'freedom'
        ? AppTheme.textPrimary
        : Colors.white;
    return Container(
      padding: EdgeInsets.all(AppLayout.scaledValue(16)),
      decoration: BoxDecoration(
        color: tierColor,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '会员订阅',
                  style: TextStyle(
                    color: onTier.withValues(alpha: 0.82),
                    fontSize: AppLayout.scaledValue(12),
                  ),
                ),
                SizedBox(height: AppLayout.scaledValue(4)),
                Text(
                  plan?.displayName ?? membershipTitle(level),
                  style: TextStyle(
                    color: onTier,
                    fontSize: AppLayout.scaledValue(24),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppLayout.scaledValue(12)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标志只辅助识别，价格文本继续承担金额和无障碍语义。
                  ExcludeSemantics(
                    child: Image.asset(
                      'packages/citizen_assets/logo/mark256.png',
                      key: ValueKey('membership-detail-price-gmb-mark-$level'),
                      width: 18,
                      height: 18,
                      color: gmbMarkColor,
                      colorBlendMode: BlendMode.srcIn,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  SizedBox(width: AppLayout.scaledValue(6)),
                  Text(
                    priceFen == null ? '—' : fenToYuanMoneyLabel(priceFen!),
                    style: TextStyle(
                      color: onTier,
                      fontSize: AppLayout.scaledValue(18),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (priceFen != null)
                Text(
                  '/月',
                  style: TextStyle(
                    color: onTier.withValues(alpha: 0.82),
                    fontSize: AppLayout.scaledValue(11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(
    Color tierColor,
    IconData icon,
    String title,
    List<Widget> rows,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(14)),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppLayout.scaledValue(6)),
            child: Row(
              children: [
                Icon(icon, size: AppLayout.scaledValue(16), color: tierColor),
                SizedBox(width: AppLayout.scaledValue(6)),
                Text(
                  title,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: AppLayout.scaledValue(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows) ...[
            const Divider(height: 1, color: AppTheme.border),
            row,
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppLayout.scaledValue(9)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: AppLayout.scaledValue(14),
            ),
          ),
          SizedBox(width: AppLayout.scaledValue(12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: AppLayout.scaledValue(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subscribeButton(BuildContext context, Color tierColor, Color onTier) {
    return Material(
      color: subscribeEnabled ? tierColor : AppTheme.border,
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        onTap: subscribeEnabled && plan != null
            ? () {
                // 订阅流程在会员页：先返回,再触发原 _handleAction。
                Navigator.of(context).pop();
                onSubscribe();
              }
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppLayout.scaled(context, 14),
          ),
          child: Center(
            child: Text(
              // 价格已经在详情头部单独展示；按钮只表达动作或不可用原因，避免把
              // “服务不可用/添加钱包”等状态与金额拼成一句错误文案。
              actionLabel,
              style: TextStyle(
                color: subscribeEnabled ? onTier : AppTheme.textTertiary,
                fontSize: AppLayout.scaled(context, 15),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片摘要和完整详情共用的纯展示文本，不能传给额度预检或订阅授权。
typedef MembershipBenefits = ({
  String voice,
  String videoMessage,
  String voiceCall,
  String videoCall,
  String file,
  String documentText,
  String documentImages,
  String imageDimension,
  String imageSize,
  String videoText,
  String videoDuration,
  String videoQuality,
  String videoSize,
  String articleBody,
  String articleTitle,
  String articleImages,
  String articleVideos,
  String storage,
  String attachments,
  String mediaRequests,
  String downloads,
  String uploads,
  String begins,
});

/// 无套餐时使用用户确认的最新三档介绍；真实套餐或缓存到达后按原值展示。
/// 这里只生成文案，不构造 SquareMembershipPlan，也不填充价格、用量或资格。
MembershipBenefits membershipBenefits(
  String level,
  SquareMembershipPlan? plan,
) {
  final copy = switch (level) {
    'freedom' => (
      file: '10 MiB',
      imageDimension: '1280px',
      imageSize: '400 KiB',
      videoDuration: '3 分钟',
      videoQuality: '480p',
      videoSize: '12 MiB',
      articleImages: 20,
      articleVideos: 1,
      storage: '256 GiB',
      attachments: '1 GiB',
      mediaRequests: 5000,
      downloads: '1 GiB',
      uploads: '512 MiB',
      begins: 128,
    ),
    'democracy' => (
      file: '100 MiB',
      imageDimension: '1600px',
      imageSize: '800 KiB',
      videoDuration: '30 分钟',
      videoQuality: '720p',
      videoSize: '200 MiB',
      articleImages: 50,
      articleVideos: 3,
      storage: '1 TiB',
      attachments: '5 GiB',
      mediaRequests: 15000,
      downloads: '5 GiB',
      uploads: '2 GiB',
      begins: 256,
    ),
    'spark' => (
      file: '5 GiB',
      imageDimension: '1920px',
      imageSize: '1200 KiB',
      videoDuration: '3 小时',
      videoQuality: '1080p',
      videoSize: '1800 MiB',
      articleImages: 100,
      articleVideos: 10,
      storage: '10 TiB',
      attachments: '12 GiB',
      mediaRequests: 50000,
      downloads: '50 GiB',
      uploads: '10 GiB',
      begins: 1024,
    ),
    _ => throw ArgumentError.value(level, 'level', '会员档位未知'),
  };
  String daily(String metric, String description) {
    if (plan == null) return description;
    final value = plan.dailyLimits[metric];
    return value == null ? '待获取' : _meterValue(metric, value);
  }

  final attachmentBytes = plan?.resources['attachment_bytes'];
  return (
    voice: plan?.chatVoiceLabel ?? '3 分钟',
    videoMessage: plan?.chatVideoLabel ?? '3 分钟',
    voiceCall: plan == null || plan.chat.voiceCallEnabled ? '支持' : '不支持',
    videoCall: plan == null || plan.chat.videoCallEnabled ? '支持' : '不支持',
    file: plan?.fileSizeLabel ?? copy.file,
    documentText: '${plan?.document.textMaxChars ?? 300} 字',
    documentImages: '${plan?.document.maxImages ?? 9} 张',
    imageDimension: plan?.documentImageLabel ?? copy.imageDimension,
    imageSize: plan?.imageBytesLabel ?? copy.imageSize,
    videoText: '${plan?.video.textMaxChars ?? 300} 字',
    videoDuration: plan?.videoDurationLabel ?? copy.videoDuration,
    videoQuality: plan?.videoQualityLabel ?? copy.videoQuality,
    videoSize: plan?.videoBytesLabel ?? copy.videoSize,
    articleBody: _wan(plan?.article.bodyMaxChars ?? 30000),
    articleTitle:
        '${plan?.article.titleMinChars ?? 10}–${plan?.article.titleMaxChars ?? 50} 字',
    articleImages: '${plan?.article.maxImages ?? copy.articleImages} 张',
    articleVideos: '${plan?.article.maxVideos ?? copy.articleVideos} 个',
    storage: plan?.storageSizeLabel ?? copy.storage,
    attachments: plan == null
        ? copy.attachments
        : attachmentBytes == null
        ? '待获取'
        : SquareMembershipPlan.formatBytes(attachmentBytes),
    mediaRequests: daily(
      'media_requests',
      '${_thousands(copy.mediaRequests)} 次',
    ),
    downloads: daily('delivery_bytes', copy.downloads),
    uploads: daily('upload_bytes', copy.uploads),
    begins: daily('attachment_begins', '${_thousands(copy.begins)} 次'),
  );
}

// 指标名称和单位只用于当前真实已用量的展示，不参与权益文案或授权。
// 界面只展示用户能直接理解的媒体请求与流量；完整计数仍保留在同一服务端快照中。
const _dailyDisplay = {
  'media_requests': '媒体读取请求',
  'upload_bytes': '聊天附件上传总大小',
  'delivery_bytes': '媒体下发总大小',
  'attachment_begins': '新建聊天附件次数',
};
String _meterValue(String metric, int value) => metric.endsWith('_bytes')
    ? SquareMembershipPlan.formatBytes(value)
    : '${_thousands(value)} 次';

/// 会员档色（自由金 / 民主蓝 / 薪火红），与会员卡片一致。
Color _tierColor(String level) => switch (level) {
  'spark' => AppTheme.identityCandidate,
  'democracy' => AppTheme.identityVoting,
  _ => AppTheme.identityVisitor,
};

/// 顶带前景色：自由金底用深棕，其余用白字。
Color _onTierColor(String level) =>
    level == 'freedom' ? const Color(0xFF4A3000) : Colors.white;

/// 整数千分号：5000 → "5,000"。
String _thousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// 字数「万」简写：30000 → "3 万字"；非整万回退千分号原值。
String _wan(int chars) => chars >= 10000 && chars % 10000 == 0
    ? '${chars ~/ 10000} 万字'
    : '${_thousands(chars)} 字';

/// 固定档名仅用于展示，不包含价格、用量或授权信息。
String membershipTitle(String level) => switch (level) {
  'freedom' => '自由会员',
  'democracy' => '民主会员',
  'spark' => '薪火会员',
  _ => throw ArgumentError.value(level, 'level', '会员档位未知'),
};
