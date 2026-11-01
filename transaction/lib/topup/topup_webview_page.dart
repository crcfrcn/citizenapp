import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:citizen_sdk/citizen_sdk.dart'
    show CitizenSdk, CitizenSigningTransform;
import 'package:citizen_scanner/qr_sign_session_page.dart'
    show signCitizenPayload;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/app_log.dart';

import 'package:citizen_transaction/topup/topup_api.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
import 'package:citizen_transaction/topup/topup_erc20.dart';
import 'package:citizen_transaction/topup/tron.dart';
import 'package:citizen_transaction/topup/solana.dart';
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_transaction/topup/wallet_link_dispatcher.dart';

/// 本次新付款使用这一底部弹窗，不再压入独立的“连接钱包支付”整页。
Future<TopupRecord?> showTopupSheet(
  BuildContext context, {
  required Widget child,
}) => showModalBottomSheet<TopupRecord>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: AppTheme.surfaceCard,
  clipBehavior: Clip.antiAlias,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => SizedBox(
    height: min(MediaQuery.sizeOf(context).height * .72, 440.0),
    child: child,
  ),
);

/// 只展示本产品固定阶段与错误类别；未知输入不回显，异常正文与钱包资料不进入UI。
String topupFailure(Object? stage, Object? code) {
  if (code == 'user_rejected') return '你已拒绝本次钱包请求，可关闭后重新选择';
  if (code == 'user_closed' || code == 'cancelled') {
    return '本次钱包操作已取消，可关闭后重新选择';
  }
  if (code == 'wallet_open_failed') return '未能打开所选钱包，可关闭后重新选择';
  if (code == 'wallet_mismatch') return '钱包链接与所选钱包不一致，本次操作已停止';
  if (code == 'connect_timeout') return '钱包连接等待超时，未发起付款';
  if (code == 'request_timeout') return '钱包请求等待超时，请返回核实原订单';
  return switch (stage) {
    'connection' => '钱包连接未完成，可关闭后重新选择',
    'account' => '钱包账户或所选网络未通过核验，未发起付款',
    'create_order' => '本地充值订单保存失败，未发起付款',
    'transaction' => '付款交易准备未完成，请返回核实原订单',
    'submitting' || 'submitted' => '付款回执待核实，请保留原订单，勿重复付款',
    _ => '充值流程已停止，请返回核实原订单',
  };
}

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

/// 钱包选择弹窗；App只接收签名和公开交易，公民币由服务端转账。
class TopupWebviewPage extends StatefulWidget {
  const TopupWebviewPage({
    super.key,
    required this.selection,
    required this.accountId,
    required this.api,
    required this.store,
  });
  final TopupSelection selection;
  final String accountId;
  final TopupApi api;
  final TopupStore store;
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
  bool _handling = false, _opening = false, _stopped = false;
  bool _solanaPrepared = false, _solanaBroadcast = false;
  late final String _accountId = widget.accountId;
  bool get _active => mounted && !_stopped && widget.accountId == _accountId;
  int _last = 0;
  int _lastObservation = 0;
  TopupRecord? _record;
  Future<void> _messages = Future<void>.value();
  StreamSubscription<TopupChange>? _recordChanges;
  @override
  void initState() {
    super.initState();
    _recordChanges = TopupStore.changes.listen((change) {
      final current = _record;
      if (current != null &&
          change.record != null &&
          change.accountId == _accountId &&
          change.orderId == current.payment.orderId &&
          change.origin == current.origin) {
        _record = TopupStore.fromEntry(change.record!);
      }
      if (change.record == null &&
          current != null &&
          change.accountId == _accountId &&
          change.orderId == current.payment.orderId &&
          change.origin == current.origin) {
        // 删除提交后结束原文档；在途响应只能更新原行，不能重新插入。
        _stopped = true;
        _record = null;
        final document = _document;
        if (document != null && document.started) {
          unawaited(
            _controller
                .runJavaScript('if (${document.check}) CitizenTopup.cancel()')
                .catchError((Object _) {}),
          );
        }
        if (mounted) setState(() => _error = '本地充值订单已删除');
      }
    });
    _links = WalletLinkDispatcher(
      launcher: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    _controller = WebViewController();
    unawaited(_loadDocument());
  }

  @override
  void dispose() {
    final leftWithoutResult = !_stopped;
    _stopped = true;
    unawaited(_recordChanges?.cancel());
    final document = _document;
    if (document != null && document.started) {
      // 离页即结束原文档的连接和等待；同次JS核对来源/nonce，旧回调不能带到下一钱包。
      unawaited(
        _controller
            .runJavaScript('if (${document.check}) CitizenTopup.cancel()')
            .catchError((Object _) {}),
      );
    }
    final record = _record;
    if (leftWithoutResult &&
        record != null &&
        !record.terminal &&
        record.wire == null) {
      final progress = record.progress;
      unawaited(
        widget.store
            .save(
              record.update(
                progress: progress,
                failureCode: 'wallet_view_closed',
              ),
              before: record,
            )
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      // 就绪消息可能紧随内存文档执行；必须先等待系统模式、通道及委托实际注册完成。
      await _controller.setBackgroundColor(AppTheme.surfaceCard);
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.addJavaScriptChannel(
        'TopupBridge',
        onMessageReceived: (message) {
          // JS收到回执后可能在平台回执返回前发下一条；排队不能静默丢掉合法请求。
          _messages = _messages.then((_) => _message(message)).catchError((
            Object _,
          ) {
            AppLog.d('topup_bridge_stopped');
          });
        },
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
        'packages/citizen_transaction/web/walletconnect.html',
      );
      final bytes = await rootBundle.load(
        'packages/citizen_transaction/web/walletconnect.bundle.js',
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
      if (_active) setState(() => _error = '连接页面初始化失败，可关闭后重新选择');
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
      if (_active) setState(() => _error = '连接页面初始化失败，可关闭后重新选择');
      return;
    }
    if (!_active) return;
    final cfg = {
      'session': _session,
      'projectId': TopupWebviewPage.projectId,
      'selection': widget.selection.toJson(),
      'rpc': TopupRpcConfig.endpoint(widget.selection.network),
      'available_wallets': [
        for (final id in TopupWallets.ids)
          if (TopupWallets.paymentReady(id, widget.selection.network)) id,
      ],
      'summary':
          '${widget.selection.package.payDisplay} ${widget.selection.token} → ${widget.selection.package.coinDisplay} 公民币',
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
    if (!_active) {
      if (!next.terminal) {
        final progress = next.progress;
        try {
          await widget.store.save(
            next.update(progress: progress, failureCode: 'wallet_view_closed'),
            before: next,
          );
        } on Object {
          /* 原行已更新/删除时不覆盖或重新插入。 */
        }
      }
      throw const TopupDeletedException();
    }
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
        setState(() => _error = '连接页面初始化失败，可关闭后重新选择');
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
      if (_record == null || _record!.progress != TopupProgress.pending) {
        await _reply(id, error: '充值订单尚未签名保存，不能打开付款钱包');
        return;
      }
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
      AppLog.topupFailure(data['stage'], data['code']);
      final before = _record;
      if (before != null && !before.terminal) {
        final code = data['code'];
        final progress = before.progress;
        try {
          await _save(
            before.update(
              progress: progress,
              failureCode: before.isPaid
                  ? 'issuance_request_unresolved'
                  : code == 'user_rejected' || code == 'user_closed'
                  ? 'payment_cancelled'
                  : 'payment_unverified',
            ),
          );
        } on Object {
          /* 删除或离页不能复活原单。 */
        }
      }
      _finish();
      return;
    }
    if (_handling) return;
    _handling = true;
    _last = id;
    try {
      if (data['kind'] == 'create_order') {
        if (_record != null) throw StateError('一次钱包点击只能创建一个订单');
        final walletId = data['wallet_id'];
        if (walletId is! String ||
            !TopupWallets.paymentReady(walletId, widget.selection.network)) {
          throw const FormatException('钱包选择无效');
        }
        final draft = TopupDraft.create(widget.selection, _accountId);
        final created = await widget.store.signOrder(
          draft,
          walletId,
          (payload) => signCitizenPayload(
            signing: context.read<CitizenSdk>(),
            context: context,
            accountId: _accountId,
            payload: payload,
            action: TopupDraft.action,
            transform: CitizenSigningTransform.raw(),
          ),
          active: () => _active,
        );
        if (!_active) return;
        _record = created;
        await _reply(id, value: {'order_id': created.payment.orderId});
        return;
      }
      final current = _record;
      if (current != null &&
          current.isPaid &&
          data['kind'] == 'submitted' &&
          data['txid'] == current.txid) {
        await _reply(id, value: {'submitted': true});
        _finish();
        return;
      }
      if (current == null || current.terminal) throw StateError('本地订单不存在或已经结束');
      final payer = TopupContext.fromJson(data);
      if (payer.network != widget.selection.network ||
          current.payer != null && payer.payer != current.payer) {
        throw const FormatException('钱包上下文与订单不一致');
      }
      switch (data['kind']) {
        case 'connected':
          if (current.progress != TopupProgress.pending ||
              current.payer != null ||
              data['token'] != current.payment.token ||
              data['package_id'] != current.payment.packageId) {
            throw const FormatException('原订单选择已变化');
          }
          await _save(current.update(payer: payer.payer));
          final rail = TopupConfig.local().rail(
            current.payment.token,
            current.payment.network,
          );
          final details = rail.network == TopupNetwork.tron
              ? tronPayment(rail, current.payment)
              : rail.network == TopupNetwork.solana
              ? solanaPayment(rail, current.payment)
              : <String, Object>{
                  'asset': rail.asset,
                  'data': encodeErc20Transfer(
                    rail.recvAddress,
                    BigInt.parse(current.payment.payAmount),
                    current.binding,
                  ),
                };
          await _reply(
            id,
            value: {
              ...details,
              'memo': current.memo,
              'binding': current.binding,
              'selection': widget.selection.toJson(),
              'context': {
                'network': payer.network.wire,
                'chain': payer.network.caip2,
                'payer': payer.payer,
              },
            },
          );
          break;
        case 'solana_rpc':
          if (payer.network != TopupNetwork.solana ||
              data['method'] is! String ||
              data['params'] is! List) {
            throw const FormatException('付款节点请求无效');
          }
          final method = data['method'] as String,
              params = List<Object?>.from(data['params'] as List);
          if (!const {
            'getGenesisHash',
            'getLatestBlockhash',
            'sendTransaction',
          }.contains(method)) {
            throw const FormatException('未允许的付款请求');
          }
          if (method == 'sendTransaction' &&
              (current.progress != TopupProgress.pending ||
                  current.wire == null ||
                  current.wire == null ||
                  params.isEmpty ||
                  params.first != current.wire)) {
            throw const FormatException('原签名付款未保存');
          }
          if (method == 'getLatestBlockhash') {
            final options = params.length == 1 ? params.single : null;
            if (_solanaPrepared ||
                current.progress != TopupProgress.pending ||
                current.payer == null ||
                options is! Map ||
                options.length != 1 ||
                options['commitment'] != 'finalized') {
              throw StateError('只允许一次付款区块构造请求');
            }
            _solanaPrepared = true;
          } else {
            final options = params.length == 2 ? params[1] : null;
            if (_solanaBroadcast ||
                options is! Map ||
                options.length != 4 ||
                options['encoding'] != 'base64' ||
                options['skipPreflight'] != false ||
                options['preflightCommitment'] != 'confirmed' ||
                options['maxRetries'] != 0) {
              throw StateError('原付款只广播一次');
            }
            _solanaBroadcast = true;
          }
          final result = await widget.api.paymentRpc(
            payer.network,
            method,
            params,
          );
          if (_active) await _reply(id, value: result);
          break;
        case 'submitting':
          if (current.progress != TopupProgress.pending ||
              current.payer == null) {
            throw StateError('原订单不能重复付款');
          }
          if (current.wire != null) throw StateError('原订单不能重复付款');
          String? tx = data['txid'] as String?, wire = data['wire'] as String?;
          if (payer.network.evmId != null) {
            final transaction = data['transaction'];
            if (transaction is! Map ||
                transaction.length != 5 ||
                transaction['from'] != payer.payer ||
                transaction['to'] != current.payment.asset ||
                transaction['value'] != '0x0' ||
                transaction['chainId'] !=
                    '0x${payer.network.evmId!.toRadixString(16)}' ||
                transaction['data'] !=
                    encodeErc20Transfer(
                      current.payment.recvAddress,
                      BigInt.parse(current.payment.payAmount),
                      current.binding,
                    )) {
              throw const FormatException('付款交易与已签订单不一致');
            }
            wire = jsonEncode(transaction);
          } else if (tx == null ||
              wire == null ||
              !payer.network.transaction(tx)) {
            throw const FormatException('原签名付款无效');
          }
          await _save(current.update(txid: tx, wire: wire));
          await _reply(id);
          break;
        case 'submitted':
          if (current.progress != TopupProgress.pending ||
              current.wire == null ||
              data['txid'] is! String) {
            throw const FormatException('付款回执缺少定位');
          }
          final tx = data['txid'] as String;
          if (!payer.network.transaction(tx) ||
              current.txid != null && current.txid != tx) {
            throw const FormatException('付款回执与原交易不一致');
          }
          if (!mounted) return;
          final updates = context.read<TopupUpdates>();
          final sent = current.update(txid: tx);
          if (current.txid == null) {
            await widget.store.save(sent, before: current);
          }
          _record = sent;
          // 广播回执交给App后返回账户；关闭期间的落盘成功也必须交给App验款。
          updates.verifyPayment(sent);
          if (_active) await _reply(id, value: {'submitted': true});
          _finish();
          break;
        default:
          throw const FormatException('未知钱包操作');
      }
    } on TopupDeletedException {
      _record = null;
      _finish();
    } on Object {
      final before = _record;
      if (before != null && !before.terminal) {
        final progress = before.progress;
        try {
          await _save(
            before.update(
              progress: progress,
              failureCode: before.isPaid
                  ? 'issuance_request_unresolved'
                  : 'client_payment_unverified',
            ),
          );
        } on Object {
          /* 原记录不覆盖或重建。 */
        }
      }
      await _reply(
        id,
        error: before == null
            ? '充值签名或保存未完成，未创建订单，未启动付款钱包'
            : '本次操作未完成，请在交易记录核实付款，不会重新支付',
      );
      _finish();
    } finally {
      _handling = false;
    }
  }

  void _finish() {
    if (!_active) return;
    final record = _record;
    _stopped = true;
    if (mounted) Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.surfaceCard,
    // 拖动、遮罩与系统返回沿原弹窗退出；不再占一行放关闭叉号。
    child: _error == null
        ? WebViewWidget(controller: _controller)
        : Center(
            child: Padding(
              padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
              child: SingleChildScrollView(
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
                      child: const Text('返回'),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
