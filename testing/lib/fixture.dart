import 'dart:convert';
import 'dart:io';

/// 按真实Pub配置定位所属包的测试夹具；不依赖从仓库根还是包目录启动。
File fixtureFile(String package, String path, {Directory? from}) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path
          .split('/')
          .any((part) => part.isEmpty || part == '..' || part == '.')) {
    throw ArgumentError.value(path, 'path', '须为包内测试相对路径');
  }
  var directory = (from ?? Directory.current).absolute;
  while (!File('${directory.path}/.dart_tool/package_config.json')
      .existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) throw StateError('测试需要产品Pub包配置');
    directory = parent;
  }
  final config = File('${directory.path}/.dart_tool/package_config.json');
  final rows =
      (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
  final matches = rows
      .cast<Map>()
      .where((row) => row['name'] == package)
      .toList();
  if (matches.length != 1) throw StateError('夹具所属包缺失或重复：$package');
  final root = config.uri.resolve(matches.single['rootUri'] as String);
  final file = File.fromUri(
    Uri.directory(root.toFilePath()).resolve('test/$path'),
  );
  if (!file.existsSync()) throw StateError('所属包夹具缺失：$package/$path');
  return file;
}
