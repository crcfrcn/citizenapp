import 'dart:convert';

import 'package:citizen_citizen/pallet_registry.dart';

import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_chain/citizen_chain.dart';

class SquareChainPublishedResult {
  const SquareChainPublishedResult({
    required this.txHash,
    required this.blockHash,
    this.failed = false,
  });

  final String txHash;
  final String blockHash;
  final bool failed;
}

class SquareChainPublishException implements Exception {
  const SquareChainPublishException(
    this.message, {
    required this.canAbortUpload,
  });

  final String message;

  /// 只有 finalized ExtrinsicFailed 等确定未写入 SquarePosts 的结果才允许清理上传。
  final bool canAbortUpload;

  @override
  String toString() => message;
}

abstract class SquarePostChainPublisher {
  Future<SquareChainPublishedResult> publishPost({
    required Uint8List signerPublicKey,
    required String postId,
    required SquarePostType postType,
    required String contentHashHex,
    required String receiptId,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
    void Function(String txHash)? onSigned,
  });
  Future<SquareChainPublishedResult?> recoverPost({
    required String accountId,
    required String postId,
    required SquarePostType postType,
    required String contentHash,
    required String receiptId,
  });
}

class SquareChainService implements SquarePostChainPublisher {
  SquareChainService({
    CitizenSdk? chain,
    CitizenSdk? transactions,
    CitizenIdentityChainReader? identityChainReader,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
    Future<CitizenPreparedTransaction> Function(
      Uint8List sourceAccountId,
      Uint8List callData,
    )?
    prepareTransaction,
    Future<CitizenTransactionExecution> Function(String preparationId)?
    executePreparedTransaction,
    Future<void> Function(String executionId)?
    cancelPreparedTransactionExecution,
    Future<CitizenTransactionExecutionCompleted> Function(
      String executionId,
      String response,
    )?
    consumePreparedTransactionQrResponse,
    Stream<CitizenSdkEvent>? events,
    CitizenHistoryReader? getHistory,
  }) : _events = events ?? transactions?.events,
       _getHistory = getHistory ?? transactions?.getTransactionHistory,
       _identityChainReader =
           identityChainReader ??
           CitizenIdentityChainReader(
             chain: chain,
             getFinalizedHead: getFinalizedHead,
             getRuntimeContext: getRuntimeContext,
             getStorageBatch: getStorageBatch,
             getStorage: getStorage,
           ),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext =
           getRuntimeContext ?? chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _getStorageBatch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((CitizenBlockRef block, List<Uint8List> keys) =>
               throw StateError('未配置getStorageBatch')),
       _prepareTransaction =
           prepareTransaction ??
           transactions?.prepareTransaction ??
           ((Uint8List sourceAccountId, Uint8List callData) =>
               throw StateError('未配置prepareTransaction')),
       _executePreparedTransaction =
           executePreparedTransaction ??
           transactions?.executePreparedTransaction ??
           ((String preparationId) =>
               throw StateError('未配置executePreparedTransaction')),
       _cancelPreparedTransactionExecution =
           cancelPreparedTransactionExecution ??
           transactions?.cancelPreparedTransactionExecution ??
           ((String executionId) =>
               throw StateError('未配置cancelPreparedTransactionExecution')),
       _consumePreparedTransactionQrResponse =
           consumePreparedTransactionQrResponse ??
           transactions?.consumePreparedTransactionQrResponse ??
           ((String executionId, String response) =>
               throw StateError('未配置consumePreparedTransactionQrResponse'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;
  final Future<List<Uint8List?>> Function(
    CitizenBlockRef block,
    List<Uint8List> keys,
  )
  _getStorageBatch;
  final Future<CitizenPreparedTransaction> Function(
    Uint8List sourceAccountId,
    Uint8List callData,
  )
  _prepareTransaction;
  final Future<CitizenTransactionExecution> Function(String preparationId)
  _executePreparedTransaction;
  final Future<void> Function(String executionId)
  _cancelPreparedTransactionExecution;
  final Future<CitizenTransactionExecutionCompleted> Function(
    String executionId,
    String response,
  )
  _consumePreparedTransactionQrResponse;

  final CitizenIdentityChainReader _identityChainReader;

  final Stream<CitizenSdkEvent>? _events;
  final CitizenHistoryReader? _getHistory;

  static String _hash(String s) => s.startsWith('0x') ? s : '0x$s';
  Future<CitizenTransactionHistoryRecord?> _matching(
    String account,
    String call,
  ) async {
    final history = await _getHistory?.call(limit: 4);
    if (history == null) return null;
    for (final record in history.records) {
      if (record.sourceAccountId == account &&
          _hash(record.callDataHash) == _hash(call)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<SquareChainPublishedResult?> recoverPost({
    required String accountId,
    required String postId,
    required SquarePostType postType,
    required String contentHash,
    required String receiptId,
  }) async {
    final call = buildPublishPostCallData(
      postId: postId,
      postType: postType,
      contentHashHex: contentHash,
      receiptId: receiptId,
    );
    final record = await _matching(
      accountId,
      hexEncode(CitizenScale.blake2b256(call)),
    );
    if (record == null) return null;
    final finalBlock = record.execution?.block.hash;
    return SquareChainPublishedResult(
      txHash: _hash(record.transactionHash),
      blockHash: finalBlock ?? '',
      failed: record.status == CitizenTransactionHistoryStatus.finalizedFailed,
    );
  }

  static const int palletIndex = PalletRegistry.squarePostPallet;
  static const int publishPostCallIndex = PalletRegistry.publishPostCall;
  static const int maxPostIdBytes = 64;
  static const int maxStorageReceiptIdBytes = 96;

  @override
  Future<SquareChainPublishedResult> publishPost({
    required Uint8List signerPublicKey,
    required String postId,
    required SquarePostType postType,
    required String contentHashHex,
    required String receiptId,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
    void Function(String txHash)? onSigned,
  }) async {
    final callData = buildPublishPostCallData(
      postId: postId,
      postType: postType,
      contentHashHex: contentHashHex,
      receiptId: receiptId,
    );
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    String? observed;
    var closed = false;
    void signed(String hash) {
      if (closed || observed != null) return;
      observed = hash;
      onSigned?.call(hash);
    }

    final events = _events;
    final getHistory = _getHistory;
    // 同一准备标识观察 SDK 已持久化的本次签名，上传仍由广场决定。
    final listener = onSigned == null || events == null || getHistory == null
        ? null
        : watchCitizenPreparedTransaction(
            prepared: prepared, events: events, getHistory: getHistory,
          ).listen(
            (record) => signed(_hash(record.transactionHash)),
            onError: (Object _) {
              // 最终回执仍交付同一哈希。观察失败由原发布流程处理。
            },
          );
    try {
      final completed = await completeCitizenTransaction(
        await _executePreparedTransaction(prepared.preparationId),
        requestResponse: externalSigning,
        consumeResponse: _consumePreparedTransactionQrResponse,
        cancelExecution: _cancelPreparedTransactionExecution,
      );
      if (completed == null) {
        throw const SquareChainPublishException(
          '广场发布签名已取消',
          canAbortUpload: true,
        );
      }
      final hash = _hash(hexEncode(completed.transactionHash));
      if (observed != null && observed != hash) {
        throw const SquareChainPublishException(
          '签名和最终交易哈希不一致',
          canAbortUpload: false,
        );
      }
      signed(hash);
      final execution = completed.execution;
      if (execution == null ||
          completed.resolution == CitizenTransactionResolution.poolRejected) {
        throw const SquareChainPublishException(
          '交易最终结果未确定',
          canAbortUpload: false,
        );
      }
      // 成功或失败都上报同一最终区块。广场状态由服务端独立验证。
      return SquareChainPublishedResult(
        txHash: hash,
        blockHash: execution.block.hash,
        failed:
            completed.resolution ==
            CitizenTransactionResolution.finalizedFailed,
      );
    } finally {
      closed = true;
      await listener?.cancel();
    }
  }

  Future<String?> fetchNormalCitizenCidNumber(String accountId) async {
    final identity = await _identityChainReader.readByAccountId(accountId);
    // 广场普通帖子只要求 active CID；匿名已注册同样拥有稳定的 CID 归属。
    return identity?.cidNumber;
  }

  /// 读链上身份档：有效投票身份的 cid + 是否竞选公民。
  /// cid_level = visitor（无有效投票身份）/ voting / candidate（另有候选记录）。
  Future<({String? cidNumber, String identityLevel})> fetchIdentity(
    String accountId,
  ) async {
    final identity = await _identityChainReader.readByAccountId(accountId);
    // 匿名已注册仍暴露 CID 作为帖子归属，但不升级投票/竞选身份徽章。
    final voting = identity?.votingIdentity;
    if (voting == null || !votingIdentityIsActive(voting)) {
      return (cidNumber: identity?.cidNumber, identityLevel: 'visitor');
    }
    return (
      cidNumber: identity!.cidNumber,
      identityLevel: identity.candidateIdentity != null
          ? 'candidate'
          : 'voting',
    );
  }

  /// 读链上平台会员某档月价：`PlatformPrice[level]`（u128 分，OptionQuery）。
  /// 平台价链上单源（治理设置），未设该档返回 null，页面据此显示占位。
  Future<int?> fetchPlatformPriceFen(String level) async {
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    final data = await _getStorage(
      finalized,
      _platformPriceKey(runtime, level),
    );
    return decodePlatformPriceFen(data);
  }

  /// 一次批量读三档平台价（自由/民主/薪火），会员页据此逐档展示；缺档不入表。
  Future<Map<String, int>> fetchAllPlatformPrices({
    bool forceFresh = false,
  }) async {
    const levels = ['freedom', 'democracy', 'spark'];
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    final values = await _getStorageBatch(finalized, [
      for (final level in levels) _platformPriceKey(runtime, level),
    ]);
    final prices = <String, int>{};
    for (var index = 0; index < levels.length; index++) {
      final level = levels[index];
      final fen = decodePlatformPriceFen(values[index]);
      if (fen != null) prices[level] = fen;
    }
    return prices;
  }

  static Uint8List _platformPriceKey(CitizenRuntimeContext runtime, String level) =>
      runtime.storageKey('SquarePost', 'PlatformPrice', [
        SubscriptionChain.membershipLevelVariant(level),
      ]);

  /// 解码 `PlatformPrice` 值：u128 小端 16 字节 → int（分级金额在 int 安全范围）。
  /// 未设（null）或字节不足返回 null。
  @visibleForTesting
  static int? decodePlatformPriceFen(Uint8List? data) {
    if (data == null || data.length < 16) return null;
    return CitizenScale.readUnsigned(data, 0, 16).toInt();
  }

  @visibleForTesting
  static Uint8List buildPublishPostCallData({
    required String postId,
    required SquarePostType postType,
    required String contentHashHex,
    required String receiptId,
  }) {
    final postIdBytes = Uint8List.fromList(utf8.encode(postId.trim()));
    if (postIdBytes.isEmpty || postIdBytes.length > maxPostIdBytes) {
      throw ArgumentError('post_id 长度需在 1..=$maxPostIdBytes 字节');
    }

    final receiptBytes = Uint8List.fromList(utf8.encode(receiptId.trim()));
    if (receiptBytes.isEmpty ||
        receiptBytes.length > maxStorageReceiptIdBytes) {
      throw ArgumentError(
        'storage_receipt_id 长度需在 1..=$maxStorageReceiptIdBytes 字节',
      );
    }

    final contentHash = hexDecode(contentHashHex);
    if (contentHash.length != 32 || contentHash.every((byte) => byte == 0)) {
      throw ArgumentError('content_hash 必须是非零 32 字节 sha256 hex');
    }
    final output = CitizenScaleWriter();
    output.pushByte(palletIndex);
    output.pushByte(publishPostCallIndex);
    writeCompactBytes(output, postIdBytes);
    output.pushByte(postType.index);
    output.write(contentHash);
    writeCompactBytes(output, receiptBytes);
    return output.toBytes();
  }

  @visibleForTesting
  static bool votingIdentityIsActive(Uint8List data, {int? today}) {
    try {
      if (!CitizenIdentityChainReader.votingIdentityLayoutIsValid(data)) {
        return false;
      }
      var offset = 0;
      final validFrom = CitizenScale.readUnsigned(data, offset, 4).toInt();
      offset += 4;
      final validUntil = CitizenScale.readUnsigned(data, offset, 4).toInt();
      offset += 4;
      final citizenStatus = data[offset];
      if (citizenStatus != 0) return false;
      final beijingNow = DateTime.now().toUtc().add(const Duration(hours: 8));
      final currentDate =
          today ??
          beijingNow.year * 10000 + beijingNow.month * 100 + beijingNow.day;
      return currentDate >= validFrom && currentDate <= validUntil;
    } catch (_) {
      return false;
    }
  }

  static void writeCompactBytes(CitizenScaleWriter output, Uint8List bytes) {
    output.write(CitizenScale.compact(bytes.length));
    output.write(bytes);
  }

  static String hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List hexDecode(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (h.isEmpty || h.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) {
      throw FormatException('非法 hex: $hex');
    }
    final result = Uint8List(h.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
