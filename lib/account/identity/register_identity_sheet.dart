import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:flutter/material.dart';

import 'package:citizenapp/account/identity/cid_generator.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/transaction/topup/onchain_topup_page.dart';
import 'package:citizenapp/system/theme/app_layout.dart';

/// 「注册身份」的选择结果:主体类型 + 绑定的钱包账户。
class RegisterChoice {
  const RegisterChoice({
    required this.institution,
    required this.bindAccountId,
  });

  /// [kCidInstitutionCitizen](公民)/ [kCidInstitutionResident](居民)。
  final String institution;

  /// CID 绑定的钱包账户 accountId(鉴权凭证,可任意 `//n`;私钥泄漏可换绑)。
  final String bindAccountId;
}

/// 提交结果只携带安全的页面状态；余额不足的充值目标始终取本页所选账户。
final class RegistrationSubmitOutcome {
  const RegistrationSubmitOutcome.success(this.message)
    : registered = true,
      recharge = false;
  const RegistrationSubmitOutcome.failure(this.message, {this.recharge = false})
    : registered = false;

  final bool registered;
  final bool recharge;
  final String message;
}

/// 注册身份面板在真人验证、链交易和失败后保持挂载；正常流程只在成功或主动取消时关闭。
/// 外层 WalletGate 在钱包被清空时仍可主动清栈回初始化页。
/// [accounts] 来自 WalletGate 已放行的钱包；充值只进入本页选择的绑定账户。
Future<bool?> showRegisterIdentitySheet(
  BuildContext context, {
  required List<CitizenWalletStateAccount> accounts,
  required Future<RegistrationSubmitOutcome> Function(
    BuildContext sheetContext,
    RegisterChoice choice,
  ) onSubmit,
  Future<void> Function(BuildContext, String)? openTopup,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => RegisterIdentitySheet(
      accounts: accounts,
      onSubmit: onSubmit,
      openTopup: openTopup,
    ),
  );
}

class RegisterIdentitySheet extends StatefulWidget {
  const RegisterIdentitySheet({
    super.key,
    required this.accounts,
    required this.onSubmit,
    this.openTopup,
  });

  final List<CitizenWalletStateAccount> accounts;
  final Future<RegistrationSubmitOutcome> Function(
    BuildContext sheetContext,
    RegisterChoice choice,
  ) onSubmit;
  final Future<void> Function(BuildContext, String)? openTopup;

  @override
  State<RegisterIdentitySheet> createState() => _RegisterIdentitySheetState();
}

class _RegisterIdentitySheetState extends State<RegisterIdentitySheet> {
  bool _submitted = false;
  String? _error;
  String _institution = kCidInstitutionCitizen;
  late final List<CitizenWalletStateAccount> _sortedAccounts;
  late String _bindAccountId;

  @override
  void initState() {
    super.initState();
    _sortedAccounts = [...widget.accounts]
      ..sort(
        (a, b) => (a.accountIndex ?? 0x7fffffff).compareTo(
          b.accountIndex ?? 0x7fffffff,
        ),
      );
    // 默认绑账户0(序号最小者);列表为空是异常兜底,留空由 service 拒。
    _bindAccountId = _sortedAccounts.isEmpty
        ? ''
        : _sortedAccounts.first.accountId;
  }

  Future<void> _submit() async {
    if (_submitted || _sortedAccounts.isEmpty) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    final choice = RegisterChoice(
      institution: _institution,
      bindAccountId: _bindAccountId,
    );
    try {
      final outcome = await widget.onSubmit(context, choice);
      if (!mounted) return;
      if (outcome.registered) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = outcome.message);
      if (outcome.recharge) {
        try {
          await (widget.openTopup ?? _openTopup)(context, choice.bindAccountId);
        } on Object {
          if (mounted) {
            setState(() => _error = '${outcome.message}；链上充值页面暂时无法打开');
          }
        }
      }
    } on Object {
      if (mounted) setState(() => _error = '注册暂时无法完成，请重试');
    } finally {
      if (mounted) setState(() => _submitted = false);
    }
  }

  Future<void> _openTopup(BuildContext context, String accountId) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OnchainTopupPage(accountId: accountId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      // 验证、交易和激活期间不允许系统返回关闭面板；空闲时可主动取消。
      canPop: !_submitted,
      child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: AppLayout.scaled(context, 36),
                  height: AppLayout.scaled(context, 4),
                  margin: EdgeInsets.only(
                    bottom: AppLayout.scaled(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(2),
                    ),
                  ),
                ),
              ),
              Text(
                '注册身份',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 17),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 6)),
              Text(
                '占用一个匿名身份 CID 号并绑定到你选的钱包账户,自付最低链上费。身份主键是'
                'CID 号,绑定账户只是鉴权凭证——私钥泄漏可换绑到新账户,CID 不丢失。',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 16)),
              const _SectionLabel('主体类型'),
              SizedBox(height: AppLayout.scaled(context, 8)),
              _TypeOption(
                label: '公民',
                code: kCidInstitutionCitizen,
                desc: '可后续到注册局线下升级为投票 / 竞选公民。',
                selected: _institution == kCidInstitutionCitizen,
                onTap: () =>
                    setState(() => _institution = kCidInstitutionCitizen),
              ),
              SizedBox(height: AppLayout.scaled(context, 10)),
              _TypeOption(
                label: '居民',
                code: kCidInstitutionResident,
                desc: '永久匿名身份,不可升级为投票 / 竞选公民。',
                selected: _institution == kCidInstitutionResident,
                onTap: () =>
                    setState(() => _institution = kCidInstitutionResident),
              ),
              if (_sortedAccounts.length > 1) ...[
                SizedBox(height: AppLayout.scaled(context, 16)),
                const _SectionLabel('绑定钱包账户'),
                SizedBox(height: AppLayout.scaled(context, 8)),
                ..._sortedAccounts.map(
                  (account) => Padding(
                    padding: EdgeInsets.only(
                      bottom: AppLayout.scaled(context, 8),
                    ),
                    child: _AccountRadio(
                      account: account,
                      selected: _bindAccountId == account.accountId,
                      onTap: () =>
                          setState(() => _bindAccountId = account.accountId),
                    ),
                  ),
                ),
              ],
              SizedBox(height: AppLayout.scaled(context, 14)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: AppTheme.bannerDecoration(AppTheme.warning),
                child: Text(
                  '自助注册只产生匿名身份。投票公民、竞选公民只能在对应注册局线下注册,'
                  '本页无法自助升级。',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 12),
                    height: 1.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 16)),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger),
                ),
                SizedBox(height: AppLayout.scaled(context, 12)),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _submitted
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: AppLayout.scaled(context, 46),
                child: FilledButton(
                  onPressed: _submitted || _sortedAccounts.isEmpty ? null : _submit,
                  child: Text(_submitted ? '注册中…' : '确认注册'),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: AppLayout.scaled(context, 12),
        color: AppTheme.textTertiary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 主体类型选项卡:选中态描边加粗、附机构码与说明。
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.code,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.border;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  AppTheme.primary.withAlpha(10),
                  AppTheme.surfaceCard,
                )
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : AppTheme.textTertiary,
              size: AppLayout.scaled(context, 20),
            ),
            SizedBox(width: AppLayout.scaled(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 15),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(width: AppLayout.scaled(context, 8)),
                      Text(
                        code,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          fontFamily: 'monospace',
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppLayout.scaled(context, 3)),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 绑定账户单选行:账户名 + 序号 + 短地址。
class _AccountRadio extends StatelessWidget {
  const _AccountRadio({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final CitizenWalletStateAccount account;
  final bool selected;
  final VoidCallback onTap;

  String get _shortAddress {
    final value = account.ss58Address;
    if (value.length <= 18) return value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.border;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : AppTheme.textTertiary,
              size: AppLayout.scaled(context, 20),
            ),
            SizedBox(width: AppLayout.scaled(context, 12)),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 14),
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: AppLayout.scaled(context, 8)),
                  Text(
                    '#${account.accountIndex}',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _shortAddress,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 11),
                fontFamily: 'monospace',
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
