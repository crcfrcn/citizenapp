import Flutter
import Foundation
import Darwin

/// 公民广场媒体原生通道；跨端字段统一使用 snake_case。
final class SquareMediaChannel {
  static let channelName = "citizenapp/square_media"

  private let channel: FlutterMethodChannel
  private let transcoder = SquareVideoTranscoder()
  private var playbackInitializationFailed = false

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    do {
      _ = try Self.playbackDirectory()
    } catch {
      playbackInitializationFailed = true
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    transcoder.cancel()
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      result(transcoder.capabilities())
    case "transcode_video":
      do {
        let request = try SquareVideoRequest(arguments: call.arguments)
        transcoder.transcode(request) { transcodeResult in
          DispatchQueue.main.async {
            switch transcodeResult {
            case let .success(value):
              result(value)
            case let .failure(error):
              result(
                FlutterError(
                  code: "square_media_transcode_failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
      } catch {
        result(
          FlutterError(
            code: "square_media_invalid",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "prepare_playback_file", "verify_playback_file", "delete_playback_file":
      do {
        guard !playbackInitializationFailed else {
          throw SquareMediaError.processing("本地播放残留清理失败")
        }
        guard let values = call.arguments as? [String: Any] else {
          throw SquareMediaError.invalidRequest("本地播放参数无效")
        }
        if call.method == "prepare_playback_file" {
          let size = try values.requiredInt64("byte_size")
          guard size > 0, size <= 3_000_000_000 else {
            throw SquareMediaError.invalidRequest("本地视频大小无效")
          }
          let root = try Self.playbackDirectory()
          let disk = try FileManager.default.attributesOfFileSystem(forPath: root.path)
          guard let free = disk[.systemFreeSize] as? NSNumber,
                free.int64Value >= size + 1_048_576 else {
            throw SquareMediaError.processing("本地播放空间不足")
          }
          let file = root.appendingPathComponent(UUID().uuidString + ".mp4")
          let fd = Darwin.open(file.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0o600)
          guard fd >= 0 else { throw SquareMediaError.processing("本地播放文件创建失败") }
          Darwin.close(fd)
          do {
            try Self.protect(file)
            try Self.checkFile(file, size: 0)
            Self.playbackFiles.insert(file.path)
          } catch {
            try FileManager.default.removeItem(at: file)
            guard try !Self.existsWithoutFollowing(file.path) else {
              throw SquareMediaError.processing("本地播放文件清理失败")
            }
            throw error
          }
          result(file.path)
        } else {
          let path = try values.requiredString("output_path")
          let file = try Self.ownedFile(path)
          if call.method == "verify_playback_file" {
            let size = try values.requiredInt64("byte_size")
            guard size > 0, size <= 3_000_000_000 else {
              throw SquareMediaError.invalidRequest("本地视频大小无效")
            }
            try Self.checkFile(file, size: size)
          } else {
            if try Self.existsWithoutFollowing(path) {
              try Self.checkFile(file, size: nil)
              try FileManager.default.removeItem(at: file)
            }
            guard try !Self.existsWithoutFollowing(path) else {
              throw SquareMediaError.processing("本地播放文件清理失败")
            }
            Self.playbackFiles.remove(path)
          }
          result(nil)
        }
      } catch {
        result(FlutterError(code: "square_media_playback_failed",
                            message: "本地播放文件保护、空间或清理检查失败", details: nil))
      }
    case "cancel_video":
      transcoder.cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  // 仅管理本通道专属目录；进程首次使用清理崩溃残留，不触及其他缓存或钱包。
  private static var playbackRoot: URL?
  private static var playbackFiles = Set<String>()

  private static func existsWithoutFollowing(_ path: String) throws -> Bool {
    var info = stat()
    if lstat(path, &info) == 0 { return true }
    guard errno == ENOENT else {
      throw SquareMediaError.processing("本地播放文件回读失败")
    }
    return false
  }

  private static func protect(_ url: URL) throws {
    try FileManager.default.setAttributes([
      .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
      .posixPermissions: url.hasDirectoryPath ? 0o700 : 0o600
    ], ofItemAtPath: url.path)
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try target.setResourceValues(values)
  }

  private static func checkOwnedRegularFile(_ file: URL) throws -> [FileAttributeKey: Any] {
    let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
    guard attrs[.type] as? FileAttributeType == .typeRegular,
          (attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600,
          (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
          file.resolvingSymlinksInPath().path == file.path
    else { throw SquareMediaError.processing("本地播放文件归属失败") }
    return attrs
  }

  private static func checkFile(_ file: URL, size: Int64?) throws {
    let attrs = try checkOwnedRegularFile(file)
    guard
          attrs[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication,
          try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true
    else { throw SquareMediaError.processing("本地播放文件保护失败") }
    if let size, (attrs[.size] as? NSNumber)?.int64Value != size {
      throw SquareMediaError.processing("本地播放文件长度不一致")
    }
  }

  private static func playbackDirectory() throws -> URL {
    if let root = playbackRoot { return root }
    let fm = FileManager.default
    let cache = try fm.url(for: .cachesDirectory, in: .userDomainMask,
                           appropriateFor: nil, create: true).resolvingSymlinksInPath()
    let root = cache.appendingPathComponent("square_video_playback", isDirectory: true)
    if !fm.fileExists(atPath: root.path) {
      try fm.createDirectory(at: root, withIntermediateDirectories: false,
                             attributes: [.posixPermissions: 0o700,
                                          .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    }
    let attrs = try fm.attributesOfItem(atPath: root.path)
    guard attrs[.type] as? FileAttributeType == .typeDirectory,
          root.resolvingSymlinksInPath().path == root.path,
          (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == getuid()
    else { throw SquareMediaError.processing("本地播放目录无效") }
    try protect(root)
    let protected = try fm.attributesOfItem(atPath: root.path)
    guard (protected[.posixPermissions] as? NSNumber)?.intValue == 0o700,
          protected[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication,
          try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true
    else { throw SquareMediaError.processing("本地播放目录保护失败") }
    for file in try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
      guard file.pathExtension == "mp4",
            UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil else {
        throw SquareMediaError.processing("本地播放目录存在未知文件")
      }
      // 崩溃可能发生在空文件的保护登记完成前；校验专属归属后仍必须清掉。
      _ = try checkOwnedRegularFile(file)
      try fm.removeItem(at: file)
      guard try !existsWithoutFollowing(file.path) else {
        throw SquareMediaError.processing("本地播放残留清理失败")
      }
    }
    playbackRoot = root
    return root
  }

  private static func ownedFile(_ path: String) throws -> URL {
    let root = try playbackDirectory()
    let file = URL(fileURLWithPath: path)
    guard file.deletingLastPathComponent().path == root.path,
          file.path == path, file.pathExtension == "mp4",
          UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
          playbackFiles.contains(path) else {
      throw SquareMediaError.invalidRequest("本地播放文件归属无效")
    }
    return file
  }
}

struct SquareVideoRequest {
  let inputPath: String
  let outputPath: String
  let coverPath: String
  let maxWidth: Int
  let maxHeight: Int
  let videoBitrate: Int
  let totalPeakBitrate: Int
  let audioBitrate: Int
  let audioSampleRate: Int
  let maxFrameRate: Int
  let keyFrameIntervalSeconds: Int
  let maxDurationSeconds: Int
  let maxBytes: Int64
  let coverMaxEdge: Int
  let coverQuality: Int
  let coverMaxBytes: Int

  init(arguments: Any?) throws {
    guard let values = arguments as? [String: Any] else {
      throw SquareMediaError.invalidRequest("视频参数不是对象")
    }
    inputPath = try values.requiredString("input_path")
    outputPath = try values.requiredString("output_path")
    coverPath = try values.requiredString("cover_path")
    maxWidth = try values.requiredInt("max_width")
    maxHeight = try values.requiredInt("max_height")
    videoBitrate = try values.requiredInt("video_bitrate")
    totalPeakBitrate = try values.requiredInt("total_peak_bitrate")
    audioBitrate = try values.requiredInt("audio_bitrate")
    audioSampleRate = try values.requiredInt("audio_sample_rate")
    maxFrameRate = try values.requiredInt("max_frame_rate")
    keyFrameIntervalSeconds = try values.requiredInt("key_frame_interval_seconds")
    maxDurationSeconds = try values.requiredInt("max_duration_seconds")
    maxBytes = try values.requiredInt64("max_bytes")
    coverMaxEdge = try values.requiredInt("cover_max_edge")
    coverQuality = try values.requiredInt("cover_quality")
    coverMaxBytes = try values.requiredInt("cover_max_bytes")

    guard maxWidth >= 2, maxWidth <= 1920,
          maxHeight >= 2, maxHeight <= 1080,
          videoBitrate > 0, audioBitrate > 0, totalPeakBitrate > 0,
          audioSampleRate == 48_000,
          maxFrameRate > 0, maxFrameRate <= 30,
          keyFrameIntervalSeconds == 2,
          maxDurationSeconds > 0, maxDurationSeconds <= 10_800,
          maxBytes > 0, maxBytes <= 3_000_000_000,
          coverMaxEdge > 0, coverMaxEdge <= 720,
          coverQuality > 0, coverQuality <= 100,
          coverMaxBytes > 0, coverMaxBytes <= 512_000
    else {
      throw SquareMediaError.invalidRequest("视频参数超出允许范围")
    }
  }
}

enum SquareMediaError: LocalizedError {
  case invalidRequest(String)
  case unsupported(String)
  case processing(String)
  case cancelled

  var errorDescription: String? {
    switch self {
    case let .invalidRequest(message), let .unsupported(message), let .processing(message):
      return message
    case .cancelled:
      return "视频处理已取消"
    }
  }
}

private extension Dictionary where Key == String, Value == Any {
  func requiredString(_ key: String) throws -> String {
    guard let value = self[key] as? String, !value.isEmpty else {
      throw SquareMediaError.invalidRequest("\(key) 缺失")
    }
    return value
  }

  func requiredInt(_ key: String) throws -> Int {
    guard let number = self[key] as? NSNumber else {
      throw SquareMediaError.invalidRequest("\(key) 缺失")
    }
    return number.intValue
  }

  func requiredInt64(_ key: String) throws -> Int64 {
    guard let number = self[key] as? NSNumber else {
      throw SquareMediaError.invalidRequest("\(key) 缺失")
    }
    return number.int64Value
  }
}
