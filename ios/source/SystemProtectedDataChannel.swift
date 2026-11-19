import Flutter
import Foundation
import Security
import Darwin
import MLS

/// App所属记录与User库系统保护。没有密钥生成、签名、解封或生物识别入口。
final class SystemProtectedDataChannel {
  private let channel: FlutterMethodChannel
  init(binaryMessenger: FlutterBinaryMessenger) {
    // 保留设备签名库同一进程的原生符号供 Dart 读取。
    mls_free_string(nil)
    // 文件锁竞争和同步落盘都留在Flutter串行后台队列，不能阻塞主线程处理触摸/场景事件。
    guard let queue = binaryMessenger.makeBackgroundTaskQueue?() else {
      preconditionFailure("系统保护存储需要Flutter后台任务队列")
    }
    channel = FlutterMethodChannel(name: "citizenapp/system_protected_data", binaryMessenger: binaryMessenger,
      codec: FlutterStandardMethodCodec.sharedInstance(), taskQueue: queue)
    channel.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "prepareRecords": result(try Self.prepareRecords().path)
        case "compareRecords":
          guard let args = call.arguments as? [String: Any], args.count == 3,
                let name = args["name"] as? String, let next = args["next"] as? String,
                args["expected"] is NSNull || args["expected"] is String else { throw CocoaError(.fileReadInvalidFileName) }
          result(try Self.compareRecordFile(root: Self.prepareRecords(), name: name, expected: args["expected"] as? String, next: next))
        case "protectUserDatabase":
          guard let args = call.arguments as? [String: Any], args.count == 1,
                let directory = args["directory"] as? String else { throw CocoaError(.fileReadInvalidFileName) }
          try Self.protectUserDatabase(directory); result(nil)
        case "eraseObsoleteDataMaterial": try Self.eraseObsoleteDataMaterial(); result(nil)
        case "prepareWipeDirectory": result(try Self.prepareWipeDirectory().path)
        case "syncWipeLayout": try Self.syncWipeLayout(); result(nil)
        case "prepareDeviceStorage": result(try Self.prepareDeviceStorage(call))
        case "eraseDeviceStorage": try Self.eraseDeviceStorage(call); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "system_protection_unavailable", message: "系统保护存储不可用", details: nil))
      }
    }
  }
  private static func eraseDeviceStorage(_ call: FlutterMethodCall) throws {
    let manager = FileManager.default
    guard let args = call.arguments as? [String: Any] else { throw CocoaError(.fileReadInvalidFileName) }
    var target = try deviceStorageRoot()
    if let user = args["user_id"] {
      guard let user = user as? String, !user.isEmpty, user.utf8.count <= 120, !user.contains(":") else { throw CocoaError(.fileReadInvalidFileName) }
      let name = user.utf8.map { String(format: "%02x", $0) }.joined()
      target.appendPathComponent(name, isDirectory: true)
    }
    guard target.resolvingSymlinksInPath().path == target.path else { throw CocoaError(.fileReadInvalidFileName) }
    if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
    if manager.fileExists(atPath: target.path) { throw CocoaError(.fileWriteUnknown) }
  }

  /// 账户签名在秘密生成前验证目录保护；已有目录缺状态时由读取接口明确失败。
  private static func prepareDeviceStorage(_ call: FlutterMethodCall) throws -> String {
    guard let args = call.arguments as? [String: Any], let user = args["user_id"] as? String,
          !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !user.contains(":"), user.utf8.count <= 120 else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let manager = FileManager.default
    // 系统容器路径可能含/var别名；先规范平台给出的根，再拒绝设备子目录链接。
    let root = try deviceStorageRoot()
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
    return target.path
  }

  private static func syncProtectedDirectory(_ url: URL) throws {
    let descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
    guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { close(descriptor) }
    guard fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
  }

  private static func syncWipeLayout() throws {
    let base = try support()
    try syncProtectedDirectory(base.appendingPathComponent("wipe", isDirectory: true))
    try syncProtectedDirectory(base)
  }

  private static func deviceStorageRoot() throws -> URL {
    let root = try support().appendingPathComponent("device", isDirectory: true)
    var info = stat()
    if lstat(root.path, &info) != 0 {
      if errno == ENOENT { return root }
      throw CocoaError(.fileReadUnknown)
    }
    guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
          info.st_uid == geteuid(), root.resolvingSymlinksInPath().path == root.path else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    return root
  }

  private static func prepareWipeDirectory() throws -> URL {
    let root = try support().appendingPathComponent("wipe", isDirectory: true)
    let manager = FileManager.default
    if !manager.fileExists(atPath: root.path) {
      try manager.createDirectory(at: root, withIntermediateDirectories: false)
    }
    guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    try protect(root)
    return root
  }

  private static func support() throws -> URL {
    guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      throw CocoaError(.fileNoSuchFile)
    }
    let canonical = root.resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: canonical, withIntermediateDirectories: true)
    return canonical
  }
  static func protect(_ url: URL) throws {
    let manager = FileManager.default
    let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
    // 拒绝符号链接；系统路径别名不按字符串差异拒绝。
    guard values.isSymbolicLink != true else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
      .posixPermissions: values.isDirectory == true ? 0o700 : 0o600], ofItemAtPath: url.path)
    var target = url
    var excluded = URLResourceValues(); excluded.isExcludedFromBackup = true
    try target.setResourceValues(excluded)
    guard try manager.attributesOfItem(atPath: url.path)[.protectionKey] as? FileProtectionType ==
            .completeUntilFirstUserAuthentication,
          (try manager.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ==
            (values.isDirectory == true ? 0o700 : 0o600),
          try target.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
      throw CocoaError(.fileWriteUnknown)
    }
  }
  static func prepareRecords() throws -> URL {
    let target = try support().appendingPathComponent("citizenapp_records", isDirectory: true)
    let manager = FileManager.default
    if !manager.fileExists(atPath: target.path) {
      try manager.createDirectory(at: target, withIntermediateDirectories: false,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o700])
    }
    try protect(target)
    for file in try manager.contentsOfDirectory(at: target, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
      guard ["identity.json", "lock.json", "registration.json", "identity.json.lock", "lock.json.lock",
             "identity.json.part", "lock.json.part", "registration.json.lock", "registration.json.part"].contains(file.lastPathComponent) else {
        throw CocoaError(.fileReadInvalidFileName)
      }
      try protect(file)
    }
    let descriptor = open(target.path, O_RDONLY | O_DIRECTORY)
    guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { close(descriptor) }
    guard fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
    return target
  }
  /// 原生文件描述符锁覆盖完整比较与提交；Dart进程级锁不能隔离同进程的多个isolate。
  static func compareRecordFile(root: URL, name: String, expected: String?, next: String) throws -> Bool {
    guard ["identity.json", "lock.json", "registration.json"].contains(name), next.utf8.count <= 262144,
          let bytes = next.data(using: .utf8),
          let values = try JSONSerialization.jsonObject(with: bytes) as? [String: String] else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    _ = values
    try protect(root)
    let target = root.appendingPathComponent(name)
    let part = root.appendingPathComponent(name + ".part")
    let lock = root.appendingPathComponent(name + ".lock")
    for file in [target, part, lock] where FileManager.default.fileExists(atPath: file.path) {
      let type = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
      guard type.isSymbolicLink != true, type.isRegularFile == true else { throw CocoaError(.fileReadInvalidFileName) }
      try protect(file)
    }
    let descriptor = open(lock.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { _ = flock(descriptor, LOCK_UN) }
    let existing = FileManager.default.fileExists(atPath: target.path) ? try String(contentsOf: target, encoding: .utf8) : nil
    guard existing == expected else { return false }
    guard FileManager.default.createFile(atPath: part.path, contents: nil,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o600]) else {
      throw CocoaError(.fileWriteUnknown)
    }
    let handle = try FileHandle(forWritingTo: part)
    do { try handle.write(contentsOf: bytes); try handle.synchronize(); try handle.close() }
    catch { try? handle.close(); throw error }
    try protect(part)
    guard rename(part.path, target.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    try protect(target); try protect(lock)
    let parent = open(root.path, O_RDONLY | O_DIRECTORY)
    guard parent >= 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { close(parent) }
    guard fsync(parent) == 0, try String(contentsOf: target, encoding: .utf8) == next else { throw CocoaError(.fileWriteUnknown) }
    return true
  }

  static func protectUserDatabase(_ directory: String) throws {
    let root = try support()
    guard URL(fileURLWithPath: directory).standardizedFileURL.path == root.path else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    // 首次开库前给父目录设置继承保护；只对User数据库文件排除备份，不遍历其他业务库。
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: root.path)
    for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
      if file.lastPathComponent == "citizenapp_user.isar" ||
          file.lastPathComponent.hasPrefix("citizenapp_user.isar.") {
        try protect(file)
      }
    }
  }
  static func eraseObsoleteDataMaterial() throws {
    // 只查询公开标签，不索取秘密或钥引用；只删除已核验属于旧App数据金库的命名空间。
    var attributes: CFTypeRef?
    let status = SecItemCopyMatching([kSecClass: kSecClassKey, kSecReturnAttributes: true,
      kSecMatchLimit: kSecMatchLimitAll] as CFDictionary, &attributes)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw CocoaError(.fileWriteUnknown) }
    for item in attributes as? [[String: Any]] ?? [] {
      guard let tag = item[kSecAttrApplicationTag as String] as? Data,
            let label = String(data: tag, encoding: .utf8) else { continue }
      let prefix = "citizenapp.device_data_key."
      let owned = label.hasPrefix(prefix) && !label.dropFirst(prefix.count).isEmpty &&
        label.dropFirst(prefix.count).allSatisfy({ $0.isASCII && $0.isNumber })
      if owned || label == "fss.enclave.flutter_secure_storage_service" {
        try deleteItem([kSecClass: kSecClassKey, kSecAttrApplicationTag: tag])
      }
    }
    // 官方插件默认service只由App旧通用存储使用；CitizenSDK钱包不依赖该插件。
    try deleteItem([kSecClass: kSecClassGenericPassword, kSecAttrService: "flutter_secure_storage_service"])
  }
  private static func deleteItem(_ query: [CFString: Any]) throws {
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound,
          SecItemCopyMatching(query as CFDictionary, nil) == errSecItemNotFound else {
      throw CocoaError(.fileWriteUnknown)
    }
  }
}
