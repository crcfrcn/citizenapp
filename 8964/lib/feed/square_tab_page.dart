import 'package:flutter/material.dart';

import 'package:citizen_square/feed/square_home_page.dart';

/// 底部“广场”Tab 入口。
///
/// 入口只核对统一CID事实；会话失败留在原动态读取路径，不阻止本地编辑入口。
/// 广场首页默认显示本机保存顺序中的第一项。发帖通知红点经 [onSquareUnreadChanged]
/// 上抛给 AppShell 挂 Badge；[selectedTab] 广播用于重新进入广场时选中默认项。
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
  // 广场外观不受身份门禁替换；首页内部仍核对会话，未就绪禁用发布。
  Widget build(BuildContext context) => SquareHomePage(
    onSquareUnreadChanged: onSquareUnreadChanged,
    selectedTab: selectedTab,
    tabIndex: tabIndex,
  );
}
