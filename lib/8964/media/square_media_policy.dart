import 'package:citizenapp/network/square_api_client.dart';

/// 公民广场手机端媒体成品规则。
///
/// 本文件只描述手机本地生成的最终媒体，不替代 Worker 的独立额度与文件复核。
/// 所有字节上限均采用十进制 MB/GB，与 R2 计量和产品展示保持一致。
final class SquareMediaPolicy {
  const SquareMediaPolicy({
    required this.membershipLevel,
    required this.imageMaxEdge,
    required this.imageQuality,
    required this.imageMaxBytes,
    required this.videoShortSide,
    required this.videoLongSide,
    required this.videoTotalBitrate,
    required this.videoPeakBitrate,
    required this.audioBitrate,
    required this.maxVideoSeconds,
    required this.maxVideoBytes,
  });

  static const int imageThumbnailMaxEdge = 480;
  static const int imageThumbnailQuality = 70;
  static const int imageThumbnailMaxBytes = 256000;
  static const int videoCoverMaxEdge = 720;
  static const int videoCoverQuality = 75;
  static const int videoCoverMaxBytes = 512000;
  static const int videoMaxFrameRate = 30;
  static const int videoKeyFrameIntervalSeconds = 2;
  static const int audioSampleRate = 48000;

  final String membershipLevel;
  final int imageMaxEdge;
  final int imageQuality;
  final int imageMaxBytes;
  final int videoShortSide;
  final int videoLongSide;

  /// 音视频合计目标平均码率，单位 bit/s。
  final int videoTotalBitrate;

  /// 一秒滑动窗口允许的音视频合计峰值码率，单位 bit/s。
  final int videoPeakBitrate;
  final int audioBitrate;
  final int maxVideoSeconds;
  final int maxVideoBytes;

  int get videoBitrate => videoTotalBitrate - audioBitrate;

  // 本机已保存图片的安全读取顶，不提供当前账户会员授权。
  static const int maxLocalImageBytes = 4000000;
  static const int maxLocalPlaybackBytes = 3000000000;

  /// 档位只选择原编解码参数；会员字节/尺寸/时长来自本次服务端Plan。
  static SquareMediaPolicy forPlan(SquareMembershipPlan plan) {
    if (plan.imageMaxBytes <= 0 ||
        plan.imageMaxEdge <= 0 ||
        plan.video.maxVideoBytes <= 0 ||
        plan.video.maxVideoSeconds <= 0) {
      throw const FormatException('会员媒体参数缺失');
    }
    final codec = switch (plan.membershipLevel) {
      'freedom' => (72, 480, 854, 600000, 900000, 96000),
      'democracy' => (80, 720, 1280, 1200000, 1800000, 96000),
      'spark' => (85, 1080, 1920, 2000000, 3000000, 128000),
      _ => throw const FormatException('会员档位不支持广场媒体处理'),
    };
    return SquareMediaPolicy(
      membershipLevel: plan.membershipLevel,
      imageMaxEdge: plan.imageMaxEdge,
      imageQuality: codec.$1,
      imageMaxBytes: plan.imageMaxBytes,
      videoShortSide: codec.$2,
      videoLongSide: codec.$3,
      videoTotalBitrate: codec.$4,
      videoPeakBitrate: codec.$5,
      audioBitrate: codec.$6,
      maxVideoSeconds: plan.video.maxVideoSeconds,
      maxVideoBytes: plan.video.maxVideoBytes,
    );
  }
}
