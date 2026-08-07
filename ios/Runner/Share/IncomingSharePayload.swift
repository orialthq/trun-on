import Foundation

/// Mirrors the payload contract in `share/IncomingShareIntentParser.kt`. iOS has no
/// intent parser, so only the data carriers and share kinds are shared.
enum ShareKind {
  static let text = "text"
  static let image = "image"
}

struct IncomingShareAttachment {
  let id: String
  let filePath: String
  let mimeType: String
  let byteSize: Int64
  let width: Int
  let height: Int
  let sha256: String
}

struct IncomingSharePayload {
  let id: String
  let receivedAtEpochMs: Int64
  let sharedText: String
  let discoveredUrl: String?
  let sourcePackage: String?
  let mimeType: String
  let wasTruncated: Bool
  let originalLength: Int
  let shareKind: String
  let attachments: [IncomingShareAttachment]
}
