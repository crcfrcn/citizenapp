// 声明用户模块的聊天、支付、主页和联系人选择导航意图。

import 'package:flutter/widgets.dart';

typedef DirectChatOpener =
    Future<void> Function(
      BuildContext context, {
      required String peerUserId,
      required String title,
    });

// 用户模块只描述用户动作，具体聊天和支付页面由根App装配。
final class UserNavigation {
  const UserNavigation({
    required this.openDirectChat,
    required this.openTransfer,
  });
  final DirectChatOpener openDirectChat;
  final Future<void> Function(BuildContext context, {required String cidNumber})
  openTransfer;
}

/// 通讯录页使用模式。
enum ContactPickMode {
  /// 常规浏览:点联系人进主页,卡片带「转账/私信/改名/删除」操作菜单。
  browse,

  /// 选收款人(交易页发起):点联系人即返回公民号，由调用方选择收款人。
  pickForTransfer,

  /// 发起聊天内嵌多选列表；只交付选中联系人，不负责打开聊天。
  pickForChat,
}
