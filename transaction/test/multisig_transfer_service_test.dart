import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_transaction/multisig/multisig_transfer_service.dart';
import 'package:citizen_citizen/institution/institution_info.dart';

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

final institution = InstitutionInfo(
  fullName: '合成个人多签',
  shortName: '合成',
  cidFullNameEn: 'Synthetic',
  cidShortNameEn: 'SYN',
  cidNumber: 'personal-account:0x${'09' * 32}',
  orgType: OrgType.personalMultisig,
  accountId: '0x${'09' * 32}',
);
Uint8List eventBytes({
  int index = 2,
  int who = 1,
  int amount = 100,
  int phase = 0,
  String remark = '',
}) => Uint8List.fromList([
  4,
  phase,
  if (phase == 0) ...[index, 0, 0, 0],
  17,
  0,
  7,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  ...'PMUL'.codeUnits,
  0,
  ...List.filled(32, who),
  ...List.filled(32, 9),
  ...List.filled(32, 2),
  amount,
  ...List.filled(15, 0),
  utf8.encode(remark).length << 2,
  ...utf8.encode(remark),
  9,
  0,
  0,
  0,
  0,
]);
Uint8List eventMetadata() => base64Decode(
  'bWV0YQ5AAAAABQMABAAABQUACAAABQYADAAABQAAEAAAAyAAAAAAABQAAAIAABgAAAEMOEFwcGx5RXh0cmluc2ljBAAEARhzaGFyZWQAAAAwRmluYWxpemF0aW9uAAEAOEluaXRpYWxpemF0aW9uAAIAABwAAAEMQFRyYW5zZmVyUHJvcG9zZWQkASxwcm9wb3NhbF9pZAgBGHNoYXJlZAABQGluc3RpdHV0aW9uX2NvZGU4ARhzaGFyZWQAAUBhY3Rvcl9jaWRfbnVtYmVyPAEYc2hhcmVkAAFMcHJvcG9zZXJfYWNjb3VudF9pZBABGHNoYXJlZAABSGZ1bmRpbmdfYWNjb3VudF9pZBABGHNoYXJlZAABWGJlbmVmaWNpYXJ5X2FjY291bnRfaWQQARhzaGFyZWQAARhhbW91bnQ0ARhzaGFyZWQAARhyZW1hcmsUARhzaGFyZWQAAShleHBpcmVzX2F0BAEYc2hhcmVkAAAAaFNhZmV0eUZ1bmRUcmFuc2ZlclByb3Bvc2VkIAEscHJvcG9zYWxfaWQIARhzaGFyZWQAAUBhY3Rvcl9jaWRfbnVtYmVyFAEYc2hhcmVkAAFMcHJvcG9zZXJfYWNjb3VudF9pZBABGHNoYXJlZAABWGluc3RpdHV0aW9uX2FjY291bnRfaWQQARhzaGFyZWQAAVhiZW5lZmljaWFyeV9hY2NvdW50X2lkEAEYc2hhcmVkAAEYYW1vdW50NAEYc2hhcmVkAAEYcmVtYXJrFAEYc2hhcmVkAAEoZXhwaXJlc19hdAQBGHNoYXJlZAADAExTd2VlcFRvTWFpblByb3Bvc2VkHAEscHJvcG9zYWxfaWQIARhzaGFyZWQAAUBhY3Rvcl9jaWRfbnVtYmVyFAEYc2hhcmVkAAFMcHJvcG9zZXJfYWNjb3VudF9pZBABGHNoYXJlZAABWGluc3RpdHV0aW9uX2FjY291bnRfaWQQARhzaGFyZWQAATBtYWluX2FjY291bnQQARhzaGFyZWQAARhhbW91bnQ0ARhzaGFyZWQAAShleHBpcmVzX2F0BAEYc2hhcmVkAAYAACAAAAEEQE11bHRpc2lnVHJhbnNmZXIEABwBGHNoYXJlZAARAAAkAAACEAAoAAAADAEUcGhhc2UYARhzaGFyZWQAARRldmVudCABGHNoYXJlZAABGHRvcGljcyQBGHNoYXJlZAAALAAAAigAMAAABAAANAAABQcAOAAAAwQAAAAAADwAAAEIEE5vbmUAAAAQU29tZQQAFAEYc2hhcmVkAAEAAAQYU3lzdGVtARhTeXN0ZW0EGEV2ZW50cwEALAQAAAAAAAAAMAQAMA==',
);

class Chain extends TestChainReads {
  Uint8List? events = eventBytes();
  @override
  Future<CitizenRuntimeContext> getRuntimeContext(CitizenBlockRef ref) async =>
      CitizenRuntimeContext(
        block: ref,
        specVersion: 1,
        transactionVersion: 1,
        metadata: eventMetadata(),
      );
  @override
  Future<Uint8List?> getSystemEvents(CitizenBlockRef ref) async {
    expect(ref, same(block));
    return events;
  }
}

Future<Object> submit(MultisigTransferService service) =>
    service.submitProposeTransfer(
      institution: institution,
      proposerRoleCode: null,
      beneficiaryAddress: citizenSs58FromAccountId('0x${'02' * 32}'),
      amountYuan: 1,
      remark: '',
      signerPublicKey: signer,
      externalSigning: (_) async => 'synthetic-response',
    );
void main() {
  test('机构普通转账使用Some(CID)及实际岗位，缺岗位在准备前失败', () async {
    final institution = InstitutionInfo(
      fullName: '合成机构',
      shortName: '合成',
      cidFullNameEn: 'Synthetic',
      cidShortNameEn: 'SYN',
      cidNumber: 'CID-A',
      orgType: OrgType.nrc,
      adminCode: 'NRC',
      accounts: InstitutionAccounts(
        mainAccountId: '0x${'09' * 32}',
        feeAccountId: '0x${'03' * 32}',
      ),
    );
    final bytes = eventBytes();
    // 只将个人事件的PMUL/None替换成机构NRC/Some(CID)，其它独立编码字段不变。
    final payload = Uint8List.fromList([
      ...bytes.take(16),
      ...'NRC'.codeUnits,
      0,
      1,
      20,
      ...'CID-A'.codeUnits,
      ...bytes.skip(21),
    ]);
    final tx = flow(),
        service = (() {
          final reads0 = Chain()..events = payload;
          return MultisigTransferService(
            getFinalizedHead: reads0.getFinalizedHead,
            getStorageKeysPaged: reads0.getStorageKeysPaged,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
            getAccountBalance: reads0.getAccountBalance,
            getAccountBalances: reads0.getAccountBalances,
            getSystemEvents: reads0.getSystemEvents,
            getRuntimeContext: reads0.getRuntimeContext,
            prepareTransaction: tx.prepareTransaction,
            executePreparedTransaction: tx.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                tx.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                tx.consumePreparedTransactionQrResponse,
          );
        })();
    Future<Object> run(String? role) => service.submitProposeTransfer(
      institution: institution,
      proposerRoleCode: role,
      beneficiaryAddress: citizenSs58FromAccountId('0x${'02' * 32}'),
      amountYuan: 1,
      remark: '',
      signerPublicKey: signer,
      externalSigning: (_) async => null,
    );
    await expectLater(run(null), throwsArgumentError);
    expect(tx.prepareCount, 0);
    final result = await run('DIRECTOR');
    expect((result as dynamic).proposalId, 7);
  });

  test('安全基金及费用归集按所属事件、账户和金额确认', () async {
    final institution = InstitutionInfo(
      fullName: '合成机构',
      shortName: '合成',
      cidFullNameEn: 'Synthetic',
      cidShortNameEn: 'SYN',
      cidNumber: 'CID-A',
      orgType: OrgType.nrc,
      adminCode: 'NRC',
      accounts: InstitutionAccounts(
        mainAccountId: '0x${'09' * 32}',
        feeAccountId: '0x${'03' * 32}',
        safetyFundAccountId: '0x${'04' * 32}',
      ),
    );
    for (final kind in [3, 6]) {
      for (final cold in [true, false]) {
        final chain = Chain()
          ..events = Uint8List.fromList([
            4,
            0,
            2,
            0,
            0,
            0,
            17,
            kind,
            7,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            20,
            ...'CID-A'.codeUnits,
            ...signer,
            ...List.filled(32, kind == 3 ? 4 : 3),
            ...List.filled(32, kind == 3 ? 2 : 9),
            100,
            ...List.filled(15, 0),
            if (kind == 3) 0,
            9,
            0,
            0,
            0,
            0,
          ]);
        final tx = flow(cold: cold),
            service = MultisigTransferService(
              getFinalizedHead: chain.getFinalizedHead,
              getStorageKeysPaged: chain.getStorageKeysPaged,
              getStorage: chain.getStorage,
              getStorageBatch: chain.getStorageBatch,
              getAccountBalance: chain.getAccountBalance,
              getAccountBalances: chain.getAccountBalances,
              getSystemEvents: chain.getSystemEvents,
              getRuntimeContext: chain.getRuntimeContext,
              prepareTransaction: tx.prepareTransaction,
              executePreparedTransaction: tx.executePreparedTransaction,
              cancelPreparedTransactionExecution:
                  tx.cancelPreparedTransactionExecution,
              consumePreparedTransactionQrResponse:
                  tx.consumePreparedTransactionQrResponse,
            );
        final result = kind == 3
            ? await service.submitProposeSafetyFund(
                institution: institution,
                proposerRoleCode: 'DIRECTOR',
                beneficiaryAddress: citizenSs58FromAccountId('0x${'02' * 32}'),
                amountYuan: 1,
                remark: '',
                signerPublicKey: signer,
                externalSigning: (_) async => 'synthetic-response',
              )
            : await service.submitProposeSweep(
                institution: institution,
                proposerRoleCode: 'DIRECTOR',
                amountYuan: 1,
                signerPublicKey: signer,
                externalSigning: (_) async => 'synthetic-response',
              );
        expect(result.proposalId, 7);
        expect(result.blockHash, block.hash);
        expect(tx.consumeCount, cold ? 1 : 0);
      }
    }
  });
  test('多签外签回调异常取消pending，未知消费不重播', () async {
    for (final stage in ['callback', 'consume']) {
      final tx = flow(cold: true),
          service = (() {
            final reads0 = Chain();
            return MultisigTransferService(
              getFinalizedHead: reads0.getFinalizedHead,
              getStorageKeysPaged: reads0.getStorageKeysPaged,
              getStorage: reads0.getStorage,
              getStorageBatch: reads0.getStorageBatch,
              getAccountBalance: reads0.getAccountBalance,
              getAccountBalances: reads0.getAccountBalances,
              getSystemEvents: reads0.getSystemEvents,
              getRuntimeContext: reads0.getRuntimeContext,
              prepareTransaction: tx.prepareTransaction,
              executePreparedTransaction: tx.executePreparedTransaction,
              cancelPreparedTransactionExecution:
                  tx.cancelPreparedTransactionExecution,
              consumePreparedTransactionQrResponse:
                  tx.consumePreparedTransactionQrResponse,
            );
          })();
      if (stage == 'consume') {
        tx.consume = (_, _) async => throw StateError('合成未知消费');
      }
      await expectLater(
        service.submitProposeTransfer(
          institution: institution,
          proposerRoleCode: null,
          beneficiaryAddress: citizenSs58FromAccountId('0x${'02' * 32}'),
          amountYuan: 1,
          remark: '',
          signerPublicKey: signer,
          externalSigning: (_) async {
            if (stage == 'callback') {
              throw StateError('合成回调失败');
            }
            return 'synthetic-response';
          },
        ),
        throwsStateError,
      );
      expect(tx.cancelCount, stage == 'callback' ? 1 : 0);
      expect(tx.executeCount, 1);
    }
  });

  for (final cold in [true, false]) {
    test('多签提案冷热签按实际执行块确认事件：$cold', () async {
      final tx = flow(cold: cold), chain = Chain();
      final result = await submit(
        MultisigTransferService(
          getFinalizedHead: chain.getFinalizedHead,
          getStorageKeysPaged: chain.getStorageKeysPaged,
          getStorage: chain.getStorage,
          getStorageBatch: chain.getStorageBatch,
          getAccountBalance: chain.getAccountBalance,
          getAccountBalances: chain.getAccountBalances,
          getSystemEvents: chain.getSystemEvents,
          getRuntimeContext: chain.getRuntimeContext,
          prepareTransaction: tx.prepareTransaction,
          executePreparedTransaction: tx.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              tx.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              tx.consumePreparedTransactionQrResponse,
        ),
      );
      expect((result as dynamic).proposalId, 7);
      expect(tx.prepareCount, 1);
    });
  }
  for (final bad in ['index', 'phase', 'count', 'embedded']) {
    test('多签不得接受其他交易、非交易Phase或载荷中伪事件：$bad', () async {
      final chain = Chain();
      chain.events = bad == 'index'
          ? eventBytes(index: 99)
          : bad == 'phase'
          ? eventBytes(phase: 1)
          : bad == 'count'
          ? Uint8List.fromList([0, ...eventBytes().skip(1)])
          : Uint8List.fromList([4, 2, 99, 99, ...eventBytes()]);
      await expectLater(
        submit(
          (() {
            final reads0 = flow();
            return MultisigTransferService(
              getFinalizedHead: chain.getFinalizedHead,
              getStorageKeysPaged: chain.getStorageKeysPaged,
              getStorage: chain.getStorage,
              getStorageBatch: chain.getStorageBatch,
              getAccountBalance: chain.getAccountBalance,
              getAccountBalances: chain.getAccountBalances,
              getSystemEvents: chain.getSystemEvents,
              getRuntimeContext: chain.getRuntimeContext,
              prepareTransaction: reads0.prepareTransaction,
              executePreparedTransaction: reads0.executePreparedTransaction,
              cancelPreparedTransactionExecution:
                  reads0.cancelPreparedTransactionExecution,
              consumePreparedTransactionQrResponse:
                  reads0.consumePreparedTransactionQrResponse,
            );
          })(),
        ),
        throwsA(anything),
      );
    });
  }
  test('错误业务字段、取消及未知广播结果不报创建成功', () async {
    for (final bad in ['signer', 'amount', 'remark', 'cancel', 'execute']) {
      final chain = Chain()
            ..events = eventBytes(
              who: bad == 'signer' ? 2 : 1,
              amount: bad == 'amount' ? 101 : 100,
              remark: bad == 'remark' ? 'other' : '',
            ),
          tx = flow(cold: bad == 'cancel');
      if (bad == 'execute') {
        tx.execute = (_) async => throw StateError('合成未知执行');
      }
      final service = MultisigTransferService(
        getFinalizedHead: chain.getFinalizedHead,
        getStorageKeysPaged: chain.getStorageKeysPaged,
        getStorage: chain.getStorage,
        getStorageBatch: chain.getStorageBatch,
        getAccountBalance: chain.getAccountBalance,
        getAccountBalances: chain.getAccountBalances,
        getSystemEvents: chain.getSystemEvents,
        getRuntimeContext: chain.getRuntimeContext,
        prepareTransaction: tx.prepareTransaction,
        executePreparedTransaction: tx.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            tx.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            tx.consumePreparedTransactionQrResponse,
      );
      if (bad == 'cancel') {
        await expectLater(
          service.submitProposeTransfer(
            institution: institution,
            proposerRoleCode: null,
            beneficiaryAddress: citizenSs58FromAccountId('0x${'02' * 32}'),
            amountYuan: 1,
            remark: '',
            signerPublicKey: signer,
            externalSigning: (_) async => null,
          ),
          throwsStateError,
        );
        expect(tx.cancelCount, 1);
      } else {
        await expectLater(submit(service), throwsA(anything));
        expect(tx.cancelCount, 0);
      }
      expect(tx.executeCount, 1);
    }
  });
}
