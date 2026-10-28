import 'dart:convert';

import 'package:citizenapp/network/square_api_client.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;
import 'package:citizenapp/account/identity/mls_authentication.dart';
import 'package:citizenapp/network/square_request_signer.dart';

const testMlsDeviceId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const testMlsAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const testMlsCidNumber = 'CN220-CTZN2-100000001-2026';

/// 合成边界只供业务夹具；实际MLS密码学验签由SDK与服务测试拥有。
class FakeMlsAuthentication implements MlsAuthenticationSource {
  FakeMlsAuthentication({
    String cidNumber = testMlsCidNumber,
    String accountId = testMlsAccountId,
    int bindRev = 1,
    String deviceId = testMlsDeviceId,
  }) : identity = MlsAuthenticationIdentity(
         cidNumber: cidNumber,
         accountId: accountId,
         bindRev: bindRev,
         deviceId: deviceId,
         publicKey: '0x$deviceId',
       );

  MlsAuthenticationIdentity identity;
  int proofCalls = 0;
  int identityCalls = 0;
  bool closed = false;
  Future<void> Function()? beforeProof;

  @override
  Future<MlsAuthenticationIdentity> readIdentity() async {
    identityCalls++;
    await requireCurrent(identity);
    return identity;
  }

  @override
  Future<void> requireCurrent(MlsAuthenticationIdentity expected) async {
    if (closed || expected.cacheKey != identity.cacheKey) {
      throw const MlsAuthenticationException(
        '合成MLS身份已失效',
        code: 'identityChanged',
      );
    }
    identity.validate();
  }

  @override
  Future<sdk.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required sdk.MlsAuthenticationRequest request,
    required Map<String, dynamic> challenge,
  }) async {
    validateMlsChallenge(identity, request, challenge);
    await requireCurrent(identity);
    await beforeProof?.call();
    await requireCurrent(identity);
    proofCalls++;
    return _fakeProof(identity, request);
  }
}

sdk.MlsAuthenticationProof _fakeProof(
  MlsAuthenticationIdentity identity,
  sdk.MlsAuthenticationRequest request,
) => sdk.MlsAuthenticationProof.fromJson({
  'user_id': identity.cidNumber,
  'device_id': identity.deviceId,
  'public_key': identity.publicKey,
  'account_id': identity.accountId,
  'bind_rev': identity.bindRev,
  'service_origin': request.serviceOrigin,
  'nonce_id': request.nonceId,
  'expires_at': request.expiresAt,
  'http_method': request.httpMethod,
  'request_target': request.requestTarget,
  'body_hash': '0x${sha256.convert(request.bodyBytes)}',
  'signature': '0x${List.filled(64, 'ab').join()}',
});

Map<String, Object> fakeMlsChallenge(
  http.Request request, {
  String cidNumber = testMlsCidNumber,
  int bindRev = 1,
}) {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  return {
    'is_ok': true,
    'cid_number': cidNumber,
    'account_id': body['account_id'] as String,
    'bind_rev': bindRev,
    'public_key': body['public_key'] as String,
    'device_id': (body['public_key'] as String).substring(2),
    'service_origin': request.url.origin,
    'nonce_id': '0x${List.filled(32, 'cd').join()}',
    'expires_at': DateTime.now().millisecondsSinceEpoch + 240000,
    'http_method': body['http_method'] as String,
    'request_target': body['request_target'] as String,
    'body_hash': body['body_hash'] as String,
  };
}

Map<String, Object> fakeMlsSession({
  String cidNumber = testMlsCidNumber,
  String accountId = testMlsAccountId,
  String deviceId = testMlsDeviceId,
  int bindRev = 1,
  String token = 'tok',
}) => {
  'is_ok': true,
  'session_token': token,
  'cid_number': cidNumber,
  'device_id': deviceId,
  'account_id': accountId,
  'bind_rev': bindRev,
  'expires_at': 4102444800000,
};

/// 业务测试已直接注入会话时，仅合成规范公开证明；不模拟服务端验签成功。
Future<Map<String, String>> fakeMlsRequestHeaders({
  required String method,
  required Uri uri,
  required List<int> body,
  required String sessionToken,
}) async {
  final source = FakeMlsAuthentication();
  final request = sdk.MlsAuthenticationRequest(
    serviceOrigin: uri.origin,
    httpMethod: method,
    requestTarget: uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
    bodyBytes: body,
    nonceId: '0x${List.filled(32, 'cd').join()}',
    expiresAt: DateTime.now().millisecondsSinceEpoch + 240000,
  );
  final identity = source.identity;
  identity.validate();
  request.validate();
  return mlsProofHeaders(_fakeProof(identity, request));
}

SquareSession fakeSquareSession(
  String accountId, {
  String cidNumber = testMlsCidNumber,
}) => SquareSession(
  sessionToken: "tok",
  cidNumber: cidNumber,
  accountId: accountId,
  bindRev: 1,
  deviceId: testMlsDeviceId,
  expiresAt: 4102444800000,
  authenticateRequest: fakeMlsRequestHeaders,
);
