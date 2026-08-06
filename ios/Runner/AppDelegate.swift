import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private enum MapProvider: String, CaseIterable {
    case naver
    case kakao
    case google
  }

  private var placeReminderChannel: FlutterMethodChannel?
  private var portableTipChannel: FlutterMethodChannel?
  private var incomingShareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if PortableTipInbox.shared.stage(url: url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let incomingChannel = FlutterMethodChannel(
      name: "com.orialthq.ori_beauty/incoming_share/v1",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    incomingChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "drainPendingShares":
        // iOS screenshot/share ingestion is still handled by the manual picker.
        result([])
      case "loadAppSnapshot":
        result(AppSnapshotFileStore.shared.load())
      case "saveAppSnapshot":
        guard let snapshot = call.arguments as? String, !snapshot.isEmpty else {
          result(
            FlutterError(
              code: "invalid_snapshot",
              message: "App snapshot must be a non-empty string.",
              details: nil
            )
          )
          return
        }
        if AppSnapshotFileStore.shared.save(snapshot) {
          result(true)
        } else {
          result(
            FlutterError(
              code: "snapshot_save_failed",
              message: "App snapshot could not be committed to durable storage.",
              details: nil
            )
          )
        }
      case "acknowledgeShares", "keepSharedSource":
        result(nil)
      case "deleteSharedSource":
        result("unavailable")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    incomingShareChannel = incomingChannel

    let channel = FlutterMethodChannel(
      name: "com.orialthq.ori_beauty/place_reminders/v1",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "map_unavailable",
            message: "The map handler is unavailable.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "getMapProviders":
        result(self.mapProviderOptions())
      case "openMapProvider":
        self.openMap(arguments: call.arguments, result: result)
      case "openMap":
        var arguments = call.arguments as? [String: Any] ?? [:]
        arguments["provider"] = MapProvider.naver.rawValue
        self.openMap(arguments: arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    placeReminderChannel = channel

    let portableChannel = FlutterMethodChannel(
      name: "com.orialthq.ori_beauty/portable_tip/v1",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    portableChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "pendingPackages":
        result(PortableTipInbox.shared.pending())
      case "acknowledgePackages":
        let arguments = call.arguments as? [String: Any]
        let transportIds = arguments?["transportIds"] as? [String] ?? []
        PortableTipInbox.shared.acknowledge(transportIds: transportIds)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    PortableTipInbox.shared.onPendingChanged = { [weak portableChannel] in
      DispatchQueue.main.async {
        portableChannel?.invokeMethod("pendingPackagesChanged", arguments: nil)
      }
    }
    portableTipChannel = portableChannel
  }

  private func mapProviderOptions() -> [[String: Any]] {
    MapProvider.allCases.map { provider in
      [
        "id": provider.rawValue,
        "appInstalled": mapAppURL(provider: provider, query: "Trun On")
          .map(UIApplication.shared.canOpenURL) ?? false,
        "available": true,
      ]
    }
  }

  private func openMap(arguments: Any?, result: @escaping FlutterResult) {
    let values = arguments as? [String: Any]
    guard
      let providerName = values?["provider"] as? String,
      let provider = MapProvider(rawValue: providerName)
    else {
      result(
        FlutterError(
          code: "invalid_map_provider",
          message: "A supported map provider is required.",
          details: nil
        )
      )
      return
    }

    let explicitQuery =
      (values?["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = (values?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let address =
      (values?["address"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let query = explicitQuery?.isEmpty == false
      ? explicitQuery!
      : [name, address]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    guard !query.isEmpty else {
      result(
        FlutterError(
          code: "invalid_place",
          message: "A map query is required.",
          details: nil
        )
      )
      return
    }

    let appURL = mapAppURL(provider: provider, query: query)
    let appInstalled = appURL.map(UIApplication.shared.canOpenURL) ?? false
    guard
      let targetURL = appInstalled ? appURL : mapWebURL(provider: provider, query: query)
    else {
      result(
        FlutterError(
          code: "map_unavailable",
          message: "A map URL could not be created.",
          details: nil
        )
      )
      return
    }

    UIApplication.shared.open(targetURL, options: [:]) { opened in
      DispatchQueue.main.async {
        if opened {
          result([
            "provider": provider.rawValue,
            "openedInApp": appInstalled,
          ])
        } else {
          result(
            FlutterError(
              code: "map_unavailable",
              message: "No map app or browser could open the place.",
              details: nil
            )
          )
        }
      }
    }
  }

  private func mapAppURL(provider: MapProvider, query: String) -> URL? {
    var components: URLComponents
    switch provider {
    case .naver:
      components = URLComponents()
      components.scheme = "nmap"
      components.host = "search"
      components.queryItems = [
        URLQueryItem(name: "query", value: query),
        URLQueryItem(
          name: "appname",
          value: Bundle.main.bundleIdentifier ?? "com.orialthq.ori_beauty"
        ),
      ]
    case .kakao:
      components = URLComponents()
      components.scheme = "kakaomap"
      components.host = "search"
      components.queryItems = [URLQueryItem(name: "q", value: query)]
    case .google:
      components = URLComponents(string: "comgooglemaps://") ?? URLComponents()
      components.queryItems = [URLQueryItem(name: "q", value: query)]
    }
    return components.url
  }

  private func mapWebURL(provider: MapProvider, query: String) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    switch provider {
    case .naver:
      components.host = "map.naver.com"
      components.path = "/p/search/\(query)"
    case .kakao:
      components.host = "map.kakao.com"
      components.path = "/link/search/\(query)"
    case .google:
      components.host = "www.google.com"
      components.path = "/maps/search/"
      components.queryItems = [
        URLQueryItem(name: "api", value: "1"),
        URLQueryItem(name: "query", value: query),
      ]
    }
    return components.url
  }
}

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
