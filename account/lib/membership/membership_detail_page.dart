import 'package:flutter/material.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/creator/creator_money.dart'
    show fenToYuanMoneyLabel;
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 会员详情页：展开某一档（自由/民主/薪火）的**完整权益**（聊天 / 公文 / 文章 / 视频 / 用量额度）。
///
/// 额度、规格与用量只展示服务端快照或它的缓存，不定义静态套餐。
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
    final tierColor = _tierColor(level);
    final onTier = _onTierColor(level);
    return Scaffold(
      appBar: AppBar(title: const Text('会员详情'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _header(level, tierColor, onTier),
          SizedBox(height: AppLayout.scaled(context, 16)),
          if (plan != null) ...[
            _section(tierColor, Icons.chat_bubble_outline, '聊天', [
              _row('消息', '文字、表情、贴纸、图片'),
              _row('语音消息', '最长 ${plan.chatVoiceLabel}'),
              _row('视频消息', '最长 ${plan.chatVideoLabel}'),
              _row('单个附件', '最大 ${plan.fileSizeLabel}'),
              _row('语音通话', plan.chat.voiceCallEnabled ? '支持' : '不支持'),
              _row('视频通话', plan.chat.videoCallEnabled ? '支持' : '不支持'),
            ]),
            SizedBox(height: AppLayout.scaled(context, 12)),
            _section(tierColor, Icons.description_outlined, '公文', [
              _row('文字', '最多 ${plan.document.textMaxChars} 字'),
              _row(
                '图片',
                '${plan.document.maxImages} 张 · ${plan.documentImageLabel}',
              ),
              _row('单图片体积', '最大 ${plan.imageBytesLabel}'),
            ]),
            SizedBox(height: AppLayout.scaled(context, 12)),
            _section(tierColor, Icons.videocam_outlined, '视频', [
              _row('配文', '最多 ${plan.video.textMaxChars} 字'),
              _row(
                '视频',
                '1 个 · ${plan.videoDurationLabel} · ${plan.videoQualityLabel}',
              ),
              _row('单视频体积', '最大 ${plan.videoBytesLabel}'),
            ]),
            SizedBox(height: AppLayout.scaled(context, 12)),
            _section(tierColor, Icons.article_outlined, '文章', [
              _row('正文', '最多 ${_wan(plan.article.bodyMaxChars)}'),
              _row(
                '配图',
                '${plan.article.maxImages} 张 · ${plan.articleImageLabel}',
              ),
              _row('视频', '最多 ${plan.article.maxVideos} 个'),
              _row(
                '首图 · 标题',
                '${plan.articleCoverLabel} · ${plan.article.titleMinChars}–${plan.article.titleMaxChars} 字',
              ),
            ]),
            SizedBox(height: AppLayout.scaled(context, 12)),
            _section(tierColor, Icons.storage_outlined, '用量额度', [
              _row('广场存储空间', plan.storageSizeLabel),
              _row(
                '聊天附件存储',
                plan.resources['attachment_bytes'] == null
                    ? '未知'
                    : SquareMembershipPlan.formatBytes(
                        plan.resources['attachment_bytes']!,
                      ),
              ),
            ]),
            if (plan.dailyLimits.isNotEmpty) ...[
              SizedBox(height: AppLayout.scaled(context, 12)),
              _section(tierColor, Icons.today_outlined, '每日资源额度（UTC）', [
                for (final entry in plan.dailyLimits.entries.where(
                  (entry) => _dailyDisplay.containsKey(entry.key),
                ))
                  _row(
                    _dailyDisplay[entry.key]!,
                    _meterValue(entry.key, entry.value),
                  ),
              ]),
            ],
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
          ] else
            _section(tierColor, Icons.workspace_premium_outlined, '会员权益', [
              const Text('权益待获取'),
            ]),
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

// 指标名称和单位只用于展示；额度及已用值均来自同一服务端响应。
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

/// 固定档名仅用于无套餐时的UI，不包含价格、额度或授权信息。
String membershipTitle(String level) => switch (level) {
  'freedom' => '自由会员',
  'democracy' => '民主会员',
  'spark' => '薪火会员',
  _ => throw ArgumentError.value(level, 'level', '会员档位未知'),
};
