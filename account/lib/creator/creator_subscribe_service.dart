import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/square_api_client.dart' show SquareSession;
import 'package:citizen_account/creator/creator_api.dart';
import 'package:citizen_account/identity/finalized_identity_resolver.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_account/membership/subscription_chain.dart';
import 'package:citizen_network/hex_codec.dart' show hexToBytes;
import 'package:citizen_storage/user_isar.dart' show Member;

class CreatorSubscribeException implements Exception {
  const CreatorSubscribeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 订阅者侧编排：在他人主页订阅 / 取消订阅创作者会员。
///
/// 用户只为订阅、取消和换档签名；首次扣款、真实公历到期时间与后续自动扣款由
/// runtime 根据共识时间戳完成，CitizenApp 不提交续费或周期确认。
class CreatorSubscribeService {
  CreatorSubscribeService({
    CitizenSdk? wallet,
    CitizenSdk? chain,
    CitizenSdk? transactions,
    required FinalizedIdentityResolver identityResolver,
    required SquareSessionProvider sessionProvider,
    SubscriptionChain? subscriptionChain,
    CreatorApi? api,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
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
  }) : _subscriptionChain =
           subscriptionChain ??
           SubscriptionChain(
             chain: chain,
             transactions: transactions,
             getFinalizedHead: getFinalizedHead,
             getStorageBatch: getStorageBatch,
             getStorage: getStorage,
             prepareTransaction: prepareTransaction,
             executePreparedTransaction: executePreparedTransaction,
             cancelPreparedTransactionExecution:
                 cancelPreparedTransactionExecution,
             consumePreparedTransactionQrResponse:
                 consumePreparedTransactionQrResponse,
           ),
       _identityResolver = identityResolver,
       _session = sessionProvider,
       _api = api ?? CreatorApiHttp(),
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState')) {
    unawaited(_retryPendingMirrors());
  }
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final SubscriptionChain _subscriptionChain;

  final FinalizedIdentityResolver _identityResolver;
  final SquareSessionProvider _session;
  final CreatorApi _api;

  Future<CreatorView> fetchView(
    SquareSession session,
    String creatorCid,
  ) async {
    await _retryPendingMirrors();
    return _api.fetchViewOf(session, creatorCid);
  }

  /// 订阅创作者某档某周期（priceFen=该档该周期价，分）。
  Future<void> subscribe({
    BuildContext? context,
    required String creatorCid,
    required String tierId,
    required String period,
    required int priceFen,
  }) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final session = await _requireCurrentSession(identity.accountId);
    if (session.cidNumber == creatorCid) {
      throw const CreatorSubscribeException('不能订阅自己');
    }
    try {
      final result = await _subscriptionChain.subscribeCreator(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        creatorCid: creatorCid,
        tierId: tierId,
        billingPeriod: period,
        expectedPriceFen: BigInt.from(priceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      await _confirm(
        cidNumber: session.cidNumber,
        creatorCid: creatorCid,
        txHash: result.txHash,
        blockHash: result.blockHash,
      );
    } on Exception catch (e) {
      throw CreatorSubscribeException('订阅失败：$e');
    }
  }

  /// 取消对某创作者的订阅（撤销按月扣款授权）。
  Future<void> cancel({
    BuildContext? context,
    required String creatorCid,
  }) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final session = await _requireCurrentSession(identity.accountId);
    try {
      final result = await _subscriptionChain.cancelCreator(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        creatorCid: creatorCid,
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      await _confirm(
        cidNumber: session.cidNumber,
        creatorCid: creatorCid,
        txHash: result.txHash,
        blockHash: result.blockHash,
      );
    } on Exception catch (e) {
      throw CreatorSubscribeException('取消失败：$e');
    }
  }

  /// 更换创作者档位或周期；同一换档业务只提交这一笔账户签名交易。
  Future<void> changePlan({
    BuildContext? context,
    required String creatorCid,
    required String tierId,
    required String period,
    required int priceFen,
  }) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final session = await _requireCurrentSession(identity.accountId);
    if (session.cidNumber == creatorCid) {
      throw const CreatorSubscribeException('不能订阅自己');
    }
    try {
      final result = await _subscriptionChain.changeCreatorPlan(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        creatorCid: creatorCid,
        tierId: tierId,
        billingPeriod: period,
        expectedPriceFen: BigInt.from(priceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      await _confirm(
        cidNumber: session.cidNumber,
        creatorCid: creatorCid,
        txHash: result.txHash,
        blockHash: result.blockHash,
      );
    } on Exception catch (e) {
      throw CreatorSubscribeException('更换订阅失败：$e');
    }
  }

  Future<CitizenWalletStateAccount> _requireSigningAccount(
    String accountId,
  ) async {
    final account = (await _getWalletState().result).defaultAccount;
    if (account == null || account.accountId != accountId) {
      throw const CreatorSubscribeException('当前身份与默认钱包账户不一致，已拒绝签名');
    }
    return account;
  }

  Future<String?> _showExternalSigning(
    BuildContext? context,
    CitizenTransactionExternalSigningPending pending,
  ) {
    if (context == null || !context.mounted) return Future<String?>.value();
    return showCitizenSdkQrResponse(
      context,
      request: pending.qrRequest,
      expiresAt: BigInt.from(pending.expiresAt.millisecondsSinceEpoch ~/ 1000),
    );
  }

  /// 当前默认账户经 finalized 闭环验证后，才可成为创作者订阅交易签名者。
  /// 待提交证明归属永久 CID，账户只记录当时的签名与付款事实；自订阅拦截也按
  /// 不可换绑的 CID 比对。
  Future<FinalizedIdentity> _requireIdentity() async {
    final identity = await _identityResolver.resolve();
    if (identity == null || !identity.isRegistered) {
      throw const CreatorSubscribeException('请先注册并绑定公民 CID');
    }
    return identity;
  }

  Future<SquareSession> _requireCurrentSession(String accountId) async {
    final session = await _session.ensureSession();
    if (session == null || session.accountId != accountId) {
      throw const CreatorSubscribeException('当前会话与默认钱包账户不一致，请重新登录');
    }
    return session;
  }

  /// finalized 回执按订阅者永久 CID 持久化；签名账户只作为交易事实保留。
  /// HTTP 失败只重放同一交易证明，不要求第二次签名。
  Future<void> _confirm({
    required String cidNumber,
    required String creatorCid,
    required String txHash,
    required String blockHash,
  }) async {
    final proof = <String, dynamic>{
      'creator_cid': creatorCid,
      'tx_hash': txHash,
      'block_hash': blockHash,
    };
    try {
      await Member.storeProof(cidNumber, proof, pendingKind: 'creator');
    } on Exception {
      // 链上已 finalized；本地缓存异常不得转化为重新签名。
    }
    try {
      final session = await _session.ensureSession();
      if (session == null || session.cidNumber != cidNumber) return;
      await _api.confirmCreatorSubscription(
        session: session,
        creatorCid: creatorCid,
        txHash: txHash,
        blockHash: blockHash,
      );
      await Member.finishProof(cidNumber, txHash, 'creator');
    } on Exception {
      // 保留证明，下次进入创作者订阅页仅重试 HTTP。
    }
  }

  Future<void> _retryPendingMirrors() async {
    try {
      final session = await _session.ensureSession();
      if (session == null) return;
      final cidNumber = session.cidNumber;
      final pending = await Member.readProofs(
        cidNumber,
        pendingKind: 'creator',
      );
      for (final proof in List<Map<String, dynamic>>.from(pending)) {
        final txHash = proof['tx_hash'];
        final blockHash = proof['block_hash'];
        final creatorCid = proof['creator_cid'];
        if (txHash is! String ||
            blockHash is! String ||
            creatorCid is! String) {
          continue;
        }
        await _api.confirmCreatorSubscription(
          session: session,
          creatorCid: creatorCid,
          txHash: txHash,
          blockHash: blockHash,
        );
        await Member.finishProof(cidNumber, txHash, 'creator');
      }
    } on Exception {
      // Cloudflare 不可用不影响链上自动续费，证明继续保留。
    }
  }
}
