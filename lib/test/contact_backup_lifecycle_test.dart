import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizenapp/main.dart' show AppShell;
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_system/notifications/app_push_service.dart';

class _BackupContacts implements UserContactService {
  int flushes = 0;
  @override
  Future<void> flushPending() async {
    flushes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected contact operation');
}

void main() {
  testWidgets('网络恢复只触发待发补传，应用壳销毁后取消网络监听', (tester) async {
    const name = 'test/contact-backup-network';
    var cancelled = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(name),
      (call) async {
        if (call.method == 'cancel') cancelled = true;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(name),
        null,
      ),
    );
    final contacts = _BackupContacts();
    final push = AppPushService(networkChannel: const EventChannel(name));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserContactService>.value(value: contacts),
          Provider<AppPushService>.value(value: push),
        ],
        child: MaterialApp(
          home: AppShell(
            openedPushData: const Stream<Map<String, dynamic>>.empty(),
            tabBuilder: (index, _) => Center(child: Text('page:$index')),
          ),
        ),
      ),
    );
    await tester.pump();
    final initial = contacts.flushes;
    expect(initial, 1);
    void emit(bool value) => tester.binding.channelBuffers.push(
      name,
      const StandardMethodCodec().encodeSuccessEnvelope(value),
      (_) {},
    );
    emit(false);
    await tester.pump();
    expect(contacts.flushes, initial);
    emit(true);
    await tester.pump();
    expect(contacts.flushes, initial + 1);
    emit(true);
    await tester.pump();
    expect(contacts.flushes, initial + 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(cancelled, isTrue);
  });
}
