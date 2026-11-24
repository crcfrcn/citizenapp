import 'package:flutter/material.dart';
// 个人多签members功能回归，保留迁入用例和断言。

import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_personal/accounts.dart';
import 'package:citizen_personal/chain.dart';
import 'package:citizen_personal/members.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/polkadart.dart' show Hasher;

// 原用例所属：citizen/test/administrators/admin_set_change_service_test.dart
// 验证个人成员容量与1..N普通阈值、冷热执行及失败或取消的资源释放。

final signer = Uint8List.fromList(List.filled(32, 1));
final block = CitizenBlockRef(
  hash: '0x${'ab' * 32}',
  number: BigInt.from(50),
  finality: CitizenBlockFinality.finalized,
);
Future<Uint8List> buildCall(
  String pallet,
  String method,
  Object fields,
) async => (await CitizenSdkTestFixture.runtimeContext(
  block,
)).encodeCall(pallet, method, fields);

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

PersonalMember person(int n) => PersonalMember(
  accountId: '0x${n.toRadixString(16).padLeft(2, '0') * 32}',
  familyName: '测试',
  givenName: '管理员',
);
PersonalMemberState account({int status = 1}) => PersonalMemberState(
  accountId: '0x${'09' * 32}',
  orgCode: 'PMUL',
  kind: 2,
  admins: [person(1), person(2)],
  threshold: 2,
  personalStatus: status,
);
void _registerAdminsetchangeservice() {
  test('管理员64人可选1到64阈值，65人及非法阈值拒绝', () async {
    final service = (() {
      final reads0 = TestTransactionCalls();
      return PersonalMembersService(
        buildCall: buildCall,
        prepareTransaction: reads0.prepareTransaction,
        executePreparedTransaction: reads0.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            reads0.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            reads0.consumePreparedTransactionQrResponse,
      );
    })();
    expect(
      await service.buildCallData(
        account: account(),
        proposerAccountId: person(1).accountId,
        admins: List.generate(64, (i) => person(i + 1)),
        newThreshold: 33,
      ),
      isNotEmpty,
    );
    for (final values in [(64, 0), (64, 65), (65, 33)]) {
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

  for (final threshold in [1, 32, 64]) {
    test('64人成员阈值$threshold合法', () async {
      final data = await PersonalMembersService(buildCall: buildCall)
          .buildCallData(
            account: account(),
            proposerAccountId: person(1).accountId,
            admins: List.generate(64, (i) => person(i + 1)),
            newThreshold: threshold,
          );
      expect(
        CitizenScale.readUnsigned(data, data.length - 4, 4).toInt(),
        threshold,
      );
    });
  }
  test('仅改阈值允许，成员备注和阈值完全相同才拒绝', () async {
    final service = PersonalMembersService(buildCall: buildCall);
    final current = account();
    expect(
      await service.buildCallData(
        account: current,
        proposerAccountId: person(1).accountId,
        admins: current.admins,
        newThreshold: 1,
      ),
      isNotEmpty,
    );
    expect(
      () => service.buildCallData(
        account: current,
        proposerAccountId: person(1).accountId,
        admins: current.admins.reversed.toList(),
        newThreshold: 2,
      ),
      throwsStateError,
    );
  });
  for (final cold in [false, true]) {
    test('管理员集合变更冷热签沿SDK唯一生命周期：$cold', () async {
      final tx = flow(cold: cold);
      final result =
          await PersonalMembersService(
            buildCall: buildCall,
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
      expect(tx.callData!.take(2), [7, 3]);
      expect(tx.prepareCount, 1);
      expect(tx.consumeCount, cold ? 1 : 0);
    });
  }
  for (final kind in [
    'duplicate',
    'count',
    'threshold',
    'threshold-overflow',
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
        PersonalMembersService(
          buildCall: buildCall,
          prepareTransaction: tx.prepareTransaction,
          executePreparedTransaction: tx.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              tx.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              tx.consumePreparedTransactionQrResponse,
        ).submit(
          account: account(status: kind == 'inactive' ? 0 : 1),
          admins: admins,
          newThreshold: kind == 'threshold'
              ? 0
              : kind == 'threshold-overflow'
              ? 3
              : 2,
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
  test('取消与冷签异常释放原执行，未返回完整执行不能报成功', () async {
    for (final fail in ['cancel', 'callback', 'consume', 'missing', 'failed']) {
      final tx = flow(
        cold: ['cancel', 'callback', 'consume'].contains(fail),
        result: completed(
          missing: fail == 'missing',
          resolution: fail == 'failed'
              ? CitizenTransactionResolution.finalizedFailed
              : CitizenTransactionResolution.finalizedSuccess,
        ),
      );
      if (fail == 'consume') {
        tx.consume = (_, _) async => throw StateError('合成响应消费失败');
      }
      await expectLater(
        PersonalMembersService(
          buildCall: buildCall,
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
            return fail == 'consume' ? 'synthetic-response' : null;
          },
        ),
        throwsStateError,
      );
      expect(
        tx.cancelCount,
        ['cancel', 'callback', 'consume'].contains(fail) ? 1 : 0,
      );
    }
  });
}

// 原用例所属：citizen/test/administrators/admins_change_codec_test.dart
// 验证个人成员账户与备注姓名的三字段布局。

void _registerAdminschangecodec() {
  List<int> bytes(String text) => [
    (utf8.encode(text).length << 2),
    ...utf8.encode(text),
  ];
  List<int> code(String value) => [
    ...value.codeUnits,
    ...List.filled(4 - value.length, 0),
  ];
  List<int> u32(int value) => [value, 0, 0, 0];
  List<int> admin(String familyName, String givenName, int accountByte) => [
    ...List.filled(32, accountByte),

    ...bytes(familyName),
    ...bytes(givenName),
  ];
  PersonalMember person(
    String accountId,
    String familyName,
    String givenName,
  ) => PersonalMember(
    accountId: accountId,
    familyName: familyName,
    givenName: givenName,
  );

  test('个人多签继续解码独立账户布局', () {
    final accountId = Uint8List.fromList(List.filled(32, 9));
    final value = Uint8List.fromList([
      ...code('PMUL'),
      2,
      8,
      ...admin('张', '三', 1),
      ...admin('李', '四', 2),
      ...List.filled(32, 3),
      ...u32(7),
      ...u32(9),
      1,
    ]);
    final decoded = PersonalMemberCodec.decodePersonal(accountId, value)!;
    expect(decoded.admins.map((admin) => admin.accountId), [
      '0x${'01' * 32}',
      '0x${'02' * 32}',
    ]);
    expect(decoded.personalCreatorAccountId, '0x${'03' * 32}');
  });

  test('个人多签管理员集合校验仍按钱包账户运行', () {
    final account = PersonalMemberState(
      accountId: '0x${'11' * 32}',
      orgCode: 'PMUL',
      kind: 2,
      admins: [
        person('0x${'aa' * 32}', '张', '三'),
        person('0x${'bb' * 32}', '李', '四'),
      ],
      threshold: 2,
      personalCreatorAccountId: '0x${'aa' * 32}',
      personalCreatedAt: 1,
      personalUpdatedAt: 1,
      personalStatus: 1,
    );
    final normalized = PersonalMembersValidation.validate(
      account: account,
      proposerAccountId: '0x${'aa' * 32}',
      admins: [
        person('0x${'aa' * 32}', '张', '三'),
        person('0x${'cc' * 32}', '管理', '员'),
      ],
      newThreshold: 2,
    );
    expect(normalized.admins.map((admin) => admin.accountId), [
      '0x${'aa' * 32}',
      '0x${'cc' * 32}',
    ]);
  });

  test('个人多签管理员更换载荷逐字段编码账户、姓、名', () async {
    final accountId = Uint8List.fromList(List.filled(32, 9));
    final runtime = await CitizenSdkTestFixture.runtimeContext(
      CitizenBlockRef(
        hash: '0x${'11' * 32}',
        number: BigInt.one,
        finality: CitizenBlockFinality.finalized,
      ),
    );
    final callData = await PersonalMembersCallCodec.build(
      buildCall: (pallet, method, fields) async =>
          runtime.encodeCall(pallet, method, fields),
      orgCode: 'PMUL',
      adminKind: 2,
      accountId: accountId,
      admins: [
        person('0x${'01' * 32}', '张', '三'),
        person('0x${'02' * 32}', '管理', '员'),
      ],
      newThreshold: 2,
    );

    expect(
      callData,
      Uint8List.fromList([
        7,
        3,
        ...code('PMUL'),
        ...accountId,
        8,
        ...admin('张', '三', 1),
        ...admin('管理', '员', 2),
        ...u32(2),
      ]),
    );
  });
}

// 原用例所属：citizen/test/administrators/institution_admin_service_test.dart
// 验证个人成员名册、阈值读取和缓存隔离。

Uint8List _memberKey(Uint8List bytes) =>
    Uint8List.fromList([...Hasher.blake2b128.hash(bytes), ...bytes]);

Uint8List _personalStorageKey(Uint8List account) => Uint8List.fromList([
  ...Hasher.twoxx128.hashString('Personal'),
  ...Hasher.twoxx128.hashString('AdminAccounts'),
  ..._memberKey(account),
]);

class PersonalMemberTestChain extends TestChainReads {
  final Map<String, Uint8List?> responses = {};
  final List<String> requestedKeys = [];
  final Set<String> failedKeys = {};
  final Map<String, List<Uint8List>> scanKeys = {};
  final queued = <String, List<Future<Uint8List?> Function()>>{};
  int scans = 0;
  int finalizedReads = 0;
  bool advanceHeads = false;
  bool scanFailure = false;
  bool batchFailure = false;
  final scanBlocks = <String>[];
  final batchBlocks = <String>[];
  final batchSizes = <int>[];

  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    finalizedReads++;
    return CitizenBlockRef(
      hash: advanceHeads
          ? '0x${finalizedReads.toRadixString(16).padLeft(64, '0')}'
          : '0x${'11' * 32}',
      number: advanceHeads ? BigInt.from(finalizedReads) : BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    final storageKeyHex =
        '0x${key.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    requestedKeys.add(storageKeyHex);
    if (queued[storageKeyHex]?.isNotEmpty == true) {
      return queued[storageKeyHex]!.removeAt(0)();
    }
    if (failedKeys.contains(storageKeyHex)) throw StateError('合成人员/阈值读取失败');
    return responses[storageKeyHex];
  }

  @override
  Future<List<Uint8List>> getStorageKeysPaged(
    CitizenBlockRef block,
    Uint8List prefix, {
    Uint8List? startKey,
    int limit = 256,
  }) async {
    scans++;
    scanBlocks.add(block.hash);
    if (scanFailure) throw StateError('合成岗位读取失败');
    int compare(Uint8List a, Uint8List b) {
      for (var i = 0; i < a.length && i < b.length; i++) {
        if (a[i] != b[i]) return a[i].compareTo(b[i]);
      }
      return a.length.compareTo(b.length);
    }

    final keys = [
      ...?scanKeys['0x${prefix.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}'],
    ]..sort(compare);
    return keys
        .where((key) => startKey == null || compare(key, startKey) > 0)
        .take(limit)
        .toList();
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async {
    batchBlocks.add(block.hash);
    batchSizes.add(keys.length);
    if (batchFailure) throw StateError('合成岗位批取失败');
    return [
      for (final key in keys)
        responses['0x${key.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}'],
    ];
  }
}

void _registerPersonalMemberReads() {
  useIsolatedIsar();
  setUp(
    () => (() {
      final reads0 = TestChainReads();
      return PersonalMemberService(
        getFinalizedHead: reads0.getFinalizedHead,
        getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getStorage: reads0.getStorage,
      );
    })().clearCache(),
  );
  String hexOf(Iterable<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  List<int> codeBytes(String code) => [
    ...code.codeUnits,
    ...List.filled(4 - code.length, 0),
  ];

  List<int> u32Le(int value) => [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];

  Uint8List personalAdminBytes({required List<int> admin}) {
    final familyBytes = utf8.encode('管理');
    final givenBytes = utf8.encode('员');
    return Uint8List.fromList([
      ...codeBytes('PMUL'),
      2,
      4,
      ...admin,

      familyBytes.length << 2,
      ...familyBytes,
      givenBytes.length << 2,
      ...givenBytes,
      ...List<int>.filled(32, 0xcc),
      ...u32Le(1),
      ...u32Le(2),
      1,
    ]);
  }

  String thresholdKey({
    required String palletName,
    required String storageName,
    required Uint8List keyData,
  }) {
    final bytes = <int>[
      ...Hasher.twoxx128.hashString(palletName),
      ...Hasher.twoxx128.hashString(storageName),
      ..._memberKey(keyData),
    ];
    return '0x${hexOf(bytes)}';
  }

  test('个人查询身份不能作为机构查询身份', () {
    final personal = PersonalMemberIdentity.personalAccount(
      accountId: '0x${'01' * 32}',
      accountLabel: '合成个人',
    );
    expect(personal, isNot(isA<AdminAccountIdentity>()));
  });

  test('个人多签严格按 personal_account_id 路由', () async {
    final rpc = PersonalMemberTestChain();
    final service = PersonalMemberService(
      getFinalizedHead: rpc.getFinalizedHead,
      getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getStorage: rpc.getStorage,
    );
    final accountId = '0x${'22' * 32}';
    final accountIdBytes = citizenAccountIdBytes(accountId);
    final accountKey = '0x${hexOf(_personalStorageKey(accountIdBytes))}';
    final thresholdStorageKey = thresholdKey(
      palletName: 'InternalVote',
      storageName: 'ActivePersonalThresholds',
      keyData: accountIdBytes,
    );
    rpc.responses[accountKey] = personalAdminBytes(
      admin: List<int>.filled(32, 0xbb),
    );
    rpc.responses[thresholdStorageKey] = Uint8List.fromList(u32Le(2));

    final identity = PersonalMemberIdentity.personalAccount(
      accountId: accountId,
      accountLabel: '个人多签',
    );
    expect(
      (await service.fetchAdmins(identity)).map((admin) => admin.accountId),
      ['0x${'bb' * 32}'],
    );
    expect(await service.fetchThreshold(identity), 2);
    expect(rpc.requestedKeys, [accountKey, thresholdStorageKey]);
  });

  test('管理员缓存按明确 identity key 隔离并可清除', () async {
    final rpc = PersonalMemberTestChain();
    final service = PersonalMemberService(
      getFinalizedHead: rpc.getFinalizedHead,
      getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getStorage: rpc.getStorage,
    );
    final accountId = '0x${'33' * 32}';
    final accountIdBytes = citizenAccountIdBytes(accountId);
    final identity = PersonalMemberIdentity.personalAccount(
      accountId: accountId,
      accountLabel: '个人多签',
    );
    final accountKey = '0x${hexOf(_personalStorageKey(accountIdBytes))}';
    final thresholdStorageKey = thresholdKey(
      palletName: 'InternalVote',
      storageName: 'ActivePersonalThresholds',
      keyData: accountIdBytes,
    );
    rpc.responses[accountKey] = personalAdminBytes(
      admin: List<int>.filled(32, 0xdd),
    );
    rpc.responses[thresholdStorageKey] = Uint8List.fromList(u32Le(2));

    await service.fetchByIdentity(identity);
    await service.fetchByIdentity(identity);
    expect(rpc.requestedKeys, [accountKey, thresholdStorageKey]);

    service.clearCache(identity);
    await service.fetchByIdentity(identity);
    expect(rpc.requestedKeys, [
      accountKey,
      thresholdStorageKey,
      accountKey,
      thresholdStorageKey,
    ]);
  });

  test('个人账户解析为明确的个人查询身份', () {
    final personalAccount = '0x${'44' * 32}';
    final personal = PersonalMemberIdentity.fromAccount(
      PersonalAccountInfo(
        fullName: '个人账户',
        shortName: '个人账户',

        accountId: personalAccount,
      ),
    );
    expect(personal, isA<PersonalMemberIdentity>());
    expect(personal.accountId, personalAccount);
  });
}

// 原用例所属：citizen/test/shared/admin_account_storage_codec_test.dart
// 以冻结字节验证个人成员布局、数量和截断边界。

void _registerAdminaccountstoragecodec() {
  List<int> codeBytes(String code) {
    final out = List<int>.filled(4, 0);
    final raw = code.codeUnits;
    for (var i = 0; i < out.length && i < raw.length; i++) {
      out[i] = raw[i];
    }
    return out;
  }

  List<int> scaleBytes(String text) {
    final raw = utf8.encode(text);
    return [raw.length << 2, ...raw];
  }

  List<int> adminBytes(
    String familyName,
    String givenName,
    List<int> account,
  ) => [...account, ...scaleBytes(familyName), ...scaleBytes(givenName)];

  group('tryDecode', () {
    test('成功解码 Personal 三字段成员布局', () {
      final a1 = List.filled(32, 0x11);
      final a2 = List.filled(32, 0x22);
      final a3 = List.filled(32, 0x33);
      final bytes = Uint8List.fromList([
        ...codeBytes('PMUL'),
        PersonalMemberStorageCodec.kindPersonal,
        0x0C, // Compact(3): (3<<2) | 0 = 12
        ...adminBytes('张', '三', a1),
        ...adminBytes('李', '四', a2),
        ...adminBytes('管理', '员', a3),
        ...List.filled(32, 0x44),
        ...List.filled(8, 0),
        1,
      ]);
      final r = PersonalMemberStorageCodec.tryDecode(
        bytes,
        kind: PersonalMemberStorageCodec.kindPersonal,
      )!;
      expect(r.orgCode, 'PMUL');
      expect(r.kind, PersonalMemberStorageCodec.kindPersonal);
      expect(r.admins.map((admin) => admin.accountId), [
        '0x${'11' * 32}',
        '0x${'22' * 32}',
        '0x${'33' * 32}',
      ]);
    });

    test('字节不足返回 null,不抛异常', () {
      expect(
        PersonalMemberStorageCodec.tryDecode(Uint8List(0), kind: 0),
        isNull,
      );
      expect(
        PersonalMemberStorageCodec.tryDecode(
          Uint8List.fromList([0]),
          kind: PersonalMemberStorageCodec.kindPersonal,
        ),
        isNull,
      );
    });

    test('Compact 64 admins (mode=1 两字节长度)', () {
      const adminsLen = 64;
      final admins = List.generate(adminsLen, (_) => List.filled(32, 0xDD));
      final bytes = <int>[
        ...codeBytes('PMUL'),
        PersonalMemberStorageCodec.kindPersonal,
        0x01,
        0x01,
      ];
      for (var i = 0; i < admins.length; i++) {
        final account = List<int>.from(admins[i]);
        account[0] = i;
        bytes.addAll(adminBytes('管理', '员', account));
      }
      bytes.addAll(List.filled(32, 0xEE));
      bytes.addAll(List.filled(8, 0));
      bytes.add(1);
      final r = PersonalMemberStorageCodec.tryDecode(
        Uint8List.fromList(bytes),
        kind: PersonalMemberStorageCodec.kindPersonal,
      )!;
      expect(r.admins.length, adminsLen);
    });
  });

  group('storage key 主键提取', () {
    test('个人多签 storage key 末 32 字节 = personal_account_id', () {
      final key = Uint8List(32 + 16 + 32);
      for (var i = 48; i < key.length; i++) {
        key[i] = i - 48;
      }
      final accountId =
          PersonalMemberStorageCodec.extractPersonalAccountFromKey(key)!;
      expect(
        citizenAccountIdFromBytes(accountId),
        '0x000102030405060708090a0b0c0d0e0f'
        '101112131415161718191a1b1c1d1e1f',
      );
    });

    test('storage key 长度不足返回 null', () {
      expect(
        PersonalMemberStorageCodec.extractPersonalAccountFromKey(Uint8List(20)),
        isNull,
      );
    });
  });
}

void main() {
  testWidgets('迁入成员编辑器保留显示及删除交互', (tester) async {
    final people = [
      PersonalMember(
        accountId: '0x${'11' * 32}',
        familyName: '甲',
        givenName: '一',
      ),
      PersonalMember(
        accountId: '0x${'22' * 32}',
        familyName: '乙',
        givenName: '二',
      ),
    ];
    List<PersonalMember>? updated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PersonalMembersEditor(
              admins: people,
              onChanged: (value) => updated = value,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PersonalMembersEditor), findsOneWidget);
    final remove = find.byTooltip('移除');
    expect(remove, findsNWidgets(2));
    await tester.tap(remove.first);
    await tester.pump();
    expect(updated, hasLength(1));
    expect(updated!.single.accountId, people.last.accountId);
  });
  group('admin_set_change_service_test', _registerAdminsetchangeservice);
  group('admins_change_codec_test', _registerAdminschangecodec);
  group('个人成员读取', _registerPersonalMemberReads);
  group('admin_account_storage_codec_test', _registerAdminaccountstoragecodec);
}
