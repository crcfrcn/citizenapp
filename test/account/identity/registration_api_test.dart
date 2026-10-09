import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/account/identity/registration_api.dart';
import 'package:citizenapp/account/identity/registration_models.dart';

RegistrationContext registrationContext() => RegistrationContext(
  accountId: '0x${'11' * 32}',
  institution: 'CTZN',
  chainScope: '0x${'22' * 32}',
);
const enrollment = '11111111-1111-4111-8111-111111111111';
const verificationId = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> registrationResponse(
  RegistrationContext c, {
  String state = 'prepared',
  bool initial = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'ok': true,
    'protocol_version': 1,
    'enrollment_id': enrollment,
    'registration_scope': c.registrationScope,
    'service_origin': c.origin,
    'registration_context_hash': c.hash,
    'state': state,
    'created_at_millis': now - 1000,
    'expires_at_millis': now + 86400000,
    'human_verified_at_millis':
        state == 'human_verified' || state == 'activated' ? now : null,
    'activation': state == 'activated'
        ? {
            'cid_number': 'CN220-CTZN2-100000001-2026',
            'account_id': c.accountId,
            'binding_revision': 1,
            'device_id': '33' * 32,
            'public_key': '0x${'33' * 32}',
          }
        : null,
    'verification': state == 'prepared'
        ? {
            'verification_id': verificationId,
            'page_url':
                '${c.baseUrl}/user/registration/page?verification_id=$verificationId&page_token=capability',
            'page_expires_at_millis': now + 60000,
            'action': 'cid_register',
            'hostname': Uri.parse(c.baseUrl).host,
          }
        : null,
    if (initial) 'recovery_token': 'protected-recovery-capability',
  };
}

void main() {
  test('prepare只有四字段；验证和status秘密只放正文', () async {
    final c = registrationContext(), requests = <http.Request>[];
    final api = RegistrationApi(
      client: MockClient((request) async {
        requests.add(request);
        final initial = request.url.path == '/api/user/registration';
        return http.Response(
          jsonEncode(
            registrationResponse(
              c,
              state: initial ? 'prepared' : 'human_verified',
              initial: initial,
            ),
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final initial = await api.prepare(c);
    final cap = RegistrationCapabilities(
      initial.enrollmentId,
      initial.json['recovery_token'] as String,
    );
    await api.verify(
      c,
      cap,
      verificationId: verificationId,
      token: 'ephemeral-token-value-1234',
    );
    await api.status(c, cap);
    expect(jsonDecode(requests[0].body), c.toJson());
    expect(requests.map((r) => r.url.path), [
      '/api/user/registration',
      '/api/user/registration/verify',
      '/api/user/registration/status',
    ]);
    for (final r in requests) {
      expect(r.url.hasQuery, false);
      expect(r.url.toString(), isNot(contains(cap.recoveryToken)));
    }
    expect(
      jsonDecode(requests[1].body)['turnstile_token'],
      'ephemeral-token-value-1234',
    );
  });
  test('跨上下文、未知字段、缺字段和恶意页面失败关闭', () {
    final c = registrationContext();
    final raw = registrationResponse(c, initial: true);
    for (final change in [
      {'service_origin': 'https://attacker.test'},
      {'registration_context_hash': '00' * 32},
      {'protocol_version': 2},
      {'cid_number': 'premature'},
      {'ok': false},
    ]) {
      expect(
        () => RegistrationResponse.parse({...raw, ...change}, c, initial: true),
        throwsFormatException,
      );
    }
    final missing = {...raw}..remove('activation');
    expect(
      () => RegistrationResponse.parse(missing, c, initial: true),
      throwsFormatException,
    );
    final page = {
      ...(raw['verification'] as Map<String, dynamic>),
      'page_url': 'https://attacker.test/api/user/registration/page',
    };
    expect(
      () => RegistrationResponse.parse(
        {...raw, 'verification': page},
        c,
        initial: true,
      ),
      throwsFormatException,
    );
  });
  test('activated必须带准确账户和设备回执；HTTP失败不降级prepared', () async {
    final c = registrationContext();
    final raw = registrationResponse(c, state: 'activated');
    raw['activation']['account_id'] = '0x${'44' * 32}';
    expect(() => RegistrationResponse.parse(raw, c), throwsFormatException);
    final api = RegistrationApi(
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    addTearDown(api.close);
    await expectLater(api.prepare(c), throwsA(isA<RegistrationException>()));
  });
}
