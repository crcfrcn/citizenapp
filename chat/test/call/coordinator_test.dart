// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:async';
import 'dart:math';

import 'package:chat/call/coordinator.dart';
import 'package:chat/call/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证唯一通话会话、并发来电、关闭代次及失败清理重试。

void _registerCoordinator() {
  test('终态清理失败的句柄保留至协调器dispose重试成功', () async {
    final peer = _Peer()..closeFailures = 1;
    final coordinator = ChatCallCoordinator(
      transport: _Transport(),
      readLocalUserId: () async => 'local',
      peerFactory: () => peer,
    );
    final handle = await coordinator.startOutgoing(
      localUserId: 'local',
      peerUserId: 'peer',
      title: 'peer',
      video: false,
    );
    await expectLater(handle.session.hangUp(), throwsStateError);
    await coordinator.dispose();
    expect(peer.closed, true);
    expect(peer.closes, 2);
  });
  test('并发offer等待同一身份后只建立一个会话，关闭后不再接收', () async {
    final identity = Completer<String>();
    final coordinator = ChatCallCoordinator(
      transport: _Transport(),
      readLocalUserId: () => identity.future,
      peerFactory: _Peer.new,
    );
    final incoming = <ChatCallHandle>[];
    final subscription = coordinator.incomingCalls.listen(incoming.add);
    Map<String, Object?> offer(String id) =>
        CallSignal.offer(connectionId: id, sdp: 'v=0').toWire();
    final first = coordinator.handleSignal(
      senderUserId: 'a',
      signalWire: offer('rtc.1.a'),
    );
    final second = coordinator.handleSignal(
      senderUserId: 'b',
      signalWire: offer('rtc.2.b'),
    );
    identity.complete('local');
    await Future.wait([first, second]);
    expect(incoming, hasLength(1));
    expect(coordinator.activeCall, same(incoming.single));
    await coordinator.dispose();
    await coordinator.handleSignal(
      senderUserId: 'a',
      signalWire: offer('rtc.3.c'),
    );
    expect(incoming, hasLength(1));
    await expectLater(
      coordinator.startOutgoing(
        localUserId: 'local',
        peerUserId: 'a',
        title: 'a',
        video: false,
      ),
      throwsStateError,
    );
    await subscription.cancel();
  });
  test('关闭期间身份晚回不分配Peer或交付来电', () async {
    final identity = Completer<String>();
    var peers = 0;
    final coordinator = ChatCallCoordinator(
      transport: _Transport(),
      readLocalUserId: () => identity.future,
      peerFactory: () {
        peers++;
        return _Peer();
      },
    );
    final signal = coordinator.handleSignal(
      senderUserId: 'a',
      signalWire: CallSignal.offer(
        connectionId: 'rtc.1.a',
        sdp: 'v=0',
      ).toWire(),
    );
    await coordinator.dispose();
    identity.complete('local');
    await signal;
    expect(peers, 0);
    expect(coordinator.activeCall, isNull);
  });
  test('账户级信令把视频 offer 路由为唯一入站通话', () async {
    final transport = _Transport();
    final coordinator = ChatCallCoordinator(
      transport: transport,
      readLocalUserId: () async => 'local',
      peerFactory: _Peer.new,
      random: Random(1),
    );
    final incoming = coordinator.incomingCalls.first;
    await coordinator.handleSignal(
      senderUserId: 'remote',
      signalWire: <String, Object?>{
        'signal_kind': 'offer',
        'connection_id': 'rtc.123.abc',
        'sdp': 'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96',
        'sdp_type': 'offer',
      },
    );
    final handle = await incoming;
    expect(handle.incoming, isTrue);
    expect(handle.session.mediaKind, CallMediaKind.video);
    expect(coordinator.activeCall, same(handle));
    await coordinator.dispose();
  });
}

class _Transport implements CallTransport {
  @override
  Future<CallIceConfiguration> readIceConfiguration() async =>
      CallIceConfiguration(const ['stun:stun.example.com']);
  @override
  Future<bool> sendSignal({
    required String recipientUserId,
    required CallSignal signal,
  }) async => true;
}

class _Peer implements CallPeer {
  int closes = 0, closeFailures = 0;
  bool closed = false;
  final _candidates = StreamController<CallIceCandidate>.broadcast();
  final _states = StreamController<CallPeerState>.broadcast();
  @override
  Stream<CallIceCandidate> get localCandidates => _candidates.stream;
  @override
  Stream<CallPeerState> get states => _states.stream;
  @override
  Future<void> open({
    required CallIceConfiguration configuration,
    required CallMediaKind mediaKind,
  }) async {}
  @override
  Future<CallSessionDescription> createOffer() async =>
      const CallSessionDescription(type: 'offer', sdp: 'v=0');
  @override
  Future<CallSessionDescription> createAnswer() async =>
      const CallSessionDescription(type: 'answer', sdp: 'v=0');
  @override
  Future<void> setRemoteDescription(CallSessionDescription description) async {}
  @override
  Future<void> addRemoteCandidate(CallIceCandidate candidate) async {}
  @override
  Future<void> restartIce() async {}
  @override
  Future<void> close() async {
    closes++;
    if (closeFailures-- > 0) throw StateError('synthetic peer close failure');
    closed = true;
    await _candidates.close();
    await _states.close();
  }
}

// 验证通话offer、answer、ICE及挂断顺序和超时收口。

void _registerDirect() {
  test('挂断不等待挂起的信令，资源关闭失败可重试', () async {
    final transport = _DirectTransport()..wait = Completer<bool>();
    final peer = _DirectPeer()..closeFailures = 1;
    final session = DirectCallSession.outgoing(
      connectionId: 'rtc.1.a',
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      transport: transport,
      peer: peer,
    );
    final starting = session.start();
    await Future<void>.delayed(Duration.zero);
    await expectLater(session.hangUp(), throwsStateError);
    expect(session.state.phase, DirectCallPhase.ended);
    await session.hangUp();
    expect(peer.closed, isTrue);
    expect(peer.closes, 2);
    transport.wait!.complete(true);
    await starting;
    expect(session.state.phase, DirectCallPhase.ended);
  });
  test('建立前的ICE等待也受超时约束，迟到结果不发送offer', () async {
    final transport = _DirectTransport()
      ..ice = Completer<CallIceConfiguration>();
    final peer = _DirectPeer();
    final session = DirectCallSession.outgoing(
      connectionId: 'rtc.1.a',
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      transport: transport,
      peer: peer,
      connectionTimeout: Duration.zero,
    );
    final starting = session.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(session.state.phase, DirectCallPhase.failed);
    expect(peer.closed, isTrue);
    transport.ice!.complete(
      CallIceConfiguration(const ['stun:stun.example.com']),
    );
    await starting;
    expect(transport.sent, isEmpty);
  });
  test('私聊通话按 offer answer ICE 和 hangup 收口', () async {
    final transport = _DirectTransport();
    final peer = _DirectPeer();
    final session = DirectCallSession.outgoing(
      connectionId: 'rtc.123.abc',
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      transport: transport,
      peer: peer,
    );

    await session.start();
    expect(transport.sent.first.kind, CallSignalKind.offer);
    await session.receive(
      CallSignal.answer(
        connectionId: session.connectionId,
        sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
      ),
    );
    peer.emitState(CallPeerState.connected);
    await Future<void>.delayed(Duration.zero);
    expect(session.state.phase, DirectCallPhase.connected);

    await session.hangUp();
    expect(session.state.phase, DirectCallPhase.ended);
    expect(transport.sent.last.kind, CallSignalKind.hangup);
    expect(peer.closed, isTrue);
  });

  test('入站 ICE 在接听设置远端 SDP 后再写入 Peer', () async {
    final transport = _DirectTransport();
    final peer = _DirectPeer();
    final offer = CallSignal.offer(
      connectionId: 'rtc.456.def',
      sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
    );
    final session = DirectCallSession.incoming(
      connectionId: offer.connectionId,
      localUserId: 'local',
      remoteUserId: 'remote',
      mediaKind: CallMediaKind.voice,
      offer: offer,
      transport: transport,
      peer: peer,
    );
    await session.receive(
      CallSignal.ice(
        connectionId: offer.connectionId,
        candidate: 'candidate:1 1 UDP 1 127.0.0.1 9 typ host',
      ),
    );
    expect(peer.remoteCandidates, isEmpty);
    await session.accept();
    expect(peer.remoteCandidates, hasLength(1));
    expect(transport.sent.first.kind, CallSignalKind.answer);
    await session.hangUp();
  });
}

class _DirectTransport implements CallTransport {
  Completer<bool>? wait;
  Completer<CallIceConfiguration>? ice;
  final List<CallSignal> sent = <CallSignal>[];

  @override
  Future<CallIceConfiguration> readIceConfiguration() async =>
      await ice?.future ??
      CallIceConfiguration(const ['stun:stun.example.com']);

  @override
  Future<bool> sendSignal({
    required String recipientUserId,
    required CallSignal signal,
  }) async {
    sent.add(signal);
    return await wait?.future ?? true;
  }
}

class _DirectPeer implements CallPeer {
  final StreamController<CallIceCandidate> _candidates =
      StreamController<CallIceCandidate>.broadcast();
  final StreamController<CallPeerState> _states =
      StreamController<CallPeerState>.broadcast();
  final List<CallIceCandidate> remoteCandidates = <CallIceCandidate>[];
  bool closed = false;
  int closes = 0, closeFailures = 0;

  @override
  Stream<CallIceCandidate> get localCandidates => _candidates.stream;
  @override
  Stream<CallPeerState> get states => _states.stream;
  void emitState(CallPeerState value) => _states.add(value);

  @override
  Future<void> open({
    required CallIceConfiguration configuration,
    required CallMediaKind mediaKind,
  }) async {}
  @override
  Future<CallSessionDescription> createOffer() async =>
      const CallSessionDescription(
        type: 'offer',
        sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
      );
  @override
  Future<CallSessionDescription> createAnswer() async =>
      const CallSessionDescription(
        type: 'answer',
        sdp: 'v=0\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111',
      );
  @override
  Future<void> setRemoteDescription(CallSessionDescription description) async {}
  @override
  Future<void> addRemoteCandidate(CallIceCandidate candidate) async =>
      remoteCandidates.add(candidate);
  @override
  Future<void> restartIce() async {}
  @override
  Future<void> close() async {
    closes++;
    if (closeFailures-- > 0) throw StateError('synthetic close failure');
    closed = true;
    await _candidates.close();
    await _states.close();
  }
}

void main() {
  group("call/coordinator_test", _registerCoordinator);
  group("call/direct_test", _registerDirect);
}
