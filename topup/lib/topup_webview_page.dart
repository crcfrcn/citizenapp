import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/app_log.dart';

import 'package:citizen_topup/topup_api.dart';
import 'package:citizen_topup/topup_erc20.dart';
import 'package:citizen_topup/store.dart';
import 'package:citizen_topup/wallet_link_dispatcher.dart';

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
  bool _loaded = false, _scriptReady = false, _invalid = false;
  bool get canBegin => !_invalid && _loaded && _scriptReady && !started;
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

  // 初次装配仍须完整JS验真；绑定后禁止主框架导航和子框架，重载立即失效。
  bool mayNavigate(String url, {required bool mainFrame}) =>
      !_invalid &&
      mainFrame &&
      !started &&
      (url == baseUrl || url == 'about:blank');

  void navigating() {
    if (started) _invalid = true;
  }

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

  // 回执使用已验真的本地文档绑定与原生URL；不等后台WebView再执行JS证明。
  bool accepts(String? currentUrl) =>
      !_invalid && started && currentUrl == _url;

  bool ownsReady(Map<String, dynamic> value) =>
      value.length == 3 &&
      value['kind'] == 'document_ready' &&
      value['nonce'] == _nonce &&
      value['ready'] is bool;
}

/// App根层复用连接；付款只接收已经签名保存的真实订单。
class TopupWalletSession extends ChangeNotifier {
  Future<TopupRecord?> Function(TopupRecord, TopupStore, bool Function())? _pay;
  void Function(String)? _leave;
  final _attached = Completer<void>();
  bool _closed = false, _started = false;
  bool get started => _started;
  void prepare() {
    if (!_closed && !_started) {
      _started = true;
      notifyListeners();
    }
  }

  Future<TopupRecord?> pay(
    TopupRecord record,
    TopupStore store, {
    bool Function()? presenting,
  }) async {
    if (_closed) throw StateError('付款通信已关闭');
    prepare();
    await _attached.future;
    if (_closed) throw StateError('本次付款已结束');
    return _pay!(record, store, presenting ?? () => true);
  }

  void leave(String orderId) => _leave?.call(orderId);
  void close() {
    _closed = true;
    if (!_attached.isCompleted) _attached.complete();
  }
}

// 记录、完成回执和界面归属均按签后真实order_id隔离。
class _Payment {
  _Payment(this.record, this.store, this.presenting);
  TopupRecord? record;
  final TopupStore store;
  final bool Function() presenting;
  final completion = Completer<TopupRecord?>();
  bool dispatched = false, stopped = false;
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
  final _payments = <String, _Payment>{};
  final _seen = <int>{};
  final _ready = Completer<void>();
  static const _storage = MethodChannel('citizenapp/metamask');
  TopupDocument? _document;
  String? _error;
  bool _closed = false;
  bool get _active => mounted && !_closed && !widget.session._closed;
  StreamSubscription<TopupChange>? _recordChanges;

  @override
  void initState() {
    super.initState();
    AppLog.topupReadiness('loading');
    widget.session._pay = _pay;
    widget.session._leave = _leave;
    if (!widget.session._attached.isCompleted) {
      widget.session._attached.complete();
    }
    _recordChanges = TopupStore.changes.listen((change) {
      final payment = _payments[change.orderId],
          record = _payments[change.orderId]?.record;
      if (payment == null ||
          record == null ||
          change.accountId != record.payment.accountId ||
          change.origin != record.origin) {
        return;
      }
      if (change.record != null) {
        payment.record = TopupStore.fromEntry(change.record!);
      } else {
        payment.record = null;
        payment.stopped = true;
        if (!payment.completion.isCompleted) payment.completion.complete(null);
        _cancel(change.orderId);
      }
    });
    _links = WalletLinkDispatcher(
      launcher: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    _controller = WebViewController();
    unawaited(_loadDocument());
  }

  void _cancel(String orderId) {
    final doc = _document;
    if (doc != null && doc.started) {
      unawaited(
        _controller
            .runJavaScript(
              'if (${doc.check}) CitizenTopup.cancel(${jsonEncode(orderId)})',
            )
            .catchError((Object _) {}),
      );
    }
  }

  void _leave(String orderId) {
    final payment = _payments[orderId];
    if (payment == null || payment.stopped || payment.dispatched) return;
    payment.stopped = true;
    _cancel(orderId);
    final record = payment.record;
    if (record != null && !record.terminal && record.txid == null) {
      unawaited(
        payment.store
            .save(
              record.update(failureCode: 'wallet_view_closed'),
              before: record,
            )
            .catchError((Object _) {}),
      );
    }
    if (!payment.completion.isCompleted) payment.completion.complete(record);
  }

  @override
  void dispose() {
    _closed = true;
    widget.session.close();
    if (!_ready.isCompleted) _ready.complete();
    unawaited(_recordChanges?.cancel());
    final doc = _document;
    if (doc != null && doc.started) {
      unawaited(
        _controller
            .runJavaScript('if (${doc.check}) CitizenTopup.close()')
            .catchError((Object _) {}),
      );
    }
    for (final payment in _payments.values) {
      final record = payment.record;
      if (!payment.stopped &&
          record != null &&
          !record.terminal &&
          record.txid == null) {
        unawaited(
          payment.store
              .save(
                record.update(failureCode: 'wallet_view_closed'),
                before: record,
              )
              .catchError((Object _) {}),
        );
      }
      payment.stopped = true;
      if (!payment.completion.isCompleted) payment.completion.complete(record);
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
          // 每条回执独立处理，签名或其他订单的等待不能占用本条消息。
          unawaited(
            _message(message).catchError((Object _) {
              AppLog.d('topup_bridge_stopped');
            }),
          );
        },
      );
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _document?.navigating(),
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
        'packages/citizen_topup/web/metamask.html',
      );
      final bytes = await rootBundle.load(
        'packages/citizen_topup/web/metamask.bundle.js',
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
        _error = '付款钱包初始化失败';
        AppLog.topupReadiness('failed');
        if (!_ready.isCompleted) _ready.complete();
      }
    }
  }

  Future<bool> _trusted() async {
    final document = _document;
    if (!_active || document == null || !document.started) return false;
    try {
      final url = await _controller.currentUrl();
      return _active && identical(_document, document) && document.accepts(url);
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
        _error = '付款钱包初始化失败';
        AppLog.topupReadiness('failed');
        if (!_ready.isCompleted) _ready.complete();
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
    TopupRecord record,
    TopupStore store,
    bool Function() presenting,
  ) async {
    final id = record.payment.orderId;
    final existing = _payments[id];
    if (existing != null) {
      // 同一实际订单不能被重新付款；其他订单不受它的等待或结果影响。
      if (existing.record?.wire != record.wire ||
          existing.record?.accountSignature != record.accountSignature) {
        throw const FormatException('订单与原签名不一致');
      }
      return existing.completion.future;
    }
    if (record.terminal ||
        record.failureCode != null ||
        record.txid != null ||
        record.wire != jsonEncode(_transaction(record))) {
      throw const FormatException('订单不能再次发起付款');
    }
    final payment = _Payment(record, store, presenting);
    _payments[id] = payment;
    try {
      await _ready.future.timeout(const Duration(seconds: 30));
      if (_error != null) throw StateError(_error!);
      if (!_active || payment.stopped) return payment.record;
      if (!presenting()) {
        _leave(id);
        return payment.record;
      }
      final doc = _document!;
      final cfg = {
        'session': _session,
        'order_id': id,
        'selection': {
          'token': record.payment.token,
          'network': record.payment.network.wire,
          'package_id': record.payment.packageId,
        },
        'transaction': _transaction(record),
      };
      // 交付后由根层等待本单回执，不因弹窗离页丢弃在途付款结果。
      payment.dispatched = true;
      await _controller.runJavaScript(
        'if (${doc.check}) CitizenTopup.start(${jsonEncode(cfg)})',
      );
    } on Object {
      await _failure(payment, 'client_payment_unverified');
      _finish(payment);
    }
    return payment.completion.future;
  }

  Future<void> _reply(int id, {Object? value, String? error}) async {
    final doc = _document;
    if (doc == null) return;
    AppLog.topupPhase('reply_requested');
    try {
      if (!await _trusted()) {
        AppLog.topupPhase('reply_untrusted');
        return;
      }
      await _controller.runJavaScript(
        'if (${doc.check}) CitizenTopup.reply(${jsonEncode(_session)},$id,${jsonEncode({'ok': error == null, 'value': value, 'error': error})})',
      );
      AppLog.topupPhase('reply_completed');
    } on Object {
      // JS确认不可用不能撤销已经落库的广播事实，也不能阻止原生恢复前台。
      AppLog.d('topup_reply_unavailable');
    }
  }

  Future<void> _failure(_Payment payment, String code) async {
    final record = payment.record;
    // 已知广播哈希交由付款链验款裁决，界面/通信错误不能覆盖这一事实。
    if (record == null || record.terminal || record.txid != null) return;
    final next = record.update(failureCode: code);
    try {
      await payment.store.save(next, before: record);
      payment.record = next;
    } on Object {
      /* 原行已经改变/删除时不覆盖或重新插入。 */
    }
  }

  Future<void> _message(JavaScriptMessage message) async {
    if (!_active || _document == null || message.message.length > 32768) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } on Object {
      return;
    }
    final doc = _document!;
    if (data['kind'] == 'document_ready') {
      if (!doc.ownsReady(data) || doc.started) return;
      if (data['ready'] != true) {
        _error = '付款组件初始化失败';
        if (!_ready.isCompleted) _ready.complete();
        return;
      }
      doc.ready(data);
      AppLog.topupReadiness('script_ready');
      await _start();
      return;
    }
    final id = data['id'];
    if (data['session'] != _session ||
        id is! int ||
        id <= 0 ||
        !_seen.add(id)) {
      return;
    }
    if (data['kind'] == 'phase') {
      final payment = _payments[data['order_id']];
      // 仅观察固定阶段，不等待再次执行JS，也不授予存储、唤起或订单更新权限。
      // 这是Dart收到消息的时刻，不能当成钱包端响应的物理时刻。
      if (payment != null &&
          payment.record != null &&
          !payment.stopped &&
          payment.dispatched &&
          const {
            'connect_requested',
            'connect_ready',
            'transaction_requested',
            'result_received',
          }.contains(data['state'])) {
        AppLog.topupPhase(data['state']);
      }
      return;
    }
    AppLog.topupPhase('bridge_received');
    if (!await _trusted()) {
      AppLog.topupPhase('bridge_untrusted');
      return;
    }
    AppLog.topupPhase('bridge_verified');
    if (data['kind'] == 'wallet_storage') {
      try {
        final key = data['key'];
        if (!const ['channel', 'accounts', 'chain'].contains(key)) {
          throw const FormatException();
        }
        if (data.containsKey('value')) {
          final value = data['value'];
          if (value != null && (value is! String || value.length > 16384)) {
            throw const FormatException();
          }
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
    if (data['kind'] == 'wallet_link') {
      // 链接只属于SDK连接；订单回执仍须按真实order_id和冻结交易校验。
      bool inFlight() =>
          _active &&
          _payments.values.any(
            (payment) =>
                payment.dispatched &&
                !payment.stopped &&
                payment.record != null &&
                !payment.record!.terminal,
          );
      if (!inFlight() || data.containsKey('order_id')) {
        AppLog.topupPhase('link_inactive');
        await _reply(id, error: '未能打开付款钱包');
        return;
      }
      final String? channel;
      try {
        channel = await _storage.invokeMethod<String>('read', {
          'key': 'channel',
        });
      } on Object {
        AppLog.topupPhase('link_storageError');
        await _reply(id, error: '未能打开付款钱包');
        return;
      }
      _links.restore(channel);
      if (!inFlight()) {
        AppLog.topupPhase('link_inactive');
        await _reply(id, error: '未能打开付款钱包');
        return;
      }
      AppLog.topupPhase('link_requested');
      final rawUrl = data['url'];
      final result = rawUrl is String
          ? await _links.open(rawUrl)
          : WalletLinkResult.urlInvalid;
      final delivered = result == WalletLinkResult.opened;
      // 单次调用返回自身原因；系统接受链接仍不证明钱包执行了RPC。
      AppLog.topupPhase(delivered ? 'link_delivered' : 'link_${result.name}');
      await _reply(id, error: delivered ? null : '未能打开付款钱包');
      return;
    }
    final payment = _payments[data['order_id']],
        record = _payments[data['order_id']]?.record;
    if (payment == null || record == null || payment.stopped) return;
    try {
      if (data['kind'] == 'error') {
        // 已保存的广播事实不能被较晚的界面超时覆盖，更不能改成发币请求失败。
        if (record.txid != null || record.isPaid) return;
        AppLog.topupFailure(
          data['stage'],
          data['code'],
          rpcCode: data['rpc_code'],
          detail: data['detail'],
        );
        await _failure(
          payment,
          data['code'] == 'user_rejected'
              ? 'payment_cancelled'
              : data['code'] == 'payment_failed'
              ? 'payment_failed'
              : 'payment_unverified',
        );
        _finish(payment);
        return;
      }
      final expected = _transaction(record), transaction = data['transaction'];
      if (transaction is! Map ||
          transaction.length != expected.length ||
          expected.entries.any(
            (entry) => transaction[entry.key] != entry.value,
          )) {
        throw const FormatException('付款交易与原签名订单不一致');
      }
      if (data['kind'] != 'submitted') throw const FormatException('未知钱包操作');
      if (record.isPaid && data['txid'] == record.txid) {
        _finish(payment);
        await _reply(id, value: {'submitted': true});
        return;
      }
      final tx = data['txid'], payer = data['payer'];
      if (!payment.dispatched ||
          record.terminal ||
          data['network'] != record.payment.network.wire ||
          data['chain'] != record.payment.network.caip2 ||
          tx is! String ||
          !record.payment.network.transaction(tx) ||
          record.txid != null && record.txid != tx ||
          payer != null &&
              (payer is! String ||
                  record.payment.network.address(payer) != payer)) {
        throw const FormatException('付款回执与原交易不一致');
      }
      if (!mounted) return;
      final updates = context.read<TopupUpdates>();
      final sent = record.update(
        txid: tx,
        payer: payer as String?,
        clearFailure: true,
      );
      await payment.store.save(sent, before: record);
      payment.record = sent;
      updates.verifyPayment(sent);
      // 先保存并恢复原生前台；JS确认可以等App恢复后完成，不能反过来阻塞回跳。
      _finish(payment);
      await _reply(id, value: {'submitted': true});
    } on Object {
      await _failure(
        payment,
        record.isPaid
            ? 'issuance_request_unresolved'
            : 'client_payment_unverified',
      );
      _finish(payment);
      await _reply(id, error: '本次操作未完成，请核实原订单');
    }
  }

  Map<String, Object> _transaction(TopupRecord record) =>
      erc20Transaction(record.payment, record.binding);
  void _finish(_Payment payment) {
    final record = payment.record;
    final finished = record != null && (record.txid != null || record.terminal);
    final firstResult = finished && !payment.stopped;
    // 待核实只结束界面等待，原请求的迟到回执仍可进入本单；不允许重新付款。
    if (finished) payment.stopped = true;
    if (firstResult &&
        _active &&
        // 旧单迟到结果照常验款，但不抢占较新订单在钱包中的确认界面。
        identical(_payments.values.last, payment) &&
        (record.txid != null ||
            const [
              'payment_cancelled',
              'payment_failed',
            ].contains(record.failureCode))) {
      unawaited(
        _storage.invokeMethod<bool>('return').catchError((Object _) => false),
      );
    }
    if (!payment.completion.isCompleted) payment.completion.complete(record);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
