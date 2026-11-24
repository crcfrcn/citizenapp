import 'package:citizen_citizen/account_derivation.dart' show deriveAccountId;
// 个人多签chain功能回归，保留迁入用例和断言。

import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_personal/accounts.dart';
import 'package:citizen_personal/members.dart';
import 'package:citizen_personal/chain.dart';
import 'package:citizen_personal/proposals.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// 原用例所属：personal/test/personal_manage_service_test.dart
// 验证个人多签调用、阈值、唯一执行事件及分批状态读取。

class PersonalmanageserviceFakeChain extends TestChainReads {
  final Map<String, Uint8List?> responses = {};
  final List<String> requestedKeys = [];

  @override
  Future<CitizenBlockRef> getFinalizedHead() async => CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.finalized,
  );

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    final storageKeyHex = _personalmanageservicehex(key);
    requestedKeys.add(storageKeyHex);
    return responses[storageKeyHex];
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async {
    final result = <Uint8List?>[];
    for (final key in keys) {
      final keyHex = _personalmanageservicehex(key);
      requestedKeys.add(keyHex);
      result.add(responses[keyHex]);
    }
    return result;
  }

  String _personalmanageservicehex(List<int> bytes) =>
      '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}

void _registerPersonalmanageservice() {
  Future<Uint8List> buildCall(
    String pallet,
    String method,
    Object fields,
  ) async {
    final runtime = await CitizenSdkTestFixture.runtimeContext(
      await PersonalmanageserviceFakeChain().getFinalizedHead(),
    );
    return runtime.encodeCall(pallet, method, fields);
  }

  String hexOf(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  List<int> codeBytes(String code) {
    final out = List<int>.filled(4, 0);
    final raw = code.codeUnits;
    for (var i = 0; i < out.length && i < raw.length; i++) {
      out[i] = raw[i];
    }
    return out;
  }

  List<int> compactVec(String text) {
    final bytes = utf8.encode(text);
    return [(bytes.length << 2) & 0xff, ...bytes];
  }

  List<int> compactU32(int value) {
    if (value < 64) return [(value << 2) & 0xff];
    final encoded = (value << 2) | 0x01;
    return [encoded & 0xff, (encoded >> 8) & 0xff];
  }

  List<int> adminBytes(
    List<int> account, {
    String familyName = '管理',
    String givenName = '员',
  }) => [...account, ...compactVec(familyName), ...compactVec(givenName)];

  PersonalMember adminPerson(
    List<int> account, {
    String familyName = '管理',
    String givenName = '员',
  }) => PersonalMember(
    accountId: '0x${hexOf(account)}',
    familyName: familyName,
    givenName: givenName,
  );

  List<int> u32Le(int value) => [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];

  List<int> u128Le(BigInt value) {
    final out = List<int>.filled(16, 0);
    var tmp = value;
    for (var i = 0; i < 16; i++) {
      out[i] = (tmp & BigInt.from(0xff)).toInt();
      tmp = tmp >> 8;
    }
    return out;
  }

  Uint8List personalAccountBytes() {
    return Uint8List.fromList([
      ...List<int>.filled(32, 0xc2),
      ...compactVec('家庭基金'),
      ...u32Le(100),
      1,
    ]);
  }

  Uint8List adminAccountBytes({
    required List<int> admin1,
    required List<int> admin2,
  }) {
    return Uint8List.fromList([
      ...codeBytes('PMUL'),
      2, // AdminAccountKind::PersonalMultisig
      (2 << 2) & 0xff,
      ...adminBytes(admin1, familyName: '张', givenName: '三'),
      ...adminBytes(admin2, familyName: '李', givenName: '四'),
      ...List<int>.filled(32, 0x44), // creator
      ...u32Le(100), // created_at
      ...u32Le(101), // updated_at
      1, // Active
    ]);
  }

  group('PersonalManageService', () {
    test(
      'builds propose_create_personal call_data with regular_threshold',
      () async {
        final admin1 = Uint8List.fromList(List<int>.filled(32, 0x11));
        final admin2 = Uint8List.fromList(List<int>.filled(32, 0x22));
        final accountName = Uint8List.fromList(utf8.encode('家庭基金'));

        final callData =
            await PersonalManageService.buildProposeCreatePersonalCallData(
              buildCall: buildCall,
              accountName: accountName,
              admins: [
                adminPerson(admin1, familyName: '张', givenName: '三'),
                adminPerson(admin2, familyName: '李', givenName: '四'),
              ],
              regularThreshold: 2,
              amountFen: BigInt.from(111),
            );

        final expected = <int>[
          0x07,
          0x00,
          ...compactVec('家庭基金'),
          (2 << 2) & 0xff,
          ...adminBytes(admin1, familyName: '张', givenName: '三'),
          ...adminBytes(admin2, familyName: '李', givenName: '四'),
          ...u32Le(2),
          ...u128Le(BigInt.from(111)),
        ];

        expect(hexOf(callData), hexOf(expected));
      },
    );

    test('普通阈值接受1到成员数，拒绝0及超出成员数', () async {
      final admins = List.generate(
        4,
        (i) => adminPerson(List<int>.filled(32, 0x10 + i)),
      );
      for (final threshold in [1, 2, 3, 4]) {
        final data =
            await PersonalManageService.buildProposeCreatePersonalCallData(
              buildCall: buildCall,
              accountName: Uint8List.fromList(utf8.encode('家庭基金')),
              admins: admins,
              regularThreshold: threshold,
              amountFen: BigInt.from(111),
            );
        expect(
          CitizenScale.readUnsigned(data, data.length - 20, 4).toInt(),
          threshold,
        );
      }
      for (final threshold in [0, 5]) {
        expect(
          () => PersonalManageService.buildProposeCreatePersonalCallData(
            buildCall: buildCall,
            accountName: Uint8List.fromList(utf8.encode('家庭基金')),
            admins: admins,
            regularThreshold: threshold,
            amountFen: BigInt.from(111),
          ),
          throwsArgumentError,
        );
      }
    });

    test('个人多签创建只确认本次执行的唯一业务事件', () async {
      final block = await PersonalmanageserviceFakeChain().getFinalizedHead();
      final signer = Uint8List.fromList(List<int>.filled(32, 0x11));
      final peer = List<int>.filled(32, 0x22);
      final account = List<int>.filled(32, 0x33);
      final admins = [
        adminPerson(signer, familyName: '张', givenName: '三'),
        adminPerson(peer, familyName: '李', givenName: '四'),
      ];
      List<int> event(int index, {int amount = 111}) => [
        0,
        ...u32Le(index),
        7,
        0,
        ...u128Le(BigInt.from(7)),
        ...account,
        ...signer,
        ...compactVec('家庭基金'),
        8,
        ...adminBytes(signer, familyName: '张', givenName: '三'),
        ...adminBytes(peer, familyName: '李', givenName: '四'),
        ...u32Le(2),
        ...u32Le(2),
        ...u128Le(BigInt.from(amount)),
        ...u128Le(BigInt.from(10)),
        ...u32Le(99),
        0,
      ];
      Future<
        ({
          String txHash,
          int usedNonce,
          BigInt proposalId,
          String accountId,
          String blockHash,
        })
      >
      submit(List<List<int>> rows) {
        final tx = TestCitizenTransactionFlow()
          ..prepare = ((_, _) async => CitizenPreparedTransaction(
            preparationId: 'prepared',
            sourceAccountId: signer,
            callDataHash: Uint8List(32),
            bestBlock: block,
            runtimeSpecNumber: 1,
            transactionFormatNumber: 1,
            nonce: BigInt.zero,
          ))
          ..execute = ((_) async => CitizenTransactionExecutionCompleted(
            executionId: 'prepared',
            sourceAccountId: signer,
            callDataHash: Uint8List(32),
            transactionHash: Uint8List(32),
            resolution: CitizenTransactionResolution.finalizedSuccess,
            execution: CitizenExecution(
              status: CitizenExecutionStatus.success,
              block: block,
              extrinsicIndex: 2,
              dispatchVariant: null,
              palletIndex: null,
              errorIndex: null,
            ),
            poolRejectionReason: null,
            replacementHash: null,
          ));
        final service = PersonalManageService(
          buildCall: buildCall,
          getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getSystemEvents: (ref) async {
            expect(ref, same(block));
            return Uint8List.fromList([
              rows.length << 2,
              for (final row in rows) ...row,
            ]);
          },
          prepareTransaction: tx.prepareTransaction,
          executePreparedTransaction: tx.executePreparedTransaction,
        );
        return service.submitProposeCreatePersonal(
          accountName: Uint8List.fromList(utf8.encode('家庭基金')),
          admins: admins,
          regularThreshold: 2,
          amountFen: BigInt.from(111),
          signerPublicKey: signer,
          externalSigning: (_) async => null,
        );
      }

      final result = await submit([event(1), event(2)]);
      expect(result.proposalId, BigInt.from(7));
      expect(result.accountId, '0x${hexOf(account)}');
      expect(result.blockHash, block.hash);
      await expectLater(submit([event(1)]), throwsStateError);
      await expectLater(submit([event(2), event(2)]), throwsStateError);
      await expectLater(submit([event(2, amount: 112)]), throwsStateError);
    });

    test('decodes current Personal create ProposalData', () {
      final service = (() {
        final reads0 = TestChainReads();
        final reads1 = TestTransactionCalls();
        return PersonalManageService(
          buildCall: buildCall,
          getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getSystemEvents: reads0.getSystemEvents,
          getFinalizedHead: reads0.getFinalizedHead,
          getStorage: reads0.getStorage,
          getStorageBatch: reads0.getStorageBatch,
          prepareTransaction: reads1.prepareTransaction,
          executePreparedTransaction: reads1.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              reads1.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              reads1.consumePreparedTransactionQrResponse,
        );
      })();
      final inner = <int>[
        ...utf8.encode('per-mgmt'),
        0x00,
        ...List<int>.filled(32, 0x33),
        ...List<int>.filled(32, 0x44),
        ...u128Le(BigInt.from(111)),
        ...u128Le(BigInt.from(10)),
      ];
      final raw = Uint8List.fromList([...compactU32(inner.length), ...inner]);

      final decoded = service.decodePersonalProposalData(BigInt.from(7), raw);

      expect(decoded, isA<CreateProposalInfo>());
      final info = decoded as CreateProposalInfo;
      expect(info.proposalId, BigInt.from(7));
      expect(info.accountId, '0x${'33' * 32}');
      expect(info.amountFen, BigInt.from(111));
      expect(info.feeAmount, BigInt.from(10));
    });

    test('fetchPersonalAccount reads Personal current storage', () async {
      final rpc = PersonalmanageserviceFakeChain();
      final service = (() {
        final reads0 = TestTransactionCalls();
        return PersonalManageService(
          buildCall: buildCall,
          getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getSystemEvents: rpc.getSystemEvents,
          getFinalizedHead: rpc.getFinalizedHead,
          getStorage: rpc.getStorage,
          getStorageBatch: rpc.getStorageBatch,
          prepareTransaction: reads0.prepareTransaction,
          executePreparedTransaction: reads0.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              reads0.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              reads0.consumePreparedTransactionQrResponse,
        );
      })();
      final accountId = '0x${'22' * 32}';
      final runtime = await CitizenSdkTestFixture.runtimeContext(
        await rpc.getFinalizedHead(),
      );
      final personalKey =
          '0x${hexOf(PersonalManageStorageCodec.personalAccountsKey(runtime, accountId))}';
      final adminKey =
          '0x${hexOf(PersonalManageStorageCodec.adminAccountKey(runtime, citizenAccountIdBytes(accountId)))}';
      final thresholdKey =
          '0x${hexOf(PersonalManageStorageCodec.activePersonalThresholdKey(runtime, citizenAccountIdBytes(accountId)))}';
      rpc.responses[personalKey] = personalAccountBytes();
      rpc.responses[adminKey] = adminAccountBytes(
        admin1: List<int>.filled(32, 0xcc),
        admin2: List<int>.filled(32, 0xdd),
      );
      rpc.responses[thresholdKey] = Uint8List.fromList(u32Le(2));

      final info = await service.fetchPersonalAccount(accountId);

      expect(info, isNotNull);
      expect(info!.admins.map((admin) => admin.accountId), [
        '0x${'cc' * 32}',
        '0x${'dd' * 32}',
      ]);
      expect(info.threshold, 2);
      expect(info.status, MultisigStatus.active);
      expect(rpc.requestedKeys, [personalKey, adminKey, thresholdKey]);
    });

    test(
      'fetchPersonalAccountsBatch reads accounts in staged storage batches',
      () async {
        final rpc = PersonalmanageserviceFakeChain();
        final service = (() {
          final reads0 = TestTransactionCalls();
          return PersonalManageService(
            buildCall: buildCall,
            getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getSystemEvents: rpc.getSystemEvents,
            getFinalizedHead: rpc.getFinalizedHead,
            getStorage: rpc.getStorage,
            getStorageBatch: rpc.getStorageBatch,
            prepareTransaction: reads0.prepareTransaction,
            executePreparedTransaction: reads0.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                reads0.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                reads0.consumePreparedTransactionQrResponse,
          );
        })();
        final firstAccountId = '0x${'22' * 32}';
        final secondAccountId = '0x${'33' * 32}';
        final runtime = await CitizenSdkTestFixture.runtimeContext(
          await rpc.getFinalizedHead(),
        );
        String personalKey(String accountId) =>
            '0x${hexOf(PersonalManageStorageCodec.personalAccountsKey(runtime, accountId))}';
        String adminKey(String accountId) =>
            '0x${hexOf(PersonalManageStorageCodec.adminAccountKey(runtime, citizenAccountIdBytes(accountId)))}';
        String thresholdKey(String accountId) =>
            '0x${hexOf(PersonalManageStorageCodec.activePersonalThresholdKey(runtime, citizenAccountIdBytes(accountId)))}';

        rpc.responses[personalKey(firstAccountId)] = personalAccountBytes();
        rpc.responses[personalKey(secondAccountId)] = personalAccountBytes();
        rpc.responses[adminKey(firstAccountId)] = adminAccountBytes(
          admin1: List<int>.filled(32, 0xaa),
          admin2: List<int>.filled(32, 0xbb),
        );
        rpc.responses[adminKey(secondAccountId)] = adminAccountBytes(
          admin1: List<int>.filled(32, 0xcc),
          admin2: List<int>.filled(32, 0xdd),
        );
        rpc.responses[thresholdKey(firstAccountId)] = Uint8List.fromList(
          u32Le(2),
        );

        final infos = await service.fetchPersonalAccountsBatch([
          firstAccountId,
          secondAccountId,
        ]);

        expect(infos[firstAccountId]!.admins.map((admin) => admin.accountId), [
          '0x${'aa' * 32}',
          '0x${'bb' * 32}',
        ]);
        expect(infos[secondAccountId]!.admins.map((admin) => admin.accountId), [
          '0x${'cc' * 32}',
          '0x${'dd' * 32}',
        ]);
        expect(infos[firstAccountId]!.threshold, 2);
        expect(infos[secondAccountId]!.threshold, isNull);
        expect(rpc.requestedKeys, [
          personalKey(firstAccountId),
          adminKey(firstAccountId),
          personalKey(secondAccountId),
          adminKey(secondAccountId),
          thresholdKey(firstAccountId),
          thresholdKey(secondAccountId),
        ]);
      },
    );
  });
}

// 原用例所属：personal/test/personal_manage_storage_codec_test.dart
// 验证个人多签地址和生命周期解码及管理员与阈值分离。

void _registerPersonalmanagestoragecodec() {
  List<int> codeBytes(String code) {
    final out = List<int>.filled(4, 0);
    final raw = code.codeUnits;
    for (var i = 0; i < out.length && i < raw.length; i++) {
      out[i] = raw[i];
    }
    return out;
  }

  List<int> compactVec(String text) {
    final bytes = utf8.encode(text);
    return [(bytes.length << 2) & 0xff, ...bytes];
  }

  List<int> u32Le(int value) => [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];

  List<int> adminBytes(
    List<int> account,
    String familyName,
    String givenName,
  ) => [...account, ...compactVec(familyName), ...compactVec(givenName)];

  group('PersonalManageStorageCodec', () {
    test('builds personal account id', () {
      final personal = citizenAccountIdBytes('0x${'11' * 32}');

      expect(personal.length, 32);
      expect(personal, List<int>.filled(32, 0x11));
    });

    test('decodes personal account state', () {
      final data = Uint8List.fromList([
        ...List<int>.filled(32, 0x66),
        ...compactVec('家庭基金'),
        ...u32Le(101),
        1,
      ]);

      final decoded = PersonalManageStorageCodec.decodePersonalAccount(data)!;
      expect(decoded.creatorAccount, '0x${'66' * 32}');
      expect(utf8.decode(decoded.accountName), '家庭基金');
      expect(decoded.createdAt, 101);
      expect(decoded.statusByte, 1);
    });

    test('decodes admin account without reading threshold from account', () {
      final admin1 = List<int>.filled(32, 0xaa);
      final admin2 = List<int>.filled(32, 0xbb);
      final data = Uint8List.fromList([
        ...codeBytes('PMUL'),
        2,
        (2 << 2) & 0xff,
        ...adminBytes(admin1, '张', '三'),
        ...adminBytes(admin2, '李', '四'),
        ...List<int>.filled(32, 0x44),
        ...u32Le(100),
        ...u32Le(101),
        1,
      ]);

      final decoded = PersonalManageStorageCodec.decodeAdminAccount(data)!;

      expect(decoded.orgCode, 'PMUL');
      expect(decoded.adminsLen, 2);
      expect(decoded.admins.map((admin) => admin.accountId), [
        '0x${'aa' * 32}',
        '0x${'bb' * 32}',
      ]);
      expect(decoded.admins.map((admin) => admin.familyName), ['张', '李']);
      expect(decoded.admins.map((admin) => admin.givenName), ['三', '四']);
    });
  });
}

// 原用例所属：citizen/test/shared/admin_accounts_scan_service_test.dart
// 验证管理员扫描结果按类型及本机钱包筛选个人多签。

void _registerAdminaccountsscanservice() {
  final myAccountId = '0x${'aa' * 32}';
  final otherAccountId = '0x${'bb' * 32}';
  final secondAccountId = '0x${'cc' * 32}';

  PersonalScanResult resultOf(List<PersonalScannedAccount> accounts) =>
      PersonalScanResult(
        accounts: accounts,
        totalKeys: accounts.length,
        partialFailure: false,
      );

  PersonalScannedAccount acc({
    required String key,
    required String orgCode,
    required int kind,
    required List<String> adminAccountIds,
  }) => PersonalScannedAccount(
    accountId: key,
    orgCode: orgCode,
    kind: kind,
    admins: adminAccountIds
        .map(
          (account) => PersonalMember(
            accountId: account,
            familyName: '管理',
            givenName: '员',
          ),
        )
        .toList(growable: false),
  );

  group('PersonalScanService.filterMine', () {
    test('按 kind 分流:只保留个人多签', () {
      final scan = resultOf([
        acc(
          key: 'invalid-kind-account',
          orgCode: 'CGOV',
          kind: 0,
          adminAccountIds: [myAccountId],
        ),
        acc(
          key: '02',
          orgCode: 'PMUL',
          kind: PersonalMemberStorageCodec.kindPersonal,
          adminAccountIds: [myAccountId],
        ),
      ]);

      final personals = PersonalScanService.filterMine(
        scan,
        myAccountIds: {myAccountId},
        kind: PersonalMemberStorageCodec.kindPersonal,
      );
      expect(personals.map((e) => e.accountId), ['02']);
    });

    test('institution_code 白名单:个人多签仍可按 PMUL 过滤', () {
      final scan = resultOf([
        acc(
          key: '01',
          orgCode: 'PMUL',
          kind: PersonalMemberStorageCodec.kindPersonal,
          adminAccountIds: [myAccountId],
        ),
        acc(
          key: '02',
          orgCode: 'XXXX',
          kind: PersonalMemberStorageCodec.kindPersonal,
          adminAccountIds: [myAccountId],
        ),
      ]);
      final result = PersonalScanService.filterMine(
        scan,
        myAccountIds: {myAccountId},
        kind: PersonalMemberStorageCodec.kindPersonal,
        codeWhitelist: const {'PMUL'},
      );
      expect(result.map((e) => e.accountId), ['01']);
    });

    test('钱包匹配:管理员不含本地钱包的账户被排除', () {
      final scan = resultOf([
        acc(
          key: '01',
          orgCode: 'PMUL',
          kind: PersonalMemberStorageCodec.kindPersonal,
          adminAccountIds: [myAccountId, otherAccountId],
        ),
        acc(
          key: '02',
          orgCode: 'PMUL',
          kind: PersonalMemberStorageCodec.kindPersonal,
          adminAccountIds: [otherAccountId],
        ),
      ]);
      final result = PersonalScanService.filterMine(
        scan,
        myAccountIds: {myAccountId},
        kind: PersonalMemberStorageCodec.kindPersonal,
      );
      expect(result.map((e) => e.accountId), ['01']);
    });

    test('多钱包:命中任一本地钱包即保留', () {
      final scan = resultOf([
        acc(
          key: '01',
          orgCode: 'PMUL',
          kind: PersonalMemberStorageCodec.kindPersonal,
          adminAccountIds: [secondAccountId],
        ),
      ]);
      final result = PersonalScanService.filterMine(
        scan,
        myAccountIds: {myAccountId, secondAccountId},
        kind: PersonalMemberStorageCodec.kindPersonal,
      );
      expect(result.map((e) => e.accountId), ['01']);
    });

    test('空扫描结果返回空', () {
      final result = PersonalScanService.filterMine(
        PersonalScanResult.empty,
        myAccountIds: {myAccountId},
        kind: 1,
        codeWhitelist: const {'CGOV', 'UNIN'},
      );
      expect(result, isEmpty);
    });
  });
}

void main() {
  group('personal_manage_service_test', _registerPersonalmanageservice);
  group(
    'personal_manage_storage_codec_test',
    _registerPersonalmanagestoragecodec,
  );
  group('admin_accounts_scan_service_test', _registerAdminaccountsscanservice);
  test('成员备注不参与账户派生，成员身份始终为同一钱包', () {
    final creator = Uint8List.fromList(List.filled(32, 7));
    final member = PersonalMember(
      accountId: '0x${'07' * 32}',
      familyName: '甲',
      givenName: '乙',
    );
    final before = derivePersonalAccountId(
      creatorAccount: creator,
      accountName: '共同账户',
    );
    final renamed = member.copyWith(familyName: '备注', givenName: '已修改');
    expect(renamed.accountId, member.accountId);
    expect(
      derivePersonalAccountId(
        creatorAccount: citizenAccountIdBytes(renamed.accountId),
        accountName: '共同账户',
      ),
      before,
    );
    expect(renamed.familyName, '备注');
  });
  group('个人生命周期确认', _registerLifecycleConfirmation);
  group('个人派生', _registerPersonalDerivation);
  group('个人主体隔离原回归', _registerMovedSubjectBoundaries);
  group('个人冻结快照原隔离断言', _registerPersonalSnapshotBoundary);
}

// 原冻结个人账户向量原值随所属功能迁入，不按实现推导期望值。
void _registerPersonalDerivation() {
  group('个人多签派生', () {
    test('派生字节遵循个人多签账户合同', () {
      final creator = Uint8List.fromList(List<int>.generate(32, (i) => i));
      expect(
        derivePersonalAccountId(creatorAccount: creator, accountName: '个人钱包'),
        deriveAccountId(
          opTag: kOpPersonal,
          payload: <int>[...creator, ...utf8.encode('个人钱包')],
        ),
      );
    });

    test('creator 非 32 字节抛错', () {
      expect(
        () => derivePersonalAccountId(
          creatorAccount: Uint8List(31),
          accountName: 'x',
        ),
        throwsArgumentError,
      );
    });
  });
  final vectors =
      (jsonDecode(r'''[
  {
    "account_id": "0x3bf667dd1e30b82ebf7e4f13ea914648f3dd13520f2627b1571988b3125e9ed3",
    "account_name": "我的多签",
    "creator_account_id": "0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20",
    "kind": "Personal",
    "source": "self-authored: 个人多签 creator_account_id+name(address 由 Rust 回填)"
  }
]''')
              as List)
          .cast<Map<String, dynamic>>();
  for (final row in vectors) {
    test('个人账户冻结向量 ${row['account_name']}', () {
      final text = (row['creator_account_id'] as String).replaceFirst(
        RegExp(r'^0x'),
        '',
      );
      final creator = Uint8List.fromList([
        for (var i = 0; i < text.length; i += 2)
          int.parse(text.substring(i, i + 2), radix: 16),
      ]);
      expect(
        citizenAccountIdFromBytes(
          derivePersonalAccountId(
            creatorAccount: creator,
            accountName: row['account_name'] as String,
          ),
        ),
        row['account_id'],
      );
    });
  }
}

void _registerMovedSubjectBoundaries() {
  test('个人主体键保持AccountId编码，不构造机构CID', () {
    final personalAccount = '0x${'ab' * 32}';
    final personalKey = PersonalProposalQueryService.personalAccountSubjectKey(
      personalAccount,
    );
    expect(personalKey, Uint8List.fromList([1, ...List.filled(32, 0xab)]));
  });
}

class PersonalBoundarySnapshotChain extends TestChainReads {
  PersonalBoundarySnapshotChain(this.value);

  final Uint8List value;
  String expectedKey = '';
  final List<String> storageKeys = [];

  @override
  Future<CitizenBlockRef> getFinalizedHead() async => CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.finalized,
  );

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    storageKeys.add(
      '0x${key.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}',
    );
    return storageKeys.last == expectedKey ? value : null;
  }
}

void _registerPersonalSnapshotBoundary() {
  test('个人冻结快照只按真实AccountId读取，错误主体不能获得同一快照', () async {
    final raw = Uint8List.fromList([4, ...List.filled(32, 0x33)]);
    final rpc = PersonalBoundarySnapshotChain(raw);
    final runtime = await CitizenSdkTestFixture.runtimeContext(
      await rpc.getFinalizedHead(),
    );
    final id = BigInt.from(7),
        account = '0x${'ab' * 32}',
        other = '0x${'cd' * 32}';
    rpc.expectedKey =
        '0x${runtime.storageKey('VotingEngine', 'AdminSnapshot', [
          id,
          (scale: Uint8List.fromList([1, ...List.filled(32, 0xab)])),
        ]).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final query = PersonalProposalQueryService(
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: rpc.getFinalizedHead,
      getStorage: rpc.getStorage,
      getStorageBatch: rpc.getStorageBatch,
    );
    expect(await query.fetchPersonalAdminSnapshot(id, account), [
      '0x${'33' * 32}',
    ]);
    await expectLater(
      query.fetchPersonalAdminSnapshot(id, other),
      throwsStateError,
    );
    expect(rpc.storageKeys, hasLength(2));
    expect(rpc.storageKeys.first, rpc.expectedKey);
    expect(rpc.storageKeys[0], isNot(rpc.storageKeys[1]));
  });
}

List<int> _lifecycleInt(BigInt value, int count) => [
  for (var i = 0; i < count; i++)
    ((value >> (8 * i)) & BigInt.from(255)).toInt(),
];
Uint8List _lifecycleVec(List<int> bytes) =>
    Uint8List.fromList([...CitizenScale.compact(bytes.length), ...bytes]);

/// 真实metadata负责存储键和事件解码，仅替换链读/交易资源边界。
class PersonalLifecycleFixture extends PersonalmanageserviceFakeChain {
  final account = '0x${'33' * 32}';
  final creator = '0x${'11' * 32}';
  final peer = '0x${'22' * 32}';
  final beneficiary = '0x${'44' * 32}';
  final pid = BigInt.from(77);
  final baseBlock = CitizenBlockRef(
    hash: '0x${'ab' * 32}',
    number: BigInt.from(10),
    finality: CitizenBlockFinality.finalized,
  );
  final finalBlock = CitizenBlockRef(
    hash: '0x${'ac' * 32}',
    number: BigInt.from(11),
    finality: CitizenBlockFinality.finalized,
  );
  CitizenBlockRef get block => status == 0 ? baseBlock : finalBlock;
  final tx = TestCitizenTransactionFlow();
  int status = 0;
  bool clearRecords = true;
  bool failCleanupRead = false;
  final failedKeys = <String>{};
  int ownerReads = 0;
  String? proposalKey;
  String? ownerKey;
  String? peerVoteKey;
  final pendingKeys = <String>[];
  Uint8List? events;
  Uint8List? signer;
  String key(List<int> bytes) =>
      '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  Uint8List proposalBytes() => Uint8List.fromList([
    0,
    0,
    status,
    1,
    ...'PMUL'.codeUnits,
    0,
    1,
    ...citizenAccountIdBytes(account),
    0,
    ..._lifecycleInt(BigInt.one, 4),
    ..._lifecycleInt(BigInt.from(99), 4),
  ]);
  @override
  Future<CitizenBlockRef> getFinalizedHead() async => block;
  @override
  Future<Uint8List?> getStorage(
    CitizenBlockRef ref,
    Uint8List storageKey,
  ) async {
    expectSync(ref.hash, block.hash);
    if (failedKeys.contains(key(storageKey))) {
      throw StateError('synthetic chain read failure');
    }
    if (key(storageKey) == proposalKey) {
      requestedKeys.add(key(storageKey));
      return proposalBytes();
    }
    if (key(storageKey) == ownerKey) ownerReads++;
    return super.getStorage(ref, storageKey);
  }

  @override
  Future<Uint8List?> getSystemEvents(CitizenBlockRef ref) async => events;
  Future<void> initialize({bool cold = false}) async {
    final runtime = await CitizenSdkTestFixture.runtimeContext(block);
    String storage(String pallet, String entry, List<Object> fields) =>
        key(runtime.storageKey(pallet, entry, fields));
    proposalKey = storage('VotingEngine', 'Proposals', [pid]);
    ownerKey = storage('VotingEngine', 'ProposalOwner', [pid]);
    responses[ownerKey!] = _lifecycleVec('per-mgmt'.codeUnits);
    final action = [
      ...citizenAccountIdBytes(account),
      ...citizenAccountIdBytes(creator),
      ..._lifecycleInt(BigInt.from(111), 16),
      ..._lifecycleInt(BigInt.from(10), 16),
    ];
    responses[storage('VotingEngine', 'ProposalData', [pid])] = _lifecycleVec([
      ...'per-mgmt'.codeUnits,
      0,
      ...action,
    ]);
    responses[storage('VotingEngine', 'AdminSnapshot', [
      pid,
      (scale: PersonalProposalQueryService.personalAccountSubjectKey(account)),
    ])] = Uint8List.fromList([
      8,
      ...citizenAccountIdBytes(creator),
      ...citizenAccountIdBytes(peer),
    ]);
    String voteKey(String account) =>
        storage('InternalVote', 'InternalVotesByTicket', [
          pid,
          (variant: 'Personal', fields: [citizenAccountIdBytes(account)]),
        ]);
    responses[voteKey(creator)] = Uint8List.fromList([1]);
    peerVoteKey = voteKey(peer);
    pendingKeys.addAll([
      storage('Personal', 'PendingPersonalCreate', [pid]),
      storage('Personal', 'PersonalAccounts', [citizenAccountIdBytes(account)]),
      storage('Personal', 'AdminAccounts', [citizenAccountIdBytes(account)]),
    ]);
    responses[pendingKeys[0]] = Uint8List.fromList(action);
    responses[pendingKeys[1]] = Uint8List.fromList([
      ...citizenAccountIdBytes(creator),
      4,
      120,
      ..._lifecycleInt(BigInt.one, 4),
      0,
    ]);
    final members = [
      for (final id in [creator, peer]) ...[
        ...citizenAccountIdBytes(id),
        4,
        102,
        4,
        103,
      ],
    ];
    responses[pendingKeys[2]] = Uint8List.fromList([
      ...'PMUL'.codeUnits,
      2,
      8,
      ...members,
      ...citizenAccountIdBytes(creator),
      ..._lifecycleInt(BigInt.one, 4),
      ..._lifecycleInt(BigInt.one, 4),
      0,
    ]);
    CitizenTransactionExecutionCompleted complete() {
      status = 2;
      responses[peerVoteKey!] = Uint8List.fromList([0]);
      if (clearRecords) {
        for (final key in pendingKeys) {
          responses.remove(key);
        }
      }
      if (failCleanupRead) failedKeys.add(pendingKeys.first);
      events = Uint8List.fromList([
        4,
        0,
        ..._lifecycleInt(BigInt.from(2), 4),
        20,
        0,
        ..._lifecycleInt(pid, 16),
        ...signer!,
        0,
        0,
        0,
      ]);
      return CitizenTransactionExecutionCompleted(
        executionId: 'execute',
        sourceAccountId: signer!,
        callDataHash: Uint8List(32),
        transactionHash: Uint8List(32),
        resolution: CitizenTransactionResolution.finalizedSuccess,
        execution: CitizenExecution(
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
    }

    tx.prepare = ((source, call) async {
      signer = source;
      return CitizenPreparedTransaction(
        preparationId: 'prepared',
        sourceAccountId: source,
        callDataHash: Uint8List(32),
        bestBlock: block,
        runtimeSpecNumber: 1,
        transactionFormatNumber: 1,
        nonce: BigInt.zero,
      );
    });
    tx.execute = ((_) async => cold
        ? CitizenTransactionExternalSigningPending(
            executionId: 'execute',
            sourceAccountId: signer!,
            callDataHash: Uint8List(32),
            qrRequest: 'synthetic-request',
            expiresAt: DateTime.utc(2030),
          )
        : complete());
    tx.consume = ((_, response) async {
      expectSync(response, 'response');
      return complete();
    });
    tx.cancel = ((_) async {});
  }

  PersonalManageService service() => PersonalManageService(
    buildCall: (pallet, method, fields) async =>
        (await CitizenSdkTestFixture.runtimeContext(
          block,
        )).encodeCall(pallet, method, fields),
    getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
    getFinalizedHead: getFinalizedHead,
    getStorage: getStorage,
    getStorageBatch: getStorageBatch,
    getSystemEvents: getSystemEvents,
    prepareTransaction: tx.prepareTransaction,
    executePreparedTransaction: tx.executePreparedTransaction,
    cancelPreparedTransactionExecution: tx.cancelPreparedTransactionExecution,
    consumePreparedTransactionQrResponse:
        tx.consumePreparedTransactionQrResponse,
  );
}

void _registerLifecycleConfirmation() {
  for (final cold in [false, true]) {
    test('撤销创建只选未投票成员并使用统一冷热签：$cold', () async {
      final fixture = PersonalLifecycleFixture();
      await fixture.initialize(cold: cold);
      final service = fixture.service();
      expect(await service.pendingCreateVoters(fixture.account, fixture.pid), [
        fixture.peer,
      ]);
      await expectLater(
        service.revokeCreate(
          accountId: fixture.account,
          proposalId: fixture.pid,
          signerPublicKey: citizenAccountIdBytes(fixture.creator),
          externalSigning: (_) async => 'response',
        ),
        throwsStateError,
      );
      expect(fixture.tx.prepareCount, 0);
      expect(
        await service.revokeCreate(
          accountId: fixture.account,
          proposalId: fixture.pid,
          signerPublicKey: citizenAccountIdBytes(fixture.peer),
          externalSigning: (_) async => 'response',
        ),
        isTrue,
      );
      expect(fixture.tx.prepareCount, 1);
      expect(fixture.tx.executeCount, 1);
      expect(fixture.tx.consumeCount, cold ? 1 : 0);
      expect(fixture.ownerReads, greaterThanOrEqualTo(2));
      await expectLater(
        service.revokeCreate(
          accountId: fixture.account,
          proposalId: fixture.pid,
          signerPublicKey: citizenAccountIdBytes(fixture.peer),
          externalSigning: (_) async => 'response',
        ),
        throwsStateError,
      );
      expect(fixture.tx.prepareCount, 1);
    });
  }
  test('否决未清理、清理读取失败或错误主体不允许删除本机记录', () async {
    final fixture = PersonalLifecycleFixture();
    await fixture.initialize();
    fixture.clearRecords = false;
    expect(
      await fixture.service().revokeCreate(
        accountId: fixture.account,
        proposalId: fixture.pid,
        signerPublicKey: citizenAccountIdBytes(fixture.peer),
        externalSigning: (_) async => 'response',
      ),
      isFalse,
    );
    fixture.failedKeys.add(fixture.pendingKeys.first);
    await expectLater(
      fixture.service().createRejectedAndCleared(fixture.account, fixture.pid),
      throwsStateError,
    );
    fixture.failedKeys.clear();
    fixture.responses[fixture.ownerKey!] = _lifecycleVec('multisig'.codeUnits);
    await expectLater(
      fixture.service().createRejectedAndCleared(fixture.account, fixture.pid),
      throwsStateError,
    );
    final other = '0x${'55' * 32}';
    await expectLater(
      fixture.service().pendingCreateVoters(other, fixture.pid),
      throwsStateError,
    );
  });
  test('冷签取消不投票、不清理待建记录', () async {
    final fixture = PersonalLifecycleFixture();
    await fixture.initialize(cold: true);
    await expectLater(
      fixture.service().revokeCreate(
        accountId: fixture.account,
        proposalId: fixture.pid,
        signerPublicKey: citizenAccountIdBytes(fixture.peer),
        externalSigning: (_) async => null,
      ),
      throwsStateError,
    );
    expect(fixture.status, 0);
    expect(fixture.tx.cancelCount, 1);
    expect(fixture.responses[fixture.pendingKeys.first], isNotNull);
  });
  test('注销取本次唯一事件中的真实编号，拒绝缺失、重复、串单和失败执行', () async {
    for (final failure in [
      'none',
      'missing',
      'duplicate',
      'account',
      'beneficiary',
      'signer',
      'other-extrinsic',
      'execution',
    ]) {
      final fixture = PersonalLifecycleFixture();
      await fixture.initialize();
      final source = citizenAccountIdBytes(fixture.peer);
      List<int> event(int extrinsic) => [
        0,
        ..._lifecycleInt(BigInt.from(extrinsic), 4),
        7,
        4,
        ..._lifecycleInt(BigInt.from(991), 16),
        ...citizenAccountIdBytes(
          failure == 'account' ? fixture.creator : fixture.account,
        ),
        ...citizenAccountIdBytes(
          failure == 'signer' ? fixture.creator : fixture.peer,
        ),
        ...citizenAccountIdBytes(
          failure == 'beneficiary' ? fixture.creator : fixture.beneficiary,
        ),
        0,
      ];
      final rows = failure == 'missing'
          ? <List<int>>[]
          : [
              event(failure == 'other-extrinsic' ? 1 : 2),
              if (failure == 'duplicate') event(2),
            ];
      fixture.events = Uint8List.fromList([
        rows.length << 2,
        for (final row in rows) ...row,
      ]);
      fixture.tx.execute = ((_) async => CitizenTransactionExecutionCompleted(
        executionId: 'execute',
        sourceAccountId: source,
        callDataHash: Uint8List(32),
        transactionHash: Uint8List(32),
        resolution: CitizenTransactionResolution.finalizedSuccess,
        execution: failure == 'execution'
            ? null
            : CitizenExecution(
                status: CitizenExecutionStatus.success,
                block: fixture.block,
                extrinsicIndex: 2,
                dispatchVariant: null,
                palletIndex: null,
                errorIndex: null,
              ),
        poolRejectionReason: null,
        replacementHash: null,
      ));
      final result = fixture.service().submitProposeClosePersonal(
        accountId: fixture.account,
        beneficiaryAddress: citizenSs58FromAccountId(fixture.beneficiary),
        signerPublicKey: source,
        externalSigning: (_) async => null,
      );
      if (failure == 'none') {
        expect((await result).proposalId, BigInt.from(991));
      } else {
        await expectLater(result, throwsStateError);
      }
      final runtime = await CitizenSdkTestFixture.runtimeContext(fixture.block);
      expect(
        fixture.requestedKeys,
        isNot(
          contains(
            fixture.key(
              runtime.storageKey('VotingEngine', 'NextProposalId', []),
            ),
          ),
        ),
      );
    }
  });
}
