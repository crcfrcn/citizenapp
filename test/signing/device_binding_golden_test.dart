// MLS设备登记（0x1C）的SCALE与GMB跨语言固定向量。
// CID、版本、账户、规范0x MLS公钥和时间按CitizenServe同一合同编码。

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/security/hex_codec.dart';
import 'package:citizenapp/security/mls_device_binding.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import '../support/fake_citizen_sdk.dart';

const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _cidNumber = 'CN220-CTZN2-198805200-2026';
const _bindingRevision = 1;
final String _publicKey = '0x${'ab' * 32}';
const int _issuedAt = 1700000000000;
const _goldenHex =
    'ddf7ca6d82b5f2e364a710a72eb54159d401901cbea52b8cff3e1d8754ce605b';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestCitizenSdkTransport encodingTransport;
  late CitizenSdk encodingSdk;
  setUp(() async {
    encodingTransport = TestCitizenSdkTransport({}, useCore: true);
    encodingSdk = await encodingTransport.open();
  });
  tearDown(() async {
    await encodingSdk.close();
    await encodingTransport.dispose();
  });
  test(
    'buildMlsDeviceBindingSigningMessage matches Worker golden (0x1C)',
    () async {
      final message = await buildMlsDeviceBindingSigningMessage(
        _cidNumber,
        _bindingRevision,
        _accountId,
        _publicKey,
        _issuedAt,
      );
      expect(message.length, 32);
      expect(bytesToHex(message), _goldenHex);
    },
  );

  test('CitizenSDK Blake2Domain 输入与设备绑定逐字节共用 0x1C', () async {
    final payload = await encodeMlsDeviceBindingPayload(
      cidNumber: _cidNumber,
      bindingRevision: _bindingRevision,
      accountId: _accountId,
      publicKey: _publicKey,
      issuedAtMillis: _issuedAt,
    );
    final coldSigningMessage = (await CitizenSigning.encodePayload(
      CitizenSigningPayload.message(
        opTag: kOpSignMlsDeviceBind,
        scalePayload: payload,
      ),
    ));
    expect(bytesToHex(coldSigningMessage), _goldenHex);
  });
}
