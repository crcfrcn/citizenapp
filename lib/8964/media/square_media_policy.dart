import 'package:citizenapp/network/square_api_client.dart';

/// 手机只执行服务端下发的成品规格；本文件不定义三档额度或编码参数副本。
final class SquareMediaPolicy {
  const SquareMediaPolicy._(this._plan);
  final SquareMembershipPlan _plan;

  // 历史已保存媒体的1024进制安全读取顶，与新上传额度无关，降档或调小上传规格不损坏旧内容。
  static const int localImageBytes = 4 * 1024 * 1024;
  static const int playbackBytes = 3 * 1024 * 1024 * 1024;

  String get memberLevel => _plan.memberLevel;
  int get imageDimension => _plan.imageDimension;
  int get imageBytes => _plan.imageBytes;
  int get imageQuality => _value('image_quality');
  int get thumbnailDimension => _value('thumbnail_dimension');
  int get thumbnailQuality => _value('thumbnail_quality');
  int get thumbnailBytes => _value('thumbnail_bytes');
  int get coverDimension => _value('cover_dimension');
  int get coverQuality => _value('cover_quality');
  int get coverBytes => _value('cover_bytes');
  int get videoFrameRate => _value('video_frame_rate');
  int get keyframeSecs => _value('keyframe_secs');
  int get audioSampleRate => _value('audio_sample_rate');
  int get videoHeight => _value('video_height');
  int get videoWidth => _value('video_width');
  int get videoTotalBitrate => _value('video_total_bitrate');
  int get videoPeakBitrate => _value('video_peak_bitrate');
  int get audioBitrate => _value('audio_bitrate');
  int get videoBitrate => videoTotalBitrate - audioBitrate;
  int get videoMaxSeconds => _plan.video.videoMaxSeconds;
  int get videoMaxBytes => _plan.video.videoMaxBytes;

  int _value(String key) {
    final value = _plan.media[key];
    if (value == null || value <= 0) throw FormatException('媒体成品参数缺失：$key');
    return value;
  }

  static SquareMediaPolicy forPlan(SquareMembershipPlan plan) {
    if (!const ['freedom', 'democracy', 'spark'].contains(plan.memberLevel) ||
        plan.imageBytes <= 0 ||
        plan.imageDimension <= 0 ||
        plan.video.videoMaxBytes <= 0 ||
        plan.video.videoMaxSeconds <= 0) {
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
      'keyframe_secs',
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
        policy.thumbnailQuality > 100 ||
        policy.coverQuality > 100 ||
        policy.audioBitrate >= policy.videoTotalBitrate ||
        policy.videoPeakBitrate < policy.videoTotalBitrate) {
      throw const FormatException('媒体成品规格无效');
    }
    return policy;
  }
}
