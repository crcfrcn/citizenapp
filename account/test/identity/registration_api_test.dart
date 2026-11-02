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
RegistrationVerification verification() => RegistrationVerification(
  checkId: '11111111-1111-4111-8111-111111111111',
  token: 'ephemeral-cloudflare-token',
);
void main() {
  test('默认Siteverify仅两字段，成功只接受is_ok，无任务或后续令牌', () async {
    final requests = <http.Request>[];
    final api = RegistrationApi(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"is_ok":true}', 200);
      }),
    );
    addTearDown(api.close);
    await api.verify(registrationContext(), verification());
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/user/registration/verify');
    expect(requests.single.url.hasQuery, false);
    expect(jsonDecode(requests.single.body), {
      'check_id': verification().checkId,
      'turnstile_token': verification().token,
    });
  });
  test('未通过、错误成功正文、附加字段和超限均不能放行', () async {
    for (final body in [
      '{"is_ok":false}',
      '{"is_ok":true,"credential":"x"}',
      '{}',
      'x' * 4097,
    ]) {
      final api = RegistrationApi(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(api.close);
      await expectLater(
        api.verify(registrationContext(), verification()),
        throwsA(isA<Exception>()),
      );
    }
  });
  test('403和服务故障明确失败且不透传原始响应', () async {
    for (final status in [400, 403, 429, 503]) {
      final api = RegistrationApi(
        client: MockClient(
          (_) async => http.Response('private-cloudflare-details', status),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.verify(registrationContext(), verification()),
        throwsA(
          isA<RegistrationException>()
              .having((e) => e.code, '固定代码', 'registration_http_$status')
              .having(
                (e) => e.message,
                '正文隔离',
                isNot(contains('private-cloudflare-details')),
              ),
        ),
      );
    }
  });
  test('CF结果限制UUID和令牌，页面URL无能力查询', () {
    expect(
      () => RegistrationVerification(checkId: 'invalid', token: 'x'),
      throwsFormatException,
    );
    expect(
      () =>
          RegistrationVerification(checkId: verification().checkId, token: ''),
      throwsFormatException,
    );
    expect(RegistrationApi.pageUri().path, '/api/user/registration/page');
    expect(RegistrationApi.pageUri().hasQuery, false);
  });
}
