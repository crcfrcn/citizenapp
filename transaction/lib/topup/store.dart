import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:isar_community/isar.dart';
import 'package:citizen_storage/user_isar.dart' as storage;

import 'package:citizen_transaction/topup/topup_models.dart';

/// 已支付只表示付款链验款成功；发币请求结果不改写真实付款事实。
enum TopupProgress { pending, paid, completed }

class TopupRecord {
  const TopupRecord({
    required this.payment,
    required this.walletId,
    required this.recoveryToken,
    required this.accountSignature,
    this.receipt,
    this.origin = TopupConfig.origin,
    this.progress = TopupProgress.pending,
    this.payer,
    this.txid,
    this.wire,
    this.proof,
    this.requestAt,
    this.checkCount = 0,
    this.checkAt,
    this.failureCode,
  });
  final TopupPayment payment;
  final String origin, walletId, recoveryToken, accountSignature;
  final TopupProgress progress;
  final TopupReceipt? receipt;
  final String? payer, txid, wire, failureCode;
  final TopupProof? proof;
  final int? requestAt, checkAt;
  final int checkCount;
  String get key => '$origin|${payment.orderId}';
  String get signText => topupSignText(payment.toJson(), recoveryToken);
  String get binding => topupBinding(signText, accountSignature);
  String get memo => 'topup:$binding';
  bool get terminal => progress != TopupProgress.pending || failureCode != null;
  bool get isPaid =>
      progress != TopupProgress.pending &&
      proof != null &&
      payer != null &&
      txid != null &&
      proof!.matches(payment, payer!, txid!) &&
      proof!.binding == binding;
  factory TopupRecord.signed(
    TopupDraft draft,
    String walletId,
    String signature, {
    int? now,
  }) {
    if (!TopupWallets.ids.contains(walletId)) {
      throw const FormatException('钱包选择无效');
    }
    return TopupRecord(
      payment: TopupPayment.signed(draft, signature, now: now),
      walletId: walletId,
      recoveryToken: draft.recoveryToken,
      accountSignature: signature,
    );
  }
  TopupRecord update({
    TopupProgress? progress,
    String? payer,
    String? txid,
    String? wire,
    TopupProof? proof,
    int? requestAt,
    int? checkCount,
    int? checkAt,
    TopupReceipt? receipt,
    String? failureCode,
    bool clearFailure = false,
  }) => TopupRecord(
    payment: payment,
    walletId: walletId,
    recoveryToken: recoveryToken,
    accountSignature: accountSignature,
    origin: origin,
    progress: progress ?? this.progress,
    payer: payer ?? this.payer,
    txid: txid ?? this.txid,
    wire: wire ?? this.wire,
    proof: proof ?? this.proof,
    requestAt: requestAt ?? this.requestAt,
    checkCount: checkCount ?? this.checkCount,
    checkAt: checkAt ?? this.checkAt,
    receipt: receipt ?? this.receipt,
    failureCode: clearFailure ? failureCode : failureCode ?? this.failureCode,
  );
  Map<String, Object?> toJson() => {
    'origin': origin,
    'payment': payment.toJson(),
    'wallet_id': walletId,
    'recovery_token': recoveryToken,
    'account_signature': accountSignature,
    'progress': progress.name,
    'payer': payer,
    'txid': txid,
    'wire': wire,
    'proof': proof?.toJson(),
    'request_at': requestAt,
    'check_count': checkCount,
    'check_at': checkAt,
    'receipt': receipt?.toJson(),
    'failure_code': failureCode,
  };
  String encode() => jsonEncode(toJson());
  factory TopupRecord.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    exactTopupFields(j, const {
      'origin',
      'payment',
      'wallet_id',
      'recovery_token',
      'account_signature',
      'progress',
      'payer',
      'txid',
      'wire',
      'proof',
      'request_at',
      'check_count',
      'check_at',
      'receipt',
      'failure_code',
    });
    final payment = TopupPayment.fromJson(j['payment'] as Map<String, dynamic>);
    final record = TopupRecord(
      payment: payment,
      walletId: j['wallet_id'] as String,
      recoveryToken: j['recovery_token'] as String,
      accountSignature: j['account_signature'] as String,
      origin: topupOrigin(j['origin'] as String),
      progress: TopupProgress.values.byName(j['progress'] as String),
      payer: j['payer'] as String?,
      txid: j['txid'] as String?,
      wire: j['wire'] as String?,
      requestAt: j['request_at'] as int?,
      checkCount: j['check_count'] as int,
      checkAt: j['check_at'] as int?,
      failureCode: j['failure_code'] as String?,
      proof: j['proof'] == null
          ? null
          : TopupProof.fromJson(j['proof'] as Map<String, dynamic>),
      receipt: j['receipt'] == null
          ? null
          : TopupReceipt.fromJson(j['receipt'] as Map<String, dynamic>),
    );
    if (record.checkCount < 0 ||
        record.checkCount > 11 ||
        (record.checkCount == 0) != (record.checkAt == null) ||
        record.checkAt != null && record.checkAt! < payment.createdAt ||
        !TopupWallets.ids.contains(record.walletId) ||
        record.origin != TopupConfig.origin ||
        record.payment.orderId != 'top_${record.binding.substring(0, 32)}' ||
        record.payer != null &&
            payment.network.address(record.payer!) != record.payer ||
        record.txid != null && !payment.network.transaction(record.txid!) ||
        record.progress != TopupProgress.pending && !record.isPaid ||
        record.proof != null && !record.isPaid ||
        record.requestAt != null &&
            (!record.isPaid || record.requestAt! < payment.createdAt) ||
        record.wire != null && (record.payer == null || record.wire!.isEmpty) ||
        record.txid != null && record.wire == null) {
      throw const FormatException('本地充值订单事实无效');
    }
    record.receipt?.matches(payment, record.txid ?? '');
    if (record.receipt != null && !record.isPaid ||
        record.progress == TopupProgress.completed &&
            (record.receipt?.state != 'paid' ||
                record.receipt?.sealed != true)) {
      throw const FormatException('订单结果缺少原付款及封存事实');
    }
    return record;
  }
  Map<String, Object?> request({Map<String, Object?>? notify}) {
    if (!isPaid || requestAt == null) throw StateError('禁止未支付订单请求发币');
    return {
      ...payment.toJson(),
      'payer_address': payer,
      'payment_txid': txid,
      'recovery_token': recoveryToken,
      'notify': notify,
      'account_signature': accountSignature,
    };
  }
}

/// 已删除记录的迟到付款回调不能创建第二份订单。
class TopupDeletedException implements Exception {
  const TopupDeletedException();
}

/// 充值恢复和交易展示共用entry，原始凭据仅保留在order_data。
class TopupStore {
  TopupStore();
  static final TopupStore shared = TopupStore();
  static final Expando<Set<String>> _deleted = Expando<Set<String>>();
  static Set<String> _deletedIn(Isar isar) => _deleted[isar] ??= <String>{};
  static final StreamController<TopupChange> _changes =
      StreamController<TopupChange>.broadcast(sync: true);
  static Stream<TopupChange> get changes => _changes.stream;

  static Future<storage.Entry?> _find(
    Isar isar,
    String origin,
    String orderId,
  ) async {
    final rows = await isar
        .collection<storage.Entry>()
        .where()
        .serviceOriginOrderIdEqualTo(origin, orderId)
        .limit(2)
        .findAll();
    if (rows.length > 1) throw StateError('同一充值订单存在重复记录');
    if (rows.isNotEmpty && rows.single.entryKind != 'topup') {
      throw const FormatException('原订单定位被其他业务占用');
    }
    return rows.singleOrNull;
  }

  /// 到账关联只认服务端给出的准确交易哈希、目标和金额，不用备注猜测。
  static bool matchesPayment(storage.Entry order, storage.Entry event) =>
      order.entryKind == 'topup' &&
      event.entryKind == 'transfer' &&
      event.entrySource == 'sdk_finalized_event' &&
      event.entryState == 'finalized' &&
      order.txHash != null &&
      order.txHash == event.txHash &&
      order.accountId == event.accountId &&
      order.transferAmount == event.transferAmount &&
      event.amountDelta == event.transferAmount;

  static void attachPayment(storage.Entry order, storage.Entry event) {
    if (!matchesPayment(order, event)) throw StateError('充值到账事件与订单不一致');
    order
      ..amountDelta = event.amountDelta
      ..confirmedAt = event.confirmedAt
      ..blockHash = event.blockHash
      ..blockNumber = event.blockNumber
      ..eventIndex = event.eventIndex
      ..extrinsicIndex = event.extrinsicIndex;
  }

  static void publish(storage.Entry row, {List<int> removedIds = const []}) =>
      _changes.add(
        TopupChange(
          row.accountId,
          row,
          row.rowId,
          row.serviceOrigin!,
          row.orderId!,
          removedIds,
        ),
      );

  static storage.Entry toEntry(TopupRecord record, {storage.Entry? previous}) {
    final body = record.toJson()
      ..remove('origin')
      ..remove('progress')
      ..remove('failure_code');
    final row = storage.Entry()
      ..accountId = record.payment.accountId
      ..entryKind = 'topup'
      ..entrySource = 'topup_order'
      ..serviceOrigin = record.origin
      ..orderId = record.payment.orderId
      ..entryState = record.progress.name
      ..transferAmount = record.payment.coinFen
      ..amountDelta = previous?.confirmedAt != null
          ? previous!.amountDelta
          : record.progress == TopupProgress.completed
          ? record.payment.coinFen
          : '0'
      ..txHash =
          const {
                TopupProgress.completed,
                TopupProgress.paid,
              }.contains(record.progress) &&
              record.receipt?.sealed == true
          ? record.receipt!.gmbTxHash
          : previous?.txHash
      ..failReason = record.failureCode
      ..createdAt = record.payment.createdAt
      ..confirmedAt = previous?.confirmedAt
      ..blockHash = previous?.blockHash
      ..blockNumber = previous?.blockNumber
      ..eventIndex = previous?.eventIndex
      ..extrinsicIndex = previous?.extrinsicIndex
      ..orderData = jsonEncode(body);
    if (previous != null) row.rowId = previous.rowId;
    return row;
  }

  static TopupRecord fromEntry(storage.Entry row) {
    if (row.entryKind != 'topup' ||
        row.serviceOrigin == null ||
        row.orderId == null ||
        row.orderData == null) {
      throw const FormatException('充值交易记录不完整');
    }
    final body = jsonDecode(row.orderData!) as Map<String, dynamic>;
    if (body.containsKey('origin') || body.containsKey('progress')) {
      throw const FormatException('订单正文不能覆盖原行来源或状态');
    }
    final record = TopupRecord.decode(
      jsonEncode({
        'origin': row.serviceOrigin,
        'progress': row.entryState,
        'failure_code': row.failReason,
        ...body,
      }),
    );
    if (row.orderId != record.payment.orderId ||
        row.accountId != record.payment.accountId ||
        row.createdAt != record.payment.createdAt ||
        row.transferAmount != record.payment.coinFen) {
      throw const FormatException('充值公共列与订单不一致');
    }
    return record;
  }

  Future<List<TopupRecord>> list(String origin, String account) async {
    final rows = await storage.UserIsar.instance.read(
      (isar) => isar
          .collection<storage.Entry>()
          .where()
          .accountIdEqualTo(account)
          .filter()
          .entryKindEqualTo('topup')
          .serviceOriginEqualTo(origin)
          .sortByCreatedAtDesc()
          .findAll(),
    );
    return [for (final row in rows) fromEntry(row)];
  }

  /// 签名会话在内存完成；失败/离页均不保存订单或恢复凭据。
  Future<TopupRecord> signOrder(
    TopupDraft draft,
    String walletId,
    Future<Uint8List> Function(Uint8List) signer, {
    bool Function()? active,
    int? now,
  }) async {
    final signature = await signer(
      Uint8List.fromList(utf8.encode(draft.signText)),
    );
    if (active != null && !active()) throw const TopupDeletedException();
    final encoded =
        '0x${signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final record = TopupRecord.signed(draft, walletId, encoded, now: now);
    await save(record);
    return record;
  }

  Future<void> save(TopupRecord record, {TopupRecord? before}) =>
      _save(record, before: before);
  Future<void> _save(
    TopupRecord record, {
    TopupRecord? before,
    VerifiedTopupReceipt? verified,
  }) async {
    final verifiedUpdate =
        verified != null && identical(verified.receipt, record.receipt);
    TopupRecord.decode(record.encode());
    if (record.encode().length > 24576) throw const FormatException('充值记录超限');
    if (before == null && record.progress != TopupProgress.pending) {
      throw StateError('新订单必须是已签名的待支付订单');
    }
    if (before?.progress != record.progress &&
        record.progress == TopupProgress.completed &&
        !verifiedUpdate) {
      throw StateError('完成状态必须先验真服务端结果');
    }
    if (record.receipt?.sealed == true &&
        before?.encode() != record.encode() &&
        !verifiedUpdate) {
      throw StateError('封存结果必须先验真');
    }
    if (before != null) {
      final sameFacts =
          jsonEncode(record.payment.toJson()) ==
              jsonEncode(before.payment.toJson()) &&
          record.origin == before.origin &&
          record.walletId == before.walletId &&
          record.recoveryToken == before.recoveryToken &&
          record.accountSignature == before.accountSignature &&
          (before.payer == null || record.payer == before.payer) &&
          (before.txid == null || record.txid == before.txid) &&
          (before.wire == null || record.wire == before.wire) &&
          (before.proof == null ||
              jsonEncode(record.proof?.toJson()) ==
                  jsonEncode(before.proof!.toJson())) &&
          (record.checkCount == before.checkCount &&
                  (record.checkAt == before.checkAt ||
                      before.progress == TopupProgress.pending &&
                          record.progress == TopupProgress.pending &&
                          before.checkAt != null &&
                          record.checkAt != null &&
                          record.checkAt! >= before.checkAt!) ||
              before.progress == TopupProgress.pending &&
                  record.progress == TopupProgress.pending &&
                  record.checkCount == before.checkCount + 1 &&
                  record.checkAt != null &&
                  (before.checkAt == null ||
                      record.checkAt! >= before.checkAt!)) &&
          (before.requestAt == null || record.requestAt == before.requestAt) &&
          (before.receipt == null ||
              record.receipt != null &&
                  record.receipt!.publicKey == before.receipt!.publicKey &&
                  record.receipt!.revision >= before.receipt!.revision);
      if (!sameFacts ||
          record.progress.index < before.progress.index ||
          before.progress == TopupProgress.pending &&
              record.progress == TopupProgress.completed ||
          before.progress == TopupProgress.pending &&
              before.failureCode != null &&
              before.encode() != record.encode()) {
        throw StateError('原订单事实不能替换或重新付款');
      }
    }
    storage.Entry? changed;
    final removedIds = <int>[];
    await storage.UserIsar.instance.writeTxn((isar) async {
      final hash = verifiedUpdate ? record.receipt?.gmbTxHash : null;
      final rows = hash == null
          ? [?await _find(isar, record.origin, record.payment.orderId)]
          : await isar
                .collection<storage.Entry>()
                .filter()
                .group(
                  (q) => q
                      .serviceOriginEqualTo(record.origin)
                      .orderIdEqualTo(record.payment.orderId),
                )
                .or()
                .group(
                  (q) => q
                      .accountIdEqualTo(record.payment.accountId)
                      .txHashEqualTo(hash)
                      .entryKindEqualTo('transfer')
                      .entrySourceEqualTo('sdk_finalized_event'),
                )
                .limit(4)
                .findAll();
      final orders = rows.where((row) => row.entryKind == 'topup').toList();
      if (orders.length > 1) throw StateError('同一充值订单存在重复记录');
      final current = orders.singleOrNull;
      if (_deletedIn(isar).contains(record.key) ||
          current == null && before != null) {
        throw const TopupDeletedException();
      }
      final encoded = current == null ? null : fromEntry(current).encode();
      final events = rows.where((row) => row.entryKind != 'topup').toList();
      // 更新必须消费当前快照；同毫秒重复验款也不能重新生成请求能力。
      if (before != null && encoded != before.encode() ||
          before == null && encoded != null && encoded != record.encode()) {
        throw StateError('充值记录已变化，不能覆盖原订单');
      }
      if (encoded == record.encode() && events.isEmpty) return;
      final next = toEntry(record, previous: current);
      if (events.length > 1 ||
          events.any((event) => !matchesPayment(next, event))) {
        throw StateError('充值到账事件与订单不一致');
      }
      for (final event in events) {
        attachPayment(next, event);
        await isar.collection<storage.Entry>().delete(event.rowId);
        removedIds.add(event.rowId);
      }
      await isar.collection<storage.Entry>().put(next);
      changed = next;
    });
    final row = changed;
    if (row != null) publish(row, removedIds: removedIds);
  }

  /// 已支付与单次请求占位一起提交；只在事务成功后交付不可重用的请求能力。
  Future<PaidTopupOrder> markPaid(
    TopupRecord submitted,
    TopupProof proof,
  ) async {
    if (submitted.progress != TopupProgress.pending ||
        submitted.failureCode != null ||
        submitted.wire == null ||
        submitted.payer == null ||
        submitted.txid == null ||
        (!proof.matches(submitted.payment, submitted.payer!, submitted.txid!) ||
            proof.binding != submitted.binding)) {
      throw StateError('付款证据不属于原订单');
    }
    final paid = submitted.update(
      progress: TopupProgress.paid,
      proof: proof,
      requestAt: DateTime.now().millisecondsSinceEpoch,
    );
    await save(paid, before: submitted);
    return PaidTopupOrder._(paid);
  }

  /// HTTPS受理先固化服务公钥；封存结果由SDK纯验签，网络/密码学都在事务外。
  Future<TopupRecord> acceptReceipt(
    TopupRecord before,
    TopupReceipt receipt,
  ) async {
    if (!before.isPaid || before.requestAt == null) {
      throw StateError('未支付原单禁止接收发币结果');
    }
    receipt.matches(before.payment, before.txid!);
    final prior = before.receipt;
    if (prior != null &&
        (receipt.publicKey != prior.publicKey ||
            receipt.revision < prior.revision ||
            prior.sealed && !prior.sameResult(receipt))) {
      throw StateError('结果身份或封存原件不可替换');
    }
    final verified = receipt.sealed
        ? await receipt.verify(before.payment, before.txid!)
        : null;
    final next = before.update(
      receipt: receipt,

      clearFailure: true,
      failureCode: receipt.reason,
      progress: verified == null
          ? before.progress
          : receipt.state == 'paid'
          ? TopupProgress.completed
          : TopupProgress.paid,
    );
    await _save(next, before: before, verified: verified);
    return next;
  }

  Future<List<TopupRecord>> all() async {
    final rows = await storage.UserIsar.instance.read(
      (isar) => isar
          .collection<storage.Entry>()
          .filter()
          .entryKindEqualTo('topup')
          .findAll(),
    );
    final records = <TopupRecord>[];
    for (final row in rows) {
      try {
        records.add(fromEntry(row));
      } on Object {
        /* 损坏记录由交易列表展示错误，不能进入资金流程。 */
      }
    }
    return records;
  }

  Future<void> delete(storage.Entry snapshot) async {
    final origin = snapshot.serviceOrigin, orderId = snapshot.orderId;
    if (snapshot.entryKind != 'topup' || origin == null || orderId == null) {
      throw const FormatException('充值删除目标不完整');
    }
    final key = '$origin|${validateOrderId(orderId)}';
    Isar? database;
    await storage.UserIsar.instance.writeTxn((isar) async {
      database = isar;
      final current = await isar.collection<storage.Entry>().get(
        snapshot.rowId,
      );
      if (current == null) return;
      if (current.orderId != snapshot.orderId ||
          current.serviceOrigin != snapshot.serviceOrigin ||
          current.accountId != snapshot.accountId) {
        throw StateError('充值删除目标已变化');
      }
      await isar.collection<storage.Entry>().delete(current.rowId);
    });
    _deletedIn(database!).add(key);
    _changes.add(
      TopupChange(snapshot.accountId, null, snapshot.rowId, origin, orderId),
    );
  }
}

/// 事务成功后交付同一行快照；页面直接更新内存，不为订单变化重新读库。
class TopupChange {
  const TopupChange(
    this.accountId,
    this.record,
    this.rowId,
    this.origin,
    this.orderId, [
    this.removedIds = const [],
  ]);
  final String accountId, origin, orderId;
  final storage.Entry? record;
  final int rowId;
  final List<int> removedIds;
  List<storage.Entry> apply(List<storage.Entry> current, {required int limit}) {
    final result = current
        .where(
          (entry) => entry.rowId != rowId && !removedIds.contains(entry.rowId),
        )
        .toList();
    final next = record;
    if (next != null) result.add(next);
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result.take(limit).toList();
  }
}

/// 仅同库保存完成后生成，不可从WebView布尔字段或外部JSON构造。
class PaidTopupOrder {
  PaidTopupOrder._(this.record);
  final TopupRecord record;
  bool _used = false;
  Map<String, Object?> take({Map<String, Object?>? notify}) {
    if (_used) throw StateError('原已支付订单的发币请求已使用');
    _used = true;
    return record.request(notify: notify);
  }
}
