import 'dart:async';

import 'package:citizen_user/creator/creator_page.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';

import 'package:citizen_testing/isar_test_env.dart';

import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/identity/cid_business_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:citizen_user/notifications.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/creator/creator_overview.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_testing/mls_authentication_fixture.dart';

class _BusinessGate implements CidBusinessGate {
  _BusinessGate(this.result);
  Future<CidBusinessDecision> result;
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() => result;
}

Widget _creatorApp({required Widget home, CidBusinessGate? gate}) =>
    Provider<CidBusinessGate>.value(
      value:
          gate ??
          _BusinessGate(
            Future.value(
              const CidBusinessDecision(
                CidBusinessStatus.ready,
                cidNumber: 'CN220-CTZN2-100000001-2026',
              ),
            ),
          ),
      child: MaterialApp(home: home),
    );

const _cid = 'CN220-CTZN2-100000001-2026';

class _User implements CurrentUserContext {
  String cid = _cid;
  int bindRev = 1;
  @override
  Future<CurrentUser?> resolve() async {
    final account = '0x${'11' * 32}';
    return CurrentUser(
      account: CitizenWalletStateAccount(
        accountId: account,
        ss58Address: citizenSs58FromAccountId(account),
        name: '测试',
        walletIndex: 0,
        accountIndex: 0,
        isDefault: true,
        createdAtMillis: BigInt.one,
        signMode: CitizenWalletSignMode.hot,
      ),
      binding: IdentityBinding(
        genesisHash: '0x${'22' * 32}',
        cidNumber: cid,
        accountId: account,
        bindRev: bindRev,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused user boundary');
}

class _OverviewService implements CreatorService {
  @override
  Future<CreatorOverview?> cachedOverview(String cid) async => null;
  _OverviewService(this.session);
  final SquareSession session;
  final result = Completer<CreatorPageData>();
  @override
  Future<CreatorPageData> load({String? expectedCidNumber}) => result.future;
  Future<void> resolve() async {
    final overview = CreatorOverview(
      subscriberCount: 42,
      monthlyIncomeFen: BigInt.from(1234),
      blockNumber: 103,
      blockHash: '0x${"11" * 32}',
    );
    result.complete(CreatorPageData.active(overview: overview));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  useIsolatedIsar();
  for (final notificationReady in [false, true]) {
    for (final decision in MembershipDisplayDecision.values) {
      testWidgets('轻节点概览结果在通知就绪=$notificationReady、入口=$decision时正常展示', (
        tester,
      ) async {
        final user = _User()..cid = notificationReady ? _cid : '';
        final squareApi = SquareApiClient(baseUrl: 'https://review.test/api');
        Notifications.instance.invalidate();
        Notifications.instance.configure(
          api: squareApi,
          sessions: _Sessions(),
          user: user,
        );
        await tester.runAsync(() => Notifications.instance.restore());
        final session = SquareSession(
          deviceId: testMlsDeviceId,
          sessionToken: 'review',
          cidNumber: _cid,
          accountId: '0x${'11' * 32}',
          bindRev: 1,
          expiresAt: 9999999999999,
          authenticateRequest: fakeMlsRequestHeaders,
        );
        addTearDown(() {
          Notifications.instance.invalidate();
          squareApi.close();
        });
        final service = _OverviewService(session);
        await tester.pumpWidget(
          _creatorApp(
            home: CreatorPage(
              service: service,
              initialCidNumber: _cid,
              initialMembershipDecision: decision,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('刷新'));
        await tester.runAsync(() => service.resolve());
        await tester.pumpAndSettle();
        expect(find.text('42'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _Sessions extends Fake implements SquareSessionProvider {}
