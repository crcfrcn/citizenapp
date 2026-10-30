import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/fixture.dart';

void main() {
  test('包配置相对/绝对URI及不同启动目录定位同一所属夹具', () {
    final work = Directory.systemTemp.createTempSync('citizen-fixture-');
    addTearDown(() => work.deleteSync(recursive: true));
    Directory('${work.path}/.dart_tool').createSync();
    final member = Directory('${work.path}/owner with space')..createSync();
    Directory('${member.path}/test').createSync();
    final expected = File('${member.path}/test/vector.json')
      ..writeAsStringSync('{}');
    final config = File('${work.path}/.dart_tool/package_config.json');
    for (final root in ['../owner%20with%20space', member.uri.toString()]) {
      config.writeAsStringSync(
        jsonEncode({
          'packages': [
            {'name': 'owner', 'rootUri': root},
          ],
        }),
      );
      for (final from in [work, member]) {
        expect(
          fixtureFile('owner', 'vector.json', from: from).path,
          expected.path,
        );
      }
      expect(
        () => fixtureFile('missing', 'vector.json', from: work),
        throwsStateError,
      );
      expect(
        () => fixtureFile('owner', 'missing.json', from: work),
        throwsStateError,
      );
    }
    for (final path in [
      '',
      '../vector.json',
      '/vector.json',
      'a/../vector.json',
    ]) {
      expect(() => fixtureFile('owner', path, from: work), throwsArgumentError);
    }
    config.writeAsStringSync(
      jsonEncode({
        'packages': [
          {'name': 'owner'},
          {'name': 'owner'},
        ],
      }),
    );
    expect(
      () => fixtureFile('owner', 'vector.json', from: work),
      throwsStateError,
    );
  });
}
