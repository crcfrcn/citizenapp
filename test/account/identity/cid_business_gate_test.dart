import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import 'package:citizenapp/account/identity/cid_business_gate.dart';
import 'package:citizenapp/account/identity/citizen_identity_chain_reader.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/finalized_identity_resolver.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/identity_register_guide.dart';

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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
