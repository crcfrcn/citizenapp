// 验证通知状态不阻断概览刷新或引入额外链读取。

import 'dart:async';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_user/creator/creator_overview.dart';
import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/membership/membership_revision.dart';
import 'package:citizen_user/notifications.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'creator_test_support.dart';

class _Sessions extends Fake implements SquareSessionProvider {}

void main() {
  useIsolatedIsar();
  for (final notificationReady in [false, true]) {
    testWidgets('通知就绪=$notificationReady，会员广播不取消概览刷新也不新增链读', (tester) async {
      final user = CreatorTestUser();
      final notificationUser = CreatorTestUser()
        ..cidNumber = notificationReady ? f.cidA : '';
      final api = SquareApiClient(baseUrl: 'https://review.test/api');
      Notifications.instance.invalidate();
      Notifications.instance.configure(
        api: api,
        sessions: _Sessions(),
        user: notificationUser,
      );
      await tester.runAsync(() => Notifications.instance.restore());
      final reader = f.Reader();
      final source = ChainDataService(
        reader: reader,
        getFinalizedHead: () async => f.block(103),
        getGenesisHash: () async => f.hash(0),
        getAccount: () async => user.ownerAccountId,
      );
      final result = Completer<CreatorPageData>();
      final service = CreatorTestService()..refresh = () => result.future;
      addTearDown(() async {
        Notifications.instance.invalidate();
        api.close();
        await source.close();
      });
      await source.start();
      await tester.pumpWidget(
        creatorTestApp(source: source, user: user, service: service),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(service.loadCalls, 1);
      final before = reader.calls.length;
      MembershipRevision.instance.notifyChanged(f.cidA);
      MembershipRevision.instance.notifyChanged(f.cidB);
      await tester.pump();
      result.complete(
        CreatorPageData(
          overview: CreatorOverview(
            subscriberCount: 42,
            monthlyIncomeFen: BigInt.from(1234),
            blockNumber: 103,
            blockHash: f.hash(103),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
      expect(reader.calls.length, before);
      expect(find.text('已开通'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
