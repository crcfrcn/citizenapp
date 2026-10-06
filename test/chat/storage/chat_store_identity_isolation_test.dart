import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import '../../support/isar_test_env.dart';

void main() {
  useIsolatedIsar();
  test('finalized 公开绑定推进代次，旧上下文不能读取或继续写入', () async {
    const first = ChatBinding(bindingScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      userId: 'CID-A', bindingRevision: 1, accountId: 'account-a');
    const next = ChatBinding(bindingScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      userId: 'CID-A', bindingRevision: 2, accountId: 'account-b');
    final a = ChatStore(), b = ChatStore.withIndependentBindingGateForTest();
    final token = await a.activateBindingFence(first);
    final current = await b.convergeFinalizedBinding(next);
    expect(current.generation, greaterThan(token.generation));
    await expectLater(a.validateBindingFenceToken(token), throwsStateError);
    await expectLater(a.captureBindingFenceToken(first), throwsStateError);
    await expectLater(a.captureBindingFenceToken(const ChatBinding(
      bindingScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      userId: 'CID-B', bindingRevision: 2, accountId: 'account-b')), throwsStateError);
    await expectLater(a.convergeFinalizedBinding(first), throwsStateError);
  });
}
