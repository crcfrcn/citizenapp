// 提供创作者、会员和主页测试共用的夹具。

import 'package:citizen_chain/service.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/chain.dart' as f;
import 'package:citizen_user/creator/service.dart' show CreatorOverview, CreatorPageData, CreatorService;
import 'package:citizen_user/creator/page.dart' show CreatorPage;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_user/identity/state.dart' show CidBusinessDecision, CidBusinessGate, CidBusinessStatus;
import 'package:citizen_user/context.dart' show CurrentUser, CurrentUserContext, IdentityBinding;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// 提供创作者页面的身份、门禁和服务测试端口。

class CreatorTestUser extends Fake implements CurrentUserContext {
  String ownerAccountId = f.account(1);
  String cidNumber = f.cidA;
  int bindRev = 1;
  String genesisHash = f.hash(0);
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      accountId: ownerAccountId,
      ss58Address: citizenSs58FromAccountId(ownerAccountId),
      name: '测试',
      walletIndex: 0,
      accountIndex: 0,
      isDefault: true,
      createdAtMillis: BigInt.one,
      signMode: CitizenWalletSignMode.hot,
    ),
    binding: IdentityBinding(
      genesisHash: genesisHash,
      accountId: ownerAccountId,
      cidNumber: cidNumber,
      bindRev: bindRev,
    ),
  );
}

class CreatorTestGate extends Fake implements CidBusinessGate {
  CreatorTestGate(this.user);
  final CreatorTestUser user;
  Future<CidBusinessDecision>? decision;
  @override
  final revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() =>
      decision ??
      Future.value(
        CidBusinessDecision(CidBusinessStatus.ready, cidNumber: user.cidNumber),
      );
}

class CreatorTestSecurity extends Fake implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
}

class CreatorTestService extends Fake implements CreatorService {
  int loadCalls = 0;
  int cacheCalls = 0;
  Future<CreatorOverview?> Function(String)? readOverview;
  Future<CreatorPageData> Function()? refresh;
  @override
  Future<CreatorOverview?> cachedOverview(String cid) async {
    cacheCalls++;
    return readOverview == null ? null : await readOverview!(cid);
  }

  @override
  Future<CreatorPageData> load({String? expectedCidNumber}) async {
    loadCalls++;
    return refresh == null ? const CreatorPageData() : await refresh!();
  }
}

Widget creatorTestApp({
  required ChainDataService source,
  required CreatorTestUser user,
  required CreatorTestService service,
  CreatorTestGate? gate,
  CreatorTestSecurity? security,
  Widget? home,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<ChainDataService>.value(value: source),
    Provider<CurrentUserContext>.value(value: user),
    Provider<CidBusinessGate>.value(value: gate ?? CreatorTestGate(user)),
    if (security != null)
      Provider<AccountSecurityService>.value(value: security),
  ],
  child: MaterialApp(home: home ?? CreatorPage(service: service)),
);
