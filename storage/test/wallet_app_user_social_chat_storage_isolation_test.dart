import 'package:citizen_storage/app_isar.dart'
    as app_store
    show Region, Version;
import 'package:citizen_storage/social_isar.dart'
    as social_store
    show PostCursor;
import 'package:citizen_storage/user_isar.dart' as user_store show Profile;
import 'package:citizen_storage/wallet_isar.dart' as wallet_store show Scan;

import 'dart:async';

import 'package:citizen_storage/social_isar.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizen_storage/app_isar.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_storage/wallet_isar.dart' hide Group;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:citizen_testing/isar_test_env.dart';

const Duration _timeout = Duration(seconds: 1);
const String _ownerUserId = 'CN220-CTZN2-100000011-2026';
const String _peerUserId = 'CN220-CTZN2-100000012-2026';

void main() {
  useIsolatedIsar();

  test('五个数据库四轮交错并发冷启动仍持有各自句柄与集合', () async {
    // 重复冷启动并交替调用顺序，真实开库和集合访问必须同时覆盖五域。
    final openers = <Future<Isar> Function()>[
      AppIsar.instance.db,
      SocialIsar.instance.db,
      ChatIsar.instance.db,
      UserIsar.instance.db,
      WalletIsar.instance.db,
    ];
    for (var round = 0; round < 4; round++) {
      if (round > 0) {
        await WalletIsar.instance.resetForTest();
        await ChatIsar.instance.resetForTest();
        await SocialIsar.instance.resetForTest();
        await UserIsar.instance.resetForTest();
        await AppIsar.instance.resetForTest();
      }
      final order = round.isEven ? openers : openers.reversed;
      final opened = await Future.wait<Isar>(order.map((open) => open()));
      final byName = <String, Isar>{for (final isar in opened) isar.name: isar};
      expect(byName.keys.toSet(), <String>{
        'citizenapp_app',
        'citizenapp_social',
        'tatachat_sdk_chat',
        'citizenapp_user',
        'citizenapp_wallet',
      });
      expect(opened.toSet(), hasLength(5));
      for (final isar in opened) {
        expect(Isar.getInstance(isar.name), same(isar));
      }
      final counts = await Future.wait<int>(<Future<int>>[
        byName['citizenapp_app']!.collection<app_store.Region>().count(),
        byName['citizenapp_social']!
            .collection<social_store.PostCursor>()
            .count(),
        byName['tatachat_sdk_chat']!.chatRouteCacheEntitys.count(),
        byName['citizenapp_user']!.collection<user_store.Profile>().count(),
        byName['citizenapp_wallet']!.collection<wallet_store.Scan>().count(),
      ]);
      expect(counts, everyElement(0), reason: '第 $round 轮集合必须属于各自的新库');
    }
  });

  test('AppIsar 队列挂起时其余四域仍可独立读写', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocked = AppIsar.instance.read<void>((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(_timeout);

    try {
      await Future.wait<void>(<Future<void>>[
        WalletIsar.instance.writeTxn<void>((isar) async {
          await isar.collection<wallet_store.Scan>().put(
            wallet_store.Scan()
              ..rowId = 0
              ..walletHash = 'wallet',
          );
        }),
        UserIsar.instance.writeTxn<void>((isar) async {
          await isar.collection<user_store.Profile>().putByCidNumber(
            user_store.Profile()
              ..cidNumber = _ownerUserId
              ..profileData = '{"display_name":"用户资料"}',
          );
        }),
        SocialIsar.instance.writeTxn<void>((isar) async {
          await isar.collection<social_store.PostCursor>().putByCidNumber(
            social_store.PostCursor()
              ..cidNumber = _ownerUserId
              ..postId = 'post'
              ..publishedAt = 1,
          );
        }),
        ChatIsar.instance.writeTxn<void>((isar) async {
          await isar.chatRouteCacheEntitys.put(
            ChatRouteCacheEntity()
              ..ownerUserId = _ownerUserId
              ..peerUserId = _peerUserId
              ..routeDisplayName = '联系人'
              ..deviceId = 'device'
              ..safetyNumber = '1234'
              ..createdAtMillis = 1
              ..updatedAtMillis = 1,
          );
        }),
      ]).timeout(_timeout);

      expect(AppIsar.instance.hasActiveOperation, isTrue);
      expect(WalletIsar.instance.hasActiveOperation, isFalse);
      expect(UserIsar.instance.hasActiveOperation, isFalse);
      expect(SocialIsar.instance.hasActiveOperation, isFalse);
      expect(ChatIsar.instance.hasActiveOperation, isFalse);
    } finally {
      release.complete();
      await blocked.timeout(_timeout);
    }
  });

  test('WalletIsar 队列挂起时 App 通用目录仍可独立读写', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocked = WalletIsar.instance.read<void>((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(_timeout);

    try {
      await AppIsar.instance
          .writeTxn<void>((isar) async {
            await isar.collection<app_store.Version>().putByDataKind(
              app_store.Version()
                ..dataKind = 'storage-isolation'
                ..globalVersion = 'app-ready',
            );
          })
          .timeout(_timeout);
      final value = await AppIsar.instance
          .read<String?>((isar) async {
            return (await isar.collection<app_store.Version>().getByDataKind(
              'storage-isolation',
            ))?.globalVersion;
          })
          .timeout(_timeout);

      expect(value, 'app-ready');
      expect(WalletIsar.instance.hasActiveOperation, isTrue);
      expect(AppIsar.instance.hasActiveOperation, isFalse);
    } finally {
      release.complete();
      await blocked.timeout(_timeout);
    }
  });

  test('关闭 AppIsar 只删除通用数据库，其余四域事实保持可用', () async {
    await AppIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<app_store.Version>().putByDataKind(
        app_store.Version()
          ..dataKind = 'delete-boundary'
          ..globalVersion = 'app',
      );
    });
    await WalletIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<wallet_store.Scan>().put(
        wallet_store.Scan()
          ..rowId = 0
          ..walletHash = 'wallet',
      );
    });
    await UserIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<user_store.Profile>().putByCidNumber(
        user_store.Profile()
          ..cidNumber = _ownerUserId
          ..profileData = '{"display_name":"保留用户资料"}',
      );
    });
    await SocialIsar.instance.writeTxn<void>((isar) async {
      await isar.collection<social_store.PostCursor>().putByCidNumber(
        social_store.PostCursor()
          ..cidNumber = _ownerUserId
          ..postId = 'social'
          ..publishedAt = 1,
      );
    });
    await ChatIsar.instance.writeTxn<void>((isar) async {
      await isar.chatRouteCacheEntitys.put(
        ChatRouteCacheEntity()
          ..ownerUserId = _ownerUserId
          ..peerUserId = _peerUserId
          ..routeDisplayName = 'chat'
          ..deviceId = 'device'
          ..safetyNumber = '5678'
          ..createdAtMillis = 1
          ..updatedAtMillis = 1,
      );
    });

    await AppIsar.instance.closeAndDeleteFromDisk();
    await expectLater(AppIsar.instance.db(), throwsA(isA<StateError>()));

    expect(
      await WalletIsar.instance.read(
        (isar) async =>
            (await isar.collection<wallet_store.Scan>().get(0))?.walletHash,
      ),
      'wallet',
    );
    expect(
      await UserIsar.instance.read(
        (isar) async =>
            (await isar.collection<user_store.Profile>().getByCidNumber(
              _ownerUserId,
            ))?.profileData,
      ),
      '{"display_name":"保留用户资料"}',
    );
    expect(
      await SocialIsar.instance.read(
        (isar) async =>
            (await isar.collection<social_store.PostCursor>().getByCidNumber(
              _ownerUserId,
            ))?.postId,
      ),
      'social',
    );
    expect(
      await ChatIsar.instance.read(
        (isar) async =>
            (await isar.chatRouteCacheEntitys.getByOwnerUserIdPeerUserId(
              _ownerUserId,
              _peerUserId,
            ))?.routeDisplayName,
      ),
      'chat',
    );
  });

  test('AppIsar 回调内重入快速失败，不形成同域自锁', () async {
    final nested = AppIsar.instance.read<void>((_) async {
      await AppIsar.instance.read<void>((_) async {});
    });
    await expectLater(nested.timeout(_timeout), throwsA(isA<StateError>()));
  });
}
