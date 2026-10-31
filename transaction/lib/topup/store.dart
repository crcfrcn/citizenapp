import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:citizen_storage/user_isar.dart' as storage;

import 'package:citizen_network/citizen_serve_api_config.dart';
import 'package:citizen_system/security/system_protected_storage.dart';

import 'package:citizen_transaction/topup/topup_models.dart';

/// 只存本订单公开交易和恢复能力，不存钱包私钥、服务端种子或配对URI。
enum TopupProgress { quoted, authorized, submitting, submitted, confirmed }

class TopupRecord {
  const TopupRecord({
    required this.origin,
    required this.intent,
    this.progress = TopupProgress.quoted,
    this.signature,
    this.txid,
    this.wire,
    this.order,
  });
  final String origin;
  final TopupPaymentIntent intent;
  final TopupProgress progress;
  final String? signature, txid, wire;
  final TopupOrder? order;
  bool get terminal => order?.terminal ?? false;
  String get key => '$origin|${intent.orderId}';
  TopupRecord update({
    TopupProgress? progress,
    String? signature,
    String? txid,
    String? wire,
    TopupOrder? order,
  }) => TopupRecord(
    origin: origin,
    intent: intent,
    progress: progress ?? this.progress,
    signature: signature ?? this.signature,
    txid: txid ?? this.txid,
    wire: wire ?? this.wire,
    order: order ?? this.order,
  );
  Map<String, Object?> toJson() => {
    'origin': origin,
    'intent': intent.toJson(),
    'progress': progress.name,
    'signature': signature,
    'txid': txid,
    'wire': wire,
    'order': order?.toJson(),
  };
  String encode() => jsonEncode(toJson());

  // 恢复记录独立校验完整闭集；未知字段不能被模型重编码静默丢弃。
  static void _fields(Map<String, dynamic> value, Set<String> expected) {
    if (value.length != expected.length ||
        !value.keys.every(expected.contains)) {
      throw const FormatException('充值恢复记录字段不完整或含未知字段');
    }
  }

  factory TopupRecord.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    _fields(j, const {
      'origin',
      'intent',
      'progress',
      'signature',
      'txid',
      'wire',
      'order',
    });
    final base = CitizenServeApiConfig.normalize('${j['origin']}/api');
    final i = TopupPaymentIntent.fromJson(j['intent'] as Map<String, dynamic>);
    final signature = j['signature'] as String?;
    final tx = j['txid'] as String?;
    final progress = TopupProgress.values.byName(j['progress'] as String);
    if (signature != null) i.network.signature(signature);
    if (tx != null && !i.network.transaction(tx)) {
      throw const FormatException('恢复交易定位无效');
    }
    if ((progress.index >= TopupProgress.authorized.index &&
            signature == null) ||
        (progress.index >= TopupProgress.submitted.index && tx == null) ||
        (j['wire'] != null && (tx == null || i.network.evmId != null))) {
      throw const FormatException('恢复记录阶段不完整');
    }
    if (j['order'] != null) {
      _fields(j['order'] as Map<String, dynamic>, const {
        'is_ok',
        'order_id',
        'order_state',
        'coin_fen',
        'payment_txid',
        'gmb_tx_hash',
        'exception_reason',
      });
    }
    final o = j['order'] == null
        ? null
        : TopupOrder.fromJson(j['order'] as Map<String, dynamic>);
    if (o != null &&
        (o.orderId != i.orderId ||
            o.coinFen != i.coinFen ||
            o.paymentTxid != null && o.paymentTxid != tx)) {
      throw const FormatException('恢复订单归属错误');
    }
    return TopupRecord(
      origin: topupOrigin(base),
      intent: i,
      progress: progress,
      signature: signature,
      txid: tx,
      wire: j['wire'] as String?,
      order: o,
    );
  }
}

/// 已删除记录的迟到付款回调不能创建第二份订单。
class TopupDeletedException implements Exception {
  const TopupDeletedException();
}

/// 充值恢复和交易展示共用entry，原始凭据仅保留在order_data。
class TopupStore {
  TopupStore({SystemProtectedRecordStore? records}) : _legacy = records;
  final SystemProtectedRecordStore? _legacy;
  Future<void>? _importing;
  static final TopupStore shared = TopupStore();
  static final Expando<Set<String>> _deleted = Expando<Set<String>>();
  static Set<String> _deletedIn(Isar isar) => _deleted[isar] ??= <String>{};
  static final StreamController<TopupChange> _changes =
      StreamController<TopupChange>.broadcast(sync: true);
  static Stream<TopupChange> get changes => _changes.stream;

  Future<void> prepare() {
    if (_legacy == null && !identical(this, shared)) return shared.prepare();
    if (_legacy == null && Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<void>.value();
    }
    return _importing ??= _import().catchError((Object error) {
      _importing = null;
      throw error;
    });
  }

  Future<void> _import() async {
    final legacy = _legacy ?? SystemProtectedRecordStore.topup;
    final values = await legacy.readAll();
    if (values.isEmpty) return;
    final records = values.entries.map((entry) {
      final record = TopupRecord.decode(entry.value);
      if (record.key != entry.key) throw StateError('充值恢复记录归属不一致');
      return record;
    }).toList();
    // 完整校验后一次事务导入；冲突或坏记录不覆盖，不清除旧文件。
    await storage.UserIsar.instance.writeTxn((isar) async {
      for (final record in records) {
        final previous = await _find(
          isar,
          record.origin,
          record.intent.orderId,
        );
        if (previous != null) {
          if (fromEntry(previous).encode() != record.encode()) {
            throw StateError('充值记录切换冲突，保留原记录');
          }
        } else {
          await isar.collection<storage.Entry>().put(toEntry(record));
        }
      }
    });
    // 删除只接受导入时的同一快照；并发旧写入保留并明确报错。
    if (!await legacy.consumeSnapshot(values)) {
      throw StateError('旧充值记录切换期间发生变化');
    }
  }

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
    final row = storage.Entry()
      ..accountId = record.intent.accountId
      ..entryKind = 'topup'
      ..entrySource = 'topup_order'
      ..serviceOrigin = record.origin
      ..orderId = record.intent.orderId
      ..entryState = record.order?.orderState.name ?? record.progress.name
      ..transferAmount = record.intent.coinFen
      ..amountDelta = record.order?.orderState == TopupPhase.paid
          ? record.intent.coinFen
          : '0'
      ..txHash = record.order?.gmbTxHash
      ..failReason = record.order?.exceptionReason
      ..createdAt = record.intent.intentData['issued_at'] as int
      ..confirmedAt = previous?.confirmedAt
      ..blockHash = previous?.blockHash
      ..blockNumber = previous?.blockNumber
      ..eventIndex = previous?.eventIndex
      ..extrinsicIndex = previous?.extrinsicIndex
      ..orderData = jsonEncode({
        'intent_token': record.intent.intentToken,
        'intent_data': record.intent.intentData,
        'sign_message': record.intent.signMessage,
        'progress': record.progress.name,
        'payer_signature': record.signature,
        'payment_txid': record.txid,
        'signed_wire': record.wire,
      });
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
    final data = jsonDecode(row.orderData!) as Map<String, dynamic>;
    TopupRecord._fields(data, const {
      'intent_token',
      'intent_data',
      'sign_message',
      'progress',
      'payer_signature',
      'payment_txid',
      'signed_wire',
    });
    final progress = TopupProgress.values.byName(data['progress'] as String);
    final hasOrder = TopupPhase.values.any(
      (phase) => phase.name == row.entryState,
    );
    if (!hasOrder && row.entryState != progress.name) {
      throw const FormatException('充值状态与恢复进度不一致');
    }
    final record = TopupRecord.decode(
      jsonEncode({
        'origin': row.serviceOrigin,
        'intent': {
          'is_ok': true,
          'order_id': row.orderId,
          'intent_token': data['intent_token'],
          'intent_data': data['intent_data'],
          'sign_message': data['sign_message'],
        },
        'progress': progress.name,
        'signature': data['payer_signature'],
        'txid': data['payment_txid'],
        'wire': data['signed_wire'],
        'order': hasOrder
            ? {
                'is_ok': true,
                'order_id': row.orderId,
                'order_state': row.entryState,
                'coin_fen': row.transferAmount,
                'payment_txid': data['payment_txid'],
                'gmb_tx_hash': row.txHash,
                'exception_reason': row.failReason,
              }
            : null,
      }),
    );
    if (row.accountId != record.intent.accountId ||
        row.transferAmount != record.intent.coinFen ||
        row.createdAt != record.intent.intentData['issued_at']) {
      throw const FormatException('充值记录与原始意图不一致');
    }
    return record;
  }

  Future<List<TopupRecord>> list(String origin, String account) async {
    await prepare();
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
    return rows.map(fromEntry).toList();
  }

  Future<void> save(TopupRecord record, {TopupRecord? before}) async {
    TopupRecord.decode(record.encode());
    if (record.encode().length > 24576) throw const FormatException('充值恢复记录超限');
    if (before != null &&
        (before.key != record.key ||
            jsonEncode(before.intent.toJson()) !=
                jsonEncode(record.intent.toJson()) ||
            record.progress.index < before.progress.index ||
            before.signature != null && record.signature != before.signature ||
            before.txid != null && record.txid != before.txid ||
            before.wire != null && record.wire != before.wire ||
            before.order != null &&
                record.order != null &&
                record.order!.orderState.index <
                    before.order!.orderState.index ||
            before.terminal &&
                jsonEncode(before.order?.toJson()) !=
                    jsonEncode(record.order?.toJson()))) {
      throw const FormatException('充值记录不能替换或倒退');
    }
    await prepare();
    storage.Entry? changed;
    final removedIds = <int>[];
    await storage.UserIsar.instance.writeTxn((isar) async {
      final hash = record.order?.gmbTxHash;
      // 一次定位查询同时取得原订单和已先到达的准确到账事件。
      final candidates = hash == null
          ? [
              if (await _find(isar, record.origin, record.intent.orderId)
                  case final row?)
                row,
            ]
          : await isar
                .collection<storage.Entry>()
                .filter()
                .group(
                  (q) => q
                      .serviceOriginEqualTo(record.origin)
                      .orderIdEqualTo(record.intent.orderId),
                )
                .or()
                .group(
                  (q) => q
                      .accountIdEqualTo(record.intent.accountId)
                      .txHashEqualTo(hash)
                      .entryKindEqualTo('transfer')
                      .entrySourceEqualTo('sdk_finalized_event'),
                )
                .limit(4)
                .findAll();
      final orders = candidates
          .where((row) => row.entryKind == 'topup')
          .toList();
      if (orders.length > 1) throw StateError('同一充值订单存在重复记录');
      final current = orders.singleOrNull;
      if (_deletedIn(isar).contains(record.key) ||
          current == null && before != null) {
        throw const TopupDeletedException();
      }
      final encoded = current == null ? null : fromEntry(current).encode();
      final events = candidates
          .where((row) => row.entryKind != 'topup')
          .toList();
      if (encoded == record.encode() && events.isEmpty) return;
      if (encoded != record.encode() && encoded != before?.encode()) {
        throw StateError('充值记录已变化，请恢复原订单');
      }
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

  Future<void> delete(storage.Entry snapshot) async {
    await prepare();
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
