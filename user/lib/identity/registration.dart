// 整合CID生成、人验、自助注册及注册界面。

import 'dart:convert';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/format.dart';
import 'package:citizen_system/security/access.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/chat.dart';
import 'package:citizen_user/identity/state.dart' show FinalizedIdentity, FinalizedIdentityResolver, MyIdService;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider, SquareSessionResolution, SquareSessionStatus;
import 'package:citizen_user/context.dart' show CurrentUserContext, IdentityBinding;
import 'package:citizen_system/theme.dart';
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_topup/page.dart';
import 'package:http/http.dart' as http;
import 'package:citizen_network/http.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:citizen_system/security/storage.dart';

// 按链原语的人主体协议生成公民或居民CID号码。

/// 人主体机构码:公民。
const String kCidInstitutionCitizen = 'CTZN';

/// 人主体机构码:居民。
const String kCidInstitutionResident = 'NATP';

/// 校验位字母表(对齐 number.rs `CHECKSUM_ALPHABET`)。
const String _checksumAlphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// 人主体号段容量:12 位十进制 = 1e12/年。
final BigInt _numberModulus = BigInt.from(1000000000000);

/// R5 高 3 位 / N9 低 9 位分界:1e9。
final BigInt _highLowSplit = BigInt.from(1000000000);

/// 生成公民 / 居民「人主体」CID 号(链上自助占号首选候选号)。
///
/// [accountId] 必须为小写 `0x` + 64 位十六进制的账户文本(与链端 `public_key`
/// 输入逐字节一致,原样进 hash,不做大小写归一)。[institution] 取 `CTZN`(公民)
/// 或 `NATP`(居民)。[year] 为 4 位公历年份 YYYY。
String generateCitizenCid({
  required String accountId,
  required String institution,
  required int year,
}) {
  if (institution != kCidInstitutionCitizen &&
      institution != kCidInstitutionResident) {
    throw ArgumentError.value(
      institution,
      'institution',
      '人主体 CID 仅支持 CTZN(公民)/ NATP(居民)',
    );
  }
  if (year < 1000 || year > 9999) {
    throw ArgumentError.value(year, 'year', 'year 必须为 4 位公历年份 YYYY');
  }
  final yearText = year.toString();

  final input = '$accountId|$institution|$yearText';
  final digest = CitizenScale.blake2b256(utf8.encode(input));

  // 前 8 字节小端 → 无符号 u64。用 BigInt 承载,避免 Dart 有符号 int 在高位溢出。
  final n = CitizenScale.readUnsigned(digest, 0, 8);
  final number = n % _numberModulus;
  final high3 = (number ~/ _highLowSplit).toInt(); // 0..=999
  final low9 = (number % _highLowSplit).toInt();

  final r5 = 'CN${high3.toString().padLeft(3, '0')}';
  final n9 = low9.toString().padLeft(9, '0');

  final payload = '$r5$institution$n9$yearText';
  final m1 = _checksumCharM1(payload);

  return '$r5-$institution$m1-$n9-$yearText';
}

/// 4 字符布局盈利码(Profit)的 M1 校验位 —— 对齐 number.rs
/// `checksum_char_m1(payload, profit = true)`:`'0' + (acc % 10)`。
String _checksumCharM1(String payload) {
  final acc = _checksumAcc(payload);
  final zero = '0'.codeUnitAt(0);
  return String.fromCharCode(zero + (acc % 10));
}

/// 校验和累加器 —— 对齐 number.rs `checksum_acc`:
/// `Σ (idx+1) * alphabetIndex(ch)`,字母表外字符按索引 0 计。
int _checksumAcc(String payload) {
  var total = 0;
  for (var idx = 0; idx < payload.length; idx++) {
    final pos = _checksumAlphabet.indexOf(payload[idx]);
    total += (idx + 1) * (pos < 0 ? 0 : pos);
  }
  return total;
}

// 协调统一人验、原链注册和最终结果报告及既有身份恢复。

/// 全App唯一注册编排：默认人验通过后执行原链交易和最终性，再报告公开绑定。
/// 注册报告不授予设备或会话；账户切换和未知交易结果仍失败关闭。
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
          wallet: sdk,
          signing: sdk,
          chain: sdk,
          transactions: sdk,
          history: sdk,
          accountSecurity: context.read<AccountSecurityService>(),
          currentUserContext: context.read<CurrentUserContext>(),
          identityResolver: context.read<FinalizedIdentityResolver>(),
          sessionProvider: context.read<SquareSessionProvider>(),
          onChatBindingChanged: (binding, {required existingOnly}) async {
            final ChatRuntime? runtime = existingOnly
                ? null
                : (() => context.read<ChatRuntime>())();
            await runtime?.convergeFinalizedBinding(
              ChatBinding.fromIdentity(binding),
            );
          },
        );
  }
  // 已有身份CID号先恢复公开绑定与服务准备，绝不打开注册面板或Turnstile。
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
          showVerification: () async {
            if (!sheetContext.mounted) return null;
            return Navigator.of(sheetContext).push<RegistrationVerification>(
              MaterialPageRoute(builder: (_) => const RegistrationPage()),
            );
          },
          requireAffordable: () =>
              _requireAffordable(service, choice.bindAccountId),
          readFinalized: () =>
              service.readRegistrationIdentity(choice.bindAccountId),
          registerCid: (saveCheckpoint) => service.registerCid(
            context: sheetContext,
            onCheckpoint: saveCheckpoint,
            institution: choice.institution,
            accountId: choice.bindAccountId,
          ),
          canRetryChain: service.canRetryRegistration,
        );
        return RegistrationSubmitOutcome.success(
          '身份CID号 已注册:${formatIdentityCidText(result.binding.cidNumber)}',
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
    _showSnack(context, '身份CID号 已注册');
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
    '注册失败：钱包余额不足，至少需要 ${formatFen(requiredFen, group: false)} 元',
    code: 'insufficient_balance',
  );
}

/// 分 → 元展示串(两位小数)。

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
      CitizenSdkErrorCode.conflict => '注册状态冲突，请核对当前身份CID号状态',
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
      content: Text(identityCidUiText(message)),
      backgroundColor: isError ? AppTheme.danger : null,
    ),
  );
}

// 采集公民或居民类型和绑定账户，展示注册提交状态。

/// 「注册身份」的选择结果:身份类型 + 绑定的钱包账户。
class RegisterChoice {
  const RegisterChoice({
    required this.institution,
    required this.bindAccountId,
  });

  /// [kCidInstitutionCitizen](公民)/ [kCidInstitutionResident](居民)。
  final String institution;

  /// CID 绑定的钱包账户 account_id(鉴权凭证,可任意 `//n`;私钥泄漏可换绑)。
  final String bindAccountId;
}

/// 提交结果只携带安全的页面状态；余额不足的充值目标始终取本页所选账户。
final class RegistrationSubmitOutcome {
  const RegistrationSubmitOutcome.success(this.message)
    : registered = true,
      recharge = false;
  const RegistrationSubmitOutcome.failure(this.message, {this.recharge = false})
    : registered = false;

  final bool registered;
  final bool recharge;
  final String message;
}

/// 注册身份面板在真人验证、链交易和失败后保持挂载；正常流程只在成功或主动取消时关闭。
/// 外层 WalletGate 在钱包被清空时仍可主动清栈回初始化页。
/// [accounts] 来自 WalletGate 已放行的钱包；充值只进入本页选择的绑定账户。
Future<bool?> showRegisterIdentitySheet(
  BuildContext context, {
  required List<CitizenWalletStateAccount> accounts,
  required Future<RegistrationSubmitOutcome> Function(
    BuildContext sheetContext,
    RegisterChoice choice,
  )
  onSubmit,
  Future<void> Function(BuildContext, String)? openTopup,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => RegisterIdentitySheet(
      accounts: accounts,
      onSubmit: onSubmit,
      openTopup: openTopup,
    ),
  );
}

class RegisterIdentitySheet extends StatefulWidget {
  const RegisterIdentitySheet({
    super.key,
    required this.accounts,
    required this.onSubmit,
    this.openTopup,
  });

  final List<CitizenWalletStateAccount> accounts;
  final Future<RegistrationSubmitOutcome> Function(
    BuildContext sheetContext,
    RegisterChoice choice,
  )
  onSubmit;
  final Future<void> Function(BuildContext, String)? openTopup;

  @override
  State<RegisterIdentitySheet> createState() => _RegisterIdentitySheetState();
}

class _RegisterIdentitySheetState extends State<RegisterIdentitySheet> {
  bool _submitted = false;
  String? _error;
  bool _needsTopup = false;
  String _institution = kCidInstitutionCitizen;
  late final List<CitizenWalletStateAccount> _sortedAccounts;
  late String _bindAccountId;

  @override
  void initState() {
    super.initState();
    _sortedAccounts = [...widget.accounts]
      ..sort(
        (a, b) => (a.accountIndex ?? 0x7fffffff).compareTo(
          b.accountIndex ?? 0x7fffffff,
        ),
      );
    // 默认绑账户0(序号最小者);列表为空是异常兜底,留空由 service 拒。
    _bindAccountId = _sortedAccounts.isEmpty
        ? ''
        : _sortedAccounts.first.accountId;
  }

  Future<void> _submit() async {
    if (_submitted || _sortedAccounts.isEmpty) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    final choice = RegisterChoice(
      institution: _institution,
      bindAccountId: _bindAccountId,
    );
    try {
      final outcome = await widget.onSubmit(context, choice);
      if (!mounted) return;
      if (outcome.registered) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = outcome.message);
      setState(() => _needsTopup = outcome.recharge);
    } on Object {
      if (mounted) setState(() => _error = '注册暂时无法完成，请重试');
    } finally {
      if (mounted) setState(() => _submitted = false);
    }
  }

  Future<void> _openTopup(String token) async {
    if (_submitted) return;
    final id = _bindAccountId;
    if (widget.openTopup != null) {
      await widget.openTopup!(context, id);
    } else {
      await showTopup(context, accountId: id, token: token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      // 人验和链交易期间不允许系统返回关闭面板；空闲时可主动取消。
      canPop: !_submitted,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: AppLayout.scaled(context, 36),
                    height: AppLayout.scaled(context, 4),
                    margin: EdgeInsets.only(
                      bottom: AppLayout.scaled(context, 2),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary,
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(2),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: AppLayout.scaled(context, 16),
                        ),
                        child: Text(
                          '注册身份',
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 17),
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(
                          top: AppLayout.scaled(context, 16),
                        ),
                        minimumSize: const Size(
                          AppLayout.minimumTapTarget,
                          AppLayout.minimumTapTarget,
                        ),
                      ),
                      onPressed: _submitted
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                  ],
                ),
                SizedBox(height: AppLayout.scaled(context, 2)),
                Text(
                  '身份CID号是公民App的唯一用户账号，所绑定的钱包是唯一登录与控制凭证，请妥善保存。',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 12),
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: AppLayout.scaled(context, 16)),
                const _SectionLabel('身份类型'),
                SizedBox(height: AppLayout.scaled(context, 8)),
                _TypeOption(
                  label: '公民',
                  code: kCidInstitutionCitizen,
                  desc: '可后续到注册局线下升级为投票 / 竞选公民。',
                  selected: _institution == kCidInstitutionCitizen,
                  onTap: () =>
                      setState(() => _institution = kCidInstitutionCitizen),
                ),
                SizedBox(height: AppLayout.scaled(context, 10)),
                _TypeOption(
                  label: '居民',
                  code: kCidInstitutionResident,
                  desc: '永久匿名身份,不可升级为投票 / 竞选公民。',
                  selected: _institution == kCidInstitutionResident,
                  onTap: () =>
                      setState(() => _institution = kCidInstitutionResident),
                ),
                if (_sortedAccounts.length > 1) ...[
                  SizedBox(height: AppLayout.scaled(context, 16)),
                  const _SectionLabel('绑定钱包账户'),
                  SizedBox(height: AppLayout.scaled(context, 8)),
                  ..._sortedAccounts.map(
                    (account) => Padding(
                      padding: EdgeInsets.only(
                        bottom: AppLayout.scaled(context, 8),
                      ),
                      child: _AccountRadio(
                        account: account,
                        selected: _bindAccountId == account.accountId,
                        onTap: () =>
                            setState(() => _bindAccountId = account.accountId),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: AppLayout.scaled(context, 16)),
                if (_error != null) ...[
                  Text(
                    identityCidUiText(_error!),
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                  if (_needsTopup)
                    Row(
                      children: [
                        TextButton(
                          onPressed: _submitted
                              ? null
                              : () => _openTopup('USDT'),
                          child: const Text('充值/USDT'),
                        ),
                        TextButton(
                          onPressed: _submitted
                              ? null
                              : () => _openTopup('USDC'),
                          child: const Text('充值/USDC'),
                        ),
                      ],
                    ),
                  SizedBox(height: AppLayout.scaled(context, 12)),
                ],
                SizedBox(
                  width: double.infinity,
                  height: AppLayout.scaled(context, 46),
                  child: FilledButton(
                    onPressed: _submitted || _sortedAccounts.isEmpty
                        ? null
                        : _submit,
                    child: Text(_submitted ? '注册中…' : '确认注册'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: AppLayout.scaled(context, 12),
        color: AppTheme.textTertiary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 身份类型选项卡:选中态描边加粗、附机构码与说明。
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.code,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.border;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  AppTheme.primary.withAlpha(10),
                  AppTheme.surfaceCard,
                )
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : AppTheme.textTertiary,
              size: AppLayout.scaled(context, 20),
            ),
            SizedBox(width: AppLayout.scaled(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 15),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(width: AppLayout.scaled(context, 8)),
                      Text(
                        code,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          fontFamily: 'monospace',
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppLayout.scaled(context, 3)),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 绑定账户单选行:账户名 + 序号 + 短地址。
class _AccountRadio extends StatelessWidget {
  const _AccountRadio({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final CitizenWalletStateAccount account;
  final bool selected;
  final VoidCallback onTap;

  String get _shortAddress {
    final value = account.ss58Address;
    if (value.length <= 18) return value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.border;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : AppTheme.textTertiary,
              size: AppLayout.scaled(context, 20),
            ),
            SizedBox(width: AppLayout.scaled(context, 12)),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 14),
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: AppLayout.scaled(context, 8)),
                  Text(
                    '#${account.accountIndex}',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _shortAddress,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 11),
                fontFamily: 'monospace',
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 提交默认Cloudflare人验并只消费当次核验结果。

/// 默认Cloudflare核验；只确认当次通过，不创建任务、签发凭据或持久化令牌。
class RegistrationApi {
  RegistrationApi({http.Client? client})
    : _http = HttpsOnlyClient(client ?? http.Client());
  final http.Client _http;
  Future<void> verify(
    RegistrationContext context,
    RegistrationVerification verification,
  ) async {
    try {
      final response = await _http
          .post(
            Uri.parse('${context.baseUrl}/user/registration/verify'),
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode(verification.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw RegistrationException(
          response.statusCode == 403 ? '真人验证未通过，请重试' : '真人验证服务暂不可用，请重试',
          code: 'registration_http_${response.statusCode}',
        );
      }
      if (response.bodyBytes.length > 4096) {
        throw const FormatException('真人验证响应超限');
      }
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is! Map<String, dynamic> ||
          value.length != 1 ||
          value['is_ok'] != true) {
        throw const RegistrationException(
          '真人验证未通过',
          code: 'verification_failed',
        );
      }
    } on SocketException {
      throw const RegistrationException(
        '真人验证网络连接失败',
        code: 'network_unavailable',
      );
    } on TimeoutException {
      throw const RegistrationException(
        '真人验证请求超时',
        code: 'network_unavailable',
      );
    } on http.ClientException {
      throw const RegistrationException(
        '真人验证网络请求失败',
        code: 'network_unavailable',
      );
    }
  }

  static Uri pageUri() =>
      Uri.parse('${CitizenServeApiConfig.baseUrl}/user/registration/page');
  void close() => _http.close();
}

// 在人验通过后执行原注册交易并持久确认最终链结果。

/// 一次默认人验后执行原链注册，以持久化的链上最终结果收尾。
class RegistrationCoordinator {
  RegistrationCoordinator({RegistrationApi? api, RegistrationStore? store})
    : api = api ?? RegistrationApi(),
      store = store ?? RegistrationStore();
  final RegistrationApi api;
  final RegistrationStore store;
  Future<FinalizedRegistration>? _flight;
  String? _context;
  bool get isRegistering => _flight != null;
  Future<FinalizedRegistration> run({
    required RegistrationContext context,
    required Future<void> Function() requireCurrent,
    required Future<RegistrationVerification?> Function() showVerification,
    required Future<void> Function() requireAffordable,
    required Future<FinalizedRegistration?> Function() readFinalized,
    required Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    registerCid,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
  }) {
    if (_flight != null) {
      if (_context == context.recordKey) return _flight!;
      throw const RegistrationException('另一个账户正在注册，请完成后再切换');
    }
    _context = context.recordKey;
    late final Future<FinalizedRegistration> task;
    task =
        _run(
          context,
          requireCurrent,
          showVerification,
          requireAffordable,
          readFinalized,
          registerCid,
          canRetryChain,
        ).whenComplete(() {
          if (identical(_flight, task)) {
            _flight = null;
            _context = null;
          }
        });
    _flight = task;
    return task;
  }

  Future<FinalizedRegistration> _run(
    RegistrationContext context,
    Future<void> Function() guard,
    Future<RegistrationVerification?> Function() showPage,
    Future<void> Function() affordable,
    Future<FinalizedRegistration?> Function() readChain,
    Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    register,
    Future<bool> Function(Map<String, dynamic>?)? canRetry,
  ) async {
    await guard();
    var finalized = await readChain();
    await guard();
    var record = await store.read(context);
    await guard();
    if (finalized == null) {
      if (record?.finalized != null) {
        throw const RegistrationException(
          '已确认的链绑定发生变化，请核实账户',
          code: 'identityChanged',
        );
      }
      final checkpoint = record?.checkpoint;
      if (checkpoint != null &&
          !{
            'prepared',
            'cancelled_before_broadcast',
          }.contains(checkpoint['state']) &&
          !(await canRetry?.call(checkpoint) ?? false)) {
        throw const RegistrationException(
          '链交易结果尚未确认，不会重复签名注册',
          code: 'chain_pending',
        );
      }
      final verification = await showPage();
      await guard();
      if (verification == null) {
        throw const RegistrationException(
          '真人验证已取消',
          code: 'verification_cancelled',
        );
      }
      await api.verify(context, verification);
      await guard();
      await affordable();
      await guard();
      finalized = await readChain();
      await guard();
      if (finalized == null) {
        finalized = await register((checkpoint) async {
          await guard();
          final next = RegistrationRecord(
            context: context,
            checkpoint: Map.unmodifiable(checkpoint),
          );
          await store.save(record, next);
          record = next;
          await guard();
        });
        await guard();
      }
    }
    final binding = finalized.binding;
    binding.validate();
    if (binding.accountId != context.accountId ||
        binding.genesisHash != context.chainScope) {
      throw const RegistrationException(
        '链注册结果与所选账户或链不一致',
        code: 'identityChanged',
      );
    }
    final saved = record?.finalized;
    if (saved != null &&
        (saved.binding.cidNumber != binding.cidNumber ||
            saved.binding.accountId != binding.accountId ||
            saved.binding.genesisHash != binding.genesisHash ||
            saved.binding.bindRev != binding.bindRev)) {
      throw const RegistrationException('已确认的链绑定发生变化', code: 'identityChanged');
    }
    finalized = saved ?? finalized;
    if (saved == null) {
      final next = (record ?? RegistrationRecord(context: context)).next(
        finalized: finalized,
      );
      await store.save(record, next);
      record = next;
      await guard();
    }
    return finalized;
  }
}

// 定义注册选择、瞬时人验、广播阶段和最终链记录模型。

class RegistrationException implements Exception {
  const RegistrationException(
    this.message, {
    this.code = 'registration_unavailable',
  });
  final String message, code;
  @override
  String toString() => message;
}

/// 原SDK执行尚未开始，不能用此异常处理未知广播。
class RegistrationBeforeBroadcastException extends RegistrationException {
  const RegistrationBeforeBroadcastException()
    : super('注册交易尚未开始，可主动重试', code: 'before_broadcast');
}

void registrationFields(Map<String, dynamic> value, Set<String> fields) {
  if (value.length != fields.length || !value.keys.every(fields.contains)) {
    throw const FormatException('注册数据字段无效');
  }
}

String registrationText(Map<String, dynamic> value, String name) {
  final text = value[name];
  if (text is! String || text.isEmpty || text.length > 8192) {
    throw const FormatException('注册数据无效');
  }
  return text;
}

/// 当前选择账户及链；自然键只定位本机交易，不生成登记摘要或服务端任务。
class RegistrationContext {
  RegistrationContext({
    required this.accountId,
    required this.orgCode,
    required this.chainScope,
    String? baseUrl,
  }) : baseUrl = CitizenServeApiConfig.normalize(
         baseUrl ?? CitizenServeApiConfig.baseUrl,
       ) {
    if (!isCitizenAccountId(accountId) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(chainScope) ||
        !{'CTZN', 'NATP'}.contains(orgCode)) {
      throw const FormatException('注册账户或链无效');
    }
  }
  final String accountId, orgCode, chainScope, baseUrl;
  String get recordKey => jsonEncode([chainScope, accountId]);
  Map<String, Object> toRecord() => {
    'base_url': baseUrl,
    'chain_scope': chainScope,
    'account_id': accountId,
    'org_code': orgCode,
  };
  factory RegistrationContext.fromRecord(Map<String, dynamic> value) {
    registrationFields(value, {
      'base_url',
      'chain_scope',
      'account_id',
      'org_code',
    });
    return RegistrationContext(
      baseUrl: registrationText(value, 'base_url'),
      chainScope: registrationText(value, 'chain_scope'),
      accountId: registrationText(value, 'account_id'),
      orgCode: registrationText(value, 'org_code'),
    );
  }
}

/// Cloudflare本次挑战的瞬时结果；只供Siteverify，不进入任何存储或链结果报告。
class RegistrationVerification {
  RegistrationVerification({required this.checkId, required this.token}) {
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(checkId) ||
        token.isEmpty ||
        token.length > 2048 ||
        token.trim() != token) {
      throw const FormatException('真人验证结果无效');
    }
  }
  final String checkId, token;
  Map<String, Object> toJson() => {
    'check_id': checkId,
    'turnstile_token': token,
  };
}

/// 原SDK已确认的链结果；区块事实保留在本机，报告只发送绑定中的公民号和账户。
class FinalizedRegistration {
  const FinalizedRegistration({
    required this.binding,
    required this.blockHash,
    this.txHash,
  });
  final IdentityBinding binding;
  final String blockHash;
  final String? txHash;
  Map<String, Object?> toJson() => {
    'binding': binding.toJson(),
    'block_hash': blockHash,
    'tx_hash': txHash,
  };
  factory FinalizedRegistration.fromJson(Map<String, dynamic> value) {
    registrationFields(value, {'binding', 'block_hash', 'tx_hash'});
    final block = registrationText(value, 'block_hash'), tx = value['tx_hash'];
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(block) ||
        (tx != null &&
            (tx is! String || !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(tx))) ||
        value['binding'] is! Map<String, dynamic>) {
      throw const FormatException('链注册结果无效');
    }
    final binding = IdentityBinding.fromJson(jsonEncode(value['binding']));
    if (binding == null) throw const FormatException('链绑定无效');
    binding.validate();
    return FinalizedRegistration(
      binding: binding,
      blockHash: block,
      txHash: tx as String?,
    );
  }
}

/// 仅保存原链交易检查点和真实最终结果；不保存人验、服务端状态或恢复秘密。
class RegistrationRecord {
  const RegistrationRecord({
    required this.context,
    this.checkpoint,
    this.finalized,
  });
  final RegistrationContext context;
  final Map<String, dynamic>? checkpoint;
  final FinalizedRegistration? finalized;
  RegistrationRecord next({
    Map<String, dynamic>? checkpoint,
    FinalizedRegistration? finalized,
  }) => RegistrationRecord(
    context: context,
    checkpoint: checkpoint ?? this.checkpoint,
    finalized: finalized ?? this.finalized,
  );
  String encode() => jsonEncode({
    'context': context.toRecord(),
    'checkpoint': checkpoint,
    'finalized': finalized?.toJson(),
  });
  factory RegistrationRecord.decode(String text) {
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic>) throw const FormatException('链注册记录无效');
    registrationFields(raw, {'context', 'checkpoint', 'finalized'});
    if (raw['context'] is! Map<String, dynamic>) {
      throw const FormatException('链注册属主无效');
    }
    final context = RegistrationContext.fromRecord(
      raw['context'] as Map<String, dynamic>,
    );
    if (raw['finalized'] != null && raw['finalized'] is! Map<String, dynamic>) {
      throw const FormatException('链注册结果结构无效');
    }
    final finalized = raw['finalized'] == null
        ? null
        : FinalizedRegistration.fromJson(
            raw['finalized'] as Map<String, dynamic>,
          );
    if (finalized != null &&
        (finalized.binding.accountId != context.accountId ||
            finalized.binding.genesisHash != context.chainScope)) {
      throw const FormatException('链注册结果属主不一致');
    }
    final checkpoint = raw['checkpoint'];
    if (checkpoint != null) {
      const fields = {
        'preparation_id',
        'account_id',
        'call_data_hash',
        'state',
        'execution_id',
        'tx_hash',
      };
      if (checkpoint is! Map<String, dynamic> ||
          !checkpoint.keys.every(fields.contains) ||
          checkpoint.values.any((v) => v is! String || v.length > 200) ||
          checkpoint['account_id'] != context.accountId ||
          checkpoint['call_data_hash'] is! String ||
          !RegExp(r'^0x[0-9a-f]{64}$')
              .hasMatch(checkpoint['call_data_hash'] as String) ||
          !{
            'prepared',
            'executing',
            'awaiting_qr',
            'cancelled_before_broadcast',
            'finalizedSuccess',
            'finalizedFailed',
            'poolRejected',
          }.contains(checkpoint['state'])) {
        throw const FormatException('SDK链交易检查点无效');
      }
    }
    return RegistrationRecord(
      context: context,
      checkpoint: checkpoint as Map<String, dynamic>?,
      finalized: finalized,
    );
  }
}

// 承载默认Cloudflare核验页面并交付本次瞬时令牌。

/// 默认Cloudflare页面只交付本次瞬时令牌，服务端Siteverify通过前不允许注册。
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  static RegistrationVerification? verificationFromMessage(String message) {
    if (message.length > 4096) return null;
    try {
      final raw = jsonDecode(message);
      if (raw is! Map<String, dynamic> ||
          raw.length != 2 ||
          !raw.keys.every({'check_id', 'token'}.contains) ||
          raw['check_id'] is! String ||
          raw['token'] is! String) {
        return null;
      }
      return RegistrationVerification(
        checkId: raw['check_id'] as String,
        token: raw['token'] as String,
      );
    } on Object {
      return null;
    }
  }

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  late final WebViewController controller;
  bool returned = false;
  String? error;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Turnstile',
        onMessageReceived: (message) {
          final token = RegistrationPage.verificationFromMessage(
            message.message,
          );
          if (token != null && mounted && !returned) {
            returned = true;
            Navigator.of(context).pop(token);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              !request.isMainFrame ||
                  request.url == RegistrationApi.pageUri().toString()
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (event) {
            if (event.isForMainFrame == true && mounted) {
              setState(() => error = '验证页面加载失败，请返回后重试');
            }
          },
        ),
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.loadRequest(RegistrationApi.pageUri()).catchError((
          Object _,
        ) {
          if (mounted && !returned) setState(() => error = '验证页面加载失败，请返回后重试');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('注册安全验证')),
    body: SafeArea(
      child: error == null
          ? WebViewWidget(controller: controller)
          : Center(child: Text(error!)),
    ),
  );
}

// 通过受保护原子通道保存真实注册交易事实。

/// 原子保存真实链交易事实；复用原保护通道，不处理任何服务端登记能力。
class RegistrationStore {
  RegistrationStore({SystemProtectedRecordStore? records})
    : _records = records ?? SystemProtectedRecordStore.registration;
  final SystemProtectedRecordStore _records;
  Future<RegistrationRecord?> read(RegistrationContext context) async {
    final raw = await _records.read(context.recordKey);
    if (raw == null) return null;
    final record = RegistrationRecord.decode(raw);
    if (record.context.recordKey != context.recordKey) {
      throw StateError('链交易记录归属不一致');
    }
    return record;
  }

  Future<void> save(
    RegistrationRecord? previous,
    RegistrationRecord next,
  ) async {
    if (previous != null &&
        previous.context.recordKey != next.context.recordKey) {
      throw StateError('链交易记录不可换属主');
    }
    final value = next.encode();
    RegistrationRecord.decode(value);
    if (!await _records.compareAndSet(
          next.context.recordKey,
          expected: previous?.encode(),
          next: value,
        ) ||
        await _records.read(next.context.recordKey) != value) {
      throw StateError('链交易检查点未保存');
    }
  }
}
