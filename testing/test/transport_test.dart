import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// 公共夹具只交付明确业务函数；协议能力来自本轮真实Core。
void main() {
  final core = TestCitizenSdkHarness();
  test('同例多个真实会话不替换仍在使用的物理通道', () async {
    final extra = await openTestSdk();
    expect(identical(extra.fixture, core.fixture), isTrue);
    await extra.sdk.close();
    final wire = await core.sdk.encodeAccountId(testCitizenAccountId);
    expect((await core.sdk.parseQr(wire)).accountId, testCitizenAccountId);
  });
  test('未声明的链事实和交易调用立即失败', () {
    expect(
      () => const TestChainReads().getFinalizedHead(),
      throwsUnimplementedError,
    );
    expect(
      () => const TestWalletReads().getWalletState(),
      throwsUnimplementedError,
    );
    expect(
      () => const TestTransactionCalls().executePreparedTransaction('missing'),
      throwsUnimplementedError,
    );
  });
  test('SDK原生绑定拒绝不支持的钱包读取，业务调用不走物理资源通道', () async {
    await expectLater(
      core.sdk.getWalletState().result,
      throwsA(
        isA<CitizenSdkException>().having(
          (e) => e.code,
          'code',
          CitizenSdkErrorCode.unsupported,
        ),
      ),
    );
    expect(core.fixture.calls.where((m) => m != 'diagnose'), ['open']);
    final text = await core.sdk.encodeAccountId(testCitizenAccountId);
    expect((await core.sdk.parseQr(text)).accountId, testCitizenAccountId);
  });
}
