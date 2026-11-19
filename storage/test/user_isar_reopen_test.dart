// 仅本测试固定旧schema元数据，使用Isar提供的schema构造API。
// ignore_for_file: invalid_use_of_protected_member
import 'dart:convert';
import 'package:citizen_storage/isar_core_bootstrap.dart';
import 'package:isar_community/isar.dart';

import 'package:citizen_storage/user_isar.dart' as app_store;
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  useIsolatedIsar();

  test('无事件版本的旧游标物理库重开后默认0且原进度完整保留', () async {
    final definition =
        jsonDecode(jsonEncode(app_store.WalletCursorSchema.toJson()))
            as Map<String, dynamic>;
    definition['id'] = app_store.WalletCursorSchema.id.toString();
    definition['idName'] = app_store.WalletCursorSchema.idName;
    definition['version'] = app_store.WalletCursorSchema.version;
    for (final index in definition['indexes'] as List) {
      index['id'] = app_store.WalletCursorSchema.indexes[index['name']]!.id
          .toString();
    }
    final properties = (definition['properties'] as List)
        .where((dynamic p) => p['name'] != 'event_version')
        .toList();
    for (var i = 0; i < properties.length; i++) {
      properties[i]['id'] = i;
    }
    definition['properties'] = properties;
    final legacy = _oldProposalSchema<app_store.WalletCursor>(definition);
    final old = Isar.openSync(
      [legacy],
      name: 'citizenapp_user',
      directory: await IsarCoreBootstrap.resolveDirectory(),
    );
    await old.writeTxn(() async {
      await old.collection<app_store.WalletCursor>().importJson([
        {
          'id': 1,
          'account_id': '0x${'aa' * 32}',
          'created_at': 4000,
          'genesis_hash': 'genesis',
          'start_block': 4,
          'cursor_block': 99,
        },
      ]);
    });
    await old.close();
    final reopened = await app_store.UserIsar.instance.db();
    final saved = await reopened.collection<app_store.WalletCursor>().get(1);
    expect(saved!.eventVersion, 0);
    expect(saved.startBlock, 4);
    expect(saved.cursorBlock, 99);
    expect(saved.createdAt, 4000);
    expect(saved.genesisHash, 'genesis');
  });

  test('原名 UserIsar 保存目录状态后连续关闭重开，不触发旧版本键冲突', () async {
    final first = await app_store.UserIsar.instance.db();
    expect(first.name, 'citizenapp_user');
    await first.writeTxn(() async {
      await first.versions.putByDataKind(
        app_store.Version()
          ..dataKind = 'public_institution'
          ..globalVersion = 'synthetic-snapshot'
          ..provinceData = '{"ZS":"synthetic-shard"}',
      );
    });
    await first.close();

    for (var round = 0; round < 3; round++) {
      final reopened = await app_store.UserIsar.instance.db();
      expect(reopened.name, 'citizenapp_user');
      final saved = await reopened.versions.getByDataKind('public_institution');
      expect(saved?.globalVersion, 'synthetic-snapshot');
      expect(saved?.provinceData, '{"ZS":"synthetic-shard"}');
      await reopened.close();
    }
  });

  test('原余额正文中的两类快照独立更新和删除', () async {
    final store = app_store.UserIsar.instance;
    final id = '0x${'11' * 32}';
    const wss = 'wss://clearing.example';
    final chain = {
      'block_hash': '0x${'22' * 32}',
      'block_number': '10',
      'free_fen': '100',
      'reserved_fen': '7',
    };
    await store.writeTxn((isar) async {
      await isar.balances.putByAccountId(
        app_store.Balance()
          ..accountId = id
          ..bodyData = jsonEncode({
            'chain': chain,
            'clearing_balances': {wss: '10'},
          }),
      );
    });
    final next = {...chain, 'free_fen': '102'};
    await Future.wait<void>([
      store.writeBalance(id, (old) {
        expect(jsonDecode(old!), {'chain': chain});
        return jsonEncode({'chain': next});
      }),
      store.writeClearingBalance(id, wss, BigInt.from(15)),
    ]);
    final row = await store.read(
      (isar) => isar.balances.getByAccountId(id),
    );
    expect(jsonDecode(row!.bodyData), {
      'chain': next,
      'clearing_balances': {wss: '15'},
    });

    await store.writeBalance(id, (_) => null);
    expect(await store.readBalance(id), isNull);
    expect(await store.readClearingBalance(id, wss), BigInt.from(15));
    await store.removeClearingBalances(id);
    expect(
      await store.read((isar) => isar.balances.getByAccountId(id)),
      isNull,
    );
  });

  test('真实旧schema的四类提案历史迁移后完整保留且可重复打开', () async {
    final store = app_store.UserIsar.instance;
    // 固定自提案ID扩宽前的生成定义：原集合ID、字段和原索引，不从新schema裁剪。
    final definitions = (jsonDecode(r'''[
  {
    "model": "Summary",
    "name": "summary",
    "id": "7630605597744450915",
    "version": "3.3.2",
    "idName": "id",
    "properties": [{"id":0,"name":"data","type":"String"},{"id":1,"name":"proposal_id","type":"Long"}],
    "indexes": [{"id":"-1697214643687574663","name":"proposal_id","unique":true,"replace":true,"properties":[{"name":"proposal_id","type":"Value","caseSensitive":false}]}]
  },
  {
    "model": "ProposalList",
    "name": "list",
    "id": "-5742266293228518431",
    "version": "3.3.2",
    "idName": "id",
    "properties": [{"id":0,"name":"cid_number","type":"String"},{"id":1,"name":"proposal_ids","type":"LongList"},{"id":2,"name":"synced_at","type":"Long"}],
    "indexes": [{"id":"5073804840546792610","name":"cid_number","unique":true,"replace":true,"properties":[{"name":"cid_number","type":"Hash","caseSensitive":true}]}]
  },
  {
    "model": "Proposal",
    "name": "proposal",
    "id": "7845892132956556269",
    "version": "3.3.2",
    "idName": "id",
    "properties": [{"id":0,"name":"data","type":"String"},{"id":1,"name":"kind","type":"String"},{"id":2,"name":"proposal_id","type":"Long"}],
    "indexes": [{"id":"-1114706425788016234","name":"kind_proposal_id","unique":true,"replace":true,"properties":[{"name":"kind","type":"Hash","caseSensitive":true},{"name":"proposal_id","type":"Value","caseSensitive":false}]}]
  },
  {
    "model": "Action",
    "name": "action",
    "id": "-2948318935682215514",
    "version": "3.3.2",
    "idName": "id",
    "properties": [{"id":0,"name":"account_id","type":"String"},{"id":1,"name":"created_at","type":"Long"},{"id":2,"name":"data","type":"String"},{"id":3,"name":"final_at","type":"Long"},{"id":4,"name":"kind","type":"String"},{"id":5,"name":"no_count","type":"Long"},{"id":6,"name":"proposal_id","type":"Long"},{"id":7,"name":"state","type":"String"},{"id":8,"name":"yes_count","type":"Long"}],
    "indexes": [{"id":"35444471039370691","name":"account_id_proposal_id","unique":true,"replace":true,"properties":[{"name":"account_id","type":"Hash","caseSensitive":true},{"name":"proposal_id","type":"Value","caseSensitive":false}]},{"id":"1484550194077596484","name":"kind","unique":false,"replace":false,"properties":[{"name":"kind","type":"Hash","caseSensitive":true}]},{"id":"7917036384617311412","name":"state","unique":false,"replace":false,"properties":[{"name":"state","type":"Hash","caseSensitive":true}]},{"id":"6296488693525790031","name":"created_at","unique":false,"replace":false,"properties":[{"name":"created_at","type":"Value","caseSensitive":false}]}]
  }
]''') as List).cast<Map<String, dynamic>>();
    final oldSchemas = <CollectionSchema<dynamic>>[
      _oldProposalSchema<app_store.Summary>(definitions[0]),
      _oldProposalSchema<app_store.ProposalList>(definitions[1]),
      _oldProposalSchema<app_store.Proposal>(definitions[2]),
      _oldProposalSchema<app_store.Action>(definitions[3]),
      app_store.VersionSchema,
      app_store.BalanceSchema,
    ];
    expect(oldSchemas.take(4).map((schema) => schema.name), ['summary', 'list', 'proposal', 'action']);
    expect(oldSchemas[0].id, app_store.SummarySchema.id);
    expect(oldSchemas[1].id, app_store.ProposalListSchema.id);
    expect(oldSchemas[2].id, app_store.ProposalSchema.id);
    expect(oldSchemas[3].id, app_store.ActionSchema.id);
    for (final schema in oldSchemas.take(4)) {
      expect(schema.properties.keys.any((name) => name.contains('proposal_id_text')), false);
    }
    expect(oldSchemas[0].indexes['proposal_id']!.unique, true);
    expect(oldSchemas[2].indexes['kind_proposal_id']!.unique, true);
    expect(oldSchemas[3].indexes['account_id_proposal_id']!.unique, true);
    final accountA = '0x${'11' * 32}', accountB = '0x${'22' * 32}';
    final summaryBody = jsonEncode({
      'kind': 0, 'stage': 0, 'status': 3, 'title': '原提案',
      'subtitle': '原副标题', 'list_subtitle': '原列表', 'icon_kind': 'transfer', 'updated_at': 123,
    });
    final detailBody = jsonEncode({'updated_at': 456, 'status': 3, 'detail': {'remark': '原详情'}});
    final actionBody = jsonEncode({'remark': '原业务快照', 'amount_fen': '100'});
    // 先直接打开真正的旧schema，只用原始JSON导入，绝不调用新实体的序列化回调。
    final old = Isar.openSync(oldSchemas, name: 'citizenapp_user',
      directory: await IsarCoreBootstrap.resolveDirectory(), relaxedDurability: false);
    await old.writeTxn(() async {
      await old.collection<app_store.Summary>().importJson([
        {'id': 101, 'proposal_id': 0, 'data': summaryBody},
        {'id': 102, 'proposal_id': 7, 'data': summaryBody},
      ]);
      await old.collection<app_store.ProposalList>().importJson([
        {'id': 201, 'cid_number': 'LN001-NRC0G-944805165-2026', 'proposal_ids': [0, 7], 'synced_at': 123},
        {'id': 202, 'cid_number': '另一机构', 'proposal_ids': [7, 42], 'synced_at': 456},
      ]);
      await old.collection<app_store.Proposal>().importJson([
        {'id': 301, 'kind': 'transfer', 'proposal_id': 7, 'data': detailBody},
        {'id': 302, 'kind': 'upgrade', 'proposal_id': 7, 'data': detailBody},
        {'id': 303, 'kind': 'transfer', 'proposal_id': 0, 'data': detailBody},
      ]);
      await old.collection<app_store.Action>().importJson([
        {'id': 401, 'account_id': accountA, 'proposal_id': 7, 'kind': 'transfer', 'state': 'executed',
          'yes_count': 13, 'no_count': 2, 'created_at': 1000, 'final_at': 1010, 'data': actionBody},
        {'id': 402, 'account_id': accountB, 'proposal_id': 7, 'kind': 'create', 'state': 'voting',
          'yes_count': 1, 'no_count': 0, 'created_at': 2000, 'final_at': null, 'data': actionBody},
      ]);
      await old.versions.put(app_store.Version()..rowId = 501..dataKind = 'public_institution'
        ..globalVersion = 'unrelated-original'..provinceData = '{}');
      await old.balances.put(app_store.Balance()..rowId = 601..accountId = accountA..bodyData = '{"chain":{"free_fen":"100"}}');
    });
    await old.close();
    for (var round = 0; round < 3; round++) {
      final reopened = await store.db();
      final summaries = await reopened.collection<app_store.Summary>().where().findAll();
      expect(summaries.map((row) => row.rowId).toSet(), {101, 102});
      expect(summaries.map((row) => row.proposalId).toSet(), {BigInt.zero, BigInt.from(7)});
      expect(summaries.every((row) => row.bodyData == summaryBody), true);
      final lists = await reopened.collection<app_store.ProposalList>().where().findAll();
      expect(lists.map((row) => row.rowId).toSet(), {201, 202});
      final firstList = lists.singleWhere((row) => row.rowId == 201);
      expect(firstList.cidNumber, 'LN001-NRC0G-944805165-2026');
      expect(firstList.proposalIds, [BigInt.zero, BigInt.from(7)]);
      expect(firstList.syncedAt, 123);
      expect(lists.singleWhere((row) => row.rowId == 202).proposalIds, [BigInt.from(7), BigInt.from(42)]);
      final details = await reopened.collection<app_store.Proposal>().where().findAll();
      expect(details.map((row) => row.rowId).toSet(), {301, 302, 303});
      expect(details.where((row) => row.proposalId == BigInt.from(7)).map((row) => row.proposalKind).toSet(), {'transfer', 'upgrade'});
      expect(details.singleWhere((row) => row.rowId == 303).proposalId, BigInt.zero);
      expect(details.every((row) => row.bodyData == detailBody), true);
      final actions = await reopened.collection<app_store.Action>().where().findAll();
      expect(actions.map((row) => row.rowId).toSet(), {401, 402});
      expect(actions.every((row) => row.proposalId == BigInt.from(7) && row.snapshotData == actionBody), true);
      final actionA = actions.singleWhere((row) => row.accountId == accountA);
      expect((actionA.actionKind, actionA.proposalState, actionA.yesCount, actionA.noCount, actionA.createdAt, actionA.finalAt),
        ('transfer', 'executed', 13, 2, 1000, 1010));
      final actionB = actions.singleWhere((row) => row.accountId == accountB);
      expect((actionB.actionKind, actionB.proposalState, actionB.yesCount, actionB.noCount, actionB.createdAt, actionB.finalAt),
        ('create', 'voting', 1, 0, 2000, null));
      expect((await reopened.versions.get(501))!.globalVersion, 'unrelated-original');
      expect((await reopened.balances.get(601))!.bodyData, '{"chain":{"free_fen":"100"}}');
      await reopened.close();
    }
    final huge = (BigInt.one << 127) + BigInt.from(17);
    final upgraded = await store.db();
    await upgraded.writeTxn(() async {
      await upgraded.collection<app_store.Summary>().put(app_store.Summary()..proposalId = huge..bodyData = summaryBody);
      await upgraded.collection<app_store.Proposal>().put(app_store.Proposal()..proposalKind = 'transfer'..proposalId = huge..bodyData = detailBody);
      await upgraded.collection<app_store.Action>().put(app_store.Action()..accountId = accountA
        ..proposalId = huge..actionKind = 'transfer'..proposalState = 'voting'..yesCount = 0..noCount = 0
        ..createdAt = 3000..snapshotData = actionBody);
      final list = (await upgraded.collection<app_store.ProposalList>().get(201))!;
      list.proposalIds = [...list.proposalIds, huge];
      await upgraded.collection<app_store.ProposalList>().put(list);
    });
    await upgraded.close();
    final again = await store.db();
    expect(await again.collection<app_store.Summary>().count(), 3);
    expect(await again.collection<app_store.Proposal>().count(), 4);
    expect(await again.collection<app_store.Action>().count(), 3);
    expect((await again.collection<app_store.Summary>().where().findAll()).singleWhere((row) => row.proposalId == huge).bodyData, summaryBody);
    expect((await again.collection<app_store.Proposal>().where().findAll()).singleWhere((row) => row.proposalId == huge).bodyData, detailBody);
    expect((await again.collection<app_store.Action>().where().findAll()).singleWhere((row) => row.proposalId == huge).snapshotData, actionBody);
    expect((await again.collection<app_store.ProposalList>().get(201))!.proposalIds, [BigInt.zero, BigInt.from(7), huge]);
  });

}


// 旧schema只用于原始JSON导入；这些回调明确禁止误用当前实体去读写旧布局。
CollectionSchema<T> _oldProposalSchema<T>(Map<String, dynamic> definition) {
  return CollectionSchema<T>(
    id: int.parse(definition['id'] as String),
    name: definition['name'] as String,
    properties: {
      for (final property in definition['properties'] as List)
        property['name'] as String: PropertySchema(
          id: property['id'] as int, name: property['name'] as String,
          type: IsarType.values.singleWhere((type) => type.schemaName == property['type']),
        ),
    },
    indexes: {
      for (final index in definition['indexes'] as List)
        index['name'] as String: IndexSchema(
          id: int.parse(index['id'] as String), name: index['name'] as String,
          unique: index['unique'] as bool, replace: index['replace'] as bool,
          properties: [
            for (final property in index['properties'] as List)
              IndexPropertySchema.fromJson(Map<String, dynamic>.from(property as Map)),
          ],
        ),
    },
    estimateSize: (_, __, ___) => throw StateError('旧schema仅允许原始JSON导入'),
    serialize: (_, __, ___, ____) => throw StateError('旧schema仅允许原始JSON导入'),
    deserialize: (_, __, ___, ____) => throw StateError('旧schema仅允许原始JSON导入'),
    deserializeProp: (_, __, ___, ____) => throw StateError('旧schema仅允许原始JSON导入'),
    idName: definition['idName'] as String, links: {}, embeddedSchemas: {},
    getId: (_) => throw StateError('旧schema仅允许原始JSON导入'),
    getLinks: (_) => [], attach: (_, __, ___) {}, version: definition['version'] as String,
  );
}
