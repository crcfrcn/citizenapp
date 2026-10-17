import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// 仅处理App自有私有路径；平台校验失败不得继续开库或记录写入。
abstract final class SystemProtectedStorage {
  static const channel = MethodChannel('citizenapp/system_protected_data');
  static Future<String> recordsDirectory() async {
    final path = await channel.invokeMethod<String>('prepareRecords');
    if (path == null || path.isEmpty || !path.startsWith('/')) {
      throw StateError('系统保护记录目录不可用');
    }
    if (await Directory(path).resolveSymbolicLinks() != path) {
      throw StateError('系统保护记录路径不可用');
    }
    return path;
  }

  static Future<void> protectUserDatabase(String directory) => channel
      .invokeMethod<void>('protectUserDatabase', {'directory': directory});

  /// 只删旧App非钱包材料；平台实现不得生成、读取或解封旧秘密。
  static Future<void> eraseObsoleteDataMaterial() =>
      channel.invokeMethod<void>('eraseObsoleteDataMaterial');
}

/// 系统保护原子记录；同isolate排队，生产提交在原生文件锁内比较完整快照。
/// Dart在Unix上的文件锁为进程级，不能单独承担跨isolate的CAS。
final class SystemProtectedRecordStore {
  SystemProtectedRecordStore(this.name, {Future<String> Function()? directory})
    : _directory = directory;
  static final identity = SystemProtectedRecordStore('identity.json');
  static final lock = SystemProtectedRecordStore('lock.json');
  static final registration = SystemProtectedRecordStore('registration.json');
  final String name;
  final Future<String> Function()? _directory;
  static final Map<String, Future<void>> _tails = {};
  bool _closed = false;
  int _generation = 0;
  void _require(int generation) {
    if (_closed || generation != _generation) throw StateError('保护记录已关闭');
  }

  Future<String> _path() async {
    if (name != 'identity.json' &&
        name != 'lock.json' &&
        name != 'registration.json') {
      throw ArgumentError('记录名称无效');
    }
    if (_directory != null &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('记录目录替身仅限测试');
    }
    final root =
        await (_directory?.call() ?? SystemProtectedStorage.recordsDirectory());
    if (await Directory(root).resolveSymbolicLinks() != root) {
      throw StateError('记录根路径无效');
    }
    return '$root/$name';
  }

  Future<T> _transaction<T>(
    Future<T> Function(Map<String, String>, File, int, String?) action,
  ) async {
    final generation = _generation;
    _require(generation);
    final path = await _path();
    _require(generation);
    final previous = _tails[path] ?? Future<void>.value();
    final done = Completer<void>();
    _tails[path] = done.future;
    try {
      await previous;
      _require(generation);
      final file = File(path);
      final lockFile = File('$path.lock');
      for (final target in [file, lockFile, File('$path.part')]) {
        final type = await FileSystemEntity.type(
          target.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.file) {
          throw StateError('保护记录拒绝非普通文件');
        }
      }
      final handle = await lockFile.open(mode: FileMode.append);
      try {
        await handle.lock(FileLock.blockingExclusive);
        _require(generation);
        // 未提交临时文件没有读取资格；禁止以残片替换完整记录。
        final values = <String, String>{};
        String? expected;
        if (await file.exists()) {
          if (await file.length() > 262144) {
            throw const FormatException('记录体积超限');
          }
          expected = await file.readAsString();
          final decoded = jsonDecode(expected);
          if (decoded is! Map<String, dynamic> ||
              decoded.values.any((v) => v is! String)) {
            throw const FormatException('保护记录格式损坏');
          }
          values.addAll(decoded.cast<String, String>());
        }
        final result = await action(values, file, generation, expected);
        _require(generation);
        return result;
      } finally {
        await handle.unlock();
        await handle.close();
      }
    } finally {
      done.complete();
      if (identical(_tails[path], done.future)) _tails.remove(path);
    }
  }

  Future<bool> _commit(
    Map<String, String> values,
    File file,
    int generation,
    String? expected,
  ) async {
    final encoded = utf8.encode(jsonEncode(values));
    if (encoded.length > 262144) throw const FormatException('记录体积超限');
    if (_directory == null) {
      _require(generation);
      final committed = await SystemProtectedStorage.channel.invokeMethod<bool>(
        'compareRecords',
        {'name': name, 'expected': expected, 'next': utf8.decode(encoded)},
      );
      _require(generation);
      if (committed == null) throw StateError('原生记录提交未确认');
      return committed;
    }
    final part = File('${file.path}.part');
    _require(generation);
    await part.writeAsBytes(encoded, flush: true);
    _require(generation);
    await part.rename(file.path);
    _require(generation);
    if (await file.readAsString() != utf8.decode(encoded)) {
      throw StateError('保护记录回读失败');
    }
    return true;
  }

  Future<String?> read(String key) =>
      _transaction((values, _, _, _) async => values[key]);
  Future<Map<String, String>> readAll() => _transaction(
    (values, _, _, _) async => Map<String, String>.unmodifiable(values),
  );
  Future<void> write(String key, String value) =>
      _transaction((values, file, generation, expectedRecord) async {
        values[key] = value;
        if (!await _commit(values, file, generation, expectedRecord)) {
          throw StateError('保护记录并发变化，请重试');
        }
      });
  Future<void> delete(String key) =>
      _transaction((values, file, generation, expectedRecord) async {
        values.remove(key);
        if (!await _commit(values, file, generation, expectedRecord)) {
          throw StateError('保护记录并发变化，请重试');
        }
      });
  Future<bool> compareAndSet(
    String key, {
    required String? expected,
    String? next,
  }) => _transaction((values, file, generation, expectedRecord) async {
    if (values[key] != expected) return false;
    if (next == null) {
      values.remove(key);
    } else {
      values[key] = next;
    }
    return _commit(values, file, generation, expectedRecord);
  });

  /// 普通清除保持记录服务可用；终态关闭会拒绝所有正在等待的旧操作。
  Future<void> deleteAll() =>
      _transaction((values, file, generation, expectedRecord) async {
        values.clear();
        if (!await _commit(values, file, generation, expectedRecord)) {
          throw StateError('保护记录并发变化，请重试');
        }
      });
  void close() {
    _closed = true;
    _generation++;
  }
}
