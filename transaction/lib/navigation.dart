import 'package:flutter/widgets.dart';
import 'package:citizen_account/navigation.dart';

// 交易表单通过公开选择端口使用钱包和通讯录，不导入这两个包的页面。
final class TransactionNavigation {
  const TransactionNavigation({required this.walletPicker, required this.contactPicker});
  final Widget Function() walletPicker;
  final Widget Function(ContactPickMode mode) contactPicker;
}
