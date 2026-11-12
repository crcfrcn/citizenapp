import 'creator_plan.dart';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart' show SquareSession;
import 'package:citizen_user/creator/creator_api.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_chain/citizen_chain.dart';
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
    ChainDataService? chainData,
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
  }) : _chainData =
           chainData ?? (chain == null ? null : ChainDataService.forSdk(chain)),
       _subscriptionChain =
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
           (() => throw StateError('未配置getWalletState'));
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final ChainDataService? _chainData;
  final SubscriptionChain _subscriptionChain;

  final FinalizedIdentityResolver _identityResolver;
  final SquareSessionProvider _session;
  final CreatorApi _api;

  Future<CreatorView> fetchView(
    SquareSession session,
    String creatorCid,
  ) async {
    await _retryRegistrations(session);
    final source = _chainData;
    if (source == null) {
      throw const CreatorApiException('轻节点创作者读取不可用');
    }
    final data = await source.ensureCitizen(creatorCid, creator: true);
    await session.validateCurrent();
    if (data.accountId != session.accountId ||
        data.ownCid != session.cidNumber ||
        data.own?.identity?.bindRev != session.bindRev) {
      throw const CreatorApiException('当前账户已变化');
    }
    final target = data.citizens[creatorCid]!,
        state = data.subscriptions[creatorCid];
    return CreatorView(
      plan: data.memberActive(creatorCid)
          ? creatorPlanFromChain(target.creatorTiers)
          : null,
      subscription: state == null
          ? null
          : CreatorSubscriptionState(
              tierId: state.plan.tierId!,
              billingPeriod: state.plan.billingPeriod!,
              subState: state.subState,
              paidUntil: state.paidUntil,
            ),
    );
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
    final cid = identity.snapshot!.cidNumber;
    if (cid == creatorCid) {
      throw const CreatorSubscribeException('不能订阅自己');
    }
    try {
      final result = await _subscriptionChain.subscribeCreator(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        creatorCid: creatorCid,
        tierId: tierId,
        billingPeriod: period,
        expectedPriceFen: BigInt.from(priceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      await _register(
        cidNumber: cid,
        creatorCid: creatorCid,
        finalBlock: result.blockNumber,
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
    try {
      await _subscriptionChain.cancelCreator(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        creatorCid: creatorCid,
        externalSigning: (pending) => _showExternalSigning(context, pending),
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
    final cid = identity.snapshot!.cidNumber;
    if (cid == creatorCid) {
      throw const CreatorSubscribeException('不能订阅自己');
    }
    try {
      await _subscriptionChain.changeCreatorPlan(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        creatorCid: creatorCid,
        tierId: tierId,
        billingPeriod: period,
        expectedPriceFen: BigInt.from(priceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
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
    if (context == null || !context.mounted) {
      return Future<String?>.value();
    }
    return showCitizenSdkQrResponse(
      context,
      request: pending.qrRequest,
      expiresAt: BigInt.from(pending.expiresAt.millisecondsSinceEpoch ~/ 1000),
    );
  }

  /// 当前默认账户经 finalized 闭环验证后，才可成为创作者订阅交易签名者。
  /// 登记目标归属永久 CID，账户只记录当时的签名与付款事实；自订阅拦截也按
  /// 不可换绑的 CID 比对。
  Future<FinalizedIdentity> _requireIdentity() async {
    final identity = await _identityResolver.resolve();
    if (identity == null || !identity.isRegistered) {
      throw const CreatorSubscribeException('请先注册并绑定公民 CID');
    }
    return identity;
  }

  final Set<String> _registered = {};
  Future<void> _register({
    required String cidNumber,
    required String creatorCid,
    required int finalBlock,
  }) async {
    final key = '$cidNumber:$creatorCid';
    if (_registered.contains(key)) {
      return;
    }
    await Member.pendCreator(cidNumber, creatorCid, finalBlock);
    try {
      final s = await _session.ensureSession();
      if (s != null && s.cidNumber == cidNumber) {
        await _retryRegistrations(s);
      }
    } on Exception {
      /* 已上链，仅待下一次真实会话重试登记。 */
    }
  }

  final Map<SquareSession, Future<void>> _registrations = {};
  Future<void> _retryRegistrations(SquareSession session) {
    final pending = _registrations[session];
    if (pending != null) {
      return pending;
    }
    late final Future<void> work;
    work = _sendRegistrations(session).whenComplete(() {
      if (identical(_registrations[session], work)) {
        _registrations.remove(session);
      }
    });
    return _registrations[session] = work;
  }

  Future<void> _sendRegistrations(SquareSession s) async {
    try {
      await s.validateCurrent();
      final pending = await Member.pendingCreators(s.cidNumber);
      for (final item in pending.entries) {
        await _api.registerSubscription(
          session: s,
          creatorCid: item.key,
          finalBlock: item.value,
        );
        await s.validateCurrent();
        await Member.finishCreator(s.cidNumber, item.key);
        _registered.add('${s.cidNumber}:${item.key}');
      }
    } on Exception {
      /* 已上链动作不因云端不可用而重签；仅保留必要登记目标。 */
    }
  }
}
