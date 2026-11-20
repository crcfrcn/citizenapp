import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:chat/call/flutter_call_peer.dart';
import 'package:chat/call/call_peer.dart';

void main() {
  test('flutter_webrtc 连接状态完整映射到 公民聊天', () {
    expect(
      callPeerStateFromRtc(
        RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      ),
      CallPeerState.connected,
    );
    expect(
      callPeerStateFromRtc(RTCPeerConnectionState.RTCPeerConnectionStateFailed),
      CallPeerState.failed,
    );
    expect(
      callPeerStateFromRtc(
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
      ),
      CallPeerState.disconnected,
    );
  });
}
