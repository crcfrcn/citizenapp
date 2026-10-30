import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_account/identity/registration_api.dart';
import 'package:citizen_account/identity/registration_models.dart';

RegistrationContext registrationContext() => RegistrationContext(
  accountId: '0x${'11' * 32}',
  orgCode: 'CTZN',
  chainScope: '0x${'22' * 32}',
);
const regId = '11111111-1111-4111-8111-111111111111';
const checkId = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> registrationResponse(
  RegistrationContext c, {
  String jobState = 'prepared',
  bool initial = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'is_ok': true,
    'protocol_version': 1,
    'reg_id': regId,
    'reg_scope': c.regScope,
    'service_origin': c.serviceOrigin,
    'context_hash': '0x${c.contextHash}',
    'job_state': jobState,
    'created_at': now - 1000,
    'expires_at': now + 86400000,
    'human_at': jobState == 'human_verified' || jobState == 'activated'
        ? now
        : null,
    'activation': jobState == 'activated'
        ? {
            'cid_number': 'CN220-CTZN2-100000001-2026',
            'account_id': c.accountId,
            'bind_rev': 1,
            'device_id': '33' * 32,
            'public_key': '0x${'33' * 32}',
          }
        : null,
    'verification': jobState == 'prepared'
        ? {
            'check_id': checkId,
            'page_url':
                '${c.baseUrl}/user/registration/page?check_id=$checkId&page_token=capability',
            'page_expires_at': now + 60000,
            'action': 'cid_register',
            'hostname': Uri.parse(c.baseUrl).host,
          }
        : null,
    if (initial) 'recovery_token': 'protected-recovery-capability',
  };
}

void main() {
  test('与Serve原七字段金标一致，HTTP只接受原0x摘要且本地定位键保持', () {
    // 来源：Serve既有test/contract/registration.json的公开上下文与摘要。
    final c = RegistrationContext(
      accountId:
          '0x2afba9278e30ccf6a6ceb3a8b6e336b70068f045c666f2e7f4f9cc5f47db8972',
      orgCode: 'CTZN',
      chainScope: '0x${'00' * 32}',
      baseUrl: 'https://registration.example.test/api',
      regScope: 'citizenserve:fixture',
    );
    expect(
      '0x${c.contextHash}',
      '0x3f41f857b7cdc569ac12579659aab7a5f319b716624bc9a4fcdbb33cfacf7d2b',
    );
    expect(c.contextHash.length, 64);
    final response = registrationResponse(c, initial: true);
    expect(RegistrationResponse.parse(response, c, initial: true).regId, regId);
    final oldState = {...response}..['state'] = response['job_state'];
    expect(
      () => RegistrationResponse.parse(oldState, c, initial: true),
      throwsFormatException,
    );
    oldState.remove('job_state');
    expect(
      () => RegistrationResponse.parse(oldState, c, initial: true),
      throwsFormatException,
    );
    response['context_hash'] = c.contextHash;
    expect(
      () => RegistrationResponse.parse(response, c, initial: true),
      throwsFormatException,
    );
  });

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
              jobState: initial ? 'prepared' : 'human_verified',
              initial: initial,
            ),
          ),
          initial ? 201 : 200,
        );
      }),
    );
    addTearDown(api.close);
    final initial = await api.prepare(c);
    final cap = RegistrationCapabilities(
      initial.regId,
      initial.json['recovery_token'] as String,
    );
    await api.verify(
      c,
      cap,
      checkId: checkId,
      token: 'ephemeral-token-value-1234',
    );
    await api.status(c, cap);
    expect(jsonDecode(requests[0].body), {
      'protocol_version': 1,
      'chain_scope': c.chainScope,
      'account_id': c.accountId,
      'org_code': c.orgCode,
    });
    expect(jsonDecode(requests[1].body), {
      'protocol_version': 1,
      'reg_id': cap.regId,
      'recovery_token': cap.recoveryToken,
      'check_id': checkId,
      'turnstile_token': 'ephemeral-token-value-1234',
    });
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
      {'context_hash': '00' * 32},
      {'protocol_version': 2},
      {'cid_number': 'premature'},
      {'is_ok': false},
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
    final raw = registrationResponse(c, jobState: 'activated');
    raw['activation']['account_id'] = '0x${'44' * 32}';
    expect(() => RegistrationResponse.parse(raw, c), throwsFormatException);
    final api = RegistrationApi(
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    addTearDown(api.close);
    await expectLater(api.prepare(c), throwsA(isA<RegistrationException>()));
  });

  test('注册服务 HTTP 故障分类明确，且不透传服务端正文', () async {
    final c = registrationContext();
    for (final caseValue in <(int, String)>[
      (401, '重新进行真人验证'),
      (409, '注册状态冲突'),
      (429, '过于频繁'),
      (503, '注册验证服务故障'),
    ]) {
      final api = RegistrationApi(
        // 显式交付UTF-8字节及响应头，保留真实HTTP错误分类与正文隔离断言。
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('服务端私有登记能力不得展示'),
            caseValue.$1,
            headers: const {'content-type': 'text/plain; charset=utf-8'},
          ),
        ),
      );
      try {
        await api.prepare(c);
        fail('HTTP ${caseValue.$1} 必须失败关闭');
      } on RegistrationException catch (error) {
        expect(error.code, 'registration_http_${caseValue.$1}');
        expect(error.message, contains(caseValue.$2));
        expect(error.message, isNot(contains('私有登记能力')));
      } finally {
        api.close();
      }
    }
  });
}
