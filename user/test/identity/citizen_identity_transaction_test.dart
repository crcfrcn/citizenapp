// 验证自助占号和换绑SCALE布局、完整授权域及版本绑定。

import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'package:citizen_user/identity/citizen_identity_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

CitizenIdentityTransaction _transaction(TestChainReads chain) => (() {
  final reads0 = TestTransactionCalls();
  return CitizenIdentityTransaction(
    getFinalizedHead: chain.getFinalizedHead,
    getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
    getGenesisHash: chain.getGenesisHash,
    getStorageBatch: chain.getStorageBatch,
    prepareTransaction: reads0.prepareTransaction,
    executePreparedTransaction: reads0.executePreparedTransaction,
    cancelPreparedTransactionExecution:
        reads0.cancelPreparedTransactionExecution,
    consumePreparedTransactionQrResponse:
        reads0.consumePreparedTransactionQrResponse,
  );
})();

CitizenBlockRef _finalized(String hash, [int number = 88]) => CitizenBlockRef(
  hash: hash,
  number: BigInt.from(number),
  finality: CitizenBlockFinality.finalized,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();
  late CitizenRuntimeContext runtime;
  setUpAll(() async {
    runtime = await CitizenSdkTestFixture.runtimeContext(
      _finalized('0x${'01' * 32}'),
    );
  });

  // 采用链端 CTZN 金标号做样本(26 字节 ASCII)。
  const cid = 'CN951-CTZN1-539598435-2026';
  final cidBytes = Uint8List.fromList(cid.codeUnits);
  // 26 < 64 ⇒ 单字节 SCALE compact = len << 2 = 104。
  const compactCid = 26 << 2; // 0x68

  group('self_occupy_cid call data', () {
    test('布局 [10,5, compact(len), ...cid.utf8]', () async {
      final call = CitizenIdentityTransaction.buildSelfOccupyCidCall(
        cid,
        runtime: runtime,
      );
      expect(call[0], 10);
      expect(call[1], 5);
      expect(call[2], compactCid);
      expect(call.sublist(3), cidBytes);
      expect(call.length, 3 + 26);
    });

    test('空 / 超 32 字节 cid 被拒', () async {
      expect(
        () => CitizenIdentityTransaction.buildSelfOccupyCidCall(
          '',
          runtime: runtime,
        ),
        throwsArgumentError,
      );
      expect(
        () => CitizenIdentityTransaction.buildSelfOccupyCidCall(
          'X' * 33,
          runtime: runtime,
        ),
        throwsArgumentError,
      );
    });
  });

  group('self_rebind_cid_account_id call data', () {
    final sig = Uint8List(64)..fillRange(0, 64, 0xAB);
    final revision = BigInt.from(0x01020304);

    test('布局 [10,9,cid,revision:u64LE,expires:u64LE,sig]', () async {
      final call = CitizenIdentityTransaction.buildSelfRebindCidAccountCall(
        runtime: runtime,
        cidNumber: cid,
        expectedBindingRevision: revision,

        currentAccountSignature: sig,
      );
      expect(call.sublist(0, 2), <int>[10, 9]);
      expect(call[2], compactCid);
      expect(call.sublist(3, 3 + 26), cidBytes);
      const revisionStart = 3 + 26;
      expect(call.sublist(revisionStart, revisionStart + 8), <int>[
        0x04,
        0x03,
        0x02,
        0x01,
        0,
        0,
        0,
        0,
      ]);
      const sigStart = revisionStart + 8;
      expect(call.sublist(sigStart, sigStart + 2), <int>[0x01, 0x01]);
      expect(call.sublist(sigStart + 2), sig);
      expect(call.length, sigStart + 2 + 64); // 111
    });

    test('非 64 字节签名或越界 u64 被拒', () async {
      expect(
        () => CitizenIdentityTransaction.buildSelfRebindCidAccountCall(
          runtime: runtime,
          cidNumber: cid,
          expectedBindingRevision: revision,

          currentAccountSignature: Uint8List(63),
        ),
        throwsArgumentError,
      );
      expect(
        () => CitizenIdentityTransaction.buildSelfRebindCidAccountCall(
          runtime: runtime,
          cidNumber: cid,
          expectedBindingRevision: BigInt.one << 64,

          currentAccountSignature: sig,
        ),
        throwsArgumentError,
      );
    });
  });

  group('rebind 完整授权与原摘要', () {
    final genesisHash = Uint8List.fromList(List<int>.filled(32, 0x22));
    const currentAccount =
        '0x3333333333333333333333333333333333333333333333333333333333333333';
    const newAccount =
        '0x1111111111111111111111111111111111111111111111111111111111111111';
    final currentAccountBytes = Uint8List.fromList(List<int>.filled(32, 0x33));
    final newAccountBytes = Uint8List.fromList(List<int>.filled(32, 0x11));
    final revision = BigInt.from(0x01020304);

    test('op=0x11 且字段逐字节对齐 CidRebindAuthorization SCALE', () async {
      final authorization = CitizenIdentityTransaction.buildRebindAuthorization(
        genesisHash: genesisHash,
        cidNumber: cid,
        currentAccountId: currentAccount,
        newAccountId: newAccount,
        expectedBindingRevision: revision,
      );
      expect(kOpSignCidRebind, 0x11);
      expect(authorization.length, 131);

      final payload = <int>[
        ...genesisHash,
        compactCid,
        ...cidBytes,
        ...currentAccountBytes,
        ...newAccountBytes,
        0x04,
        0x03,
        0x02,
        0x01,
        0,
        0,
        0,
        0,
      ];
      final expected = (await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignCidRebind,
          scalePayload: Uint8List.fromList(payload),
        ),
      ));
      expect(authorization, payload);
      final digest = await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignCidRebind,
          scalePayload: authorization,
        ),
      );
      expect(digest, expected);
      expect(
        digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        '648df90f231b32d1e0665fd54a9dca94381a739689a665a69d83857941520d4d',
      );
    });

    test('创世/当前账户/revision 任一变化均改变完整授权', () async {
      Uint8List authorization({
        Uint8List? genesis,
        String? old,
        BigInt? revisionValue,
      }) => CitizenIdentityTransaction.buildRebindAuthorization(
        genesisHash: genesis ?? genesisHash,
        cidNumber: cid,
        currentAccountId: old ?? currentAccount,
        newAccountId: newAccount,
        expectedBindingRevision: revisionValue ?? revision,
      );

      final baseline = authorization();
      expect(authorization(genesis: Uint8List(32)..[0] = 1), isNot(baseline));
      expect(authorization(old: '0x${'44' * 32}'), isNot(baseline));
      expect(
        authorization(revisionValue: revision + BigInt.one),
        isNot(baseline),
      );
    });

    test('非法 newAccountId 文本被拒', () {
      // 完整授权在交付签名端前同步拒绝非法账户。
      expect(
        () => CitizenIdentityTransaction.buildRebindAuthorization(
          genesisHash: genesisHash,
          cidNumber: cid,
          currentAccountId: currentAccount,
          newAccountId: 'not-hex',
          expectedBindingRevision: revision,
        ),
        throwsArgumentError,
      );
    });
  });

  test('换绑上下文同块读取当前账户与revision，不读取区块时间', () async {
    final rpc = _RebindContextChain();
    final context = await _transaction(
      rpc,
    ).fetchSelfRebindAuthorizationContext(cid);

    expect(context.genesisHash, Uint8List.fromList(List<int>.filled(32, 0x22)));
    expect(context.currentAccountId, '0x${'33' * 32}');
    expect(context.expectedBindingRevision, BigInt.from(7));
    expect(rpc.readBlockHashes, List<String>.filled(2, '0x${'55' * 32}'));
    expect(rpc.storageKeys.toSet().length, 2);
    expect(rpc.batchCalls, 1);
  });

  test('revision=u64::MAX 在生成签名前 fail-closed', () async {
    final rpc = _RebindContextChain(revision: (BigInt.one << 64) - BigInt.one);
    await expectLater(
      _transaction(rpc).fetchSelfRebindAuthorizationContext(cid),
      throwsA(isA<StateError>()),
    );
  });

  group('finalized 目标绑定后置核验', () {
    const newAccount =
        '0x1111111111111111111111111111111111111111111111111111111111111111';
    const blockHash =
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('账户与 revision 精确命中才通过', () async {
      final rpc = _FinalizedBindingChain(accountByte: 0x11, revision: 8);
      await expectLater(
        _transaction(rpc).verifyFinalizedBindingState(
          cidNumber: cid,
          expectedAccountId: newAccount,
          expectedBindingRevision: BigInt.from(8),
          finalizedBlock: _finalized(blockHash),
        ),
        completes,
      );
      expect(rpc.readBlockHashes, <String>[blockHash, blockHash]);
      expect(rpc.batchCalls, 1);
    });

    test('extrinsic 已 finalized 但绑定仍是此前账户/此前 revision 时拒绝', () async {
      final rpc = _FinalizedBindingChain(accountByte: 0x33, revision: 7);
      await expectLater(
        _transaction(rpc).verifyFinalizedBindingState(
          cidNumber: cid,
          expectedAccountId: newAccount,
          expectedBindingRevision: BigInt.from(8),
          finalizedBlock: _finalized(blockHash),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('目标账户已变但 revision 没有精确推进时拒绝', () async {
      final rpc = _FinalizedBindingChain(accountByte: 0x11, revision: 7);
      await expectLater(
        _transaction(rpc).verifyFinalizedBindingState(
          cidNumber: cid,
          expectedAccountId: newAccount,
          expectedBindingRevision: BigInt.from(8),
          finalizedBlock: _finalized(blockHash),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('首次占号只接受目标账户 + revision=1', () async {
      final rpc = _FinalizedBindingChain(accountByte: 0x11, revision: 1);
      await expectLater(
        _transaction(rpc).verifyFinalizedBindingState(
          cidNumber: cid,
          expectedAccountId: newAccount,
          expectedBindingRevision: BigInt.one,
          finalizedBlock: _finalized(blockHash),
        ),
        completes,
      );
    });
  });
}

class _RebindContextChain extends TestChainReads {
  _RebindContextChain({BigInt? revision})
    : revision = revision ?? BigInt.from(7);

  final BigInt revision;
  int _readIndex = 0;
  final List<String> readBlockHashes = <String>[];
  final List<String> storageKeys = <String>[];
  int batchCalls = 0;

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async {
    batchCalls++;
    return Future.wait(keys.map((key) => getStorage(block, key)));
  }

  @override
  Future<CitizenBlockRef> getFinalizedHead() async =>
      _finalized('0x${'55' * 32}');

  @override
  Future<String> getGenesisHash() async => '0x${'22' * 32}';

  @override
  Future<Uint8List?> getStorage(
    CitizenBlockRef block,
    Uint8List storageKey,
  ) async {
    storageKeys.add(_hex(storageKey));
    readBlockHashes.add(block.hash);
    return switch (_readIndex++) {
      0 => Uint8List.fromList(List<int>.filled(32, 0x33)),
      1 => _u64(revision),
      _ => throw StateError('unexpected storage read'),
    };
  }

  static Uint8List _u64(BigInt value) {
    final result = Uint8List(8);
    var remaining = value;
    for (var index = 0; index < result.length; index++) {
      result[index] = (remaining & BigInt.from(0xff)).toInt();
      remaining >>= 8;
    }
    return result;
  }

  static String _hex(List<int> bytes) =>
      '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}

class _FinalizedBindingChain extends TestChainReads {
  _FinalizedBindingChain({required this.accountByte, required this.revision});

  final int accountByte;
  final int revision;
  int _readIndex = 0;
  final List<String> readBlockHashes = <String>[];
  int batchCalls = 0;

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async {
    batchCalls++;
    return Future.wait(keys.map((key) => getStorage(block, key)));
  }

  @override
  Future<Uint8List?> getStorage(
    CitizenBlockRef block,
    Uint8List storageKey,
  ) async {
    readBlockHashes.add(block.hash);
    return switch (_readIndex++) {
      0 => Uint8List.fromList(List<int>.filled(32, accountByte)),
      1 => _RebindContextChain._u64(BigInt.from(revision)),
      _ => throw StateError('unexpected storage read: $storageKey'),
    };
  }
}
