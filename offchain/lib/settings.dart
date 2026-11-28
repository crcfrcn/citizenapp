// 清算行绑定与设置页面。

import 'package:citizen_system/format.dart';
import 'package:citizen_system/security/access.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_scanner/sign.dart';
import 'package:citizen_offchain/chain.dart' show OnchainClearingBankChain;
import 'package:citizen_offchain/bank.dart' show ClearingBankBindingSnapshot, ClearingBankPrefs;
import 'package:citizen_system/theme.dart';
import 'dart:async';
import 'package:citizen_offchain/bank.dart' show ClearingBankCandidate, ClearingBankDirectory;

// 展示并确认按机构CID绑定或切换清算行。

/// 绑定**清算行**(L2)确认页。
///
/// 设置页选择 finalized 目录中的机构，确认后以身份CID号 绑定或切换。
/// 绑定即开户，无预存和业务开户费，签名者支付链上交易费。
class BindClearingBankPage extends StatefulWidget {
  const BindClearingBankPage({
    super.key,
    required this.accountId,
    required this.bank,
    this.switchMode = false,
    this.chain,
    this.readFees,
  });

  /// L3 用户链账户主键(0x+64hex):按账户签名、构造 signerPublicKey、绑定缓存键。
  final String accountId;

  final ClearingBankCandidate bank;
  final bool switchMode;
  final OnchainClearingBankChain? chain;
  final Future<CitizenFeeSnapshot> Function()? readFees;

  @override
  State<BindClearingBankPage> createState() => _BindClearingBankPageState();
}

class _BindClearingBankPageState extends State<BindClearingBankPage> {
  bool _submitting = false;
  BigInt? _feeFen;

  @override
  Widget build(BuildContext context) {
    final b = widget.bank;
    final title = b.displayTitle.isEmpty ? '(未设置全称)' : b.displayTitle;
    return Scaffold(
      appBar: AppBar(title: Text(widget.switchMode ? '切换清算行' : '绑定清算行')),
      body: ListView(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        children: [
          ListTile(title: const Text('清算行'), subtitle: Text(title)),
          ListTile(
            title: const Text('所在地'),
            subtitle: Text(b.areaPath.isEmpty ? '-' : b.areaPath),
          ),
          ListTile(
            title: const Text('身份CID号'),
            subtitle: IdentityCidSelectableText(b.cidNumber),
          ),
          ListTile(
            title: const Text('主账户'),
            subtitle: SelectableText('0x${b.mainAccountId}'),
          ),
          SizedBox(height: AppLayout.scaled(context, 12)),
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppLayout.scaledValue(12)),
              child: Text(
                '说明:\n'
                '· 绑定即开户,无需预存\n'
                '${_feeFen == null ? '· 提交前读取链上手续费' : '· 预估链上手续费：${formatFen(_feeFen!)} 元'}\n'
                '· 同一时间只能绑定一家清算行\n'
                '· 切换前需把当前清算行存款全部提现',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 13),
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 24)),
          FilledButton(
            onPressed: _submitting ? null : _confirmBind,
            child: _submitting
                ? SizedBox(
                    width: AppLayout.scaled(context, 20),
                    height: AppLayout.scaled(context, 20),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.switchMode ? '确认切换' : '确认绑定'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBind() async {
    if (_submitting) return;
    final bank = widget.bank;

    setState(() {
      _submitting = true;
      _feeFen = null;
    });
    try {
      final publicKeyBytes = citizenAccountIdBytes(widget.accountId);

      final fees = await (widget.readFees?.call() ??
          context.read<CitizenSdk>().getFeeSnapshot());
      if (!mounted) return;
      setState(() => _feeFen = fees.feeFen);
      final chain = widget.chain ??
          OnchainClearingBankChain(transactions: context.read<CitizenSdk>());
      final result = widget.switchMode
          ? await chain.switchBank(
              signerPublicKey: publicKeyBytes,
              bankCid: bank.cidNumber,
              externalSigning: (pending) => showCitizenSdkQrResponse(
                context,
                request: pending.qrRequest,
                expiresAt: BigInt.from(
                  pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            )
          : await chain.bindClearingBank(
              signerPublicKey: publicKeyBytes,
              bankCid: bank.cidNumber,
              externalSigning: (pending) => showCitizenSdkQrResponse(
                context,
                request: pending.qrRequest,
                expiresAt: BigInt.from(
                  pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            );

      // 最终成功与本地展示缓存分别报告。返回后设置页仍重新读链。
      var cacheFailed = false;
      try {
        final endpoint = bank.endpoint;
        final now = DateTime.now().millisecondsSinceEpoch;
        await ClearingBankPrefs.saveSnapshot(
          widget.accountId,
          ClearingBankBindingSnapshot(
            cidNumber: bank.cidNumber,
            fullName: bank.fullName,
            shortName: bank.shortName ?? '',
            mainAccountId: bank.mainAccountId.substring(2),
            feeAccountId: bank.feeAccountId.substring(2),
            peerId: endpoint.peerId,
            rpcDomain: endpoint.rpcDomain,
            rpcPort: endpoint.rpcPort,
            boundAtMs: now,
            lastVerifiedAtMs: now,
          ),
        );
      } catch (_) {
        cacheFailed = true;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.switchMode ? '切换' : '绑定'}已确认，交易 ${_short(result.txHash)}'
            '${cacheFailed ? '（本地缓存未更新）' : ''}',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on AccountSecurityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('${widget.switchMode ? '切换' : '绑定'}失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _short(String h) {
    if (h.length <= 14) return h;
    return '${h.substring(0, 8)}…${h.substring(h.length - 4)}';
  }
}

// 查询已绑定清算行及最终目录，提供搜索、绑定和切换界面。

/// 「设置清算行」真实入口。
///
///
/// - finalized `ClearingBankNodes` 是清算行目录和资格的唯一来源，机构链快照只补名称。
/// - 页面只缓存绑定快照,不把本地缓存当作权威状态;绑定、切换和支付仍以链上校验为准。
/// - 一律按 `account_id` 键控,单钱包多账户下每个账户独立绑定清算行。
class ClearingBankSettingsPage extends StatefulWidget {
  const ClearingBankSettingsPage({
    super.key,
    required this.accountId,
    this.directory,
  });

  /// 该账户链账户主键(0x+64hex):绑定缓存键、按账户签名。
  final String accountId;

  final ClearingBankDirectory? directory;

  @override
  State<ClearingBankSettingsPage> createState() =>
      _ClearingBankSettingsPageState();
}

class _ClearingBankSettingsPageState extends State<ClearingBankSettingsPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  late final ClearingBankDirectory _directory;
  bool _dependenciesReady = false;

  String? _currentCid;
  ClearingBankBindingSnapshot? _current;
  List<ClearingBankCandidate> _items = const [];
  bool _loadingCurrent = false;
  int _bindingRead = 0;
  bool _searching = false;
  String? _bindingError;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.directory != null) {
      _directory = widget.directory!;
      _dependenciesReady = true;
      unawaited(_loadCurrent());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _directory = ClearingBankDirectory(chain: context.read<CitizenSdk>());
    _dependenciesReady = true;
    unawaited(_loadCurrent());
  }

  @override
  void didUpdateWidget(covariant ClearingBankSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId == widget.accountId) return;
    _currentCid = null;
    _current = null;
    _loadingCurrent = false;
    unawaited(_loadCurrent());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    if (_loadingCurrent) return;
    final accountId = widget.accountId;
    final read = ++_bindingRead;
    bool isCurrent() => mounted && read == _bindingRead;
    setState(() {
      _loadingCurrent = true;
      _bindingError = null;
    });
    try {
      final cid = await _directory.fetchUserBankCid(accountId);
      if (!isCurrent()) return;
      final snapshot = cid == null
          ? null
          : await ClearingBankPrefs.loadSnapshot(accountId)
                .onError((_, _) => null);
      if (!isCurrent()) return;
      setState(() {
        _currentCid = cid;
        _current = snapshot?.cidNumber == cid ? snapshot : null;
      });
    } catch (e) {
      if (isCurrent()) setState(() => _bindingError = '读取当前绑定失败：$e');
    } finally {
      if (isCurrent()) setState(() => _loadingCurrent = false);
    }
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final items = await _directory.search(_searchCtrl.text.trim());
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '搜索失败:$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openBind(ClearingBankCandidate item) async {
    if (_loadingCurrent) return;
    final accountId = widget.accountId;
    final reload = _loadCurrent();
    final read = _bindingRead;
    await reload;
    if (!mounted ||
        read != _bindingRead ||
        widget.accountId != accountId ||
        _bindingError != null ||
        _currentCid == item.cidNumber) {
      return;
    }
    final isSwitch = _currentCid != null;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BindClearingBankPage(
          accountId: accountId,
          bank: item,
          switchMode: isSwitch,
        ),
      ),
    );
    if (mounted && widget.accountId == accountId && changed == true) {
      await _loadCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置清算行'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadCurrent,
        child: ListView(
          padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
          children: [
            _currentCard(),
            SizedBox(height: AppLayout.scaled(context, 12)),
            _searchBox(),
            if (_error != null) ...[
              SizedBox(height: AppLayout.scaled(context, 12)),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            SizedBox(height: AppLayout.scaled(context, 12)),
            if (_searching)
              const Center(child: CircularProgressIndicator())
            else if (_items.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: AppLayout.scaled(context, 48)),
                child: const Center(
                  child: Text(
                    '暂无结果',
                    style: TextStyle(color: AppTheme.textTertiary),
                  ),
                ),
              )
            else
              ..._items.map(_candidateTile),
          ],
        ),
      ),
    );
  }

  Widget _currentCard() {
    if (_loadingCurrent) {
      return const ListTile(
        leading: CircularProgressIndicator(),
        title: Text('正在读取当前绑定'),
      );
    }
    final error = _bindingError;
    if (error != null) {
      return ListTile(
        title: Text(error),
        trailing: TextButton(onPressed: _loadCurrent, child: const Text('重试')),
      );
    }
    final cid = _currentCid;
    if (cid == null) {
      return const ListTile(
        leading: Icon(Icons.account_balance_outlined),
        title: Text('尚未绑定清算行'),
        subtitle: Text('搜索已加入清算网络的机构后绑定'),
      );
    }
    final current = _current;
    return ListTile(
      leading: const Icon(Icons.account_balance),
      title: Text(current?.displayTitle ?? '当前清算行'),
      subtitle: Text(formatIdentityCidText(cid)),
      trailing: current == null
          ? null
          : TextButton(
              onPressed: () async {
                final accountId = widget.accountId;
                await ClearingBankPrefs.clear(accountId);
                if (mounted && widget.accountId == accountId) {
                  await _loadCurrent();
                }
              },
              child: const Text('清除缓存'),
            ),
    );
  }

  Widget _searchBox() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '搜索清算行',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppLayout.scaledValue(8)),
                ),
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
        ),
        SizedBox(width: AppLayout.scaledValue(8)),
        IconButton.filled(
          onPressed: _searching ? null : _search,
          icon: const Icon(Icons.search),
          tooltip: '搜索',
        ),
      ],
    );
  }

  Widget _candidateTile(ClearingBankCandidate item) {
    final endpoint = item.endpoint;
    final title = item.displayTitle.isEmpty ? '(未设置全称)' : item.displayTitle;
    final isCurrent = _currentCid == item.cidNumber;
    final ready = !_loadingCurrent && _bindingError == null;
    final buttonText = !ready
        ? '待核对'
        : isCurrent
        ? '已绑定'
        : (_currentCid == null ? '绑定' : '切换');

    return ListTile(
      leading: const Icon(Icons.verified_outlined, color: Colors.green),
      title: Text(title),
      subtitle: Text('${formatIdentityCidText(item.cidNumber)}\n${endpoint.wssUrl}'),
      isThreeLine: true,
      trailing: FilledButton(
        onPressed: ready && !isCurrent ? () => _openBind(item) : null,
        child: Text(buttonText),
      ),
    );
  }
}
