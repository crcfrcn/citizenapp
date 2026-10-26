import 'package:citizenapp/network/square_api_client.dart';

/// 手机只执行服务端下发的成品规格；本文件不定义三档额度或编码参数副本。
final class SquareMediaPolicy {
  const SquareMediaPolicy._(this._plan);
  final SquareMembershipPlan _plan;

  // 历史已保存媒体的安全读取顶，与新上传额度无关，降档或调小上传规格不损坏旧内容。
  static const int maxLocalImageBytes = 4000000;
  static const int maxLocalPlaybackBytes = 3000000000;

  String get membershipLevel => _plan.membershipLevel;
  int get imageMaxEdge => _plan.imageMaxEdge;
  int get imageMaxBytes => _plan.imageMaxBytes;
  int get imageQuality => _value('image_quality');
  int get imageThumbnailMaxEdge => _value('thumbnail_dimension');
  int get imageThumbnailQuality => _value('thumbnail_quality');
  int get imageThumbnailMaxBytes => _value('thumbnail_bytes');
  int get videoCoverMaxEdge => _value('cover_dimension');
  int get videoCoverQuality => _value('cover_quality');
  int get videoCoverMaxBytes => _value('cover_bytes');
  int get videoMaxFrameRate => _value('video_frame_rate');
  int get videoKeyFrameIntervalSeconds => _value('video_key_frame_seconds');
  int get audioSampleRate => _value('audio_sample_rate');
  int get videoShortSide => _value('video_height');
  int get videoLongSide => _value('video_width');
  int get videoTotalBitrate => _value('video_total_bitrate');
  int get videoPeakBitrate => _value('video_peak_bitrate');
  int get audioBitrate => _value('audio_bitrate');
  int get videoBitrate => videoTotalBitrate - audioBitrate;
  int get maxVideoSeconds => _plan.video.maxVideoSeconds;
  int get maxVideoBytes => _plan.video.maxVideoBytes;

  int _value(String key) {
    final value = _plan.media[key];
    if (value == null || value <= 0) throw FormatException('媒体成品参数缺失：$key');
    return value;
  }

  static SquareMediaPolicy forPlan(SquareMembershipPlan plan) {
    if (!const [
          'freedom',
          'democracy',
          'spark',
        ].contains(plan.membershipLevel) ||
        plan.imageMaxBytes <= 0 ||
        plan.imageMaxEdge <= 0 ||
        plan.video.maxVideoBytes <= 0 ||
        plan.video.maxVideoSeconds <= 0) {
      throw const FormatException('会员媒体参数缺失');
    }
    final policy = SquareMediaPolicy._(plan);
    for (final key in const [
      'image_quality',
      'thumbnail_dimension',
      'thumbnail_quality',
      'thumbnail_bytes',
      'cover_dimension',
      'cover_quality',
      'cover_bytes',
      'video_frame_rate',
      'video_key_frame_seconds',
      'audio_sample_rate',
      'video_height',
      'video_width',
      'video_total_bitrate',
      'video_peak_bitrate',
      'audio_bitrate',
    ]) {
      policy._value(key);
    }
    if (policy.imageQuality > 100 ||
        policy.imageThumbnailQuality > 100 ||
        policy.videoCoverQuality > 100 ||
        policy.audioBitrate >= policy.videoTotalBitrate ||
        policy.videoPeakBitrate < policy.videoTotalBitrate) {
      throw const FormatException('媒体成品规格无效');
    }
    return policy;
  }
}
