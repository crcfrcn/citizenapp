import 'dart:async';

import 'package:citizen_system/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile failure records the actual known error and version comparison',
    () {
      final lines = <String>[];
      runZoned(
        () => AppLog.profileLoadFailure(
          stage: 'cache_version',
          error: StateError('旧资料不能覆盖较新的本地版本'),
          stackTrace: StackTrace.fromString(
            '#0 CitizenProfileCache._commit (package:citizen_user/profile/citizen_profile_cache.dart:276:11)',
          ),
          localVersion: 1793472841955,
          remoteVersion: 0,
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      expect(
        lines.first,
        contains('type=StateError reason=profile_version_regression'),
      );
      expect(
        lines.first,
        contains('local_version=1793472841955 remote_version=0'),
      );
      expect(
        lines.last,
        contains(
          'package:citizen_user/profile/citizen_profile_cache.dart:276:11',
        ),
      );
    },
  );

  test('unknown error text and custom stack data never enter profile logs', () {
    final lines = <String>[];
    runZoned(
      () => AppLog.profileLoadFailure(
        stage: 'secret-stage',
        error: StateError('secret-token and private profile body'),
        stackTrace: StackTrace.fromString(
          'https://example.test/?token=secret-token',
        ),
        localVersion: -1,
      ),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines, hasLength(1));
    expect(lines.single, contains('stage=other type=StateError reason=other'));
    expect(lines.single, contains('local_version=none remote_version=none'));
    expect(lines.join(), isNot(contains('secret')));
    expect(lines.join(), isNot(contains('private')));
  });
}
