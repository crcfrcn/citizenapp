import 'dart:convert';

import 'package:citizen_user/square_api_client.dart';
import 'package:crypto/crypto.dart';
import 'package:chat/chat.dart' as chat;
import 'package:citizen_user/identity/mls_authentication.dart';
import 'package:citizen_network/square_request_signer.dart';

const testMlsDeviceId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const testMlsAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const testMlsCidNumber = 'CN220-CTZN2-100000001-2026';

/// 合成边界只供业务夹具；实际MLS密码学验签由聊天模块与服务测试拥有。
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
  Future<chat.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required chat.MlsAuthenticationRequest request,
  }) async {
    identity.validate();
    request.validate();
    await requireCurrent(identity);
    await beforeProof?.call();
    await requireCurrent(identity);
    proofCalls++;
    return _fakeProof(identity, request);
  }
}

chat.MlsAuthenticationProof _fakeProof(
  MlsAuthenticationIdentity identity,
  chat.MlsAuthenticationRequest request,
) => chat.MlsAuthenticationProof.fromJson({
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
  'token_purpose': request.tokenPurpose,
  if (request.sessionHash != null) 'session_hash': request.sessionHash!,
  'signature': '0x${List.filled(64, 'ab').join()}',
});

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
  final request = chat.MlsAuthenticationRequest(
    tokenPurpose: 'request',
    sessionHash: sha256.convert(utf8.encode(sessionToken)).toString(),
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
