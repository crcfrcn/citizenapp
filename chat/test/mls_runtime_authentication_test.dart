import 'dart:convert';
import 'dart:io';

import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:chat/chat.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/chat.dart' as chat;

class _Security implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected wallet operation');
}

class _Current implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: testMlsAccountId,
      ss58Address: 'synthetic-public-address',
      name: 'A',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
    binding: const IdentityBinding(
      genesisHash:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
      accountId: testMlsAccountId,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected current user operation');
}

class _Transport implements chat.ChatServiceTransport {
  _Transport(this.accessProvider);
  final chat.ChatAccessProvider accessProvider;
  chat.ChatAccess? access;
  final published = <chat.MlsKeyPackage>[];
  @override
  String? lastRealtimeDiagnosticCode;
  @override
  Future<void> connect() async {
    access = await accessProvider();
  }

  @override
  Future<void> registerPushEndpoint({
    required String pushProvider,
    required String pushToken,
    required String? apnsEnvironment,
    required int expiresAtMillis,
  }) async {}
  @override
  Future<void> publishKeyPackage(chat.MlsKeyPackage keyPackage) async {
    published.add(keyPackage);
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected chat transport operation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('公民宿主聊天初始化完整经过同一聊天运行时的MLS身份、挑战签名及许可认证', () async {
    SharedPreferences.setMockInitialValues({});
    final temporary = await Directory.systemTemp.createTemp(
      'citizen-chat-auth-',
    );
    final root = Directory(await temporary.resolveSymbolicLinks());
    final state = await Directory('${root.path}/mls').create();
    final security = _Security();
    final current = _Current();
    final paths = <String>[];
    final devices = <String>{};
    final client = SquareApiClient(
      baseUrl: 'https://service.test/api',
      httpClient: MockClient((request) async {
        final proof =
            (jsonDecode(
                      utf8.decode(
                        base64Url.decode(
                          base64Url.normalize(request.headers['x-mls-proof']!),
                        ),
                      ),
                    )
                    as Map)
                .cast<String, dynamic>();
        expect(proof['user_id'], testMlsCidNumber);
        expect(proof['account_id'], testMlsAccountId);
        expect(proof['request_target'], request.url.path);
        expect(proof['body_hash'], '0x${sha256.convert(request.bodyBytes)}');
        expect(proof['public_key'], '0x${proof['device_id']}');
        devices.add(proof['device_id'] as String);
        paths.add(request.url.path);
        final now = DateTime.now().millisecondsSinceEpoch;
        final response = switch (request.url.path) {
          '/api/user/sessions' => fakeMlsSession(
            deviceId: proof['device_id'] as String,
          ),
          '/api/chat/access' => <String, Object>{
            'is_ok': true,
            'realtime_url': 'wss://service.test/api/chat/realtime',
            'access_token': 'synthetic-chat-token',
            'expires_at': now + 300000,
            'recheck_at': now + 120000,
          },
          _ => throw StateError('unexpected HTTP request'),
        };
        return http.Response(jsonEncode(response), 200);
      }),
    );
    final sessions = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: current,
      client: client,
    );
    late _Transport transport;
    var transportCreates = 0;
    final runtime = ChatRuntime(
      accountSecurity: security,
      currentUserContext: current,
      squareSessionProvider: sessions,
      documentsDirectoryProvider: () async => root,
      stateStoreFactory: (user) async =>
          chat.MlsStateStore(state, ownerUserId: user),
      pushTokenProvider: () async => const AppPushToken(
        provider: 'fcm',
        token: 'synthetic-push-token',
        apnsEnvironment: null,
      ),
      transportFactory: ({required identity, required accessProvider}) {
        transportCreates++;
        return transport = _Transport(accessProvider);
      },
      onClosing: sessions.closeAuthentication,
    );
    sessions.installMlsAuthentication(
      readLocalIdentity: () => (() => runtime)().readLocalMlsIdentity(),
      createProof: (request) =>
          (() => runtime)().createMlsAuthenticationProof(request),
    );
    addTearDown(() async {
      await runtime.stop();
      client.close();
      security.revision.dispose();
      await root.delete(recursive: true);
    });
    await Future.wait([
      runtime.ensureReady(testMlsAccountId),
      runtime.ensureReady(testMlsAccountId),
    ]);
    expect(transportCreates, 1);
    final identity = await runtime.readLocalMlsIdentity();
    expect(devices, {identity.deviceId});
    expect(transport.published.single.deviceId, identity.deviceId);
    expect(transport.access!.accessToken, 'synthetic-chat-token');
    expect(paths, ['/api/user/sessions', '/api/chat/access']);
    expect(
      await chat.MlsStateStore(
        state,
        ownerUserId: testMlsCidNumber,
      ).pendingResults(null),
      isEmpty,
    );
  });
}
