import 'package:chat/transport/chat_connection.dart';
import 'package:citizen_network/protocol/chat_frame.pb.dart';
import 'package:citizen_user/square_api_client.dart';
export 'package:citizen_user/square_api_client.dart' show SquareResourceLease;

/// 传输回归的合成资源许可，不参与生产授权。
abstract interface class ChatResourceFixture {
  Future<SquareResourceLease> reserve(
    String action, {
    List<int> frame = const [],
    int bytes = 0,
  });
}

class ChatAccessFixture extends ChatAccess {
  ChatAccessFixture({
    required super.realtimeUrl,
    required super.accessToken,
    required super.expiresAtMillis,
    this.resources,
  });
  final ChatResourceFixture? resources;

  @override
  Future<SquareResourceLease?> reserveResources(
    String action, {
    List<int> frame = const [],
    int bytes = 0,
  }) async => resources?.reserve(action, frame: frame, bytes: bytes);

  @override
  void finishResources(
    SquareResourceLease? lease, {
    ResourceUsage? receipt,
    Map<String, String>? headers,
    bool accepted = true,
    String? errorCode,
  }) => lease?.finish(
    receipt: receipt,
    headers: headers,
    accepted: accepted,
    uncertain:
        !accepted &&
        (errorCode == 'storage_unavailable' || errorCode == 'server_failure'),
  );
}
