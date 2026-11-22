// 验证CID显示缩写、标签规范及完整与部分选区复制。

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/identity_cid_display.dart';

void main() {
  const full = 'GZ018-CREGM-159197206-2026';
  const short = 'GZ018-CREGM-159197206';
  test(
    'display only hides the final CID year and normalizes system labels',
    () {
      expect(formatIdentityCidText(full), short);
      expect(identityCidUiText('CID编号'), identityCidLabel);
      expect(identityCidReviewText('CID编号', full), short);
      expect(identityCidReviewText('姓名', full), full);
      expect(full, 'GZ018-CREGM-159197206-2026');
      expect(formatIdentityCidText(short), short);
      expect(identityCidFieldText('remark', full), full);
      expect(identityCidFieldText('actor_cid_number', full), short);
      expect(identityCidFieldText('admins', '张三 / $full'), '张三 / $short');
      expect(
        formatIdentityCidText('CN001-NATP4-123456789-10000'),
        'CN001-NATP4-123456789',
      );
      for (final other in [
        '2026-11-22',
        'personal-account:0x1234',
        '0xabcdef',
        'GZ018-CREGM-159197206-20261234567',
      ]) {
        expect(formatIdentityCidText(other), other);
      }
      expect(
        identityCidUiText('公民CID号 / 居民CID号 / 机构CID号 / 身份ID / 公民号'),
        '身份CID号 / 身份CID号 / 身份CID号 / 身份CID号 / 身份CID号',
      );
    },
  );
  test(
    'selection copying restores full identifiers and preserves partial selection',
    () {
      expect(identityCidSelectionText(full, 0, short.length), full);
      expect(identityCidSelectionText(full, 0, 5), 'GZ018');
      final other = full.replaceFirst('2026', '2036');
      final original = '甲：$full；乙：$other';
      final display = '甲：$short；乙：$short';
      expect(identityCidSelectionText(original, 0, display.length), original);
      expect(
        identityCidSelectionText(original, 2 + short.length, display.length),
        '；乙：$other',
      );
    },
  );
}
