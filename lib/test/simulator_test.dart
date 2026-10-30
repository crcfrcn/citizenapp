import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';

import '../../account/test/identity/identity_binding_test.dart' as bindings;
import '../../system/test/security/system_protected_record_store_test.dart'
    as records;
import '../../account/test/identity/mls_device_registrar_test.dart'
    as registration;
import '../../account/test/identity/current_user_context_test.dart' as identity;
import '../../account/test/profile/user_profile_page_test.dart' as profile;
import '../../account/test/profile/profile_posts_tab_test.dart' as posts;
import '../../account/test/profile/follows_list_page_test.dart' as follows;
import '../../account/test/user/contact_book_page_test.dart' as contacts;
import '../../8964/test/square_home_page_test.dart' as square;
import '../../account/test/membership/membership_page_test.dart' as membership;
import '../../account/test/identity/square_session_selfheal_test.dart'
    as session;
import 'chat_tab_test.dart' as chat;

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
    'bindings': bindings.main,
    'records': records.main,
    'registration': registration.main,
    'identity': identity.main,
    'profile': profile.main,
    'posts': posts.main,
    'follows': follows.main,
    'contacts': contacts.main,
    'square': square.main,
    'membergate': membership.main,
    'session': session.main,
    'chat': chat.main,
  };
  if (!suites.containsKey(selected)) {
    throw ArgumentError('必须明确选择已登记的软件测试组');
  }
  group(selected, suites[selected]!);
}
