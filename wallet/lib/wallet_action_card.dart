import 'package:citizen_wallet/navigation.dart';

import 'dart:async';

import 'package:citizen_wallet/account_balance_snapshot_store.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:citizen_transaction/offchain/clearing_bank_prefs.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/theme/app_theme.dart';

/// 冷热账户共用双币充值与零钱包入口，余额和目标始终绑定精确account_id。
/// USDT/USDC都直接打开套餐弹窗；零钱包仍使用原清算行绑定与余额查询。
class WalletActionCard extends StatefulWidget {
  const WalletActionCard({
    super.key,
    required this.accountId,
    required this.accountAddress,
    this.finalizedBalanceLoader,
    this.hasOuterCard = false,
  });

  /// 该账户链账户主键(0x+64hex):充值目标、清算行绑定缓存键、按账户签名均以它为准。
  final String accountId;

  /// 该账户 SS58 地址,用于查询清算行存款余额。
  final String accountAddress;

  /// 外层已有完整卡片时，不叠加组件自己的底线。
  final bool hasOuterCard;

  /// 默认复用链上余额 RPC；测试可注入稳定结果，避免把网络状态写进组件断言。
  final Future<double> Function(String accountId)? finalizedBalanceLoader;

  @override
  State<WalletActionCard> createState() => WalletActionCardState();
}

class WalletActionCardState extends State<WalletActionCard> {
  ClearingBankBindingSnapshot? _binding;
  bool _bindingLoaded = false;
  bool _topupOpening = false;
  WalletBalanceState<CitizenAccountBalance>? _onchain;
  WalletBalanceState<BigInt>? _clearing;
  WalletBalanceState<BigInt>? _testBalance;

  String get _onchainBalanceText {
    final value = _onchain?.value?.totalFen ?? _testBalance?.value;
    if (value != null) {
      return '${AccountBalanceSnapshotStore.formatFen(value)} 元';
    }
    return (_onchain?.hasError ?? _testBalance?.hasError ?? false)
        ? '查询失败'
        : '读取中';
  }

  String get _balanceText {
    if (!_bindingLoaded) return '读取中';
    if (_binding == null) return '未绑定';
    final value = _clearing?.value;
    if (value != null) {
      return '${AccountBalanceSnapshotStore.formatFen(value)} 元';
    }
    return _clearing?.hasError == true ? '节点不可达' : '读取中';
  }

  @override
  void initState() {
    super.initState();
    _bindOnchain();
    unawaited(refresh(forceRefresh: false));
  }

  void _bindOnchain() {
    final accountId = widget.accountId;
    final loader = widget.finalizedBalanceLoader;
    if (loader == null) {
      _onchain = AccountBalanceSnapshotStore.forChain(
        context.read<CitizenSdk>(),
      ).accountState(accountId)..addListener(_changed);
    } else {
      // 既有布局测试注入仍复用相同状态机；正式页面始终绑定唯一余额所有者。
      _testBalance = WalletBalanceState(
        (_) async => BigInt.from((await loader(accountId) * 100).round()),
      )..addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _unbind() {
    _onchain?.removeListener(_changed);
    _clearing?.removeListener(_changed);
    _testBalance?.removeListener(_changed);
    _onchain = null;
    _clearing = null;
    _testBalance = null;
  }

  @override
  void didUpdateWidget(covariant WalletActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.accountAddress != widget.accountAddress ||
        oldWidget.finalizedBalanceLoader != widget.finalizedBalanceLoader) {
      _unbind();
      _binding = null;
      _bindingLoaded = false;
      _bindOnchain();
      unawaited(refresh(forceRefresh: false));
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  Future<void> refresh({bool forceRefresh = true}) async {
    final accountId = widget.accountId;
    final onchainFuture =
        _onchain?.load(forceRefresh: forceRefresh) ??
        _testBalance!.load(forceRefresh: forceRefresh);
    final binding = await ClearingBankPrefs.loadSnapshot(accountId);
    if (!mounted || widget.accountId != accountId) return;
    _clearing?.removeListener(_changed);
    _binding = binding;
    _bindingLoaded = true;
    _clearing = binding == null
        ? null
        : AccountBalanceSnapshotStore.forChain(context.read<CitizenSdk>())
              .clearingState(
                accountId: accountId,
                accountAddress: widget.accountAddress,
                wssUrl: binding.wssUrl,
              );
    _clearing?.addListener(_changed);
    setState(() {});
    await Future.wait([
      onchainFuture,
      if (_clearing != null) _clearing!.load(forceRefresh: forceRefresh),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet-action-card'),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: widget.hasOuterCard
            ? null
            : const Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      padding: EdgeInsets.symmetric(
        vertical: AppLayout.scaled(context, 20),
        horizontal: AppLayout.scaled(context, 12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 沿用原来三等列的宽度，右侧竖线位置不因左侧合并余额而移动。
          final column = (constraints.maxWidth - 2) / 3;
          return Row(
            children: [
              SizedBox(
                width: column * 2 + 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _RechargeAction(
                            token: 'USDT',
                            onTap: () => _openTopup(context, 'USDT'),
                          ),
                        ),
                        const _ActionDivider(
                          key: ValueKey('wallet-topup-divider'),
                          height: 56,
                        ),
                        Expanded(
                          child: _RechargeAction(
                            token: 'USDC',
                            onTap: () => _openTopup(context, 'USDC'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppLayout.scaled(context, 4)),
                    Text(
                      _onchainBalanceText,
                      key: const ValueKey('wallet-onchain-balance'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 12),
                        color: AppTheme.textTertiary,
                        height: AppLayout.subtitleLineHeight,
                      ),
                    ),
                  ],
                ),
              ),
              const _ActionDivider(key: ValueKey('wallet-petty-divider')),
              SizedBox(
                width: column,
                child: _BalanceAction(
                  balanceText: _balanceText,
                  onTap: () => _openPettyWallet(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openTopup(BuildContext context, String token) async {
    if (_topupOpening) return;
    _topupOpening = true;
    final account = widget.accountId;
    try {
      final paid = await context.read<WalletNavigation>().topup(
        context,
        accountId: account,
        token: token,
      );
      if (mounted && widget.accountId == account)
        await refresh(forceRefresh: paid == true);
    } finally {
      _topupOpening = false;
    }
  }

  /// 零钱包 = 进清算行零钱包详情页(余额 + 充值到零钱包 + 提现);需已绑定。
  Future<void> _openPettyWallet(BuildContext context) async {
    final binding = _binding;
    if (binding == null) {
      _showNeedBinding(context);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => context.read<WalletNavigation>().pettyWallet(
          accountId: widget.accountId,
          accountAddress: widget.accountAddress,
          wssUrl: binding.wssUrl,
          displayTitle: binding.displayTitle,
        ),
      ),
    );
    await refresh(forceRefresh: false);
  }

  static void _showNeedBinding(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请先在“清算行”页面绑定清算行'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// 三列之间的轻量分隔线，只组织视觉关系，不形成新的卡片。
class _ActionDivider extends StatelessWidget {
  const _ActionDivider({super.key, this.height = 88});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: AppLayout.scaled(context, height),
      color: AppTheme.divider,
    );
  }
}

/// 两个币种复用现有带圆底SVG；图文加共有余额不超过原96设计高度，长竖线不移位。
class _RechargeAction extends StatelessWidget {
  const _RechargeAction({required this.token, required this.onTap});
  final String token;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: AppLayout.scaled(context, 74)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'packages/citizen_assets/icons/${token.toLowerCase()}.svg',
              width: AppLayout.scaled(context, 48),
              height: AppLayout.scaled(context, 48),
              excludeFromSemantics: true,
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            Text(
              '充值/$token',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 14),
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
                height: AppLayout.compactLineHeight,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BalanceAction extends StatelessWidget {
  const _BalanceAction({required this.balanceText, required this.onTap});

  final String balanceText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: AppLayout.scaled(context, 96)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppLayout.scaled(context, 48),
                height: AppLayout.scaled(context, 48),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: AppLayout.scaled(context, 26),
                  color: AppTheme.primaryDark,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 8)),
              Text(
                '零钱包',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                  height: AppLayout.compactLineHeight,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 4)),
              Text(
                balanceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: AppTheme.textTertiary,
                  height: AppLayout.subtitleLineHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
