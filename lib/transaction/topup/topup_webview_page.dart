import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/system/theme/app_layout.dart';

import 'topup_api.dart';
import 'topup_models.dart';
import 'topup_erc20.dart';
import 'tron.dart';
import 'solana.dart';
import 'store.dart';
import 'wallet_link_dispatcher.dart';

/// 保留原连接钱包页；App只接收签名和公开交易，公民币由服务端转账。
class TopupWebviewPage extends StatefulWidget {
  const TopupWebviewPage({
    super.key,
    required this.config,
    required this.token,
    required this.package,
    required this.accountId,
    required this.api,
    required this.store,
    this.resume,
    this.replay = false,
  });
  final TopupConfig config;
  final String token, accountId;
  final TopupPackage package;
  final TopupApi api;
  final TopupStore store;
  final TopupRecord? resume;
  final bool replay;
  static const projectId = '8830074307d80484b839db4eb10b1f2c';
  @override
  State<TopupWebviewPage> createState() => _TopupWebviewPageState();
}

class _TopupWebviewPageState extends State<TopupWebviewPage> {
  late final WebViewController _controller;
  late final WalletLinkDispatcher _links;
  final _session = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  String? _document, _error;
  bool _started = false, _handling = false, _opening = false;
  int _last = 0;
  TopupRecord? _record;
  bool _local(String raw) {
    final uri = Uri.tryParse(raw);
    return uri != null &&
        uri.scheme == 'file' &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.path.endsWith('/assets/topup/walletconnect.html');
  }

  @override
  void initState() {
    super.initState();
    _record = widget.resume;
    _links = WalletLinkDispatcher(
      launcher: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('TopupBridge', onMessageReceived: _message)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) async {
            if (r.isMainFrame &&
                _local(r.url) &&
                (_document == null || r.url == _document))
              return NavigationDecision.navigate;
            if (!r.isMainFrame) return NavigationDecision.navigate;
            // 外部网页没有桥接权限；钱包唤起只能由本地页面的明确消息触发。
            return NavigationDecision.prevent;
          },
          onPageFinished: _start,
        ),
      )
      ..loadFlutterAsset('assets/topup/walletconnect.html');
  }

  Future<void> _start(String url) async {
    if (_started || !_local(url)) return;
    _document = url;
    _started = true;
    final cfg = {
      'session': _session,
      'projectId': TopupWebviewPage.projectId,
      'token': widget.token,
      'tronRpc': TopupRpcConfig.tron,
      'solanaRpc': TopupRpcConfig.solana,
      if (widget.replay)
        'replay': {
          'context': {
            'network': _record!.intent.network.wire,
            'chain': _record!.intent.network.caip2,
            'payer': _record!.intent.payer,
          },
          'txid': _record!.txid,
          'wire': _record!.wire,
          'expiresAt': _record!.intent.expiresAt,
          'rpc': _record!.intent.network == TopupNetwork.tron
              ? TopupRpcConfig.tron
              : TopupRpcConfig.solana,
        },
    };
    await _controller.runJavaScript('CitizenTopup.start(${jsonEncode(cfg)})');
  }

  Future<void> _reply(int id, {Object? value, String? error}) async {
    if (!mounted) return;
    await _controller.runJavaScript(
      'CitizenTopup.reply(${jsonEncode(_session)},$id,${jsonEncode({'ok': error == null, 'value': value, 'error': error})})',
    );
  }

  Future<void> _save(TopupRecord next) async {
    await widget.store.save(next, before: _record);
    _record = next;
  }

  Future<void> _message(JavaScriptMessage message) async {
    if (!mounted ||
        _document == null ||
        await _controller.currentUrl() != _document ||
        message.message.length > 32768)
      return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } on Object {
      return;
    }
    final id = data['id'];
    if (data['session'] != _session || id is! int || id <= _last) return;
    if (data['kind'] == 'external_wallet') {
      _last = id;
      if (_opening) return;
      _opening = true;
      try {
        final opened = await _links.open(
          data['url'] as String,
          source: WalletLinkSource.walletOpenBridge,
        );
        await _reply(
          id,
          error: opened == WalletLinkOpenResult.opened ? null : '未能打开付款钱包',
        );
      } on Object {
        await _reply(id, error: '未能打开付款钱包');
      } finally {
        _opening = false;
      }
      return;
    }
    if (data['kind'] == 'error') {
      _last = id;
      setState(
        () => _error =
            _record != null &&
                _record!.progress.index >= TopupProgress.submitting.index
            ? '付款回执待核实，请返回恢复原订单，勿重复付款'
            : '连接或付款未完成，可返回原充值页面',
      );
      return;
    }
    if (_handling) return;
    _handling = true;
    _last = id;
    try {
      final contextValue = TopupContext.fromJson(data);
      if (data['kind'] == 'connected') {
        final rail = widget.config.rail(widget.token, contextValue.network);
        if (rail.network == TopupNetwork.tron)
          TopupRpcConfig.url(TopupRpcConfig.tron);
        if (rail.network == TopupNetwork.solana)
          TopupRpcConfig.url(TopupRpcConfig.solana);
        if (_record != null &&
            (_record!.progress.index >= TopupProgress.submitting.index ||
                _record!.intent.accountId != widget.accountId))
          throw const FormatException('请先核实原付款订单');
        final intent =
            _record?.intent ??
            await widget.api.createIntent(
              token: widget.token,
              packageId: widget.package.packageId,
              accountId: widget.accountId,
              payer: contextValue,
            );
        if (!mounted) return;
        final genesis = await context.read<CitizenSdk>().chain.getGenesisHash();
        intent.validatePayment(
          rail: rail,
          package: widget.package,
          accountId: widget.accountId,
          payerAddress: contextValue.payer,
          chainGenesisHash: genesis,
          serviceOrigin: topupOrigin(widget.api.baseUrl),
        );
        if (_record == null)
          await _save(
            TopupRecord(
              origin: topupOrigin(widget.api.baseUrl),
              intent: intent,
            ),
          );
        final details = rail.network == TopupNetwork.tron
            ? tronPayment(rail, intent)
            : rail.network == TopupNetwork.solana
            ? solanaPayment(rail, intent)
            : <String, Object>{
                'asset': rail.asset,
                'data': encodeErc20Transfer(
                  rail.recvAddress,
                  BigInt.parse(widget.package.amount(rail)),
                ),
              };
        await _reply(
          id,
          value: {
            ...details,
            'context': {
              'network': contextValue.network.wire,
              'chain': contextValue.network.caip2,
              'payer': contextValue.payer,
            },
            'message': intent.authorizationMessage,
            'expiresAt': intent.expiresAt,
            'signature': _record!.signature,
          },
        );
      } else {
        final before = _record;
        if (before == null ||
            before.intent.payer != contextValue.payer ||
            before.intent.network != contextValue.network)
          throw const FormatException('付款上下文已变化');
        switch (data['kind']) {
          case 'replay':
            if (!widget.replay ||
                before.terminal ||
                before.wire == null ||
                before.txid == null ||
                before.signature == null ||
                contextValue.network.evmId != null ||
                data['wire'] != before.wire ||
                data['txid'] != before.txid ||
                DateTime.now().millisecondsSinceEpoch >=
                    before.intent.expiresAt)
              throw const FormatException('原交易不能继续广播');
            await _reply(id);
            break;
          case 'authorization':
            final signature = data['signature'] as String;
            contextValue.network.signature(signature);
            await _save(
              before.update(
                progress: TopupProgress.authorized,
                signature: signature,
              ),
            );
            await _reply(id);
            break;
          case 'submitting':
            if (before.signature == null) throw const FormatException('缺少付款授权');
            final txid = data['txid'] as String?;
            final wire = data['wire'] as String?;
            if (contextValue.network.evmId == null &&
                (txid == null ||
                    wire == null ||
                    !contextValue.network.transaction(txid)))
              throw const FormatException('缺少原签名交易');
            if (DateTime.now().millisecondsSinceEpoch >=
                before.intent.expiresAt)
              throw const FormatException('付款意图已过期');
            await _save(
              before.update(
                progress: TopupProgress.submitting,
                txid: txid,
                wire: wire,
              ),
            );
            if (txid != null) {
              try {
                final status = await widget.api.confirm(
                  intent: before.intent,
                  paymentTxid: txid,
                  payerSignature: before.signature!,
                );
                await _save(_record!.update(order: status));
              } on TopupApiException {
                /* 已有原交易可恢复；网络未知不能促使重签。 */
              }
            }
            await _reply(id);
            break;
          case 'submitted':
            if (before.progress.index < TopupProgress.submitting.index)
              throw const FormatException('付款未持久提交');
            final txid = data['txid'] as String;
            if (!before.intent.network.transaction(txid))
              throw const FormatException('付款回执无效');
            await _save(
              before.update(
                progress: before.progress.index > TopupProgress.submitted.index
                    ? before.progress
                    : TopupProgress.submitted,
                txid: txid,
              ),
            );
            await _reply(id);
            if (mounted) Navigator.of(context).pop(_record);
            break;
          default:
            throw const FormatException('未知付款桥接阶段');
        }
      }
    } on Object {
      await _reply(id, error: '付款流程已停止，请返回核实原订单');
      if (mounted) setState(() => _error = '付款未继续；如已在钱包确认，请恢复原订单，勿重复付款');
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('连接钱包支付'), centerTitle: true),
    body: _error == null
        ? WebViewWidget(controller: _controller)
        : Center(
            child: Padding(
              padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_record),
                    child: const Text('返回原订单'),
                  ),
                ],
              ),
            ),
          ),
  );
}
