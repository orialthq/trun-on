import CryptoKit
import Foundation
import ImageIO

/// Mirror of `share/IncomingShareIngestor.kt` for the iOS picker path.
///
/// Android ingests from a content URI carried by an intent; iOS ingests from a
/// file URL produced by the photo picker. Everything after that — the limits, the
/// magic-byte check, the temporary-then-rename copy, and the rejection behaviour —
/// is kept identical so a screenshot accepted on one platform is accepted on both.
final class IncomingShareIngestor {
  static let attachmentDirectoryName = "incoming_share_attachments"
  static let maxAttachmentCount = 8
  static let maxAttachmentBytes: Int64 = 12 * 1024 * 1024
  static let maxTotalBytes: Int64 = 60 * 1024 * 1024
  static let maxImageDimension = 20_000
  static let maxImagePixels: Int64 = 100_000_000

  private static let imageHeaderBytes = 12
  private static let copyBufferBytes = 64 * 1024
  private static let supportedMimeTypes: Set<String> = [
    "image/jpeg", "image/png", "image/webp",
  ]

  static let shared = IncomingShareIngestor()

  private let fileManager = FileManager.default

  private lazy var attachmentDirectory: URL? = {
    guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
      return nil
    }
    let directory = base.appendingPathComponent(
      IncomingShareIngestor.attachmentDirectoryName,
      isDirectory: true
    )
    do {
      try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
      // Android keeps attachments in noBackupFilesDir; match that here.
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

  /// Copies every picked image into app-private storage and returns the payload the
  /// pending queue stores. Returns `nil` — after deleting anything already copied —
  /// when any image fails validation, matching the Android all-or-nothing behaviour.
  func ingest(
    sourceURLs: [URL],
    declaredMimeType: String?,
    sourcePackage: String?
  ) -> IncomingSharePayload? {
    let normalizedDeclared = Self.normalizeMimeType(declaredMimeType)
    if normalizedDeclared != nil,
      normalizedDeclared != "image/*",
      !Self.supportedMimeTypes.contains(normalizedDeclared!)
    {
      return nil
    }

    var copied: [IncomingShareAttachment] = []
    do {
      guard !sourceURLs.isEmpty, sourceURLs.count <= Self.maxAttachmentCount else {
        throw InvalidIncomingImage()
      }
      var copiedBytes: Int64 = 0
      for url in sourceURLs {
        let remainingTotalBytes = Self.maxTotalBytes - copiedBytes
        guard remainingTotalBytes > 0 else {
          throw InvalidIncomingImage()
        }
        let attachment = try copyAndValidate(
          url: url,
          declaredMimeType: normalizedDeclared,
          maxBytes: min(Self.maxAttachmentBytes, remainingTotalBytes)
        )
        copied.append(attachment)
        copiedBytes += attachment.byteSize
      }

      guard let first = copied.first else {
        throw InvalidIncomingImage()
      }
      return IncomingSharePayload(
        id: UUID().uuidString,
        receivedAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
        sharedText: "",
        discoveredUrl: nil,
        sourcePackage: sourcePackage,
        mimeType: first.mimeType,
        wasTruncated: false,
        originalLength: 0,
        shareKind: ShareKind.image,
        attachments: copied
      )
    } catch {
      deleteAttachments(copied)
      return nil
    }
  }

  func deleteAttachments(_ attachments: [IncomingShareAttachment]) {
    for attachment in attachments {
      deleteManagedAttachment(filePath: attachment.filePath)
    }
  }

  private func copyAndValidate(
    url: URL,
    declaredMimeType: String?,
    maxBytes: Int64
  ) throws -> IncomingShareAttachment {
    guard let attachmentDirectory else {
      throw InvalidIncomingImage()
    }

    let providerMimeType = Self.normalizeMimeType(Self.mimeType(for: url))
    let attachmentId = UUID().uuidString
    let temporaryURL = attachmentDirectory.appendingPathComponent(".\(attachmentId).part")
    var finalURL: URL?

    do {
      let copyResult = try copyToTemporaryFile(
        from: url,
        to: temporaryURL,
        maxBytes: maxBytes
      )
      guard let format = IncomingImageSignature.detect(header: copyResult.header) else {
        throw InvalidIncomingImage()
      }
      try validateMimeType(
        declaredMimeType: declaredMimeType,
        providerMimeType: providerMimeType,
        detectedMimeType: format.mimeType
      )

      let dimensions = readDimensions(url: temporaryURL)
      guard dimensions.width > 0,
        dimensions.height > 0,
        dimensions.width <= Self.maxImageDimension,
        dimensions.height <= Self.maxImageDimension,
        Int64(dimensions.width) * Int64(dimensions.height) <= Self.maxImagePixels
      else {
        throw InvalidIncomingImage()
      }

      let destination = attachmentDirectory.appendingPathComponent(
        "\(attachmentId).\(format.fileExtension)"
      )
      guard !fileManager.fileExists(atPath: destination.path) else {
        throw InvalidIncomingImage()
      }
      finalURL = destination
      try fileManager.moveItem(at: temporaryURL, to: destination)

      return IncomingShareAttachment(
        id: attachmentId,
        filePath: destination.path,
        mimeType: format.mimeType,
        byteSize: copyResult.byteSize,
        width: dimensions.width,
        height: dimensions.height,
        sha256: copyResult.sha256
      )
    } catch {
      try? fileManager.removeItem(at: temporaryURL)
      if let finalURL {
        try? fileManager.removeItem(at: finalURL)
      }
      throw InvalidIncomingImage()
    }
  }

  private func copyToTemporaryFile(
    from url: URL,
    to temporaryURL: URL,
    maxBytes: Int64
  ) throws -> CopiedFile {
    let hasSecurityScope = url.startAccessingSecurityScopedResource()
    defer {
      if hasSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }

    guard fileManager.createFile(
      atPath: temporaryURL.path,
      contents: nil,
      attributes: [.protectionKey: FileProtectionType.complete]
    ) else {
      throw InvalidIncomingImage()
    }

    let input = try FileHandle(forReadingFrom: url)
    defer { try? input.close() }
    let output = try FileHandle(forWritingTo: temporaryURL)
    defer { try? output.close() }

    var hasher = SHA256()
    var header: [UInt8] = []
    var byteSize: Int64 = 0

    while true {
      let chunk = try input.read(upToCount: Self.copyBufferBytes) ?? Data()
      if chunk.isEmpty {
        break
      }
      byteSize += Int64(chunk.count)
      if byteSize > maxBytes {
        throw InvalidIncomingImage()
      }
      if header.count < Self.imageHeaderBytes {
        header.append(contentsOf: chunk.prefix(Self.imageHeaderBytes - header.count))
      }
      hasher.update(data: chunk)
      try output.write(contentsOf: chunk)
    }
    try output.synchronize()

    guard byteSize > 0 else {
      throw InvalidIncomingImage()
    }

    return CopiedFile(
      byteSize: byteSize,
      header: header,
      sha256: hasher.finalize().map { String(format: "%02x", $0) }.joined()
    )
  }

  /// Reads the pixel size from metadata only, the way Android uses
  /// `BitmapFactory.Options.inJustDecodeBounds`.
  private func readDimensions(url: URL) -> (width: Int, height: Int) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      return (0, 0)
    }
    return (width, height)
  }

  private func validateMimeType(
    declaredMimeType: String?,
    providerMimeType: String?,
    detectedMimeType: String
  ) throws {
    if let declaredMimeType,
      declaredMimeType != "image/*",
      declaredMimeType != detectedMimeType
    {
      throw InvalidIncomingImage()
    }
    if let providerMimeType,
      providerMimeType != "image/*",
      providerMimeType != detectedMimeType
    {
      throw InvalidIncomingImage()
    }
  }

  private func deleteManagedAttachment(filePath: String) {
    guard let attachmentDirectory else { return }
    let root = URL(fileURLWithPath: attachmentDirectory.path).standardizedFileURL
    let file = URL(fileURLWithPath: filePath).standardizedFileURL
    guard file.deletingLastPathComponent() == root else { return }
    try? fileManager.removeItem(at: file)
  }

  private struct CopiedFile {
    let byteSize: Int64
    let header: [UInt8]
    let sha256: String
  }

  private struct InvalidIncomingImage: Error {}

  static func normalizeMimeType(_ value: String?) -> String? {
    guard let value else { return nil }
    let normalized = value
      .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    guard !normalized.isEmpty else { return nil }
    switch normalized {
    case "image/jpg", "image/pjpeg": return "image/jpeg"
    case "image/x-png": return "image/png"
    default: return normalized
    }
  }

  private static func mimeType(for url: URL) -> String? {
    switch url.pathExtension.lowercased() {
    case "jpg", "jpeg": return "image/jpeg"
    case "png": return "image/png"
    case "webp": return "image/webp"
    default: return nil
    }
  }
}
