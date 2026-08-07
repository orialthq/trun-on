import Foundation

/// Durable, acknowledge-after-save inbox for small `.trunon` documents.
final class PortableTipInbox {
  static let shared = PortableTipInbox()

  var onPendingChanged: (() -> Void)?

  private let maximumBytes = 64 * 1024
  private let fileManager = FileManager.default
  private lazy var directoryURL: URL? = {
    guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
      return nil
    }
    let directory = base.appendingPathComponent("portable_tip_inbox", isDirectory: true)
    do {
      try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true
      var mutableDirectory = directory
      try? mutableDirectory.setResourceValues(resourceValues)
      return directory
    } catch {
      return nil
    }
  }()

  private init() {}

  @discardableResult
  func stage(url: URL) -> Bool {
    guard url.pathExtension.lowercased() == "trunon", let directoryURL else {
      return false
    }
    let hasSecurityScope = url.startAccessingSecurityScopedResource()
    defer {
      if hasSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }
    do {
      let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard values.isRegularFile != false,
        let size = values.fileSize,
        size > 0,
        size <= maximumBytes
      else {
        return false
      }
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      guard data.count > 0,
        data.count <= maximumBytes,
        String(data: data, encoding: .utf8) != nil
      else {
        return false
      }
      let destination = directoryURL
        .appendingPathComponent(UUID().uuidString.lowercased())
        .appendingPathExtension("trunon")
      try data.write(to: destination, options: [.atomic, .completeFileProtection])
      onPendingChanged?()
      return true
    } catch {
      return false
    }
  }

  func pending() -> [[String: String]] {
    guard let directoryURL,
      let files = try? fileManager.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }
    return files
      .filter { $0.pathExtension.lowercased() == "trunon" }
      .sorted { left, right in
        let leftValues = try? left.resourceValues(forKeys: [.contentModificationDateKey])
        let rightValues = try? right.resourceValues(forKeys: [.contentModificationDateKey])
        let leftDate = leftValues?.contentModificationDate ?? .distantPast
        let rightDate = rightValues?.contentModificationDate ?? .distantPast
        return leftDate < rightDate
      }
      .compactMap { file in
        guard UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
          let data = try? Data(contentsOf: file),
          data.count > 0,
          data.count <= maximumBytes,
          let contents = String(data: data, encoding: .utf8)
        else {
          return nil
        }
        return [
          "transportId": file.deletingPathExtension().lastPathComponent,
          "contents": contents,
        ]
      }
  }

  func acknowledge(transportIds: [String]) {
    guard let directoryURL else { return }
    for transportId in transportIds where UUID(uuidString: transportId) != nil {
      let target = directoryURL
        .appendingPathComponent(transportId)
        .appendingPathExtension("trunon")
      try? fileManager.removeItem(at: target)
    }
  }
}
