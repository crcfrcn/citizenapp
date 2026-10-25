import 'package:citizenapp/citizen/account_derivation.dart';
import 'package:flutter/foundation.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/profile/citizen_profile.dart';
import 'package:citizenapp/citizen/public/isar_public_institution_store.dart';
import 'package:citizenapp/citizen/public/public_institution_dto.dart';
import 'package:citizenapp/storage/app_isar.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/storage/user_isar.dart';
import 'package:citizenapp/storage/isar_core_bootstrap.dart';
import 'package:citizenapp/account/contacts/contact_service.dart';
import 'package:citizenapp/scanner/qr_scan_page.dart';
import 'package:isar_community/isar.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/account_security_service.dart';

import '../../support/isar_test_env.dart';
import '../../square/mls_authentication_fixture.dart' show testMlsDeviceId;

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
        bindingRevision: 1,
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
    bindingRevision: 1,
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
      'updated_at': 1,
      'identity_level': 'visitor',
      'is_certified': false,
      'membergate_level': null,
      'membergate_active': false,
      'avatar_object_key': null,
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('开库前精确删除废弃通讯录行，保留新记录和首页偏好', () async {
    final opened = await Isar.open(
      [
        UserPublicProfileCacheEntitySchema,
        UserProfileUpdateEntitySchema,
        UserProfileMediaEntitySchema,
        UserIdentityBadgeSnapshotEntitySchema,
        UserContactStateEntitySchema,
        UserNotificationStateEntitySchema,
        UserSettingsEntitySchema,
        UserPublicInstitutionSubscriptionEntitySchema,
      ],
      name: 'citizenapp_user',
      directory: await IsarCoreBootstrap.resolveDirectory(),
    );
    await opened.writeTxn(() async {
      await opened.userContactStateEntitys.putAll([
        UserContactStateEntity()
          ..stateKey = 'user.contact.obsolete'
          ..ownerCidNumber = _ownerCidNumber
          ..stateKind = 'book'
          ..payloadJson = 'discard-without-reading',
        UserContactStateEntity()
          ..stateKey = 'user.mls.contacts.book:$_ownerCidNumber'
          ..ownerCidNumber = _ownerCidNumber
          ..stateKind = 'book'
          ..payloadJson = '[]',
      ]);
      await opened.userSettingsEntitys.put(
        UserSettingsEntity()..openChatOnLaunch = true,
      );
    });
    final usable = await UserIsar.instance.db();
    expect(
      await usable.userContactStateEntitys
          .filter()
          .stateKeyStartsWith('user.contact.')
          .count(),
      0,
    );
    expect(
      await usable.userContactStateEntitys
          .filter()
          .stateKeyStartsWith('user.mls.contacts.book:')
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
        ss58Address: _contactA,
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
          ss58Address: _owner,
          contactRemark: '',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('浏览联系人只读本地，保留展示地址和私人备注', () async {
      final service = createService();
      await service.addContact(
        cidNumber: _contactCidNumber,
        ss58Address: _contactA,
        contactRemark: '保留备注',
      );
      final contacts = await service.getContacts();
      expect(contacts.single.cidNumber, _contactCidNumber);
      expect(contacts.single.ss58Address, _contactA);
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
      (db) => db.userContactStateEntitys.where().findAll(),
    );
    expect(contacts, isEmpty);
  });
  test('公权机构关注按订阅者 CID 持久化，钱包换绑不产生新分区', () async {
    const institutionCidNumber = 'GD001-CGOV0-000000001-2026';
    final isar = await AppIsar.instance.db();
    await isar.writeTxn(() async {
      await isar.publicInstitutionEntitys.clear();
    });
    final store = IsarPublicInstitutionStore(isar: isar);
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': institutionCidNumber,
        'cid_full_name': '广东省人民政府',
        'province_code': 'GD',
        'city_code': '001',
        'institution_code': 'CGOV',
        'account_count': 2,
      }),
    ], catalogVersion: 'test');

    await store.subscribe(_ownerCidNumber, institutionCidNumber);

    expect(
      (await store.listSubscribed(_ownerCidNumber)).map((row) => row.cidNumber),
      [institutionCidNumber],
      reason: '关注归属永久 CID，不接收或存储当前钱包账户作为分区键',
    );
    expect(await store.listSubscribed('CN220-CTZN2-OTHER-2026'), isEmpty);
  });
}
