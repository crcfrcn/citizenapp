import 'dart:async';

import 'package:citizen_offchain/clearing_bank_directory.dart';
import 'package:citizen_offchain/offchain_clearing_rpc.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:citizen_offchain/deposit_page.dart';
import 'package:citizen_offchain/withdraw_page.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 零钱包详情页(链下清算行零钱包)。
///
/// 从账户详情「零钱包」按钮进入。承接原动作卡上的「充值到清算行」入口,并提供:
/// - 零钱包余额(节点端 `offchain_queryBalance`);
/// - 充值到清算行(链上账户 → 清算行零钱包,原 `DepositPage`);
/// - 提现到链上(清算行 → 链上账户,`WithdrawPage`)。
/// 一律按 `account_id` 键控,单钱包多账户下每账户独立零钱包。
class PettyWalletPage extends StatefulWidget {
  const PettyWalletPage({
    super.key,
    required this.accountId,
  });

  /// 该账户链账户主键(0x+64hex)。
  final String accountId;

  @override
  State<PettyWalletPage> createState() => _PettyWalletPageState();
}

class _PettyWalletPageState extends State<PettyWalletPage> {
  late final ClearingBankDirectory _directory;
  ClearingBankBinding? _binding;
  ClearingBalance? _balance;
  bool _loading = true;
  bool _failed = false;
  bool _opening = false;
  int _bindingRead = 0;

  String get _balanceText {
    if (_loading) return '查询中';
    if (_failed) return '绑定待核对';
    if (_binding == null) return '未绑定';
    final value = _balance?.value;
    if (value != null) return '¥${formatFen(value)}';
    return _balance?.hasError == true ? '节点不可达' : '查询中';
  }

  @override
  void initState() {
    super.initState();
    _directory = context.read<ClearingBankDirectory?>() ??
        ClearingBankDirectory(chain: context.read<CitizenSdk>());
    unawaited(_loadBalance());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PettyWalletPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _binding = null;
      unawaited(_loadBalance());
    }
  }

  @override
  void dispose() {
    _balance?.removeListener(_changed);
    super.dispose();
  }

  // 下拉和返回都重新核对节点，再刷新当前清算行的余额。
  Future<void> _loadBalance({bool forceRefresh = false}) async {
    final accountId = widget.accountId;
    final read = ++_bindingRead;
    setState(() => _loading = true);
    ClearingBankBinding? bank;
    var failed = false;
    try {
      bank = await _directory.fetchUserBank(accountId);
    } catch (_) {
      failed = true;
    }
    if (!mounted || read != _bindingRead) return;
    _balance?.removeListener(_changed);
    final balance = bank == null
        ? null
        : ClearingBalances.instance.state(
            accountId: accountId,
            wssUrl: bank.endpoint.wssUrl,
          );
    balance?.addListener(_changed);
    setState(() {
      _binding = bank;
      _balance = balance;
      _loading = false;
      _failed = failed;
    });
    await balance?.load(forceRefresh: forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('零钱包'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () => _loadBalance(forceRefresh: true),
        child: ListView(
          padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: EdgeInsets.all(AppLayout.scaled(context, 20)),
              decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _binding?.title ?? '清算行',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 13),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppLayout.scaled(context, 10)),
                  Text(
                    _balanceText,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 28),
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  SizedBox(height: AppLayout.scaled(context, 4)),
                  Text(
                    '零钱包余额（链下清算行）',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 16)),
            _ActionTile(
              icon: Icons.arrow_circle_down_outlined,
              title: '充值到清算行',
              subtitle: '从链上账户转入清算行零钱包',
              onTap: () => _open(withdraw: false),
            ),
            SizedBox(height: AppLayout.scaled(context, 12)),
            _ActionTile(
              icon: Icons.arrow_circle_up_outlined,
              title: '提现到链上',
              subtitle: '从零钱包提现回链上账户',
              onTap: () => _open(withdraw: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open({required bool withdraw}) async {
    if (_opening) return;
    _opening = true;
    final accountId = widget.accountId;
    try {
      final reload = _loadBalance();
      final read = _bindingRead;
      await reload;
      if (!mounted || widget.accountId != accountId || read != _bindingRead) {
        return;
      }
      final bank = _binding;
      if (bank == null || _loading) {
        final message = _failed || _loading
            ? '无法核对当前清算行，请重试'
            : '请先绑定清算行';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => withdraw
              ? WithdrawPage(
                  accountId: accountId,
                  directory: _directory,
                  bank: bank,
                )
              : DepositPage(
                  accountId: accountId,
                  directory: _directory,
                  bank: bank,
                ),
        ),
      );
      if (mounted) await _loadBalance(forceRefresh: submitted == true);
    } finally {
      _opening = false;
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
          decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
          child: Row(
            children: [
              Container(
                width: AppLayout.scaled(context, 44),
                height: AppLayout.scaled(context, 44),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppLayout.scaled(context, 22),
                  color: AppTheme.primaryDark,
                ),
              ),
              SizedBox(width: AppLayout.scaled(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 16),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppLayout.scaled(context, 2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 12),
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppLayout.scaled(context, 18),
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
