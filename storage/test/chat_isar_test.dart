import 'package:isar_community/isar.dart';
import 'dart:io';

import 'package:citizen_storage/chat_isar.dart';
import 'package:citizen_storage/isar_core_bootstrap.dart';
import 'package:citizen_storage/social_isar.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  useIsolatedIsar();

  test('聊天库真实重开后保留自己的数据和物理文件名', () async {
    final first = await ChatIsar.instance.db();
    await ChatIsar.instance.writeTxn((isar) async {
      await isar.chatBindingFenceEntitys.put(
        ChatBindingFenceEntity()
          ..ownerUserId = 'synthetic-owner'
          ..generation = 7
          ..fenceState = 'active',
      );
    });
    await first.close();
    final reopened = await ChatIsar.instance.db();
    expect(identical(first, reopened), isFalse);
    final records = await ChatIsar.instance.read(
      (isar) => isar.chatBindingFenceEntitys.where().findAll(),
    );
    expect(records.single.ownerUserId, 'synthetic-owner');
    expect(records.single.generation, 7);
    expect(
      File(
        '${IsarCoreBootstrap.debugTestDirectoryOverride}/chat.isar',
      ).existsSync(),
      isTrue,
    );
  });

  test('关闭和删除聊天库不会关闭或删除用户库、广场库', () async {
    final user = await UserIsar.instance.db();
    final social = await SocialIsar.instance.db();
    final chat = await ChatIsar.instance.db();
    await UserIsar.instance.writeOpenChatOnLaunch(true);
    expect({user.name, social.name, chat.name}.length, 3);
    await ChatIsar.instance.closeAndDeleteFromDisk();
    expect(user.isOpen, isTrue);
    expect(social.isOpen, isTrue);
    expect(await UserIsar.instance.readOpenChatOnLaunch(), isTrue);
    await SocialIsar.instance.read((isar) async => isar.isOpen);
    final root = IsarCoreBootstrap.debugTestDirectoryOverride;
    expect(File('$root/chat.isar').existsSync(), isFalse);
    expect(File('$root/${user.name}.isar').existsSync(), isTrue);
    expect(File('$root/${social.name}.isar').existsSync(), isTrue);
    await expectLater(ChatIsar.instance.db(), throwsStateError);
  });
}
