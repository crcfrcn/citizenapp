import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_storage/user_isar.dart';

/// 使用稳定分类名保存顺序，去除未知/重复项，新增分类补到末尾。
List<SquareFeedKind> resolveSquareTabOrder(List<String> saved) {
  final byName = {for (final kind in SquareFeedKind.values) kind.name: kind};
  return <SquareFeedKind>{
    for (final name in saved)
      if (byName[name] != null) byName[name]!,
    ...SquareFeedKind.values,
  }.toList(growable: false);
}

/// 展示偏好保存在现有 UserIsar 设置行；事务由 UserIsar 按调用顺序提交。
class SquareTabOrderStore {
  const SquareTabOrderStore();

  Future<List<SquareFeedKind>> read() => UserIsar.instance.read((isar) async {
    final settings = await isar.collection<Setting>().get(0);
    return resolveSquareTabOrder(settings?.squareTabOrder ?? const []);
  });

  Future<void> write(List<SquareFeedKind> order) {
    final names = order.map((kind) => kind.name).toList(growable: false);
    return UserIsar.instance.writeTxn((isar) async {
      final settings = await isar.collection<Setting>().get(0) ?? Setting();
      settings.rowId = 0;
      settings.squareTabOrder = names;
      await isar.collection<Setting>().put(settings);
    });
  }
}
