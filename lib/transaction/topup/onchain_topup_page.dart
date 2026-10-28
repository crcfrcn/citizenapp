import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:citizenapp/system/theme/app_theme.dart';

import 'topup_api.dart';
import 'topup_models.dart';
import 'topup_result_page.dart';
import 'topup_webview_page.dart';
import 'store.dart';

import 'package:citizenapp/system/theme/app_layout.dart';

/// 沿用原币种卡片与套餐弹窗；用户在两个套餐下面选择固定付款网络。
///
/// 币轨/收款地址/套餐全部来自 Worker config(App 不写死合约);支付通过 WebView 内的
/// WalletConnect连自托管钱包，按用户所选网络构造付款；仅服务端paid代表到账。
class OnchainTopupPage extends StatefulWidget {
  const OnchainTopupPage({
    super.key,
    required this.accountId,
    this.api,
    this.store,
    this.paymentOpener,
  });

  /// 收公民币的公民链账户(充值目标 `account_id`,0x+64 hex)。
  /// 付款用的自托管钱包由 WalletConnect 另接。
  final String accountId;

  /// 注入用于测试;生产用默认 TopupApi(连当前 Worker)。
  final TopupApi? api;
  final TopupStore? store;

  /// 测试可注入同一付款导航端口；生产仍使用本模块原WebView付款页。
  final Future<TopupRecord?> Function(
    TopupSelection selection,
    TopupRecord? resume,
  )?
  paymentOpener;

  @override
  State<OnchainTopupPage> createState() => _OnchainTopupPageState();
}

class _OnchainTopupPageState extends State<OnchainTopupPage> {
  late final TopupApi _api = widget.api ?? TopupApi();
  late Future<TopupConfig> _configFuture;
  late final TopupStore _store = widget.store ?? TopupStore();
  List<TopupRecord> _records = [];
  bool _recordsLoaded = false;
  bool _paymentOpen = false;
  String? _recoveryError;

  @override
  void initState() {
    super.initState();
    _configFuture = _api.fetchConfig();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final account = widget.accountId;
    try {
      final records = await _store.list(topupOrigin(_api.baseUrl), account);
      if (mounted && account == widget.accountId) {
        setState(() {
          _records = records;
          _recordsLoaded = true;
          _recoveryError = null;
        });
      }
    } on Object {
      if (mounted && account == widget.accountId) {
        setState(() => _recoveryError = '订单恢复记录暂不可用，暂不能发起付款');
      }
    }
  }

  @override
  void didUpdateWidget(covariant OnchainTopupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _records = [];
      _recordsLoaded = false;
      _loadRecords();
    }
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  void _reload() {
    setState(() => _configFuture = _api.fetchConfig());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('链上充值'), centerTitle: true),
      body: FutureBuilder<TopupConfig>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ErrorState(onRetry: _reload);
          }
          return _buildLoaded(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, TopupConfig config) {
    return ListView(
      padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
      children: [
        Text(
          '用稳定币购买公民币，到账后自动转入你的链上钱包。',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 13),
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
        ),
        SizedBox(height: AppLayout.scaled(context, 16)),
        if (!config.ready)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '充值暂未开放，原订单仍可查询',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
        ...config.tokens.map(
          (token) => _RailCard(
            token: token,
            onTap: () async {
              if (!_recordsLoaded || _recoveryError != null) return;
              // 未知付款结果只能恢复原单，避免返回后误付第二笔。
              final pending = _records.where(
                (r) =>
                    !r.terminal &&
                    r.progress.index >= TopupProgress.submitting.index,
              );
              if (pending.isNotEmpty) {
                await _resume(config, pending.first);
                return;
              }
              await _openPackageSheet(context, config, token);
            },
          ),
        ),
        if (_recoveryError != null)
          Text(_recoveryError!, style: const TextStyle(color: AppTheme.danger)),
        ..._records
            .where(
              (r) =>
                  r.progress.index >= TopupProgress.submitting.index ||
                  DateTime.now().millisecondsSinceEpoch < r.intent.expiresAt,
            )
            .take(10)
            .map(
              (r) => ListTile(
                title: Text(
                  r.terminal
                      ? '充值订单 · ${r.order!.status == TopupOrderStatus.paid ? '已到账' : '待核查'}'
                      : '恢复充值订单',
                ),
                subtitle: Text(
                  r.order?.message ??
                      (r.progress.index >= TopupProgress.submitting.index
                          ? '付款回执待核实，请勿重复付款'
                          : '付款尚未提交'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _resume(config, r),
              ),
            ),
        SizedBox(height: AppLayout.scaled(context, 8)),
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: AppLayout.scaled(context, 16),
              color: AppTheme.textTertiary,
            ),
            SizedBox(width: AppLayout.scaled(context, 8)),
            Expanded(
              child: Text(
                '使用支持所选网络的 WalletConnect 兼容钱包',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openPackageSheet(
    BuildContext context,
    TopupConfig config,
    String token,
  ) async {
    if (_paymentOpen) return;
    _paymentOpen = true;
    try {
      final account = widget.accountId;
      final selection = await showModalBottomSheet<TopupSelection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PackageSheet(token: token, config: config),
      );
      if (selection == null || !mounted || account != widget.accountId) return;
      await _startPayment(config, selection);
    } finally {
      _paymentOpen = false;
    }
  }

  Future<void> _startPayment(
    TopupConfig config,
    TopupSelection selection, {
    TopupRecord? resume,
  }) async {
    final account = widget.accountId;
    final record = widget.paymentOpener != null
        ? await widget.paymentOpener!(selection, resume)
        : await Navigator.of(context).push<TopupRecord>(
            MaterialPageRoute(
              builder: (_) => TopupWebviewPage(
                selection: selection,
                accountId: widget.accountId,
                api: _api,
                store: _store,
                resume: resume,
              ),
            ),
          );
    if (!mounted || account != widget.accountId) return;
    await _loadRecords();
    if (record != null &&
        record.progress.index >= TopupProgress.submitting.index) {
      await _showResult(config, record, selection.package);
    }
  }

  Future<void> _resume(TopupConfig config, TopupRecord record) async {
    if (_paymentOpen) return;
    _paymentOpen = true;
    try {
      if (record.origin != topupOrigin(_api.baseUrl) ||
          record.intent.accountId != widget.accountId) {
        return;
      }
      final selection = TopupSelection.fromIntent(record.intent, config);
      if (record.progress.index < TopupProgress.submitting.index &&
          DateTime.now().millisecondsSinceEpoch < record.intent.expiresAt) {
        if (!config.ready) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('充值暂未开放，未继续付款')));
          return;
        }
        await _startPayment(config, selection, resume: record);
      } else {
        await _showResult(config, record, selection.package);
      }
    } finally {
      _paymentOpen = false;
    }
  }

  Future<void> _showResult(
    TopupConfig config,
    TopupRecord record,
    TopupPackage package,
  ) async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TopupResultPage(
          api: _api,
          store: _store,
          record: record,
          package: package,
          onReplay: (original) => Navigator.of(context).push<TopupRecord>(
            MaterialPageRoute(
              builder: (_) => TopupWebviewPage(
                selection: TopupSelection.fromIntent(original.intent, config),
                accountId: widget.accountId,
                api: _api,
                store: _store,
                resume: original,
                replay: true,
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (paid == true) {
      Navigator.of(context).pop(true);
    } else {
      await _loadRecords();
    }
  }
}

/// 原币种卡片视觉不变，同一币种的多个网络不重复生成卡片。
/// 严格模型仅允许USDC/USDT，六币轨共用各自币种图标。
String _tokenIconAsset(String token) => token.toUpperCase() == 'USDT'
    ? 'assets/icons/usdt.svg'
    : 'assets/icons/usdc.svg';

class _RailCard extends StatelessWidget {
  const _RailCard({required this.token, required this.onTap});

  final String token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
            decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
            child: Row(
              children: [
                // 币种入口保持两张，具体网络在套餐内选择。
                SvgPicture.asset(
                  _tokenIconAsset(token),
                  width: AppLayout.scaled(context, 44),
                  height: AppLayout.scaled(context, 44),
                ),
                SizedBox(width: AppLayout.scaled(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        token,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 16),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppLayout.scaled(context, 2)),
                      Text(
                        token == 'USDC'
                            ? 'Ethereum · Base · Solana'
                            : 'Ethereum · Tron · BNB',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '去支付',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 13),
                    color: AppTheme.primary,
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
      ),
    );
  }
}

/// 金额只展示；点击套餐内的网络一次确定币种、套餐和网络。
class _PackageSheet extends StatefulWidget {
  const _PackageSheet({required this.token, required this.config});
  final String token;
  final TopupConfig config;
  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  bool _opening = false;
  @override
  Widget build(BuildContext context) {
    const order = [
      TopupNetwork.ethereum,
      TopupNetwork.base,
      TopupNetwork.solana,
      TopupNetwork.tron,
      TopupNetwork.bnb,
    ];
    final networks = order
        .where((n) => allowedPair(widget.token, n))
        .toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppLayout.scaledValue(20)),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppLayout.scaled(context, 36),
                height: AppLayout.scaled(context, 4),
                margin: EdgeInsets.only(bottom: AppLayout.scaled(context, 16)),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(AppLayout.scaledValue(2)),
                ),
              ),
            ),
            Text(
              '选择充值套餐 · ${widget.token}',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 15),
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 14)),
            for (final package in widget.config.packages)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackageOption(
                  token: widget.token,
                  package: package,
                  networks: networks,
                  enabled: widget.config.ready && !_opening,
                  showBetterRate: package == widget.config.packages.last,
                  onNetwork: (network) {
                    if (_opening) return;
                    setState(() => _opening = true);
                    Navigator.of(context).pop(
                      TopupSelection(
                        token: widget.token,
                        package: package,
                        network: network,
                      ),
                    );
                  },
                ),
              ),
            if (!widget.config.ready)
              const Text(
                '充值暂未开放',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            const Text(
              '选择网络后，将打开兼容钱包确认付款',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary),
            ),
            const Text(
              '网络手续费由付款钱包另行确认',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageOption extends StatelessWidget {
  const _PackageOption({
    required this.token,
    required this.package,
    required this.networks,
    required this.enabled,
    required this.showBetterRate,
    required this.onNetwork,
  });
  final String token;
  final TopupPackage package;
  final List<TopupNetwork> networks;
  final bool enabled, showBetterRate;
  final ValueChanged<TopupNetwork> onNetwork;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
    decoration: BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(14)),
      border: Border.all(color: AppTheme.border, width: .5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${package.coinDisplay} 公民币',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 18),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '支付 ${package.payDisplay} $token',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (showBetterRate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(31),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '更优汇率',
                  style: TextStyle(fontSize: 11, color: AppTheme.gold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final network in networks)
              OutlinedButton(
                key: ValueKey('${package.packageId}:${network.wire}'),
                onPressed: enabled ? () => onNetwork(network) : null,
                child: Text(network.label),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '加载充值渠道失败',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          SizedBox(height: AppLayout.scaled(context, 12)),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
