import 'dart:async';
import 'dart:io';

import 'registration_coordinator.dart';
import 'registration_models.dart';
import 'registration_page.dart';

import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import 'package:citizenapp/account/identity/finalized_identity_resolver.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/account/identity/myid_service.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/register_identity_sheet.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/account/identity/account_security_service.dart';

/// 全App唯一注册编排：确认后服务器保存真人验证，再执行原余额/钱包/CID交易，
/// finalized后激活同一SDK的MLS设备及普通会话。返回true代表完整账户服务就绪。
/// onSubmitting覆盖验证、链交易与激活；取消、未知网络和待激活均失败关闭。
Future<bool> startCidRegistrationFlow(
  BuildContext context, {
  MyIdService? myIdService,
  ValueChanged<bool>? onSubmitting,
  Future<void> Function(BuildContext, String)? openTopup,
}) async {
  late final MyIdService service;
  if (myIdService != null) {
    service = myIdService;
  } else {
    final sdk = context.read<CitizenSdk>();
    service =
        context.read<MyIdService?>() ??
        MyIdService(
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
  // 已有公民号先恢复公开绑定与服务准备，绝不打开注册面板或Turnstile。
  try {
    final verified = await context.read<FinalizedIdentityResolver>().resolve();
    if (verified == null) return false;
    await service.synchronizeIdentity(verified);
    if (!context.mounted) return false;
    if (verified.isRegistered) {
      return await ensureCidRegisteredOrPrompt(context, myIdService: service);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnack(context, _describeError(error), isError: true);
    }
    return false;
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
  final registered = await showRegisterIdentitySheet(
    context,
    accounts: accounts,
    openTopup: openTopup,
    onSubmit: (sheetContext, choice) async {
      onSubmitting?.call(true);
      try {
        final coordinator = context.read<RegistrationCoordinator>();
        final guard = await service.registrationGuard(choice.bindAccountId);
        final registration = RegistrationContext(
          accountId: choice.bindAccountId,
          orgCode: choice.institution,
          chainScope: await service.registrationChainScope(),
        );
        await guard();
        final result = await coordinator.run(
          context: registration,
          requireCurrent: guard,
          showVerification: (verification) async {
            if (!sheetContext.mounted) return null;
            return Navigator.of(sheetContext).push<String>(
              MaterialPageRoute(
                builder: (_) => RegistrationPage(verification: verification),
              ),
            );
          },
          requireAffordable: () =>
              _requireAffordable(service, choice.bindAccountId),
          readFinalized: () =>
              service.readRegistrationIdentity(choice.bindAccountId),
          registerCid: (saveCheckpoint) => service.registerEnrollmentCid(
            context: sheetContext,
            onCheckpoint: saveCheckpoint,
            institution: choice.institution,
            accountId: choice.bindAccountId,
          ),
          activate: service.activateRegistration,
          canRetryChain: service.canRetryRegistration,
        );
        return RegistrationSubmitOutcome.success(
          '身份 CID 已注册:${result.binding.cidNumber}',
        );
      } on Object catch (error) {
        final insufficient =
            error is RegistrationException &&
            error.code == 'insufficient_balance';
        return RegistrationSubmitOutcome.failure(
          _describeError(error),
          recharge: insufficient,
        );
      } finally {
        onSubmitting?.call(false);
      }
    },
  );
  if (registered == true && context.mounted) {
    _showSnack(context, '身份 CID 已注册');
  }
  return registered == true;
}

/// 动作级统一拦截:动作(发布/私信/加好友/订阅/看资料…)要求已注册 CID 时,
/// 在动作入口调用本函数。
///
/// - 已注册 → 返回 true,动作继续;
/// - 无钱包 → 返回 false，外层 WalletGate 清栈回钱包初始化页;
/// - 未注册 → 返回 false，所属页面显示统一注册引导；只能由引导的注册按钮
///   打开 [startCidRegistrationFlow]，动作不得越过页面直接弹面板;
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
    return false;
  }
  try {
    final service = myIdService ?? context.read<MyIdService?>();
    if (service != null) await service.synchronizeIdentity(identity);
  } on Object {
    if (context.mounted) _showSnack(context, '身份同步失败，请重试', isError: true);
    return false;
  }
  if (!context.mounted) return false;
  if (identity.isRegistered) {
    try {
      final provider = context.read<SquareSessionProvider>();
      final resolution = await resolveCitizenSessionForAction(
        context,
        provider: provider,
      );
      if (!context.mounted) return false;
      if (resolution.status == SquareSessionStatus.ready &&
          resolution.session?.accountId == identity.accountId &&
          resolution.session?.cidNumber == identity.snapshot?.cidNumber &&
          resolution.session?.bindRev == identity.snapshot?.bindRev) {
        return true;
      }
      _showSnack(context, resolution.message, isError: true);
    } on Object catch (error) {
      if (context.mounted) {
        _showSnack(
          context,
          SquareSessionResolution.fromError(error).message,
          isError: true,
        );
      }
    }
    return false;
  }
  // 统一注册页面的按钮是唯一入口；动作自身不越过引导直接打开注册面板。
  return false;
}

/// 已有重试共用自动准备；没有初始化弹窗，也不借设备故障进入注册。
Future<SquareSessionResolution> resolveCitizenSessionForAction(
  BuildContext context, {
  required SquareSessionProvider provider,
}) async {
  try {
    var resolution = await provider.resolveSession();
    if (!context.mounted) return resolution;
    if (resolution.errorCode == 'device_not_registered' ||
        resolution.errorCode == 'authenticationRequired') {
      await provider.registerCurrentDevice();
      resolution = await provider.resolveSession();
    }
    return resolution;
  } on Object catch (error) {
    return SquareSessionResolution.fromError(error);
  }
}

/// 真人验证后、链交易前的余额闸；只报告已确认的余额不足。
///
/// 门槛 = 链上 `OnchainMinFee + ExistentialDeposit`,两个数都现取自链上 metadata
/// (交易费常量真源恒在区块链常量库,App 侧不留副本)。返回 true 表示可以继续提交。
///
/// 三个分支都必须 fail-closed 到「不产生误导」:
/// - 读失败 → 只提示重试。既不跳充值(会误导余额充足的用户去充钱),也不硬提交
///   (链上会以「交易无效」之类的含糊原因回绝,用户看不出真因)。
/// - 余额不足 → 抛准确状态，由仍挂载的注册身份页进入所选钱包链上充值；返回不自动续跑。
/// - 余额充足 → 放行提交。
Future<void> _requireAffordable(
  MyIdService service,
  String bindAccountId,
) async {
  final ({BigInt requiredFen, BigInt balanceFen}) affordability;
  try {
    affordability = await service.fetchRegistrationAffordability(bindAccountId);
  } on Object {
    throw const RegistrationException(
      '余额读取失败，请检查链连接后重试',
      code: 'balance_unavailable',
    );
  }
  final requiredFen = affordability.requiredFen;
  if (affordability.balanceFen >= requiredFen) return;
  throw RegistrationException(
    '注册失败：钱包余额不足，至少需要 ${_formatFen(requiredFen)} 元',
    code: 'insufficient_balance',
  );
}

/// 分 → 元展示串(两位小数)。
String _formatFen(BigInt fen) => (fen / BigInt.from(100)).toStringAsFixed(2);

String _describeError(Object error) {
  if (error is RegistrationException) return error.message;
  if (error is AccountSecurityException) return error.message;
  if (error is CitizenSdkException) {
    // 原生错误正文可能含内部细节；只按 SDK 公开错误码给出可操作的具体原因。
    return switch (error.code) {
      CitizenSdkErrorCode.authenticationCancelled ||
      CitizenSdkErrorCode.cancelled => '钱包签名授权已取消，注册未提交',
      CitizenSdkErrorCode.authenticationRequired => '钱包签名需要重新验证身份',
      CitizenSdkErrorCode.keyInvalidated => '钱包签名密钥已失效，请先恢复钱包',
      CitizenSdkErrorCode.permissionDenied => '钱包签名权限被拒绝，请检查设备授权',
      CitizenSdkErrorCode.network => '链网络连接失败，请检查网络后重试',
      CitizenSdkErrorCode.timeout => '链请求超时，请稍后重试',
      CitizenSdkErrorCode.unavailable => '链服务暂时不可用，请稍后重试',
      CitizenSdkErrorCode.storage => '本机安全存储失败，请检查设备存储状态',
      CitizenSdkErrorCode.integrity => '链上回执或身份校验未通过，请核实当前账户',
      CitizenSdkErrorCode.notFound => '所选钱包账户或链上登记不存在，请核对账户',
      CitizenSdkErrorCode.conflict => '注册状态冲突，请核对当前公民号状态',
      CitizenSdkErrorCode.notReady ||
      CitizenSdkErrorCode.invalidState => '钱包或链状态尚未就绪，请稍后重试',
      CitizenSdkErrorCode.busy ||
      CitizenSdkErrorCode.queueFull => '钱包正在处理其他请求，请稍后重试',
      CitizenSdkErrorCode.invalidArgument ||
      CitizenSdkErrorCode.decode => '注册数据校验失败，请核对所选账户',
      CitizenSdkErrorCode.unsupported => '当前钱包不支持本次注册操作',
      CitizenSdkErrorCode.invalidHandle ||
      CitizenSdkErrorCode.internal ||
      CitizenSdkErrorCode.panic => '钱包或链内部故障，请稍后重试',
    };
  }
  if (error is TimeoutException) return '注册验证服务响应超时，请稍后重试';
  if (error is SocketException) return '注册验证服务连接失败，请检查网络后重试';
  if (error is FormatException) return '注册服务响应格式不完整，请稍后重试';
  return '注册暂时无法完成，请检查网络和身份状态后重试';
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
