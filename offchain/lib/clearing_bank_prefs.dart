import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 当前钱包绑定清算行的本地快照。
///
///
/// - 链上权威仍然是 `UserBank[user]` 与 `ClearingBankNodes[cid_number]`。
/// - 本地快照只供展示。当前绑定和操作端点均须查链。
class ClearingBankBindingSnapshot {
  const ClearingBankBindingSnapshot({
    required this.cidNumber,
    required this.fullName,
    required this.shortName,
    required this.mainAccountId,
    required this.feeAccountId,
    required this.peerId,
    required this.rpcDomain,
    required this.rpcPort,
    required this.boundAtMs,
    required this.lastVerifiedAtMs,
  });

  final String cidNumber;
  final String fullName;
  final String shortName;
  final String mainAccountId;
  final String feeAccountId;
  final String peerId;
  final String rpcDomain;
  final int rpcPort;
  final int boundAtMs;
  final int lastVerifiedAtMs;

  /// 本机、局域网与公网端点统一使用WSS，不按主机名降级。
  String get wssUrl => 'wss://$rpcDomain:$rpcPort';

  String get displayTitle {
    final cidShort = shortName.trim();
    if (cidShort.isNotEmpty) return cidShort;
    final cidFull = fullName.trim();
    return cidFull.isEmpty ? cidNumber : cidFull;
  }

  Map<String, dynamic> toJson() => {
    'cid_number': cidNumber,
    'cid_full_name': fullName,
    'cid_short_name': shortName,
    'main_account_id': mainAccountId,
    'fee_account_id': feeAccountId,
    'peer_id': peerId,
    'rpc_domain': rpcDomain,
    'rpc_port': rpcPort,
    'bound_at_ms': boundAtMs,
    'last_verified_at_ms': lastVerifiedAtMs,
  };

  factory ClearingBankBindingSnapshot.fromJson(Map<String, dynamic> json) {
    return ClearingBankBindingSnapshot(
      cidNumber: (json['cid_number'] as String?) ?? '',
      fullName: (json['cid_full_name'] as String?) ?? '',
      shortName: (json['cid_short_name'] as String?) ?? '',
      mainAccountId: (json['main_account_id'] as String?) ?? '',
      feeAccountId: (json['fee_account_id'] as String?) ?? '',
      peerId: (json['peer_id'] as String?) ?? '',
      rpcDomain: (json['rpc_domain'] as String?) ?? '',
      rpcPort: (json['rpc_port'] as num?)?.toInt() ?? 0,
      boundAtMs: (json['bound_at_ms'] as num?)?.toInt() ?? 0,
      lastVerifiedAtMs: (json['last_verified_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 扫码支付 Step 3:**用户绑定清算行本地快照缓存**。
///
/// - 链上 `OffchainTransaction::UserBank[user]` 保存清算行机构 CID。
/// - 本地快照补充名称、派生账户和节点端点，绑定和切换以 finalized 链状态为准。
/// - 缓存按 `account_id` 隔离(单钱包多账户下,每个账户独立绑定清算行,互不干扰)。
class ClearingBankPrefs {
  ClearingBankPrefs._();

  static const String _keyPrefix = 'clearing_bank_binding_';

  @visibleForTesting
  static Future<bool> Function(SharedPreferences prefs, String key)?
  debugRemoveForTest;

  @visibleForTesting
  static Future<bool> Function(SharedPreferences prefs, String key, String value)?
  debugSetForTest;

  /// 写入完整绑定快照。[accountId] 为该绑定账户的链账户主键(0x+64hex)。
  static Future<void> saveSnapshot(
    String accountId,
    ClearingBankBindingSnapshot snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$accountId';
    final value = jsonEncode(snapshot.toJson());
    final set = debugSetForTest;
    final saved = await (set == null
        ? prefs.setString(key, value)
        : set(prefs, key, value));
    if (!saved) throw StateError('清算行缓存写入未提交');
  }

  /// 读取完整绑定快照。[accountId] 为该账户的链账户主键(0x+64hex)。
  static Future<ClearingBankBindingSnapshot?> loadSnapshot(
    String accountId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$accountId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = ClearingBankBindingSnapshot.fromJson(json);
      if (snapshot.cidNumber.isEmpty ||
          snapshot.mainAccountId.isEmpty ||
          snapshot.feeAccountId.isEmpty ||
          snapshot.rpcDomain.isEmpty ||
          snapshot.rpcPort <= 0) {
        return null;
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  /// 清除本地快照，链上绑定状态独立存储。
  static Future<void> clear(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$accountId';
    if (!prefs.containsKey(key)) return;
    final remove = debugRemoveForTest;
    final removed = await (remove == null
        ? prefs.remove(key)
        : remove(prefs, key));
    if (!removed) {
      throw StateError('清算行缓存删除未提交');
    }
    // remove 返回 true 也不代表当前事实已不存在；并发写入或异常后端
    // 可在回读前重建该键。只要值仍存在就必须抛错，上层 pending 不得 ack。
    if (prefs.containsKey(key)) {
      throw StateError('清算行缓存删除后回读仍存在');
    }
  }
}
