import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/identity/registration_page.dart';
import 'package:citizen_user/identity/registration_api.dart';

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  test('默认页面只接受本次CF的UUID及token', () {
    final value = RegistrationPage.verificationFromMessage(
      jsonEncode({'check_id': id, 'token': 'ephemeral-token'}),
    );
    expect(value!.checkId, id);
    expect(value.token, 'ephemeral-token');
    expect(RegistrationApi.pageUri().hasQuery, false);
  });
  test('未知字段、伪造成功、无效ID和超限令牌不能放行', () {
    for (final value in [
      <String, Object>{'is_ok': true},
      {'check_id': 'invalid', 'token': 'x'},
      {'check_id': id, 'token': ''},
      {'check_id': id, 'token': 'x' * 2049},
      {'check_id': id, 'token': 'x', 'credential': 'x'},
    ]) {
      expect(
        RegistrationPage.verificationFromMessage(jsonEncode(value)),
        isNull,
      );
    }
  });
}
