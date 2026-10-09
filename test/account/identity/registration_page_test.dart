import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/account/identity/registration_page.dart';

void main() {
  final verification = RegistrationVerification(
    'id',
    Uri.parse('https://www.crcfrcn.com/api/user/registration/page'),
    10000,
  );
  test('只接收本次JSON verification_id/token；纯token、过期、未知字段拒绝', () {
    final valid = {'verification_id': 'id', 'token': 'a' * 32};
    expect(
      RegistrationPage.tokenFromMessage(
        jsonEncode(valid),
        verification,
        now: 9999,
      ),
      'a' * 32,
    );
    // token为提供方不透明正文；App不凭长度下限判断真人，通过事实仅来自服务器。
    expect(
      RegistrationPage.tokenFromMessage(
        jsonEncode({...valid, 'token': 'short'}),
        verification,
        now: 9999,
      ),
      'short',
    );
    for (final raw in [
      'a' * 32,
      jsonEncode({...valid, 'verification_id': 'other'}),
      jsonEncode({...valid, 'extra': true}),
      jsonEncode({...valid, 'token': ''}),
      jsonEncode({...valid, 'token': ' ${'a' * 32}'}),
    ]) {
      expect(
        RegistrationPage.tokenFromMessage(raw, verification, now: 9999),
        isNull,
      );
    }
    expect(
      RegistrationPage.tokenFromMessage(
        jsonEncode(valid),
        verification,
        now: 10000,
      ),
      isNull,
    );
  });
}
