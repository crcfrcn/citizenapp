// 验证资料卡缩写显示CID，同时保留完整身份值和头像种子。

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/profile/profile_header_card.dart';
import 'package:citizen_user/profile/profile_avatar.dart';

void main() {
  testWidgets(
    'profile renders a short identity CID without changing the identity or avatar seed',
    (tester) async {
      const full = 'CN001-CTZN4-123456789-2026';
      final image = MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderCard(
              cidNumber: full,
              profile: null,
              actions: const SizedBox.shrink(),
              avatarImage: image,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('身份CID号：CN001-CTZN4-123456789'), findsOneWidget);
      expect(find.textContaining(full), findsNothing);
      expect(
        tester
            .widget<ProfileHeaderCard>(find.byType(ProfileHeaderCard))
            .cidNumber,
        full,
      );
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).seed,
        full,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
