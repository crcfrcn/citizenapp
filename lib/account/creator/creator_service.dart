import 'package:citizenapp/storage/wallet_isar.dart'
    as wallet_store
    show Creator, Member;
import 'package:citizenapp/system/notifications/notifications.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/network/square_api_client.dart' show SquareSession;
import 'package:citizenapp/account/creator/creator_api.dart';
import 'package:citizenapp/account/creator/creator_overview.dart';
import 'package:citizenapp/account/creator/creator_plan.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';
import 'package:citizenapp/account/identity/finalized_identity_resolver.dart';
import 'package:citizenapp/scanner/qr_sign_session_page.dart';
import 'package:citizenapp/account/membership/subscription_chain.dart';
import 'package:citizenapp/network/hex_codec.dart' show hexToBytes;
import 'package:citizenapp/storage/wallet_isar.dart' hide Group;

/// 创作者页展示态：无可用钱包账户会话 / 已开通（含计划与概览）。

class CreatorPageData {
  const CreatorPageData._({required this.gated, this.plan, this.overview});

  /// true = 无会话或没有当前有效的平台会员权益。
  final bool gated;
  final CreatorPlan? plan;
  final CreatorOverview? overview;

  factory CreatorPageData.gated() => const CreatorPageData._(gated: true);

  factory CreatorPageData.active({
    required CreatorPlan plan,
    required CreatorOverview overview,
  }) => CreatorPageData._(gated: false, plan: plan, overview: overview);
}

/// 创作者页本地展示快照。
///
/// 快照只决定首帧展示，不授予会员权益，也不允许绕过保存动作中的 CitizenServe 鉴权。
/// CID 是快照唯一归属主键；会员态与创作者数据分别记录成功读取时间。
/// 时间戳只描述数据年龄，普通进入不得因过期或缺失自动联网。
class CreatorDisplaySnapshot {
  const CreatorDisplaySnapshot({
    required this.cidNumber,
    required this.data,
    required this.memberAt,
    required this.creatorAt,
  });

  final String cidNumber;
  final CreatorPageData data;
  final int memberAt;
  final int creatorAt;

  bool isFresh(
    int nowMs, {
    Duration membershipTtl = const Duration(minutes: 5),
    Duration creatorTtl = const Duration(minutes: 1),
  }) {
    bool fresh(int timestamp, Duration ttl) =>
        timestamp > 0 &&
        nowMs >= timestamp &&
        nowMs - timestamp <= ttl.inMilliseconds;
    return fresh(memberAt, membershipTtl) &&
        (data.gated || fresh(creatorAt, creatorTtl));
  }
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
    required CitizenSdkWallet wallet,
    required CitizenChain chain,
    required CitizenTransactions transactions,
    required FinalizedIdentityResolver identityResolver,
    required SquareSessionProvider sessionProvider,
    CreatorApi? api,
    SubscriptionChain? subscriptionChain,
    SubscriptionService? subscriptionService,
  }) : _api = api ?? CreatorApiHttp(),
       _subscriptionChain =
           subscriptionChain ??
           SubscriptionChain(chain: chain, transactions: transactions),
       _wallet = wallet,
       _identityResolver = identityResolver,
       _session = sessionProvider,
       _subscriptionService =
           subscriptionService ??
           SubscriptionService(
             wallet: wallet,
             chain: chain,
             transactions: transactions,
             identityResolver: identityResolver,
             sessionProvider: sessionProvider,
           );

  final CreatorApi _api;
  final SubscriptionChain _subscriptionChain;
  final CitizenSdkWallet _wallet;
  final FinalizedIdentityResolver _identityResolver;
  final SquareSessionProvider _session;
  final Map<SquareSession, Future<CreatorPageData>> _loads = {};
  final SubscriptionService _subscriptionService;

  /// 读取上一次成功同步的页面快照；损坏快照不参与展示，读取路径绝不删除数据。
  Future<CreatorDisplaySnapshot?> readDisplaySnapshot(String cidNumber) async {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty) return null;
    final member = await _subscriptionService.readDisplaySnapshot(normalized);
    if (member != null && !member.state.active) {
      return CreatorDisplaySnapshot(
        cidNumber: normalized,
        data: CreatorPageData.gated(),
        memberAt: member.memberAt,
        creatorAt: 0,
      );
    }
    final pushed = Notifications.instance.creatorFor(normalized);
    if (pushed != null) {
      final CreatorPageData data;
      if (pushed['gated'] == true) {
        data = CreatorPageData.gated();
      } else {
        final plan = CreatorPlan.fromJson(
          (pushed['plan'] as Map).cast<String, dynamic>(),
        );
        if (plan.creatorCidNumber != normalized) {
          throw const FormatException('创作者快照身份不一致');
        }
        final overview = (pushed['overview'] as Map).cast<String, dynamic>();
        data = CreatorPageData.active(
          plan: plan,
          overview: CreatorOverview.fromJson(overview),
        );
      }
      return CreatorDisplaySnapshot(
        cidNumber: normalized,
        data: data,
        memberAt: Notifications.instance.memberReceivedAt,
        creatorAt: Notifications.instance.creatorReceivedAt,
      );
    }
    final raw = await _readCreatorState(normalized);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.containsKey('cid_number') ||
          decoded['gated'] is! bool) {
        return null;
      }
      final gated = decoded['gated'] as bool;
      final memberAt = decoded['member_at'];
      final creatorAt = decoded['creator_at'];
      if (memberAt is! int || creatorAt is! int) {
        return null;
      }
      if (gated) {
        return CreatorDisplaySnapshot(
          cidNumber: normalized,
          data: CreatorPageData.gated(),
          memberAt: memberAt,
          creatorAt: creatorAt,
        );
      }
      final planRaw = decoded['plan'];
      final overviewRaw = decoded['overview'];
      if (planRaw is! Map<String, dynamic> ||
          overviewRaw is! Map<String, dynamic>) {
        return null;
      }
      if (planRaw.containsKey('creator_cid_number')) return null;
      final plan = CreatorPlan.fromJson({
        'creator_cid_number': normalized,
        ...planRaw,
      });
      if (plan.creatorCidNumber != normalized) return null;
      return CreatorDisplaySnapshot(
        cidNumber: normalized,
        data: CreatorPageData.active(
          plan: plan,
          overview: CreatorOverview.fromJson(overviewRaw),
        ),
        memberAt: memberAt,
        creatorAt: creatorAt,
      );
    } on FormatException {
      return null;
    }
  }

  /// 保存已经可展示的创作者页数据；只更新本地读模型，不改变授权状态。
  Future<void> rememberDisplayData({
    required String cidNumber,
    required CreatorPageData data,
    required int memberAt,
    required int creatorAt,
  }) async {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty) return;
    final plan = data.plan;
    final overview = data.overview;
    await _writeCreatorState(
      normalized,
      jsonEncode({
        'gated': data.gated,
        'member_at': memberAt,
        'creator_at': creatorAt,
        if (plan != null)
          'plan': {'tiers': plan.tiersJson(), 'updated_at': plan.updatedAt},
        if (overview != null)
          'overview': {
            'subscriber_count': overview.subscriberCount,
            'monthly_income_fen': overview.monthlyIncomeFen,
            'tier_count': overview.tierCount,
          },
      }),
    );
  }

  /// 主动刷新或会员动作确认后的读取：会员与档位读取 CitizenServe finalized 投影。
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
    if (pending != null) return pending;
    final task = _loadSession(session);
    _loads[session] = task;
    try {
      return await task;
    } on CreatorException {
      rethrow;
    } on Object {
      throw const CreatorException('创作者刷新失败，已保留本地内容');
    } finally {
      if (identical(_loads[session], task)) _loads.remove(session);
    }
  }

  Future<CreatorPageData> _loadSession(SquareSession session) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // 已finalized的待确认投影先补交，再读取本人快照；不再提交链上交易。
    await _retryPendingProjection(session);
    await session.validateCurrent();
    // 本人概览自身执行当前会员门禁；展示刷新不再前置GET会员。
    // 两个逻辑读取在HTTP层共用同一本人概览响应，失败不覆盖已有快照或刷新成功时间。
    final List<Object?> results;
    try {
      results = await Future.wait<Object?>([
        _api.fetchMyPlan(session),
        _api.fetchOverview(session),
      ]);
    } on CreatorApiException catch (error) {
      if (error.statusCode != 403 || error.errorCode != 'membergate_required') {
        rethrow;
      }
      final data = CreatorPageData.gated();
      await session.validateCurrent();
      await rememberDisplayData(
        cidNumber: session.cidNumber,
        data: data,
        memberAt: nowMs,
        creatorAt: 0,
      );
      return data;
    }
    await session.validateCurrent();
    final data = CreatorPageData.active(
      plan: results[0] as CreatorPlan? ?? CreatorPlan.empty(session.cidNumber),
      overview: results[1] as CreatorOverview,
    );
    await rememberDisplayData(
      cidNumber: session.cidNumber,
      data: data,
      memberAt: nowMs,
      creatorAt: nowMs,
    );
    return data;
  }

  /// 覆盖式保存档位：一次链上签名原子写入名称与价格，再确认 finalized 投影。
  Future<CreatorPlan> saveTiers(
    List<CreatorTier> tiers, {
    BuildContext? context,
  }) async {
    if (tiers.length > CreatorPlan.maxTiers) {
      throw const CreatorException('最多 ${CreatorPlan.maxTiers} 个会员档');
    }
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final session = await _session.ensureSession();
    if (session == null) {
      throw const CreatorException('会话不可用，请稍后重试');
    }
    if (session.accountId != identity.accountId) {
      throw const CreatorException('当前会话与默认钱包账户不一致，请重新登录');
    }
    try {
      final membership = await _subscriptionService.authorizeMembership(
        session,
        forceRefresh: true,
      );
      if (!membership.active) {
        throw const CreatorException('需要当前有效的平台会员才能设置创作者会员档');
      }
      final result = await _subscriptionChain.setCreatorPlans(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        tiers: tiers
            .map(
              (tier) => CreatorTierInput(
                tierId: tier.tierId,
                tierName: tier.tierName,
                pricesFen: tier.pricesFen.entries
                    .map(
                      (entry) => CreatorPeriodPriceInput(
                        billingPeriod: entry.key.key,
                        priceFen: BigInt.from(entry.value),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      return await _completeFinalizedSave(
        session: session,
        accountId: identity.accountId,
        creatorCidNumber: session.cidNumber,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
        tiers: tiers,
      );
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
    final session = await _session.ensureSession();
    if (session == null || session.accountId != identity.accountId) {
      throw const CreatorException('当前会话与默认钱包账户不一致，请重新登录');
    }
    final index = currentTiers.indexWhere((tier) => tier.tierId == tierId);
    if (index < 0) throw const CreatorException('要改名的会员档不存在');
    try {
      final result = await _subscriptionChain.updateCreatorTierName(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        tierId: tierId,
        tierName: tierName,
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      try {
        await _appendLocalTransaction(
          creatorCidNumber: session.cidNumber,
          accountId: identity.accountId,
          action: 'update_creator_tier_name',
          txHash: result.txHash,
          blockHashHex: result.blockHashHex,
        );
      } on Exception {
        // 链上已经 finalized；本地审计缓存失败不得诱导用户再次签名。
      }
      CreatorPlan? projectedPlan;
      try {
        projectedPlan = await _api.saveMyPlan(
          session: session,
          txHash: result.txHash,
          blockHashHex: result.blockHashHex,
        );
        await wallet_store.Member.finishProof(
          session.cidNumber,
          result.txHash,
          'plan',
        );
      } on Exception {
        // 保留同一 finalized 交易，下次进入创作者页只重试投影确认。
      }
      final localTiers = List<CreatorTier>.from(currentTiers);
      localTiers[index] = localTiers[index].copyWith(tierName: tierName);
      final localPlan = CreatorPlan(
        creatorCidNumber: session.cidNumber,
        tiers: List.unmodifiable(localTiers),
        updatedAt: 0,
      );
      if (projectedPlan != null &&
          projectedPlan.creatorCidNumber != session.cidNumber) {
        throw const CreatorApiException('创作者投影属主已变化');
      }
      return projectedPlan ?? localPlan;
    } on Exception catch (e) {
      throw CreatorException('改名失败：$e');
    }
  }

  /// 当前默认账户经 finalized 闭环验证后，才可签名 `set_creator_plans` 链上
  /// 交易的唯一签名者。档位与待提交证明归属永久 CID，账户只记录签名事实。
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
    if (context == null || !context.mounted) return Future<String?>.value();
    return showCitizenSdkQrResponse(
      context,
      request: pending.qrRequest,
      expiresAt: BigInt.from(pending.expiresAt.millisecondsSinceEpoch ~/ 1000),
    );
  }

  Future<CitizenWalletStateAccount> _requireSigningAccount(
    String accountId,
  ) async {
    final account = (await _wallet.getState().result).defaultAccount;
    if (account == null || account.accountId != accountId) {
      throw const CreatorException('当前身份与默认钱包账户不一致，已拒绝签名');
    }
    return account;
  }

  Future<void> _retryPendingProjection(SquareSession session) async {
    try {
      final pending = await wallet_store.Member.readProofs(
        session.cidNumber,
        pendingKind: 'plan',
      );
      if (pending.isEmpty) return;
      final decoded = pending.single;
      final txHash = decoded['tx_hash'];
      final blockHashHex = decoded['block_hash'];
      if (txHash is! String || blockHashHex is! String) {
        return;
      }
      await _api.saveMyPlan(
        session: session,
        txHash: txHash,
        blockHashHex: blockHashHex,
      );
      await wallet_store.Member.finishProof(session.cidNumber, txHash, 'plan');
    } on Exception {
      // 保留待同步记录；页面继续使用上一次 CitizenServe 快照，不阻断创作者功能。
    }
  }

  /// 进入本方法时链上业务已经 finalized；之后任何边缘或本地缓存失败都不得要求用户重签。
  Future<CreatorPlan> _completeFinalizedSave({
    required SquareSession session,
    required String accountId,
    required String creatorCidNumber,
    required String txHash,
    required String blockHashHex,
    required List<CreatorTier> tiers,
  }) async {
    final localPlan = CreatorPlan(
      creatorCidNumber: creatorCidNumber,
      tiers: tiers,
      updatedAt: 0,
    );
    try {
      await _appendLocalTransaction(
        creatorCidNumber: creatorCidNumber,
        accountId: accountId,
        action: 'set_creator_plans',
        txHash: txHash,
        blockHashHex: blockHashHex,
      );
    } on Exception {
      // 继续立即提交 Cloudflare；链上已成功，禁止把本地缓存异常变成第二次签名。
    }

    var displayPlan = localPlan;
    try {
      displayPlan = await _api.saveMyPlan(
        session: session,
        txHash: txHash,
        blockHashHex: blockHashHex,
      );
      await wallet_store.Member.finishProof(creatorCidNumber, txHash, 'plan');
    } on Exception {
      // 保留待同步记录；下次进入创作者页只重试 HTTP。
    }

    return displayPlan;
  }

  /// 本地按永久 CID 保留有限条 finalized 交易证明；签名账户留在证明内部作为
  /// 不可变交易事实，Cloudflare 成功后也不删除链上交易记录。
  Future<void> _appendLocalTransaction({
    required String creatorCidNumber,
    required String accountId,
    required String action,
    required String txHash,
    required String blockHashHex,
  }) async {
    await wallet_store.Member.storeProof(
      creatorCidNumber,
      {
        'action': action,
        'tx_hash': txHash,
        'block_hash': blockHashHex,
        'signer_account_id': accountId,
      },
      pendingKind: 'plan',
      replacePending: true,
    );
  }

  Future<String?> _readCreatorState(String cidNumber) =>
      WalletIsar.instance.read(
        (db) async =>
            (await db.collection<wallet_store.Creator>().getByCidNumber(
              cidNumber,
            ))?.bodyData,
      );

  Future<void> _writeCreatorState(String cidNumber, String bodyData) =>
      WalletIsar.instance.writeTxn((db) async {
        await db.collection<wallet_store.Creator>().putByCidNumber(
          wallet_store.Creator()
            ..cidNumber = cidNumber
            ..bodyData = bodyData,
        );
      });
}
