import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testPackageInfoUsesInstalledBundleVersion() {
    let info = AppDelegate.packageInfo(
      infoDictionary: [
        "CFBundleShortVersionString": "1.2.3",
        "CFBundleVersion": "456",
      ],
      bundleIdentifier: "com.crcfrcn.citizenapp"
    )
    XCTAssertEqual(info["packageName"] as? String, "com.crcfrcn.citizenapp")
    XCTAssertEqual(info["versionName"] as? String, "1.2.3")
    XCTAssertEqual(info["versionCode"] as? Int, 456)
  }

  func testSquareVideoRequestAcceptsOnlyCanonicalEnvelope() throws {
    let request = try SquareVideoRequest(arguments: squareVideoArguments())
    XCTAssertEqual(request.maxWidth, 854)
    XCTAssertEqual(request.audioSampleRate, 48_000)
    XCTAssertEqual(request.keyFrameIntervalSeconds, 2)

    var invalid = squareVideoArguments()
    invalid["audio_sample_rate"] = 44_100
    XCTAssertThrowsError(try SquareVideoRequest(arguments: invalid))
  }

  func testSquareMediaCapabilitiesAlwaysContainFailClosedFlags() {
    let capabilities = SquareVideoTranscoder().capabilities()
    XCTAssertEqual(Set(capabilities.keys), Set(["can_encode_hevc", "can_decode_hevc"]))
  }

  func testApnsEnvironmentUsesEmbeddedProvisioningProfile() throws {
    XCTAssertEqual(
      try AppDelegate.apnsEnvironment(
        provisioningProfileData: provisioningProfile(environment: "development"),
        hasAppStoreReceipt: false
      ),
      "sandbox"
    )
    XCTAssertEqual(
      try AppDelegate.apnsEnvironment(
        provisioningProfileData: provisioningProfile(environment: "production"),
        hasAppStoreReceipt: false
      ),
      "production"
    )
    XCTAssertThrowsError(
      try AppDelegate.apnsEnvironment(
        provisioningProfileData: provisioningProfile(environment: "sandbox"),
        hasAppStoreReceipt: false
      )
    )
    XCTAssertThrowsError(
      try AppDelegate.apnsEnvironment(
        provisioningProfileData: provisioningProfile(environment: nil),
        hasAppStoreReceipt: false
      )
    )
  }

  func testApnsEnvironmentUsesProductionOnlyForStoreReceiptWithoutProfile() throws {
    XCTAssertEqual(
      try AppDelegate.apnsEnvironment(
        provisioningProfileData: nil,
        hasAppStoreReceipt: true
      ),
      "production"
    )
    XCTAssertThrowsError(
      try AppDelegate.apnsEnvironment(
        provisioningProfileData: nil,
        hasAppStoreReceipt: false
      )
    )
    XCTAssertThrowsError(
      try AppDelegate.apnsEnvironment(
        provisioningProfileData: Data("not-a-profile".utf8),
        hasAppStoreReceipt: true
      )
    )
  }

  private func provisioningProfile(environment: String?) -> Data {
    let environmentEntry = environment.map {
      "<key>aps-environment</key><string>\($0)</string>"
    } ?? ""
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict>
      <key>Entitlements</key><dict>\(environmentEntry)</dict>
    </dict></plist>
    """
    var profile = Data([0xff, 0x00, 0x01])
    profile.append(Data(plist.utf8))
    profile.append(Data([0x00, 0xfe]))
    return profile
  }

  private func squareVideoArguments() -> [String: Any] {
    [
      "input_path": "/tmp/input.mov",
      "output_path": "/tmp/output.mp4",
      "cover_path": "/tmp/cover.png",
      "max_width": 854,
      "max_height": 480,
      "video_bitrate": 504_000,
      "total_peak_bitrate": 900_000,
      "audio_bitrate": 96_000,
      "audio_sample_rate": 48_000,
      "max_frame_rate": 30,
      "key_frame_interval_seconds": 2,
      "max_duration_seconds": 180,
      "max_bytes": 16_000_000,
      "cover_max_edge": 720,
      "cover_quality": 75,
      "cover_max_bytes": 512_000,
    ]
  }

  func testSystemProtectedFilesReadBackProtectionAndPermissions() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: root) }
    let file = root.appendingPathComponent("record.json")
    try Data("public-record".utf8).write(to: file)
    try SystemProtectedDataChannel.protect(root)
    try SystemProtectedDataChannel.protect(file)
    XCTAssertEqual((try manager.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    let attributes = try manager.attributesOfItem(atPath: file.path)
    XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .completeUntilFirstUserAuthentication)
    XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
  }

  func testSystemProtectionRejectsLinksAndForeignDatabaseDirectory() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: root) }
    let file = root.appendingPathComponent("record")
    try Data([1]).write(to: file)
    let link = root.appendingPathComponent("link")
    try manager.createSymbolicLink(at: link, withDestinationURL: file)
    XCTAssertThrowsError(try SystemProtectedDataChannel.protect(link))
    XCTAssertThrowsError(try SystemProtectedDataChannel.protectUserDatabase(root.path))
    XCTAssertEqual(try Data(contentsOf: file), Data([1]))
  }

  func testNativeRecordCasSerializesConcurrentWritersAndRejectsStaleSnapshots() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: root) }
    let results = RecordCasResults()
    DispatchQueue.concurrentPerform(iterations: 2) { index in
      do {
        let success = try SystemProtectedDataChannel.compareRecordFile(root: root, name: "identity.json", expected: nil,
          next: "{\"record\":\"" + String(index) + "\"}")
        results.append(success: success, error: nil)
      } catch { results.append(success: false, error: error) }
    }
    XCTAssertEqual(results.errors.count, 0)
    XCTAssertEqual(results.successes.filter { $0 }.count, 1)
    let committed = try String(contentsOf: root.appendingPathComponent("identity.json"), encoding: .utf8)
    XCTAssertFalse(try SystemProtectedDataChannel.compareRecordFile(root: root, name: "identity.json", expected: nil, next: "{}"))
    XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("identity.json"), encoding: .utf8), committed)
  }
  func testRegistrationRecordCasProtectsAndRejectsUnknownOrStaleNames() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: root) }
    XCTAssertTrue(try SystemProtectedDataChannel.compareRecordFile(root: root, name: "registration.json", expected: nil, next: "{\"context\":\"protected-capability\"}"))
    XCTAssertFalse(try SystemProtectedDataChannel.compareRecordFile(root: root, name: "registration.json", expected: nil, next: "{}"))
    let record = root.appendingPathComponent("registration.json")
    XCTAssertEqual(try manager.attributesOfItem(atPath: record.path)[.posixPermissions] as? Int, 0o600)
    XCTAssertTrue(try record.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    XCTAssertThrowsError(try SystemProtectedDataChannel.compareRecordFile(root: root, name: "registration.json.part", expected: nil, next: "{}"))
    XCTAssertThrowsError(try SystemProtectedDataChannel.compareRecordFile(root: root, name: "../registration.json", expected: nil, next: "{}"))
  }



}

private final class RecordCasResults: @unchecked Sendable {
  private let lock = NSLock()
  private(set) var successes: [Bool] = []
  private(set) var errors: [Error] = []
  func append(success: Bool, error: Error?) {
    lock.lock(); defer { lock.unlock() }
    successes.append(success)
    if let error { errors.append(error) }
  }
}
