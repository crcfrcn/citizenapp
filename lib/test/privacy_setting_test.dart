import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:citizenapp/user.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Identity extends Fake implements CurrentUserContext {
  String cid = testMlsCidNumber;
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: testMlsAccountId,
      ss58Address: 'synthetic',
      name: '测试',
      createdAtMillis: BigInt.zero,
      isDefault: true,
    ),
    binding: IdentityBinding(
      genesisHash: '0x${'ab' * 32}',
      cidNumber: cid,
      accountId: testMlsAccountId,
      bindRev: 1,
    ),
  );
}

class _Sessions extends Fake implements SquareSessionProvider {
  _Sessions(this.identity);
  final _Identity identity;
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async => SquareSessionResolution(
    SquareSessionStatus.ready,
    session: SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'synthetic',
      cidNumber: identity.cid,
      accountId: testMlsAccountId,
      bindRev: 1,
      expiresAt: 9999999999999,
      authenticateRequest: fakeMlsRequestHeaders,
    ),
  );
}

class _Api extends SquareApiClient {
  DmPolicy value = DmPolicy.none;
  ProfileVisibility visibility = ProfileVisibility.public;
  final profileWrites = <ProfileVisibility>[];
  bool fail = false;
  bool failRead = false;
  final writes = <DmPolicy>[];
  Completer<DmPolicy>? pending;
  @override
  Future<PrivacySettings> fetchPrivacy(SquareSession session) async {
    if (failRead) throw StateError('测试读取失败');
    return PrivacySettings(dmPolicy: value, profileVisibility: visibility);
  }

  @override
  Future<PrivacySettings> savePrivacy(
    SquareSession session, {
    DmPolicy? dmPolicy,
    ProfileVisibility? profileVisibility,
  }) async {
    if (dmPolicy != null) writes.add(dmPolicy);
    if (profileVisibility != null) profileWrites.add(profileVisibility);
    if (fail) throw StateError('测试保存失败');
    if (pending != null) dmPolicy = await pending!.future;
    value = dmPolicy ?? value;
    visibility = profileVisibility ?? visibility;
    return PrivacySettings(dmPolicy: value, profileVisibility: visibility);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  late Directory records;
  setUp(() async {
    records = await Directory.systemTemp.createTemp('privacy_records_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemProtectedStorage.channel, (call) async {
          if (call.method == 'prepareRecords') return records.path;
          if (call.method == 'compareRecords') {
            final args = (call.arguments as Map).cast<String, dynamic>();
            final file = File('${records.path}/${args['name']}');
            final old = await file.exists() ? await file.readAsString() : null;
            if (old != args['expected']) return false;
            await file.writeAsString(args['next'] as String, flush: true);
            return true;
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemProtectedStorage.channel, null);
    if (records.existsSync()) records.deleteSync(recursive: true);
  });
  Future<void> open(
    WidgetTester tester,
    _Api api,
    _Identity user, {
    Listenable? revision,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (_) async {},
          privacyApi: api,
          privacyUserContext: user,
          privacySessionProvider: _Sessions(user),
          privacyRevision: revision,
        ),
      ),
    );
    for (var i = 0; i < 40 && find.text('隐私').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Finder tile(String key) => find.byKey(ValueKey(key));
  Future<void> choose(WidgetTester tester, String key, String value) async {
    await Scrollable.ensureVisible(tester.element(tile(key)), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(tile(key));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text(value),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('隐私位于安全下，主页四档保存并在重进后恢复', (tester) async {
    final api = _Api(), user = _Identity();
    await open(tester, api, user);
    expect(
      tester.getTopLeft(find.text('隐私')).dy,
      greaterThan(tester.getTopLeft(find.text('安全')).dy),
    );
    expect(find.text('禁止私信'), findsOneWidget);
    expect(find.text('公开可见'), findsOneWidget);
    await choose(tester, 'profile-visibility-setting', '仅自己可见');
    expect(find.text('仅自己可见'), findsOneWidget);
    expect(api.profileWrites, [ProfileVisibility.private]);
    expect(api.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester, api, user);
    expect(find.text('仅自己可见'), findsOneWidget);
  });
  testWidgets('权限读取失败不冒充默认成功，原行可重试', (tester) async {
    final api = _Api()..failRead = true;
    await open(tester, api, _Identity());
    expect(find.text('暂不可用'), findsNWidgets(2));
    expect(find.text('禁止私信'), findsNothing);
    api.failRead = false;
    await tester.tap(tile('dm-policy-setting'));
    await tester.pumpAndSettle();
    expect(find.text('禁止私信'), findsOneWidget);
    expect(api.writes, isEmpty);
  });

  testWidgets('私信三档保存成功才更新，失败保留旧值', (tester) async {
    final api = _Api();
    await open(tester, api, _Identity());
    await choose(tester, 'dm-policy-setting', '我关注的');
    expect(api.value, DmPolicy.following);
    expect(find.text('我关注的'), findsOneWidget);
    api.fail = true;
    await choose(tester, 'dm-policy-setting', '相互关注的');
    expect(find.text('我关注的'), findsOneWidget);
    expect(find.text('私信权限保存失败，请重试'), findsOneWidget);
  });
  testWidgets('主页保存失败保留旧值，四项均可选', (tester) async {
    final api = _Api();
    await open(tester, api, _Identity());
    for (final policy in [
      ProfileVisibility.private,
      ProfileVisibility.followers,
      ProfileVisibility.mutual,
      ProfileVisibility.public,
    ]) {
      await choose(tester, 'profile-visibility-setting', policy.label);
      expect(api.visibility, policy);
    }
    api.fail = true;
    await choose(tester, 'profile-visibility-setting', '仅自己可见');
    expect(api.visibility, ProfileVisibility.public);
    expect(find.text('主页可见保存失败，请重试'), findsOneWidget);
  });
  testWidgets('旧身份保存迟到不覆盖新身份', (tester) async {
    final api = _Api()..pending = Completer<DmPolicy>();
    final user = _Identity(), revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    await open(tester, api, user, revision: revision);
    await choose(tester, 'dm-policy-setting', '我关注的');
    user.cid = 'CN583-CTZN2-100000002-2026';
    revision.value++;
    await tester.pumpAndSettle();
    api.pending!.complete(DmPolicy.following);
    await tester.pumpAndSettle();
    expect(find.text('禁止私信'), findsOneWidget);
    expect(find.text('我关注的'), findsNothing);
  });
  test('隐私API严格解析两项，部分提交不附带另一项', () async {
    final sessions = _Sessions(_Identity());
    final session = (await sessions.resolveSession()).session!;
    final requests = <http.Request>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'dm_policy': request.method == 'PUT' ? 'mutual' : 'none',
            'profile_visibility': request.method == 'PUT'
                ? (jsonDecode(request.body)['profile_visibility'] ?? 'public')
                : 'public',
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    expect((await api.fetchPrivacy(session)).dmPolicy, DmPolicy.none);
    expect(
      (await api.savePrivacy(session, dmPolicy: DmPolicy.mutual)).dmPolicy,
      DmPolicy.mutual,
    );
    expect(requests.map((r) => r.method), ['GET', 'PUT']);
    expect(requests.every((r) => r.url.path == '/api/user/privacy'), isTrue);
    expect(jsonDecode(requests.last.body), {'dm_policy': 'mutual'});
    await api.savePrivacy(
      session,
      profileVisibility: ProfileVisibility.private,
    );
    expect(jsonDecode(requests.last.body), {'profile_visibility': 'private'});
  });

  test('主页预检只请求准确access路径，缺失隐私字段不回退公开', () async {
    final session = (await _Sessions(_Identity()).resolveSession()).session!;
    final requests = <http.Request>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'is_ok': true}), 200);
      }),
    );
    addTearDown(api.close);
    await api.requireProfileAccess(session.cidNumber, session);
    expect(
      requests.single.url.path,
      '/api/user/profiles/${session.cidNumber}/access',
    );
    await expectLater(
      api.fetchPrivacy(session),
      throwsA(isA<SquareApiException>()),
    );
  });
}
