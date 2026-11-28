// 验证身份事实、最终块闭环、缓存及业务门禁。

import 'dart:async';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:citizen_user/identity/state.dart' show CidBusinessDecision, CidBusinessGate, CidBusinessStatus, FinalizedIdentity, FinalizedIdentityResolver, IdentityBadgeSnapshot, IdentityBadgeSnapshotStore, MyIdService, MyIdStatus, MyIdTier;
import 'package:citizen_chain/service.dart';
import 'package:citizen_user/context.dart' show CurrentUser, CurrentUserContext, IdentityBinding;
import 'package:citizen_user/identity/badge.dart' show CitizenServiceGate;
import 'package:citizen_network/auth.dart' show bytesToHex, hexToBytes;
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_storage/user.dart' as user_store show Identity;
import 'package:isar_community/isar.dart' hide byte;
import 'package:citizen_storage/user.dart';
import 'package:citizen_testing/database.dart';
import 'package:citizen_testing/chat/runtime.dart';
import 'package:citizen_system/security/access.dart';
import 'dart:convert';
import 'package:citizen_user/api.dart' show SquareSession;
import 'package:chat/chat.dart';
import 'package:citizen_user/identity/registration.dart' show generateCitizenCid, kCidInstitutionCitizen;
import 'package:citizen_citizen/public/store.dart' show AdminDivisionStore;
import 'package:citizen_user/identity/transaction.dart' show CitizenIdentityTransaction, SelfRebindAuthorizationContext;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;

void main() {
  group('cid_business_gate_test', suite75);
  group('finalized_identity_resolver_test', suite79);
  group('identity_badge_snapshot_store_test', suite80);
  group('myid_service_test', suite85);
}

// 验证CID就绪、未知与未注册区分及并发恢复和身份变化。

const accountId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const otherAccountId =
    '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const cidNumber = 'CN220-CTZN2-100000001-2026';
const genesisHash =
    '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

CitizenWalletStateAccount account(String id) => CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 0,
  accountIndex: 0,
  accountId: id,
  ss58Address: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
  name: '当前账户',
  createdAtMillis: BigInt.zero,
  isDefault: true,
);

const binding = IdentityBinding(
  genesisHash: genesisHash,
  cidNumber: cidNumber,
  bindRev: 1,
  accountId: accountId,
);

CitizenIdentityChainSnapshot snapshot() => CitizenIdentityChainSnapshot(
  cidNumber: cidNumber,
  accountId: Uint8List.fromList(List<int>.filled(32, 0xaa)),
  bindRev: 1,
  votingIdentity: null,
  candidateIdentity: null,
);

class _Current implements CurrentUserContext {
  CurrentUser? value;
  int invalidations = 0;
  _Current(this.value);

  @override
  Future<CurrentUser?> resolve() async => value;

  @override
  void invalidate() => invalidations++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Resolver implements FinalizedIdentityResolver {
  FinalizedIdentity? value;
  Completer<FinalizedIdentity?>? pending;
  bool fails = false;
  int reads = 0;
  _Resolver(this.value);

  @override
  Future<FinalizedIdentity?> resolve() async {
    reads++;
    if (fails) throw StateError('链状态不可用');
    if (pending != null) return pending!.future;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedGate implements CidBusinessGate {
  _FixedGate(this.decision);
  CidBusinessDecision decision;
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() async => decision;
}

void suite75() {
  test('链完整性失败不能因并发出现本地绑定而放行', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(null)..pending = Completer<FinalizedIdentity?>();
    final revision = ValueNotifier(0);
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: revision,
      synchronizeIdentity: (_) async => fail('不应同步失败结果'),
    );
    final result = gate.resolve();
    await Future<void>.delayed(Duration.zero);
    current.value = CurrentUser(account: account(accountId), binding: binding);
    revision.value++;
    resolver.pending!.completeError(
      const CitizenSdkException(
        code: CitizenSdkErrorCode.integrity,
        message: '合成完整性失败',
      ),
    );
    expect((await result).status, CidBusinessStatus.unavailable);
    revision.dispose();
  });

  test('并发同步已保存同一绑定时不误报不可用', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(null)..pending = Completer<FinalizedIdentity?>();
    final revision = ValueNotifier(0);
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: revision,
      synchronizeIdentity: (_) async => fail('不得重复保存已完成绑定'),
    );
    final result = gate.resolve();
    await Future<void>.delayed(Duration.zero);
    current.value = CurrentUser(account: account(accountId), binding: binding);
    revision.value++;
    resolver.pending!.complete(
      FinalizedIdentity(
        accountId: accountId,
        accountAddress: 'test',
        snapshot: snapshot(),
      ),
    );
    expect((await result).status, CidBusinessStatus.ready);
    revision.dispose();
  });

  for (final status in [
    CidBusinessStatus.unregistered,
    CidBusinessStatus.unavailable,
  ]) {
    testWidgets('${status.name} 不挂载公民服务业务内容', (tester) async {
      await tester.pumpWidget(
        Provider<CidBusinessGate>.value(
          value: _FixedGate(CidBusinessDecision(status)),
          child: const MaterialApp(
            home: CitizenServiceGate(
              title: '用户主页',
              description: '注册后即可查看用户主页。',
              child: Text('受保护的业务内容'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('受保护的业务内容'), findsNothing);
      if (status == CidBusinessStatus.unregistered) {
        expect(find.text('尚未注册'), findsOneWidget);
        expect(find.text('注册'), findsOneWidget);
      } else {
        expect(find.textContaining('暂时无法核实'), findsOneWidget);
        expect(find.text('注册'), findsNothing);
      }
    });
  }

  testWidgets('身份修订后统一引导与业务子页按新门禁结论切换', (tester) async {
    final gate = _FixedGate(
      const CidBusinessDecision(CidBusinessStatus.unregistered),
    );
    await tester.pumpWidget(
      Provider<CidBusinessGate>.value(
        value: gate,
        child: const MaterialApp(
          home: CitizenServiceGate(
            title: '内容详情',
            description: '注册后即可查看内容。',
            child: Text('已授权内容'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('尚未注册'), findsOneWidget);
    gate.decision = const CidBusinessDecision(
      CidBusinessStatus.ready,
      cidNumber: cidNumber,
    );
    gate.revision.value++;
    await tester.pump();
    await tester.pump();
    expect(find.text('已授权内容'), findsOneWidget);
    gate.decision = const CidBusinessDecision(CidBusinessStatus.unregistered);
    gate.revision.value++;
    await tester.pump();
    await tester.pump();
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.text('已授权内容'), findsNothing);
  });

  test('无钱包交给外层钱包门禁，不读链也不恢复绑定', () async {
    final current = _Current(null);
    final resolver = _Resolver(null);
    var restores = 0;
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {
        restores++;
      },
    );
    expect((await gate.resolve()).status, CidBusinessStatus.noWallet);
    expect(resolver.reads, 0);
    expect(restores, 0);
  });

  test('本机已有当前账户绑定时直接放行，不读取链或恢复绑定', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: binding),
    );
    final resolver = _Resolver(null)..fails = true;
    var restores = 0;
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {
        restores++;
      },
    );
    final decision = await gate.resolve();
    expect(decision.status, CidBusinessStatus.ready);
    expect(decision.cidNumber, cidNumber);
    expect(resolver.reads, 0);
    expect(restores, 0);
  });

  test('已核实未注册直接显示引导，不重复查链或同步', () async {
    final current = _Current(
      CurrentUser(
        account: account(accountId),
        binding: null,
        verifiedUnregistered: true,
      ),
    );
    final resolver = _Resolver(null)..fails = true;
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async => fail('已核实状态不应重新同步'),
    );
    expect((await gate.resolve()).status, CidBusinessStatus.unregistered);
    expect(resolver.reads, 0);
  });

  test('并发入口共用当前账户一次链核对', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(null)..pending = Completer<FinalizedIdentity?>();
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {},
    );
    final first = gate.resolve();
    final second = gate.resolve();
    await Future<void>.delayed(Duration.zero);
    expect(resolver.reads, 1);
    resolver.pending!.complete(
      FinalizedIdentity(
        accountId: accountId,
        accountAddress: account(accountId).ss58Address,
        snapshot: null,
      ),
    );
    expect((await first).status, CidBusinessStatus.unregistered);
    expect((await second).status, CidBusinessStatus.unregistered);
  });

  test('链读取期间切换账户不显示旧账户的未注册引导', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(null)..pending = Completer<FinalizedIdentity?>();
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {},
    );
    final pending = gate.resolve();
    await Future<void>.delayed(Duration.zero);
    current.value = CurrentUser(
      account: account(otherAccountId),
      binding: null,
    );
    resolver.pending!.complete(
      FinalizedIdentity(
        accountId: accountId,
        accountAddress: account(accountId).ss58Address,
        snapshot: null,
      ),
    );
    expect((await pending).status, CidBusinessStatus.unavailable);
  });

  test('同账户注册完成并广播修订后，新门禁不复用旧的未注册链请求', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(null)..pending = Completer<FinalizedIdentity?>();
    final revision = ValueNotifier<int>(0);
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: revision,
      synchronizeIdentity: (_) async {},
    );
    final oldDecision = gate.resolve();
    await Future<void>.delayed(Duration.zero);
    current.value = CurrentUser(account: account(accountId), binding: binding);
    revision.value++;
    final newDecision = await gate.resolve();
    expect(newDecision.status, CidBusinessStatus.ready);
    resolver.pending!.complete(
      FinalizedIdentity(
        accountId: accountId,
        accountAddress: account(accountId).ss58Address,
        snapshot: null,
      ),
    );
    expect((await oldDecision).status, CidBusinessStatus.unavailable);
  });

  test('链上确认无公民号同步空身份后输出注册态', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(
      FinalizedIdentity(
        accountId: accountId,
        accountAddress: account(accountId).ss58Address,
        snapshot: null,
      ),
    );
    var restores = 0;
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {
        restores++;
      },
    );
    expect((await gate.resolve()).status, CidBusinessStatus.unregistered);
    expect(restores, 1);
  });

  test('本机缓存缺失但链上已有公民号时恢复同一绑定', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(
      FinalizedIdentity(
        accountId: accountId,
        accountAddress: account(accountId).ss58Address,
        snapshot: snapshot(),
      ),
    );
    var restores = 0;
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {
        restores++;
        current.value = CurrentUser(
          account: account(accountId),
          binding: binding,
        );
      },
    );
    final decision = await gate.resolve();
    expect(decision.status, CidBusinessStatus.ready);
    expect(decision.cidNumber, cidNumber);
    expect(restores, 1);
    expect(current.invalidations, 1);
  });

  test('链故障及恢复时账户切换只报告操作失败，不写入没有CID', () async {
    final current = _Current(
      CurrentUser(account: account(accountId), binding: null),
    );
    final resolver = _Resolver(
      FinalizedIdentity(
        accountId: accountId,
        accountAddress: account(accountId).ss58Address,
        snapshot: snapshot(),
      ),
    )..fails = true;
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {},
    );
    expect((await gate.resolve()).status, CidBusinessStatus.unavailable);
    expect(current.value!.verifiedUnregistered, false);
    expect(current.invalidations, 0);
    expect((await gate.resolve()).status, CidBusinessStatus.unavailable);
    expect(resolver.reads, 2, reason: '失败不缓存为没有CID，下一次仍核对真实链');
    resolver.fails = false;
    final changed = CidBusinessGate(
      currentUserContext: current,
      identityResolver: resolver,
      revision: ValueNotifier<int>(0),
      synchronizeIdentity: (_) async {
        current.value = CurrentUser(
          account: account(otherAccountId),
          binding: null,
        );
      },
    );
    expect((await changed.resolve()).status, CidBusinessStatus.unavailable);
  });
}

// 验证最终身份闭环、同次验真合并及账户和修订切换隔离。

const _account0 =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _account5 =
    '0x5555555555555555555555555555555555555555555555555555555555555555';

/// 金标：链上创世 `CidRegistry[CN220-CTZN2-198805200-2026]` 逐字节实测值
/// （2026-07-31 于 127.0.0.1:9944 finalized 读出，共 67 字节）。
///
/// registrar "ZS001-FRG07-249474503-2026" | commitment 32B | 省码空 | 市码空
/// | status=Active | registered_at=0 | revoked_at=None。
const _genesisCidRecordHex =
    '685a533030312d46524730372d3234393437343530332d323032'
    '3693c7cc569ee4c38bead016a83ffd5e76d1c6a628555b55805cf18d3f06779a66'
    '0000000000000000';

const _genesisCid = 'CN220-CTZN2-198805200-2026';
const _genesisAccountId =
    '0x0cb1d05c0c9c7f05679b60d6f24c7e5719a3985264e41c5e899d4822dca4b06b';

final _genesisDefaultAccount = CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 1,
  accountIndex: 0,
  name: '钱包1',
  ss58Address: 'ss58-genesis',
  accountId: _genesisAccountId,
  createdAtMillis: BigInt.zero,
  isDefault: true,
);

final _default0 = CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 1,
  accountIndex: 0,
  name: '账户0',
  ss58Address: 'ss58-0',
  accountId: _account0,
  createdAtMillis: BigInt.zero,
  isDefault: true,
);

final _default5 = CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.cold,
  walletIndex: 2,
  accountIndex: null,
  name: '冷账户5',
  ss58Address: 'ss58-5',
  accountId: _account5,
  createdAtMillis: BigInt.zero,
  isDefault: true,
);

CitizenIdentityChainSnapshot _anonSnapshot() => CitizenIdentityChainSnapshot(
  cidNumber: 'CID-TEST-0001',
  accountId: Uint8List(32),
  bindRev: 1,
  votingIdentity: null,
  candidateIdentity: null,
);

void suite79() {
  ({FinalizedIdentityResolver resolver, _FakeReader reader}) resolver({
    CitizenWalletStateAccount? account,
    bool noAccount = false,
    Map<String, CitizenIdentityChainSnapshot> chain = const {},
    String? throwFor,
  }) {
    final reader = _FakeReader(chain, throwFor: throwFor);
    return (
      resolver: (() {
        final reads0 = _FakeWallet(noAccount ? null : account ?? _default0);
        return FinalizedIdentityResolver(
          getWalletState: reads0.getWalletState,
          chainReader: reader,
        );
      })(),
      reader: reader,
    );
  }

  test('共享会员批次未就绪时只读取当前账户身份，不等待整批刷新', () async {
    final reader = _FakeReader({_account0: _anonSnapshot()});
    final reads = _FakeWallet(_default0);
    final subject = FinalizedIdentityResolver(
      getWalletState: reads.getWalletState,
      chainReader: reader,
      chainData: _PendingChainData(),
    );
    final result = await subject.resolve();
    expect(result!.snapshot!.cidNumber, 'CID-TEST-0001');
    expect(reader.calls, [_account0]);
  });

  test('同账户同版本并发验真合并，完成后的新操作重新验真', () async {
    final reader = _DelayedReader();
    final subject = (() {
      final reads0 = _FakeWallet(_default0);
      return FinalizedIdentityResolver(
        getWalletState: reads0.getWalletState,
        chainReader: reader,
      );
    })();
    final first = subject.resolve();
    final second = subject.resolve();
    await reader.started.future;
    expect(reader.calls, 1);
    reader.answer.complete(null);
    await Future.wait([first, second]);
    await subject.resolve();
    expect(reader.calls, 2);
  });

  test('查询期间切换账户或身份版本，旧结果必须拒绝', () async {
    final reader = _DelayedReader();
    final wallet = _FakeWallet(_default0);
    final revision = ValueNotifier(0);
    final subject = FinalizedIdentityResolver(
      getWalletState: wallet.getWalletState,
      chainReader: reader,
      identityRevision: revision,
    );
    final first = subject.resolve();
    final rejected = expectLater(first, throwsStateError);
    await reader.started.future;
    wallet.account = _default5;
    wallet.walletRevision += BigInt.one;
    revision.value++;
    reader.answer.complete(null);
    await rejected;
    revision.dispose();
  });

  test('身份验证失败不留下可复用的完成授权', () async {
    final reader = _DelayedReader();
    final subject = (() {
      final reads0 = _FakeWallet(_default0);
      return FinalizedIdentityResolver(
        getWalletState: reads0.getWalletState,
        chainReader: reader,
      );
    })();
    final first = subject.resolve();
    final rejected = expectLater(first, throwsStateError);
    await reader.started.future;
    reader.answer.completeError(StateError('测试断网'));
    await rejected;
    await expectLater(subject.resolve(), throwsStateError);
    expect(reader.calls, 2);
  });

  test('默认账户绑 CID → 当前用户命中且只读取该账户一次', () async {
    final fixture = resolver(chain: {_account0: _anonSnapshot()});
    final r = await fixture.resolver.resolve();
    expect(r, isNotNull);
    expect(r!.accountId, _account0);
    expect(r.isRegistered, isTrue);
    expect(fixture.reader.calls, [_account0]);
  });

  test('默认账户无 CID 时保持访客，禁止扫描另一个有 CID 的账户', () async {
    final fixture = resolver(chain: {_account5: _anonSnapshot()});
    final r = await fixture.resolver.resolve();
    expect(r!.accountId, _account0);
    expect(r.isRegistered, isFalse);
    expect(r.snapshot, isNull);
    expect(fixture.reader.calls, [_account0]);
  });

  test('冷钱包也可成为默认账户并解析其 CID', () async {
    final fixture = resolver(
      account: _default5,
      chain: {_account5: _anonSnapshot()},
    );
    final r = await fixture.resolver.resolve();
    expect(r!.accountId, _account5);
    expect(r.isRegistered, isTrue);
    expect(fixture.reader.calls, [_account5]);
  });

  test('没有任何默认账户 → null', () async {
    final r = await resolver(noAccount: true).resolver.resolve();
    expect(r, isNull);
  });

  test('链读异常上抛,绝不吞成访客/未注册', () async {
    await expectLater(
      resolver(throwFor: _account0).resolver.resolve(),
      throwsA(isA<StateError>()),
    );
  });

  test('按 CID 读取绑定锚定同一 finalized 区块并校验双向闭环', () async {
    const cidNumber = 'CN220-CTZN2-100000001-2026';
    final accountId = Uint8List.fromList(List<int>.filled(32, 0xaa));
    final cidScale = CitizenIdentityChainReader.encodeBoundedBytes(
      cidNumber.codeUnits,
    );
    final chainRpc = _BindingChain(<String, Uint8List>{
      _identityKey('AccountIdByCid', cidScale): accountId,
      _identityKey('CidRegistry', cidScale): _activeCidRecord(),
      _identityKey('BindingRevisionByCid', cidScale): Uint8List.fromList([
        2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]),
      _identityKey('CidByAccountId', accountId):
          CitizenIdentityChainReader.encodeBoundedBytes(cidNumber.codeUnits),
    });

    final result = await CitizenIdentityChainReader(
      getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: chainRpc.getFinalizedHead,
      getStorageBatch: chainRpc.getStorageBatch,
      getStorage: chainRpc.getStorage,
    ).readBindingByCidNumber(cidNumber);

    expect(result, isNotNull);
    expect(result!.accountIdText, citizenAccountIdFromBytes(accountId));
    expect(result.bindRev, 2);
    expect(chainRpc.blockHashes.toSet(), {
      '0x${List<String>.filled(32, '00').join()}',
    });
  });

  test('按 CID 读取时反向账户映射不一致必须失败关闭', () async {
    const cidNumber = 'CN220-CTZN2-100000001-2026';
    final accountId = Uint8List.fromList(List<int>.filled(32, 0xbb));
    final cidScale = CitizenIdentityChainReader.encodeBoundedBytes(
      cidNumber.codeUnits,
    );
    final chainRpc = _BindingChain(<String, Uint8List>{
      _identityKey('AccountIdByCid', cidScale): accountId,
      _identityKey('CidRegistry', cidScale): _activeCidRecord(),
      _identityKey('BindingRevisionByCid', cidScale): Uint8List.fromList([
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]),
      _identityKey('CidByAccountId', accountId):
          CitizenIdentityChainReader.encodeBoundedBytes('OTHER-CID'.codeUnits),
    });

    final result = await CitizenIdentityChainReader(
      getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: chainRpc.getFinalizedHead,
      getStorageBatch: chainRpc.getStorageBatch,
      getStorage: chainRpc.getStorage,
    ).readBindingByCidNumber(cidNumber);

    expect(result, isNull);
  });

  group('CidRecord 解析', () {
    test('创世金标:居住省/市码为空的 Active 记录判 Active', () {
      final record = hexToBytes(_genesisCidRecordHex);
      expect(record.length, 67);
      expect(CitizenIdentityChainReader.cidRecordIsActive(record), isTrue);
    });

    test('居住省/市码非空同样判 Active', () {
      final record = Uint8List.fromList([
        ..._bounded('FEDERAL_REGISTRY-CID'),
        ...List<int>.filled(32, 7),
        ..._bounded('GD'),
        ..._bounded('0755'),
        0,
        1,
        0,
        0,
        0,
        0,
      ]);
      expect(CitizenIdentityChainReader.cidRecordIsActive(record), isTrue);
    });

    test('记录不存在判非 Active,不抛异常', () {
      expect(CitizenIdentityChainReader.cidRecordIsActive(null), isFalse);
    });

    test('status=Revoked 判非 Active', () {
      final record = hexToBytes(_genesisCidRecordHex);
      record[61] = 1; // CidRecordStatus::Revoked
      expect(CitizenIdentityChainReader.cidRecordIsActive(record), isFalse);
    });

    test('Active 却带撤销块号 → 自相矛盾判非 Active', () {
      final record = Uint8List.fromList([
        ...hexToBytes(_genesisCidRecordHex).sublist(0, 66),
        1, 9, 0, 0, 0, // revoked_at = Some(9)
      ]);
      expect(CitizenIdentityChainReader.cidRecordIsActive(record), isFalse);
    });

    test('布局截断上抛,绝不吞成非 Active', () {
      expect(
        () => CitizenIdentityChainReader.cidRecordIsActive(
          hexToBytes(_genesisCidRecordHex).sublist(0, 62),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('尾随字节非法上抛', () {
      expect(
        () => CitizenIdentityChainReader.cidRecordIsActive(
          Uint8List.fromList([...hexToBytes(_genesisCidRecordHex), 0]),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('创世匿名身份端到端', () {
    Map<String, Uint8List> genesisStorage() {
      final accountId = citizenAccountIdBytes(_genesisAccountId);
      final cidScale = CitizenIdentityChainReader.encodeBoundedBytes(
        _genesisCid.codeUnits,
      );
      // VotingIdentityByCid / CandidateIdentityByCid 故意缺席 = 匿名已注册。
      return <String, Uint8List>{
        _identityKey(
          'CidByAccountId',
          accountId,
        ): CitizenIdentityChainReader.encodeBoundedBytes(
          _genesisCid.codeUnits,
        ),
        _identityKey('AccountIdByCid', cidScale): accountId,
        _identityKey('CidRegistry', cidScale): hexToBytes(_genesisCidRecordHex),
        _identityKey('BindingRevisionByCid', cidScale): Uint8List.fromList([
          1,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ]),
      };
    }

    test('readByAccountId 命中匿名快照', () async {
      final snapshot = await (() {
        final reads0 = _BindingChain(genesisStorage());
        return CitizenIdentityChainReader(
          getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getFinalizedHead: reads0.getFinalizedHead,
          getStorageBatch: reads0.getStorageBatch,
          getStorage: reads0.getStorage,
        );
      })().readByAccountId(_genesisAccountId);

      expect(snapshot, isNotNull);
      expect(snapshot!.cidNumber, _genesisCid);
      expect(snapshot.bindRev, 1);
      expect(snapshot.isAnonymous, isTrue);
    });

    test('门禁判据 isRegistered = true(不再误判未注册)', () async {
      final r = await (() {
        final reads0 = _FakeWallet(_genesisDefaultAccount);
        return FinalizedIdentityResolver(
          getWalletState: reads0.getWalletState,
          chainReader: (() {
            final reads0 = _BindingChain(genesisStorage());
            return CitizenIdentityChainReader(
              getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
              getFinalizedHead: reads0.getFinalizedHead,
              getStorageBatch: reads0.getStorageBatch,
              getStorage: reads0.getStorage,
            );
          })(),
        );
      })().resolve();

      expect(r, isNotNull);
      expect(r!.accountId, _genesisAccountId);
      expect(r.isRegistered, isTrue);
    });
  });
}

List<int> _bounded(String value) =>
    CitizenIdentityChainReader.encodeBoundedBytes(value.codeUnits);

/// 链上真实形态的 Active `CidRecord`。
///
/// 居住省码/市码**恒为空**：创世 `initial_cid_bindings`、`self_occupy_cid` 与
/// 注册局占号都写 `AreaCodeBound::default()`。夹具必须照此，写非空省市码会让
/// 「空 BoundedVec 解析」这条真实路径永远测不到。
Uint8List _activeCidRecord() => Uint8List.fromList([
  ..._bounded('FEDERAL_REGISTRY-CID'),
  ...List<int>.filled(32, 7), // commitment
  0, // residence_province_code 空
  0, // residence_city_code 空
  0, // status = Active
  1, 0, 0, 0, // registered_at
  0, // revoked_at = None
]);

String _identityKey(String storageName, Uint8List data) {
  final key = [
    ...CitizenScale.storagePrefix('Identity', storageName),
    ...CitizenScale.blake2b128(data),
    ...data,
  ];
  return '0x${bytesToHex(key)}';
}

class _FakeWallet extends TestWalletReads {
  _FakeWallet(this.account);
  CitizenWalletStateAccount? account;
  BigInt walletRevision = BigInt.one;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: account == null
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: walletRevision,
          hotProfile: null,
          accounts: account == null ? const [] : [account!],
        ),
      );
}

class _FakeReader extends CitizenIdentityChainReader {
  _FakeReader(this._chain, {this.throwFor}) : super();
  final Map<String, CitizenIdentityChainSnapshot> _chain;
  final String? throwFor;
  final List<String> calls = <String>[];

  @override
  Future<CitizenIdentityChainSnapshot?> readByAccountId(
    String accountId, {
    CitizenBlockRef? at,
  }) async {
    calls.add(accountId);
    if (accountId == throwFor) throw StateError('chain down');
    return _chain[accountId];
  }
}

class _BindingChain extends TestChainReads {
  _BindingChain(this.storage);

  final Map<String, Uint8List> storage;
  final List<String> blockHashes = <String>[];

  @override
  Future<CitizenBlockRef> getFinalizedHead() async => CitizenBlockRef(
    hash: '0x${'00' * 32}',
    number: BigInt.from(7),
    finality: CitizenBlockFinality.finalized,
  );

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    blockHashes.add(block.hash);
    return storage[_hex(key)];
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async {
    blockHashes.addAll(List<String>.filled(keys.length, block.hash));
    return keys.map((key) => storage[_hex(key)]).toList(growable: false);
  }

  String _hex(List<int> bytes) =>
      '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}

class _DelayedReader extends CitizenIdentityChainReader {
  _DelayedReader() : super();
  final started = Completer<void>();
  final answer = Completer<CitizenIdentityChainSnapshot?>();
  int calls = 0;
  @override
  Future<CitizenIdentityChainSnapshot?> readByAccountId(
    String accountId, {
    CitizenBlockRef? at,
  }) {
    calls++;
    if (!started.isCompleted) started.complete();
    return answer.future;
  }
}

class _PendingChainData implements ChainDataService {
  @override
  ChainDataSnapshot? get snapshot => null;
  @override
  bool get isStale => true;
  @override
  Future<ChainDataSnapshot?> refresh() => throw StateError('身份不得等待整批会员刷新');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// 验证身份快照持久化、CID和账户隔离及损坏或过期拒绝。

void suite80() {
  const cidA = 'GD-CTZN1-000000001-2026';
  const cidB = 'GD-CTZN1-000000002-2026';

  useIsolatedIsar();

  test('完整身份持久化、未注册和换绑结果按账户隔离', () async {
    final a =
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        b = '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    CitizenIdentityChainSnapshot snapshot(int byte, int version) =>
        CitizenIdentityChainSnapshot(
          cidNumber: cidA,
          accountId: Uint8List.fromList(List.filled(32, byte)),
          bindRev: version,
          votingIdentity: null,
        );
    final store = IdentityBadgeSnapshotStore();
    await store.writeVerified(
      accountId: a,
      identity: snapshot(0xaa, 1),
      isCurrent: () => true,
    );
    // 真正关闭后重开数据库，不能只用新服务实例证明持久保存。
    await (await UserIsar.instance.db()).close();
    final reopened = IdentityBadgeSnapshotStore();
    expect((await reopened.readForAccountId(a))?.identity?.cidNumber, cidA);
    await store.writeVerified(
      accountId: b,
      identity: null,
      isCurrent: () => true,
    );
    expect((await reopened.readForAccountId(b))?.verified, isTrue);
    expect((await reopened.readForAccountId(b))?.identity, isNull);
    await store.writeVerified(
      accountId: b,
      identity: snapshot(0xbb, 2),
      isCurrent: () => true,
    );
    expect((await reopened.readForAccountId(a))?.identity, isNull);
    expect((await reopened.readForAccountId(b))?.identity?.bindRev, 2);
    expect((await reopened.read(cidA))?.accountId, b);
    await store.writeVerified(
      accountId: b,
      identity: null,
      isCurrent: () => true,
    );
    expect(await reopened.read(cidA), isNull);
    expect((await reopened.readForAccountId(b))?.verified, isTrue);
  });

  test('过期上下文和损坏完整快照不能覆盖成功数据或伪装未注册', () async {
    final account =
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final store = IdentityBadgeSnapshotStore();
    await store.writeVerified(
      accountId: account,
      identity: CitizenIdentityChainSnapshot(
        cidNumber: cidA,
        accountId: Uint8List.fromList(List.filled(32, 0xaa)),
        bindRev: 1,
        votingIdentity: null,
      ),
      isCurrent: () => true,
    );
    await expectLater(
      store.writeVerified(
        accountId: account,
        identity: null,
        isCurrent: () => false,
      ),
      throwsStateError,
    );
    expect((await store.readForAccountId(account))?.cidNumber, cidA);
    await UserIsar.instance.writeTxn((isar) async {
      final row = await isar
          .collection<user_store.Identity>()
          .filter()
          .accountIdEqualTo(account)
          .findFirst();
      row!.identityData = '{broken';
      await isar.collection<user_store.Identity>().put(row);
    });
    expect(await store.readForAccountId(account), isNull);
  });

  test('身份徽章快照按永久 CID 隔离', () async {
    final store = IdentityBadgeSnapshotStore(
      nowProvider: () => DateTime.fromMillisecondsSinceEpoch(1234),
    );

    await store.write(cidNumber: cidA, cidLevel: 'voting');
    await store.write(cidNumber: cidB, cidLevel: 'candidate');

    final citizenA = await store.read(cidA);
    final citizenB = await store.read(cidB);
    expect(citizenA?.cidLevel, 'voting');
    expect(citizenA?.updatedAt, 1234);
    expect(citizenB?.cidLevel, 'candidate');
  });

  test('损坏快照按无展示处理且读取路径不删除事实', () async {
    final store = IdentityBadgeSnapshotStore();
    await UserIsar.instance.writeTxn((isar) async {
      await isar.collection<user_store.Identity>().put(
        user_store.Identity()
          ..cidNumber = cidA
          ..identityData = '{"cid_level":"broken"}'
          ..updatedAt = -1,
      );
    });
    expect(await store.read(cidA), isNull);
    final retained = await UserIsar.instance.read(
      (isar) async => isar
          .collection<user_store.Identity>()
          .filter()
          .cidNumberEqualTo(cidA)
          .findFirst(),
    );
    expect(retained, isNotNull);
    expect(retained?.identityData, '{"cid_level":"broken"}');
  });

  test('不接受非正式身份档', () async {
    final store = IdentityBadgeSnapshotStore();

    await expectLater(
      store.write(cidNumber: cidA, cidLevel: 'admin'),
      throwsArgumentError,
    );
    expect(await store.read(cidA), isNull);
  });
}

// 验证身份验真与绑定先保存后广播、并发合并及失败主动重试。

const _validAccountId =
    '0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d';
final _validAddress = citizenSs58FromAccountId(_validAccountId);

CitizenWalletStateAccount _testAccount({
  required String accountId,
  required String accountAddress,
  required int accountIndex,
  required String name,
}) => CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 1,
  accountIndex: accountIndex,
  accountId: accountId,
  ss58Address: accountAddress,
  name: name,
  createdAtMillis: BigInt.zero,
  isDefault: accountIndex == 0,
);

final _aliceWallet = _testAccount(
  accountId: _validAccountId,
  accountAddress: _validAddress,
  accountIndex: 0,
  name: '账户0',
);

void suite85() {
  final core = TestCitizenSdkHarness();
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  MyIdService buildService({
    CitizenWalletStateAccount? wallet,
    bool noWallet = false,
    Uint8List? voting,
    Uint8List? candidate,
    bool chainThrows = false,
    bool mismatchWallet = false,
    int cidStatus = 0,
    bool hasCid = false,
    DateTime? now,
  }) {
    final walletManager = _FakeWalletManager(
      noWallet ? null : wallet ?? _aliceWallet,
    );
    final chainRpc = _FakeChain(
      voting: voting,
      candidate: candidate,
      throws: chainThrows,
      mismatchWallet: mismatchWallet,
      cidStatus: cidStatus,
      hasCid: hasCid,
    );
    return (() {
      final reads0 = TestTransactionCalls();
      return MyIdService(
        getWalletState: walletManager.getWalletState,
        signing: core.sdk,
        payloadSigner: walletManager.signPayload,
        accountSecurity: walletManager,
        currentUserContext: _InvalidationCountingIdentityCache(),
        sessionProvider: _UnusedSessionProvider(),
        getFeeSnapshot: chainRpc.getFeeSnapshot,
        getGenesisHash: chainRpc.getGenesisHash,
        getFinalizedHead: chainRpc.getFinalizedHead,
        getAccountBalance: chainRpc.getAccountBalance,
        getStorage: chainRpc.getStorage,
        getStorageBatch: chainRpc.getStorageBatch,
        prepareTransaction: reads0.prepareTransaction,
        executePreparedTransaction: reads0.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            reads0.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            reads0.consumePreparedTransactionQrResponse,
        identityResolver: FinalizedIdentityResolver(
          getWalletState: walletManager.getWalletState,
          chainReader: CitizenIdentityChainReader(
            getFinalizedHead: chainRpc.getFinalizedHead,
            getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getStorage: chainRpc.getStorage,
            getStorageBatch: chainRpc.getStorageBatch,
          ),
        ),
        divisionStore: _FakeDivisionStore(),
        badgeSnapshotStore: _FakeBadgeStore(),
        nowProvider: () => now ?? DateTime.utc(2026, 6, 1),
        onChatBindingChanged: (binding, {required existingOnly}) async {
          final ChatRuntime? runtime = existingOnly
              ? null
              : (() => _BindingRuntime())();
          await runtime?.convergeFinalizedBinding(
            ChatBinding.fromIdentity(binding),
          );
        },
      );
    })();
  }

  MyIdService testService({
    CitizenSdk? signing,
    bool useDefaultSigner = false,
    bool sdkSwitchesDefault = true,
    _FakeWalletManager? wallet,
    TestChainReads? chain,
    FinalizedIdentityResolver? identityResolver,
    CitizenIdentityTransaction? identityTransaction,
    CurrentUserContext? currentUserContext,
    int Function()? cidYearProvider,
    IdentityBadgeSnapshotStore? badgeSnapshotStore,
    ChatRuntime? runtime,
    SquareSessionProvider? sessionProvider,
  }) {
    final actualWallet = wallet ?? _FakeWalletManager(_aliceWallet);
    if (identityTransaction is _FakeIdentityTransaction && sdkSwitchesDefault) {
      identityTransaction.onSdkDefaultCommitted = (target) {
        actualWallet._wallet = actualWallet.accounts.singleWhere(
          (a) => a.accountId == target,
        );
        actualWallet.catalogRevision += BigInt.one;
      };
    }
    final actualChain = chain ?? _FakeChain();
    final actualRuntime = runtime ?? _BindingRuntime();
    addTearDown(actualRuntime.close);
    return (() {
      final reads0 = TestTransactionCalls();
      return MyIdService(
        getWalletState: actualWallet.getWalletState,
        signing: signing ?? core.sdk,
        payloadSigner: useDefaultSigner ? null : actualWallet.signPayload,
        accountSecurity: actualWallet,
        currentUserContext:
            currentUserContext ?? _InvalidationCountingIdentityCache(),
        identityResolver: identityResolver ?? _FakeIdentityResolver(null),
        sessionProvider: sessionProvider ?? _UnusedSessionProvider(),
        getFeeSnapshot: actualChain.getFeeSnapshot,
        getGenesisHash: actualChain.getGenesisHash,
        getFinalizedHead: actualChain.getFinalizedHead,
        getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getAccountBalance: actualChain.getAccountBalance,
        getStorage: actualChain.getStorage,
        getStorageBatch: actualChain.getStorageBatch,
        prepareTransaction: reads0.prepareTransaction,
        executePreparedTransaction: reads0.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            reads0.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            reads0.consumePreparedTransactionQrResponse,
        divisionStore: _FakeDivisionStore(),
        badgeSnapshotStore: badgeSnapshotStore ?? _FakeBadgeStore(),
        identityTransaction: identityTransaction,
        cidYearProvider: cidYearProvider,
        onChatBindingChanged: (binding, {required existingOnly}) async {
          final ChatRuntime? runtime = existingOnly
              ? null
              : (() => actualRuntime)();
          await runtime?.convergeFinalizedBinding(
            ChatBinding.fromIdentity(binding),
          );
        },
      );
    })();
  }

  for (final result in ['registered', 'unregistered', 'network', 'changed']) {
    test('公开身份同步只验真一次且不登记设备，$result保持正确状态', () async {
      final wallet = _FakeWalletManager(_aliceWallet);
      final current = CurrentUserContext(
        getWalletState: wallet.getWalletState,
        accountSecurity: wallet,
      );
      final identity = _registeredIdentity(_validAccountId);
      final resolver = _SyncResolver(
        result == 'unregistered'
            ? FinalizedIdentity(
                accountId: _validAccountId,
                accountAddress: _validAddress,
                snapshot: null,
              )
            : identity,
        failure: result == 'network',
        changed: result == 'changed',
      );
      final sessions = _SyncSessions(identity);
      final service = testService(
        wallet: wallet,
        currentUserContext: current,
        identityResolver: resolver,
        sessionProvider: sessions,
      );
      if (result == 'registered') {
        final state = await service.refreshState();
        expect(state.status, isNot(MyIdStatus.queryFailed));
        final synced = service.sync.value;
        expect(synced, isNotNull);
        expect(synced!.accountId, _validAccountId);
        expect(identical(synced.state, state), isTrue);
        expect(await service.isCurrentSync(synced), isTrue);
        wallet.revision.value++;
        expect(await service.isCurrentSync(synced), isFalse);
        expect(sessions.registrations, 0);
        expect(
          (await current.resolve())?.cidNumber,
          identity.snapshot!.cidNumber,
        );
      } else {
        final state = await service.refreshState();
        expect(
          state.status,
          result == 'network' || result == 'changed'
              ? MyIdStatus.queryFailed
              : isNot(MyIdStatus.queryFailed),
        );
        expect(sessions.registrations, 0);
        if (result == 'network' || result == 'changed') {
          expect(service.sync.value, isNull);
        } else {
          expect(service.sync.value, isNotNull);
        }
      }
      expect(resolver.reads, 1);
      expect(wallet.signCalls, 0);
    });
  }

  test('同步失败后主动重试可写入绑定，不请求钱包签名或登记', () async {
    final wallet = _FakeWalletManager(_aliceWallet);
    final resolver = _SyncResolver(
      _registeredIdentity(_validAccountId),
      failure: true,
    );
    final service = testService(wallet: wallet, identityResolver: resolver);
    expect((await service.refreshState()).status, MyIdStatus.queryFailed);
    expect(wallet.bindings, isEmpty);
    resolver.failure = false;
    expect(
      (await service.refreshState()).cidNumber,
      resolver.identity.snapshot!.cidNumber,
    );
    expect(resolver.reads, 2);
    expect(
      wallet.activeBinding!.cidNumber,
      resolver.identity.snapshot!.cidNumber,
    );
    expect(wallet.signCalls, 0);
    expect(wallet.mlsDeviceRegistrationCalls, 0);
  });

  for (final code in [
    CitizenSdkErrorCode.notReady,
    CitizenSdkErrorCode.integrity,
  ]) {
    test('SDK ${code.name} 区分同步未就绪与完整性失败', () async {
      final service = testService(
        identityResolver: _SdkErrorResolver(
          _registeredIdentity(_validAccountId),
          code,
        ),
      );
      expect(
        (await service.refreshState()).status,
        code == CitizenSdkErrorCode.notReady
            ? MyIdStatus.unknown
            : MyIdStatus.queryFailed,
      );
    });
  }

  test('展示快照发布时业务绑定必须已经保存', () async {
    final wallet = _FakeWalletManager(_aliceWallet);
    final store = _OrderedBadgeStore(wallet);
    final service = testService(
      wallet: wallet,
      badgeSnapshotStore: store,
      identityResolver: _SyncResolver(_registeredIdentity(_validAccountId)),
    );
    await service.refreshState();
    expect(store.publishedAfterBinding, isTrue);
  });

  test('同一账户并发刷新共用完整同步，不只合并链读取', () async {
    final wallet = _FakeWalletManager(_aliceWallet);
    final resolver = _SyncResolver(_registeredIdentity(_validAccountId))
      ..pending = Completer<FinalizedIdentity?>();
    final service = testService(wallet: wallet, identityResolver: resolver);
    final requests = [service.refreshState(), service.refreshState()];
    await Future<void>.delayed(Duration.zero);
    expect(resolver.reads, 1);
    final gateSynchronization = service.synchronizeIdentity(resolver.identity);
    resolver.pending!.complete(resolver.identity);
    final states = await Future.wait(requests);
    await gateSynchronization;
    expect(states.map((state) => state.cidNumber).toSet(), {
      resolver.identity.snapshot!.cidNumber,
    });
    expect(wallet.bindings, hasLength(1));
    expect(wallet.identityNotifications, 1);
  });

  test('相同绑定的重复身份刷新保留会话和身份版本', () async {
    final wallet = _FakeWalletManager(_aliceWallet);
    final identity = _registeredIdentity(_validAccountId);
    final sessions = _SyncSessions(identity);
    final current = _InvalidationCountingIdentityCache();
    final service = testService(
      wallet: wallet,
      identityResolver: _SyncResolver(identity),
      sessionProvider: sessions,
      currentUserContext: current,
    );
    await service.refreshState();
    final revision = wallet.revision.value;
    final invalidations = current.invalidateCalls;
    await service.refreshState();
    await service.synchronizeIdentity(identity);
    expect(wallet.revision.value, revision);
    expect(wallet.identityNotifications, 1);
    expect(wallet.bindings, hasLength(1));
    expect(sessions.invalidatedAccounts, isEmpty);
    expect(current.invalidateCalls, invalidations);
    expect(service.sync.value?.state.cidNumber, identity.snapshot!.cidNumber);
  });

  test('同一账户重复确认未注册不重复失效会话或广播身份变化', () async {
    final wallet = _FakeWalletManager(_aliceWallet);
    final current = _InvalidationCountingIdentityCache();
    final store = IdentityBadgeSnapshotStore();
    final identity = FinalizedIdentity(
      accountId: _validAccountId,
      accountAddress: _validAddress,
      snapshot: null,
    );
    final service = testService(
      wallet: wallet,
      currentUserContext: current,
      badgeSnapshotStore: store,
      identityResolver: _SyncResolver(identity),
    );
    await service.refreshState();
    final revision = wallet.revision.value;
    final invalidations = current.invalidateCalls;
    expect(wallet.identityNotifications, 1);
    await service.refreshState();
    await service.synchronizeIdentity(identity);
    expect(wallet.identityNotifications, 1);
    expect(wallet.revision.value, revision);
    expect(current.invalidateCalls, invalidations);
    expect((await store.readForAccountId(_validAccountId))?.verified, isTrue);
  });

  test('绑定不变的身份等级更新仍刷新展示，不清会话或增加版本', () async {
    final identity = _registeredIdentity(_validAccountId);
    final updated = FinalizedIdentity(
      accountId: identity.accountId,
      accountAddress: identity.accountAddress,
      snapshot: CitizenIdentityChainSnapshot(
        cidNumber: identity.snapshot!.cidNumber,
        accountId: identity.snapshot!.accountId,
        bindRev: identity.snapshot!.bindRev,
        votingIdentity: _encodeVoting(
          from: 20260101,
          until: 20310101,
          status: 0,
          province: 'GD',
          city: '001',
          town: '001',
        ),
      ),
    );
    final wallet = _FakeWalletManager(_aliceWallet);
    final sessions = _SyncSessions(identity);
    final store = IdentityBadgeSnapshotStore();
    final resolver = _SyncResolver(identity);
    final service = testService(
      wallet: wallet,
      identityResolver: resolver,
      sessionProvider: sessions,
      badgeSnapshotStore: store,
    );
    expect((await service.refreshState()).tier, MyIdTier.visitor);
    final revision = wallet.revision.value;
    resolver.identity = updated;
    expect((await service.refreshState()).tier, MyIdTier.voting);
    expect(
      (await store.readForAccountId(identity.accountId))?.cidLevel,
      'voting',
    );
    expect(wallet.revision.value, revision);
    expect(sessions.invalidatedAccounts, isEmpty);
  });

  test('绑定代次实际变化只失效一次，再次刷新同代次保持会话', () async {
    final identity = _registeredIdentity(_validAccountId);
    final updated = _registeredIdentity(_validAccountId, bindRev: 2);
    final wallet = _FakeWalletManager(_aliceWallet);
    final sessions = _SyncSessions(identity);
    final resolver = _SyncResolver(identity);
    final service = testService(
      wallet: wallet,
      identityResolver: resolver,
      sessionProvider: sessions,
    );
    await service.refreshState();
    resolver.identity = updated;
    await service.refreshState();
    final revision = wallet.revision.value;
    expect(wallet.identityNotifications, 2);
    expect(sessions.invalidatedAccounts, [identity.accountId]);
    await service.refreshState();
    expect(wallet.revision.value, revision);
    expect(wallet.bindings, hasLength(2));
    expect(sessions.invalidatedAccounts, [identity.accountId]);
  });

  test('激活绑定已经发出身份通知时不重复增加版本', () async {
    final wallet = _NotifyingWalletManager(_aliceWallet);
    final service = testService(
      wallet: wallet,
      identityResolver: _SyncResolver(_registeredIdentity(_validAccountId)),
    );
    await service.refreshState();
    expect(wallet.revision.value, 1);
    expect(wallet.identityNotifications, 1);
    await service.refreshState();
    expect(wallet.revision.value, 1);
    expect(wallet.identityNotifications, 1);
  });

  test('相同绑定的展示缓存写入失败也保留会话和身份版本', () async {
    final identity = _registeredIdentity(_validAccountId);
    final wallet = _FakeWalletManager(_aliceWallet);
    final sessions = _SyncSessions(identity);
    final store = _FailingBadgeStore();
    final service = testService(
      wallet: wallet,
      identityResolver: _SyncResolver(identity),
      sessionProvider: sessions,
      badgeSnapshotStore: store,
    );
    await service.refreshState();
    final revision = wallet.revision.value;
    store.fail = true;
    expect((await service.refreshState()).status, MyIdStatus.queryFailed);
    expect(wallet.revision.value, revision);
    expect(sessions.invalidatedAccounts, isEmpty);
  });

  test('排队时默认账户变化不能把新账户结果作为旧任务成功，重试才接管', () async {
    final wallet = _FakeWalletManager(_aliceWallet);
    final resolver = _SyncResolver(_registeredIdentity(_validAccountId))
      ..pending = Completer<FinalizedIdentity?>();
    final service = testService(wallet: wallet, identityResolver: resolver);
    final pending = service.refreshState();
    await Future<void>.delayed(Duration.zero);
    final nextId = '0x${'22' * 32}';
    wallet._wallet = _testAccount(
      accountId: nextId,
      accountAddress: citizenSs58FromAccountId(nextId),
      accountIndex: 0,
      name: '新账户',
    );
    resolver.pending!.complete(_registeredIdentity(nextId));
    expect((await pending).status, MyIdStatus.queryFailed);
    expect(wallet.bindings, isEmpty);
    final current = await service.refreshState();
    expect(current.status, isNot(MyIdStatus.queryFailed));
    expect(wallet.activeBinding!.accountId, nextId);
    expect(current.votingAccountId, citizenSs58FromAccountId(nextId));
    expect(current.cidNumber, _registeredIdentity(nextId).snapshot!.cidNumber);
  });

  test('公开同步保存完整竞选快照，绑定收尾不能降为匿名', () async {
    final base = _registeredIdentity(_validAccountId);
    final identity = FinalizedIdentity(
      accountId: base.accountId,
      accountAddress: base.accountAddress,
      snapshot: CitizenIdentityChainSnapshot(
        cidNumber: base.snapshot!.cidNumber,
        accountId: base.snapshot!.accountId,
        bindRev: 1,
        votingIdentity: _encodeVoting(
          from: 20260101,
          until: 20310101,
          status: 0,
          province: 'GD',
          city: '001',
          town: '001',
        ),
        candidateIdentity: _encodeCandidate(
          province: 'GD',
          city: '001',
          town: '001',
          familyName: '张',
          givenName: '三',
          sex: 0,
        ),
      ),
    );
    final store = IdentityBadgeSnapshotStore();
    final service = testService(
      identityResolver: _SyncResolver(identity),
      badgeSnapshotStore: store,
    );
    expect((await service.refreshState()).tier, MyIdTier.candidate);
    final saved = await service.getState();
    expect(saved.tier, MyIdTier.candidate);
    expect(saved.familyName, '张');
    expect(saved.givenName, '三');
    expect(saved.passportValidUntil, '2031-01-01');
  });

  test('本地公民号与完整快照重进复用且不调用验真', () async {
    final store = IdentityBadgeSnapshotStore();
    final reader = _FakeIdentityResolver(null);
    final snapshot = CitizenIdentityChainSnapshot(
      cidNumber: 'CID-DISPLAY-TEST',
      accountId: Uint8List.fromList([
        for (var i = 2; i < _validAccountId.length; i += 2)
          int.parse(_validAccountId.substring(i, i + 2), radix: 16),
      ]),
      bindRev: 1,
      votingIdentity: null,
    );
    await store.writeVerified(
      accountId: _validAccountId,
      identity: snapshot,
      isCurrent: () => true,
    );
    for (var i = 0; i < 3; i++) {
      final service = testService(
        identityResolver: reader,
        badgeSnapshotStore: IdentityBadgeSnapshotStore(),
      );
      final state = await service.getState();
      expect(state.cidNumber, 'CID-DISPLAY-TEST');
      expect(state.votingAccountId, _validAddress);
    }
    expect(reader.reads, 0);
  });

  test('完整投票身份从持久快照恢复有效期和选区，重进不验真', () async {
    final store = IdentityBadgeSnapshotStore();
    final resolver = _FakeIdentityResolver(null);
    await store.writeVerified(
      accountId: _validAccountId,
      identity: CitizenIdentityChainSnapshot(
        cidNumber: 'CID-DISPLAY-TEST',
        accountId: Uint8List.fromList([
          for (var i = 2; i < _validAccountId.length; i += 2)
            int.parse(_validAccountId.substring(i, i + 2), radix: 16),
        ]),
        bindRev: 1,
        votingIdentity: _encodeVoting(
          from: 20260101,
          until: 20310101,
          status: 0,
          province: 'GD',
          city: '0755',
          town: '001',
        ),
      ),
      isCurrent: () => true,
    );
    final service = testService(
      identityResolver: resolver,
      badgeSnapshotStore: IdentityBadgeSnapshotStore(),
    );
    final state = await service.getState();
    expect(state.tier, MyIdTier.voting);
    expect(state.passportValidUntil, '2031-01-01');
    expect(state.votingAccountId, _validAddress);
    expect(state.residenceDistrict, contains('N(0755)'));
    expect(resolver.reads, 0);
  });

  test('无本地身份为未知而非未注册，且不偷偷查链', () async {
    final reader = _FakeIdentityResolver(null);
    final service = testService(
      identityResolver: reader,
      badgeSnapshotStore: IdentityBadgeSnapshotStore(),
      currentUserContext: _LocalCurrentUser(null),
    );
    expect((await service.getState()).status, MyIdStatus.unknown);
    expect(reader.reads, 0);
  });

  test('仅有持久绑定时仍直接显示CID且不查链', () async {
    final reader = _FakeIdentityResolver(null);
    final current = CurrentUser(
      account: _aliceWallet,
      binding: const IdentityBinding(
        genesisHash: '0x0000000000000000000000000000000000000000000000000000000000000000',
        cidNumber: 'CID-LOCAL-TEST',
        bindRev: 1,
        accountId: _validAccountId,
      ),
    );
    final service = testService(
      identityResolver: reader,
      badgeSnapshotStore: IdentityBadgeSnapshotStore(),
      currentUserContext: _LocalCurrentUser(current),
    );
    final state = await service.getState();
    expect(state.cidNumber, 'CID-LOCAL-TEST');
    expect(state.votingAccountId, _validAddress);
    expect(reader.reads, 0);
  });

  group('注册前余额闸 fetchRegistrationAffordability', () {
    test('门槛取自链上常量,余额旁路缓存读取', () async {
      final rpc = _FakeChain()
        ..minSelfPayFen = BigInt.from(121)
        ..balanceFen = BigInt.from(121);
      final service = testService(chain: rpc);
      final result = await service.fetchRegistrationAffordability(
        _validAccountId,
      );
      expect(result.requiredFen, BigInt.from(121));
      expect(result.balanceFen, BigInt.from(121));
    });

    test('链读失败必须上抛,绝不静默当成余额充足或不足', () async {
      final rpc = _FakeChain()..balanceThrows = true;
      final service = testService(chain: rpc);
      await expectLater(
        service.fetchRegistrationAffordability(_validAccountId),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('无默认账户时为访客并提示创建钱包', () async {
    final state = await buildService(noWallet: true).refreshState();
    expect(state.tier, MyIdTier.visitor);
    expect(state.votingAccountId, isNull);
    expect(state.errorMessage, '请先创建钱包');
  });

  test('MyId 身份只读不构造 ChatRuntime', () async {
    final liveChatRuntimeCount = ChatRuntime.debugLiveInstanceCount;
    final service = buildService(noWallet: true);
    await service.refreshState();
    expect(
      ChatRuntime.debugLiveInstanceCount,
      lessThanOrEqualTo(liveChatRuntimeCount),
      reason: 'Wallet/MyId 普通读取不得惰性之外构造 ChatRuntime',
    );
  });

  test('默认账户链上无投票身份时为访客轻节点', () async {
    final state = await buildService(voting: null).refreshState();
    expect(state.tier, MyIdTier.visitor);
    expect(state.votingAccountId, isNull);
    expect(state.status, isNull);
    expect(state.isAnonymousRegistered, isFalse);
    expect(state.cidNumber, isNull);
  });

  test('有 CID、绑定闭环但无投票身份时为匿名已注册(访客卡显 CID)', () async {
    final state = await buildService(voting: null, hasCid: true).refreshState();
    // 仍是访客档(不新增卡/色),但已占匿名 CID → isAnonymousRegistered。
    expect(state.tier, MyIdTier.visitor);
    expect(state.isAnonymousRegistered, isTrue);
    expect(state.cidNumber, 'GD-CTZN1-8F3A2B');
    expect(state.votingAccountId, _validAddress);
    expect(state.status, isNull);
  });

  test('有投票身份、无候选身份时为投票公民并解出全部字段', () async {
    final state = await buildService(
      voting: _encodeVoting(
        from: 20260101,
        until: 20310101,
        status: 0,
        province: 'GD',
        city: '0755',
        town: '001',
      ),
    ).refreshState();

    expect(state.tier, MyIdTier.voting);
    expect(state.status, MyIdStatus.normal);
    expect(state.votingAccountId, _validAddress);
    expect(state.cidNumber, 'GD-CTZN1-8F3A2B');
    expect(state.passportValidFrom, '2026-01-01');
    expect(state.passportValidUntil, '2031-01-01');
    // 居住选区经字典 join:省名 + 市名 + 镇名(fake 字典把 code 映射成 N(code))。
    expect(state.residenceDistrict, contains('N(0755)'));
    expect(state.residenceDistrict, contains('N(001)'));
    // 投票公民无候选专属字段。
    expect(state.familyName, isNull);
    expect(state.givenName, isNull);
    expect(state.birthDistrict, isNull);
  });

  test('同时有候选身份时为竞选公民并解出姓名/性别/出生地', () async {
    final state = await buildService(
      voting: _encodeVoting(
        from: 20260101,
        until: 20310101,
        status: 0,
        province: 'GD',
        city: '0755',
        town: '001',
      ),
      candidate: _encodeCandidate(
        province: 'GD',
        city: '0020',
        town: '005',
        familyName: '陈',
        givenName: '明',
        sex: 0,
      ),
    ).refreshState();

    expect(state.tier, MyIdTier.candidate);
    expect(state.familyName, '陈');
    expect(state.givenName, '明');
    expect(state.citizenSexLabel, '男');
    expect(state.birthDistrict, contains('N(0020)'));
    expect(state.citizenBirthDate, '2000-01-31');
  });

  test('护照未生效/已过期/已吊销状态派生正确', () async {
    Uint8List voting({required int status}) => _encodeVoting(
      from: 20260101,
      until: 20310101,
      status: status,
      province: 'GD',
      city: '0755',
      town: '001',
    );

    final notYet = await buildService(
      voting: voting(status: 0),
      now: DateTime.utc(2025),
    ).refreshState();
    expect(notYet.status, MyIdStatus.notYetValid);

    final expired = await buildService(
      voting: voting(status: 0),
      now: DateTime.utc(2032),
    ).refreshState();
    expect(expired.status, MyIdStatus.expired);

    final revoked = await buildService(voting: voting(status: 1))
        .refreshState();
    expect(revoked.status, MyIdStatus.revoked);
  });

  test('链上读取失败时不静默降级访客,而是标记读取失败', () async {
    final state = await buildService(chainThrows: true).refreshState();
    expect(state.status, MyIdStatus.queryFailed);
    expect(state.errorMessage, '身份同步失败，请重试');
  });

  test('反向钱包错配或 CID 已吊销时不承认公民身份', () async {
    final voting = _encodeVoting(
      from: 20260101,
      until: 20310101,
      status: 0,
      province: 'GD',
      city: '0755',
      town: '001',
    );

    final mismatch = await buildService(
      voting: voting,
      mismatchWallet: true,
    ).refreshState();
    final revoked = await buildService(
      voting: voting,
      cidStatus: 1,
    ).refreshState();

    expect(mismatch.tier, MyIdTier.visitor);
    expect(revoked.tier, MyIdTier.visitor);
  });

  test('空居住镇码不会把公民误判为访客', () async {
    final state = await buildService(
      voting: _encodeVoting(
        from: 20260101,
        until: 20310101,
        status: 0,
        province: 'GD',
        city: '0755',
        town: '', // 空镇码
      ),
    ).refreshState();
    expect(state.tier, MyIdTier.voting);
    expect(state.cidNumber, 'GD-CTZN1-8F3A2B');
  });

  test('注册匿名 CID:用账户0 accountId + UTC 年生成金标 CID 并提交自签占号', () async {
    final identityCache = _InvalidationCountingIdentityCache();
    final fakeWallet = _FakeWalletManager(_aliceWallet);
    final fakeRpc = _FakeIdentityTransaction();
    final expected = generateCitizenCid(
      accountId: _validAccountId,
      institution: kCidInstitutionCitizen,
      year: 2026,
    );
    final service = testService(
      wallet: fakeWallet,
      chain: _FakeChain(),
      identityTransaction: fakeRpc,
      identityResolver: _FakeIdentityResolver(
        _registeredIdentity(_validAccountId, cidNumber: expected),
      ),
      currentUserContext: identityCache,
      cidYearProvider: () => 2026,
    );

    final cid = await service.registerAnonymousCid(
      context: null,
      institution: kCidInstitutionCitizen,
    );

    // 与 cid_generator 金标同源:account_id=_validAccountId, CTZN, 2026。
    expect(cid, expected);
    expect(fakeRpc.occupiedCid, expected);
    expect(fakeRpc.occupiedAccountId, _validAccountId);
    // 公开绑定激活前与finally广播前各失效一次；身份通知仍仅发送一次。
    expect(identityCache.invalidateCalls, 2);
    expect(fakeWallet.identityNotifications, 1);
  });

  test('MyIdService默认签名入口签完整授权的0x11摘要，真实SDK外部会话验签通过', () async {
    final hot = await openTestSdk(
      modules:
          CitizenSdkModules.wallet |
          CitizenSdkModules.signing |
          CitizenSdkModules.qr,
      vaultMode: 1,
    );
    const mnemonic =
        'bottom drive obey lake curtain smoke basket hold race lonely fit walk';
    await hot.sdk.importWallet(mnemonic: mnemonic).result;
    final profile = await hot.sdk
        .addAccounts(
          mnemonic: mnemonic,
          derivation: CitizenAccountDerivation.sr25519,
          indices: [1, 2],
        )
        .result;
    final old = profile.accounts.firstWhere((a) => a.index == 1).accountId;
    final target = profile.accounts.firstWhere((a) => a.index == 2).accountId;
    final wallet = _FakeWalletManager(
      _testAccount(
        accountId: old,
        accountAddress: citizenSs58FromAccountId(old),
        accountIndex: 0,
        name: '原账户',
      ),
      accounts: [
        _testAccount(
          accountId: target,
          accountAddress: citizenSs58FromAccountId(target),
          accountIndex: 2,
          name: '目标账户',
        ),
      ],
    );
    final transaction = _FakeIdentityTransaction(currentAccountId: old);
    final service = testService(
      signing: hot.sdk,
      useDefaultSigner: true,
      wallet: wallet,
      identityTransaction: transaction,
      identityResolver: _SequenceResolver([
        _registeredIdentity(old),
        _registeredIdentity(target, bindRev: 2),
      ]),
    );
    await service.rebindCidTo(
      buildContext: null,
      cidNumber: 'GD-CTZN1-8F3A2B',
      newAccountId: target,
    );
    expect(wallet.signCalls, 0, reason: '必须走生产默认签名入口');
    final authorization = CitizenIdentityTransaction.buildRebindAuthorization(
      genesisHash: Uint8List.fromList(List.filled(32, 0x42)),
      cidNumber: 'GD-CTZN1-8F3A2B',
      currentAccountId: old,
      newAccountId: target,
      expectedBindingRevision: BigInt.one,
    );
    final verifier = await openTestSdk(
      modules:
          CitizenSdkModules.wallet |
          CitizenSdkModules.signing |
          CitizenSdkModules.qr,
      vaultMode: 1,
    );
    await verifier.sdk.importColdAccount(old).result;
    final pending =
        await verifier.sdk
                .beginSigning(
                  CitizenSigningIntent(
                    accountId: old,
                    payload: authorization,
                    opaqueAction: CitizenQrActions.cidRebind,
                    externalSignerTransport:
                        CitizenExternalSignerTransport.qrV1,
                    transform: CitizenSigningTransform.blake2Domain(
                      await CitizenSdk.encodePayload(
                        CitizenSigningPayload.binaryPrefix(kOpSignCidRebind),
                      ),
                    ),
                  ),
                )
                .result
            as CitizenExternalSigningPending;
    final response = await verifier.sdk.encodeDocument(
      CitizenQrContent.signResponse(
        requestId: pending.sessionId,
        expiresAt: pending.expiresAt,
        signerAccountId: old,
        signature: transaction.reboundSignature!,
      ),
    );
    final verified = await verifier.sdk
        .consumeExternalSignature(
          sessionId: pending.sessionId,
          response: response.canonicalText,
        )
        .result;
    expect(verified.signature, transaction.reboundSignature);
    expect(wallet.bindings.single.accountId, target);
  });

  test('自主换绑保留当前账户授权；finalized 后仅由新账户接管', () async {
    final newAccount = _testAccount(
      accountIndex: 5,
      accountId: '0x${'11' * 32}',
      accountAddress: 'new-ss58',
      name: '账户5',
    );
    final fakeRpc = _FakeIdentityTransaction();
    final fakeWallet = _FakeWalletManager(_aliceWallet, accounts: [newAccount]);
    final resolver = _SequenceResolver(<FinalizedIdentity>[
      _registeredIdentity(_validAccountId),
      _registeredIdentity(newAccount.accountId, bindRev: 2),
    ]);
    final metadataRuntime = _BindingRuntime();
    final service = testService(
      runtime: metadataRuntime,
      badgeSnapshotStore: IdentityBadgeSnapshotStore(),
      wallet: fakeWallet,
      chain: _FakeChain(),
      identityTransaction: fakeRpc,
      identityResolver: resolver,
    );

    await service.rebindCidTo(
      buildContext: null,
      cidNumber: 'GD-CTZN1-8F3A2B',
      newAccountId: newAccount.accountId,
    );

    // 原账户交付完整授权，动作19与签名域0x11保持独立。
    expect(fakeWallet.signedAction, CitizenQrActions.cidRebind);
    expect(fakeWallet.signedAction, 19);
    expect(fakeWallet.signedAccount, _validAccountId);
    expect(
      fakeWallet.signedPayload,
      CitizenIdentityTransaction.buildRebindAuthorization(
        genesisHash: Uint8List.fromList(List<int>.filled(32, 0x42)),
        cidNumber: 'GD-CTZN1-8F3A2B',
        currentAccountId: _validAccountId,
        newAccountId: newAccount.accountId,
        expectedBindingRevision: BigInt.one,
      ),
    );
    expect(fakeWallet.signedPayload!.length, greaterThan(32));

    // 链上换绑参数传对。
    expect(fakeRpc.reboundCid, 'GD-CTZN1-8F3A2B');
    expect(fakeRpc.reboundOld, _validAccountId);
    expect(fakeRpc.reboundNew, newAccount.accountId);
    // runtime 调用参数仍包含当前绑定账户，证明自主换绑授权没有被接管阶段替代。
    expect(fakeRpc.reboundOld, _validAccountId);
    // finalized 激活新绑定后同步原设备，不重新占号或创建设备。
    expect(fakeWallet.bindings.single.accountId, newAccount.accountId);
    expect(fakeWallet.bindings.single.bindingRevision, 2);
    expect(fakeWallet.mlsDeviceRegistrationCalls, 0);
    expect(metadataRuntime.observed!.userId, 'GD-CTZN1-8F3A2B');
    expect(metadataRuntime.observed!.accountId, newAccount.accountId);
    expect(metadataRuntime.observed!.bindingRevision, 2);
    expect(fakeRpc.occupiedCid, isNull, reason: '已有公民号换绑收敛不得再次占号');
    expect(
      (await fakeWallet.getWalletState().result).defaultAccount?.accountId,
      newAccount.accountId,
    );
    expect((await service.getState()).cidNumber, 'GD-CTZN1-8F3A2B');
    expect(fakeWallet.signCalls, 1, reason: '仅原账户授权，默认切换不得再请求签名');
  });

  test('链上换绑完成但SDK未切默认时，不激活展示或报告完整成功', () async {
    final target = _testAccount(
      accountId: '0x${'11' * 32}',
      accountAddress: 'new-ss58',
      accountIndex: 5,
      name: '目标账户',
    );
    final wallet = _FakeWalletManager(_aliceWallet, accounts: [target]);
    final service = testService(
      wallet: wallet,
      sdkSwitchesDefault: false,
      identityResolver: _FakeIdentityResolver(
        _registeredIdentity(_validAccountId),
      ),
      identityTransaction: _FakeIdentityTransaction(),
    );
    await expectLater(
      service.rebindCidTo(
        buildContext: null,
        cidNumber: 'GD-CTZN1-8F3A2B',
        newAccountId: target.accountId,
      ),
      throwsA(isA<AccountSecurityException>()),
    );
    expect(wallet.bindings, isEmpty);
    expect(wallet.bindingSyncs, isEmpty);
    expect(wallet.identityNotifications, 0);
    expect(wallet.signCalls, 1);
    expect(
      (await wallet.getWalletState().result).defaultAccount?.accountId,
      _validAccountId,
    );
  });

  test('换绑 finalized 后立即同步原设备绑定，不等待会话失败', () async {
    final newAccount = _testAccount(
      accountIndex: 5,
      accountId: '0x${'11' * 32}',
      accountAddress: 'new-ss58',
      name: '账户5',
    );
    final fakeWallet = _FakeWalletManager(_aliceWallet, accounts: [newAccount]);
    final resolver = _MutableResolver(_validAccountId);
    final service = testService(
      wallet: fakeWallet,
      chain: _FakeChain(),
      identityTransaction: _FakeIdentityTransaction(
        onRebound: () =>
            resolver.setAccountId(newAccount.accountId, bindRev: 2),
      ),
      identityResolver: resolver,
    );

    await service.rebindCidTo(
      buildContext: null,
      cidNumber: 'GD-CTZN1-8F3A2B',
      newAccountId: newAccount.accountId,
    );
    expect(fakeWallet.bindings.single.accountId, newAccount.accountId);
    expect(fakeWallet.mlsDeviceRegistrationCalls, 0);
    expect(fakeWallet.bindingSyncs.single.accountId, newAccount.accountId);
    expect(fakeWallet.bindingSyncs.single.bindRev, 2);
    fakeWallet.bindingSyncSucceeds = false;
    await service.refreshState();
    fakeWallet.bindingSyncSucceeds = true;
    await service.refreshState();
    expect(fakeWallet.bindingSyncs, hasLength(3));
    expect(fakeWallet.signCalls, 1, reason: '同步重试不得重新提交链上换绑');
  });

  test('换绑 extrinsic finalized 但目标状态未确认时绝不迁移本地数据', () async {
    final newAccount = _testAccount(
      accountIndex: 5,
      accountId: '0x${'11' * 32}',
      accountAddress: 'new-ss58',
      name: '账户5',
    );
    final fakeWallet = _FakeWalletManager(_aliceWallet, accounts: [newAccount]);
    final service = testService(
      wallet: fakeWallet,
      chain: _FakeChain(),
      identityTransaction: _FakeIdentityTransaction(
        rebindError: StateError('finalized 目标绑定未生效'),
      ),
      identityResolver: _FakeIdentityResolver(
        _registeredIdentity(_validAccountId),
      ),
    );

    await expectLater(
      service.rebindCidTo(
        buildContext: null,
        cidNumber: 'GD-CTZN1-8F3A2B',
        newAccountId: newAccount.accountId,
      ),
      throwsA(isA<StateError>()),
    );

    expect(fakeWallet.mlsDeviceRegistrationCalls, 0);
    expect(fakeWallet.bindingSyncs, isEmpty);
    expect(fakeWallet.bindings, isEmpty);
  });

  test('换绑目标 == 当前身份账户时拒', () async {
    final self = _testAccount(
      accountIndex: 0,
      accountId: _validAccountId,
      accountAddress: _validAddress,
      name: '账户0',
    );
    final wallet = _FakeWalletManager(_aliceWallet, accounts: [self]);
    final identityRpc = _FakeIdentityTransaction();
    final service = testService(
      wallet: wallet,
      chain: _FakeChain(),
      identityTransaction: identityRpc,
      identityResolver: _FakeIdentityResolver(
        _registeredIdentity(_validAccountId),
      ),
    );

    await expectLater(
      service.rebindCidTo(
        buildContext: null,
        cidNumber: 'GD-CTZN1-8F3A2B',
        newAccountId: _validAccountId,
      ),
      throwsA(isA<AccountSecurityException>()),
    );
    expect(wallet.signCalls, 0, reason: '相同 account_id 必须在读取私钥前拒绝');
    expect(identityRpc.fetchRebindContextCalls, 0);
  });

  test('listRebindTargets 排除当前身份账户', () async {
    final self = _testAccount(
      accountIndex: 0,
      accountId: _validAccountId,
      accountAddress: _validAddress,
      name: '账户0',
    );
    final other = _testAccount(
      accountIndex: 1,
      accountId: '0x${'22' * 32}',
      accountAddress: 'other-ss58',
      name: '账户1',
    );
    final service = testService(
      wallet: _FakeWalletManager(_aliceWallet, accounts: [self, other]),
      chain: _FakeChain(),
      identityResolver: _FakeIdentityResolver(
        _registeredIdentity(_validAccountId),
      ),
    );

    final targets = await service.listRebindTargets();
    expect(targets.map((account) => account.accountId).toList(), [
      other.accountId,
    ]);
  });

  test('listBindableAccounts 返回全部本地账户(含账户0)', () async {
    final acc0 = _testAccount(
      accountIndex: 0,
      accountId: _validAccountId,
      accountAddress: _validAddress,
      name: '账户0',
    );
    final acc5 = _testAccount(
      accountIndex: 5,
      accountId: '0x${'55' * 32}',
      accountAddress: 'ss5-addr',
      name: '账户5',
    );
    final service = testService(
      wallet: _FakeWalletManager(_aliceWallet, accounts: [acc0, acc5]),
      chain: _FakeChain(),
    );

    final accounts = await service.listBindableAccounts();
    expect(accounts.map((a) => a.accountIndex).toList(), [0, 5]);
  });

  test('注册匿名 CID 可绑到所选子账户 //5(非账户0)', () async {
    final acc5 = _testAccount(
      accountIndex: 5,
      accountId: '0x${'55' * 32}',
      accountAddress: 'ss5-addr',
      name: '账户5',
    );
    final fakeRpc = _FakeIdentityTransaction();
    final expected = generateCitizenCid(
      accountId: acc5.accountId,
      institution: kCidInstitutionCitizen,
      year: 2026,
    );
    final service = testService(
      wallet: _FakeWalletManager(_aliceWallet, accounts: [acc5]),
      chain: _FakeChain(
        hasCid: true,
        registeredCid: expected,
        boundAccountId: acc5.accountId,
      ),
      identityTransaction: fakeRpc,
      identityResolver: _FakeIdentityResolver(
        _registeredIdentity(acc5.accountId, cidNumber: expected),
      ),
      cidYearProvider: () => 2026,
    );

    final cid = await service.registerAnonymousCid(
      context: null,
      institution: kCidInstitutionCitizen,
      bindAccountId: acc5.accountId,
    );

    expect(cid, expected);
    expect(fakeRpc.occupiedCid, expected);
    // 绑到子账户 //5,而非默认账户0。
    expect(fakeRpc.occupiedAccountId, acc5.accountId);
  });
}

// ── SCALE 编码夹具(镜像 citizen-identity pallet 的 VotingIdentity/CandidateIdentity 布局) ──

List<int> _compact(int n) {
  if (n < 64) return [n << 2];
  if (n < 16384) {
    final x = (n << 2) | 1;
    return [x & 0xff, (x >> 8) & 0xff];
  }
  throw ArgumentError('测试夹具只覆盖短向量');
}

List<int> _vec(String s) {
  final bytes = utf8.encode(s);
  return [..._compact(bytes.length), ...bytes];
}

List<int> _u32(int v) => [
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
];

Uint8List _encodeVoting({
  required int from,
  required int until,
  required int status,
  required String province,
  required String city,
  required String town,
  int updatedAt = 1,
}) {
  return Uint8List.fromList([
    ..._u32(from),
    ..._u32(until),
    status,
    ..._vec(province),
    ..._vec(city),
    ..._vec(town),
    ..._u32(updatedAt),
  ]);
}

Uint8List _encodeCandidate({
  required String province,
  required String city,
  required String town,
  required String familyName,
  required String givenName,
  required int sex,
  int birthDate = 20000131,
  int updatedAt = 1,
}) {
  return Uint8List.fromList([
    ..._vec(province),
    ..._vec(city),
    ..._vec(town),
    ..._vec(familyName),
    ..._vec(givenName),
    sex,
    ..._u32(birthDate),
    ..._u32(updatedAt),
  ]);
}

// ── Fakes ──

class _FakeWalletManager extends TestWalletReads
    implements AccountSecurityService {
  _FakeWalletManager(
    this._wallet, {
    this.accounts = const <CitizenWalletStateAccount>[],
  });
  CitizenWalletStateAccount? _wallet;
  @override
  final revision = ValueNotifier<int>(0);
  final List<CitizenWalletStateAccount> accounts;
  BigInt catalogRevision = BigInt.one;

  int mlsDeviceRegistrationCalls = 0;
  final bindingSyncs = <IdentityBinding>[];
  bool bindingSyncSucceeds = true;

  /// finalized公开绑定激活记录。
  final List<({String cidNumber, int bindingRevision, String accountId})>
  bindings = [];
  final List<String> events = <String>[];
  int signCalls = 0;
  Uint8List? signedPayload;
  int? signedAction;
  String? signedAccount;
  int identityNotifications = 0;
  IdentityBinding? activeBinding;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: _wallet == null && accounts.isEmpty
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: catalogRevision,
          hotProfile: null,
          accounts: <CitizenWalletStateAccount>[
            ?_wallet,
            ...accounts.where(
              (account) => account.accountId != _wallet?.accountId,
            ),
          ],
        ),
      );

  Future<Uint8List> signPayload(
    String accountId,
    Uint8List payload,
    int action,
    BuildContext? context,
  ) async {
    signCalls++;
    signedPayload = Uint8List.fromList(payload);
    signedAction = action;
    signedAccount = accountId;
    return Uint8List(64);
  }

  @override
  Future<void> activateIdentityBinding({
    required String genesisHash,
    required String cidNumber,
    required int bindRev,
    required String accountId,
    bool notify = true,
  }) async {
    expect(genesisHash, '0x${'42' * 32}');
    events.add('activate');
    bindings.add((
      cidNumber: cidNumber,
      bindingRevision: bindRev,
      accountId: accountId,
    ));
    activeBinding = IdentityBinding(
      genesisHash: genesisHash,
      cidNumber: cidNumber,
      bindRev: bindRev,
      accountId: accountId,
    );
  }

  @override
  Future<IdentityBinding?> readIdentityBindingForCid(String cidNumber) async =>
      activeBinding?.cidNumber == cidNumber ? activeBinding : null;

  @override
  Future<IdentityBinding?> readIdentityBindingForAccountId(
    String accountId,
  ) async => activeBinding?.accountId == accountId ? activeBinding : null;

  @override
  Future<bool> synchronizeMlsBinding(IdentityBinding binding) async {
    expect(activeBinding?.accountId, binding.accountId);
    expect(_wallet?.accountId, binding.accountId);
    bindingSyncs.add(binding);
    return bindingSyncSucceeds;
  }

  @override
  Future<void> registerMlsDeviceForBinding(IdentityBinding binding) async {
    mlsDeviceRegistrationCalls++;
  }

  @override
  void notifyIdentityBindingChanged() {
    identityNotifications++;
    revision.value++;
  }
}

class _NotifyingWalletManager extends _FakeWalletManager {
  _NotifyingWalletManager(super.wallet);

  @override
  Future<void> activateIdentityBinding({
    required String genesisHash,
    required String cidNumber,
    required int bindRev,
    required String accountId,
    bool notify = true,
  }) async {
    await super.activateIdentityBinding(
      genesisHash: genesisHash,
      cidNumber: cidNumber,
      bindRev: bindRev,
      accountId: accountId,
      notify: notify,
    );
    if (notify) notifyIdentityBindingChanged();
  }
}

class _UnusedChatHost implements ChatRuntimeFixture {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSessionProvider implements SquareSessionProvider {
  @override
  void invalidateAccount(String accountId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 预设身份账户解析结果的假 resolver(换绑/列举目标测试用,绕开真链读序列)。
class _FakeIdentityResolver implements FinalizedIdentityResolver {
  _FakeIdentityResolver(this._resolved);
  final FinalizedIdentity? _resolved;
  int reads = 0;
  @override
  Future<FinalizedIdentity?> resolve() async {
    reads++;
    return _resolved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InvalidationCountingIdentityCache implements CurrentUserContext {
  int invalidateCalls = 0;

  @override
  void invalidate() {
    invalidateCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SequenceResolver implements FinalizedIdentityResolver {
  _SequenceResolver(this._values);
  final List<FinalizedIdentity> _values;
  int _index = 0;

  @override
  Future<FinalizedIdentity?> resolve() async {
    final index = _index < _values.length ? _index++ : _values.length - 1;
    return _values[index];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 可变身份账户的假 resolver(对账测试:换绑前后链上身份账户切换)。
class _MutableResolver implements FinalizedIdentityResolver {
  _MutableResolver(this._accountId, {int bindRev = 1})
    : _bindingRevision = bindRev;
  String _accountId;
  int _bindingRevision;
  void setAccountId(String accountId, {required int bindRev}) {
    _accountId = accountId;
    _bindingRevision = bindRev;
  }

  @override
  Future<FinalizedIdentity?> resolve() async =>
      _registeredIdentity(_accountId, bindRev: _bindingRevision);

  @override
  Future<void> assertCurrent(FinalizedIdentity identity) async {
    if (identity.accountId != _accountId ||
        identity.snapshot?.bindRev != _bindingRevision) {
      throw const AccountSecurityException('合成账户已变化', code: 'identityChanged');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 造一个「已注册(匿名)身份账户」解析结果:account_id 绑了 CID(snapshot 非空)。
FinalizedIdentity _registeredIdentity(
  String accountId, {
  String cidNumber = 'GD-CTZN1-8F3A2B',
  int bindRev = 1,
}) => FinalizedIdentity(
  accountId: accountId,
  accountAddress: citizenSs58FromAccountId(accountId),
  snapshot: CitizenIdentityChainSnapshot(
    cidNumber: cidNumber,
    accountId: Uint8List.fromList(
      List.generate(
        32,
        (i) => int.parse(accountId.substring(2 + i * 2, 4 + i * 2), radix: 16),
      ),
    ),
    bindRev: bindRev,
    votingIdentity: null,
    candidateIdentity: null,
  ),
);

/// 记录占号 / 换绑调用参数的假 RPC(不上链),验证 service 编排把账户与 CID 传对。
class _FakeIdentityTransaction extends CitizenIdentityTransaction {
  _FakeIdentityTransaction({
    this.rebindError,
    this.onRebound,
    this.currentAccountId = _validAccountId,
  }) : super();

  final String currentAccountId;
  Uint8List? reboundSignature;

  final Object? rebindError;
  final void Function()? onRebound;
  void Function(String)? onSdkDefaultCommitted;
  String? occupiedCid;
  String? occupiedAccountId;
  String? reboundCid;
  String? reboundOld;
  String? reboundNew;
  int fetchRebindContextCalls = 0;

  @override
  Future<({String txHash, int usedNonce, String blockHash})> selfOccupyCid({
    required String cidNumber,
    required String accountId,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    occupiedCid = cidNumber;
    occupiedAccountId = accountId;
    return (txHash: '0xtx', usedNonce: 0, blockHash: '0xblk');
  }

  @override
  Future<({String txHash, int usedNonce, String blockHash})>
  selfRebindCidAccount({
    required String cidNumber,
    required String newAccountId,
    required String currentAccountId,
    required SelfRebindAuthorizationContext context,
    required Uint8List currentAccountSignature,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final error = rebindError;
    if (error != null) throw error;
    reboundCid = cidNumber;
    reboundNew = newAccountId;
    reboundOld = currentAccountId;
    reboundSignature = Uint8List.fromList(currentAccountSignature);
    onRebound?.call();
    onSdkDefaultCommitted?.call(newAccountId);
    return (txHash: '0xtx', usedNonce: 0, blockHash: '0xblk');
  }

  @override
  Future<SelfRebindAuthorizationContext> fetchSelfRebindAuthorizationContext(
    String cidNumber,
  ) async {
    fetchRebindContextCalls++;
    return SelfRebindAuthorizationContext(
      genesisHash: Uint8List.fromList(List<int>.filled(32, 0x42)),
      currentAccountId: currentAccountId,
      expectedBindingRevision: BigInt.one,
    );
  }
}

class _FakeChain extends TestChainReads {
  _FakeChain({
    this.voting,
    this.candidate,
    this.throws = false,
    this.mismatchWallet = false,
    this.cidStatus = 0,
    this.hasCid = false,
    this.registeredCid,
    this.boundAccountId,
  });
  final Uint8List? voting;
  final Uint8List? candidate;
  final bool throws;
  static const String cidNumber = 'GD-CTZN1-8F3A2B';
  final bool mismatchWallet;
  final int cidStatus;

  /// 是否存在 `CidByAccountId`。有 voting 必有 cid;匿名态显式置 true 表示
  /// 「有 CID 且绑定闭环、但无 voting」,用来驱动 reader 的匿名已注册分支。
  final bool hasCid;
  final String? registeredCid;
  final String? boundAccountId;
  int _readIndex = 0;

  /// 链上下发的自付门槛(分)与账户余额(分),供注册前余额闸用例驱动三分支。
  BigInt minSelfPayFen = BigInt.from(121);
  BigInt balanceFen = BigInt.zero;
  bool balanceThrows = false;

  @override
  Future<String> getGenesisHash() async => '0x${'42' * 32}';

  @override
  Future<CitizenFeeSnapshot> getFeeSnapshot() async {
    if (balanceThrows) throw StateError('metadata 未就绪');
    return CitizenFeeSnapshot(
      bestBlock: _bestBlock,
      feeRateParts: 1000000,
      minimumFeeFen: BigInt.from(10),
      existentialDepositFen: minSelfPayFen - BigInt.from(10),
      FLAT_FEE: BigInt.from(100),
      feeFen: BigInt.from(10),
      minimumSelfPayFen: minSelfPayFen,
    );
  }

  @override
  Future<CitizenAccountBalance> getAccountBalance(String accountId) async {
    if (balanceThrows) throw StateError('CitizenSDK 链状态未就绪');
    return CitizenAccountBalance(
      accountId: accountId,
      block: _finalizedBlock,
      freeFen: balanceFen,
      reservedFen: BigInt.zero,
      totalFen: balanceFen,
    );
  }

  @override
  Future<CitizenBlockRef> getFinalizedHead() async => _finalizedBlock;

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    if (throws) throw StateError('CitizenSDK 链状态未就绪');
    final current = _readIndex++;
    if (current == 0) {
      // 有投票身份必有 CID;匿名态(hasCid=true)也有 CID 但后续 voting 读为 null。
      final present = voting != null || hasCid;
      return present
          ? Uint8List.fromList(_vec(registeredCid ?? cidNumber))
          : null;
    }
    if (current == 1) {
      final accountId = citizenAccountIdBytes(
        boundAccountId ?? _validAccountId,
      );
      if (mismatchWallet) accountId[0] ^= 0xff;
      return accountId;
    }
    if (current == 2) {
      return Uint8List.fromList([
        ..._vec('FEDERAL_REGISTRY-CID'),
        ...List<int>.filled(32, 7),
        ..._vec('GD'),
        ..._vec('0755'),
        cidStatus,
        ..._u32(1),
        0,
      ]);
    }
    if (current == 3) return voting;
    if (current == 4) return candidate;
    if (current == 5) return Uint8List.fromList(<int>[1, 0, 0, 0, 0, 0, 0, 0]);
    throw StateError('读取次数超出身份闭环');
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async => Future.wait(keys.map((key) => getStorage(block, key)));

  static final CitizenBlockRef _finalizedBlock = CitizenBlockRef(
    hash: '0x${'00' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.finalized,
  );

  static final CitizenBlockRef _bestBlock = CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.best,
  );
}

class _FakeDivisionStore implements AdminDivisionStore {
  @override
  Future<String> regionName({
    required String provinceCode,
    String cityCode = '',
    String townCode = '',
  }) async =>
      'N(${townCode.isNotEmpty
          ? townCode
          : cityCode.isNotEmpty
          ? cityCode
          : provinceCode})';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeBadgeStore extends IdentityBadgeSnapshotStore {
  @override
  Future<void> writeVerified({
    required String accountId,
    required CitizenIdentityChainSnapshot? identity,
    required bool Function() isCurrent,
  }) async {}

  @override
  Future<void> write({
    required String cidNumber,
    required String cidLevel,
  }) async {}
  @override
  Future<IdentityBadgeSnapshot?> read(String cidNumber) async => null;
}

class _FailingBadgeStore extends _FakeBadgeStore {
  bool fail = false;

  @override
  Future<void> writeVerified({
    required String accountId,
    required CitizenIdentityChainSnapshot? identity,
    required bool Function() isCurrent,
  }) async {
    if (fail) throw StateError('synthetic display cache failure');
  }
}

class _LocalCurrentUser implements CurrentUserContext {
  _LocalCurrentUser(this.current);
  final CurrentUser? current;
  @override
  Future<CurrentUser?> resolve() async => current;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BindingRuntime extends TestChatRuntime {
  _BindingRuntime() : super(host: _UnusedChatHost());
  ChatBinding? observed;
  @override
  Future<void> convergeFinalizedBinding(ChatBinding current) async {
    observed = current;
  }
}

/// 公开同步用例仍核对每次本机代际；错误不会触发第二次链读取。
class _SyncResolver implements FinalizedIdentityResolver {
  _SyncResolver(this.identity, {this.failure = false, this.changed = false});
  FinalizedIdentity identity;
  bool failure, changed;
  Completer<FinalizedIdentity?>? pending;
  int reads = 0;
  @override
  Future<FinalizedIdentity?> resolve() async {
    reads++;
    if (failure) throw const FormatException('合成链故障');
    if (pending != null) return pending!.future;
    return identity;
  }

  @override
  Future<void> assertCurrent(FinalizedIdentity identity) async {
    if (changed) {
      throw const AccountSecurityException('当前用户已变化', code: 'identityChanged');
    }
  }
}

class _SyncSessions implements SquareSessionProvider {
  _SyncSessions(this.identity);
  final FinalizedIdentity identity;
  int registrations = 0;
  final invalidatedAccounts = <String>[];
  @override
  void invalidateAccount(String accountId) =>
      invalidatedAccounts.add(accountId);
  @override
  Future<SquareSession?> registerCurrentDevice() async {
    registrations++;
    return SquareSession(
      sessionToken: 'ordinary',
      cidNumber: identity.snapshot!.cidNumber,
      accountId: identity.accountId,
      bindRev: identity.snapshot!.bindRev,
      deviceId: 'ab' * 32,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OrderedBadgeStore extends _FakeBadgeStore {
  _OrderedBadgeStore(this.wallet);
  final _FakeWalletManager wallet;
  bool publishedAfterBinding = false;
  @override
  Future<void> writeVerified({
    required String accountId,
    required CitizenIdentityChainSnapshot? identity,
    required bool Function() isCurrent,
  }) async {
    publishedAfterBinding =
        wallet.activeBinding?.accountId == accountId &&
        wallet.activeBinding?.cidNumber == identity?.cidNumber;
  }
}

class _SdkErrorResolver extends _SyncResolver {
  _SdkErrorResolver(super.identity, this.code);
  final CitizenSdkErrorCode code;
  @override
  Future<FinalizedIdentity?> resolve() async =>
      throw CitizenSdkException(code: code, message: '合成错误');
}
