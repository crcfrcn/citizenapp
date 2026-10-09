import 'dart:convert';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;
import 'package:citizenapp/security/mls_authentication.dart';
import 'package:citizenapp/8964/services/square_request_signer.dart';

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
    int bindingRevision = 1,
    String deviceId = testMlsDeviceId,
  }) : identity = MlsAuthenticationIdentity(
         cidNumber: cidNumber,
         accountId: accountId,
         bindingRevision: bindingRevision,
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
    return sdk.MlsAuthenticationProof(
      userId: identity.cidNumber,
      deviceId: identity.deviceId,
      publicKey: identity.publicKey,
      accountId: identity.accountId,
      bindingRevision: identity.bindingRevision,
      serviceOrigin: request.serviceOrigin,
      challenge: request.challenge,
      expiresAtMillis: request.expiresAtMillis,
      method: request.method,
      requestTarget: request.requestTarget,
      bodySha256: '0x${sha256.convert(request.bodyBytes)}',
      signature: '0x${List.filled(64, 'ab').join()}',
    );
  }
}

Map<String, Object> fakeMlsChallenge(
  http.Request request, {
  String cidNumber = testMlsCidNumber,
  int bindingRevision = 1,
}) {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  return {
    'ok': true,
    'user_id': cidNumber,
    'account_id': body['account_id'] as String,
    'binding_revision': bindingRevision,
    'public_key': body['public_key'] as String,
    'device_id': (body['public_key'] as String).substring(2),
    'service_origin': request.url.origin,
    'challenge': '0x${List.filled(32, 'cd').join()}',
    'expires_at_millis': DateTime.now().millisecondsSinceEpoch + 240000,
    'method': body['method'] as String,
    'request_target': body['request_target'] as String,
    'body_sha256': body['body_sha256'] as String,
  };
}

Map<String, Object> fakeMlsSession({
  String cidNumber = testMlsCidNumber,
  String accountId = testMlsAccountId,
  String deviceId = testMlsDeviceId,
  int bindingRevision = 1,
  String token = 'tok',
}) => {
  'ok': true,
  'session_token': token,
  'cid_number': cidNumber,
  'device_id': deviceId,
  'account_id': accountId,
  'binding_revision': bindingRevision,
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
    method: method,
    requestTarget: uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
    bodyBytes: body,
    challenge: '0x${List.filled(32, 'cd').join()}',
    expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 240000,
  );
  final identity = source.identity;
  final challenge =
      {
          ...fakeMlsSession(),
          'user_id': identity.cidNumber,
          'public_key': identity.publicKey,
          'service_origin': request.serviceOrigin,
          'challenge': request.challenge,
          'expires_at_millis': request.expiresAtMillis,
          'method': method,
          'request_target': request.requestTarget,
          'body_sha256': '0x${sha256.convert(body)}',
        }
        ..remove('session_token')
        ..remove('cid_number')
        ..remove('expires_at');
  return mlsProofHeaders(
    await source.createProof(
      identity: identity,
      request: request,
      challenge: challenge,
    ),
  );
}

SquareSession fakeSquareSession(
  String accountId, {
  String cidNumber = testMlsCidNumber,
}) => SquareSession(
  sessionToken: "tok",
  cidNumber: cidNumber,
  accountId: accountId,
  bindingRevision: 1,
  deviceId: testMlsDeviceId,
  expiresAt: 4102444800000,
  authenticateRequest: fakeMlsRequestHeaders,
);
