import Foundation

/// Atomic iOS persistence for the same app snapshot used on Android.
final class AppSnapshotFileStore {
  static let shared = AppSnapshotFileStore()

  private let maximumBytes = 16 * 1024 * 1024
  private let fileManager = FileManager.default
  private lazy var applicationSupportURL: URL? = {
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
      return base
    } catch {
      return nil
    }
  }()
  private lazy var fileURL: URL? = applicationSupportURL?.appendingPathComponent(
    "app_snapshot.json",
    isDirectory: false
  )
  private lazy var planFileURL: URL? = applicationSupportURL?.appendingPathComponent(
    "plan_snapshot.json",
    isDirectory: false
  )

  private init() {}

  func load() -> String? {
    load(from: fileURL)
  }

  func save(_ snapshot: String) -> Bool {
    save(snapshot, to: fileURL)
  }

  func loadPlanSnapshot() -> String? {
    load(from: planFileURL)
  }

  func savePlanSnapshot(_ snapshot: String) -> Bool {
    save(snapshot, to: planFileURL)
  }

  private func load(from fileURL: URL?) -> String? {
    guard let fileURL,
      let data = try? Data(contentsOf: fileURL),
      data.count > 0,
      data.count <= maximumBytes
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private func save(_ snapshot: String, to fileURL: URL?) -> Bool {
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
