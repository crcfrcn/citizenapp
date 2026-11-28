// 验证隐私及首页设置。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:citizenapp/user.dart';
import 'package:citizen_user/api.dart' show DmPolicy, PrivacySettings, ProfileVisibility, SquareApiClient, SquareApiException, SquareSession;
import 'package:citizen_user/context.dart' show CurrentUser, CurrentUserContext;
import 'package:citizen_user/context.dart' show IdentityBinding;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider, SquareSessionResolution, SquareSessionStatus;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/security/storage.dart';
import 'package:citizen_testing/database.dart';
import 'package:citizen_testing/chat/authentication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_storage/user.dart';
import 'package:citizen_system/theme.dart';

void main() {
  group('privacy_setting_test', _registerPrivacy);
  group('user_home_tab_setting_test', _registerHome);
}

// 验证主页私信隐私保存、身份切换隔离及黑名单解除。

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
  int refreshes = 0;
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async {
    if (refresh) refreshes++;
    return SquareSessionResolution(
    SquareSessionStatus.ready,
    session: SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'synthetic-$refreshes',
      cidNumber: identity.cid,
      accountId: testMlsAccountId,
      bindRev: 1,
      expiresAt: 9999999999999,
      authenticateRequest: fakeMlsRequestHeaders,
    ),
  );
  }
}

class _Api extends SquareApiClient {
  DmPolicy value = DmPolicy.all;
  ProfileVisibility visibility = ProfileVisibility.public;
  final profileWrites = <ProfileVisibility>[];
  bool fail = false;
  bool failRead = false;
  Completer<PrivacySettings>? readPending;
  final writes = <DmPolicy>[];
  final blocked = <String>{};
  final blockWrites = <(String, bool)>[];
  final blockErrors = <Object>[];
  final blockSessions = <String>[];
  Completer<Set<String>>? blockPending;

  @override
  Future<Set<String>> blockedUsers(SquareSession session, {bool refresh = false}) async {
    blockSessions.add(session.sessionToken);
    if (blockErrors.isNotEmpty) throw blockErrors.removeAt(0);
    if (blockPending != null) return blockPending!.future;
    return Set<String>.unmodifiable(blocked);
  }

  @override
  Future<void> setBlocked(SquareSession session, String peer, bool value) async {
    blockWrites.add((peer, value));
    if (value) {
      blocked.add(peer);
    } else {
      blocked.remove(peer);
    }
  }

  Completer<DmPolicy>? pending;
  @override
  Future<PrivacySettings> fetchPrivacy(SquareSession session) async {
    if (failRead) throw StateError('测试读取失败');
    if (readPending != null) return readPending!.future;
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
    if (pending != null) await pending!.future;
    value = dmPolicy ?? value;
    visibility = profileVisibility ?? visibility;
    return PrivacySettings(dmPolicy: value, profileVisibility: visibility);
  }
}

void _registerPrivacy() {
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
    _Sessions? sessions,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (_) async {},
          privacyApi: api,
          privacyUserContext: user,
          privacySessionProvider: sessions ?? _Sessions(user),
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
    expect(find.text('允许私信'), findsOneWidget);
    expect(find.text('公开可见'), findsOneWidget);
    final home = tester.widget<Text>(
      find.byKey(const ValueKey('home-tab-setting-value'), skipOffstage: false),
    );
    for (final value in ['允许私信', '公开可见']) {
      expect(tester.widget<Text>(find.text(value)).style, home.style);
    }
    await choose(tester, 'profile-visibility-setting', '仅自己可见');
    expect(find.text('仅自己可见'), findsOneWidget);
    expect(api.profileWrites, [ProfileVisibility.private]);
    expect(api.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester, api, user);
    expect(find.text('仅自己可见'), findsOneWidget);
  });
  testWidgets('读取失败无提示，两项权限仍可直接选择', (tester) async {
    final api = _Api()..failRead = true;
    await open(tester, api, _Identity());
    expect(find.text('暂不可用'), findsNothing);
    expect(find.text('允许私信'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await choose(tester, 'dm-policy-setting', '禁止私信');
    await choose(tester, 'profile-visibility-setting', '仅自己可见');
    expect(find.text('禁止私信'), findsOneWidget);
    expect(find.text('仅自己可见'), findsOneWidget);
    expect(api.writes, [DmPolicy.none]);
    expect(api.profileWrites, [ProfileVisibility.private]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('私信四档始终可选，保存失败无提示且保留选择', (tester) async {
    final api = _Api();
    await open(tester, api, _Identity());
    await choose(tester, 'dm-policy-setting', '我关注的');
    expect(api.value, DmPolicy.following);
    expect(find.text('我关注的'), findsOneWidget);
    await choose(tester, 'dm-policy-setting', '禁止私信');
    expect(api.value, DmPolicy.none);
    await choose(tester, 'dm-policy-setting', '我关注的');
    api.fail = true;
    await choose(tester, 'dm-policy-setting', '相互关注的');
    expect(find.text('相互关注的'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
  testWidgets('主页四项始终可选，保存失败无提示且保留选择', (tester) async {
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
    expect(find.text('仅自己可见'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
  testWidgets('读取未完成也能选择，迟到读取不覆盖选择', (tester) async {
    final api = _Api()..readPending = Completer<PrivacySettings>();
    await open(tester, api, _Identity());
    await choose(tester, 'dm-policy-setting', '禁止私信');
    await choose(tester, 'profile-visibility-setting', '仅自己可见');
    api.readPending!.complete(const PrivacySettings(
      dmPolicy: DmPolicy.all, profileVisibility: ProfileVisibility.public,
    ));
    await tester.pumpAndSettle();
    expect(find.text('禁止私信'), findsOneWidget);
    expect(find.text('仅自己可见'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('保存未完成仍可连续选择，两项写入依次完成', (tester) async {
    final api = _Api()..pending = Completer<DmPolicy>();
    await open(tester, api, _Identity());
    await choose(tester, 'dm-policy-setting', '我关注的');
    await choose(tester, 'profile-visibility-setting', '仅自己可见');
    await choose(tester, 'dm-policy-setting', '禁止私信');
    expect(find.text('禁止私信'), findsOneWidget);
    expect(find.text('仅自己可见'), findsOneWidget);
    expect(api.writes, [DmPolicy.following]);
    api.pending!.complete(DmPolicy.following);
    await tester.pumpAndSettle();
    expect(api.writes, [DmPolicy.following, DmPolicy.none]);
    expect(api.profileWrites, [ProfileVisibility.private]);
    expect(api.value, DmPolicy.none);
    expect(api.visibility, ProfileVisibility.private);
    expect(find.byType(SnackBar), findsNothing);
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
    expect(find.text('允许私信'), findsOneWidget);
    expect(find.text('我关注的'), findsNothing);
  });
  testWidgets('黑名单左滑解除后只更新原名单', (tester) async {
    const peer = 'CN583-CTZN2-100000002-2026';
    final api = _Api()..blocked.add(peer);
    await open(tester, api, _Identity());
    final entry = tile('blocked-users-setting');
    await Scrollable.ensureVisible(tester.element(entry));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(entry).dy,
        lessThan(tester.getTopLeft(tile('dm-policy-setting')).dy));
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey(peer)), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '解除拉黑'));
    await tester.pumpAndSettle();
    expect(api.blockWrites, [(peer, false)]);
    expect(find.text(peer), findsNothing);
    expect(find.text('黑名单为空'), findsOneWidget);
  });

  testWidgets('黑名单503保留失败，用户重试恢复且不刷新会话', (tester) async {
    final identity = _Identity(), api = _Api()
      ..blockErrors.add(const SquareApiException('fixture', statusCode: 503));
    final sessions = _Sessions(identity);
    await open(tester, api, identity, sessions: sessions);
    await Scrollable.ensureVisible(tester.element(tile('blocked-users-setting')));
    await tester.tap(tile('blocked-users-setting'));
    await tester.pumpAndSettle();
    expect(find.text('读取失败，重试'), findsOneWidget);
    expect(find.text('黑名单为空'), findsNothing);
    expect(sessions.refreshes, 0);
    expect(api.blockSessions, ['synthetic-0']);
    await tester.tap(find.text('读取失败，重试'));
    await tester.pumpAndSettle();
    expect(find.text('黑名单为空'), findsOneWidget);
    expect(sessions.refreshes, 0);
    expect(api.blockSessions, ['synthetic-0', 'synthetic-0']);
  });
  for (final repeat in [false, true]) {
    testWidgets('黑名单401最多刷新一次，重复拒绝=$repeat', (tester) async {
      final identity = _Identity(), api = _Api();
      api.blockErrors.add(const SquareApiException('fixture', statusCode: 401));
      if (repeat) api.blockErrors.add(const SquareApiException('fixture', statusCode: 401));
      final sessions = _Sessions(identity);
      await open(tester, api, identity, sessions: sessions);
      await Scrollable.ensureVisible(tester.element(tile('blocked-users-setting')));
      await tester.tap(tile('blocked-users-setting'));
      await tester.pumpAndSettle();
      expect(sessions.refreshes, 1);
      expect(api.blockSessions, ['synthetic-0', 'synthetic-1']);
      expect(find.text(repeat ? '读取失败，重试' : '黑名单为空'), findsOneWidget);
    });
  }
  testWidgets('黑名单身份切换后丢弃在途旧名单', (tester) async {
    final identity = _Identity(), api = _Api()..blockPending = Completer<Set<String>>();
    final revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    await open(tester, api, identity, revision: revision);
    await Scrollable.ensureVisible(tester.element(tile('blocked-users-setting')));
    await tester.tap(tile('blocked-users-setting'));
    await tester.pump();
    revision.value++;
    api.blockPending!.complete({'CN583-CTZN2-100000002-2026'});
    await tester.pumpAndSettle();
    expect(find.text('身份已切换，请返回'), findsOneWidget);
    expect(find.text('CN583-CTZN2-100000002-2026'), findsNothing);
  });
  test('黑名单完整翻页后合并，损坏回执失败而非空名单', () async {
    final session = (await _Sessions(_Identity()).resolveSession()).session!;
    const first = 'CN100-CTZN2-100000001-2026', last = 'CN200-CTZN2-100000002-2026';
    final cursors = <String?>[];
    var invalid = false;
    final api = SquareApiClient(baseUrl: 'https://square.test/api', httpClient: MockClient((request) async {
      cursors.add(request.url.queryParameters['cursor']);
      return http.Response(jsonEncode(invalid ? {'is_ok':true,'items':null} : {
        'is_ok':true, 'items':[cursors.length == 1 ? first : last],
        'next_cursor':cursors.length == 1 ? first : null,
      }), 200);
    }));
    addTearDown(api.close);
    expect(await api.blockedUsers(session, refresh: true), {first, last});
    expect(cursors, [null, first]);
    invalid = true;
    await expectLater(api.blockedUsers(session, refresh: true), throwsA(isA<SquareApiException>()));
    expect(api.isBlocked(session.cidNumber, first), isTrue);
  });
  test('名单读一次，拉黑与解除只提交空正文并更新本机名单', () async {
    const peer = 'CN583-CTZN2-100000002-2026';
    final resolver = _Sessions(_Identity());
    final session = (await resolver.resolveSession()).session!;
    final calls = <String>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        calls.add(request.method);
        expect(request.body, isEmpty);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({
            'is_ok': true, 'items': [], 'next_cursor': null,
          }), 200);
        }
        expect(request.url.path, '/api/8964/blocks/$peer');
        return http.Response(jsonEncode({
          'is_ok': true, 'blocked': request.method == 'PUT',
        }), 200);
      }),
    );
    addTearDown(api.close);
    expect(await api.blockedUsers(session), isEmpty);
    await api.setBlocked(session, peer, true);
    expect(api.isBlocked(session.cidNumber, peer), isTrue);
    expect(await api.blockedUsers(session), {peer});
    await api.setBlocked(session, peer, false);
    expect(api.isBlocked(session.cidNumber, peer), isFalse);
    expect(calls, ['GET', 'PUT', 'DELETE']);
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

// 验证首页偏好持久化、同款布局及保存失败保留原状态。

void _registerHome() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  late Directory records;
  setUp(() async {
    final temporary = await Directory.systemTemp.createTemp(
      'home_setting_records_',
    );
    records = Directory(await temporary.resolveSymbolicLinks());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemProtectedStorage.channel, (call) async {
          if (call.method == 'prepareRecords') return records.path;
          if (call.method == 'compareRecords') {
            final args = (call.arguments as Map).cast<String, dynamic>();
            final file = File('${records.path}/${args['name'] as String}');
            final current = await file.exists()
                ? await file.readAsString()
                : null;
            if (current != args['expected']) return false;
            await file.writeAsString(args['next'] as String, flush: true);
            return true;
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemProtectedStorage.channel, null);
    await records.delete(recursive: true);
  });

  Future<void> pumpUntilSettingVisible(WidgetTester tester) async {
    for (
      var i = 0;
      i < 40 &&
          !tester.any(find.byKey(const ValueKey('home-tab-setting-switch')));
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.ensureVisible(
      find.byKey(const ValueKey('home-tab-setting-tile')),
    );
    await tester.pumpAndSettle();
  }

  test('UserIsar 首页偏好缺省为广场并可原子往返', () async {
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isFalse);
    await UserIsar.instance.writeOpenChatOnLaunch(true);
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isTrue);
    await UserIsar.instance.writeOpenChatOnLaunch(false);
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isFalse);
  });

  testWidgets('首页设置位于安全和关于之间并同行显示广场与同款 Switch', (tester) async {
    // 新增隐私分组后使用足够长的视口，继续同时核对三个分组的实际几何顺序。
    tester.view.physicalSize = const Size(411, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (_) async {},
        ),
      ),
    );
    await pumpUntilSettingVisible(tester);

    final homeSetting = find.text('首页设置');
    final tileFinder = find.byKey(const ValueKey('home-tab-setting-tile'));
    final switchFinder = find.byKey(const ValueKey('home-tab-setting-switch'));
    expect(homeSetting, findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-tab-setting-value')),
      findsOneWidget,
    );
    expect(find.text('广场'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(
      tester.getCenter(homeSetting).dy,
      closeTo(tester.getCenter(switchFinder).dy, 1),
    );
    expect(
      tester.getTopLeft(homeSetting).dy,
      greaterThan(tester.getTopLeft(find.text('安全')).dy),
    );
    expect(
      tester.getTopLeft(homeSetting).dy,
      lessThan(tester.getTopLeft(find.text('关于')).dy),
    );
    // 首页设置与“我的”主页的“设置”入口共享唯一行高令牌，任何屏幕倍率都不得分叉。
    final tileContext = tester.element(tileFinder);
    expect(
      tester.getSize(tileFinder).height,
      closeTo(AppLayout.serviceEntryHeight(tileContext), 0.01),
    );
  });

  testWidgets('打开后保存 true 并立即同行显示聊天', (tester) async {
    bool? savedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (value) async => savedValue = value,
        ),
      ),
    );
    await pumpUntilSettingVisible(tester);

    await tester.tap(find.byKey(const ValueKey('home-tab-setting-switch')));
    await tester.pumpAndSettle();

    expect(find.text('聊天'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('home-tab-setting-switch')))
          .value,
      isTrue,
    );
    expect(savedValue, isTrue);
  });

  testWidgets('保存失败保持广场和关闭状态并给出重试提示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          homeTabPreferenceReader: () async => false,
          homeTabPreferenceWriter: (_) async => throw StateError('write fail'),
        ),
      ),
    );
    await pumpUntilSettingVisible(tester);

    await tester.tap(find.byKey(const ValueKey('home-tab-setting-switch')));
    await tester.pumpAndSettle();

    expect(find.text('广场'), findsOneWidget);
    expect(find.text('首页设置保存失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('home-tab-setting-switch')))
          .value,
      isFalse,
    );
  });
}
