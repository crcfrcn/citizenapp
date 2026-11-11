import 'package:isar_community/isar.dart';
part 'chain_state.g.dart';

/// 轻节点业务读模型；键包含创世链与默认账户，正文携带最终区块锚。
@collection
@Name('chain_state')
class ChainState {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String key;
  late String data;
}
