import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// 共享夹具必须让未配置调用失败，不能给业务回归提供隐式成功事实。
void main() {
  test('未声明的链事实和交易调用立即失败', () {
    expect(() => TestCitizenChain().getFinalizedHead(), throwsUnimplementedError);
    expect(() => TestCitizenSdkWallet().getState(), throwsUnimplementedError);
  });
  test('SDK原生绑定对损坏的合成钱包回执保持拒绝', () async {
    final transport = TestCitizenSdkTransport({'getWalletState': (_) => ['invalid']});
    final sdk = await transport.open();
    try {
      await expectLater(sdk.wallet.getState().result, throwsA(isA<Exception>()));
    } finally {
      await sdk.close();
      await transport.dispose();
    }
  });
}
