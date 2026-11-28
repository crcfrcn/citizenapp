// 个人成员查询模型、编辑校验、变更签名与组件。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'dart:convert';
import 'package:citizen_citizen/proposal/data.dart' show ProposalRole;
import 'package:citizen_scanner/sign.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_widgets/balance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'accounts.dart';
import 'proposals.dart';
import 'chain.dart';
import 'storage.dart';

/// 个人成员以钱包账户识别；姓、名仅为备注，不参与地址派生或授权。
class PersonalMember {
  const PersonalMember({
    required this.accountId,
    required this.familyName,
    required this.givenName,
  });
  final String accountId;
  final String familyName;
  final String givenName;
  PersonalMember copyWith({
    String? accountId,
    String? familyName,
    String? givenName,
  }) => PersonalMember(
    accountId: accountId ?? this.accountId,
    familyName: familyName ?? this.familyName,
    givenName: givenName ?? this.givenName,
  );
}

// 个人成员查询身份，不接受机构CID。
class PersonalMemberIdentity {
  const PersonalMemberIdentity._(this.accountId, this.accountLabel);
  factory PersonalMemberIdentity.personalAccount({
    required String accountId,
    required String accountLabel,
  }) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('个人多签账户标识无效');
    }
    return PersonalMemberIdentity._(accountId, accountLabel);
  }
  factory PersonalMemberIdentity.fromAccount(PersonalAccountInfo account) =>
      PersonalMemberIdentity.personalAccount(
        accountId: account.accountId,
        accountLabel: account.shortName,
      );
  final String accountId;
  final String accountLabel;
  String get identityKey => 'personal-account:$accountId';
  String get orgCode => 'PMUL';
  int get kind => 2;
  String get typeLabel => '个人多签';
  String get orgLabel => '个人多签';
}

class PersonalMemberState {
  const PersonalMemberState({
    required this.accountId,
    required this.orgCode,
    required this.kind,
    required this.admins,
    required this.threshold,
    this.personalCreatorAccountId,
    this.personalCreatedAt,
    this.personalUpdatedAt,
    this.personalStatus,
  });

  final String accountId;
  final String orgCode;
  final int kind;
  final List<PersonalMember> admins;
  final int threshold;

  /// 以下字段只属于 Personal 的个人多签生命周期。
  final String? personalCreatorAccountId;
  final int? personalCreatedAt;
  final int? personalUpdatedAt;
  final int? personalStatus;

  bool get isActive => personalStatus == 1;

  PersonalMemberState copyWith({int? threshold}) => PersonalMemberState(
    accountId: accountId,
    orgCode: orgCode,
    kind: kind,
    admins: admins,
    threshold: threshold ?? this.threshold,
    personalCreatorAccountId: personalCreatorAccountId,
    personalCreatedAt: personalCreatedAt,
    personalUpdatedAt: personalUpdatedAt,
    personalStatus: personalStatus,
  );

  String get kindLabel => '个人多签';

  String get orgLabel => '个人多签';

  String get statusLabel {
    return switch (personalStatus) {
      0 => '待激活',
      1 => '已激活',
      2 => '已关闭',
      _ => '未知状态',
    };
  }
}

// 展示个人多签管理员及本人钱包可执行的激活投票。

/// 管理员行的激活按钮渲染状态。
enum _ActivateButtonState {
  /// 不显示按钮(创建者 / 非本钱包成员 / 多签已激活)。
  hidden,

  /// 蓝色"激活"可点(本钱包成员且未投票且多签待激活)。
  ready,

  /// 灰色"已激活"禁用(本钱包成员已投赞成)。
  alreadyApproved,

  /// 灰色"已拒绝"禁用(本钱包成员已投反对)。
  alreadyRejected,
}

class PersonalAdminListPage extends StatefulWidget {
  const PersonalAdminListPage({
    super.key,
    required this.account,
    required this.multisigStatus,
    required this.admins,
    required this.adminWallets,
    this.creatorAccount,
  });

  /// 多签元信息（名称与多签账户）。
  final PersonalAccountInfo account;

  /// 多签当前状态(Pending / Active)。
  final MultisigStatus multisigStatus;

  /// 完整管理员人员集合；权限和投票匹配只使用 `account_id`。
  final List<PersonalMember> admins;

  /// 用户本地能签名的 admin 钱包子集(由调用方过滤好)。
  final List<CitizenWalletStateAccount> adminWallets;

  /// 创建人规范 AccountId。req 3 未实现时只有创建者本机已知。
  final String? creatorAccount;

  @override
  State<PersonalAdminListPage> createState() => _PersonalAdminListPageState();
}

class _PersonalAdminListPageState extends State<PersonalAdminListPage> {
  late final PersonalProposalQueryService _proposalService;
  bool _dependenciesReady = false;
  final PersonalPendingCreateLookup _lookup = PersonalPendingCreateLookup();

  bool _loading = true;
  String? _error;
  BigInt? _proposalId;
  Map<String, bool?> _votes = const {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _proposalService = PersonalProposalQueryService(
      chain: context.read<CitizenSdk>(),
    );
    _dependenciesReady = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 多签已激活时无需查投票:激活按钮整体不显示。
      if (widget.multisigStatus != MultisigStatus.pending) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _proposalId = null;
          _votes = const {};
        });
        return;
      }

      final pid = await _lookup.findActiveCreate(widget.account.accountId);

      // 仅查本钱包持有的 admin 投票状态(其他人投票状态对 UI 无意义,节省 RPC)。
      final votes = <String, bool?>{};
      if (pid != null) {
        // 本机可能导入多个管理员钱包，用批量 storage 查询避免逐钱包 RPC。
        votes.addAll(
          await _proposalService.fetchAdminVotesBatch(
            pid,
            widget.adminWallets.map((wallet) => wallet.accountId),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _proposalId = pid;
        _votes = votes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  _ActivateButtonState _resolveButtonState(String adminAccountId) {
    // 多签已激活 → 全部隐藏
    if (widget.multisigStatus != MultisigStatus.pending) {
      return _ActivateButtonState.hidden;
    }
    // 创建者 → 隐藏(创建即同意)
    if (widget.creatorAccount != null &&
        widget.creatorAccount!.toLowerCase() == adminAccountId) {
      return _ActivateButtonState.hidden;
    }
    // 非本钱包持有的 admin → 隐藏(本机不能代签)
    final isLocalWallet = widget.adminWallets.any((w) {
      return w.accountId == adminAccountId;
    });
    if (!isLocalWallet) return _ActivateButtonState.hidden;
    // 找不到活跃创建提案(异常态)→ 不显示按钮
    if (_proposalId == null) return _ActivateButtonState.hidden;
    final vote = _votes[adminAccountId];
    if (vote == null) return _ActivateButtonState.ready;
    return vote
        ? _ActivateButtonState.alreadyApproved
        : _ActivateButtonState.alreadyRejected;
  }

  Future<void> _onActivatePressed() async {
    final pid = _proposalId;
    if (pid == null) return;
    final pushed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalProposalDetailPage(
          account: widget.account,
          proposalId: pid,
          proposalContext: PersonalProposalContext(
            account: widget.account,
            adminWallets: widget.adminWallets,
            role: ProposalRole.admin,
          ),
        ),
      ),
    );
    if (pushed == true && mounted) {
      // 投票完成 → 重读投票状态(可能本行变成"已激活")
      await _load();
    }
  }

  // ──── UI ────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '管理员列表',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: EdgeInsets.all(AppLayout.scaledValue(24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: AppLayout.scaledValue(36),
            color: AppTheme.textTertiary,
          ),
          SizedBox(height: AppLayout.scaledValue(12)),
          Text(
            _error!,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppLayout.scaledValue(16)),
          OutlinedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildHeaderCard(),
          SizedBox(height: AppLayout.scaledValue(16)),
          _buildAdminListCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(16)),
        child: Row(
          children: [
            const Icon(Icons.person, color: AppTheme.accent),
            SizedBox(width: AppLayout.scaledValue(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.account.shortName,
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(15),
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  SizedBox(height: AppLayout.scaledValue(2)),
                  Text(
                    widget.multisigStatus == MultisigStatus.active
                        ? '已激活 · ${widget.admins.length} 位管理员'
                        : '待激活 · ${widget.admins.length} 位管理员需逐一签名',
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(12),
                      color: AppTheme.textTertiary,
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

  Widget _buildAdminListCard() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Column(
        children: List.generate(widget.admins.length, (index) {
          final admin = widget.admins[index];
          final accountId = admin.accountId;
          final ss58 = _accountIdToSs58(accountId);
          final isCreator =
              widget.creatorAccount != null &&
              widget.creatorAccount!.toLowerCase() == accountId;
          final state = _resolveButtonState(accountId);
          return Column(
            children: [
              if (index > 0) const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  radius: AppLayout.scaledValue(16),
                  backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.08),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(12),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                title: Text('${admin.familyName}${admin.givenName}'),
                subtitle: Text(
                  isCreator ? '$ss58\n创建者' : ss58,
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(11),
                    fontFamily: 'monospace',
                    color: isCreator ? AppTheme.accent : null,
                  ),
                ),
                trailing: _buildActivateButton(state),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget? _buildActivateButton(_ActivateButtonState state) {
    switch (state) {
      case _ActivateButtonState.hidden:
        return null;
      case _ActivateButtonState.ready:
        return TextButton(
          onPressed: _onActivatePressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryDark,
            backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.08),
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaledValue(14),
              vertical: AppLayout.scaledValue(6),
            ),
            minimumSize: Size(0, AppLayout.scaledValue(32)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '激活',
            style: TextStyle(fontSize: AppLayout.scaledValue(13)),
          ),
        );
      case _ActivateButtonState.alreadyApproved:
        return const _DisabledTag(label: '已激活');
      case _ActivateButtonState.alreadyRejected:
        return const _DisabledTag(label: '已拒绝');
    }
  }

  /// 截断 SDK 返回的公民链地址，适配当前列表行宽。
  String _accountIdToSs58(String accountId) {
    try {
      final address = citizenSs58FromAccountId(accountId);
      if (address.length <= 24) return address;
      return '${address.substring(0, 12)}…${address.substring(address.length - 8)}';
    } on FormatException {
      return '地址无效';
    }
  }
}

class _DisabledTag extends StatelessWidget {
  const _DisabledTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 10),
        vertical: AppLayout.scaled(context, 4),
      ),
      decoration: BoxDecoration(
        color: AppTheme.textTertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppLayout.scaled(context, 12),
          color: AppTheme.textTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// 编辑管理员集合和阈值，校验后进入确认签名流程。

class PersonalMembersPage extends StatefulWidget {
  const PersonalMembersPage({
    super.key,
    required this.account,
    required this.accountIdentity,
    required this.adminWallets,
  });

  final PersonalAccountInfo account;
  final PersonalMemberIdentity accountIdentity;
  final List<CitizenWalletStateAccount> adminWallets;

  @override
  State<PersonalMembersPage> createState() => _AdminsChangePageState();
}

class _AdminsChangePageState extends State<PersonalMembersPage> {
  late final PersonalMemberService _accountService;
  late final PersonalMembersService _changeService;
  bool _dependenciesReady = false;
  final _thresholdController = TextEditingController();
  PersonalMemberState? _subject;
  List<PersonalMember> _admins = const [];
  CitizenWalletStateAccount? _selectedWallet;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedWallet = widget.adminWallets.isNotEmpty
        ? widget.adminWallets.first
        : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk>();
    _accountService = PersonalMemberService(chain: sdk);
    _changeService = PersonalMembersService(transactions: sdk);
    _dependenciesReady = true;
    _load();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await _accountService.fetchByIdentity(
        widget.accountIdentity,
      );
      if (!mounted) return;
      setState(() {
        _subject = account;
        _admins = account?.admins ?? const <PersonalMember>[];
        if (account != null) _syncThresholdInput(account, _admins.length);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: [
      ...?_subject?.admins,
      ..._admins,
    ].map((admin) => admin.accountId),
    builder: _buildBalanceView,
  );

  Widget _buildBalanceView(BuildContext context, CitizenBalances balances) {
    final account = _subject;
    final balanceByAccountId = <String, BigInt>{
      for (final admin in [...?_subject?.admins, ..._admins])
        if (balances.accountState(admin.accountId).value != null)
          admin.accountId: balances
              .accountState(admin.accountId)
              .value!
              .freeFen,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('更换管理员')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : account == null
          ? Center(child: Text(_error ?? '未查询到管理员账户'))
          : ListView(
              padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
              children: [
                PersonalMembersCard(account: account),
                SizedBox(height: AppLayout.scaled(context, 12)),
                _buildWalletSelector(),
                SizedBox(height: AppLayout.scaled(context, 12)),
                PersonalMembersEditor(
                  admins: _admins,
                  balances: balanceByAccountId,
                  onChanged: (value) => _setNewAdmins(account, value),
                ),
                SizedBox(height: AppLayout.scaled(context, 12)),
                _buildThresholdCard(account),
                SizedBox(height: AppLayout.scaled(context, 12)),
                PersonalMembersDiffCard(
                  currentAdmins: account.admins,
                  admins: _admins,
                  balances: balanceByAccountId,
                ),
                if (_error != null) ...[
                  SizedBox(height: AppLayout.scaled(context, 12)),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
      bottomNavigationBar: account == null
          ? null
          : PersonalMembersActionBar(
              busy: _submitting,
              enabled: _selectedWallet != null,
              onSubmit: _submit,
            ),
    );
  }

  Widget _buildWalletSelector() {
    return DropdownButtonFormField<CitizenWalletStateAccount>(
      initialValue: _selectedWallet,
      decoration: const InputDecoration(labelText: '发起管理员钱包'),
      items: widget.adminWallets
          .map(
            (wallet) =>
                DropdownMenuItem(value: wallet, child: Text(wallet.name)),
          )
          .toList(),
      onChanged: _submitting
          ? null
          : (wallet) => setState(() => _selectedWallet = wallet),
    );
  }

  void _setNewAdmins(PersonalMemberState account, List<PersonalMember> value) {
    setState(() {
      _admins = value;
      _syncThresholdInput(account, value.length);
    });
  }

  Widget _buildThresholdCard(PersonalMemberState account) {
    final min = _admins.isEmpty
        ? 0
        : PersonalMembersValidation.minimumDynamicThreshold(_admins.length);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(14)),
        child: TextField(
          controller: _thresholdController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '通过阈值',
            helperText: _admins.isEmpty
                ? '请先添加管理员'
                : '范围：$min ~ ${_admins.length}',
          ),
        ),
      ),
    );
  }

  void _syncThresholdInput(PersonalMemberState account, int adminsLen) {
    if (adminsLen <= 0) {
      _thresholdController.clear();
      return;
    }
    final min = PersonalMembersValidation.minimumDynamicThreshold(adminsLen);
    final current = int.tryParse(_thresholdController.text.trim());
    if (current == null || current < min || current > adminsLen) {
      _thresholdController.text = adminsLen.toString();
    }
  }

  int _readNewThreshold(PersonalMemberState account) {
    final value = int.tryParse(_thresholdController.text.trim());
    if (value == null) throw StateError('请输入有效阈值');
    return value;
  }

  Future<void> _submit() async {
    final account = _subject;
    final wallet = _selectedWallet;
    if (account == null || wallet == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final newThreshold = _readNewThreshold(account);
      final validated = PersonalMembersValidation.validate(
        account: account,
        proposerAccountId: wallet.accountId,
        admins: _admins,
        newThreshold: newThreshold,
      );
      final result = await _changeService.submit(
        account: account,
        admins: validated.admins,
        newThreshold: validated.threshold,
        signerPublicKey: citizenAccountIdBytes(wallet.accountId),
        externalSigning: (pending) => showCitizenSdkQrResponse(
          context,
          request: pending.qrRequest,
          expiresAt: BigInt.from(
            pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );
      _accountService.clearPersonalAccountCache(account.accountId);
      _accountService.clearCache(widget.accountIdentity);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PersonalMembersConfirmPage(txHash: result.txHash),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// 展示管理员集合差异及阈值，确认后提交治理变更。

class PersonalMembersConfirmPage extends StatelessWidget {
  const PersonalMembersConfirmPage({super.key, required this.txHash});

  final String txHash;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理员更换')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: AppLayout.scaled(context, 56),
                color: Colors.green,
              ),
              SizedBox(height: AppLayout.scaled(context, 12)),
              const Text('管理员更换提案已提交'),
              SizedBox(height: AppLayout.scaled(context, 8)),
              SelectableText(txHash, textAlign: TextAlign.center),
              SizedBox(height: AppLayout.scaled(context, 16)),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 展示管理员集合变更的提交和取消动作栏。

class PersonalMembersActionBar extends StatelessWidget {
  const PersonalMembersActionBar({
    super.key,
    required this.busy,
    required this.enabled,
    required this.onSubmit,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        child: FilledButton(
          onPressed: busy || !enabled ? null : onSubmit,
          child: Text(busy ? '提交中…' : '发起管理员更换'),
        ),
      ),
    );
  }
}

// 编辑管理员列表，协调姓名、账户和阈值输入。

class PersonalMembersEditor extends StatefulWidget {
  const PersonalMembersEditor({
    super.key,
    required this.admins,
    this.balances = const {},
    required this.onChanged,
  });

  final List<PersonalMember> admins;
  final Map<String, BigInt> balances;
  final ValueChanged<List<PersonalMember>> onChanged;

  @override
  State<PersonalMembersEditor> createState() => _AdminSetEditorState();
}

class _AdminSetEditorState extends State<PersonalMembersEditor> {
  final _accountController = TextEditingController();
  final _familyNameController = TextEditingController(text: '管理');
  final _givenNameController = TextEditingController(text: '员');

  @override
  void dispose() {
    _accountController.dispose();
    _familyNameController.dispose();
    _givenNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        child: Column(
          children: [
            for (var i = 0; i < widget.admins.length; i++) ...[
              _buildAdminEditor(i),
              SizedBox(height: AppLayout.scaled(context, 8)),
            ],
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: '管理员公钥 hex'),
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _familyNameController,
                    decoration: const InputDecoration(labelText: '姓'),
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                Expanded(
                  child: TextField(
                    controller: _givenNameController,
                    decoration: const InputDecoration(labelText: '名'),
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                FilledButton(onPressed: _add, child: const Text('添加')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminEditor(int index) {
    final admin = widget.admins[index];
    return Container(
      padding: EdgeInsets.all(AppLayout.scaledValue(10)),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${index + 1}'),
              SizedBox(width: AppLayout.scaledValue(8)),
              Expanded(child: Text(citizenSs58FromAccountId(admin.accountId))),
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: '移除',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => widget.onChanged([
                  for (var i = 0; i < widget.admins.length; i++)
                    if (i != index) widget.admins[i],
                ]),
              ),
            ],
          ),
          Text(
            '余额：${(widget.balances[admin.accountId] == null ? '--' : formatFen(widget.balances[admin.accountId]!))} 元',
          ),
          SizedBox(height: AppLayout.scaledValue(8)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('${admin.accountId}-$index-family'),
                  initialValue: admin.familyName,
                  decoration: const InputDecoration(labelText: '姓'),
                  onChanged: (value) =>
                      _updateName(index, admin.copyWith(familyName: value)),
                ),
              ),
              SizedBox(width: AppLayout.scaledValue(8)),
              Expanded(
                child: TextFormField(
                  key: ValueKey('${admin.accountId}-$index-given'),
                  initialValue: admin.givenName,
                  decoration: const InputDecoration(labelText: '名'),
                  onChanged: (value) =>
                      _updateName(index, admin.copyWith(givenName: value)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateName(int index, PersonalMember next) {
    widget.onChanged([
      for (var i = 0; i < widget.admins.length; i++)
        if (i == index) next else widget.admins[i],
    ]);
  }

  void _add() {
    final clean = _accountController.text.trim();
    if (!isCitizenAccountId(clean) ||
        widget.admins.any((admin) => admin.accountId == clean)) {
      return;
    }
    widget.onChanged([
      ...widget.admins,
      PersonalMember(
        accountId: clean,
        familyName: _familyNameController.text.trim().isEmpty
            ? '管理'
            : _familyNameController.text.trim(),
        givenName: _givenNameController.text.trim().isEmpty
            ? '员'
            : _givenNameController.text.trim(),
      ),
    ]);
    _accountController.clear();
    _familyNameController.text = '管理';
    _givenNameController.text = '员';
  }
}

// 展示管理员增加、移除及变更前后差异。

class PersonalMembersDiffCard extends StatelessWidget {
  const PersonalMembersDiffCard({
    super.key,
    required this.currentAdmins,
    required this.admins,
    this.balances = const {},
  });

  final List<PersonalMember> currentAdmins;
  final List<PersonalMember> admins;
  final Map<String, BigInt> balances;

  @override
  Widget build(BuildContext context) {
    final current = {for (final admin in currentAdmins) admin.accountId: admin};
    final next = {for (final admin in admins) admin.accountId: admin};
    final added = next.entries
        .where((entry) => !current.containsKey(entry.key))
        .map((entry) => entry.value)
        .toList();
    final removed = current.entries
        .where((entry) => !next.containsKey(entry.key))
        .map((entry) => entry.value)
        .toList();
    final renamed = next.entries
        .where((entry) {
          final old = current[entry.key];
          return old != null &&
              (old.familyName != entry.value.familyName ||
                  old.givenName != entry.value.givenName);
        })
        .map((entry) => entry.value)
        .toList();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '变更差异',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            _buildAccountList('新增', added),
            SizedBox(height: AppLayout.scaled(context, 8)),
            _buildAccountList('移除', removed),
            SizedBox(height: AppLayout.scaled(context, 8)),
            _buildAccountList('姓名调整', renamed),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList(String title, List<PersonalMember> admins) {
    if (admins.isEmpty) return Text('$title：无');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title：'),
        SizedBox(height: AppLayout.scaledValue(6)),
        for (final admin in admins) ...[
          ListTile(
            dense: true,
            title: Text('${admin.familyName}${admin.givenName}'),
            subtitle: Text(
              '${citizenSs58FromAccountId(admin.accountId)}\n'
              '余额：${(balances[admin.accountId] == null ? '--' : formatFen(balances[admin.accountId]!))} 元',
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(6)),
        ],
      ],
    );
  }
}

// 展示管理员账户、姓名及相关状态的共用卡片。

class PersonalMembersCard extends StatelessWidget {
  const PersonalMembersCard({super.key, required this.account});

  final PersonalMemberState account;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.kindLabel,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppLayout.scaled(context, 4)),
                  Text(
                    '管理员 ${account.admins.length} 人，阈值 ${account.threshold}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Chip(label: Text(account.statusLabel)),
          ],
        ),
      ),
    );
  }
}

// 校验并编码管理员集合变更，将通用准备及冷热执行交给SDK。

/// 本服务校验并编码管理员集合变更业务 RuntimeCall，再委托 CitizenSDK 准备和执行通用交易；
/// 热签、QR_V1 冷签和链上终态观察均由 SDK 提供，不在 CitizenApp 业务层重复实现。
class PersonalMembersService {
  PersonalMembersService({
    CitizenSdk? transactions,
    CitizenCallBuilder? buildCall,
    Future<CitizenPreparedTransaction> Function(
      Uint8List sourceAccountId,
      Uint8List callData,
    )?
    prepareTransaction,
    Future<CitizenTransactionExecution> Function(String preparationId)?
    executePreparedTransaction,
    Future<void> Function(String executionId)?
    cancelPreparedTransactionExecution,
    Future<CitizenTransactionExecutionCompleted> Function(
      String executionId,
      String response,
    )?
    consumePreparedTransactionQrResponse,
  }) : _buildCall =
           buildCall ??
           transactions?.buildCall ??
           ((pallet, method, fields) => throw StateError('未配置buildCall')),
       _prepareTransaction =
           prepareTransaction ??
           transactions?.prepareTransaction ??
           ((Uint8List sourceAccountId, Uint8List callData) =>
               throw StateError('未配置prepareTransaction')),
       _executePreparedTransaction =
           executePreparedTransaction ??
           transactions?.executePreparedTransaction ??
           ((String preparationId) =>
               throw StateError('未配置executePreparedTransaction')),
       _cancelPreparedTransactionExecution =
           cancelPreparedTransactionExecution ??
           transactions?.cancelPreparedTransactionExecution ??
           ((String executionId) =>
               throw StateError('未配置cancelPreparedTransactionExecution')),
       _consumePreparedTransactionQrResponse =
           consumePreparedTransactionQrResponse ??
           transactions?.consumePreparedTransactionQrResponse ??
           ((String executionId, String response) =>
               throw StateError('未配置consumePreparedTransactionQrResponse'));
  final CitizenCallBuilder _buildCall;
  final Future<CitizenPreparedTransaction> Function(
    Uint8List sourceAccountId,
    Uint8List callData,
  )
  _prepareTransaction;
  final Future<CitizenTransactionExecution> Function(String preparationId)
  _executePreparedTransaction;
  final Future<void> Function(String executionId)
  _cancelPreparedTransactionExecution;
  final Future<CitizenTransactionExecutionCompleted> Function(
    String executionId,
    String response,
  )
  _consumePreparedTransactionQrResponse;

  Future<Uint8List> buildCallData({
    required PersonalMemberState account,
    required String proposerAccountId,
    required List<PersonalMember> admins,
    required int newThreshold,
  }) {
    final normalized = PersonalMembersValidation.validate(
      account: account,
      proposerAccountId: proposerAccountId,
      admins: admins,
      newThreshold: newThreshold,
    );
    return PersonalMembersCallCodec.build(
      buildCall: _buildCall,
      orgCode: account.orgCode,
      adminKind: account.kind,
      accountId: citizenAccountIdBytes(account.accountId),
      admins: normalized.admins,
      newThreshold: normalized.threshold,
    );
  }

  Future<PersonalMembersSubmitResult> submit({
    required PersonalMemberState account,
    required List<PersonalMember> admins,
    required int newThreshold,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (signerPublicKey.length != 32) throw ArgumentError('签名公钥必须为32字节');
    final callData = await buildCallData(
      account: account,
      proposerAccountId: citizenAccountIdFromBytes(signerPublicKey),
      admins: admins,
      newThreshold: newThreshold,
    );
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    final started = await _executePreparedTransaction(prepared.preparationId);
    final completed = await completeCitizenTransaction(
      started,
      requestResponse: externalSigning,
      consumeResponse: _consumePreparedTransactionQrResponse,
      cancelExecution: _cancelPreparedTransactionExecution,
    );
    if (completed == null) throw StateError('管理员更换签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null ||
        completed.execution!.status != CitizenExecutionStatus.success ||
        completed.execution!.block.finality != CitizenBlockFinality.finalized) {
      throw StateError(completed.poolRejectionReason ?? '管理员更换交易执行失败');
    }
    return PersonalMembersSubmitResult(
      txHash:
          '0x${completed.transactionHash.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}',
    );
  }
}

// 编码个人多签管理员集合及阈值变更调用。

class PersonalMembersCallCodec {
  PersonalMembersCallCodec._();

  static Future<Uint8List> build({
    required CitizenCallBuilder buildCall,
    required String orgCode,
    required int adminKind,
    required Uint8List accountId,
    required List<PersonalMember> admins,
    required int newThreshold,
  }) {
    if (accountId.length != 32) {
      throw ArgumentError('accountId 必须为 32 字节');
    }
    if (orgCode != 'PMUL' || adminKind != 2) {
      throw ArgumentError('机构管理员由 entity 任职结果管理；本调用只允许个人多签');
    }
    if (newThreshold <= 0) {
      throw ArgumentError('newThreshold 必须大于 0');
    }
    final encodedAdmins = <List<Object>>[];
    for (final admin in admins) {
      final bytes = citizenAccountIdBytes(admin.accountId);
      if (bytes.length != 32) {
        throw ArgumentError('管理员公钥必须为 32 字节');
      }
      encodedAdmins.add([
        bytes,
        _nameBytes(admin.familyName, 'family_name'),
        _nameBytes(admin.givenName, 'given_name'),
      ]);
    }
    return buildCall('Personal', 'propose_admin_set_change', [
      Uint8List.fromList(utf8.encode(orgCode)),
      accountId,
      encodedAdmins,
      newThreshold,
    ]);
  }

  static Uint8List _nameBytes(String value, String field) {
    final bytes = utf8.encode(value.trim());
    if (bytes.isEmpty || bytes.length > 128) {
      throw ArgumentError('$field 长度必须在 1..=128 字节');
    }
    return Uint8List.fromList(bytes);
  }
}

// 表示管理员集合变更提交后的公开执行结果。

class PersonalMembersSubmitResult {
  const PersonalMembersSubmitResult({required this.txHash});

  final String txHash;
}

// 前置校验管理员唯一性、容量及个人普通阈值范围。

class PersonalMembersValidationResult {
  const PersonalMembersValidationResult({
    required this.admins,
    required this.threshold,
  });

  final List<PersonalMember> admins;
  final int threshold;
}

class PersonalMembersValidation {
  PersonalMembersValidation._();

  static PersonalMembersValidationResult validate({
    required PersonalMemberState account,
    required String proposerAccountId,
    required List<PersonalMember> admins,
    required int newThreshold,
  }) {
    if (!account.isActive) {
      throw StateError('管理员账户不是已激活状态');
    }
    if (account.kind != 2 || account.orgCode != 'PMUL') {
      throw StateError('机构管理员由 entity 任职结果管理；本流程只允许个人多签');
    }
    final proposer = _requireAccountId(proposerAccountId);
    if (!account.admins.any((admin) => admin.accountId == proposer)) {
      throw StateError('当前签名钱包不是该主体管理员');
    }
    final normalized = admins
        .map(
          (admin) => PersonalMember(
            accountId: _requireAccountId(admin.accountId),
            familyName: _normalizeName(admin.familyName, '管理', '姓'),
            givenName: _normalizeName(admin.givenName, '员', '名'),
          ),
        )
        .toList(growable: false);
    _validateCount(account.kind, account.orgCode, normalized.length);
    final nextAccountIds = normalized.map((admin) => admin.accountId).toSet();
    if (nextAccountIds.length != normalized.length) {
      throw StateError('新管理员列表存在重复公钥');
    }
    if (_sameAdmins(account.admins, normalized) &&
        newThreshold == account.threshold) {
      throw StateError('新管理员集合与当前集合没有变化');
    }
    _validateThreshold(
      account.kind,
      account.orgCode,
      normalized.length,
      newThreshold,
    );
    return PersonalMembersValidationResult(
      admins: normalized,
      threshold: newThreshold,
    );
  }

  static int minimumDynamicThreshold(int adminsLen) {
    return 1;
  }

  static String _requireAccountId(String value) {
    if (!isCitizenAccountId(value)) {
      throw const FormatException('管理员账户标识无效');
    }
    return value;
  }

  static String _normalizeName(String value, String fallback, String label) {
    final normalized = value.trim().isEmpty ? fallback : value.trim();
    if (utf8.encode(normalized).length > 128) {
      throw FormatException('管理员$label不得超过 128 字节', value);
    }
    return normalized;
  }

  static bool _sameAdmins(
    List<PersonalMember> left,
    List<PersonalMember> right,
  ) {
    if (left.length != right.length) return false;
    final leftByAccountId = {for (final admin in left) admin.accountId: admin};
    for (final admin in right) {
      final current = leftByAccountId[admin.accountId];
      if (current == null ||
          current.familyName != admin.familyName ||
          current.givenName != admin.givenName) {
        return false;
      }
    }
    return true;
  }

  static void _validateCount(int kind, String code, int count) {
    if (kind == 2) {
      if (code != 'PMUL') {
        throw StateError('个人多签管理员更换必须使用 PMUL');
      }
      if (count < 2 || count > 64) throw StateError('个人多签管理员数量必须在 2..=64 之间');
      return;
    }
    throw StateError('未知管理员账户类型');
  }

  static void _validateThreshold(
    int kind,
    String code,
    int count,
    int threshold,
  ) {
    if (kind == 2 && code == 'PMUL') {
      // 个人普通阈值按引擎的1..=成员数规则做前置校验；
      // 真正保存和生效仍由 internal-vote 负责。
      if (threshold <= 0 || threshold > count) {
        throw StateError('普通阈值必须在1到管理员总数之间');
      }
      return;
    }
    throw StateError('该管理员账户不能设置阈值');
  }
}
