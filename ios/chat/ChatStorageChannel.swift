import Flutter
import Foundation
import Darwin
import ChatOpenMLS

final class ChatStorageChannel {
  private let securityChannel: FlutterMethodChannel
  init(binaryMessenger: FlutterBinaryMessenger) {
    // 空指针释放无状态，用真实符号引用保证 App 装载这一份 OpenMLS 动态库。
    chat_openmls_free_string(nil)
    securityChannel = FlutterMethodChannel(name: "citizenapp/chat/storage", binaryMessenger: binaryMessenger,
      codec: FlutterStandardMethodCodec.sharedInstance(), taskQueue: binaryMessenger.makeBackgroundTaskQueue?())
    securityChannel.setMethodCallHandler { call, result in
      if call.method == "eraseMlsStorage" {
        do { try Self.eraseMlsStorage(call); result(nil) }
        catch { result(FlutterError(code: "mls_storage_unavailable", message: "MLS安全存储清理失败", details: nil)) }
        return
      }
      if call.method == "prepareMlsStorage" {
        do { result(try Self.prepareMlsStorage(call)) }
        catch { result(FlutterError(code: "mls_storage_unavailable", message: "MLS安全存储不可用", details: nil)) }
        return
      }
      guard call.method == "prepareDataStorage" else { result(FlutterMethodNotImplemented); return }
      var stage = "support_directory"
      do { result(try Self.prepareDataStorage(stage: &stage)) }
      catch {
        // 正式包仅记录固定阶段和系统错误码，不输出路径、userInfo或错误正文。
        let failure = error as NSError
        let domains = [NSCocoaErrorDomain, NSPOSIXErrorDomain, NSOSStatusErrorDomain]
        let domain = domains.contains(failure.domain) ? failure.domain : "other"
        NSLog("公民聊天 storage stage=%@ domain=%@ code=%ld", stage, domain, failure.code)
        if let cause = failure.userInfo[NSUnderlyingErrorKey] as? NSError {
          let causeDomain = domains.contains(cause.domain) ? cause.domain : "other"
          NSLog("公民聊天 storage underlying_domain=%@ code=%ld", causeDomain, cause.code)
        }
        result(FlutterError(code: "data_storage_unavailable", message: "聊天系统保护存储不可用",
          details: ["stage": stage, "domain": domain, "code": failure.code]))
      }
    }
  }
  deinit { securityChannel.setMethodCallHandler(nil) }
  /// 只删除聊天自有保护目录；整库清理仅由聊天既有全量擦除入口调用。
  private static func eraseMlsStorage(_ call: FlutterMethodCall) throws {
    let manager = FileManager.default
    guard let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
          let args = call.arguments as? [String: Any] else { throw CocoaError(.fileReadInvalidFileName) }
    var target = try migrateDirectory("tatachat_sdk_mls", "chat_mls", support: support)
    if let user = args["user_id"] {
      guard let user = user as? String, !user.isEmpty, user.utf8.count <= 120, !user.contains(":") else { throw CocoaError(.fileReadInvalidFileName) }
      let name = user.utf8.map { String(format: "%02x", $0) }.joined()
      target.appendPathComponent(name, isDirectory: true)
    }
    guard target.resolvingSymlinksInPath().path == target.path else { throw CocoaError(.fileReadInvalidFileName) }
    if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
    if manager.fileExists(atPath: target.path) { throw CocoaError(.fileWriteUnknown) }
  }

  /// 聊天包在秘密生成前验证目录保护；已有目录缺状态时由读取接口明确失败。
  private static func prepareMlsStorage(_ call: FlutterMethodCall) throws -> [String: Any] {
    guard let args = call.arguments as? [String: Any], let user = args["user_id"] as? String,
          !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !user.contains(":"), user.utf8.count <= 4096,
          let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let manager = FileManager.default
    // 系统容器路径可能含/var别名；先规范平台给出的根，再拒绝聊天子目录链接。
    let root = try migrateDirectory("tatachat_sdk_mls", "chat_mls", support: support)
    let name = user.utf8.map { String(format: "%02x", $0) }.joined()
    // UTF-8编码保持一一对应，不用字符替换造成不同用户目录碰撞。
    guard name.count <= 240 else { throw CocoaError(.fileReadInvalidFileName) }
    let target = root.appendingPathComponent(name, isDirectory: true)
    for var directory in [root, target] {
      if manager.fileExists(atPath: directory.path) {
        let resource = try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard resource.isSymbolicLink != true, resource.isDirectory == true,
              directory.resolvingSymlinksInPath().path == directory.path else { throw CocoaError(.fileReadInvalidFileName) }
      } else {
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o700])
      }
      try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o700], ofItemAtPath: directory.path)
      var values = URLResourceValues(); values.isExcludedFromBackup = true
      try directory.setResourceValues(values)
      let attrs = try manager.attributesOfItem(atPath: directory.path)
      guard attrs[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication,
            (attrs[.posixPermissions] as? NSNumber)?.intValue == 0o700,
            try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else { throw CocoaError(.fileWriteUnknown) }
    }
    guard let items = manager.enumerator(at: target, includingPropertiesForKeys: [.isSymbolicLinkKey]) else {
      throw CocoaError(.fileReadUnknown)
    }
    do {
      for case var item as URL in items {
        guard try item.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw CocoaError(.fileReadInvalidFileName) }
        try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: item.path)
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try item.setResourceValues(values)
        let attrs = try manager.attributesOfItem(atPath: item.path)
        guard attrs[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication,
              try item.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else { throw CocoaError(.fileWriteUnknown) }
      }
    }
    // 平台只交付保护目录，身份首次准备由原生持久状态决定。
    return ["path": target.path]
  }

  /// 聊天唯一数据目录；首次解锁后可后台使用，不引入应用包装密钥。
  private static func prepareDataStorage(stage: inout String) throws -> String {
    let manager = FileManager.default
    guard let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      throw CocoaError(.fileNoSuchFile)
    }
    // 普通准备只验证当前保护域，不删除或迁移旧数据库及附件。
    let root = try migrateDirectory("tatachat_sdk_data", "chat_data", support: support)
    stage = "data_directory_create"
    if !manager.fileExists(atPath: root.path) {
      try manager.createDirectory(at: root, withIntermediateDirectories: false,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o700])
    }
    stage = "data_directory_protect"
    try protectOwnedData(root)
    return root.path
  }

  private static func eraseOwnedData(_ url: URL) throws {
    let manager = FileManager.default
    guard url.resolvingSymlinksInPath().path == url.path else { throw CocoaError(.fileReadInvalidFileName) }
    if manager.fileExists(atPath: url.path) {
      try protectOwnedData(url)
      try manager.removeItem(at: url)
    }
    if manager.fileExists(atPath: url.path) { throw CocoaError(.fileWriteUnknown) }
  }

  static func protectOwnedData(_ url: URL) throws {
    let manager = FileManager.default
    let resource = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey])
    // 系统枚举可能返回/private/var别名；用真实类型拒绝链接，不比较路径拼写。
    guard resource.isSymbolicLink != true,
          resource.isDirectory == true || resource.isRegularFile == true else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let permissions = resource.isDirectory == true ? 0o700 : 0o600
    try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        .posixPermissions: permissions], ofItemAtPath: url.path)
    var protected = url
    var values = URLResourceValues(); values.isExcludedFromBackup = true
    try protected.setResourceValues(values)
    let attributes = try manager.attributesOfItem(atPath: url.path)
    guard attributes[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication,
          (attributes[.posixPermissions] as? NSNumber)?.intValue == permissions,
          try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
      throw CocoaError(.fileWriteUnknown)
    }
    if resource.isDirectory == true {
      for child in try manager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
        try protectOwnedData(child)
      }
    }
  }


  // 升级过程串行搬移旧聊天根及文件名，保留内容、MLS 身份和擦除标记。
  static func migrateDirectory(_ legacy: String, _ current: String, support: URL) throws -> URL {
    let manager = FileManager.default
    let base = support.resolvingSymlinksInPath()
    if !manager.fileExists(atPath: base.path) {
      try manager.createDirectory(at: base, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o700])
    }
    let lock = base.appendingPathComponent(".chat-storage-upgrade.lock")
    let fd = Darwin.open(lock.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { Darwin.close(fd) }
    guard flock(fd, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { flock(fd, LOCK_UN) }
    let old = base.appendingPathComponent(legacy, isDirectory: true)
    let target = base.appendingPathComponent(current, isDirectory: true)
    guard old.resolvingSymlinksInPath().path == old.path,
          target.resolvingSymlinksInPath().path == target.path else { throw CocoaError(.fileReadInvalidFileName) }
    if manager.fileExists(atPath: old.path) {
      guard !manager.fileExists(atPath: target.path) else { throw CocoaError(.fileWriteFileExists) }
      try manager.moveItem(at: old, to: target)
    }
    if manager.fileExists(atPath: target.path) {
      for entry in try manager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil) {
        let name = entry.lastPathComponent.replacingOccurrences(of: "tatachatsdk_chat", with: "chat").replacingOccurrences(of: "tatachat_sdk_data", with: "chat_data")
        if name != entry.lastPathComponent {
          let to = target.appendingPathComponent(name)
          guard !manager.fileExists(atPath: to.path), entry.resolvingSymlinksInPath().path == entry.path else { throw CocoaError(.fileWriteFileExists) }
          try manager.moveItem(at: entry, to: to)
        }
      }
    }
    return target
  }

}
