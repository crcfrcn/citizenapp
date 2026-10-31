import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_citizen/administrators/admin_set_change_service.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';

final signer = Uint8List.fromList(List.filled(32, 1));
final block = CitizenBlockRef(
  hash: '0x${'ab' * 32}',
  number: BigInt.from(50),
  finality: CitizenBlockFinality.finalized,
);
CitizenPreparedTransaction prepared() => CitizenPreparedTransaction(
  preparationId: 'prepared',
  sourceAccountId: signer,
  callDataHash: Uint8List(32),
  bestBlock: block,
  runtimeSpecNumber: 1,
  transactionFormatNumber: 1,
  nonce: BigInt.from(3),
);
CitizenTransactionExecutionCompleted completed({
  CitizenTransactionResolution resolution =
      CitizenTransactionResolution.finalizedSuccess,
  CitizenExecution? execution,
  bool missing = false,
}) => CitizenTransactionExecutionCompleted(
  executionId: 'execution',
  sourceAccountId: signer,
  callDataHash: Uint8List(32),
  transactionHash: Uint8List(32),
  resolution: resolution,
  execution: missing
      ? null
      : execution ??
            CitizenExecution(
              status: CitizenExecutionStatus.success,
              block: block,
              extrinsicIndex: 2,
              dispatchVariant: null,
              palletIndex: null,
              errorIndex: null,
            ),
  poolRejectionReason: null,
  replacementHash: null,
);
CitizenTransactionExternalSigningPending pending() =>
    CitizenTransactionExternalSigningPending(
      executionId: 'execution',
      sourceAccountId: signer,
      callDataHash: Uint8List(32),
      qrRequest: 'synthetic-qr',
      expiresAt: DateTime.utc(2027),
    );
TestCitizenTransactionFlow flow({
  bool cold = false,
  CitizenTransactionExecutionCompleted? result,
}) => TestCitizenTransactionFlow()
  ..prepare = ((_, _) async => prepared())
  ..execute = ((_) async => cold ? pending() : result ?? completed())
  ..consume = ((_, _) async => result ?? completed())
  ..cancel = ((_) async {});

AdminPerson person(int n) => AdminPerson(
  accountId: '0x${n.toRadixString(16).padLeft(2, '0') * 32}',
  familyName: '测试',
  givenName: '管理员',
);
AdminAccountState account({int status = 1}) => AdminAccountState(
  accountId: '0x${'09' * 32}',
  orgCode: 'PMUL',
  kind: 2,
  admins: [person(1), person(2)],
  threshold: 2,
  personalStatus: status,
);
void main() {
  test('管理员64人及严格多数边界，65人拒绝', () {
    final service = (() {
      final reads0 = TestTransactionCalls();
      return AdminsChangeService(
        prepareTransaction: reads0.prepareTransaction,
        executePreparedTransaction: reads0.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            reads0.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            reads0.consumePreparedTransactionQrResponse,
      );
    })();
    expect(
      service.buildCallData(
        account: account(),
        proposerAccountId: person(1).accountId,
        admins: List.generate(64, (i) => person(i + 1)),
        newThreshold: 33,
      ),
      isNotEmpty,
    );
    for (final values in [(64, 32), (65, 33)]) {
      expect(
        () => service.buildCallData(
          account: account(),
          proposerAccountId: person(1).accountId,
          admins: List.generate(values.$1, (i) => person(i + 1)),
          newThreshold: values.$2,
        ),
        throwsStateError,
      );
    }
  });

  for (final cold in [false, true]) {
    test('管理员集合变更冷热签沿SDK唯一生命周期：$cold', () async {
      final tx = flow(cold: cold);
      final result =
          await AdminsChangeService(
            prepareTransaction: tx.prepareTransaction,
            executePreparedTransaction: tx.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                tx.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                tx.consumePreparedTransactionQrResponse,
          ).submit(
            account: account(),
            admins: [person(1), person(3)],
            newThreshold: 2,
            signerPublicKey: signer,
            externalSigning: (_) async => 'synthetic-response',
          );
      expect(result.txHash, '0x${'00' * 32}');
      expect(tx.callData!.take(2), [29, 0]);
      expect(tx.prepareCount, 1);
      expect(tx.consumeCount, cold ? 1 : 0);
    });
  }
  for (final kind in [
    'duplicate',
    'count',
    'threshold',
    'unchanged',
    'inactive',
    'permission',
    'signer',
  ]) {
    test('变更$kind无副作用拒绝', () async {
      final tx = flow();
      final admins = kind == 'duplicate'
          ? [person(1), person(1)]
          : kind == 'count'
          ? [person(1)]
          : kind == 'unchanged'
          ? [person(1), person(2)]
          : [person(1), person(3)];
      await expectLater(
        AdminsChangeService(
          prepareTransaction: tx.prepareTransaction,
          executePreparedTransaction: tx.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              tx.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              tx.consumePreparedTransactionQrResponse,
        ).submit(
          account: account(status: kind == 'inactive' ? 0 : 1),
          admins: admins,
          newThreshold: kind == 'threshold' ? 1 : 2,
          signerPublicKey: kind == 'signer'
              ? Uint8List(31)
              : kind == 'permission'
              ? Uint8List.fromList(List.filled(32, 8))
              : signer,
          externalSigning: (_) async => null,
        ),
        throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())),
      );
      expect(tx.prepareCount, 0);
    });
  }
  test('取消与回调异常取消pending，未返回完整执行不能报成功', () async {
    for (final fail in ['cancel', 'callback', 'missing', 'failed']) {
      final tx = flow(
        cold: ['cancel', 'callback'].contains(fail),
        result: completed(
          missing: fail == 'missing',
          resolution: fail == 'failed'
              ? CitizenTransactionResolution.finalizedFailed
              : CitizenTransactionResolution.finalizedSuccess,
        ),
      );
      await expectLater(
        AdminsChangeService(
          prepareTransaction: tx.prepareTransaction,
          executePreparedTransaction: tx.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              tx.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              tx.consumePreparedTransactionQrResponse,
        ).submit(
          account: account(),
          admins: [person(1), person(3)],
          newThreshold: 2,
          signerPublicKey: signer,
          externalSigning: (_) async {
            if (fail == 'callback') throw StateError('合成失败');
            return null;
          },
        ),
        throwsStateError,
      );
      expect(tx.cancelCount, ['cancel', 'callback'].contains(fail) ? 1 : 0);
    }
  });
}
