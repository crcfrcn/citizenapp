import 'dart:convert';
import 'dart:typed_data';

import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;

/// 只接受实际请求结构，不能用普通登录能力签任意消息。
typedef MlsRequestAuthenticator = Future<Map<String, String>> Function({
  required String method,
  required Uri uri,
  required List<int> body,
  required String sessionToken,
});

Future<Map<String, String>> squareRequestHeaders({
  required String method,
  required Uri uri,
  required String body,
  required String sessionToken,
  required MlsRequestAuthenticator authenticate,
}) => squareRequestHeadersForBytes(
  method: method,
  uri: uri,
  body: Uint8List.fromList(utf8.encode(body)),
  sessionToken: sessionToken,
  authenticate: authenticate,
);

/// 正文不可变副本直接用于SDK摘要；查询和/api前缀原样保留。
Future<Map<String, String>> squareRequestHeadersForBytes({
  required String method,
  required Uri uri,
  required Uint8List body,
  required String sessionToken,
  required MlsRequestAuthenticator authenticate,
}) => authenticate(
  method: method,
  uri: uri,
  body: List<int>.unmodifiable(body),
  sessionToken: sessionToken,
);

Map<String, String> mlsProofHeaders(sdk.MlsAuthenticationProof proof) {
  final bytes = utf8.encode(jsonEncode(proof.toJson()));
  if (bytes.length > 16384) throw const FormatException('MLS证明超过16KiB');
  return {'x-mls-proof': base64UrlEncode(bytes).replaceAll('=', '')};
}
