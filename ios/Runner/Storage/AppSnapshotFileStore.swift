import Foundation

/// Atomic iOS persistence for the same app snapshot used on Android.
final class AppSnapshotFileStore {
  static let shared = AppSnapshotFileStore()

  private let maximumBytes = 16 * 1024 * 1024
  private let fileManager = FileManager.default
  private lazy var fileURL: URL? = {
    guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
      return nil
    }
    do {
      try fileManager.createDirectory(
        at: base,
        withIntermediateDirectories: true,
        attributes: nil
      )
      return base.appendingPathComponent("app_snapshot.json", isDirectory: false)
    } catch {
      return nil
    }
  }()

  private init() {}

  func load() -> String? {
    guard let fileURL,
      let data = try? Data(contentsOf: fileURL),
      data.count > 0,
      data.count <= maximumBytes
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  func save(_ snapshot: String) -> Bool {
    guard let fileURL,
      let data = snapshot.data(using: .utf8),
      data.count > 0,
      data.count <= maximumBytes
    else {
      return false
    }
    do {
      try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
      return true
    } catch {
      return false
    }
  }
}
