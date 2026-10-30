import 'package:flutter/widgets.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

// 扫码采集不反向导入交易或账户页面；实际导航由根App实现。
abstract interface class ScanDispatch {
  Future<void> openScanDispatchFlow({required BuildContext context, required CitizenWalletStateAccount? paymentWallet, CitizenWalletStateAccount? signingAccount});
  Future<void> openAccountScanSignFlow({required BuildContext context, required CitizenWalletStateAccount account});
}
