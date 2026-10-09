import 'mls_authentication_fixture.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/security/identity_binding.dart';
import 'package:citizenapp/security/hex_codec.dart' show bytesToHex,hexToBytes;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/security/mls_authentication.dart';
import '../support/fake_citizen_sdk.dart';

const _accountId='0x625e25364c7b68e0a83065ccb40afed43f8fe933e669b24f3d69a57eddb3b715';
const _cidNumber='CN220-CTZN2-198805200-2026';
const _binding=IdentityBinding(genesisHash:'0x3333333333333333333333333333333333333333333333333333333333333333',
 cidNumber:_cidNumber,bindingRevision:1,accountId:_accountId);
const _nonce='1111111111111111111111111111111111111111111111111111111111111111';

// 独立夹具按公开合同构造SCALE字节，不调用产品私有payload方法。
Map<String,dynamic> challenge(String purpose) {
 final expiry=DateTime.now().millisecondsSinceEpoch+240000;
 final out=BytesBuilder();
 void string(String value){final raw=utf8.encode(value);out.addByte(raw.length<<2);out.add(raw);}
 void u64(int value){final d=ByteData(8)..setUint64(0,value,Endian.little);out.add(d.buffer.asUint8List());}
 string('citizenserve.account_deletion');string('https://square.test');
 out.add(hexToBytes(_binding.genesisHash));string(_cidNumber);out.add(hexToBytes(_accountId));
 u64(1);out.addByte(purpose=='delete'?0:1);out.add(hexToBytes(_nonce));u64(expiry);
 return {'ok':true,'purpose':purpose,'challenge_id':_nonce,'cid_number':_cidNumber,
 'account_id':_accountId,'binding_revision':1,'chain_scope':_binding.genesisHash,
 'service_origin':'https://square.test','expires_at_millis':expiry,
 'signing_payload_hex':'0x'+bytesToHex(out.takeBytes())};
}
Map<String,Object?> receipt(String state)=>{'ok':true,'cid_number':_cidNumber,
 'account_id':_accountId,'binding_revision':1,'deletion_id':state=='absent'?null:_nonce,'state':state};
http.Response json(Object value,[int status=200])=>http.Response(jsonEncode(value),status,headers:{'content-type':'application/json; charset=utf-8'});
SquareApiClient client(Future<http.Response> Function(http.Request) business)=>SquareApiClient(
 baseUrl:'https://square.test/api',httpClient:MockClient((request)async{
 if(request.url.path=='/api/user/challenges')return json(fakeMlsChallenge(request,cidNumber:_cidNumber));
 if(request.url.path=='/api/user/sessions')return json(fakeMlsSession(cidNumber:_cidNumber,accountId:_accountId,token:'sqs_test'));
 return business(request);
}));
Future<void> login(SquareApiClient api)=>api.ensureSession(accountId:_accountId,
 authentication:FakeMlsAuthentication(cidNumber:_cidNumber,accountId:_accountId)).then((_) {});

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late TestCitizenSdkTransport transport;late CitizenSdk sdk;
 setUp(()async{
 SquareApiClient.activateFinalizedBinding(cidNumber:_cidNumber,bindingRevision:1,accountId:_accountId);
 transport=TestCitizenSdkTransport({},useCore:true);sdk=await transport.open();
 });
 tearDown(()async{await sdk.close();await transport.dispose();});

 test('submit requires MLS, returns pending, then wallet-only status recovers completion',()async{
 final submitted=<String>[];final signed=<Uint8List>[];final payloads=<String>[];
 final api=client((request)async{
 submitted.add(request.url.path);
 if(request.url.path=='/api/user/deletion/challenges'){
 expect(request.headers['authorization'],'Bearer sqs_test');
 expect(request.headers['x-mls-proof'],isNotNull);expect(jsonDecode(request.body),{});
 final c=challenge('delete');payloads.add(c['signing_payload_hex'] as String);return json(c);
 }
 if(request.url.path=='/api/user/deletion'){
 expect(request.headers['x-mls-proof'],isNotNull);
 expect(jsonDecode(request.body),{'challenge_id':_nonce,'signature':'0xSIG'});
 return json(receipt('pending'),202);
 }
 if(request.url.path=='/api/user/deletion/status/challenges'){
 expect(request.headers['authorization'],isNull);expect(request.headers['x-mls-proof'],isNull);
 expect(jsonDecode(request.body),{'cid_number':_cidNumber,'account_id':_accountId});
 final c=challenge('status');payloads.add(c['signing_payload_hex'] as String);return json(c);
 }
 if(request.url.path=='/api/user/deletion/status'){
 expect(request.headers['authorization'],isNull);return json(receipt('complete'));
 }
 return http.Response('not found',404);
 });
 await login(api);
 Future<String> signer(Uint8List message)async{signed.add(message);return '0xSIG';}
 await expectLater(api.deleteAccount(binding:_binding,signAction:signer),
 throwsA(isA<SquareAccountDeletionPendingException>()));
 await api.deleteAccount(binding:_binding,signAction:signer);
 expect(submitted,['/api/user/deletion/challenges','/api/user/deletion',
 '/api/user/deletion/status/challenges','/api/user/deletion/status']);
 for(var i=0;i<signed.length;i++){
 final expected=await CitizenSigning.encodePayload(CitizenSigningPayload.message(opTag:kOpSignSquareAction,scalePayload:hexToBytes(payloads[i])));
 expect(bytesToHex(signed[i]),bytesToHex(expected));
 }
 expect(bytesToHex(signed[0]),isNot(bytesToHex(signed[1])));
 });

 test('a new client recovers pending without a session and never creates a deletion',()async{
 final paths=<String>[];
 final api=client((request)async{
 paths.add(request.url.path);
 if(request.url.path.endsWith('/challenges'))return json(challenge('status'));
 return json(receipt('pending'));
 });
 await expectLater(api.deleteAccount(binding:_binding,signAction:(_)async=>'0xSIG'),
 throwsA(isA<SquareAccountDeletionPendingException>()));
 expect(paths,['/api/user/deletion/status/challenges','/api/user/deletion/status']);
 });

 test('lost acceptance with a stale session switches only to read-only wallet recovery',()async{
 final paths=<String>[];
 final api=client((request)async{
 paths.add(request.url.path);
 if(request.url.path=='/api/user/deletion/challenges')return json({'error_code':'invalid_session'},401);
 if(request.url.path=='/api/user/deletion/status/challenges')return json(challenge('status'));
 return json(receipt('complete'));
 });
 await login(api);await api.deleteAccount(binding:_binding,signAction:(_)async=>'0xSIG');
 expect(paths,['/api/user/deletion/challenges','/api/user/deletion/status/challenges','/api/user/deletion/status']);
 });

 test('foreign binding, scope, purpose, expiry and opaque payload are rejected before signing',()async{
 final changes=<Map<String,Object?>>[
 {'cid_number':'OTHER-CID'},{'account_id':'0x'+List.filled(32,'22').join()},{'binding_revision':2},
 {'chain_scope':'0x'+List.filled(32,'44').join()},{'service_origin':'https://other.test'},{'purpose':'delete'},
 {'expires_at_millis':1},{'signing_payload_hex':'0x00'},{'op_tag':0x99},
 {'challenge_id':'../other'},
 ];
 for(final change in changes){
 var signed=false;
 final api=client((_)async=>json({...challenge('status'),...change}));
 await expectLater(api.deleteAccount(binding:_binding,signAction:(_)async{signed=true;return '0xSIG';}),
 throwsA(isA<SquareApiException>()));
 expect(signed,isFalse);
 }
 });

 test('binding changed during wallet signing prevents submitting the old intent',()async{
 var submits=0;
 final api=client((request)async{
 if(request.url.path.endsWith('/challenges'))return json(challenge('status'));
 submits++;return json(receipt('complete'));
 });
 await expectLater(api.deleteAccount(binding:_binding,signAction:(_)async{
 SquareApiClient.activateFinalizedBinding(cidNumber:_cidNumber,bindingRevision:2,accountId:_accountId);
 return '0xSIG';
 }),throwsA(isA<SquareApiException>()));
 expect(submits,0);
 });

 test('wrong completion receipt never permits local cleanup; absent is not complete',()async{
 for(final result in [receipt('complete')..['cid_number']='OTHER-CID',receipt('complete')..['deletion_id']='bad',receipt('absent')]){
 final api=client((request)async=>json(request.url.path.endsWith('/challenges')?challenge('status'):result));
 await expectLater(api.deleteAccount(binding:_binding,signAction:(_)async=>'0xSIG'),
 throwsA(isA<SquareApiException>()));
 }
 });
  test('finalized 换绑立即清除旧会话，并拒绝换绑后才返回的旧握手', () async {
    const newAccountId =
        '0x2222222222222222222222222222222222222222222222222222222222222222';
    SquareApiClient.activateFinalizedBinding(
      cidNumber: _cidNumber,
      bindingRevision: 1,
      accountId: _accountId,
    );
    final cachedClient = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/user/challenges') {
          return http.Response(
            jsonEncode(fakeMlsChallenge(request, cidNumber: _cidNumber)),
            200,
          );
        }
        return http.Response(
          jsonEncode(fakeMlsSession(cidNumber: _cidNumber, accountId: _accountId, token: 'cached-token')),
          200,
        );
      }),
    );
    await cachedClient.ensureSession(
      accountId: _accountId,
      authentication: FakeMlsAuthentication(cidNumber: _cidNumber, accountId: _accountId),
    );

    final sessionRequested = Completer<void>();
    final sessionResponse = Completer<http.Response>();
    final lateClient = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/user/challenges') {
          return http.Response(
            jsonEncode(fakeMlsChallenge(request, cidNumber: _cidNumber)),
            200,
          );
        }
        sessionRequested.complete();
        return sessionResponse.future;
      }),
    );
    final late = lateClient.ensureSession(
      accountId: _accountId,
      authentication: FakeMlsAuthentication(cidNumber: _cidNumber, accountId: _accountId),
    );
    final rejectedLate = expectLater(late, throwsA(isA<MlsAuthenticationException>()));
    await sessionRequested.future;

    SquareApiClient.activateFinalizedBinding(
      cidNumber: _cidNumber,
      bindingRevision: 2,
      accountId: newAccountId,
    );
    sessionResponse.complete(http.Response(
      jsonEncode(fakeMlsSession(cidNumber: _cidNumber, accountId: _accountId, token: 'late-token')),
      200,
    ));

    await expectLater(
      cachedClient.deleteAccount(
        binding: _binding,
        signAction: (_) async => '0xSIG',
      ),
      throwsA(isA<SquareApiException>()),
    );
    await rejectedLate;
  });
}
