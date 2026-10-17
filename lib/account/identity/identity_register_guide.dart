import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:citizenapp/account/identity/cid_business_gate.dart';
import 'package:citizenapp/account/identity/register_identity_flow.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/system/theme/app_layout.dart';

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
    setState(() => _registering = true);
    try {
      final registered = await startCidRegistrationFlow(context);
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
                'assets/icons/file-user.svg',
                width: AppLayout.scaled(context, 40),
                height: AppLayout.scaled(context, 40),
                colorFilter:
                    const ColorFilter.mode(AppTheme.primary, BlendMode.srcIn),
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
                      horizontal: AppLayout.scaled(context, 22)),
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

/// 社交详情与编辑直达入口的统一门禁；未确认公民号前不挂载业务子页面。
/// 外层 WalletGate 已处理无钱包，这里只处理公民服务业务身份。
class CitizenServiceGate extends StatefulWidget {
  const CitizenServiceGate({
    super.key,
    required this.title,
    required this.description,
    this.child,
    this.builder,
  }) : assert((child == null) != (builder == null));

  final String title;
  final String description;
  final Widget? child;
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
      body: switch (decision?.status) {
        CidBusinessStatus.unregistered => IdentityRegisterGuide(
          description: widget.description,
          onRegistered: _onRevision,
        ),
        CidBusinessStatus.unavailable => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('暂时无法核实公民号身份，请重试'),
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
