import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:citizen_system/theme/app_theme.dart';

import 'package:citizen_transaction/topup/topup_api.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
import 'package:citizen_transaction/topup/topup_webview_page.dart';
import 'package:citizen_transaction/topup/store.dart';

import 'package:citizen_system/theme/app_layout.dart';

/// 在当前账户详情上直接显示套餐；只有未指定币种的注册入口才先选币种。
Future<bool?> showTopup(
  BuildContext context, {
  required String accountId,
  String? token,
  TopupApi? api,
  TopupStore? store,
  Future<TopupRecord?> Function(TopupSelection)? paymentOpener,
}) {
  if (token != null && !const ['USDT', 'USDC'].contains(token)) {
    throw ArgumentError.value(token, 'token', '不支持的充值币种');
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.surfaceCard,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => TopupSheet(
      accountId: accountId,
      token: token,
      api: api,
      store: store,
      paymentOpener: paymentOpener,
    ),
  );
}

/// 套餐仅用本地可信配置，不因服务端不可用而请求报价或预建单。
class TopupSheet extends StatefulWidget {
  const TopupSheet({
    super.key,
    required this.accountId,
    this.token,
    this.api,
    this.store,
    this.paymentOpener,
  });
  final String accountId;
  final String? token;
  final TopupApi? api;
  final TopupStore? store;
  final Future<TopupRecord?> Function(TopupSelection)? paymentOpener;
  @override
  State<TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<TopupSheet> {
  late final TopupApi _api = widget.api ?? TopupApi();
  late final TopupStore _store = widget.store ?? TopupStore.shared;
  late String? _token = widget.token;
  bool _paymentOpen = false;
  @override
  void didUpdateWidget(covariant TopupSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _token = widget.token;
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceCard,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: _buildLoaded(context, TopupConfig.local()),
    ),
  );

  Widget _buildLoaded(BuildContext context, TopupConfig config) {
    final token = _token;
    const order = [
      TopupNetwork.ethereum,
      TopupNetwork.base,
      TopupNetwork.solana,
      TopupNetwork.tron,
      TopupNetwork.bnb,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  token == null ? '选择充值币种' : '选择充值套餐 · $token',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 15),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (widget.token == null && token != null)
                TextButton(
                  onPressed: _paymentOpen
                      ? null
                      : () => setState(() => _token = null),
                  child: const Text('更换币种'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (token == null)
            ...config.tokens.map(
              (value) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RailCard(
                  token: value,
                  onTap: () => setState(() => _token = value),
                ),
              ),
            )
          else ...[
            for (final package in config.packages)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackageOption(
                  token: token,
                  package: package,
                  networks: order
                      .where((n) => allowedPair(token, n))
                      .toList(growable: false),
                  enabled: config.ready && !_paymentOpen,
                  showBetterRate: package == config.packages.last,
                  onNetwork: (network) => _choose(
                    config,
                    TopupSelection(
                      token: token,
                      package: package,
                      network: network,
                    ),
                  ),
                ),
              ),
            if (!config.ready)
              const Text(
                '充值暂未开放',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            const Text(
              '选择付款钱包后，先签充值信息，再确认付款',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary),
            ),
            const Text(
              '网络手续费由付款钱包另行确认',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _choose(TopupConfig config, TopupSelection selection) async {
    if (_paymentOpen) return;
    setState(() => _paymentOpen = true);
    final account = widget.accountId;
    try {
      TopupRecord? outcome;
      if (widget.paymentOpener != null) {
        outcome = await widget.paymentOpener!(selection);
      } else {
        outcome = await showTopupSheet(
          context,
          child: TopupWebviewPage(
            selection: selection,
            accountId: account,
            api: _api,
            store: _store,
          ),
        );
      }
      // 钱包付款结果均返回原账户详情；公民币到账由后续结果通知推进。
      if (mounted &&
          widget.accountId == account &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop(outcome?.progress == TopupProgress.completed);
      }
    } finally {
      if (mounted) setState(() => _paymentOpen = false);
    }
  }
}

/// 原币种卡片视觉不变，同一币种的多个网络不重复生成卡片。
/// 严格模型仅允许USDC/USDT，六币轨共用各自币种图标。
String _tokenIconAsset(String token) => token.toUpperCase() == 'USDT'
    ? 'packages/citizen_assets/icons/usdt.svg'
    : 'packages/citizen_assets/icons/usdc.svg';

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
        // 固定三列圆形底色图标；全名称缩放为一行，付款选择仍只提交一次。
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final network in networks)
              Expanded(
                child: TextButton(
                  key: ValueKey('${package.packageId}:${network.wire}'),
                  onPressed: enabled ? () => onNetwork(network) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    disabledForegroundColor: AppTheme.textTertiary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: enabled ? 1 : .4,
                        child: Container(
                          width: AppLayout.scaled(context, 56),
                          height: AppLayout.scaled(context, 56),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (network) {
                              TopupNetwork.ethereum => const Color(0xFFEEEAF7),
                              TopupNetwork.base => const Color(0xFFE8EFFF),
                              TopupNetwork.solana => const Color(0xFF141414),
                              TopupNetwork.tron => const Color(0xFFFFEBEE),
                              TopupNetwork.bnb => const Color(0xFF181A20),
                            },
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'packages/citizen_assets/icons/${network.wire}.svg',
                            width: AppLayout.scaled(
                              context,
                              network == TopupNetwork.base ? 24 : 36,
                            ),
                            height: AppLayout.scaled(
                              context,
                              network == TopupNetwork.base ? 24 : 36,
                            ),
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      SizedBox(height: AppLayout.scaled(context, 8)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          network.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
