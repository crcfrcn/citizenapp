import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;
import 'package:flutter/widgets.dart';

// 钱包只发出页面/弹窗意图；跨包入口由根App装配，充值返回本次到账结果。
final class WalletNavigation {
  const WalletNavigation({
    required this.history,
    required this.topup,
    required this.pettyWallet,
    required this.identity,
    required this.recordDetail,
  });
  final Widget Function({
    required String accountAddress,
    required String accountId,
  })
  history;
  final Future<bool?> Function(
    BuildContext context, {
    required String accountId,
    required String token,
  })
  topup;
  final Widget Function({
    required String accountId,
    required String accountAddress,
    required String wssUrl,
    required String displayTitle,
  })
  pettyWallet;
  final Widget Function() identity;
  final Widget Function({required wallet_store.Entry record}) recordDetail;
}
