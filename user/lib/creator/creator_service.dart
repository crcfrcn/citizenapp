import 'package:citizen_storage/user_isar.dart' as wallet_store show Creator;

import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart' show SquareSession;
import 'package:citizen_user/creator/creator_api.dart';
import 'package:citizen_user/creator/creator_overview.dart';
import 'package:citizen_user/creator/creator_plan.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_chain/citizen_chain.dart';

/// 创作者页展示态：无可用钱包账户会话 / 已开通（含计划与概览）。

class CreatorPageData {
  const CreatorPageData._({required this.gated, this.plan, this.overview});

  /// true = 无会话或没有当前有效的平台会员权益。
  final bool gated;
  final CreatorPlan? plan;
  final CreatorOverview? overview;

  factory CreatorPageData.gated() => const CreatorPageData._(gated: true);

  factory CreatorPageData.active({
    CreatorPlan? plan,
    required CreatorOverview overview,
  }) => CreatorPageData._(gated: false, plan: plan, overview: overview);
}

class CreatorException implements Exception {
  const CreatorException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 创作者管理编排：当前有效的平台会员可创建档位、读取概览并收取订阅款。
///
/// - 保存档位只签一次 `set_creator_plans` 链上交易；名称与价格均由 finalized 链状态确认。
class CreatorService {
  CreatorService({
    ChainDataService? chainData,
    CitizenSdk? wallet,
    CitizenSdk? chain,
    CitizenSdk? transactions,
    required FinalizedIdentityResolver identityResolver,
    required SquareSessionProvider sessionProvider,
    CreatorApi? api,
    SubscriptionChain? subscriptionChain,
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
       _api = api ?? CreatorApiHttp(),
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
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState'));
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final ChainDataService? _chainData;
  final CreatorApi _api;
  final SubscriptionChain _subscriptionChain;

  final FinalizedIdentityResolver _identityResolver;
  final SquareSessionProvider _session;
  final Map<SquareSession, Future<CreatorPageData>> _loads = {};

  /// 主动刷新取得登记CID集合；档位和统计由统一轻节点读模型提供。
  ///
  /// 页面首帧不等待本方法；[expectedCidNumber] 防止旧会话结果写入新身份页面。
  Future<CreatorPageData> load({String? expectedCidNumber}) async {
    final resolution = await _session.resolveSession();
    final session = resolution.session;
    if (session == null) {
      throw CreatorException(resolution.message);
    }
    final expected = expectedCidNumber?.trim() ?? '';
    if (expected.isNotEmpty && session.cidNumber != expected) {
      throw const CreatorException('当前会话与创作者身份不一致，请稍后重试');
    }

    final pending = _loads[session];
    if (pending != null) {
      return pending;
    }
    final task = _loadSession(session);
    _loads[session] = task;
    try {
      return await task;
    } on CreatorException {
      rethrow;
    } on Object {
      throw const CreatorException('创作者刷新失败，已保留本地内容');
    } finally {
      if (identical(_loads[session], task)) {
        _loads.remove(session);
      }
    }
  }

  Future<CreatorPageData> _loadSession(SquareSession session) async {
    await session.validateCurrent();
    final source = _chainData;
    if (source == null) {
      throw const CreatorException('轻节点统计尚未就绪');
    }
    final data = await source.ensureCitizen(session.cidNumber, creator: true);
    if (data.accountId != session.accountId ||
        data.own?.identity?.bindRev != session.bindRev) {
      throw const CreatorException('统计身份已变化');
    }
    if (!data.memberActive(session.cidNumber)) {
      return CreatorPageData.gated();
    }
    final ids = <String>{};
    String? cursor;
    final cursors = <String>{};
    do {
      final page = await _api.fetchSubscribers(session, cursor: cursor);
      await session.validateCurrent();
      ids.addAll(page.cidNumbers);
      cursor = page.nextCursor;
      if (cursor != null && !cursors.add(cursor)) {
        throw const CreatorException('登记分页循环');
      }
    } while (cursor != null);
    final summary = await source.creatorSummary(session.cidNumber, ids);
    await session.validateCurrent();
    final overview = CreatorOverview(
      subscriberCount: summary.subscribers,
      monthlyIncomeFen: summary.monthly,
      blockNumber: summary.block.number.toInt(),
      blockHash: summary.block.hash,
    );
    await wallet_store.Creator.saveSummary(
      session.cidNumber,
      overview.toJson(),
      () => session.isUsable,
    );
    return CreatorPageData.active(
      plan: creatorPlanFromChain(data.own!.creatorTiers),
      overview: overview,
    );
  }

  Future<CreatorOverview?> cachedOverview(String cid) async {
    final value = await wallet_store.Creator.readSummary(cid);
    return value == null ? null : CreatorOverview.fromJson(value);
  }

  /// 覆盖式保存档位：一次链上签名原子写入名称与价格，等待轻节点确认 finalized。
  Future<CreatorPlan> saveTiers(
    List<CreatorTier> tiers, {
    BuildContext? context,
  }) async {
    if (tiers.length > CreatorPlan.maxTiers) {
      throw const CreatorException('最多 ${CreatorPlan.maxTiers} 个会员档');
    }
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    try {
      final data = await _chainData?.refresh();
      if (data == null ||
          _chainData!.isStale ||
          data.accountId != identity.accountId ||
          data.ownCid != identity.snapshot!.cidNumber ||
          data.own?.identity?.bindRev != identity.snapshot!.bindRev) {
        throw const CreatorException('轻节点会员状态尚未核验');
      }
      if (!data.memberActive(data.ownCid!)) {
        throw const CreatorException('需要当前有效的平台会员才能设置创作者会员档');
      }
      await _subscriptionChain.setCreatorPlans(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        tiers: tiers
            .map(
              (tier) => CreatorTierInput(
                tierId: tier.tierId,
                tierName: tier.tierName,
                pricesFen: BillingPeriod.values
                    .where(tier.hasPeriod)
                    .map(
                      (period) => CreatorPeriodPriceInput(
                        billingPeriod: period.key,
                        priceFen: BigInt.from(tier.priceFenOf(period)!),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      return CreatorPlan(tiers: tiers);
    } on CreatorApiException catch (e) {
      throw CreatorException(e.message);
    } on Exception catch (e) {
      throw CreatorException('保存失败：$e');
    }
  }

  /// 只改现有档位名称：当前 CID 控制账户签名，价格、授权、续费与扣款完全不变。
  Future<CreatorPlan> updateTierName({
    BuildContext? context,
    required List<CreatorTier> currentTiers,
    required String tierId,
    required String tierName,
  }) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final index = currentTiers.indexWhere((tier) => tier.tierId == tierId);
    if (index < 0) {
      throw const CreatorException('要改名的会员档不存在');
    }
    try {
      await _subscriptionChain.updateCreatorTierName(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        tierId: tierId,
        tierName: tierName,
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      final localTiers = List<CreatorTier>.from(currentTiers);
      localTiers[index] = localTiers[index].copyWith(tierName: tierName);
      final localPlan = CreatorPlan(tiers: List.unmodifiable(localTiers));
      return localPlan;
    } on Exception catch (e) {
      throw CreatorException('改名失败：$e');
    }
  }

  /// 当前默认账户经 finalized 闭环验证后，才可签名 `set_creator_plans` 链上
  /// 交易的唯一签名者。档位归属永久 CID，账户只记录签名事实。
  Future<FinalizedIdentity> _requireIdentity() async {
    final identity = await _identityResolver.resolve();
    if (identity == null || !identity.isRegistered) {
      throw const CreatorException('请先注册并绑定公民 CID');
    }
    return identity;
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

  Future<CitizenWalletStateAccount> _requireSigningAccount(
    String accountId,
  ) async {
    final account = (await _getWalletState().result).defaultAccount;
    if (account == null || account.accountId != accountId) {
      throw const CreatorException('当前身份与默认钱包账户不一致，已拒绝签名');
    }
    return account;
  }
}
