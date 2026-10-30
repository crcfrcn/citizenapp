import 'package:citizen_storage/wallet_isar.dart' as wallet_store show Entry;
import 'package:flutter/widgets.dart';

// 钱包只发出页面构造意图；跨包页面由根App装配。
final class WalletNavigation {
  const WalletNavigation({required this.history, required this.topup, required this.withdraw, required this.pettyWallet, required this.identity, required this.recordDetail});
  final Widget Function({required String accountAddress, required String accountId}) history;
  final Widget Function({required String accountId}) topup;
  final Widget Function({required String accountId, required String accountAddress, required String wssUrl}) withdraw;
  final Widget Function({required String accountId, required String accountAddress, required String wssUrl, required String displayTitle}) pettyWallet;
  final Widget Function() identity;
  final Widget Function({required wallet_store.Entry record}) recordDetail;
}
