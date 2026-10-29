import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:citizenapp/8964/post/square_models.dart';
import 'package:citizenapp/8964/feed/square_tab_order_store.dart';
import 'package:citizenapp/storage/user_isar.dart';

import '../support/isar_test_env.dart';

void main() {
  useIsolatedIsar();

  test('旧顺序去重并保留已保存顺序，缺失分类补回', () {
    expect(resolveSquareTabOrder(['videos', 'article', 'videos', 'unknown']), [
      SquareFeedKind.videos,
      SquareFeedKind.article,
      SquareFeedKind.recommended,
      SquareFeedKind.circle,
      SquareFeedKind.following,
      SquareFeedKind.campaign,
      SquareFeedKind.notifications,
    ]);
  });

  test('连续拖动事务持久保存最后顺序，关闭真库重新打开仍保留', () async {
    const store = SquareTabOrderStore();
    await UserIsar.instance.writeTxn((isar) async {
      await isar.collection<Setting>().put(
        Setting()
          ..guideSeen = true
          ..councilOrder = ['council']
          ..bankOrder = ['bank'],
      );
    });
    final first = List<SquareFeedKind>.of(SquareFeedKind.values.reversed);
    final last = [
      SquareFeedKind.circle,
      ...first.where((k) => k != SquareFeedKind.circle),
    ];
    await Future.wait([store.write(first), store.write(last)]);
    expect(await store.read(), last);
    final db = await UserIsar.instance.db();
    final directory = db.directory!;
    await db.close();
    // 丢弃已关闭的内存实例，从同一个真实文件读取，模拟 App 重启。
    final reopened = Isar.openSync(
      [
        ProfileSchema,
        EditSchema,
        ProfileMediaSchema,
        IdentitySchema,
        ContactSchema,
        NoticeSchema,
        SettingSchema,
        FollowSchema,
      ],
      directory: directory,
      name: 'citizenapp_user',
      relaxedDurability: false,
      inspector: false,
    );
    try {
      final settings = reopened.collection<Setting>().getSync(0)!;
      expect(resolveSquareTabOrder(settings.squareTabOrder), last);
      expect(settings.guideSeen, isTrue);
      expect(settings.councilOrder, ['council']);
      expect(settings.bankOrder, ['bank']);
    } finally {
      await reopened.close();
    }
  });
}
