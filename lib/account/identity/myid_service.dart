import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/wallet/account_balance_snapshot_store.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizenapp/app_log.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/8964/profile/square_session_provider.dart';
import 'package:citizenapp/citizen/public/admin_division_store.dart';
import 'package:citizenapp/citizen/public/area_path_formatter.dart';
import 'package:citizenapp/citizen/public/isar_admin_division_store.dart';
import 'package:citizenapp/citizen/public/public_provinces.dart';
import 'package:citizenapp/citizen/cid_generator.dart';
import 'package:citizenapp/account/identity/citizen_identity_transaction.dart';
import 'package:citizenapp/account/identity/citizen_identity_chain_reader.dart';
import 'package:citizenapp/scanner/qr_sign_session_page.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/security/identity_binding.dart';

import 'current_user_context.dart';
import 'finalized_identity_resolver.dart';
import 'identity_badge_snapshot_store.dart';

/// 身份页身份档。
///
/// 身份钥匙 = **CID 绑定的钱包账户**（经 [FinalizedIdentityResolver] 对当前默认账户
/// 做 finalized 闭环验证）。身份主键是 CID 号，
/// 绑定账户切换(换绑)即跟随;链上一人一 CID 一账户一身份,故无多身份冲突。
enum MyIdTier {
  /// 访客(默认匿名)。含两子态,均用同一张访客卡、同一枚访客徽章:
  /// - **纯访客**:账户从未占号(`cidNumber` 为空)。
  /// - **匿名已注册**:账户自助占了一个 CID 并双向绑定,但链上无 `VotingIdentityByCid`
  ///   (`cidNumber` 非空,见 [MyIdState.isAnonymousRegistered])。仅在第 1 卡展示该 CID 号,
  ///   不升级徽章色/卡片(投票/竞选身份只能经注册局线下升级)。
  visitor,

  /// 钱包与永久 CID 双向绑定闭环完整，且存在 `VotingIdentityByCid`。
  voting,

  /// 在投票公民之上再有 `CandidateIdentityByCid` 对应的竞选身份。
  candidate,
}

/// 身份展示状态；unknown 表示没有已保存事实，queryFailed 表示本次读取失败。
enum MyIdStatus { normal, notYetValid, expired, revoked, unknown, queryFailed }

/// 身份页展示状态；来自本地持久化或本次主动验真，不作为操作授权。
class MyIdState {
  const MyIdState({
    required this.tier,
    this.status,
    this.votingAccountId,
    this.cidNumber,
    this.residenceDistrict,
    this.passportValidFrom,
    this.passportValidUntil,
    this.familyName,
    this.givenName,
    this.citizenSexLabel,
    this.birthDistrict,
    this.citizenBirthDate,
    this.errorMessage,
  });

  final MyIdTier tier;

  /// 公民档护照状态；已知访客为 null，缺快照为 unknown，读取失败为 queryFailed。
  final MyIdStatus? status;

  /// 链上投票绑定账户 = CID 绑定账户地址(SS58)。访客不显示,为 null。
  final String? votingAccountId;
  final String? cidNumber;

  /// 预 join 的居住选区「省·市·镇」(service 层查字典拼好,UI 直接展示)。
  final String? residenceDistrict;

  /// YYYY-MM-DD,来自链上 YYYYMMDD 整数。
  final String? passportValidFrom;
  final String? passportValidUntil;

  // ── 竞选公民专属公开字段 ──
  final String? familyName;
  final String? givenName;

  /// 男/女。
  final String? citizenSexLabel;
  final String? birthDistrict;

  /// 出生日期 YYYY-MM-DD,来自链上竞选身份 birth_date(YYYYMMDD 整数)。
  final String? citizenBirthDate;

  final String? errorMessage;

  bool get isCitizen => tier == MyIdTier.voting || tier == MyIdTier.candidate;

  /// 访客卡的「已占匿名 CID」子态:访客档 + 已绑定 CID 号(无投票身份)。
  /// UI 据此在第 1 卡展示 CID 号、把右上按钮从「注册」切成「更换」。
  bool get isAnonymousRegistered =>
      tier == MyIdTier.visitor && (cidNumber?.trim().isNotEmpty ?? false);

  /// 徽章分色信号:visitor/voting/candidate,与 [IdentityBadgeSnapshotStore] 契约一致。
  String get identityLevel => switch (tier) {
    MyIdTier.candidate => 'candidate',
    MyIdTier.voting => 'voting',
    MyIdTier.visitor => 'visitor',
  };
}

class MyIdService {
  MyIdService({
    required CitizenSdkWallet wallet,
    required CitizenSigning signing,
    required AccountSecurityService accountSecurity,
    required CurrentUserContext currentUserContext,
    required FinalizedIdentityResolver identityResolver,
    required SquareSessionProvider sessionProvider,
    required ChatSdk Function() chatRuntime,
    required CitizenChain chain,
    required CitizenTransactions transactions,
    AdminDivisionStore? divisionStore,
    IdentityBadgeSnapshotStore? badgeSnapshotStore,
    CitizenIdentityTransaction? identityTransaction,
    DateTime Function()? nowProvider,
    int Function()? cidYearProvider,
    CitizenHistory? history,
  }) : _wallet = wallet,
       _signing = signing,
       _accountSecurity = accountSecurity,
       _currentUserContext = currentUserContext,
       _sessionProvider = sessionProvider,
       _chatRuntime = chatRuntime,
       _divisionStore = divisionStore ?? IsarAdminDivisionStore(),
       _badgeSnapshotStore = badgeSnapshotStore ?? IdentityBadgeSnapshotStore(),
       _identityResolver = identityResolver,
       _chain = chain,
       _nowProvider = nowProvider ?? _beijingNow,
       _cidYearProvider = cidYearProvider ?? _utcYear,
       _history = history {
    _identityTransaction =
        identityTransaction ??
        CitizenIdentityTransaction(
          chain: chain,
          transactions: _RegistrationTransactions(transactions, (
            checkpoint,
          ) async {
            await _registrationCheckpoint?.call(checkpoint);
          }),
        );
  }

  final CitizenSdkWallet _wallet;
  final CitizenSigning _signing;
  final AccountSecurityService _accountSecurity;
  final CurrentUserContext _currentUserContext;
  final SquareSessionProvider _sessionProvider;
  final ChatSdk Function() _chatRuntime;
  final AdminDivisionStore _divisionStore;
  final IdentityBadgeSnapshotStore _badgeSnapshotStore;
  final FinalizedIdentityResolver _identityResolver;
  late final CitizenIdentityTransaction _identityTransaction;
  final CitizenHistory? _history;
  Future<void> Function(Map<String, dynamic>)? _registrationCheckpoint;

  final CitizenChain _chain;

  final DateTime Function() _nowProvider;
  final int Function() _cidYearProvider;

  /// 链上护照有效期窗口按 UTC+8 判定(与 runtime `can_vote` 口径一致),
  /// 避免本机时区在跨日边界把"今天"算差一天。
  static DateTime _beijingNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  /// 自助占号的 CID 年份取 **UTC 当前年**(与 CID 生成金标口径一致,不随本机时区漂移)。
  static int _utcYear() => DateTime.now().toUtc().year;

  /// 只读取当前默认账户的持久展示状态，不启动链查询。
  ///
  /// 身份主键 = CID 号；展示始终跟随账户顺序第一项。
  /// 不扫描其它账户。完整快照缺失时仅显示已保存的CID，未知状态由主动刷新补齐。
  Future<MyIdState> getState() async {
    final account = (await _wallet.getState().result).defaultAccount;
    if (account == null) {
      return const MyIdState(tier: MyIdTier.visitor, errorMessage: '请先创建钱包');
    }
    final saved = await _badgeSnapshotStore.readForAccountId(account.accountId);
    if (saved?.verified == true) {
      return _stateForSnapshot(account.accountId, saved!.identity);
    }
    // 既有本地绑定本身已持久保存CID；缺少完整卡片时仍能显示公民号，绝不自动联网。
    final current = await _currentUserContext.resolve();
    final cid = current?.accountId == account.accountId
        ? current?.cidNumber
        : null;
    if (cid == null || cid.isEmpty) {
      return const MyIdState(
        tier: MyIdTier.visitor,
        status: MyIdStatus.unknown,
        errorMessage: '身份尚未获取，请下拉刷新',
      );
    }
    final badge = await _badgeSnapshotStore.read(cid);
    return MyIdState(
      tier: switch (badge?.identityLevel) {
        'candidate' => MyIdTier.candidate,
        'voting' => MyIdTier.voting,
        _ => MyIdTier.visitor,
      },
      votingAccountId: account.accountId,
      cidNumber: cid,
    );
  }

  /// 只有主动刷新调用；业务授权直接持有解析器返回的本次验真结果。
  Future<MyIdState> refreshState() async {
    FinalizedIdentity? resolved;
    try {
      resolved = await _identityResolver.resolve();
    } catch (e) {
      AppLog.d('myid identity resolve failed');
      // 链读失败不静默降级访客、不覆盖徽章快照,交由 UI 提示重试。
      return const MyIdState(
        tier: MyIdTier.visitor,
        status: MyIdStatus.queryFailed,
        errorMessage: '链上身份读取失败',
      );
    }
    if (resolved == null) {
      // 没有任何有效热、冷账户 → 无默认账户 → 访客（引导创建钱包）。
      return const MyIdState(tier: MyIdTier.visitor, errorMessage: '请先创建钱包');
    }

    return _stateForSnapshot(resolved.accountId, resolved.snapshot);
  }

  Future<MyIdState> _stateForSnapshot(
    String identityAccountId,
    CitizenIdentityChainSnapshot? chainIdentity,
  ) async {
    if (chainIdentity == null) {
      return const MyIdState(tier: MyIdTier.visitor);
    }

    if (chainIdentity.isAnonymous) {
      // 匿名已注册:访客卡 + 展示 CID;徽章仍访客色(决策:不新增卡/色)。
      return MyIdState(
        tier: MyIdTier.visitor,
        votingAccountId: identityAccountId,
        cidNumber: chainIdentity.cidNumber,
      );
    }

    final voting = _decodeVotingIdentity(chainIdentity.votingIdentity!);
    if (voting == null) {
      // 有记录但解不开 = 数据异常,不静默当访客。
      return const MyIdState(
        tier: MyIdTier.visitor,
        status: MyIdStatus.queryFailed,
        errorMessage: '身份数据解析失败',
      );
    }

    final status = _deriveStatus(voting);
    final residence = await _resolveDistrict(
      voting.resProvince,
      voting.resCity,
      voting.resTown,
    );

    final candidateRaw = chainIdentity.candidateIdentity;
    final candidate = candidateRaw == null
        ? null
        : _decodeCandidateIdentity(candidateRaw);
    final tier = candidate != null ? MyIdTier.candidate : MyIdTier.voting;

    final birth = candidate == null
        ? null
        : await _resolveDistrict(
            candidate.birthProvince,
            candidate.birthCity,
            candidate.birthTown,
          );

    return MyIdState(
      tier: tier,
      status: status,
      votingAccountId: identityAccountId,
      cidNumber: chainIdentity.cidNumber,
      residenceDistrict: residence,
      passportValidFrom: _formatDateInt(voting.passportValidFrom),
      passportValidUntil: _formatDateInt(voting.passportValidUntil),
      familyName: candidate?.familyName,
      givenName: candidate?.givenName,
      citizenSexLabel: candidate == null
          ? null
          : (candidate.sex == 1 ? '女' : '男'),
      birthDistrict: birth,
      citizenBirthDate: candidate == null
          ? null
          : _formatDateInt(candidate.birthDate),
    );
  }

  /// 自助占一个匿名 CID,把它绑定到用户所选的钱包账户 [bindAccountId](null = 账户0),
  /// 返回占用的 CID 号。
  ///
  /// 身份主键 = CID 号;绑定账户是用户自选的鉴权凭证(可任意 `//n`,私钥泄漏可换绑)。
  /// [institution] 取 [kCidInstitutionCitizen](公民)/ [kCidInstitutionResident](居民)。
  /// 年份取 UTC 当前年;CID = f(绑定 accountId, institution, year),撞号由链端 registry
  /// 兜底吸收。提交经 `self_occupy_cid` 由绑定账户自签自付费(触发一次生物识别);成功后
  /// 广播身份绑定变化,常驻页重读身份。
  Future<String> registerAnonymousCid({
    required BuildContext? context,
    required String institution,
    String? bindAccountId,
  }) async {
    final state = await _wallet.getState().result;
    final defaultAccount = state.defaultAccount;
    if (defaultAccount == null) {
      throw const AccountSecurityException('无钱包账户,请先创建钱包');
    }
    // 绑定账户为当前默认账户，或用户从 SDK 统一热／冷账户目录中选择的账户。
    final String resolvedBindAccountId;
    if (bindAccountId == null || bindAccountId == defaultAccount.accountId) {
      resolvedBindAccountId = defaultAccount.accountId;
    } else {
      final account = _findAccount(state, bindAccountId);
      if (account == null) {
        throw const AccountSecurityException('绑定账户不存在');
      }
      resolvedBindAccountId = account.accountId;
    }
    final cid = generateCitizenCid(
      accountId: resolvedBindAccountId,
      institution: institution,
      year: _cidYearProvider(),
    );
    final transaction = await _identityTransaction.selfOccupyCid(
      cidNumber: cid,
      accountId: resolvedBindAccountId,
      externalSigning: (pending) => context == null || !context.mounted
          ? Future<String?>.value()
          : showCitizenSdkQrResponse(
              context,
              request: pending.qrRequest,
              expiresAt: BigInt.from(
                pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
              ),
            ),
    );
    final finalized = await _requireFinalizedBinding(
      cidNumber: cid,
      accountId: resolvedBindAccountId,
    );
    _registrationFinalized[resolvedBindAccountId] = FinalizedRegistration(
      binding: await _bindingForFinalizedIdentity(finalized),
      blockHash: transaction.blockHashHex,
      txHash: transaction.txHash,
    );
    // CID注册finalized后只推进公开绑定及同CID数据上下文；MLS首次设备登记
    // 由Worker明确未登记时触发，身份交易收尾不额外请求钱包授权。
    try {
      await _finishResolvedBinding(finalized);
    } on Object catch (error) {
      // finalized 链身份已经成立，本机公开绑定或数据收敛失败不能反向冒充“注册失败”。
      // `_finishFinalizedBinding` 的 finally 已广播新身份；具体本机能力在真实访问时
      // 继续按安全边界自愈或显示自身错误。
      AppLog.d('CID finalized 后本机绑定收敛待后续自愈: $error');
    }
    return cid;
  }

  /// 把当前身份 CID [cidNumber] 换绑到另一本地账户 [newAccountId]。
  ///
  /// 当前账户 = **当前 CID 绑定账户**(经 [FinalizedIdentityResolver] 解析,可为任意 `//n`,
  /// 非恒账户0),对含创世、当前绑定、revision 与 expires_at 的授权载荷签名;新账户自签
  /// 提交 `self_rebind_cid_account_id`(当前、新账户各签名一次)。换绑成功后 CID 归
  /// 新账户、广播身份绑定变化,常驻页/身份页跟随。
  /// 仅**匿名 CID** 可自助换绑;投票/竞选链端强制走注册局(`CivicRebindRequiresRegistrar`)。
  Future<void> rebindCidTo({
    required BuildContext? buildContext,
    required String cidNumber,
    required String newAccountId,
  }) async {
    final resolved = await _identityResolver.resolve();
    if (resolved == null || !resolved.isRegistered) {
      throw const AccountSecurityException('当前无已注册身份,无法换绑');
    }
    final currentAccountId = resolved.accountId;
    final resolvedCidNumber = resolved.snapshot?.cidNumber;
    if (resolvedCidNumber == null || resolvedCidNumber != cidNumber) {
      throw const AccountSecurityException('当前链上身份与待换绑 CID 不一致');
    }
    final newAccount = _findAccount(
      await _wallet.getState().result,
      newAccountId,
    );
    if (newAccount == null) {
      throw const AccountSecurityException('目标账户不存在');
    }
    if (newAccount.accountId == currentAccountId) {
      throw const AccountSecurityException('目标账户与当前身份账户相同');
    }
    final context = await _identityTransaction
        .fetchSelfRebindAuthorizationContext(cidNumber);
    if (context.currentAccountId != currentAccountId) {
      throw const AccountSecurityException('CID 当前绑定账户已经变化，请刷新后重试');
    }
    final source = IdentityBinding(
      genesisHash: '0x${_bytesToHex(context.genesisHash)}',
      cidNumber: cidNumber,
      bindingRevision: context.expectedBindingRevision.toInt(),
      accountId: currentAccountId,
    );
    final target = IdentityBinding(
      genesisHash: source.genesisHash,
      cidNumber: cidNumber,
      bindingRevision: source.bindingRevision + 1,
      accountId: newAccount.accountId,
    );
    final currentAccountDigest =
        await CitizenIdentityTransaction.buildRebindSigningDigest(
          genesisHash: context.genesisHash,
          cidNumber: cidNumber,
          currentAccountId: currentAccountId,
          newAccountId: newAccount.accountId,
          expectedBindingRevision: context.expectedBindingRevision,
          expiresAt: context.expiresAt,
        );
    if (buildContext != null && !buildContext.mounted) {
      throw const AccountSecurityException('当前页面已经关闭');
    }
    final currentAccountSignature = await signCitizenPayload(
      signing: _signing,
      context: buildContext,
      accountId: currentAccountId,
      payload: currentAccountDigest,
      action: kOpSignCidRebind,
    );
    await _identityTransaction.selfRebindCidAccount(
      cidNumber: cidNumber,
      newAccountId: newAccount.accountId,
      currentAccountId: currentAccountId,
      context: context,
      currentAccountSignature: currentAccountSignature,
      externalSigning: (pending) =>
          buildContext == null || !buildContext.mounted
          ? Future<String?>.value()
          : showCitizenSdkQrResponse(
              buildContext,
              request: pending.qrRequest,
              expiresAt: BigInt.from(
                pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
              ),
            ),
    );
    // SDK 已核验交易执行，业务层已在同一 finalized 块核对目标绑定。
    await _finishFinalizedBinding(target);
  }

  /// 注册身份前的自付能力测算:返回门槛与该账户当前余额(均为**分**)。
  ///
  /// 门槛 = 链上 `OnchainMinFee + ExistentialDeposit`,两个数都现取自链上 metadata——
  /// 交易费常量真源恒在区块链常量库,App 侧不留任何副本。余额走 `forceFresh` 绕开块内
  /// 缓存,否则会拿到充值前的旧值,把刚充完钱的用户又踢回充值页。
  ///
  /// 链读失败**不吞**:上抛给调用方 fail-closed 处理,绝不静默当成「余额不足」或「充足」。
  Future<({BigInt requiredFen, BigInt balanceFen})>
  fetchRegistrationAffordability(String bindAccountId) async {
    final fees = await _chain.getFeeSnapshot();
    final requiredFen = fees.minimumFeeFen + fees.existentialDepositFen;
    final balance = await AccountBalanceSnapshotStore.forChain(_chain)
        .getAccountBalance(bindAccountId, forceRefresh: true);
    return (requiredFen: requiredFen, balanceFen: balance.freeFen);
  }

  Future<IdentityBinding> _bindingForFinalizedIdentity(
    FinalizedIdentity resolved,
  ) async {
    final snapshot = resolved.snapshot;
    if (snapshot == null) {
      throw const AccountSecurityException('当前无已注册身份，无法解析MLS设备绑定');
    }
    final genesisHash = await _chain.getGenesisHash();
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(genesisHash)) {
      throw const AccountSecurityException('创世哈希无效，禁止激活当前身份绑定');
    }
    return IdentityBinding(
      genesisHash: genesisHash,
      cidNumber: snapshot.cidNumber,
      bindingRevision: snapshot.bindingRevision,
      accountId: resolved.accountId,
    );
  }

  /// 只供 CID 注册 finalized 调用；页面门禁与 finalized 均不得初始化任何设备密钥。
  Future<void> _finishResolvedBinding(FinalizedIdentity resolved) async {
    await _finishFinalizedBinding(await _bindingForFinalizedIdentity(resolved));
  }

  /// finalized只推进公开身份和失效代次；不派生材料，不登记设备或请求钱包授权。
  Future<void> _finishFinalizedBinding(IdentityBinding current) async {
    try {
      // 自助占号/换绑已经按交易finalized块验证匿名CID绑定；直接保存该事实，页面不再查链。
      await _badgeSnapshotStore.writeVerified(
        accountId: current.accountId,
        identity: CitizenIdentityChainSnapshot(
          cidNumber: current.cidNumber,
          accountId: Uint8List.fromList([
            for (var i = 2; i < current.accountId.length; i += 2)
              int.parse(current.accountId.substring(i, i + 2), radix: 16),
          ]),
          bindingRevision: current.bindingRevision,
          votingIdentity: null,
        ),
        isCurrent: () => true,
      );
      final previous = await _accountSecurity.readIdentityBindingForCid(
        current.cidNumber,
      );
      await _accountSecurity.activateIdentityBinding(
        genesisHash: current.genesisHash,
        cidNumber: current.cidNumber,
        bindingRevision: current.bindingRevision,
        accountId: current.accountId,
      );
      _currentUserContext.invalidate();
      if (previous != null) {
        _sessionProvider.invalidateAccount(previous.accountId);
      }
      SquareApiClient.activateFinalizedBinding(
        cidNumber: current.cidNumber,
        bindingRevision: current.bindingRevision,
        accountId: current.accountId,
      );
      await _chatRuntime().convergeFinalizedBinding(
        ChatBinding(
          bindingScope: current.genesisHash,
          userId: current.cidNumber,
          bindingRevision: current.bindingRevision,
          accountId: current.accountId,
        ),
      );
    } finally {
      // CID 占号与换绑不一定改变 account_id，必须先清“未注册”快照再广播；所有常驻
      // 页面收到 revision 后按 cid_number + account_id 重读，禁止依赖重启 App。
      _currentUserContext.invalidate();
      _accountSecurity.notifyIdentityBindingChanged();
    }
  }

  static String _bytesToHex(List<int> bytes) {
    const alphabet = '0123456789abcdef';
    final output = StringBuffer();
    for (final byte in bytes) {
      output
        ..write(alphabet[(byte >> 4) & 0x0f])
        ..write(alphabet[byte & 0x0f]);
    }
    return output.toString();
  }

  Future<FinalizedIdentity> _requireFinalizedBinding({
    required String cidNumber,
    required String accountId,
  }) async {
    final state = await _wallet.getState().result;
    final account = _findAccount(state, accountId);
    if (account == null) throw const AccountSecurityException('所选注册账户已变化');
    final resolved = state.defaultAccount?.accountId == accountId
        ? await _identityResolver.resolve()
        : FinalizedIdentity(
            accountId: accountId,
            ss58Address: account.ss58Address,
            snapshot: await CitizenIdentityChainReader(chain: _chain)
                .readByAccountId(accountId),
          );
    final snapshot = resolved?.snapshot;
    if (resolved == null ||
        snapshot == null ||
        snapshot.cidNumber != cidNumber ||
        resolved.accountId != accountId) {
      throw const AccountSecurityException('finalized CID 当前绑定与预期不一致');
    }
    return resolved;
  }

  final Map<String, FinalizedRegistration> _registrationFinalized = {};

  /// 锁定钱包代际及默认账户；切换或移除账户后不借其他账户继续签名。
  Future<Future<void> Function()> registrationGuard(String accountId) async {
    final initial = await _wallet.getState().result;
    if (_findAccount(initial, accountId) == null) {
      throw const AccountSecurityException('注册账户不存在');
    }
    return () async {
      final state = await _wallet.getState().result;
      if (state.revision != initial.revision ||
          state.defaultAccount?.accountId !=
              initial.defaultAccount?.accountId ||
          _findAccount(state, accountId) == null) {
        throw const AccountSecurityException('注册期间钱包账户已变化');
      }
    };
  }

  Future<String> registrationChainScope() => _chain.getGenesisHash();

  /// 恢复只查询finalized双向绑定；链读失败直接上抛，不伪装未注册。
  Future<FinalizedRegistration?> readRegistrationIdentity(
    String accountId,
  ) async {
    final state = await _wallet.getState().result;
    final account = _findAccount(state, accountId);
    if (account == null) throw const AccountSecurityException('注册账户已移除');
    final snapshot = await CitizenIdentityChainReader(chain: _chain)
        .readByAccountId(accountId);
    if (snapshot == null) return null;
    final binding = await _bindingForFinalizedIdentity(
      FinalizedIdentity(
        accountId: accountId,
        ss58Address: account.ss58Address,
        snapshot: snapshot,
      ),
    );
    final saved = _registrationFinalized[accountId];
    return FinalizedRegistration(
      binding: binding,
      blockHash: saved?.binding.cidNumber == binding.cidNumber
          ? saved!.blockHash
          : (await _chain.getFinalizedHead()).hash,
      txHash: saved?.binding.cidNumber == binding.cidNumber
          ? saved?.txHash
          : null,
    );
  }

  /// 原交易入口内部生成CID、签名和finalized；编排消费真实公开结果。
  Future<FinalizedRegistration> registerEnrollmentCid({
    required BuildContext? context,
    required String institution,
    required String accountId,
    required Future<void> Function(Map<String, dynamic>) onCheckpoint,
  }) async {
    var executionStarted = false;
    _registrationCheckpoint = (checkpoint) async {
      // executing必须先持久化再进入SDK；一旦进入该阶段，任何未知失败都禁止重发。
      if (checkpoint['state'] == 'executing') executionStarted = true;
      await onCheckpoint(checkpoint);
    };
    try {
      await registerAnonymousCid(
        context: context,
        institution: institution,
        bindAccountId: accountId,
      );
      return _registrationFinalized[accountId] ??
          (throw const AccountSecurityException('finalized注册证据未保存'));
    } catch (_) {
      if (!executionStarted) throw const RegistrationBeforeBroadcastException();
      rethrow;
    } finally {
      _registrationCheckpoint = null;
    }
  }

  Future<bool> canRetryRegistration(Map<String, dynamic>? checkpoint) async {
    if (checkpoint == null) return false;
    if ({
      'prepared',
      'cancelled_before_broadcast',
    }.contains(checkpoint['state'])) {
      return true;
    }
    final history = _history;
    if (history == null || checkpoint['execution_id'] is! String) return false;
    var page = await history.syncTransactionHistory();
    final visited = <String>{};
    for (var count = 0; count < 100; count++) {
      final matching = page.records
          .where(
            (item) =>
                item.executionId == checkpoint['execution_id'] &&
                item.sourceAccountId == checkpoint['account_id'] &&
                item.callDataHash == checkpoint['call_data_hash'],
          )
          .toList();
      if (matching.length > 1) return false;
      if (matching.length == 1) {
        return matching.single.status ==
                CitizenTransactionHistoryStatus.poolRejected ||
            matching.single.status ==
                CitizenTransactionHistoryStatus.finalizedFailed;
      }
      final cursor = page.nextBeforeExecutionId;
      if (cursor == null || !visited.add(cursor)) return false;
      page = await history.getTransactionHistory(beforeExecutionId: cursor);
    }
    return false;
  }

  Future<String> activateRegistration(FinalizedRegistration finalized) async {
    await _sessionProvider.projectFinalizedIdentity(finalized.blockHash);
    await _finishFinalizedBinding(finalized.binding);
    final session = await _sessionProvider.ensureSessionForAccountId(
      finalized.binding.accountId,
    );
    if (session == null ||
        session.cidNumber != finalized.binding.cidNumber ||
        session.bindingRevision != finalized.binding.bindingRevision ||
        !session.isUsable) {
      throw const AccountSecurityException('注册普通会话与finalized身份不一致');
    }
    // 会话deviceId已经由同一SDK的实际MLS证明核对；编排再核对服务器激活回执。
    return session.deviceId;
  }

  /// 列出可作换绑目标的本地账户(当前身份账户以外的全部账户)。
  Future<List<CitizenWalletStateAccount>> listRebindTargets() async {
    final state = await _wallet.getState().result;
    final defaultAccount = state.defaultAccount;
    if (defaultAccount == null) return const <CitizenWalletStateAccount>[];
    // 打开目标列表只读本机账户；实际提交换绑时才执行身份验真。
    final currentIdentityAccountId = defaultAccount.accountId;
    return state.accounts
        .where((account) => account.accountId != currentIdentityAccountId)
        .toList(growable: false);
  }

  /// 列出注册 CID 时可选的绑定账户(当前热钱包下全部本地账户,含账户0)。
  Future<List<CitizenWalletStateAccount>> listBindableAccounts() async {
    return (await _wallet.getState().result).accounts;
  }

  static CitizenWalletStateAccount? _findAccount(
    CitizenWalletState state,
    String accountId,
  ) {
    for (final account in state.accounts) {
      if (account.accountId == accountId) return account;
    }
    return null;
  }

  /// 把三段行政区码预 join 成「省·市·镇」展示串;省码空则返回空串。
  ///
  /// [formatAreaPath] 内部字典缺失会回退显 code(绝不崩、绝不空);再包一层
  /// 兜底防字典异常,避免选区展示阻断整卡。
  Future<String> _resolveDistrict(
    String province,
    String city,
    String town,
  ) async {
    if (province.isEmpty) return '';
    try {
      return await formatAreaPath(
        _divisionStore,
        provinceName: provinceDisplayNameByCode(province),
        provinceCode: province,
        cityCode: city,
        townCode: town,
      );
    } catch (e) {
      AppLog.d('myid area path resolve failed: $e');
      return [
        provinceDisplayNameByCode(province),
        city,
        town,
      ].where((s) => s.isNotEmpty).join(' · ');
    }
  }

  MyIdStatus _deriveStatus(_VotingIdentity identity) {
    if (identity.citizenStatus == _CitizenStatus.revoked) {
      return MyIdStatus.revoked;
    }
    final today = _dateInt(_nowProvider());
    if (today < identity.passportValidFrom) return MyIdStatus.notYetValid;
    if (today > identity.passportValidUntil) return MyIdStatus.expired;
    return MyIdStatus.normal;
  }

  /// 解码链上 `VotingIdentity<BlockNumber>`,字段序与
  /// `citizenchain/runtime/misc/citizen-identity/src/lib.rs` 逐字节一致:
  /// valid_from(u32) + valid_until(u32) + status(u8) + residence_省/市/镇码
  /// + updated_at(u32)。永久 CID 只存在于 storage key，不在值中重复保存。
  _VotingIdentity? _decodeVotingIdentity(Uint8List data) {
    try {
      var offset = 0;
      if (offset + 4 + 4 + 1 > data.length) return null;
      final validFrom = _readU32Le(data, offset);
      offset += 4;
      final validUntil = _readU32Le(data, offset);
      offset += 4;
      if (!_isValidDateInt(validFrom) || !_isValidDateInt(validUntil)) {
        return null;
      }
      final status = switch (data[offset]) {
        0 => _CitizenStatus.normal,
        1 => _CitizenStatus.revoked,
        _ => null,
      };
      if (status == null) return null;
      offset += 1;
      // 居住 3 码允许空(区划码可能只到市;空段绝不能把整条身份误判为不存在)。
      final prov = _readUtf8VecAllowEmpty(data, offset, maxLen: 16);
      offset = prov.nextOffset;
      final city = _readUtf8VecAllowEmpty(data, offset, maxLen: 16);
      offset = city.nextOffset;
      final town = _readUtf8VecAllowEmpty(data, offset, maxLen: 16);
      offset = town.nextOffset;
      // updated_at(BlockNumber=u32):只校验尾部存在,展示不使用。
      if (offset + 4 > data.length) return null;
      return _VotingIdentity(
        passportValidFrom: validFrom,
        passportValidUntil: validUntil,
        citizenStatus: status,
        resProvince: prov.value,
        resCity: city.value,
        resTown: town.value,
      );
    } catch (_) {
      return null;
    }
  }

  /// 解码链上 `CandidateIdentity<BlockNumber>`(增量存储,不含 voting 基础字段):
  /// birth_省/市/镇码 + family_name + given_name + citizen_sex(u8,0男1女)
  /// + birth_date(u32 YYYYMMDD) + updated_at(u32)。
  _CandidateIdentity? _decodeCandidateIdentity(Uint8List data) {
    try {
      var offset = 0;
      final prov = _readUtf8VecAllowEmpty(data, offset, maxLen: 16);
      offset = prov.nextOffset;
      final city = _readUtf8VecAllowEmpty(data, offset, maxLen: 16);
      offset = city.nextOffset;
      final town = _readUtf8VecAllowEmpty(data, offset, maxLen: 16);
      offset = town.nextOffset;
      final familyName = _readUtf8VecAllowEmpty(data, offset, maxLen: 128);
      offset = familyName.nextOffset;
      final givenName = _readUtf8VecAllowEmpty(data, offset, maxLen: 128);
      offset = givenName.nextOffset;
      if (offset + 1 > data.length) return null;
      final sex = data[offset];
      offset += 1;
      if (sex != 0 && sex != 1) return null;
      // birth_date(u32 YYYYMMDD) + 尾部 updated_at(u32)。
      if (offset + 4 > data.length) return null;
      final birthDate = _readU32Le(data, offset);
      offset += 4;
      if (!_isValidDateInt(birthDate)) return null;
      if (offset + 4 > data.length) return null;
      return _CandidateIdentity(
        birthProvince: prov.value,
        birthCity: city.value,
        birthTown: town.value,
        familyName: familyName.value,
        givenName: givenName.value,
        sex: sex,
        birthDate: birthDate,
      );
    } catch (_) {
      return null;
    }
  }

  /// 读 `BoundedVec<u8>`,允许空(长度 0 返回空串)。区划码/姓名用。
  static ({String value, int nextOffset}) _readUtf8VecAllowEmpty(
    Uint8List data,
    int offset, {
    required int maxLen,
  }) {
    final (length, lengthSize) = _readCompactU32(data, offset);
    final start = offset + lengthSize;
    final end = start + length;
    if (length < 0 || length > maxLen || end > data.length) {
      throw const FormatException('BoundedVec 长度不合法');
    }
    if (length == 0) return (value: '', nextOffset: start);
    return (
      value: utf8.decode(data.sublist(start, end), allowMalformed: false),
      nextOffset: end,
    );
  }

  static (int, int) _readCompactU32(Uint8List data, int offset) {
    if (offset >= data.length) {
      throw const FormatException('Compact<u32> offset 越界');
    }
    final first = data[offset];
    final mode = first & 0x03;
    if (mode == 0) return (first >> 2, 1);
    if (mode == 1) {
      if (offset + 1 >= data.length) {
        throw const FormatException('Compact<u32> mode1 长度不足');
      }
      return ((first >> 2) | (data[offset + 1] << 6), 2);
    }
    if (mode == 2) {
      if (offset + 3 >= data.length) {
        throw const FormatException('Compact<u32> mode2 长度不足');
      }
      return (
        (first >> 2) |
            (data[offset + 1] << 6) |
            (data[offset + 2] << 14) |
            (data[offset + 3] << 22),
        4,
      );
    }
    throw const FormatException('Compact<u32> big-integer 模式暂不支持');
  }

  static int _readU32Le(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  static bool _isValidDateInt(int value) {
    final year = value ~/ 10000;
    final month = (value ~/ 100) % 100;
    final day = value % 100;
    return year >= 1900 &&
        year <= 9999 &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31;
  }

  static int _dateInt(DateTime value) =>
      value.year * 10000 + value.month * 100 + value.day;

  static String _formatDateInt(int value) {
    final year = value ~/ 10000;
    final month = (value ~/ 100) % 100;
    final day = value % 100;
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }
}

class _VotingIdentity {
  const _VotingIdentity({
    required this.passportValidFrom,
    required this.passportValidUntil,
    required this.citizenStatus,
    required this.resProvince,
    required this.resCity,
    required this.resTown,
  });

  final int passportValidFrom;
  final int passportValidUntil;
  final _CitizenStatus citizenStatus;
  final String resProvince;
  final String resCity;
  final String resTown;
}

class _CandidateIdentity {
  const _CandidateIdentity({
    required this.birthProvince,
    required this.birthCity,
    required this.birthTown,
    required this.familyName,
    required this.givenName,
    required this.sex,
    required this.birthDate,
  });

  final String birthProvince;
  final String birthCity;
  final String birthTown;
  final String familyName;
  final String givenName;
  final int sex;

  /// 出生日期(YYYYMMDD 整数),竞选身份专属。
  final int birthDate;
}

enum _CitizenStatus { normal, revoked }

/// 只观察原SDK公开检查点，原交易包装器仍是唯一RuntimeCall/签名/上链实现。
/// 准备句柄不是重发许可；未知广播必须等待SDK持久执行记录和链事实。
class _RegistrationTransactions implements CitizenTransactions {
  _RegistrationTransactions(this.delegate, this.checkpoint);
  final CitizenTransactions delegate;
  final Future<void> Function(Map<String, dynamic>) checkpoint;
  final Map<String, Map<String, dynamic>> prepared = {};
  final Map<String, Map<String, dynamic>> executions = {};
  String hex(Uint8List value) =>
      '0x${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  @override
  Future<CitizenPreparedTransaction> prepareTransaction(
    Uint8List account,
    Uint8List call,
  ) async {
    final result = await delegate.prepareTransaction(account, call);
    final record = <String, dynamic>{
      'preparation_id': result.preparationId,
      'account_id': hex(result.sourceAccountId),
      'call_data_hash': hex(result.callDataHash),
      'state': 'prepared',
    };
    await checkpoint(record);
    prepared[result.preparationId] = record;
    return result;
  }

  @override
  Future<CitizenTransactionExecution> executePreparedTransaction(
    String id,
  ) async {
    final record = prepared[id] ?? (throw StateError('SDK注册准备检查点缺失'));
    await checkpoint({...record, 'state': 'executing'});
    try {
      final result = await delegate.executePreparedTransaction(id);
      await remember(result, record);
      return result;
    } on CitizenSdkException catch (error) {
      if (error.code == CitizenSdkErrorCode.authenticationCancelled &&
          error.stage == CitizenSdkFailureStage.authentication) {
        await checkpoint({...record, 'state': 'cancelled_before_broadcast'});
      }
      rethrow;
    }
  }

  Future<void> remember(
    CitizenTransactionExecution result,
    Map<String, dynamic> record,
  ) async {
    final next = {
      ...record,
      'execution_id': result.executionId,
      'state': result is CitizenTransactionExecutionCompleted
          ? result.resolution.name
          : 'awaiting_qr',
      if (result is CitizenTransactionExecutionCompleted)
        'tx_hash': hex(result.transactionHash),
    };
    executions[result.executionId] = next;
    await checkpoint(next);
  }

  @override
  Future<CitizenTransactionExecutionCompleted>
  consumePreparedTransactionQrResponse(String id, String response) async {
    final result = await delegate.consumePreparedTransactionQrResponse(
      id,
      response,
    );
    await remember(
      result,
      executions[id] ?? (throw StateError('SDK注册执行检查点缺失')),
    );
    return result;
  }

  @override
  Future<void> cancelPreparedTransaction(String id) =>
      delegate.cancelPreparedTransaction(id);
  @override
  Future<void> cancelPreparedTransactionExecution(String id) async {
    await delegate.cancelPreparedTransactionExecution(id);
    await checkpoint({
      ...?executions[id],
      'state': 'cancelled_before_broadcast',
    });
  }
}
