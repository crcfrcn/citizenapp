import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:citizen_sdk/citizen_sdk.dart'
    show CitizenSdk, CitizenSigningTransform, CitizenSdkException;
import 'package:citizen_scanner/qr_sign_session_page.dart'
    show signCitizenPayload;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/app_log.dart';

import 'package:citizen_transaction/topup/topup_api.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
import 'package:citizen_transaction/topup/topup_erc20.dart';
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_transaction/topup/wallet_link_dispatcher.dart';

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
  bool _loaded = false, _scriptReady = false;
  bool get canBegin => _loaded && _scriptReady && !started;
  void loaded(String url) {
    if (mayNavigate(url, mainFrame: true)) _loaded = true;
  }

  void ready(Map<String, dynamic> value) {
    if (ownsReady(value) && value['ready'] == true) _scriptReady = true;
  }

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
    if (!canBegin ||
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

/// App只持有一个付款通信宿主；弹窗交付原选择，不新增订单页面。
class TopupWalletSession extends ChangeNotifier {
  Future<TopupRecord?> Function(
    BuildContext,
    TopupSelection,
    String,
    TopupApi,
    TopupStore,
  )?
  _pay;
  final _attached = Completer<void>();
  bool _closed = false, _started = false;
  bool get started => _started;

  // 只预备随包本地文档；不初始化SDK、不连接钱包、不签名或创建订单。
  void prepare() {
    if (!_closed && !_started) {
      _started = true;
      notifyListeners();
    }
  }

  Future<TopupRecord?> pay(
    BuildContext context,
    TopupSelection selection,
    String accountId,
    TopupApi api,
    TopupStore store,
  ) async {
    if (_closed) throw StateError('付款通信已关闭');
    prepare();
    await _attached.future;
    if (_closed || !context.mounted) throw StateError('本次付款已结束');
    return _pay!(context, selection, accountId, api, store);
  }

  void close() {
    _closed = true;
    if (!_attached.isCompleted) _attached.complete();
  }
}

class TopupWebviewPage extends StatefulWidget {
  const TopupWebviewPage({super.key, required this.session});
  final TopupWalletSession session;
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
  bool _handling = false, _opened = false, _stopped = true, _closed = false;
  String? _operation;
  String _accountId = '';
  TopupSelection? _selection;
  TopupStore? _store;
  BuildContext? _context;
  Completer<TopupRecord?>? _completion;
  final _ready = Completer<void>();
  static const _storage = MethodChannel('citizenapp/metamask');
  bool get _active => mounted && !_closed && !widget.session._closed;
  bool get _current => _active && !_stopped && _operation != null;
  int _last = 0;
  TopupRecord? _record;
  Future<void> _messages = Future<void>.value();
  StreamSubscription<TopupChange>? _recordChanges;
  @override
  void initState() {
    super.initState();
    AppLog.topupReadiness('loading');
    widget.session._pay = _pay;
    if (!widget.session._attached.isCompleted)
      widget.session._attached.complete();
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
        _completion?.complete(null);
        _completion = null;
        final document = _document;
        if (document != null && document.started) {
          unawaited(
            _controller
                .runJavaScript(
                  'if (${document.check}) CitizenTopup.cancel(${jsonEncode(_operation)})',
                )
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
    _closed = true;
    _stopped = true;
    widget.session.close();
    if (!_ready.isCompleted) _ready.complete();
    if (!(_completion?.isCompleted ?? true)) _completion!.complete(_record);
    _completion = null;
    unawaited(_recordChanges?.cancel());
    final document = _document;
    if (document != null && document.started) {
      // App关闭才释放通信宿主；不在每笔订单结束时销毁有效会话。
      unawaited(
        _controller
            .runJavaScript('if (${document.check}) CitizenTopup.close()')
            .catchError((Object _) {}),
      );
    }
    final record = _record;
    // 签名建单时已保存wire；离页未核实应按是否收到交易哈希判断，不能再依赖旧准备阶段。
    if (leftWithoutResult &&
        record != null &&
        !record.terminal &&
        record.txid == null) {
      final progress = record.progress;
      unawaited(
        _store!
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
          onPageFinished: (url) {
            _document?.loaded(url);
            AppLog.topupReadiness('loaded');
            unawaited(_start());
          },
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
      if (_active) {
        _stopped = true;
        _error = '付款钱包初始化失败';
        AppLog.topupReadiness('failed');
        if (!_ready.isCompleted) _ready.complete();
        _finish();
      }
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
    if (!_active || document == null || !document.canBegin) return;
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
      if (_active) {
        _stopped = true;
        _error = '付款钱包初始化失败';
        AppLog.topupReadiness('failed');
        if (!_ready.isCompleted) _ready.complete();
        _finish();
      }
      return;
    }
    if (!_active) return;
    if (!_ready.isCompleted) {
      _ready.complete();
      AppLog.topupReadiness('ready');
    }
  }

  Future<TopupRecord?> _pay(
    BuildContext context,
    TopupSelection selection,
    String accountId,
    TopupApi api,
    TopupStore store,
  ) async {
    if (_current || _handling) throw StateError('上一笔付款尚未结束');
    try {
      await _ready.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      AppLog.topupReadiness('timeout');
      throw StateError('付款组件初始化超时');
    }
    if (_error != null) throw StateError(_error!);
    if (_current || _handling) throw StateError('上一笔付款尚未结束');
    if (!_active || !context.mounted) throw StateError('本次付款已结束');
    _accountId = accountId;
    _selection = selection;
    _store = store;
    _context = context;
    _record = null;
    _opened = false;
    _stopped = false;
    _error = null;
    _operation = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final completion = Completer<TopupRecord?>();
    _completion = completion;
    final document = _document!;
    final cfg = {
      'session': _session,
      'operation': _operation,
      'selection': selection.toJson(),
    };
    // 在同一JS执行中再核对本次文档，避免异步原生检查后导航提交的竞态。
    try {
      await _controller.runJavaScript(
        'if (${document.check}) CitizenTopup.start(${jsonEncode(cfg)})',
      );
    } on Object {
      _error = '付款组件启动失败';
      _finish();
    }
    return completion.future;
  }

  Future<void> _reply(int id, {Object? value, String? error}) async {
    final document = _document;
    if (document == null || !await _trusted()) return;
    await _controller.runJavaScript(
      'if (${document.check}) CitizenTopup.reply(${jsonEncode(_session)},$id,${jsonEncode({'ok': error == null, 'value': value, 'error': error})})',
    );
  }

  Future<void> _save(TopupRecord next) async {
    await _store!.save(next, before: _record);
    if (!_current) {
      if (!next.terminal) {
        final progress = next.progress;
        try {
          await _store!.save(
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
        _error = '付款组件初始化失败，可关闭后重新选择';
        if (!_ready.isCompleted) _ready.complete();
        return;
      }
      document.ready(data);
      AppLog.topupReadiness('script_ready');
      await _start();
      return;
    }
    final id = data['id'];
    if (data['session'] != _session || id is! int || id <= 0) return;
    if (!await _trusted()) return;
    if (id <= _last) return;
    if (data['kind'] == 'wallet_storage') {
      _last = id;
      try {
        final key = data['key'];
        if (!const ['channel', 'accounts', 'chain'].contains(key))
          throw const FormatException();
        if (data.containsKey('value')) {
          final value = data['value'];
          if (value != null && (value is! String || value.length > 16384))
            throw const FormatException();
          await _storage.invokeMethod<void>('write', {
            'key': key,
            'value': value,
          });
          if (key == 'channel') _links.restore(value as String?);
          await _reply(id);
        } else {
          final value = await _storage.invokeMethod<String>('read', {
            'key': key,
          });
          if (key == 'channel') _links.restore(value);
          await _reply(id, value: value);
        }
      } on Object {
        await _reply(id, error: '钱包会话保存不可用');
      }
      return;
    }
    if (!_current || data['operation'] != _operation) return;
    if (data['kind'] == 'external_wallet') {
      _last = id;
      if (_opened) {
        await _reply(id, error: '本次付款只能打开钱包一次');
        return;
      }
      if (_record == null ||
          _record!.progress != TopupProgress.pending ||
          _record!.wire == null) {
        await _reply(id, error: '本地订单尚未完整保存或已经结束');
        return;
      }
      final expected = _transaction(_record!);
      final sent = data['transaction'];
      if (sent is! Map ||
          sent.length != expected.length ||
          expected.entries.any((entry) => sent[entry.key] != entry.value)) {
        await _reply(id, error: '付款交易与原签名订单不一致');
        return;
      }
      AppLog.topupWallet('requested');
      _opened = true;
      try {
        final opened = await _links.open(data['url'] as String);
        AppLog.topupWallet(opened ? 'opened' : 'rejected');
        await _reply(id, error: opened ? null : '未能打开付款钱包');
      } on Object {
        AppLog.topupWallet('rejected');
        await _reply(id, error: '未能打开付款钱包');
      }
      return;
    }
    if (data['kind'] == 'error') {
      AppLog.topupFailure(
        data['stage'],
        data['code'],
        rpcCode: data['rpc_code'],
        detail: data['detail'],
      );
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
                  : code == 'payment_failed'
                  ? 'payment_failed'
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
        if (_record != null) throw StateError('一次链点击只能创建一个订单');
        AppLog.topupOrder('signing');
        final draft = TopupDraft.create(_selection!, _accountId);
        final created = await _store!.signOrder(draft, TopupWallet.id, (
          payload,
        ) async {
          final signature = await signCitizenPayload(
            signing: _context!.read<CitizenSdk>(),
            context: _context!,
            accountId: _accountId,
            payload: payload,
            action: TopupDraft.action,
            transform: CitizenSigningTransform.raw(),
          );
          AppLog.topupOrder('signed');
          return signature;
        }, active: () => _current && (_context?.mounted ?? false));
        if (!_current) return;
        _record = created;
        AppLog.topupOrder('saved');
        await _reply(id, value: {'transaction': _transaction(created)});
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
      final expected = _transaction(current);
      final transaction = data['transaction'];
      if (transaction is! Map ||
          transaction.length != expected.length ||
          expected.entries.any(
            (entry) => transaction[entry.key] != entry.value,
          )) {
        throw const FormatException('付款交易与原签名订单不一致');
      }
      if (data['kind'] == 'submitted') {
        final tx = data['txid'], payer = data['payer'];
        if (!_opened ||
            current.wire != jsonEncode(expected) ||
            data['network'] != _selection!.network.wire ||
            data['chain'] != _selection!.network.caip2 ||
            tx is! String ||
            !current.payment.network.transaction(tx) ||
            current.txid != null && current.txid != tx ||
            payer != null &&
                (payer is! String ||
                    current.payment.network.address(payer) != payer)) {
          throw const FormatException('付款回执与原交易不一致');
        }
        if (!mounted) return;
        final updates = context.read<TopupUpdates>();
        final sent = current.update(txid: tx, payer: payer as String?);
        // 先保存唯一交易定位；即使页面随后关闭，也由App继续验款。
        await _store!.save(sent, before: current);
        _record = sent;
        updates.verifyPayment(sent);
        if (_active) await _reply(id, value: {'submitted': true});
        _finish();
      } else {
        throw const FormatException('未知钱包操作');
      }
    } on TopupDeletedException {
      _record = null;
      _finish();
    } on Object catch (error) {
      if (data['kind'] == 'create_order')
        AppLog.topupOrder(
          'failed',
          sdkCode: error is CitizenSdkException ? error.code : null,
        );
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

  Map<String, Object> _transaction(TopupRecord record) =>
      erc20Transaction(record.payment, record.binding);

  void _finish() {
    if (!_active) return;
    final record = _record;
    if (_opened &&
        record != null &&
        (record.txid != null ||
            const [
              'payment_cancelled',
              'payment_failed',
            ].contains(record.failureCode))) {
      // SDK已经交付真实回执或明确拒绝；只恢复本应用，不替钱包确认交易。
      unawaited(
        _storage.invokeMethod<bool>('return').catchError((Object _) => false),
      );
    }
    _stopped = true;
    final completion = _completion;
    _completion = null;
    if (completion != null && !completion.isCompleted) {
      if (record == null) {
        completion.completeError(StateError(_error ?? '充值签名或保存未完成，未创建订单'));
      } else {
        completion.complete(record);
      }
    }
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
