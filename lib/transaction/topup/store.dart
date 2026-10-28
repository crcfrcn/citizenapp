import 'dart:convert';

import 'package:citizenapp/network/citizen_serve_api_config.dart';
import 'package:citizenapp/system/security/system_protected_storage.dart';

import 'topup_models.dart';

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
        'status',
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

class TopupStore {
  TopupStore({SystemProtectedRecordStore? records})
    : _records = records ?? SystemProtectedRecordStore.topup;
  final SystemProtectedRecordStore _records;
  Future<List<TopupRecord>> list(String origin, String account) async {
    final records = <TopupRecord>[];
    for (final entry in (await _records.readAll()).entries) {
      // 普通读取只接受当前结构，保留失败记录，不写回或升级。
      final record = TopupRecord.decode(entry.value);
      if (entry.key != record.key) throw StateError('充值恢复记录归属不一致');
      if (record.origin == origin && record.intent.accountId == account) {
        records.add(record);
      }
    }
    records.sort(
      (a, b) => (b.intent.intentData['issued_at'] as int).compareTo(
        a.intent.intentData['issued_at'] as int,
      ),
    );
    return records;
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
    final current = await _records.read(record.key);
    if (current == record.encode()) return;
    if (current != before?.encode() ||
        !await _records.compareAndSet(
          record.key,
          expected: before?.encode(),
          next: record.encode(),
        )) {
      throw StateError('充值记录已变化，请恢复原订单');
    }
  }
}
