import 'package:citizen_storage/user_isar.dart' as wallet_store show Scan;
import 'package:citizen_storage/social_isar.dart'
    as social_store
    show PostCursor;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:citizen_storage/social_isar.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizen_storage/user_isar.dart' hide Group;

import 'package:citizen_testing/isar_test_env.dart';

void main() {
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
            return (await isar.collection<wallet_store.Scan>().get(0))
                ?.walletHash;
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
