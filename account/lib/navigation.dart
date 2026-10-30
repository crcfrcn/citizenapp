import 'package:flutter/widgets.dart';

typedef DirectChatOpener = Future<void> Function(
  BuildContext context, {
  required String peerUserId,
  required String title,
});

// 账户页只描述用户动作，具体聊天和支付页面由根App装配。
final class AccountNavigation {
  const AccountNavigation({required this.openDirectChat, required this.openTransfer});
  final DirectChatOpener openDirectChat;
  final Future<void> Function(BuildContext context, {required String toAddress, required String cidNumber}) openTransfer;
}

/// 通讯录页使用模式。
enum ContactPickMode {
  /// 常规浏览:点联系人进主页,卡片带「转账/私信/改名/删除」操作菜单。
  browse,

  /// 选收款人(交易页发起):点联系人即返回该联系人,由调用方预填收款地址。
  pickForTransfer,

  /// 选私信对象(聊天页「发私信」):点联系人直接打开一对一聊天,不带操作菜单与扫码入口。
  pickForMessage,
}

