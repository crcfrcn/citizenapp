import 'package:flutter/material.dart';

import 'package:citizenapp/8964/feed/square_home_page.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';

/// 底部“广场”Tab 入口。
///
/// 入口复用统一CID事实与会话自动准备，不另建初始化或设备登记交互。
/// 广场首页默认进入推荐流。发帖通知红点：广场底部 tab 数经 [onSquareUnreadChanged]
/// 上抛给 AppShell 挂 Badge；[selectedTab] 广播用于「进广场清广场红点」。
class SquareTab extends StatelessWidget {
  const SquareTab({
    super.key,
    this.onSquareUnreadChanged,
    this.selectedTab,
    this.tabIndex = 0,
  });

  final ValueChanged<int>? onSquareUnreadChanged;
  final ValueNotifier<int>? selectedTab;
  final int tabIndex;

  @override
  Widget build(BuildContext context) => MembershipBusinessGate(
    child: SquareHomePage(
      onSquareUnreadChanged: onSquareUnreadChanged,
      selectedTab: selectedTab,
      tabIndex: tabIndex,
    ),
  );
}
