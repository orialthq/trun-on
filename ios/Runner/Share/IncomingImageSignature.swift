import Foundation

struct IncomingImageFormat {
  let mimeType: String
  let fileExtension: String
}

/// Byte-for-byte mirror of `share/IncomingImageSignature.kt`. Both platforms must
/// accept and reject exactly the same headers, so keep the two in sync.
enum IncomingImageSignature {
  private static let jpeg = IncomingImageFormat(mimeType: "image/jpeg", fileExtension: "jpg")
  private static let png = IncomingImageFormat(mimeType: "image/png", fileExtension: "png")
  private static let webp = IncomingImageFormat(mimeType: "image/webp", fileExtension: "webp")

  static func detect(header: [UInt8]) -> IncomingImageFormat? {
    if header.count >= 3,
      header[0] == 0xff,
      header[1] == 0xd8,
      header[2] == 0xff
    {
      return jpeg
    }

    if header.count >= 8,
      header[0] == 0x89,
      header[1] == 0x50,
      header[2] == 0x4e,
      header[3] == 0x47,
      header[4] == 0x0d,
      header[5] == 0x0a,
      header[6] == 0x1a,
      header[7] == 0x0a
    {
      return png
    }

    if header.count >= 12,
      String(decoding: header[0..<4], as: UTF8.self) == "RIFF",
      String(decoding: header[8..<12], as: UTF8.self) == "WEBP"
    {
      return webp
    }

    return nil
  }
}
