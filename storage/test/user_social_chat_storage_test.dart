import 'dart:async';

import 'package:citizen_storage/user_isar.dart' as user;
import 'package:citizen_storage/social_isar.dart' as social;
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

const _timeout = Duration(seconds: 2);

const _userColumns = <String, Set<String>>{
  'region': {'id', 'province_code', 'city_code', 'town_code', 'region_name'},
  'entity': {
    'id',
    'cid_number',
    'full_name',
    'short_name',
    'cid_state',
    'province_code',
    'city_code',
    'town_code',
    'org_code',
    'parent_cid',
    'is_legal',
    'family_name',
    'given_name',
    'legal_cid',
    'legal_account',
    'account_count',
    'account_names',
  },
  'sync': {'id', 'data_kind', 'global_version', 'province_data'},
  'catalog': {'id', 'province_codes'},
  'province': {'id', 'province_code', 'data_version'},
  'edit': {
    'id',
    'cid_number',
    'state',
    'request',
    'response',
    'content_hash',
    'avatar_bytes',
    'banner_bytes',
  },
  'profile': {'id', 'cid_number', 'data'},
  'media': {
    'id',
    'cid_number',
    'media_role',
    'object_key',
    'profile_at',
    'body_hash',
    'media_bytes',
  },
  'identity': {'id', 'cid_number', 'account_id', 'data', 'updated_at'},
  'contact': {'id', 'cid_number', 'kind', 'data'},
  'notice': {'id', 'cid_number', 'data', 'pending'},
  'setting': {
    'id',
    'guide_seen',
    'chat_home',
    'council_order',
    'bank_order',
    'square_tab_order',
  },
  'follow': {'id', 'cid_number', 'peer_cid'},
  'balance': {'id', 'account_id', 'data'},
  'group': {'id', 'account_id', 'state', 'synced_at', 'data'},
  'scan': {'id', 'wallet_hash'},
  'summary': {'id', 'proposal_id', 'data'},
  'list': {'id', 'cid_number', 'proposal_ids', 'synced_at'},
  'proposal': {'id', 'kind', 'proposal_id', 'data'},
  'law': {'id', 'state_key', 'state_hex'},
  'admin': {'id', 'data'},
  'member': {'id', 'cid_number', 'kind', 'data'},
  'creator': {'id', 'cid_number', 'data'},
  'account': {
    'id',
    'account_id',
    'account_name',
    'creator_account',
    'added_at',
    'is_found',
    'admin_accounts',
  },
  'action': {
    'id',
    'account_id',
    'proposal_id',
    'kind',
    'state',
    'yes_count',
    'no_count',
    'created_at',
    'final_at',
    'data',
  },
  'cursor': {
    'id',
    'account_id',
    'created_at',
    'genesis_hash',
    'start_block',
    'cursor_block',
  },
  'entry': {
    'id',
    'account_id',
    'kind',
    'amount_delta',
    'transfer_amount',
    'fee_amount',
    'from_address',
    'to_address',
    'tx_note',
    'state',
    'entry_source',
    'tx_hash',
    'execution_id',
    'call_hash',
    'block_number',
    'block_hash',
    'event_index',
    'extrinsic_index',
    'created_at',
    'confirmed_at',
    'fail_reason',
  },
};
const _socialColumns = <String, Set<String>>{
  'reply': {'id', 'cid_number', 'post_id', 'page_data', 'pending'},
  'erase': {'id', 'cid_number', 'post_id', 'state'},
  'post': {
    'id',
    'post_id',
    'cid_number',
    'account_id',
    'post_category',
    'post_type',
    'manifest_bytes',
    'content_hash',
    'receipt_id',
    'chain_block',
    'published_at',
    'state',
  },
  'draft': {
    'id',
    'cid_number',
    'draft_id',
    'post_type',
    'post_title',
    'post_text',
    'media_data',
    'section_data',
    'updated_at',
  },
  'cursor': {'id', 'cid_number', 'post_id', 'published_at'},
  'cleanup': {
    'id',
    'cid_number',
    'draft_id',
    'cleanup_kind',
    'created_at',
    'try_count',
    'last_error',
  },
  'media': {
    'id',
    'cid_number',
    'media_kind',
    'content_type',
    'byte_size',
    'body_hash',
    'is_complete',
  },
  'chunk': {
    'id',
    'cid_number',
    'body_hash',
    'part_index',
    'part_bytes',
    'part_hash',
  },
  'link': {
    'id',
    'cid_number',
    'body_hash',
    'content_id',
    'content_kind',
    'media_index',
    'media_role',
  },
  'publish': {
    'id',
    'cid_number',
    'draft_id',
    'account_id',
    'post_id',
    'post_type',
    'content_hash',
    'receipt_id',
    'upload_id',
    'manifest_bytes',
    'state',
    'replace_id',
    'block_hash',
    'tx_hash',
    'post_category',
    'chain_block',
    'published_at',
  },
};

void main() {
  useIsolatedIsar();

  test('统一用户库与广场库使用精确物理表列合同', () {
    const userSchemas = <CollectionSchema<dynamic>>[
      user.RegionSchema,
      user.EntitySchema,
      user.VersionSchema,
      user.CatalogSchema,
      user.ProvinceSchema,
      user.EditSchema,
      user.ProfileSchema,
      user.ProfileMediaSchema,
      user.IdentitySchema,
      user.ContactSchema,
      user.NoticeSchema,
      user.SettingSchema,
      user.FollowSchema,
      user.BalanceSchema,
      user.GroupSchema,
      user.ScanSchema,
      user.SummarySchema,
      user.ProposalListSchema,
      user.ProposalSchema,
      user.LawSnapshotSchema,
      user.AdminSchema,
      user.MemberSchema,
      user.CreatorSchema,
      user.AccountSchema,
      user.ActionSchema,
      user.WalletCursorSchema,
      user.EntrySchema,
    ];
    const socialSchemas = <CollectionSchema<dynamic>>[
      social.ReplySchema,
      social.EraseSchema,
      social.PostSchema,
      social.DraftSchema,
      social.PostCursorSchema,
      social.CleanupSchema,
      social.MediaSchema,
      social.ChunkSchema,
      social.MediaLinkSchema,
      social.PublishSchema,
    ];
    for (final pair in [
      (userSchemas, _userColumns),
      (socialSchemas, _socialColumns),
    ]) {
      expect(pair.$1.map((s) => s.name).toSet(), pair.$2.keys.toSet());
      for (final schema in pair.$1) {
        expect(schema.idName, 'id');
        expect({
          schema.idName,
          ...schema.properties.keys,
        }, pair.$2[schema.name]);
      }
    }
  });

  test('三个 Isar 文件交错并发打开，统一用户库包含全部 27 张表', () async {
    final opened = await Future.wait([
      user.UserIsar.instance.db(),
      social.SocialIsar.instance.db(),
      ChatIsar.instance.db(),
      user.UserIsar.instance.db(),
    ]);
    expect(opened[0], same(opened[3]));
    expect(opened.map((db) => db.name).toSet(), {
      'citizenapp_user',
      'citizenapp_social',
      'tatachatsdk_chat',
    });
    final db = opened.first;
    final collections = <IsarCollection<dynamic>>[
      db.regions,
      db.entitys,
      db.versions,
      db.catalogs,
      db.provinces,
      db.edits,
      db.profiles,
      db.profileMedias,
      db.identitys,
      db.contacts,
      db.notices,
      db.settings,
      db.follows,
      db.balances,
      db.groups,
      db.scans,
      db.summarys,
      db.proposalLists,
      db.proposals,
      db.lawSnapshots,
      db.admins,
      db.members,
      db.creators,
      db.accounts,
      db.actions,
      db.walletCursors,
      db.entrys,
    ];
    expect(collections.map((c) => c.name).toSet(), {
      'region',
      'entity',
      'sync',
      'catalog',
      'province',
      'edit',
      'profile',
      'media',
      'identity',
      'contact',
      'notice',
      'setting',
      'follow',
      'balance',
      'group',
      'scan',
      'summary',
      'list',
      'proposal',
      'law',
      'admin',
      'member',
      'creator',
      'account',
      'action',
      'cursor',
      'entry',
    });
    expect(collections, hasLength(27));
    for (final collection in collections) {
      expect(collection.isar, same(db));
      expect(await collection.count(), 0);
    }
  });

  test('目录、资料、钱包记录共用串行队列，前一操作结束后继续执行', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final first = user.UserIsar.instance.read((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(_timeout);
    var secondStarted = false;
    final second = user.UserIsar.instance.writeTxn((db) async {
      secondStarted = true;
      await db.profiles.putByCidNumber(
        user.Profile()
          ..cidNumber = 'synthetic-owner'
          ..profileData = 'synthetic-profile',
      );
      await db.scans.put(
        user.Scan()
          ..rowId = 0
          ..walletHash = 'synthetic-wallet',
      );
    });
    await Future<void>.delayed(Duration.zero);
    expect(secondStarted, isFalse);
    release.complete();
    await Future.wait([first, second]).timeout(_timeout);
    final data = await user.UserIsar.instance.read(
      (db) async => (
        profile: (await db.profiles.getByCidNumber('synthetic-owner'))
            ?.profileData,
        wallet: (await db.scans.get(0))?.walletHash,
      ),
    );
    expect(data, (profile: 'synthetic-profile', wallet: 'synthetic-wallet'));
  });

  test('统一用户库队列等待时，广场与聊天库仍可独立读写', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final blocked = user.UserIsar.instance.read((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(_timeout);
    try {
      await social.SocialIsar.instance
          .writeTxn((db) async {
            await db.postCursors.putByCidNumber(
              social.PostCursor()
                ..cidNumber = 'synthetic-owner'
                ..postId = 'synthetic-post'
                ..publishedAt = 1,
            );
          })
          .timeout(_timeout);
      await ChatIsar.instance
          .read((db) => db.chatRouteCacheEntitys.count())
          .timeout(_timeout);
    } finally {
      release.complete();
      await blocked.timeout(_timeout);
    }
  });

  test('同库重入快速失败，不因目录与钱包归并形成自锁', () async {
    final nested = user.UserIsar.instance.read((_) async {
      await user.UserIsar.instance.writeTxn((_) async {});
    });
    await expectLater(nested.timeout(_timeout), throwsA(isA<StateError>()));
  });

  test('统一事务失败同时回滚用户资料与钱包业务写入', () async {
    await expectLater(
      user.UserIsar.instance.writeTxn((db) async {
        await db.profiles.putByCidNumber(
          user.Profile()
            ..cidNumber = 'synthetic-owner'
            ..profileData = 'not-committed',
        );
        await db.scans.put(
          user.Scan()
            ..rowId = 0
            ..walletHash = 'not-committed',
        );
        throw StateError('synthetic rollback');
      }),
      throwsA(isA<StateError>()),
    );
    final counts = await user.UserIsar.instance.read(
      (db) async => (await db.profiles.count(), await db.scans.count()),
    );
    expect(counts, (0, 0));
  });

  test('关闭统一用户库先取消 watcher，关闭后拒绝所有新操作', () async {
    await user.UserIsar.instance.db();
    var cancelled = false;
    late user.IsarConsumerLease lease;
    lease = user.UserIsar.instance.registerExternalConsumer(() async {
      cancelled = true;
      lease.release();
    });
    await user.UserIsar.instance.closeAndDeleteFromDisk();
    expect(cancelled, isTrue);
    await expectLater(user.UserIsar.instance.db(), throwsA(isA<StateError>()));
    expect(
      () => user.UserIsar.instance.registerExternalConsumer(() async {}),
      throwsStateError,
    );
    expect(
      await social.SocialIsar.instance.read((db) => db.postCursors.count()),
      0,
    );
    expect(
      await ChatIsar.instance.read((db) => db.chatRouteCacheEntitys.count()),
      0,
    );
  });

  test('活动操作超时不阻止关闭终态，迟到结果不能复活主库', () async {
    await user.UserIsar.instance.db();
    final entered = Completer<void>(), release = Completer<void>();
    final old = user.UserIsar.instance.read((_) async {
      entered.complete();
      await release.future;
      return 'stale';
    });
    await entered.future.timeout(_timeout);
    final rejected = expectLater(old, throwsA(isA<StateError>()));
    await user.UserIsar.instance.closeAndDeleteFromDisk().timeout(
      const Duration(seconds: 4),
    );
    release.complete();
    await rejected.timeout(_timeout);
    await expectLater(user.UserIsar.instance.db(), throwsA(isA<StateError>()));
  });
}
