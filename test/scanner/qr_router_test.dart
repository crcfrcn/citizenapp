import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/scanner/qr_router.dart';

/// App路由只处理SDK事实；原严格协议/坏码回归已移入SDK codec.rs直接验证真实解析器。
void main() {
  final router = QrRouter();
  final accepted = <CitizenQrKind, QrRouteType>{
    CitizenQrKind.userContact: QrRouteType.userContact,
    CitizenQrKind.userTransfer: QrRouteType.userTransfer,
  };
  for (final kind in CitizenQrKind.values) {
    final expected = accepted[kind] ?? QrRouteType.unknown;
    test('SDK码型$kind只进入允许的页面路由$expected', () {
      final document = CitizenQrDocument(
        kind: kind,
        canonicalText: 'sdk-canonical',
        scanPurposeMask: 0,
      );
      final result = router.route(raw: 'source-text', document: document);
      expect(result.type, expected);
      expect(result.raw, 'source-text');
      expect(
        result.document,
        expected == QrRouteType.unknown ? null : same(document),
      );
    });
  }

  test('SDK没有给出有效文档时，任何原文都不触发App第二解析器', () {
    for (final raw in [
      '',
      'hello world',
      'gmb://account/removed',
      '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY',
      '{"p":"QR_V1","k":3,"b":{"c":"CID","n":"untrusted"}}',
    ]) {
      final result = router.route(raw: raw);
      expect(result.type, QrRouteType.unknown);
      expect(result.document, isNull);
    }
  });
}
