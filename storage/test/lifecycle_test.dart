// 验证三库结构、事务及生命周期隔离。

import 'package:isar_community/isar.dart';
import 'dart:io';
import 'package:citizen_storage/chat.dart';
import 'package:citizen_storage/core.dart';
import 'package:citizen_storage/social.dart';
import 'package:citizen_storage/user.dart';
import 'package:citizen_testing/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_storage/user.dart' as wallet_store show Scan;
import 'package:citizen_storage/social.dart' as social_store show PostCursor;
import 'dart:async';
import 'package:chat/chat.dart';
import 'package:citizen_storage/user.dart' hide Group;
import 'package:citizen_storage/user.dart' as user;
import 'package:citizen_storage/social.dart' as social;

void main() {
  group('chat_isar_test', _registerChat);
  group('social_storage_lifecycle_test', _registerSocial);
  group('user_social_chat_storage_test', _registerIsolation);
}

// 验证聊天库真实重开及与用户和广场库的生命周期隔离。

void _registerChat() {
  useIsolatedIsar();

  test('聊天库真实重开后保留自己的数据和物理文件名', () async {
    final first = await ChatIsar.instance.db();
    await ChatIsar.instance.writeTxn((isar) async {
      await isar.chatBindingFenceEntitys.put(
        ChatBindingFenceEntity()
          ..ownerUserId = 'synthetic-owner'
          ..generation = 7
          ..fenceState = 'active',
      );
    });
    await first.close();
    final reopened = await ChatIsar.instance.db();
    expect(identical(first, reopened), isFalse);
    final records = await ChatIsar.instance.read(
      (isar) => isar.chatBindingFenceEntitys.where().findAll(),
    );
    expect(records.single.ownerUserId, 'synthetic-owner');
    expect(records.single.generation, 7);
    expect(
      File(
        '${IsarCoreBootstrap.debugTestDirectoryOverride}/chat.isar',
      ).existsSync(),
      isTrue,
    );
  });

  test('关闭和删除聊天库不会关闭或删除用户库、广场库', () async {
    final user = await UserIsar.instance.db();
    final social = await SocialIsar.instance.db();
    final chat = await ChatIsar.instance.db();
    await UserIsar.instance.writeOpenChatOnLaunch(true);
    expect({user.name, social.name, chat.name}.length, 3);
    await ChatIsar.instance.closeAndDeleteFromDisk();
    expect(user.isOpen, isTrue);
    expect(social.isOpen, isTrue);
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isTrue);
    await SocialIsar.instance.read((isar) async => isar.isOpen);
    final root = IsarCoreBootstrap.debugTestDirectoryOverride;
    expect(File('$root/chat.isar').existsSync(), isFalse);
    expect(File('$root/${user.name}.isar').existsSync(), isTrue);
    expect(File('$root/${social.name}.isar').existsSync(), isTrue);
    await expectLater(ChatIsar.instance.db(), throwsStateError);
  });
}

// 验证广场库独立队列、重入拒绝及关闭后的迟到结果隔离。

void _registerSocial() {
  useIsolatedIsar();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SocialIsar 队列挂起时 UserIsar 与 ChatIsar 读写仍独立完成', () async {
    await Future.wait<void>(<Future<void>>[
      SocialIsar.instance.db().then<void>((_) {}),
      UserIsar.instance.db().then<void>((_) {}),
      ChatIsar.instance.db().then<void>((_) {}),
    ]);

    final entered = Completer<void>();
    final release = Completer<void>();
    final blockedSocial = SocialIsar.instance.read<void>((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(const Duration(seconds: 1));

    try {
      await UserIsar.instance
          .writeTxn<void>((isar) async {
            await isar.collection<wallet_store.Scan>().put(
              wallet_store.Scan()
                ..rowId = 0
                ..walletHash = 'wallet-ok',
            );
          })
          .timeout(const Duration(seconds: 1));

      await ChatIsar.instance
          .writeTxn<void>((isar) async {
            final route = ChatRouteCacheEntity()
              ..ownerUserId = 'R5-K3P1C1-N9-D4'
              ..peerUserId = 'R5-K3P1C1-N8-D5'
              ..routeDisplayName = '隔离测试联系人'
              ..deviceId = 'device-a'
              ..safetyNumber = '1234'
              ..createdAtMillis = 1
              ..updatedAtMillis = 1;
            await isar.chatRouteCacheEntitys.put(route);
          })
          .timeout(const Duration(seconds: 1));

      final walletValue = await UserIsar.instance
          .read<String?>((isar) async {
            return (await isar.collection<wallet_store.Scan>().get(
              0,
            ))?.walletHash;
          })
          .timeout(const Duration(seconds: 1));
      final chatValue = await ChatIsar.instance
          .read<String?>((isar) async {
            return (await isar.chatRouteCacheEntitys.getByOwnerUserIdPeerUserId(
              'R5-K3P1C1-N9-D4',
              'R5-K3P1C1-N8-D5',
            ))?.routeDisplayName;
          })
          .timeout(const Duration(seconds: 1));

      expect(walletValue, 'wallet-ok');
      expect(chatValue, '隔离测试联系人');
      expect(SocialIsar.instance.hasActiveOperation, isTrue);
      expect(UserIsar.instance.hasActiveOperation, isFalse);
      expect(ChatIsar.instance.hasActiveOperation, isFalse);
    } finally {
      if (!release.isCompleted) release.complete();
      await blockedSocial.timeout(const Duration(seconds: 1));
    }
  });

  test('SocialIsar 回调内重入会快速失败，不形成同域自锁', () async {
    final nested = SocialIsar.instance.read<void>((_) async {
      await SocialIsar.instance.read<void>((_) async {});
    });
    await expectLater(
      nested.timeout(const Duration(seconds: 1)),
      throwsA(isA<StateError>()),
    );
  });

  test('SocialIsar 永久挂起操作不阻止关闭终态，旧结果不得复活', () async {
    await SocialIsar.instance.db();
    final entered = Completer<void>();
    final release = Completer<void>();
    final oldOperation = SocialIsar.instance.read<String>((_) async {
      entered.complete();
      await release.future;
      return 'stale-social-result';
    });
    await entered.future.timeout(const Duration(seconds: 1));

    await SocialIsar.instance.closeAndDeleteFromDisk().timeout(
      const Duration(seconds: 3),
    );
    await expectLater(SocialIsar.instance.db(), throwsA(isA<StateError>()));

    release.complete();
    await expectLater(
      oldOperation.timeout(const Duration(seconds: 1)),
      throwsA(isA<StateError>()),
    );
    await SocialIsar.instance.resetForTest();
  });

  test('关闭 SocialIsar 只删除广场数据库，钱包与聊天事实保持可用', () async {
    await SocialIsar.instance.writeTxn<void>((isar) async {
      final checkpoint = social_store.PostCursor()
        ..cidNumber = 'R5-K3P1C1-N9-D4'
        ..postId = 'sqp_a'
        ..publishedAt = 1;
      await isar.collection<social_store.PostCursor>().putByCidNumber(
        checkpoint,
      );
    });
    await UserIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<wallet_store.Scan>().put(
        wallet_store.Scan()
          ..rowId = 0
          ..walletHash = 'wallet',
      );
    });
    await ChatIsar.instance.writeTxn<void>((isar) async {
      final route = ChatRouteCacheEntity()
        ..ownerUserId = 'R5-K3P1C1-N9-D4'
        ..peerUserId = 'R5-K3P1C1-N8-D5'
        ..routeDisplayName = 'chat'
        ..deviceId = 'device-b'
        ..safetyNumber = '5678'
        ..createdAtMillis = 1
        ..updatedAtMillis = 1;
      await isar.chatRouteCacheEntitys.put(route);
    });

    await SocialIsar.instance.closeAndDeleteFromDisk();
    await expectLater(SocialIsar.instance.db(), throwsA(isA<StateError>()));

    final wallet = await UserIsar.instance.read<String?>((isar) async {
      return (await isar.collection<wallet_store.Scan>().get(0))?.walletHash;
    });
    final chat = await ChatIsar.instance.read<String?>((isar) async {
      return (await isar.chatRouteCacheEntitys.getByOwnerUserIdPeerUserId(
        'R5-K3P1C1-N9-D4',
        'R5-K3P1C1-N8-D5',
      ))?.routeDisplayName;
    });
    expect(wallet, 'wallet');
    expect(chat, 'chat');

    await SocialIsar.instance.resetForTest();
    final checkpointCount = await SocialIsar.instance.read(
      (isar) => isar.collection<social_store.PostCursor>().where().count(),
    );
    expect(checkpointCount, 0);
  });
}

// 验证三库精确结构、并发隔离及统一用户库原子事务。

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
  'contact': {
    'id',
    'owner_cid',
    'cid_number',
    'contact_remark',
    'pending',
    'change_version',
    'deleted',
    'delete_batch',
  },
  'contact_delete': {'id', 'ownerCid', 'batchId', 'data'},
  'notice': {'id', 'cid_number', 'data', 'pending', 'list_data'},
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
  'summary': {'id', 'proposal_id', 'proposal_id_text', 'data'},
  'list': {
    'id',
    'cid_number',
    'finalized_hash',
    'finalized_height',
    'proposal_ids',
    'proposal_id_texts',
    'synced_at',
  },
  'proposal': {'id', 'kind', 'proposal_id', 'data', 'proposal_id_text'},
  'law': {'id', 'state_key', 'state_hex'},
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
    'proposal_id_text',
  },
  'cursor': {
    'id',
    'account_id',
    'created_at',
    'genesis_hash',
    'start_block',
    'cursor_block',
    'event_version',
  },
  'entry': {
    'id',
    'service_origin',
    'order_id',
    'order_data',
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
    'post_visibility',
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
    'post_visibility',
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
    'post_visibility',
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

void _registerIsolation() {
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
      user.ContactDeleteBatchSchema,
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
      'chat',
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
      db.contactDeleteBatchs,
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
      'contact_delete',
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
      'member',
      'creator',
      'account',
      'action',
      'cursor',
      'entry',
    });
    expect(collections, hasLength(27));
    expect(
      collections.map((collection) => collection.name),
      isNot(contains('admin')),
    );
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
        profile: (await db.profiles.getByCidNumber(
          'synthetic-owner',
        ))?.profileData,
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
