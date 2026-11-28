// 保留显式设备测试选组入口。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';
import '../../user/test/context_test.dart' as bindings show suite82;
import '../../system/test/security/storage_test.dart' as records;
import '../../user/test/identity/session_test.dart' as registration show suite83;
import '../../user/test/context_test.dart' as identity show suite78;
import '../../user/test/profile/page_test.dart' as profile show suite109;
import '../../user/test/profile/list_test.dart' as posts show suite107;
import '../../user/test/profile/list_test.dart' as follows show suite99;
import '../../user/test/contacts/page_test.dart' as contacts show main;
import '../../8964/test/feed/page_test.dart' as square;
import '../../user/test/membership/page_test.dart' as membership show main;
import '../../user/test/identity/session_test.dart' as session show suite93;
import 'chat_test.dart' as chat;

// 验证未明确选择设备测试时不安装集成测试binding。

// 复用现有软件回归夹具；真实硬件认证和钥保护由用户真机验收。
void main() {
  const selected = String.fromEnvironment('SIMULATOR_SUITE');
  if (selected.isEmpty) {
    test('未显式选择设备组时不安装设备集成binding', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(
        WidgetsBinding.instance,
        isNot(isA<IntegrationTestWidgetsFlutterBinding>()),
      );
    });
    return;
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  final suites = <String, void Function()>{
    'bindings': bindings.suite82,
    'records': records.recordTests,
    'registration': registration.suite83,
    'identity': identity.suite78,
    'profile': profile.suite109,
    'posts': posts.suite107,
    'follows': follows.suite99,
    'contacts': contacts.main,
    'square': square.main,
    'membergate': membership.main,
    'session': session.suite93,
    'chat': chat.main,
  };
  if (!suites.containsKey(selected)) {
    throw ArgumentError('必须明确选择已登记的软件测试组');
  }
  group(selected, suites[selected]!);
}
