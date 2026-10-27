import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/system/theme/app_layout.dart';
import 'package:citizenapp/app_log.dart';

import 'topup_api.dart';
import 'topup_models.dart';
import 'topup_erc20.dart';
import 'tron.dart';
import 'solana.dart';
import 'store.dart';
import 'wallet_link_dispatcher.dart';

/// 文档和脚本都来自随包资产；HTTPS基址只设置来源，不加载网站网页。
/// 随机标记只留在当前文档内；相同域名的其它网页不能取得桥接权限。
class TopupDocument {
  TopupDocument(String template, List<int> script, String nonce)
    : _nonce = nonce,
      html = _render(template, script, nonce);

  static const baseUrl = 'https://www.crcfrcn.com/';
  final String html;
  final String _nonce;
  String? _url;
  bool get started => _url != null;

  static String _render(String template, List<int> script, String nonce) {
    if (!RegExp(r'^[A-Za-z0-9+/]{22,}={0,2}$').hasMatch(nonce) ||
        script.isEmpty ||
        template.split('{{TOPUP_NONCE}}').length != 5 ||
        template.split('{{TOPUP_SCRIPT}}').length != 2) {
      throw const FormatException('连接页面资源无效');
    }
    return template
        .replaceAll('{{TOPUP_NONCE}}', nonce)
        .replaceAll('{{TOPUP_SCRIPT}}', base64Encode(script));
  }

  String get markerCheck =>
      'window === window.top && '
      'document.documentElement.getAttribute("data-topup-document") === ${jsonEncode(_nonce)}';
  String get check =>
      '($markerCheck) && window.origin === ${jsonEncode(Uri.parse(baseUrl).origin)} && '
      'typeof window.CitizenTopup?.start === "function"';

  // 两端系统API可能把内存文档地址报告为基址或about:blank；仅初次装配可导航，
  // 真正准入仍须本次标记、运行时HTTPS来源和随包脚本同时成立。
  bool mayNavigate(String url, {required bool mainFrame}) =>
      !mainFrame || (!started && (url == baseUrl || url == 'about:blank'));

  bool begin(String beforeUrl, String? currentUrl, Object proof) {
    if (started ||
        beforeUrl != currentUrl ||
        proof != true ||
        !mayNavigate(beforeUrl, mainFrame: true)) {
      return false;
    }
    _url = currentUrl;
    return true;
  }

  bool accepts(String? currentUrl, Object proof) =>
      started && currentUrl == _url && proof == true;

  bool ownsReady(Map<String, dynamic> value) =>
      value.length == 3 &&
      value['kind'] == 'document_ready' &&
      value['nonce'] == _nonce &&
      value['ready'] is bool;
}

/// 保留原连接钱包页；App只接收签名和公开交易，公民币由服务端转账。
class TopupWebviewPage extends StatefulWidget {
  const TopupWebviewPage({
    super.key,
    required this.selection,
    required this.accountId,
    required this.api,
    required this.store,
    this.resume,
    this.replay = false,
  });
  final TopupSelection selection;
  final String accountId;
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
  TopupDocument? _document;
  String? _error;
  bool _handling = false, _opening = false;
  late final String _accountId = widget.accountId;
  bool get _active => mounted && widget.accountId == _accountId;
  int _last = 0;
  int _lastObservation = 0;
  TopupRecord? _record;
  @override
  void initState() {
    super.initState();
    _record = widget.resume;
    _links = WalletLinkDispatcher(
      launcher: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    _controller = WebViewController();
    unawaited(_loadDocument());
  }

  Future<void> _loadDocument() async {
    try {
      // 就绪消息可能紧随内存文档执行；必须先等待系统模式、通道及委托实际注册完成。
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.addJavaScriptChannel(
        'TopupBridge',
        onMessageReceived: _message,
      );
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) async {
            if (_document?.mayNavigate(r.url, mainFrame: r.isMainFrame) ==
                true) {
              return NavigationDecision.navigate;
            }
            // 外部主框架网页没有桥接权限，不能因HTTPS域名相同就放行。
            return NavigationDecision.prevent;
          },
        ),
      );
      final template = await rootBundle.loadString(
        'assets/topup/walletconnect.html',
      );
      final bytes = await rootBundle.load(
        'assets/topup/walletconnect.bundle.js',
      );
      final nonce = base64Encode(
        List.generate(16, (_) => Random.secure().nextInt(256)),
      );
      if (!_active) return;
      final document = TopupDocument(
        template,
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        nonce,
      );
      _document = document;
      await _controller.loadHtmlString(
        document.html,
        baseUrl: TopupDocument.baseUrl,
      );
    } on Object {
      if (_active) setState(() => _error = '连接页面初始化失败，可返回原充值页面');
    }
  }

  Future<bool> _trusted() async {
    final document = _document;
    if (!_active || document == null || !document.started) return false;
    try {
      if (!document.accepts(await _controller.currentUrl(), true)) return false;
      final proof = await _controller.runJavaScriptReturningResult(
        document.check,
      );
      return _active &&
          identical(_document, document) &&
          document.accepts(await _controller.currentUrl(), proof);
    } on Object {
      return false;
    }
  }

  Future<void> _start() async {
    final document = _document;
    if (!_active || document == null || document.started) return;
    try {
      final current = await _controller.currentUrl();
      // 就绪消息只触发检查；准入以真实当前文档及JS证明为准。
      if (current == null || !document.mayNavigate(current, mainFrame: true)) {
        return;
      }
      if (await _controller.runJavaScriptReturningResult(
            document.markerCheck,
          ) !=
          true) {
        return;
      }
      final proof = await _controller.runJavaScriptReturningResult(
        document.check,
      );
      if (proof != true) throw const FormatException('连接页面来源或脚本无效');
      if (!_active ||
          !identical(_document, document) ||
          !document.begin(current, await _controller.currentUrl(), proof)) {
        return;
      }
    } on Object {
      if (_active) setState(() => _error = '连接页面初始化失败，可返回原充值页面');
      return;
    }
    if (widget.replay) {
      try {
        final record = _record;
        if (record == null ||
            record.origin != topupOrigin(widget.api.baseUrl) ||
            record.wire == null ||
            record.txid == null ||
            record.signature == null ||
            record.terminal) {
          throw const FormatException('原交易不能继续广播');
        }
        await widget.api.authorizeReplay(
          intent: record.intent,
          txid: record.txid!,
          selection: widget.selection,
          accountId: _accountId,
          isActive: () => _active,
        );
      } on Object catch (error) {
        if (mounted) {
          setState(
            () => _error = error is TopupApiException
                ? error.message
                : '原交易不能继续广播，请返回查询原订单',
          );
        }
        return;
      }
    }
    if (!_active) return;
    final cfg = {
      'session': _session,
      'projectId': TopupWebviewPage.projectId,
      'selection': widget.selection.toJson(),
      'rpc': TopupRpcConfig.endpoint(widget.selection.network),
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
          'rpc': TopupRpcConfig.endpoint(_record!.intent.network),
        },
    };
    // 在同一JS执行中再核对本次文档，避免异步原生检查后导航提交的竞态。
    await _controller.runJavaScript(
      'if (${document.check}) CitizenTopup.start(${jsonEncode(cfg)})',
    );
  }

  Future<void> _reply(int id, {Object? value, String? error}) async {
    final document = _document;
    if (document == null || !await _trusted()) return;
    await _controller.runJavaScript(
      'if (${document.check}) CitizenTopup.reply(${jsonEncode(_session)},$id,${jsonEncode({'ok': error == null, 'value': value, 'error': error})})',
    );
  }

  Future<void> _save(TopupRecord next) async {
    await widget.store.save(next, before: _record);
    _record = next;
  }

  Future<void> _message(JavaScriptMessage message) async {
    if (!_active || _document == null || message.message.length > 32768) {
      return;
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } on Object {
      return;
    }
    final document = _document;
    if (data['kind'] == 'document_ready') {
      if (document == null || !document.ownsReady(data) || document.started) {
        return;
      }
      if (data['ready'] != true) {
        setState(() => _error = '连接页面初始化失败，可返回原充值页面');
        return;
      }
      await _start();
      return;
    }
    final id = data['id'];
    if (data['session'] != _session || id is! int || id <= 0) return;
    if (!await _trusted()) return;
    // 观察消息沿本次文档、真实来源及原会话守卫，不抢占付款回执。
    if (data['kind'] == 'connection_observation' ||
        data['kind'] == 'connection_trace') {
      if (id <= _lastObservation) return;
      _lastObservation = id;
      if (data['kind'] == 'connection_trace') {
        AppLog.topupConnectTrace(data['observation']);
      } else {
        AppLog.topupConnection(data['observation']);
      }
      return;
    }
    if (id <= _last) return;
    if (data['kind'] == 'external_wallet') {
      _last = id;
      AppLog.topupWallet('requested');
      if (_opening) {
        AppLog.topupWallet('busy');
        return;
      }
      _opening = true;
      try {
        final opened = await _links.open(
          data['url'] as String,
          source: WalletLinkSource.walletOpenBridge,
        );
        AppLog.topupWallet(
          opened == WalletLinkOpenResult.opened ? 'opened' : 'rejected',
        );
        await _reply(
          id,
          error: opened == WalletLinkOpenResult.opened ? null : '未能打开付款钱包',
        );
      } on Object {
        AppLog.topupWallet('rejected');
        await _reply(id, error: '未能打开付款钱包');
      } finally {
        _opening = false;
      }
      return;
    }
    if (data['kind'] == 'error') {
      _last = id;
      setState(
        () => _error ??=
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
      if (!_active || contextValue.network != widget.selection.network) {
        throw const FormatException('钱包网络与所选网络不一致');
      }
      if (data['kind'] == 'connected') {
        if (data['token'] != widget.selection.token ||
            data['package_id'] != widget.selection.package.packageId) {
          throw const FormatException('付款选择发生变化');
        }
        if (_record != null &&
            (_record!.progress.index >= TopupProgress.submitting.index ||
                _record!.origin != topupOrigin(widget.api.baseUrl) ||
                _record!.intent.accountId != _accountId)) {
          throw const FormatException('请先核实原付款订单');
        }
        if (!mounted) return;
        final genesis = await context.read<CitizenSdk>().chain.getGenesisHash();
        if (!_active) return;
        final prepared = await widget.api.preparePayment(
          selection: widget.selection,
          accountId: _accountId,
          payer: contextValue,
          chainGenesisHash: genesis,
          original: _record?.intent,
          isActive: () => _active,
        );
        if (!_active) return;
        final rail = prepared.rail, intent = prepared.intent;
        if (rail.network == TopupNetwork.tron) {
          TopupRpcConfig.url(TopupRpcConfig.tron);
        }
        if (rail.network == TopupNetwork.solana) {
          TopupRpcConfig.url(TopupRpcConfig.solana);
        }
        if (_record == null) {
          await _save(
            TopupRecord(
              origin: topupOrigin(widget.api.baseUrl),
              intent: intent,
            ),
          );
        }
        final details = rail.network == TopupNetwork.tron
            ? tronPayment(rail, intent)
            : rail.network == TopupNetwork.solana
            ? solanaPayment(rail, intent)
            : <String, Object>{
                'asset': rail.asset,
                'data': encodeErc20Transfer(
                  rail.recvAddress,
                  BigInt.parse(widget.selection.package.amount(rail)),
                ),
              };
        await _reply(
          id,
          value: {
            ...details,
            'selection': widget.selection.toJson(),
            'context': {
              'network': contextValue.network.wire,
              'chain': contextValue.network.caip2,
              'payer': contextValue.payer,
            },
            'message': intent.signMessage,
            'expiresAt': intent.expiresAt,
            'signature': _record!.signature,
          },
        );
      } else {
        final before = _record;
        if (before == null ||
            before.intent.payer != contextValue.payer ||
            before.intent.network != contextValue.network) {
          throw const FormatException('付款上下文已变化');
        }
        switch (data['kind']) {
          case 'solana_rpc':
            if (contextValue.network != TopupNetwork.solana ||
                before.terminal ||
                before.signature == null ||
                data.keys.any(
                  (key) => !const {
                    'session',
                    'id',
                    'kind',
                    'network',
                    'chain',
                    'payer',
                    'method',
                    'params',
                  }.contains(key),
                ) ||
                data['method'] is! String ||
                data['params'] is! List) {
              throw const FormatException('Solana节点请求不属于当前付款');
            }
            final method = data['method'] as String;
            final params = List<Object?>.from(data['params'] as List);
            if (method == 'sendTransaction') {
              if (before.progress.index < TopupProgress.submitting.index ||
                  before.wire == null ||
                  before.txid == null ||
                  params.isEmpty ||
                  params[0] != before.wire) {
                throw const FormatException('必须先保存原Solana签名交易');
              }
              await widget.api.authorizeReplay(
                intent: before.intent,
                txid: before.txid!,
                selection: widget.selection,
                accountId: _accountId,
                isActive: () => _active,
              );
            }
            final result = await widget.api.solanaRpc(
              intent: before.intent,
              method: method,
              params: params,
              wire: before.wire,
              txid: before.txid,
              isActive: () => _active,
            );
            if (!_active) return;
            await _reply(id, value: result);
            break;
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
                    before.intent.expiresAt) {
              throw const FormatException('原交易不能继续广播');
            }
            await widget.api.authorizeReplay(
              intent: before.intent,
              txid: before.txid!,
              selection: widget.selection,
              accountId: _accountId,
              isActive: () => _active,
            );
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
                    !contextValue.network.transaction(txid))) {
              throw const FormatException('缺少原签名交易');
            }
            if (DateTime.now().millisecondsSinceEpoch >=
                before.intent.expiresAt) {
              throw const FormatException('付款意图已过期');
            }
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
            if (before.progress.index < TopupProgress.submitting.index) {
              throw const FormatException('付款未持久提交');
            }
            final txid = data['txid'] as String;
            if (!before.intent.network.transaction(txid)) {
              throw const FormatException('付款回执无效');
            }
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
    } on TopupApiException catch (error) {
      await _reply(id, error: error.message);
      if (mounted) setState(() => _error = error.message);
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
