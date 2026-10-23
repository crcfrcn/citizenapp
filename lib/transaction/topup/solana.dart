import 'topup_models.dart';

/// Solana原SPL Token的USDC转账；收款地址是owner，由官方SDK推导/建立ATA。
Map<String, Object> solanaPayment(TopupRail rail, TopupPaymentIntent intent) {
  if (rail.network != TopupNetwork.solana ||
      rail.token != 'USDC' ||
      intent.network != rail.network)
    throw const FormatException('Solana付款上下文无效');
  return {
    'rpc': TopupRpcConfig.url(TopupRpcConfig.solana),
    'mint': rail.asset,
    'receiver': rail.recvAddress,
    'amount': decimal(intent.intent['pay_amount']),
    'decimals': rail.decimals,
  };
}
