// 验证资料和提案日志只包含闭集结果、版本及固定失败阶段。

import 'dart:async';

import 'package:citizen_system/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('提案详情固定失败阶段在正式日志可用，不泄露异常正文或身份', () async {
    final lines = <String>[];
    runZoned(
      () {
        for (final stage in [
          'proposal_ready',
          'proposal_snapshot',
          'proposal_threshold',
          'proposal_status',
          'proposal_tally',
          'proposal_roles',
          'institution_roles',
        ]) {
          AppLog.proposalFailure(
            stage: stage,
            error: StateError('synthetic-body-must-not-appear'),
          );
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines, hasLength(7));
    expect(lines.every((line) => line.contains('code=state')), isTrue);
    expect(lines.join(), isNot(contains('synthetic-body')));
    expect(lines.join(), isNot(contains('stage=other')));
  });
  test('profile receive reports a closed result and numeric versions only', () {
    final lines = <String>[];
    runZoned(
      () {
        AppLog.profileLoadResult(
          state: 'remoteMissing',
          localVersion: 200,
          remoteVersion: 0,
        );
        AppLog.profileLoadResult(
          state: 'private-body-secret',
          localVersion: -1,
          remoteVersion: -1,
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(
      lines.first,
      '[CitizenProfileRead] state=remoteMissing local_version=200 remote_version=0',
    );
    expect(
      lines.last,
      '[CitizenProfileRead] state=other local_version=none remote_version=none',
    );
    expect(lines.join(), isNot(contains('private')));
  });

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
