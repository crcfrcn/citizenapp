import 'dart:async';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;

void main() {
  late StreamController<CitizenSdkEvent> events;
  late f.Reader reader;
  late f.Store store;
  late ChainDataService service;
  late String owner;
  late CitizenBlockRef head;
  setUp(() {
    events = StreamController.broadcast(sync: true);
    reader = f.Reader();
    store = f.Store();
    owner = f.account(1);
    head = f.block(103);
    service = ChainDataService(
      reader: reader,
      store: store,
      getAccount: () async => owner,
      getGenesisHash: () async => f.hash(0),
      getFinalizedHead: () async => head,
      events: events.stream,
    );
  });
  tearDown(() async {
    await service.close();
    await events.close();
  });
  test('同一最终块合并读取，只有业务数据改变才写库或通知', () async {
    var notifications = 0;
    service.addListener(() => notifications++);
    await service.start();
    final release = service.watchCitizen(f.cidA);
    addTearDown(release);
    await Future.wait([service.refresh(), service.refresh()]);
    expect(reader.calls.length, 1);
    expect(store.writes.length, 1);
    final before = notifications;
    head = f.block(104);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    expect(service.snapshot!.block.number, BigInt.from(104));
    expect(store.writes.length, 1);
    expect(notifications, before);
  });
  test('读取中连续最终块只追随最新块，跳过中间块', () async {
    await service.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.behavior = (a, b, c, d) => b.number == BigInt.from(104)
        ? pending.future
        : Future.value(f.snapshot(b, a, citizens: c, creators: d));
    head = f.block(104);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    events.add(
      CitizenSdkFinalizedBlockChanged(sequence: 2, finalized: f.block(105)),
    );
    head = f.block(106);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 3, finalized: head));
    pending.complete(f.snapshot(f.block(104), owner));
    await f.flush();
    expect(reader.calls.map((e) => e.$2), [103, 104, 106]);
    expect(service.snapshot!.block.number, BigInt.from(106));
  });
  test('换账户立即撤下旧状态，迟到读取不能写回', () async {
    await service.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.behavior = (a, b, c, d) => a == f.account(1)
        ? pending.future
        : Future.value(f.snapshot(b, a, citizens: c, creators: d));
    head = f.block(104);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    owner = f.account(2);
    events.add(const CitizenSdkWalletChanged(sequence: 2));
    expect(service.snapshot, isNull);
    await f.flush();
    expect(service.snapshot!.accountId, owner); // 新账户不等待旧账户的请求。
    pending.complete(f.snapshot(head, f.account(1)));
    await f.flush();
    expect(service.snapshot!.accountId, owner);
    expect(store.writes.map((e) => e.accountId), [f.account(1), f.account(2)]);
  });
  test('读取失败保留成功状态并标记陈旧，重试恢复', () async {
    await service.start();
    reader.behavior = (_, __, ___, ____) =>
        Future.error(StateError('proof unavailable'));
    head = f.block(104);
    await expectLater(service.refresh(), throwsStateError);
    expect(service.snapshot!.block.number, BigInt.from(103));
    expect(service.isStale, isTrue);
    reader.behavior = null;
    await service.refresh();
    expect(service.isStale, isFalse);
    expect(service.snapshot!.block.number, BigInt.from(104));
  });
  test('后台暂停业务读取，恢复直接追到最新最终块', () async {
    await service.start();
    service.setForeground(false);
    head = f.block(110);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    expect(reader.calls.length, 1);
    service.setForeground(true);
    await f.flush();
    expect(reader.calls.map((e) => e.$2), [103, 110]);
  });
  test('恢复缓存仍需轻节点核验，不能把缓存当作新最终块', () async {
    store.cached = f.snapshot(f.block(86), owner);
    reader.behavior = (_, __, ___, ____) => Future.error(StateError('offline'));
    await expectLater(service.start(), throwsStateError);
    expect(service.snapshot!.block.number, BigInt.from(86));
    expect(service.isStale, isTrue);
  });
  test('按需关注可移除，下一块不再读取已离开的目标', () async {
    await service.start();
    final release = service.watchCitizen(f.cidB);
    await service.refresh();
    expect(service.snapshot!.citizens.containsKey(f.cidB), isTrue);
    release();
    head = f.block(104);
    await service.refresh();
    expect(service.snapshot!.citizens.containsKey(f.cidB), isFalse);
  });
  test('最终块跨过已付终期后，生效状态变化必须通知并持久化', () async {
    reader.behavior = (a, b, c, d) => Future.value(
      f.snapshot(b, a, paidUntil: 1104, citizens: c, creators: d),
    );
    await service.start();
    expect(service.snapshot!.memberActive(f.cidA), isTrue);
    head = f.block(104);
    await service.refresh();
    expect(service.snapshot!.memberActive(f.cidA), isFalse);
    expect(store.writes.length, 2);
  });
  test('关闭不等待未返回的SDK请求，迟到结果不写库或通知', () async {
    await service.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.behavior = (_, __, ___, ____) => pending.future;
    head = f.block(104);
    final refresh = service.refresh();
    final rejected = expectLater(refresh, throwsStateError);
    await f.flush();
    await service.close().timeout(const Duration(seconds: 1));
    await rejected;
    pending.complete(f.snapshot(head, owner));
    await f.flush();
    expect(store.writes.length, 1);
  });
}
