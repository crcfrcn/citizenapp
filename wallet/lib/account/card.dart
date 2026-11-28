// 身份、操作卡片及账户二维码。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:citizen_storage/user.dart' as wallet_store show Entry;
import 'package:citizen_wallet/history/item.dart' show LocalTxRecordTile;
import 'package:citizen_wallet/view.dart' show WalletNavigation;
import 'package:citizen_wallet/view.dart' show WalletOnchainBalanceCard;
import 'package:citizen_system/theme.dart';
import 'package:citizen_offchain/rpc.dart' show ClearingBalance, ClearingBalances;
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:citizen_offchain/bank.dart' show ClearingBankBinding, ClearingBankDirectory;
import 'package:citizen_scanner/display.dart' show AppQrImage;

// 展示冷热钱包身份、地址、账户码及最近交易记录。

/// 冷热详情唯一展示布局；名称仅展示，余额刷新与私钥权限仍由原页面负责。
class WalletDetailBody extends StatelessWidget {
  const WalletDetailBody({
    super.key,
    required this.account,
    required this.name,
    required this.onRefresh,
    required this.actionKey,
    required this.records,
    this.balanceLoader,
  });
  final CitizenWalletStateAccount account;
  final String name;
  final Future<void> Function() onRefresh;
  final GlobalKey<WalletActionCardState> actionKey;
  final List<wallet_store.Entry> records;
  final Future<CitizenAccountBalance> Function(String)? balanceLoader;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          key: const ValueKey('wallet-detail-header'),
          color: AppTheme.primary,
          child: Column(
            children: [
              WalletIdentityCard(
                key: ValueKey(account.accountId),
                wallet: account,
                name: name,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaled(context, 20),
                ),
                child: Divider(height: 1, color: Colors.white.withAlpha(55)),
              ),
              WalletOnchainBalanceCard(
                wallet: account,
                balanceLoader: balanceLoader,
              ),
            ],
          ),
        ),
        WalletActionCard(key: actionKey, accountId: account.accountId),
        SizedBox(height: AppLayout.scaled(context, 24)),
        Padding(
          key: const ValueKey('wallet-transaction-section-padding'),
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 4),
          ),
          child: Container(
            key: const ValueKey('wallet-recent-records-card'),
            clipBehavior: Clip.antiAlias,
            decoration: AppTheme.cardDecoration(radius: AppTheme.radiusMd),
            child: Column(children: _recordRows(context)),
          ),
        ),
        SizedBox(height: AppLayout.scaled(context, 24)),
      ],
    ),
  );

  /// 交易记录区块:标题跳转 + 最近 5 条列表。
  List<Widget> _recordRows(BuildContext context) {
    return [
      InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => context.read<WalletNavigation>().history(
                accountAddress: account.ss58Address,
                accountId: account.accountId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Text(
                '交易记录',
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: AppLayout.scaledValue(20),
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
      const Divider(height: 1),
      if (records.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppLayout.scaledValue(36)),
          child: const Center(
            child: Text(
              '暂无交易记录',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
        )
      else
        ...List.generate(records.length, (index) {
          final record = records[index];
          return Column(
            children: [
              // 标题行进入完整列表；单条最近记录直接进入该笔交易详情。
              LocalTxRecordTile(
                record: record,
                showChevron: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => context
                          .read<WalletNavigation>()
                          .recordDetail(record: record),
                    ),
                  );
                },
              ),
              if (index < records.length - 1) const Divider(height: 1),
            ],
          );
        }),
    ];
  }
}

/// 钱包详情页主视觉中的身份区。
///
/// - 与 [WalletOnchainBalanceCard] 共用外层纯色主视觉面板，本组件只负责身份内容。
/// - 名称仅展示；重命名统一由“我的钱包”列表菜单处理。
/// - 地址完整展示，空间不足时从第二行左对齐换行；复制按钮独立位于分隔线左侧。
/// - 右侧 QR 入口打开账户二维码弹窗，内容为 QR_V1 `k=5` 账户码（只声明账户）。
///   身份码(`k=3` 用户码)只在用户主页出示,本卡不做「该出哪种码」的运行时判断。
class WalletIdentityCard extends StatefulWidget {
  const WalletIdentityCard({
    super.key,
    required this.wallet,
    required this.name,
    this.evmAddressLoader,
  });

  final CitizenWalletStateAccount wallet;

  /// Defaults to the SDK finalized receive-address check.
  final Future<String> Function(String accountId)? evmAddressLoader;

  /// 仅展示调用方提供的名称，不提供详情页改名入口。
  final String name;

  @override
  State<WalletIdentityCard> createState() => _WalletIdentityCardState();
}

class _WalletIdentityCardState extends State<WalletIdentityCard> {
  bool _copyDialogOpen = false;

  /// One copy entry opens both address forms; only a confirmed EVM alias is copied.
  Future<void> _copyAddress() async {
    if (_copyDialogOpen) return;
    _copyDialogOpen = true;
    try {
      final accountId = widget.wallet.accountId;
      final ss58Address = widget.wallet.ss58Address;
      final ethereum = citizenEvmAddressFromAccountId(accountId);
      final loader =
          widget.evmAddressLoader ??
          context.read<CitizenSdk>().getEvmReceiveAddress;
      // Attach failure handling immediately: the route can build after an
      // already-completed read, and dismissing it must not leak a future error.
      final ready = Future<String>.sync(() => loader(accountId)).then<String?>(
        (value) => value == ethereum ? value : null,
        onError: (Object _, StackTrace stack) => null,
      );
      var copying = false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => FutureBuilder<String?>(
          future: ready,
          builder: (context, snapshot) {
            Future<void> copy(String value) async {
              if (copying) return;
              copying = true;
              try {
                await Clipboard.setData(ClipboardData(text: value));
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(const SnackBar(content: Text('地址已复制')));
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(const SnackBar(content: Text('复制失败，请重试')));
                }
              } finally {
                copying = false;
              }
            }

            return AlertDialog(
              key: const ValueKey('wallet-address-copy-dialog'),
              title: const Text('复制'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('公民链地址'),
                    Text(
                      ss58Address,
                      key: const ValueKey('wallet-copy-ss58-address'),
                    ),
                    const SizedBox(height: 16),
                    const Text('以太坊地址'),
                    Text(
                      ethereum,
                      key: const ValueKey('wallet-copy-evm-address'),
                    ),
                    if (snapshot.connectionState == ConnectionState.done &&
                        !snapshot.hasData)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('以太坊地址尚未确认，请稍后重试'),
                      )
                    else if (!snapshot.hasData)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('正在确认以太坊收款地址…'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('wallet-copy-ss58-button'),
                  onPressed: () => copy(ss58Address),
                  child: const Text('公民链地址'),
                ),
                TextButton(
                  key: const ValueKey('wallet-copy-evm-button'),
                  onPressed: snapshot.hasData
                      ? () => copy(snapshot.data!)
                      : null,
                  child: const Text('以太坊地址'),
                ),
              ],
            );
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地址读取失败，请稍后重试')));
      }
    } finally {
      _copyDialogOpen = false;
    }
  }

  /// 按最终设计稿把完整地址拆成两行：
  /// 第一行预留复制按钮槽位，第二行使用全部可用宽度并保持左对齐。
  ({String firstLine, String secondLine}) _splitAddressForTwoLines(
    double availableWidth,
    TextStyle style,
  ) {
    final address = widget.wallet.ss58Address;
    const copySlotWidth = 36.0;

    bool fits(String text, double width) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return painter.width <= width;
    }

    if (fits(address, availableWidth - copySlotWidth)) {
      return (firstLine: address, secondLine: '');
    }

    var splitAt = 1;
    for (var split = 1; split < address.length; split += 1) {
      if (fits(address.substring(0, split), availableWidth - copySlotWidth)) {
        // 第一行必须尽量排满，第二行只承接第一行确实放不下的剩余地址。
        splitAt = split;
      } else {
        break;
      }
    }

    return (
      firstLine: address.substring(0, splitAt),
      secondLine: address.substring(splitAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('wallet-identity-section'),
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 20),
        vertical: AppLayout.scaled(context, 12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧不放钱包装饰图标，账户信息直接与主视觉的左边距对齐。
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: AppLayout.scaled(context, 44),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 18),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: AppLayout.compactLineHeight,
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    height: AppLayout.scaled(context, 44),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final addressStyle = TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          height: 1.35,
                          color: Colors.white.withAlpha(190),
                          fontFamily: 'monospace',
                        );
                        final lines = _splitAddressForTwoLines(
                          constraints.maxWidth,
                          addressStyle,
                        );
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                                onTap: _copyAddress,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: AppLayout.scaled(context, 36),
                              top: 0,
                              height: AppLayout.scaled(context, 28),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  lines.firstLine,
                                  key: const ValueKey(
                                    'wallet-identity-address-line-1',
                                  ),
                                  maxLines: 1,
                                  textAlign: TextAlign.left,
                                  style: addressStyle,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: AppLayout.scaled(context, 22),
                              height: AppLayout.scaled(context, 22),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  lines.secondLine,
                                  key: const ValueKey(
                                    'wallet-identity-address-line-2',
                                  ),
                                  maxLines: 1,
                                  textAlign: TextAlign.left,
                                  style: addressStyle,
                                ),
                              ),
                            ),
                            Positioned(
                              // 向左校准 1.25 逻辑像素，使原子图形的可见右缘与
                              // 二维码原子图形的可见左缘到分隔线完全等距。
                              right: AppLayout.scaled(context, 1.25),
                              top: 0,
                              child: Semantics(
                                key: const ValueKey(
                                  'wallet-identity-copy-button',
                                ),
                                button: true,
                                label: '复制钱包地址',
                                child: Tooltip(
                                  message: '复制钱包地址',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                      onTap: _copyAddress,
                                      child: SizedBox(
                                        width: AppLayout.scaled(context, 28),
                                        height: AppLayout.scaled(context, 28),
                                        child: Transform.translate(
                                          // 最终确认稿只下移可见图标，不改变原子形状、
                                          // 点击热区、横向位置或与竖线的视觉等距。
                                          offset: Offset(
                                            0,
                                            AppLayout.scaled(context, 4),
                                          ),
                                          child: Icon(
                                            Icons.copy_outlined,
                                            key: const ValueKey(
                                              'wallet-identity-copy-icon',
                                            ),
                                            size: AppLayout.scaled(context, 12),
                                            color: Colors.white.withAlpha(210),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 按真机可见图形边缘校准：复制图标到竖线与竖线到二维码图标等距。
          SizedBox(width: AppLayout.scaled(context, 20)),
          // 方案 2 明确使用竖线分开账户信息和二维码入口。
          Container(
            key: const ValueKey('wallet-identity-qr-divider'),
            width: 1,
            height: AppLayout.scaled(context, 48),
            color: Colors.white.withAlpha(55),
          ),
          SizedBox(width: AppLayout.scaled(context, 16)),
          // 右：冷热钱包共用二维码弹窗，48×48 满足点击目标。
          Material(
            key: const ValueKey('wallet-identity-qr-button'),
            // 最终确认稿删除二维码白色底，只保留透明点击热区和白色原子图标。
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              onTap: () => showWalletQrDialog(
                context,
                accountId: widget.wallet.accountId,
                accountName: widget.name,
              ),
              child: SizedBox(
                width: AppLayout.scaled(context, 48),
                height: AppLayout.scaled(context, 48),
                child: Icon(
                  Icons.qr_code_rounded,
                  key: const ValueKey('wallet-identity-qr-icon'),
                  color: Colors.white,
                  size: AppLayout.scaled(context, 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 为准确冷热账户提供双币充值和清算零钱包入口。

/// 冷热账户共用双币充值与零钱包入口，余额和目标始终绑定精确account_id。
/// USDT/USDC都直接打开套餐弹窗；零钱包仍使用原清算行绑定与余额查询。
class WalletActionCard extends StatefulWidget {
  const WalletActionCard({super.key, required this.accountId});

  /// 该账户链账户主键(0x+64hex):充值目标、清算行绑定查询、按账户签名均以它为准。
  final String accountId;

  @override
  State<WalletActionCard> createState() => WalletActionCardState();
}

class WalletActionCardState extends State<WalletActionCard> {
  bool _bindingLoaded = false;
  bool _bindingFailed = false;
  bool _pettyOpening = false;
  int _bindingRead = 0;
  bool _topupOpening = false;
  ClearingBalance? _clearing;

  String get _balanceText {
    if (!_bindingLoaded) return '读取中';
    if (_bindingFailed) return '绑定待核对';
    if (_clearing == null) return '未绑定';
    final value = _clearing?.value;
    if (value != null) {
      return '${formatFen(value)} 元';
    }
    return _clearing?.hasError == true ? '节点不可达' : '读取中';
  }

  @override
  void initState() {
    super.initState();
    unawaited(refresh(forceRefresh: false));
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _unbind() {
    _clearing?.removeListener(_changed);
    _clearing = null;
  }

  @override
  void didUpdateWidget(covariant WalletActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _unbind();
      _bindingLoaded = false;
      _bindingFailed = false;
      unawaited(refresh(forceRefresh: false));
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  ClearingBankDirectory _directory() =>
      context.read<ClearingBankDirectory?>() ??
      ClearingBankDirectory(chain: context.read<CitizenSdk>());

  Future<void> refresh({bool forceRefresh = true}) async {
    final accountId = widget.accountId;
    final read = ++_bindingRead;
    ClearingBankBinding? bank;
    var failed = false;
    try {
      bank = await _directory().fetchUserBank(accountId);
    } catch (_) {
      failed = true;
    }
    if (!mounted || read != _bindingRead || widget.accountId != accountId) {
      return;
    }
    _unbind();
    final balance = bank == null
        ? null
        : ClearingBalances.instance.state(
            accountId: accountId,
            wssUrl: bank.endpoint.wssUrl,
          );
    _clearing = balance;
    balance?.addListener(_changed);
    setState(() {
      _bindingLoaded = true;
      _bindingFailed = failed;
    });
    await balance?.load(forceRefresh: forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet-action-card'),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      padding: EdgeInsets.symmetric(
        vertical: AppLayout.scaled(context, 20),
        horizontal: AppLayout.scaled(context, 12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _RechargeAction(
              token: 'USDT',
              onTap: () => _openTopup(context, 'USDT'),
            ),
          ),
          const _ActionDivider(lineKey: ValueKey('wallet-topup-divider')),
          Expanded(
            child: _RechargeAction(
              token: 'USDC',
              onTap: () => _openTopup(context, 'USDC'),
            ),
          ),
          const _ActionDivider(lineKey: ValueKey('wallet-petty-divider')),
          Expanded(
            child: _BalanceAction(
              balanceText: _balanceText,
              onTap: () => _openPettyWallet(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTopup(BuildContext context, String token) async {
    if (_topupOpening) return;
    _topupOpening = true;
    final account = widget.accountId;
    try {
      await context.read<WalletNavigation>().topup(
        context,
        accountId: account,
        token: token,
      );
    } finally {
      _topupOpening = false;
    }
  }

  /// 打开零钱包前重新核对绑定，详情页再按同一账户读取最新节点。
  Future<void> _openPettyWallet(BuildContext context) async {
    if (_pettyOpening) return;
    _pettyOpening = true;
    final accountId = widget.accountId;
    try {
      final bank = await _directory().fetchUserBank(accountId);
      if (!context.mounted || widget.accountId != accountId) return;
      if (bank == null) {
        _showBindingMessage(context, '请先在“清算行”页面绑定清算行');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => context.read<WalletNavigation>().pettyWallet(
            accountId: accountId,
          ),
        ),
      );
      if (mounted && widget.accountId == accountId) {
        await refresh(forceRefresh: false);
      }
    } catch (_) {
      if (context.mounted && widget.accountId == accountId) {
        _showBindingMessage(context, '无法核对当前清算行，请重试');
      }
    } finally {
      _pettyOpening = false;
    }
  }

  static void _showBindingMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

/// 两条竖线统一高40，始终居于48高图标槽正中，不随文字或余额下移。
class _ActionDivider extends StatelessWidget {
  const _ActionDivider({required this.lineKey});
  final Key lineKey;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1,
    height: AppLayout.scaled(context, 48),
    child: Center(
      child: Container(
        key: lineKey,
        width: 1,
        height: AppLayout.scaled(context, 40),
        color: AppTheme.divider,
      ),
    ),
  );
}

/// 充值图标和文字自然排版；三项都从图标顶端对齐，金额仍跨左侧两列。
class _RechargeAction extends StatelessWidget {
  const _RechargeAction({required this.token, required this.onTap});
  final String token;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'packages/citizen_assets/icons/${token.toLowerCase()}.svg',
            width: AppLayout.scaled(context, 48),
            height: AppLayout.scaled(context, 48),
            excludeFromSemantics: true,
          ),
          SizedBox(height: AppLayout.scaled(context, 8)),
          Text(
            '充值/$token',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryDark,
              height: AppLayout.compactLineHeight,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 零钱包与两个稳定币入口统一为48实色圆底白图形，继续使用原绑定和点击回调。
class _BalanceAction extends StatelessWidget {
  const _BalanceAction({required this.balanceText, required this.onTap});
  final String balanceText;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('wallet-petty-icon'),
            width: AppLayout.scaled(context, 48),
            height: AppLayout.scaled(context, 48),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: AppLayout.scaled(context, 26),
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 8)),
          Text(
            '零钱包',
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryDark,
              height: AppLayout.compactLineHeight,
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 4)),
          Text(
            balanceText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 12),
              color: AppTheme.textTertiary,
              height: AppLayout.subtitleLineHeight,
            ),
          ),
        ],
      ),
    ),
  );
}

// 构造固定账户码并展示本机名称和地址，载荷仅含规范账户。

/// 构造固定账户码（`QR_V1 k=5 account_id_code`）。
///
/// 本机账户名称和 SS58 地址只用于弹窗展示，绝不进入二维码载荷；账户授权与关系主键
/// 始终是规范 `account_id`。
@visibleForTesting
Future<String> buildWalletAccountQrData(CitizenSdk qr, String accountId) =>
    qr.encodeAccountId(accountId);

/// 打开冷热钱包共用的账户二维码弹窗。
///
/// [showDialog] 默认允许点击遮罩关闭；显式保留该行为，避免恢复成必须进入独立页面或只能
/// 点击按钮退出的旧交互。非法 `account_id` 从严拒绝，不生成可误导扫码端的二维码。
Future<void> showWalletQrDialog(
  BuildContext context, {
  required String accountId,
  required String accountName,
}) async {
  final String accountAddress;
  try {
    accountAddress = citizenSs58FromAccountId(accountId);
  } on FormatException {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('账户标识无效，无法生成二维码')));
    return;
  }
  final qrData = await buildWalletAccountQrData(
    context.read<CitizenSdk>(),
    accountId,
  );
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppLayout.scaled(dialogContext, 16),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(dialogContext, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              accountName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaled(dialogContext, 16),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppLayout.scaled(dialogContext, 16)),
            Container(
              padding: EdgeInsets.all(AppLayout.scaled(dialogContext, 12)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  AppLayout.scaled(dialogContext, 12),
                ),
                border: Border.all(color: AppTheme.border),
              ),
              child: AppQrImage(
                key: const ValueKey('wallet-account-qr'),
                data: qrData,
                color: AppTheme.primaryDark,
                size: AppLayout.scaled(dialogContext, 240),
              ),
            ),
            SizedBox(height: AppLayout.scaled(dialogContext, 12)),
            SelectableText(
              accountAddress,
              key: const ValueKey('wallet-account-address'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
                fontSize: AppLayout.scaled(dialogContext, 11),
              ),
            ),
            SizedBox(height: AppLayout.scaled(dialogContext, 12)),
            // 与公民钱包保持同一结构：关闭、复制均为等宽文字按钮。
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('关闭'),
                  ),
                ),
                SizedBox(width: AppLayout.scaled(dialogContext, 8)),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: accountAddress),
                      );
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('账户地址已复制'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text('复制'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
