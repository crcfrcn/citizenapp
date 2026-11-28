// 账户详情与添加账户弹窗。

import 'package:citizen_topup/store.dart';
import 'package:citizen_storage/user.dart' as wallet_store show Entry;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/log.dart';
import 'package:citizen_system/security/access.dart';
import 'package:citizen_wallet/history/store.dart' show LocalTxStore;
import 'package:citizen_wallet/history/service.dart' show TxAutoRefreshMixin;
import 'package:citizen_system/theme.dart';
import 'package:citizen_wallet/account/card.dart' show WalletActionCard, WalletActionCardState;
import 'package:citizen_wallet/account/card.dart' show WalletDetailBody;
import 'package:flutter/services.dart';
import 'package:citizen_wallet/onboarding/input.dart' show WalletPasswordField, validateWalletPasswordInput;
import 'package:citizen_wallet/onboarding/input.dart' show Bip39InputField;

// 展示账户详情并通过SDK受控资源查看和清理私钥。

/// 两个钱包入口共用私钥显示，真实认证、撤销和字节清零由 SDK 资源负责。
mixin WalletPrivateDisplay<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  bool _screenshotGuardActive = false;
  bool _privateOpening = false;
  bool _privateRevoked = false;
  CitizenSdkPrivateKey? _privateKeyResource;
  DialogRoute<void>? _privateKeyRoute;
  VoidCallback? _clearPrivateText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _privateRevoked = true;
    // 页面销毁期间不重入 Navigator，只移除本次敏感窗口。
    scheduleMicrotask(_dismissPrivateDisplay);
    final resource = _privateKeyResource;
    if (resource != null) unawaited(resource.close().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> revealPrivateKey(String accountId, {bool wallet = false}) async {
    if (_privateOpening || _privateKeyResource != null || !mounted) return;
    _privateOpening = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('查看私钥'),
        content: Text(
          wallet
              ? '私钥是核心机密信息，泄露将导致资产被盗。\n\n确认要查看吗？'
              : '私钥泄露将导致该账户资产被盗（仅该账户，不影响本钱包其他账户）。\n\n确认要查看吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('查看'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      _privateOpening = false;
      return;
    }
    _privateRevoked = false;
    CitizenSdkPrivateKey? resource;
    String? key;
    try {
      resource = await context.read<CitizenSdk>().openPrivateKey(accountId);
      final owned = resource;
      _privateKeyResource = owned;
      _clearPrivateText = () {
        key = null;
      };
      unawaited(
        owned.closed.then<void>((_) {
          if (identical(_privateKeyResource, owned)) {
            _privateRevoked = true;
            _dismissPrivateDisplay();
            unawaited(_releasePrivateGuard());
            _privateKeyResource = null;
          }
        }),
      );
      if (!mounted) return;
      if (!_screenshotGuardActive) {
        _screenshotGuardActive = true;
        await ScreenshotGuard.enable();
        if (!mounted) return;
      }
      if (_privateRevoked) return;
      final bytes = await resource.reveal();
      if (!mounted || _privateRevoked) return;
      // 这里只做原私钥文本的十六进制呈现，不派生、签名或持久化。
      key =
          '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
      final navigator = Navigator.of(context, rootNavigator: true);
      final dialog = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        builder: (dialogContext) => AlertDialog(
          title: const Text('私钥'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppLayout.scaledValue(14)),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.danger.withAlpha(40)),
                ),
                // 普通 Text 不提供选择/复制菜单，避免私钥进入剪贴板。
                child: Text(
                  key ?? '',
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(13),
                    fontFamily: 'monospace',
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: AppLayout.scaledValue(10)),
              Text(
                '请手抄备份，不支持复制；导出即等于该账户控制权',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontSize: AppLayout.scaledValue(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      _privateKeyRoute = dialog;
      await navigator.push(dialog);
      await dialog.completed;
    } on CitizenSdkException catch (e) {
      if (!mounted ||
          _privateRevoked ||
          e.code == CitizenSdkErrorCode.cancelled) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('验证失败：${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('验证失败：$e')));
    } finally {
      _dismissPrivateDisplay();
      key = null;
      _clearPrivateText = null;
      var drained = false;
      try {
        await resource?.close();
        drained = true;
        await _releasePrivateGuard();
      } finally {
        // 控制调用失败时仍保留终态回调的归属，真实排空后才能归还隐私保护引用。
        if (drained && identical(_privateKeyResource, resource)) {
          _privateKeyResource = null;
        }
        _privateOpening = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // OS认证尚未交付秘密时允许其临时失焦；已显示的私钥或真正后台必须关闭。
    if (state == AppLifecycleState.resumed) return;
    if (state == AppLifecycleState.inactive && _privateKeyRoute == null) return;
    _privateRevoked = true;
    _dismissPrivateDisplay();
    final resource = _privateKeyResource;
    if (resource != null) unawaited(resource.close().catchError((Object _) {}));
  }

  void _dismissPrivateDisplay() {
    final route = _privateKeyRoute;
    _privateKeyRoute = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
    _clearPrivateText?.call();
  }

  Future<void> _releasePrivateGuard() async {
    if (_screenshotGuardActive) {
      _screenshotGuardActive = false;
      await ScreenshotGuard.disable();
    }
  }
}

/// 账户详情（Lv3）：单个 `//index` 账户 = 单钱包多账户下「以前的钱包详情」。
///
/// 承载该账户的全部钱包功能，一律按 `account_id` 键控：
/// - USDT充值 / USDC充值 / 零钱包（[WalletActionCard]，链下清算行零钱包按账户独立绑定）；
/// - 清算行菜单当前只显示“暂未上线，敬请期待”，不进入尚未完成的设置页；
/// - 交易记录（[TransactionHistoryPage]，按账户 `account_id` 查询）；
/// - 顶部完整 SS58 地址与该账户的账户码（`k=5`，只声明账户；身份码在用户主页）；
/// - AppBar 菜单保留原私钥警告与显示框；SDK负责真实认证与短时资源，页面只呈现。
///
/// 追加账户不在本页：收在「我的钱包」列表右上角「＋」的「添加下一个账户 / 添加指定账户」。
class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.account});

  final CitizenWalletStateAccount account;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage>
    with
        TxAutoRefreshMixin<AccountDetailPage>,
        WidgetsBindingObserver,
        WalletPrivateDisplay<AccountDetailPage> {
  /// 双币充值/零钱包动作卡:下拉刷新时通过此 key 触发清算行余额重查。
  final GlobalKey<WalletActionCardState> _actionCardKey =
      GlobalKey<WalletActionCardState>();

  /// 该账户最近交易记录(最多 5 条),按 `account_id` 查询。
  List<wallet_store.Entry> _recentRecords = const [];

  @override
  void initState() {
    super.initState();
    // 初始化加载最近交易记录；之后由 SDK history/finalized 业务投影触发响应式重刷。
    // (不重复启动监听、不劫持全局回调)。
    _loadRecentRecords();
    startTxAutoRefresh(widget.account.accountId);
  }

  @override
  Future<void> onTxRecordsChanged() => _loadRecentRecords();

  @override
  void dispose() {
    unawaited(
      stopTxAutoRefresh().catchError((Object error, StackTrace stackTrace) {
        AppLog.d('[Wallet] 账户详情 watcher 停止失败: $error\n$stackTrace');
      }),
    );
    super.dispose();
  }

  @override
  void onTopupRecordChanged(TopupChange change) {
    setState(() => _recentRecords = change.apply(_recentRecords, limit: 5));
  }

  Future<void> _loadRecentRecords() async {
    try {
      final records = await LocalTxStore.queryRecentByAccountId(
        widget.account.accountId,
        limit: 5,
      );
      if (!mounted) return;
      setState(() => _recentRecords = records);
    } catch (_) {
      // 加载失败静默忽略,账户详情其余功能不受影响。
    }
  }

  /// 下拉刷新:清算行余额卡 + 最近交易记录。
  Future<void> _onPullRefresh() async {
    await Future.wait<void>([
      Future(() async {
        try {
          if (!mounted) return;
          await context.read<CitizenSdk>().getAccountBalance(
            widget.account.accountId,
          );
        } catch (_) {}
      }),
      Future(() async {
        try {
          await _actionCardKey.currentState?.refresh();
        } catch (_) {
          // 清算行节点可能暂不可达,动作卡内部会展示节点不可达。
        }
      }),
      refreshTxHistory(),
    ]);
  }

  /// 清算行设置尚未上线；入口保留产品位置，但不得进入未完成页面。
  void _showClearingBankUnavailable() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('暂未上线，敬请期待')));
  }

  Future<void> _onMenuAction(String action) async {
    switch (action) {
      case 'clearing_bank':
        _showClearingBankUnavailable();
      case 'private_key':
        await revealPrivateKey(widget.account.accountId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    // 普通详情页交给路由自身处理返回，保留 iOS 左边缘交互式返回手势。
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户详情'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: '账户操作',
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clearing_bank',
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: AppLayout.scaled(context, 18),
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: AppLayout.scaled(context, 10)),
                    const Text('清算行'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'private_key',
                child: Row(
                  children: [
                    Icon(
                      Icons.key_outlined,
                      size: AppLayout.scaled(context, 18),
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: AppLayout.scaled(context, 10)),
                    const Text('查看私钥'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: WalletDetailBody(
        account: account,
        name: account.name,
        onRefresh: _onPullRefresh,
        actionKey: _actionCardKey,
        records: _recentRecords,
      ),
    );
  }
}

// 采集下一个或指定派生序号，调用SDK批量追加账户。

/// 「添加账户」两模式：下一个序号 / 指定序号。
enum AddAccountMode { next, specify }

/// 弹出「添加账户」底部面板；成功追加返回 `true`，否则返回 `null`。
///
/// [mode] 固定本次添加口径：`next`=添加下一个账户；`specify`=添加指定账户。
/// 由「添加账户」底部菜单指定序号模式与签名方式，面板内不再切换。
Future<bool?> showAddAccountSheet(
  BuildContext context, {
  required String masterId,
  required AddAccountMode mode,
  CitizenAccountDerivation? derivation,
  CitizenSdkOperation<CitizenWalletProfile> Function({
    required String mnemonic,
    String password,
    CitizenAccountDerivation? derivation,
  })?
  addNextAccount,
  CitizenSdkOperation<CitizenWalletProfile> Function({
    required String mnemonic,
    String password,
    CitizenAccountDerivation? derivation,
    required List<int> indices,
  })?
  addAccounts,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddAccountSheet(
      masterId: masterId,
      mode: mode,
      derivation: derivation,
      addNextAccount: addNextAccount,
      addAccounts: addAccounts,
    ),
  );
}

/// 无根多账户追加面板：录入本钱包助记词与可选 password →（按固定 [mode]）添加账户。
///
/// 无根设备不保存助记词或 password，追加账户须重新录入；[CitizenSdk.addAccounts]
/// SDK在真实操作门内核对输入归属当前唯一热钱包；[masterId]只标识原面板的展示上下文。
class AddAccountSheet extends StatefulWidget {
  const AddAccountSheet({
    super.key,
    required this.masterId,
    required this.mode,
    this.derivation,
    this.addNextAccount,
    this.addAccounts,
  });

  final CitizenSdkOperation<CitizenWalletProfile> Function({
    required String mnemonic,
    String password,
    CitizenAccountDerivation? derivation,
  })?
  addNextAccount;
  final CitizenSdkOperation<CitizenWalletProfile> Function({
    required String mnemonic,
    String password,
    CitizenAccountDerivation? derivation,
    required List<int> indices,
  })?
  addAccounts;

  final String masterId;
  final CitizenAccountDerivation? derivation;

  /// 固定的添加模式，由底部菜单指定，面板内不再切换。
  final AddAccountMode mode;

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  CitizenSdk get _wallet => context.read<CitizenSdk>();
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _indexController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;
  CitizenSdkOperation<CitizenWalletProfile>? _operation;

  @override
  void initState() {
    super.initState();
    // 面板承载助记词与可选钱包密码，整个显示周期都禁止截屏和录屏。
    unawaited(ScreenshotGuard.enable());
  }

  @override
  void dispose() {
    final operation = _operation;
    if (operation != null) {
      unawaited(
        operation.cancel().then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
    unawaited(ScreenshotGuard.disable());
    _mnemonicController.clear();
    _indexController.clear();
    _passwordController.clear();
    _mnemonicController.dispose();
    _indexController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _describeError(Object error) {
    // 展示稳定中文类别，不把原生金库描述或调用细节直接交给用户。
    if (error is CitizenSdkException) {
      return switch (error.code) {
        CitizenSdkErrorCode.keyInvalidated => '钱包安全密钥不可用，无法添加账户',
        CitizenSdkErrorCode.authenticationCancelled ||
        CitizenSdkErrorCode.cancelled => '已取消添加账户',
        CitizenSdkErrorCode.authenticationRequired =>
          '请完成设备认证，并确认助记词和钱包密码属于当前钱包',
        CitizenSdkErrorCode.invalidArgument => '请检查助记词、钱包密码和账户序号',
        CitizenSdkErrorCode.conflict => '钱包状态已变化，请重新打开添加账户',
        CitizenSdkErrorCode.busy => '钱包正在处理其他操作，请稍后重试',
        CitizenSdkErrorCode.storage => '账户保存失败，请重试',
        _ => '添加账户失败，请重试',
      };
    }
    return '添加账户失败，请重试';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final mnemonic = _mnemonicController.text;
      final password = _passwordController.text;
      await validateWalletPasswordInput(context, password);
      if (!mounted) return;
      if (widget.mode == AddAccountMode.next) {
        final operation = (widget.addNextAccount ?? _wallet.addNextAccount)(
          mnemonic: mnemonic,
          password: password,
          derivation: widget.derivation,
        );
        _operation = operation;
        await operation.result;
      } else {
        final parsed = CitizenWalletAccountIndices.parse(_indexController.text);
        if (parsed.indices == null || parsed.indices!.isEmpty) {
          setState(
            () => _error = parsed.invalidToken == null
                ? '请输入至少一个账户序号'
                : '序号必须是数字：${parsed.invalidToken}',
          );
          return;
        }
        final operation = (widget.addAccounts ?? _wallet.addAccounts)(
          mnemonic: mnemonic,
          indices: parsed.indices!,
          password: password,
          derivation: widget.derivation,
        );
        _operation = operation;
        await operation.result;
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _describeError(e));
    } finally {
      _operation = null;
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final accountType = switch (widget.derivation ??
        CitizenSdk.defaultAccountDerivation) {
      CitizenAccountDerivation.sr25519 => '经典账户',
      CitizenAccountDerivation.mldsa65 => '量子账户',
    };
    return SafeArea(
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
                    bottom: AppLayout.scaled(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(2),
                    ),
                  ),
                ),
              ),
              Text(
                widget.mode == AddAccountMode.next
                    ? '添加下一个$accountType'
                    : '添加指定$accountType',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 17),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 6)),
              Text(
                '无根设备不保存助记词或密码，追加账户需重新录入两者校验归属。',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 12)),
              Bip39InputField(controller: _mnemonicController, wordCount: 0),
              SizedBox(height: AppLayout.scaled(context, 12)),
              WalletPasswordField(controller: _passwordController),
              SizedBox(height: AppLayout.scaled(context, 16)),
              if (widget.mode == AddAccountMode.next)
                Text(
                  '按所选签名方式派生下一个账户',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 12),
                    color: AppTheme.textSecondary,
                  ),
                )
              else
                TextField(
                  controller: _indexController,
                  // 多个编号用空格分隔；纯数字键盘没有空格键，必须使用文本键盘。
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: '账户序号',
                    hintText: '空格分隔，如 1 5 9',
                    helperText:
                        '连续或断续均可，范围 1–${CitizenWalletProfile.maxAccountIndex}',
                    border: OutlineInputBorder(),
                  ),
                ),
              if (_error != null) ...[
                SizedBox(height: AppLayout.scaled(context, 12)),
                Text(
                  _error!,
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontSize: AppLayout.scaled(context, 13),
                  ),
                ),
              ],
              SizedBox(height: AppLayout.scaled(context, 16)),
              SizedBox(
                width: double.infinity,
                height: AppLayout.scaled(context, 46),
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? '添加中…' : '确认添加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
