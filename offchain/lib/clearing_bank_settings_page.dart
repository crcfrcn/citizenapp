import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:citizen_offchain/clearing_bank_directory.dart';
import 'package:citizen_offchain/bind_clearing_bank_page.dart';
import 'package:citizen_offchain/clearing_bank_prefs.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

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
      subtitle: Text(cid),
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
      subtitle: Text('${item.cidNumber}\n${endpoint.wssUrl}'),
      isThreeLine: true,
      trailing: FilledButton(
        onPressed: ready && !isCurrent ? () => _openBind(item) : null,
        child: Text(buttonText),
      ),
    );
  }
}
