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
    this.onTopupPaid,
  });

  /// 该账户链账户主键(0x+64hex):充值目标、清算行绑定缓存键、按账户签名均以它为准。
  final String accountId;

  /// 该账户 SS58 地址,用于查询清算行存款余额。
  final String accountAddress;

  /// 到账后由详情页刷新顶部余额和记录，操作区不再保存链上金额显示状态。
  final Future<void> Function()? onTopupPaid;

  @override
  State<WalletActionCard> createState() => WalletActionCardState();
}

class WalletActionCardState extends State<WalletActionCard> {
  ClearingBankBindingSnapshot? _binding;
  bool _bindingLoaded = false;
  bool _topupOpening = false;
  WalletBalanceState<BigInt>? _clearing;

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
    unawaited(refresh(forceRefresh: false));
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _unbind() {
    _clearing?.removeListener(_changed);
    _clearing = null;
  }

  @override
  void didUpdateWidget(covariant WalletActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.accountAddress != widget.accountAddress) {
      _unbind();
      _binding = null;
      _bindingLoaded = false;
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
    await _clearing?.load(forceRefresh: forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet-action-card'),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      padding: EdgeInsets.symmetric(
        vertical: AppLayout.scaled(context, 20),
        horizontal: AppLayout.scaled(context, 12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _RechargeAction(
              token: 'USDT',
              onTap: () => _openTopup(context, 'USDT'),
            ),
          ),
          const _ActionDivider(lineKey: ValueKey('wallet-topup-divider')),
          Expanded(
            child: _RechargeAction(
              token: 'USDC',
              onTap: () => _openTopup(context, 'USDC'),
            ),
          ),
          const _ActionDivider(lineKey: ValueKey('wallet-petty-divider')),
          Expanded(
            child: _BalanceAction(
              balanceText: _balanceText,
              onTap: () => _openPettyWallet(context),
            ),
          ),
        ],
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
      if (mounted && widget.accountId == account) {
        if (paid == true) {
          await widget.onTopupPaid?.call();
        } else {
          await refresh(forceRefresh: false);
        }
      }
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

/// 两条竖线统一高40，始终居于48高图标槽正中，不随文字或余额下移。
class _ActionDivider extends StatelessWidget {
  const _ActionDivider({required this.lineKey});
  final Key lineKey;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1,
    height: AppLayout.scaled(context, 48),
    child: Center(
      child: Container(
        key: lineKey,
        width: 1,
        height: AppLayout.scaled(context, 40),
        color: AppTheme.divider,
      ),
    ),
  );
}

/// 充值图标和文字自然排版；三项都从图标顶端对齐，金额仍跨左侧两列。
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
  );
}

/// 零钱包与两个稳定币入口统一为48实色圆底白图形，继续使用原绑定和点击回调。
class _BalanceAction extends StatelessWidget {
  const _BalanceAction({required this.balanceText, required this.onTap});
  final String balanceText;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('wallet-petty-icon'),
            width: AppLayout.scaled(context, 48),
            height: AppLayout.scaled(context, 48),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: AppLayout.scaled(context, 26),
              color: Colors.white,
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
  );
}
