import Flutter
import Foundation
import Darwin
import AVFoundation
import AVKit
import UniformTypeIdentifiers

// 历史媒体的本机安全读取顶，统一1024进制；会员成品额度仍由服务端交付。
private let maxMediaBytes: Int64 = 3 * 1024 * 1024 * 1024

/// 公民广场媒体原生通道；跨端字段统一使用 snake_case。
final class SquareMediaChannel {
  static let channelName = "citizenapp/square_media"

  private let channel: FlutterMethodChannel
  private let transcoder = SquareVideoTranscoder()
  private let playback = SquarePlayback()
  private var playbackInitializationFailed = false

  init(binaryMessenger: FlutterBinaryMessenger, registrar: FlutterApplicationRegistrar? = nil) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    registrar?.register(SquarePlayerFactory(channel: channel, playback: playback), withId: "citizenapp/square_video")
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
    Array(playback.players.values).forEach { $0.dispose() }
    transcoder.cancel()
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pause_playback", "dispose_playback":
      if let args = call.arguments as? [String: Any], let id = args["player_id"] as? Int {
        if call.method == "pause_playback" { playback.players[id]?.pause() }
        else { playback.players[id]?.dispose() }
      }
      result(nil)
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
          guard size > 0, size <= maxMediaBytes else {
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
            guard size > 0, size <= maxMediaBytes else {
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
  let videoWidth: Int
  let videoHeight: Int
  let videoBitrate: Int
  let videoPeakBitrate: Int
  let audioBitrate: Int
  let audioSampleRate: Int
  let videoFrameRate: Int
  let keyframeSecs: Int
  let videoMaxSeconds: Int
  let videoMaxBytes: Int64
  let coverDimension: Int
  let coverQuality: Int
  let coverBytes: Int

  init(arguments: Any?) throws {
    guard let values = arguments as? [String: Any] else {
      throw SquareMediaError.invalidRequest("视频参数不是对象")
    }
    inputPath = try values.requiredString("input_path")
    outputPath = try values.requiredString("output_path")
    coverPath = try values.requiredString("cover_path")
    videoWidth = try values.requiredInt("video_width")
    videoHeight = try values.requiredInt("video_height")
    videoBitrate = try values.requiredInt("video_bitrate")
    videoPeakBitrate = try values.requiredInt("video_peak_bitrate")
    audioBitrate = try values.requiredInt("audio_bitrate")
    audioSampleRate = try values.requiredInt("audio_sample_rate")
    videoFrameRate = try values.requiredInt("video_frame_rate")
    keyframeSecs = try values.requiredInt("keyframe_secs")
    videoMaxSeconds = try values.requiredInt("video_max_seconds")
    videoMaxBytes = try values.requiredInt64("video_max_bytes")
    coverDimension = try values.requiredInt("cover_dimension")
    coverQuality = try values.requiredInt("cover_quality")
    coverBytes = try values.requiredInt("cover_bytes")

    guard videoWidth >= 2, videoWidth <= 1920,
          videoHeight >= 2, videoHeight <= 1080,
          videoBitrate > 0, audioBitrate > 0, videoPeakBitrate > 0,
          audioSampleRate == 48_000,
          videoFrameRate > 0, videoFrameRate <= 30,
          keyframeSecs == 2,
          videoMaxSeconds > 0, videoMaxSeconds <= 10_800,
          videoMaxBytes > 0, videoMaxBytes <= maxMediaBytes,
          coverDimension > 0, coverDimension <= 720,
          coverQuality > 0, coverQuality <= 100,
          coverBytes > 0, coverBytes <= 512 * 1024
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

/// AVPlayer只通过本资源加载器读取App交付的有界字节；不持有URL或凭据。
final class SquareRangeLoader: NSObject, AVAssetResourceLoaderDelegate {
  typealias Read = (Int64, Int, @escaping (Result<Data, Error>) -> Void) -> Void
  let total: Int64
  let read: Read
  private var pending = Set<ObjectIdentifier>()
  private var closed = false
  init(total: Int64, read: @escaping Read) { self.total = total; self.read = read }
  static func count(offset: Int64, requested: Int64, total: Int64) -> Int {
    guard offset >= 0, requested > 0, total > offset else { return 0 }
    return Int(min(524288, requested, total-offset))
  }
  func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
      shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest) -> Bool {
    guard !closed else { return false }
    let key = ObjectIdentifier(request)
    pending.insert(key)
    request.contentInformationRequest?.contentType = UTType.mpeg4Movie.identifier
    request.contentInformationRequest?.contentLength = total
    request.contentInformationRequest?.isByteRangeAccessSupported = true
    pump(request)
    return true
  }
  private func pump(_ request: AVAssetResourceLoadingRequest) {
    let key = ObjectIdentifier(request)
    guard !closed, pending.contains(key), !request.isCancelled else { return }
    guard let data = request.dataRequest else {
      pending.remove(key); request.finishLoading(); return
    }
    let offset = max(data.requestedOffset, data.currentOffset)
    let end = data.requestsAllDataToEndOfResource ? total : min(total, data.requestedOffset + Int64(data.requestedLength))
    let count = Self.count(offset: offset, requested: end-offset, total: total)
    if count == 0 { pending.remove(key); request.finishLoading(); return }
    read(offset,count) { [weak self, weak request] result in
      DispatchQueue.main.async {
        guard let self, let request, !self.closed, self.pending.contains(key), !request.isCancelled else { return }
        switch result {
        case let .success(bytes) where bytes.count == count:
          request.dataRequest?.respond(with: bytes)
          self.pump(request)
        default:
          self.pending.remove(key)
          request.finishLoading(with: NSError(domain: "citizenmedia",code: 1))
        }
      }
    }
  }
  func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel request: AVAssetResourceLoadingRequest) {
    pending.remove(ObjectIdentifier(request))
  }
  func close() { closed = true; pending.removeAll() }
}

private final class SquarePlayback { var players = [Int:SquarePlayer]() }

private final class SquarePlayerFactory: NSObject, FlutterPlatformViewFactory {
  private let channel: FlutterMethodChannel
  private let playback: SquarePlayback
  init(channel: FlutterMethodChannel, playback: SquarePlayback) { self.channel = channel; self.playback = playback }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let values = args as? [String: Any] ?? [:]
    let id=values["player_id"] as? Int ?? -1
    playback.players[id]?.dispose()
    return SquarePlayer(frame: frame, id:id,
      total: (values["byte_size"] as? NSNumber)?.int64Value ?? 0, channel: channel, playback:playback)
  }
}

/// 平台View使用标准子控制器归属，播放器控制与全屏呈现由所属Flutter控制器承接。
private final class SquarePlayerView: UIView {
  weak var controller: AVPlayerViewController?
  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil, let controller, controller.parent == nil else { return }
    var responder: UIResponder? = next
    while let current = responder {
      if let parent = current as? UIViewController {
        parent.addChild(controller)
        controller.didMove(toParent:parent)
        return
      }
      responder = current.next
    }
  }
}

private final class SquarePlayer: NSObject, FlutterPlatformView {
  private weak var playback: SquarePlayback?
  private let id: Int
  private let player = AVPlayer()
  private let controller = AVPlayerViewController()
  private let root: SquarePlayerView
  private var loader: SquareRangeLoader?
  private var observation: NSKeyValueObservation?
  private var disposed = false
  init(frame: CGRect, id: Int, total: Int64, channel: FlutterMethodChannel, playback:SquarePlayback) {
    self.id = id
    self.playback = playback
    self.root = SquarePlayerView(frame:frame)
    super.init()
    controller.view.frame = root.bounds
    controller.view.autoresizingMask = [.flexibleWidth,.flexibleHeight]
    root.addSubview(controller.view)
    root.controller = controller
    guard id >= 0, total > 0, total <= maxMediaBytes, playback.players[id] == nil else { return }
    playback.players[id] = self
    let loader = SquareRangeLoader(total: total) { [weak self] offset, length, done in
      guard let self, !self.disposed else { done(.failure(NSError(domain:"citizenmedia",code:2))); return }
      channel.invokeMethod("read_range", arguments: ["player_id":id,"offset":offset,"length":length]) { value in
        guard !self.disposed, let values = value as? [String:Any],
          (values["offset"] as? NSNumber)?.int64Value == offset,
          (values["total"] as? NSNumber)?.int64Value == total,
          values["content_type"] as? String == "video/mp4",
          let bytes = values["bytes"] as? FlutterStandardTypedData, bytes.data.count == length
        else { done(.failure(NSError(domain:"citizenmedia",code:3))); return }
        done(.success(bytes.data))
      }
    }
    self.loader = loader
    let asset = AVURLAsset(url: URL(string:"citizenmedia://player/\(id)")!)
    asset.resourceLoader.setDelegate(loader, queue: .main)
    let item = AVPlayerItem(asset:asset)
    observation = item.observe(\.status, options:[.new]) { [weak self] item, _ in
      if item.status == .failed, let self, !self.disposed {
        DispatchQueue.main.async { channel.invokeMethod("playback_failed",arguments:["player_id":id]) }
      }
    }
    player.replaceCurrentItem(with:item)
    controller.player = player
    controller.showsPlaybackControls = true
    player.play()
  }
  func view() -> UIView { root }
  func pause() { player.pause() }
  func dispose() {
    guard !disposed else { return }
    disposed = true
    player.pause()
    loader?.close()
    player.replaceCurrentItem(with:nil)
    controller.player = nil
    controller.willMove(toParent:nil)
    controller.view.removeFromSuperview()
    controller.removeFromParent()
    observation = nil
    loader = nil
    playback?.players.removeValue(forKey:id)
  }
  deinit { dispose() }
}
