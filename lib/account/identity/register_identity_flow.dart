import 'registration_coordinator.dart';
import 'registration_models.dart';
import 'registration_page.dart';

import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import 'package:citizenapp/account/identity/finalized_identity_resolver.dart';
import 'package:citizenapp/8964/profile/square_session_provider.dart';
import 'package:citizenapp/account/identity/myid_service.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/register_identity_sheet.dart';
import 'package:citizenapp/transaction/topup/onchain_topup_page.dart';
import 'package:citizenapp/theme/app_theme.dart';
import 'package:citizenapp/security/account_security_service.dart';

/// 全App唯一注册编排：确认后服务器保存真人验证，再执行原余额/钱包/CID交易，
/// finalized后激活同一SDK的MLS设备及普通会话。返回true代表完整账户服务就绪。
/// onSubmitting覆盖验证、链交易与激活；取消、未知网络和待激活均失败关闭。
Future<bool> startCidRegistrationFlow(
  BuildContext context, {
  MyIdService? myIdService,
  ValueChanged<bool>? onSubmitting,
}) async {
  late final MyIdService service;
  if (myIdService != null) {
    service = myIdService;
  } else {
    final sdk = context.read<CitizenSdk>();
    service = MyIdService(
      wallet: sdk.wallet,
      signing: sdk.signing,
      chain: sdk.chain,
      transactions: sdk.transactions,
      history: sdk.history,
      accountSecurity: context.read<AccountSecurityService>(),
      currentUserContext: context.read<CurrentUserContext>(),
      identityResolver: context.read<FinalizedIdentityResolver>(),
      sessionProvider: context.read<SquareSessionProvider>(),
      chatRuntime: () => context.read<ChatSdk>(),
    );
  }
  final List<CitizenWalletStateAccount> accounts;
  try {
    accounts = await service.listBindableAccounts();
  } on Exception catch (error) {
    if (!context.mounted) return false;
    _showSnack(context, _describeError(error), isError: true);
    return false;
  }
  if (!context.mounted) return false;
  final choice = await showRegisterIdentitySheet(context, accounts: accounts);
  if (choice == null || !context.mounted) return false;
  onSubmitting?.call(true);
  try {
    final coordinator = context.read<RegistrationCoordinator>();
    final guard = await service.registrationGuard(choice.bindAccountId);
    final registration = RegistrationContext(
      accountId: choice.bindAccountId,
      institution: choice.institution,
      chainScope: await service.registrationChainScope(),
    );
    await guard();
    final result = await coordinator.run(
      context: registration,
      requireCurrent: guard,
      showVerification: (verification) async {
        if (!context.mounted) return null;
        return Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => RegistrationPage(verification: verification),
          ),
        );
      },
      ensureAffordable: () => context.mounted
          ? _ensureAffordable(context, service, choice.bindAccountId)
          : Future.value(false),
      readFinalized: () =>
          service.readRegistrationIdentity(choice.bindAccountId),
      registerCid: (saveCheckpoint) => service.registerEnrollmentCid(
        context: context,
        onCheckpoint: saveCheckpoint,
        institution: choice.institution,
        accountId: choice.bindAccountId,
      ),
      activate: service.activateRegistration,
      canRetryChain: service.canRetryRegistration,
    );
    final cid = result.binding.cidNumber;
    if (context.mounted) _showSnack(context, '身份 CID 已注册:$cid');
    return true;
  } on Object catch (error) {
    if (!context.mounted) return false;
    _showSnack(context, _describeError(error), isError: true);
    return false;
  } finally {
    onSubmitting?.call(false);
  }
}

/// 动作级统一拦截:动作(发布/私信/加好友/订阅/看资料…)要求已注册 CID 时,
/// 在动作入口调用本函数。
///
/// - 已注册 → 返回 true,动作继续;
/// - 无热钱包 → 提示创建钱包,返回 false;
/// - 未注册 → 就地弹统一注册面板([startCidRegistrationFlow]),返回 false
///   ——注册成功后由用户重新触发原动作,与身份页充值后不自动续跑同一哲学;
/// - 身份链读失败 → fail-closed 提示稍后重试,绝不把"没读到链"当成"未注册"。
///
/// [myIdService] 仅测试注入,生产一律省缺。
Future<bool> ensureCidRegisteredOrPrompt(
  BuildContext context, {
  MyIdService? myIdService,
  FinalizedIdentityResolver? identityResolver,
}) async {
  final FinalizedIdentity? identity;
  try {
    identity =
        await (identityResolver ?? context.read<FinalizedIdentityResolver>())
            .resolve();
  } on Exception {
    if (!context.mounted) return false;
    _showSnack(context, '暂时无法验证身份，请稍后重试');
    return false;
  }
  if (!context.mounted) return false;
  if (identity == null) {
    _showSnack(context, '请先在「我的 → 我的钱包」创建热钱包');
    return false;
  }
  if (identity.isRegistered) {
    try {
      final resolution = await context
          .read<SquareSessionProvider>()
          .resolveSession();
      if (!context.mounted) return false;
      if (resolution.status == SquareSessionStatus.ready &&
          resolution.session?.accountId == identity.accountId &&
          resolution.session?.cidNumber == identity.snapshot?.cidNumber &&
          resolution.session?.bindingRevision ==
              identity.snapshot?.bindingRevision) {
        return true;
      }
      final pending =
          resolution.status == SquareSessionStatus.deviceUnavailable &&
          await context.read<RegistrationCoordinator>().store.hasPendingAccount(
            identity.accountId,
            await context.read<CitizenSdk>().chain.getGenesisHash(),
          );
      if (!context.mounted) return false;
      if (resolution.errorCode == 'registration_required' || pending) {
        await startCidRegistrationFlow(context, myIdService: myIdService);
      } else {
        _showSnack(context, resolution.message, isError: true);
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, '账户服务尚未完成验证和设备激活，请在身份页继续注册', isError: true);
      }
    }
    return false;
  }
  await startCidRegistrationFlow(context, myIdService: myIdService);
  return false;
}

/// 注册前的余额闸:占号是**自签自付**的链上交易,余额不够连入池预检都过不了。
///
/// 门槛 = 链上 `OnchainMinFee + ExistentialDeposit`,两个数都现取自链上 metadata
/// (交易费常量真源恒在区块链常量库,App 侧不留副本)。返回 true 表示可以继续提交。
///
/// 三个分支都必须 fail-closed 到「不产生误导」:
/// - 读失败 → 只提示重试。既不跳充值(会误导余额充足的用户去充钱),也不硬提交
///   (链上会以「交易无效」之类的含糊原因回绝,用户看不出真因)。
/// - 余额不足 → 直接把用户带到**这个绑定账户**的链上充值页;返回后停在原页面,
///   由用户自行再点注册,不自动续跑。
/// - 余额充足 → 放行提交。
Future<bool> _ensureAffordable(
  BuildContext context,
  MyIdService service,
  String bindAccountId,
) async {
  final ({BigInt requiredFen, BigInt balanceFen}) affordability;
  try {
    affordability = await service.fetchRegistrationAffordability(bindAccountId);
  } on Object catch (error) {
    if (!context.mounted) return false;
    _showSnack(context, '余额读取失败,请重试:${_describeError(error)}', isError: true);
    return false;
  }
  final requiredFen = affordability.requiredFen;
  if (affordability.balanceFen >= requiredFen) return true;
  if (!context.mounted) return false;
  _showSnack(context, '余额不足,注册身份至少需要 ${_formatFen(requiredFen)} 元,请先充值');
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => OnchainTopupPage(accountId: bindAccountId),
    ),
  );
  return false;
}

/// 分 → 元展示串(两位小数)。
String _formatFen(BigInt fen) => (fen / BigInt.from(100)).toStringAsFixed(2);

String _describeError(Object error) {
  if (error is AccountSecurityException) return error.message;
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

void _showSnack(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppTheme.danger : null,
    ),
  );
}
