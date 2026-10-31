import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_system/security/screenshot_guard.dart';
import 'package:citizen_transaction/history/local_tx_store.dart';
import 'package:citizen_transaction/history/tx_auto_refresh_mixin.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_wallet/wallet_action_card.dart';
import 'package:citizen_wallet/wallet_identity_card.dart';
import 'package:citizen_wallet/wallet_onchain_balance_card.dart';
import 'package:citizen_system/theme/app_layout.dart';

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
    with TxAutoRefreshMixin<AccountDetailPage>, WidgetsBindingObserver {
  bool _screenshotGuardActive = false;
  bool _privateOpening = false;
  bool _privateRevoked = false;
  CitizenSdkPrivateKey? _privateKeyResource;
  DialogRoute<void>? _privateKeyRoute;
  VoidCallback? _clearPrivateText;

  /// 双币充值/零钱包动作卡:下拉刷新时通过此 key 触发清算行余额重查。
  final GlobalKey<WalletActionCardState> _actionCardKey =
      GlobalKey<WalletActionCardState>();

  final GlobalKey<WalletOnchainBalanceCardState> _balanceCardKey =
      GlobalKey<WalletOnchainBalanceCardState>();

  /// 该账户最近交易记录(最多 5 条),按 `account_id` 查询。
  List<wallet_store.Entry> _recentRecords = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 初始化加载最近交易记录；之后由 SDK history/finalized 业务投影触发响应式重刷。
    // (不重复启动监听、不劫持全局回调)。
    _loadRecentRecords();
    startTxAutoRefresh(widget.account.accountId);
  }

  @override
  Future<void> onTxRecordsChanged() => _loadRecentRecords();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _privateRevoked = true;
    // Navigator自身销毁页面时不能重入其锁；本轮微任务移除准确敏感route，不弹出其它页面。
    scheduleMicrotask(_dismissPrivateDisplay);
    final resource = _privateKeyResource;
    if (resource != null) unawaited(resource.close().catchError((Object _) {}));
    unawaited(
      stopTxAutoRefresh().catchError((Object error, StackTrace stackTrace) {
        AppLog.d('[Wallet] 账户详情 watcher 停止失败: $error\n$stackTrace');
      }),
    );
    super.dispose();
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
          await _balanceCardKey.currentState?.refresh();
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

  Future<void> _revealPrivateKey() async {
    if (_privateOpening || _privateKeyResource != null || !mounted) return;
    _privateOpening = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('查看私钥'),
        content: const Text('私钥泄露将导致该账户资产被盗（仅该账户，不影响本钱包其他账户）。\n\n确认要查看吗？'),
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
      resource = await context.read<CitizenSdk>().openPrivateKey(
        widget.account.accountId,
      );
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
                  key!,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('验证失败：${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('验证失败：$e')));
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

  /// 清算行设置尚未上线；入口保留产品位置，但不得进入未完成页面。
  void _showClearingBankUnavailable() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('暂未上线，敬请期待')));
  }

  Future<void> _onMenuAction(String action) async {
    switch (action) {
      case 'clearing_bank':
        _showClearingBankUnavailable();
      case 'private_key':
        await _revealPrivateKey();
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
        onNameChanged: _saveAccountName,
        onRefresh: _onPullRefresh,
        balanceKey: _balanceCardKey,
        actionKey: _actionCardKey,
        records: _recentRecords,
      ),
    );
  }

  /// 当前账户名称由SDK保存并回读；不会更改钱包级名称、默认账户或公开昵称。
  Future<void> _saveAccountName(String name) async {
    final accountId = widget.account.accountId;
    try {
      final state = await context
          .read<CitizenSdk>()
          .renameAccount(accountId: accountId, name: name)
          .result;
      if (!state.accounts.any(
        (a) => a.accountId == accountId && a.name == name,
      )) {
        throw StateError('账户名称保存回读未确认');
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('账户名称保存失败，请重试')));
      }
      rethrow;
    }
  }
}
