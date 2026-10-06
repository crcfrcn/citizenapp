import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'security/identity_binding_test.dart' as bindings;
import 'security/system_protected_record_store_test.dart' as records;
import '8964/mls_device_registrar_test.dart' as registration;
import 'my/myid/current_user_context_test.dart' as identity;
import '8964/profile/user_profile_page_test.dart' as profile;
import '8964/profile/profile_posts_tab_test.dart' as posts;
import '8964/profile/follows_list_page_test.dart' as follows;
import 'user/contact_book_page_test.dart' as contacts;
import '8964/square_home_page_test.dart' as square;
import 'my/membership/membership_page_test.dart' as membership;
import '8964/square_session_selfheal_test.dart' as session;
import 'chat/chat_tab_test.dart' as chat;

// 复用现有软件回归夹具；真实硬件认证和钥保护由用户真机验收。
void main() {
  const selected = String.fromEnvironment('SIMULATOR_SUITE');
  if (selected.isEmpty) {
    test('设备侧测试须显式选择虚拟设备和测试组', () {}, skip: '仅由虚拟设备测试调用');
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
    'membership': membership.main,
    'session': session.main,
    'chat': chat.main,
  };
  if (!suites.containsKey(selected)) {
    throw ArgumentError('必须明确选择已登记的软件测试组');
  }
  group(selected, suites[selected]!);
}
