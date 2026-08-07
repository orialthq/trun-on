import XCTest

@testable import Runner

/// Swift counterpart of `IncomingImageSignatureTest.kt`. The two platforms must
/// accept and reject the same bytes, so every case here has a Kotlin twin.
final class IncomingImageSignatureTests: XCTestCase {
  func testDetectsSupportedImageSignatures() {
    XCTAssertEqual(
      IncomingImageSignature.detect(header: [0xff, 0xd8, 0xff])?.mimeType,
      "image/jpeg"
    )
    XCTAssertEqual(
      IncomingImageSignature.detect(
        header: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
      )?.mimeType,
      "image/png"
    )
    XCTAssertEqual(
      IncomingImageSignature.detect(header: Array("RIFF1234WEBP".utf8))?.mimeType,
      "image/webp"
    )
  }

  func testRejectsExtensionsAndTruncatedHeadersWithoutMatchingMagicBytes() {
    XCTAssertNil(IncomingImageSignature.detect(header: Array("photo.png".utf8)))
    XCTAssertNil(IncomingImageSignature.detect(header: Array("RIFF1234".utf8)))
    XCTAssertNil(IncomingImageSignature.detect(header: []))
  }

  func testNormalizesKnownMimeAliasesAndParameters() {
    XCTAssertEqual(
      IncomingShareIngestor.normalizeMimeType(" IMAGE/JPG; charset=binary "),
      "image/jpeg"
    )
    XCTAssertEqual(
      IncomingShareIngestor.normalizeMimeType("image/x-png"),
      "image/png"
    )
    XCTAssertEqual(
      IncomingShareIngestor.normalizeMimeType("image/webp"),
      "image/webp"
    )
    XCTAssertNil(IncomingShareIngestor.normalizeMimeType(nil))
    XCTAssertNil(IncomingShareIngestor.normalizeMimeType("   "))
  }

  func testExposesTheSameIngestionLimitsAsAndroid() {
    XCTAssertEqual(
      IncomingShareIngestor.attachmentDirectoryName,
      "incoming_share_attachments"
    )
    XCTAssertEqual(IncomingShareIngestor.maxAttachmentCount, 8)
    XCTAssertEqual(IncomingShareIngestor.maxAttachmentBytes, 12 * 1024 * 1024)
    XCTAssertEqual(IncomingShareIngestor.maxTotalBytes, 60 * 1024 * 1024)
    XCTAssertEqual(IncomingShareIngestor.maxImageDimension, 20_000)
    XCTAssertEqual(IncomingShareIngestor.maxImagePixels, 100_000_000)
  }
}
