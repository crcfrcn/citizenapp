import 'topup_models.dart';

/// Tron参数沿用服务器冻结意图；交易构造与序列化由随包TronWeb完成。
Map<String, Object> tronPayment(TopupRail rail, TopupPaymentIntent intent) {
  if (rail.network != TopupNetwork.tron ||
      rail.token != 'USDT' ||
      intent.network != rail.network)
    throw const FormatException('Tron付款上下文无效');
  return {
    'rpc': TopupRpcConfig.url(TopupRpcConfig.tron),
    'asset': rail.asset,
    'receiver': rail.recvAddress,
    'amount': decimal(intent.intent['pay_amount']),
  };
}
