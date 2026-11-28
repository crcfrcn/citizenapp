// 展示身份徽章及未注册引导。

import 'package:flutter/material.dart';
import 'package:citizen_system/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:citizen_user/identity/state.dart' show CidBusinessDecision, CidBusinessGate, CidBusinessStatus;
import 'package:citizen_user/identity/registration.dart' show startCidRegistrationFlow;

// 按已知身份及有效会员展示统一颜色和图形的身份徽章。

/// 公民徽章样式：无有效会员时展示身份档，有有效会员时展示会员档位。
///
/// 身份档配色：访客金 / 投票蓝 / 竞选红，中心为小人；会员档位配色：自由金 / 民主蓝 /
/// 薪火红，中心为白色对勾。徽章只负责展示，身份和会员的业务资格仍按 ADR-037 独立校验。
class IdentityBadgeStyle {
  const IdentityBadgeStyle({
    required this.color,
    required this.checked,
    this.checkColor = Colors.white,
  });

  /// 扇贝底色：无有效会员取身份档，有有效会员取会员档位。
  final Color color;

  /// true=有生效会员→显示对勾；false=只有身份/纯访客→显示小人。
  final bool checked;

  /// 对勾颜色固定白色；字段保留给绘制器统一使用。
  final Color checkColor;
}

/// 链上身份档位对应颜色。
Color _identityTierColor(String? level) => switch (level) {
  'candidate' => AppTheme.identityCandidate,
  'voting' => AppTheme.identityVoting,
  _ => AppTheme.identityVisitor,
};

/// 有效会员档位对应颜色；未知档位返回 null，避免把异常数据误展示为有效会员。
Color? _membershipTierColor(String? level) => switch (level) {
  'freedom' => AppTheme.identityVisitor,
  'democracy' => AppTheme.identityVoting,
  'spark' => AppTheme.identityCandidate,
  _ => null,
};

/// 计算徽章样式。会员必须同时满足有效态和合法档位才显示会员徽章，否则回落身份徽章。
IdentityBadgeStyle? identityBadgeStyle({
  required String? cidLevel,
  required String? memberLevel,
  required bool membergateActive,
}) {
  final membershipColor = membergateActive
      ? _membershipTierColor(memberLevel)
      : null;
  return IdentityBadgeStyle(
    color: membershipColor ?? _identityTierColor(cidLevel),
    checked: membershipColor != null,
    checkColor: Colors.white,
  );
}

/// 徽章无障碍/提示文案。
String identityBadgeLabel({
  required String? cidLevel,
  required String? memberLevel,
  required bool checked,
}) {
  final base = switch (cidLevel) {
    'candidate' => '竞选公民',
    'voting' => '投票公民',
    _ => '访客',
  };
  final membership = switch (memberLevel) {
    'freedom' => '自由会员',
    'democracy' => '民主会员',
    'spark' => '薪火会员',
    _ => null,
  };
  return checked && membership != null ? '$base · $membership' : base;
}

/// 推特式扇贝勋章徽章（四处认证展示点共用）：
/// 底为身份档或会员档位色，中心 checked=白色对勾（有效会员）/ 否则=白色小人（身份）。
class IdentityBadge extends StatelessWidget {
  const IdentityBadge({
    super.key,
    required this.style,
    this.size = 24,
    this.tooltip = '',
  });

  final IdentityBadgeStyle style;
  final double size;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RosetteBadgePainter(
          color: style.color,
          checked: style.checked,
          checkColor: style.checkColor,
        ),
      ),
    );
    if (tooltip.isEmpty) return badge;
    return Tooltip(message: tooltip, child: badge);
  }
}

class _RosetteBadgePainter extends CustomPainter {
  _RosetteBadgePainter({
    required this.color,
    required this.checked,
    required this.checkColor,
  });

  final Color color;
  final bool checked;
  final Color checkColor;

  // 8 个花瓣圆心（24 网格坐标），围绕中心圆构成扇贝勋章。
  static const List<Offset> _bumps = [
    Offset(18, 12),
    Offset(16.24, 16.24),
    Offset(12, 18),
    Offset(7.76, 16.24),
    Offset(6, 12),
    Offset(7.76, 7.76),
    Offset(12, 6),
    Offset(16.24, 7.76),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    Offset p(double x, double y) => Offset(x * scale, y * scale);
    final center = p(12, 12);

    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    for (final bump in _bumps) {
      canvas.drawCircle(p(bump.dx, bump.dy), 4.3 * scale, fill);
    }
    canvas.drawCircle(center, 7.6 * scale, fill);

    if (checked) {
      final stroke = Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      final path = Path()
        ..moveTo(8.3 * scale, 12.2 * scale)
        ..lineTo(10.9 * scale, 14.8 * scale)
        ..lineTo(15.8 * scale, 9.4 * scale);
      canvas.drawPath(path, stroke);
    } else {
      final white = Paint()
        ..color = Colors.white
        ..isAntiAlias = true;
      // 小人：头 + 肩。
      canvas.drawCircle(p(12, 9.7), 2.3 * scale, white);
      final shoulders = Path()
        ..moveTo(7.7 * scale, 16.4 * scale)
        ..cubicTo(
          7.7 * scale,
          14.0 * scale,
          9.6 * scale,
          12.7 * scale,
          12 * scale,
          12.7 * scale,
        )
        ..cubicTo(
          14.4 * scale,
          12.7 * scale,
          16.3 * scale,
          14.0 * scale,
          16.3 * scale,
          16.4 * scale,
        )
        ..close();
      canvas.drawPath(shoulders, white);
    }
  }

  @override
  bool shouldRepaint(covariant _RosetteBadgePainter old) =>
      old.color != color ||
      old.checked != checked ||
      old.checkColor != checkColor;
}

// 统一呈现明确未注册状态的引导及公民服务入口门禁。

/// 「尚未注册」统一引导 —— 全 App 唯一的未注册页面态组件。
///
/// 「已有钱包、未注册 CID」是合法用户状态,需要 CID 的页面(广场、聊天、创作者…)
/// 在主体区显示本组件,而不是把 fail-closed 的正确拦截包装成报错文案。
/// 点「注册」**就地**弹出统一注册面板([startCidRegistrationFlow],与身份页
/// 右上角「注册」同一条链路),不跳转身份页。
///
/// [description] 由调用方传一句该页专属说明(如「注册后即可使用聊天与通讯录。」);
/// [onRegistered] 在占号提交成功后回调,调用方借此就地回刷(占号不改钱包列表,
/// 不改变账户目录时仍需靠 finalized 身份 revision 或本回调驱动刷新。
class IdentityRegisterGuide extends StatefulWidget {
  const IdentityRegisterGuide({
    super.key,
    required this.description,
    this.onRegistered,
  });

  final String description;
  final VoidCallback? onRegistered;

  @override
  State<IdentityRegisterGuide> createState() => _IdentityRegisterGuideState();
}

class _IdentityRegisterGuideState extends State<IdentityRegisterGuide> {
  bool _registering = false;

  Future<void> _onRegister() async {
    if (_registering) return;
    // 身份同步广播会重建引导；弹窗必须归属仍挂载的页面，而不是临时按钮。
    final pageContext = Scaffold.maybeOf(context)?.context ?? context;
    setState(() => _registering = true);
    try {
      final registered = await startCidRegistrationFlow(pageContext);
      if (registered) widget.onRegistered?.call();
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppLayout.scaled(context, 84),
              height: AppLayout.scaled(context, 84),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'packages/citizen_assets/icons/file-user.svg',
                width: AppLayout.scaled(context, 40),
                height: AppLayout.scaled(context, 40),
                colorFilter: const ColorFilter.mode(
                  AppTheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 18)),
            Text(
              '尚未注册',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 17),
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 10)),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 13),
                height: 1.6,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 22)),
            SizedBox(
              height: AppLayout.scaled(context, 44),
              child: FilledButton(
                onPressed: _registering ? null : _onRegister,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.scaled(context, 22),
                  ),
                  child: const Text('注册'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 社交详情与编辑直达入口的统一门禁；未确认身份CID号前不挂载业务子页面。
/// 外层 WalletGate 已处理无钱包，这里只处理公民服务业务身份。
class CitizenServiceGate extends StatefulWidget {
  const CitizenServiceGate({
    super.key,
    required this.title,
    required this.description,
    this.child,
    this.builder,
    this.fallbackFloatingActionButton,
  }) : assert((child == null) != (builder == null));

  final String title;
  final String description;
  final Widget? child;

  /// 未就绪/未注册壳的固定展示入口；不提前挂载业务child或建立会话。
  final Widget? fallbackFloatingActionButton;
  final Widget Function(String cidNumber)? builder;

  @override
  State<CitizenServiceGate> createState() => _CitizenServiceGateState();
}

class _CitizenServiceGateState extends State<CitizenServiceGate> {
  CidBusinessGate? _gate;
  CidBusinessDecision? _decision;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gate = context.read<CidBusinessGate>();
    if (identical(_gate, gate)) return;
    _gate?.revision.removeListener(_onRevision);
    _gate = gate;
    gate.revision.addListener(_onRevision);
    _resolve(initial: true);
  }

  @override
  void dispose() {
    _generation++;
    _gate?.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() => _resolve();

  void _resolve({bool initial = false}) {
    final gate = _gate;
    if (gate == null) return;
    final generation = ++_generation;
    if (initial) {
      _decision = null;
    } else {
      setState(() => _decision = null);
    }
    gate.resolve().then((decision) {
      if (mounted && generation == _generation) {
        setState(() => _decision = decision);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    if (decision?.status == CidBusinessStatus.ready) {
      return widget.builder?.call(decision!.cidNumber!) ?? widget.child!;
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.fallbackFloatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      body: switch (decision?.status) {
        CidBusinessStatus.unregistered => IdentityRegisterGuide(
          description: widget.description,
          onRegistered: _onRevision,
        ),
        CidBusinessStatus.unavailable => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('暂时无法核实身份CID号，请重试'),
              TextButton(onPressed: _onRevision, child: const Text('重试')),
            ],
          ),
        ),
        CidBusinessStatus.noWallet => const Center(
          child: Text('钱包状态已变化，正在返回初始化页'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
