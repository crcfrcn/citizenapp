import 'package:citizen_account/contacts/contact_scan.dart';
import 'package:citizen_system/security/account_security_exception.dart';
import 'package:citizen_storage/user_isar.dart'
    as user_store
    show
        Contact,
        ContactSchema,
        EditSchema,
        FollowSchema,
        IdentitySchema,
        ProfileMediaSchema,
        NoticeSchema,
        ProfileSchema,
        Setting,
        SettingSchema;
import 'package:citizen_storage/app_isar.dart' as app_store show Entity;
import 'package:citizen_citizen/account_derivation.dart';
import 'package:flutter/foundation.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/profile/citizen_profile.dart';
import 'package:citizen_citizen/public/isar_public_institution_store.dart';
import 'package:citizen_citizen/public/public_institution_dto.dart';
import 'package:citizen_storage/app_isar.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_storage/isar_core_bootstrap.dart';
import 'package:citizen_account/contacts/contact_service.dart';
import 'package:isar_community/isar.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_account/identity/account_security_service.dart';

import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/mls_authentication_fixture.dart' show testMlsDeviceId;

const _owner = 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E';
final _accountId = UserContactService.accountIdFromSs58(_owner);
const _contactA = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
const _ownerCidNumber = 'CN220-CTZN2-198805200-2026';
const _contactCidNumber = 'CN220-CTZN2-100000001-2026';

class _FakeWalletManager implements AccountSecurityService {
  _FakeWalletManager({this.current});
  final _FakeIdentityCache? current;
  @override
  final revision = ValueNotifier<int>(0);
  @override
  Future<IdentityBinding?> readIdentityBindingForCid(String cid) async =>
      (await (current ?? _FakeIdentityCache()).resolve())!.binding;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 身份缓存 fake：恒返回已注册 CID 及其当前绑定账户。
class _FakeIdentityCache implements CurrentUserContext {
  String cid = _ownerCidNumber, account = _accountId;
  void Function(int)? onResolve;
  int resolves = 0;
  @override
  Future<CurrentUser?> resolve() async {
    onResolve?.call(++resolves);
    return CurrentUser(
      account: CitizenWalletStateAccount(
        signMode: CitizenWalletSignMode.hot,
        walletIndex: 1,
        accountIndex: 0,
        accountId: account,
        ss58Address: ss58FromAccountIdText(account),
        name: '默认账户',
        createdAtMillis: BigInt.one,
        isDefault: true,
      ),
      binding: IdentityBinding(
        genesisHash: '0x${'11' * 32}',
        cidNumber: cid,
        accountId: account,
        bindRev: 1,
      ),
    );
  }

  @override
  Future<String?> accountId() async => _accountId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionProvider implements SquareSessionProvider {
  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 'token',
    cidNumber: _ownerCidNumber,
    bindRev: 1,
    accountId: _accountId,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApi extends SquareApiClient {
  _FakeApi() : super(baseUrl: 'https://contacts.test/api');
  int reads = 0;
  @override
  Future<CitizenProfileCard> fetchUserCard({
    required String cidNumber,
    SquareSession? session,
  }) async {
    reads++;
    return CitizenProfileCard({
      'cid_number': _contactCidNumber,
      'account_id': UserContactService.accountIdFromSs58(_contactA),
      'display_name': '联系人',
      'profile_at': 1,
      'cid_level': 'visitor',
      'is_certified': false,
      'member_level': null,
      'membergate_active': false,
      'avatar_key': null,
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('重开保留通讯录各状态与首页偏好，不隐式清理或改写记录', () async {
    final opened = await Isar.open(
      [
        user_store.ProfileSchema,
        user_store.EditSchema,
        user_store.ProfileMediaSchema,
        user_store.IdentitySchema,
        user_store.ContactSchema,
        user_store.NoticeSchema,
        user_store.SettingSchema,
        user_store.FollowSchema,
      ],
      name: 'citizenapp_user',
      directory: await IsarCoreBootstrap.resolveDirectory(),
    );
    await opened.writeTxn(() async {
      await opened.collection<user_store.Contact>().putAll([
        user_store.Contact()
          ..cidNumber = _ownerCidNumber
          ..stateKind = 'pending'
          ..bodyData = 'retain-without-reading',
        user_store.Contact()
          ..cidNumber = _ownerCidNumber
          ..stateKind = 'records'
          ..bodyData = '{}',
      ]);
      await opened.collection<user_store.Setting>().put(
        user_store.Setting()..chatHome = true,
      );
    });
    final usable = await UserIsar.instance.db();
    expect(
      await usable
          .collection<user_store.Contact>()
          .filter()
          .stateKindEqualTo('pending')
          .count(),
      1,
    );
    expect(
      await usable
          .collection<user_store.Contact>()
          .filter()
          .stateKindEqualTo('records')
          .count(),
      1,
    );
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isTrue);
  });

  group('UserContactService', () {
    UserContactService createService() => UserContactService(
      accountSecurity: _FakeWalletManager(),
      currentUserContext: _FakeIdentityCache(),
      sessionProvider: _FakeSessionProvider(),
      apiClient: _FakeApi(),
      autoSync: false,
    );

    test('CID 真源字段支持添加与修改空值合法的私人备注', () async {
      final service = createService();
      final created = await service.addContact(
        cidNumber: _contactCidNumber,
        accountAddress: _contactA,
        contactRemark: '',
      );
      expect(created.created, isTrue);
      expect(created.contact.cidNumber, _contactCidNumber);
      expect(created.contact.contactRemark, isEmpty);

      final renamed = await service.renameContact(
        created.contact.cidNumber,
        '张三',
      );
      expect(renamed.single.contactRemark, '张三');
      expect(renamed.single.toJson().keys.toSet(), <String>{
        'cid_number',
        'account_id',
        'ss58_address',
        'contact_remark',
        'created_at',
        'updated_at',
      });

      final cleared = await service.renameContact(
        created.contact.cidNumber,
        '',
      );
      expect(cleared.single.contactRemark, isEmpty);
    });

    test('拒绝把默认钱包自己加入通讯录', () async {
      final service = createService();
      await expectLater(
        service.addContact(
          cidNumber: _ownerCidNumber,
          accountAddress: _owner,
          contactRemark: '',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('浏览联系人只读本地，保留展示地址和私人备注', () async {
      final service = createService();
      await service.addContact(
        cidNumber: _contactCidNumber,
        accountAddress: _contactA,
        contactRemark: '保留备注',
      );
      final contacts = await service.getContacts();
      expect(contacts.single.cidNumber, _contactCidNumber);
      expect(contacts.single.accountAddress, _contactA);
      expect(contacts.single.contactRemark, '保留备注');
    });

    test('旧 contact_name JSON 缺少 CID 与 contact_remark 时被拒绝', () {
      expect(
        () => UserContact.fromJson(<String, dynamic>{
          'account_id': UserContactService.accountIdFromSs58(_contactA),
          'ss58_address': _contactA,
          'contact_name': '旧名称',
          'created_at': 1,
          'updated_at': 2,
        }),
        throwsFormatException,
      );
    });

    test('用户名片码校验声明 CID，备注留空(码内已无昵称字段)', () async {
      final service = createService();

      final result = await addUserQrContact(
        body: CitizenQrDocument(
          kind: CitizenQrKind.userContact,
          canonicalText: 'synthetic-user-code',
          scanPurposeMask: 198,
          cidNumber: _contactCidNumber,
          accountId: UserContactService.accountIdFromSs58(_contactA),
        ),
        contactService: service,
      );

      expect(result.contact.cidNumber, _contactCidNumber);
      expect(result.contact.contactRemark, isEmpty);
    });

    test('用户名片码声明与服务端当前绑定不一致时拒绝', () async {
      final service = createService();

      await expectLater(
        addUserQrContact(
          body: CitizenQrDocument(
            kind: CitizenQrKind.userContact,
            canonicalText: 'synthetic-user-code',
            scanPurposeMask: 198,
            cidNumber: 'CN001-CTZN-999999999-2026',
            accountId: UserContactService.accountIdFromSs58(_contactA),
          ),
          contactService: service,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await service.getContacts(), isEmpty);
    });
  });

  test('扫码资料核对后切换账号，联系人与待同步操作不能改归新属主', () async {
    final current = _FakeIdentityCache();
    final security = _FakeWalletManager(current: current);
    final api = _FakeApi();
    addTearDown(api.close);
    final service = UserContactService(
      accountSecurity: security,
      currentUserContext: current,
      sessionProvider: _FakeSessionProvider(),
      apiClient: api,
      autoSync: false,
    );
    void switchOwner() {
      current.cid = 'CN220-CTZN2-100000099-2026';
      current.account = '0x${'cd' * 32}';
      security.revision.value++;
    }

    current.onResolve = (number) {
      if (number == 4) switchOwner();
    };
    try {
      await expectLater(
        service.importContact(
          cidNumber: _contactCidNumber,
          accountId: UserContactService.accountIdFromSs58(_contactA),
        ),
        throwsA(isA<AccountSecurityException>()),
      );
    } finally {
      current.onResolve = null;
    }
    final contacts = await UserIsar.instance.read(
      (db) => db.collection<user_store.Contact>().where().findAll(),
    );
    expect(contacts, isEmpty);
  });
  test('公权机构关注按订阅者 CID 持久化，钱包换绑不产生新分区', () async {
    const peerCid = 'GD001-CGOV0-000000001-2026';
    final isar = await AppIsar.instance.db();
    await isar.writeTxn(() async {
      await isar.collection<app_store.Entity>().clear();
    });
    final store = IsarPublicInstitutionStore(isar: isar);
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': peerCid,
        'cid_full_name': '广东省人民政府',
        'province_code': 'GD',
        'city_code': '001',
        'institution_code': 'CGOV',
        'account_count': 2,
      }),
    ]);

    await store.subscribe(_ownerCidNumber, peerCid);

    expect(
      (await store.listSubscribed(_ownerCidNumber)).map((row) => row.cidNumber),
      [peerCid],
      reason: '关注归属永久 CID，不接收或存储当前钱包账户作为分区键',
    );
    expect(await store.listSubscribed('CN220-CTZN2-OTHER-2026'), isEmpty);
  });
}
