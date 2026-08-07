import Foundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// iOS entry point for the picker path Android exposes through its quick settings
/// tile (`MainActivity.launchCapturePicker`).
///
/// `PHPickerViewController` runs out of process, so no photo library permission and
/// no `NSPhotoLibraryUsageDescription` are required. Selected images are never handed
/// back to Dart directly: they go through the ingestor into the pending queue, and
/// Dart is told to drain — the same ordering Android uses so a snapshot commit is
/// still what acknowledges an input.
final class CapturePickerPresenter: NSObject {
  static let shared = CapturePickerPresenter()

  /// Called after at least one image was accepted into the pending queue.
  var onPendingChanged: (() -> Void)?

  private var isPresenting = false
  /// `PHPickerViewController.delegate` is weak, so the delegate has to be held
  /// here. Without this it deallocates immediately and selecting a photo silently
  /// does nothing.
  private var activeDelegate: PickerDelegate?

  private override init() {
    super.init()
  }

  func present(completion: @escaping (Result<Bool, PickerError>) -> Void) {
    guard !isPresenting else {
      completion(.failure(.alreadyPresenting))
      return
    }
    guard let host = Self.topViewController() else {
      completion(.failure(.noHostViewController))
      return
    }

    var configuration = PHPickerConfiguration()
    configuration.filter = .images
    // Android's picker is single-select, and the analyzer still handles one image
    // at a time. Keep the platforms aligned rather than silently dropping extras.
    configuration.selectionLimit = 1

    let picker = PHPickerViewController(configuration: configuration)
    let delegate = PickerDelegate(presenter: self, completion: completion)
    activeDelegate = delegate
    picker.delegate = delegate

    isPresenting = true
    host.present(picker, animated: true)
  }

  fileprivate func finishPresenting() {
    isPresenting = false
    // Released on the next turn so the delegate is not deallocated while its own
    // callback is still running.
    DispatchQueue.main.async { [weak self] in
      self?.activeDelegate = nil
    }
  }

  /// Copies the picked items into a staging directory, ingests them, and records the
  /// payload. Returns true when something was accepted.
  fileprivate func ingest(results: [PHPickerResult], completion: @escaping (Bool) -> Void) {
    guard !results.isEmpty else {
      completion(false)
      return
    }

    let stagingDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("incoming_share_staging", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: stagingDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      completion(false)
      return
    }

    let group = DispatchGroup()
    let stagedLock = NSLock()
    var stagedURLs: [URL] = []
    var stagingFailed = false

    for result in results {
      let provider = result.itemProvider
      guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
        stagingFailed = true
        continue
      }
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
        defer { group.leave() }
        guard let url else {
          stagedLock.lock()
          stagingFailed = true
          stagedLock.unlock()
          return
        }
        // The URL is only valid inside this callback, so copy before returning.
        let destination = stagingDirectory.appendingPathComponent(
          "\(UUID().uuidString).\(url.pathExtension.isEmpty ? "img" : url.pathExtension)"
        )
        do {
          try FileManager.default.copyItem(at: url, to: destination)
          stagedLock.lock()
          stagedURLs.append(destination)
          stagedLock.unlock()
        } catch {
          stagedLock.lock()
          stagingFailed = true
          stagedLock.unlock()
        }
      }
    }

    group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
      defer { try? FileManager.default.removeItem(at: stagingDirectory) }

      guard !stagingFailed, !stagedURLs.isEmpty else {
        completion(false)
        return
      }
      guard let payload = IncomingShareIngestor.shared.ingest(
        sourceURLs: stagedURLs,
        declaredMimeType: nil,
        sourcePackage: nil
      ) else {
        completion(false)
        return
      }
      guard IncomingShareStore.shared.append(payload) else {
        IncomingShareIngestor.shared.deleteAttachments(payload.attachments)
        completion(false)
        return
      }
      self?.onPendingChanged?()
      completion(true)
    }
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    guard var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
      ?? scene?.windows.first?.rootViewController
    else {
      return nil
    }
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }

  enum PickerError: String, Error {
    case alreadyPresenting = "picker_already_presenting"
    case noHostViewController = "picker_unavailable"
  }
}

private final class PickerDelegate: NSObject, PHPickerViewControllerDelegate {
  private weak var presenter: CapturePickerPresenter?
  private let completion: (Result<Bool, CapturePickerPresenter.PickerError>) -> Void

  init(
    presenter: CapturePickerPresenter,
    completion: @escaping (Result<Bool, CapturePickerPresenter.PickerError>) -> Void
  ) {
    self.presenter = presenter
    self.completion = completion
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    presenter?.finishPresenting()

    guard let presenter else {
      completion(.success(false))
      return
    }
    presenter.ingest(results: results) { [completion] accepted in
      DispatchQueue.main.async {
        completion(.success(accepted))
      }
    }
  }
}
