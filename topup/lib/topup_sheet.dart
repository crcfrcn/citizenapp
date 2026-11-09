import 'package:citizen_sdk/citizen_sdk.dart'
    show CitizenSdk, CitizenSigningTransform, CitizenSdkException, formatFen;
import 'package:citizen_scanner/qr_sign_session_page.dart'
    show signCitizenPayload;
import 'package:citizen_system/app_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_topup/topup_api.dart';
import 'package:citizen_topup/topup_models.dart';
import 'package:citizen_topup/topup_webview_page.dart';
import 'package:citizen_topup/store.dart';

/// 币种由充值入口确定；充值金额默认10000、支付网络默认不选，点击链才开始签名建单并打开MetaMask。
Future<bool?> showTopup(
  BuildContext context, {
  required String accountId,
  required String token,
  TopupApi? api,
  TopupStore? store,
  Future<TopupRecord?> Function(TopupSelection)? paymentOpener,
}) {
  if (!const ['USDT', 'USDC'].contains(token)) {
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

class TopupSheet extends StatefulWidget {
  const TopupSheet({
    super.key,
    required this.accountId,
    required this.token,
    this.api,
    this.store,
    this.paymentOpener,
  });
  final String accountId, token;
  final TopupApi? api;
  final TopupStore? store;
  final Future<TopupRecord?> Function(TopupSelection)? paymentOpener;
  @override
  State<TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<TopupSheet> {
  late final TopupStore _store = widget.store ?? TopupStore.shared;
  int _package = 0;
  bool _busy = false;
  TopupSelection? _selection;
  String? _error;
  TopupWalletSession? _wallet;
  String? _orderId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.paymentOpener == null) {
        _wallet = context.read<TopupWalletSession?>();
        _wallet?.prepare();
      }
    });
  }

  @override
  void dispose() {
    if (_orderId != null) _wallet?.leave(_orderId!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = TopupConfig.local();
    final limit = MediaQuery.sizeOf(context).height * .85;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: limit < 320 ? limit : 320,
        maxHeight: limit,
      ),
      child: Material(
        color: AppTheme.surfaceCard,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  key: const ValueKey('topup-handle'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('使用 '),
                  SvgPicture.string(
                    TopupWallet.logo,
                    key: const ValueKey('topup-metamask-logo'),
                    width: 28,
                    height: 28,
                    semanticsLabel: 'MetaMask',
                  ),
                  const Flexible(child: Text(' MetaMask 钱包支付')),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '授权后请留在 MetaMask 完成付款。确认或取消后，请切回公民 App。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _row(
                '充值金额',
                Row(
                  children: [
                    for (
                      var index = 0;
                      index < catalog.packages.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          key: ValueKey('topup-package-$index'),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${formatFen(BigInt.parse(catalog.packages[index].coinFen))} 元',
                            ),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _package == index
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                          checkmarkColor: AppTheme.primary,
                          selectedColor: AppTheme.primary.withAlpha(24),
                          selected: _package == index,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _package = index),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '付款金额：${catalog.packages[_package].payDisplay}.00美元',
                  key: const ValueKey('topup-pay-amount'),
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              ),
              _row(
                '支付网络',
                Row(
                  children: [
                    for (final network in const [
                      TopupNetwork.ethereum,
                      TopupNetwork.bnb,
                      TopupNetwork.base,
                    ])
                      Expanded(
                        child: _icon(
                          key: ValueKey('topup-network-${network.wire}'),
                          label: network.label,
                          selected: _selection?.network == network,
                          onTap: _busy ? null : () => _pay(catalog, network),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: switch (network) {
                                      TopupNetwork.ethereum => const Color(
                                        0xFFEEEAF7,
                                      ),
                                      TopupNetwork.bnb => const Color(
                                        0xFF181A20,
                                      ),
                                      TopupNetwork.base => const Color(
                                        0xFFE8EFFF,
                                      ),
                                    },
                                  ),
                                  child: SvgPicture.asset(
                                    'packages/citizen_assets/icons/${network.wire}.svg',
                                    width: network == TopupNetwork.base
                                        ? 24
                                        : 36,
                                    height: network == TopupNetwork.base
                                        ? 24
                                        : 36,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${network.label.split('/').last}\n${network.label.split('/').first}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String title, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(title, style: const TextStyle(fontSize: 14)),
        ),
        Expanded(child: value),
      ],
    ),
  );

  Widget _icon({
    required Key key,
    required String label,
    required bool selected,
    required Widget child,
    required VoidCallback? onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withAlpha(24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.transparent,
            ),
          ),
          child: child,
        ),
      ),
    ),
  );

  Future<void> _pay(TopupConfig config, TopupNetwork network) async {
    if (_busy) return;
    final route = ModalRoute.of(context);
    final accountId = widget.accountId;
    final selection = TopupSelection(
      token: widget.token,
      package: config.packages[_package],
      network: network,
    );
    setState(() {
      _busy = true;
      _selection = selection;
      _error = null;
    });
    try {
      TopupRecord? record;
      if (widget.paymentOpener != null) {
        record = await widget.paymentOpener!(selection);
      } else {
        AppLog.topupOrder('signing');
        final created = await _store.signOrder(
          TopupDraft.create(selection, accountId),
          TopupWallet.id,
          (payload) async {
            final signature = await signCitizenPayload(
              signing: context.read<CitizenSdk>(),
              context: context,
              accountId: accountId,
              payload: payload,
              action: TopupDraft.action,
              transform: CitizenSigningTransform.raw(),
            );
            AppLog.topupOrder('signed');
            return signature;
          },
          active: () =>
              mounted &&
              widget.accountId == accountId &&
              widget.token == selection.token,
        );
        AppLog.topupOrder('saved');
        if (!mounted) return;
        _orderId = created.payment.orderId;
        _wallet ??= context.read<TopupWalletSession>();
        record = await _wallet!.pay(
          created,
          _store,
          presenting: () => mounted && (route?.isCurrent ?? false),
        );
      }
      if (mounted) _finished(record, null);
    } on Object catch (error) {
      if (_orderId == null) {
        AppLog.topupOrder(
          'failed',
          sdkCode: error is CitizenSdkException ? error.code : null,
        );
      }
      const reasons = {
        '付款组件初始化超时',
        '付款钱包初始化失败',
        '付款组件启动失败',
        '本次付款已结束',
        '付款通信已关闭',
        '充值签名或保存未完成，未创建订单',
      };
      final message = error is StateError && reasons.contains(error.message)
          ? error.message
          : '充值未完成，请核实本地订单';
      if (mounted) _finished(null, message);
    }
  }

  void _finished(TopupRecord? record, String? error) {
    if (!mounted) return;
    if (record != null || error == null) {
      Navigator.of(context).pop(record?.progress == TopupProgress.completed);
      return;
    }
    setState(() {
      _busy = false;
      _selection = null;
      _error = error;
    });
  }
}
