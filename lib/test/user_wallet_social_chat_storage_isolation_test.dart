import 'package:citizen_citizen/public/isar_public_institution_store.dart';
import 'package:citizen_storage/wallet_isar.dart' as wallet_store show Scan;
import 'package:citizen_storage/social_isar.dart'
    as social_store
    show PostCursor;
import 'package:citizen_storage/user_isar.dart' as user_store show Profile;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:citizen_storage/social_isar.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizen_storage/wallet_isar.dart' hide Group;
import 'package:citizen_storage/user_isar.dart';

import 'package:citizen_testing/isar_test_env.dart';

void main() {
  useIsolatedIsar();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('机构关注只按两个自然CID隔离，重复关注不重写且取消不串用户', () async {
    final store = IsarPublicInstitutionStore();
    const owner = 'R5-K3P1C1-N9-D4';
    const other = 'R5-K3P1C1-N8-D5';
    const target = 'R5-K3P1C1-N7-D6';
    await store.subscribe(owner, target);
    await store.subscribe(owner, target);
    await store.subscribe(other, target);
    expect(await store.isSubscribed(owner, target), isTrue);
    expect(await store.isSubscribed(other, target), isTrue);
    expect(await store.isSubscribed(target, owner), isFalse);
    await store.unsubscribe(owner, target);
    expect(await store.isSubscribed(owner, target), isFalse);
    expect(await store.isSubscribed(other, target), isTrue);
  });

  test('UserIsar 队列挂起时 Wallet、Social、Chat 仍独立读写', () async {
    await WalletIsar.instance.db();
    await ChatIsar.instance.db();
    await SocialIsar.instance.db();
    await UserIsar.instance.db();

    final entered = Completer<void>();
    final release = Completer<void>();
    final blockedUser = UserIsar.instance.read<void>((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(const Duration(seconds: 1));

    try {
      await WalletIsar.instance
          .writeTxn<void>((isar) async {
            await isar.collection<wallet_store.Scan>().put(
              wallet_store.Scan()
                ..rowId = 0
                ..walletHash = 'wallet',
            );
          })
          .timeout(const Duration(seconds: 1));
      await SocialIsar.instance
          .writeTxn<void>((isar) async {
            await isar.collection<social_store.PostCursor>().putByCidNumber(
              social_store.PostCursor()
                ..cidNumber = 'R5-K3P1C1-N9-D4'
                ..postId = 'post'
                ..publishedAt = 1,
            );
          })
          .timeout(const Duration(seconds: 1));
      await ChatIsar.instance
          .writeTxn<void>((isar) async {
            await isar.chatRouteCacheEntitys.put(
              ChatRouteCacheEntity()
                ..ownerUserId = 'R5-K3P1C1-N9-D4'
                ..peerUserId = 'R5-K3P1C1-N8-D5'
                ..routeDisplayName = 'chat'
                ..deviceId = 'device-user-isolation'
                ..safetyNumber = '1234'
                ..createdAtMillis = 1
                ..updatedAtMillis = 1,
            );
          })
          .timeout(const Duration(seconds: 1));

      expect(UserIsar.instance.hasActiveOperation, isTrue);
      expect(WalletIsar.instance.hasActiveOperation, isFalse);
      expect(SocialIsar.instance.hasActiveOperation, isFalse);
      expect(ChatIsar.instance.hasActiveOperation, isFalse);
    } finally {
      release.complete();
      await blockedUser.timeout(const Duration(seconds: 1));
    }
  });

  test('Wallet、Social、Chat 同时挂起也不阻塞 User 资料读写', () async {
    await WalletIsar.instance.db();
    await ChatIsar.instance.db();
    await SocialIsar.instance.db();
    await UserIsar.instance.db();

    final walletEntered = Completer<void>();
    final chatEntered = Completer<void>();
    final socialEntered = Completer<void>();
    final release = Completer<void>();
    final blockedWallet = WalletIsar.instance.read<void>((_) async {
      walletEntered.complete();
      await release.future;
    });
    final blockedChat = ChatIsar.instance.read<void>((_) async {
      chatEntered.complete();
      await release.future;
    });
    final blockedSocial = SocialIsar.instance.read<void>((_) async {
      socialEntered.complete();
      await release.future;
    });
    await Future.wait<void>(<Future<void>>[
      walletEntered.future,
      chatEntered.future,
      socialEntered.future,
    ]).timeout(const Duration(seconds: 1));

    try {
      await UserIsar.instance
          .writeTxn<void>((isar) async {
            await isar.collection<user_store.Profile>().putByCidNumber(
              user_store.Profile()
                ..cidNumber = 'R5-K3P1C1-N9-D4'
                ..profileData = '{"display_name":"独立用户资料"}',
            );
          })
          .timeout(const Duration(seconds: 1));
      final profileData = await UserIsar.instance
          .read((isar) async {
            return (await isar.collection<user_store.Profile>().getByCidNumber(
              'R5-K3P1C1-N9-D4',
            ))?.profileData;
          })
          .timeout(const Duration(seconds: 1));

      expect(profileData, '{"display_name":"独立用户资料"}');
      expect(UserIsar.instance.hasActiveOperation, isFalse);
      expect(WalletIsar.instance.hasActiveOperation, isTrue);
      expect(SocialIsar.instance.hasActiveOperation, isTrue);
      expect(ChatIsar.instance.hasActiveOperation, isTrue);
    } finally {
      release.complete();
      await Future.wait<void>(<Future<void>>[
        blockedWallet,
        blockedChat,
        blockedSocial,
      ]).timeout(const Duration(seconds: 1));
    }
  });

  test('UserIsar 回调内重入快速失败，不形成同域自锁', () async {
    final nested = UserIsar.instance.read<void>((_) async {
      await UserIsar.instance.read<void>((_) async {});
    });
    await expectLater(
      nested.timeout(const Duration(seconds: 1)),
      throwsA(isA<StateError>()),
    );
  });

  test('UserIsar 永久挂起不阻止显式关闭，旧结果不能复活', () async {
    await UserIsar.instance.db();
    final entered = Completer<void>();
    final release = Completer<void>();
    final oldOperation = UserIsar.instance.read<String>((_) async {
      entered.complete();
      await release.future;
      return 'stale-user-result';
    });
    await entered.future.timeout(const Duration(seconds: 1));

    await UserIsar.instance.closeAndDeleteFromDisk().timeout(
      const Duration(seconds: 3),
    );
    await expectLater(UserIsar.instance.db(), throwsA(isA<StateError>()));

    release.complete();
    await expectLater(
      oldOperation.timeout(const Duration(seconds: 1)),
      throwsA(isA<StateError>()),
    );
    await UserIsar.instance.resetForTest();
  });

  test('关闭 UserIsar 只删除用户数据库，已写入的其他业务域事实保持可用', () async {
    await UserIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<user_store.Profile>().putByCidNumber(
        user_store.Profile()
          ..cidNumber = 'R5-K3P1C1-N9-D4'
          ..profileData = '{"display_name":"用户资料"}',
      );
    });
    await WalletIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<wallet_store.Scan>().put(
        wallet_store.Scan()
          ..rowId = 0
          ..walletHash = 'wallet',
      );
    });
    await SocialIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<social_store.PostCursor>().putByCidNumber(
        social_store.PostCursor()
          ..cidNumber = 'R5-K3P1C1-N9-D4'
          ..postId = 'social'
          ..publishedAt = 2,
      );
    });
    await ChatIsar.instance.writeTxn<void>((isar) async {
      await isar.chatRouteCacheEntitys.put(
        ChatRouteCacheEntity()
          ..ownerUserId = 'R5-K3P1C1-N9-D4'
          ..peerUserId = 'R5-K3P1C1-N8-D5'
          ..routeDisplayName = 'chat'
          ..deviceId = 'device-user-close'
          ..safetyNumber = '5678'
          ..createdAtMillis = 1
          ..updatedAtMillis = 1,
      );
    });

    await UserIsar.instance.closeAndDeleteFromDisk();
    await expectLater(UserIsar.instance.db(), throwsA(isA<StateError>()));

    expect(
      await WalletIsar.instance.read(
        (isar) async =>
            (await isar.collection<wallet_store.Scan>().get(0))?.walletHash,
      ),
      'wallet',
    );
    expect(
      await SocialIsar.instance.read(
        (isar) async =>
            (await isar.collection<social_store.PostCursor>().getByCidNumber(
              'R5-K3P1C1-N9-D4',
            ))?.postId,
      ),
      'social',
    );
    expect(
      await ChatIsar.instance.read(
        (isar) async =>
            (await isar.chatRouteCacheEntitys.getByOwnerUserIdPeerUserId(
              'R5-K3P1C1-N9-D4',
              'R5-K3P1C1-N8-D5',
            ))?.routeDisplayName,
      ),
      'chat',
    );

    await UserIsar.instance.resetForTest();
    expect(
      await UserIsar.instance.read(
        (isar) => isar.collection<user_store.Profile>().where().count(),
      ),
      0,
    );
  });
}
