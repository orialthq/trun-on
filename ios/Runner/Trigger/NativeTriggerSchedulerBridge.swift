import CoreLocation
import Flutter
import Foundation
import UserNotifications

private struct NativeTriggerLocation: Codable, Equatable {
  let latitude: Double
  let longitude: Double
  let radiusMeters: Double
}

private struct NativeTriggerAlarmSchedule: Codable, Equatable {
  let firstFireAtMillis: Int64
  let timeZoneId: String?
}

private struct NativeTriggerTimeWindow: Codable, Equatable {
  let daysOfWeek: Set<Int>
  let startMinuteOfDay: Int
  let endMinuteOfDay: Int
  let timeZoneId: String?
}

private struct NativeTriggerRule: Codable, Equatable {
  let id: String
  let destinationId: String
  let title: String
  let message: String
  let location: NativeTriggerLocation?
  let alarmSchedule: NativeTriggerAlarmSchedule?
  let enabled: Bool
  let activeFromMillis: Int64?
  let activeUntilMillis: Int64?
  let timeWindow: NativeTriggerTimeWindow?
  let cooldownMillis: Int64
  let dedupeWindowMillis: Int64
  let recurrence: String
  let laterDelayMillis: Int64
  let createdAtMillis: Int64
  let updatedAtMillis: Int64

  static func decode(_ raw: Any?) throws -> NativeTriggerRule {
    guard let map = raw as? [String: Any] else {
      throw NativeTriggerError.invalid("rule must be a map")
    }
    let id = try map.requiredString("id")
    let destinationId = map.optionalString("destinationId") ?? id
    let title = try map.requiredString("title")
    let now = NativeTriggerClock.nowMillis

    let location: NativeTriggerLocation?
    if let locationMap = map["location"] as? [String: Any] {
      let latitude = try locationMap.requiredDouble("latitude")
      let longitude = try locationMap.requiredDouble("longitude")
      let radius = try locationMap.requiredDouble("radiusMeters")
      guard (-90...90).contains(latitude), (-180...180).contains(longitude),
        (50...10_000).contains(radius)
      else {
        throw NativeTriggerError.invalid("location values are out of range")
      }
      location = NativeTriggerLocation(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius
      )
    } else {
      location = nil
    }

    let alarmSchedule: NativeTriggerAlarmSchedule?
    if let alarmMap = map["alarmSchedule"] as? [String: Any] {
      alarmSchedule = NativeTriggerAlarmSchedule(
        firstFireAtMillis: try alarmMap.requiredInt64("firstFireAtMillis"),
        timeZoneId: alarmMap.optionalString("timeZoneId")
      )
    } else {
      alarmSchedule = nil
    }

    guard (location == nil) != (alarmSchedule == nil) else {
      throw NativeTriggerError.invalid("a rule requires exactly one location or alarm schedule")
    }

    let timeWindow: NativeTriggerTimeWindow?
    if let windowMap = map["timeWindow"] as? [String: Any] {
      let days = Set(
        (windowMap["daysOfWeek"] as? [Any] ?? []).compactMap { ($0 as? NSNumber)?.intValue }
      )
      let normalizedDays = days.isEmpty ? Set(1...7) : days
      let start = try windowMap.requiredInt("startMinuteOfDay")
      let end = try windowMap.requiredInt("endMinuteOfDay")
      guard normalizedDays.allSatisfy({ (1...7).contains($0) }),
        (0..<1_440).contains(start), (0..<1_440).contains(end)
      else {
        throw NativeTriggerError.invalid("time window values are out of range")
      }
      timeWindow = NativeTriggerTimeWindow(
        daysOfWeek: normalizedDays,
        startMinuteOfDay: start,
        endMinuteOfDay: end,
        timeZoneId: windowMap.optionalString("timeZoneId")
      )
    } else {
      timeWindow = nil
    }

    let recurrence = (map.optionalString("recurrence") ?? (location == nil ? "once" : "on_reentry"))
      .lowercased()
    guard ["once", "daily", "weekly", "on_reentry"].contains(recurrence) else {
      throw NativeTriggerError.invalid("unsupported recurrence")
    }
    if recurrence == "on_reentry", location == nil {
      throw NativeTriggerError.invalid("on_reentry recurrence requires location")
    }

    return NativeTriggerRule(
      id: id,
      destinationId: destinationId,
      title: title,
      message: map.optionalString("message") ?? "저장해 둔 내용을 확인해 봐.",
      location: location,
      alarmSchedule: alarmSchedule,
      enabled: map["enabled"] as? Bool ?? true,
      activeFromMillis: map.optionalInt64("activeFromMillis"),
      activeUntilMillis: map.optionalInt64("activeUntilMillis"),
      timeWindow: timeWindow,
      cooldownMillis: max(0, map.optionalInt64("cooldownMillis") ?? 21_600_000),
      dedupeWindowMillis: max(1, map.optionalInt64("dedupeWindowMillis") ?? 60_000),
      recurrence: recurrence,
      laterDelayMillis: max(1_000, map.optionalInt64("laterDelayMillis") ?? 1_800_000),
      createdAtMillis: max(0, map.optionalInt64("createdAtMillis") ?? now),
      updatedAtMillis: max(0, map.optionalInt64("updatedAtMillis") ?? now)
    )
  }

  var wireValue: [String: Any] {
    var result: [String: Any] = [
      "id": id,
      "destinationId": destinationId,
      "title": title,
      "message": message,
      "enabled": enabled,
      "cooldownMillis": cooldownMillis,
      "dedupeWindowMillis": dedupeWindowMillis,
      "recurrence": recurrence,
      "laterDelayMillis": laterDelayMillis,
      "createdAtMillis": createdAtMillis,
      "updatedAtMillis": updatedAtMillis,
    ]
    if let activeFromMillis { result["activeFromMillis"] = activeFromMillis }
    if let activeUntilMillis { result["activeUntilMillis"] = activeUntilMillis }
    if let location {
      result["location"] = [
        "latitude": location.latitude,
        "longitude": location.longitude,
        "radiusMeters": location.radiusMeters,
      ]
    }
    if let alarmSchedule {
      var value: [String: Any] = ["firstFireAtMillis": alarmSchedule.firstFireAtMillis]
      if let timeZoneId = alarmSchedule.timeZoneId { value["timeZoneId"] = timeZoneId }
      result["alarmSchedule"] = value
    }
    if let timeWindow {
      var value: [String: Any] = [
        "daysOfWeek": timeWindow.daysOfWeek.sorted(),
        "startMinuteOfDay": timeWindow.startMinuteOfDay,
        "endMinuteOfDay": timeWindow.endMinuteOfDay,
      ]
      if let timeZoneId = timeWindow.timeZoneId { value["timeZoneId"] = timeZoneId }
      result["timeWindow"] = value
    }
    return result
  }
}

private struct NativeTriggerRuntimeState: Codable {
  let ruleId: String
  var lastEventKey: String?
  var lastEventAtMillis: Int64?
  var lastNotifiedAtMillis: Int64?
  var firstNotifiedAtMillis: Int64?
  var completedAtMillis: Int64?
  var snoozedUntilMillis: Int64?
  var nextAlarmAtMillis: Int64?
  var notificationCount: Int

  init(ruleId: String) {
    self.ruleId = ruleId
    notificationCount = 0
  }

  var wireValue: [String: Any] {
    var result: [String: Any] = [
      "ruleId": ruleId,
      "notificationCount": notificationCount,
    ]
    if let lastEventKey { result["lastEventKey"] = lastEventKey }
    if let lastEventAtMillis { result["lastEventAtMillis"] = lastEventAtMillis }
    if let lastNotifiedAtMillis { result["lastNotifiedAtMillis"] = lastNotifiedAtMillis }
    if let firstNotifiedAtMillis { result["firstNotifiedAtMillis"] = firstNotifiedAtMillis }
    if let completedAtMillis { result["completedAtMillis"] = completedAtMillis }
    if let snoozedUntilMillis { result["snoozedUntilMillis"] = snoozedUntilMillis }
    if let nextAlarmAtMillis { result["nextAlarmAtMillis"] = nextAlarmAtMillis }
    return result
  }
}

private struct PendingNativeTriggerOutcome: Codable {
  let eventId: String
  let ruleId: String
  let kind: String
  let occurredAtMillis: Int64
  let snoozedUntilMillis: Int64?
  let eventKey: String?

  var wireValue: [String: Any] {
    var result: [String: Any] = [
      "eventId": eventId,
      "ruleId": ruleId,
      "kind": kind,
      "occurredAtMillis": occurredAtMillis,
    ]
    if let snoozedUntilMillis { result["snoozedUntilMillis"] = snoozedUntilMillis }
    if let eventKey { result["eventKey"] = eventKey }
    return result
  }
}

private struct PendingNativeTriggerOpen: Codable {
  let eventId: String
  let ruleId: String
  let destinationId: String
  let occurredAtMillis: Int64

  var wireValue: [String: Any] {
    [
      "eventId": eventId,
      "ruleId": ruleId,
      "destinationId": destinationId,
      "occurredAtMillis": occurredAtMillis,
    ]
  }
}

private enum NativeTriggerError: Error, LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}

private enum NativeTriggerClock {
  static var nowMillis: Int64 { Int64(Date().timeIntervalSince1970 * 1_000) }
}

private final class NativeTriggerStore {
  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var rules: [NativeTriggerRule] {
    get { decode([NativeTriggerRule].self, key: Keys.rules) ?? [] }
    set { encode(newValue, key: Keys.rules) }
  }

  var states: [String: NativeTriggerRuntimeState] {
    get { decode([String: NativeTriggerRuntimeState].self, key: Keys.states) ?? [:] }
    set { encode(newValue, key: Keys.states) }
  }

  var outcomes: [PendingNativeTriggerOutcome] {
    get { decode([PendingNativeTriggerOutcome].self, key: Keys.outcomes) ?? [] }
    set { encode(Array(newValue.suffix(100)), key: Keys.outcomes) }
  }

  var opens: [PendingNativeTriggerOpen] {
    get { decode([PendingNativeTriggerOpen].self, key: Keys.opens) ?? [] }
    set { encode(Array(newValue.suffix(100)), key: Keys.opens) }
  }

  func upsert(_ rule: NativeTriggerRule, resetState: Bool) {
    var allRules = rules.filter { $0.id != rule.id }
    allRules.append(rule)
    rules = allRules.sorted { $0.createdAtMillis < $1.createdAtMillis }
    var allStates = states
    if resetState || allStates[rule.id] == nil {
      allStates[rule.id] = NativeTriggerRuntimeState(ruleId: rule.id)
      states = allStates
    }
  }

  @discardableResult
  func remove(_ id: String) -> Bool {
    let before = rules.count
    rules = rules.filter { $0.id != id }
    var allStates = states
    allStates.removeValue(forKey: id)
    states = allStates
    return before != rules.count
  }

  func replace(_ newRules: [NativeTriggerRule], resetStateIds: Set<String>) {
    let incomingIds = Set(newRules.map(\.id))
    let previousStates = states
    rules = newRules
    states = Dictionary(uniqueKeysWithValues: newRules.map { rule in
      let state = resetStateIds.contains(rule.id)
        ? NativeTriggerRuntimeState(ruleId: rule.id)
        : previousStates[rule.id] ?? NativeTriggerRuntimeState(ruleId: rule.id)
      return (rule.id, state)
    }).filter { incomingIds.contains($0.key) }
  }

  func updateState(_ id: String, _ transform: (inout NativeTriggerRuntimeState) -> Void) {
    var allStates = states
    var state = allStates[id] ?? NativeTriggerRuntimeState(ruleId: id)
    transform(&state)
    allStates[id] = state
    states = allStates
  }

  @discardableResult
  func enqueueOutcome(
    ruleId: String,
    kind: String,
    occurredAtMillis: Int64,
    snoozedUntilMillis: Int64? = nil,
    eventKey: String? = nil
  ) -> PendingNativeTriggerOutcome {
    if kind == "fired", let eventKey,
      let existing = outcomes.last(where: {
        $0.ruleId == ruleId && $0.kind == kind && $0.eventKey == eventKey
      })
    {
      return existing
    }
    let event = PendingNativeTriggerOutcome(
      eventId: UUID().uuidString,
      ruleId: ruleId,
      kind: kind,
      occurredAtMillis: occurredAtMillis,
      snoozedUntilMillis: snoozedUntilMillis,
      eventKey: eventKey
    )
    outcomes.append(event)
    return event
  }

  @discardableResult
  func enqueueOpen(
    ruleId: String,
    destinationId: String,
    occurredAtMillis: Int64
  ) -> PendingNativeTriggerOpen {
    if let existing = opens.last(where: {
      $0.ruleId == ruleId && $0.destinationId == destinationId
    }) {
      return existing
    }
    let event = PendingNativeTriggerOpen(
      eventId: UUID().uuidString,
      ruleId: ruleId,
      destinationId: destinationId,
      occurredAtMillis: occurredAtMillis
    )
    opens.append(event)
    return event
  }

  private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? decoder.decode(type, from: data)
  }

  private func encode<T: Encodable>(_ value: T, key: String) {
    guard let data = try? encoder.encode(value) else { return }
    defaults.set(data, forKey: key)
  }

  private enum Keys {
    static let rules = "native_trigger_rules_v1"
    static let states = "native_trigger_states_v1"
    static let outcomes = "native_trigger_pending_outcomes_v1"
    static let opens = "native_trigger_pending_opens_v1"
  }
}

/// iOS counterpart of Android's native trigger channel.
///
/// Time rules use local notifications. Location and location+time rules use
/// Core Location region monitoring so the time window can be checked before a
/// notification is shown. Rules and user interactions are durable in
/// UserDefaults, while OS registrations are rebuilt whenever the app launches.
final class NativeTriggerSchedulerBridge: NSObject, CLLocationManagerDelegate {
  static let channelName = "com.orialthq.ori_beauty/native_triggers/v1"

  private let center: UNUserNotificationCenter
  private let locationManager: CLLocationManager
  private let geocoder: CLGeocoder
  private let store: NativeTriggerStore
  private var channel: FlutterMethodChannel?
  private var pendingRegionCompletions: [String: (String) -> Void] = [:]

  override init() {
    center = .current()
    locationManager = CLLocationManager()
    geocoder = CLGeocoder()
    store = NativeTriggerStore()
    super.init()
    locationManager.delegate = self
  }

  func applicationDidFinishLaunching() {
    registerNotificationCategory()
    restoreRegistrations(emitChanges: false, completion: { _ in })
  }

  func attach(to messenger: FlutterBinaryMessenger) {
    channel?.setMethodCallHandler(nil)
    let next = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    next.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    channel = next
    emitPendingInteractions()
  }

  func detach() {
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  func handleWillPresent(
    _ notification: UNNotification,
    completion: @escaping (UNNotificationPresentationOptions) -> Void
  ) -> Bool {
    guard let ruleId = notification.request.content.userInfo[Payload.ruleId] as? String,
      isNativeIdentifier(notification.request.identifier)
    else {
      return false
    }
    // Region entries are already atomically claimed before this immediate
    // local notification is queued. Recording again while foregrounded would
    // produce two `fired` outcomes for the same physical entry.
    if !notification.request.identifier.hasPrefix(Identifier.locationNotificationPrefix) {
      recordFired(
        ruleId: ruleId,
        requestId: notification.request.identifier,
        occurredAtMillis: Int64(notification.date.timeIntervalSince1970 * 1_000)
      )
    }
    completion([.banner, .list, .sound])
    return true
  }

  func handleResponse(
    _ response: UNNotificationResponse,
    completion: @escaping () -> Void
  ) -> Bool {
    let content = response.notification.request.content
    guard let ruleId = content.userInfo[Payload.ruleId] as? String,
      isNativeIdentifier(response.notification.request.identifier)
    else {
      return false
    }
    let destinationId = (content.userInfo[Payload.destinationId] as? String) ?? ruleId
    let now = NativeTriggerClock.nowMillis
    let requestId = response.notification.request.identifier
    // Location entries are claimed when Core Location delivers the region
    // transition. Recording them again on tap would create two `fired` events.
    if !requestId.hasPrefix(Identifier.locationNotificationPrefix) {
      recordFired(
        ruleId: ruleId,
        requestId: requestId,
        occurredAtMillis: Int64(response.notification.date.timeIntervalSince1970 * 1_000)
      )
    }

    switch response.actionIdentifier {
    case Action.done:
      complete(ruleId: ruleId, at: now)
      _ = store.enqueueOutcome(ruleId: ruleId, kind: "done", occurredAtMillis: now)
      emitOutcomesChanged()
    case Action.later:
      snooze(ruleId: ruleId, requestedAt: now)
    default:
      let opened = store.enqueueOpen(
        ruleId: ruleId,
        destinationId: destinationId,
        occurredAtMillis: now
      )
      invoke("triggerOpened", arguments: opened.wireValue)
      emitOpensChanged()
    }
    completion()
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "schedule":
        let arguments = call.arguments as? [String: Any] ?? [:]
        let rule = try NativeTriggerRule.decode(arguments["rule"])
        let resetState = arguments["resetState"] as? Bool ?? false
        schedule(rule, resetState: resetState, result: result)
      case "cancel":
        let id = try argumentId(call.arguments)
        let removed = store.remove(id)
        cancelRegistrations(id: id)
        result(["id": id, "removed": removed])
      case "sync":
        try sync(call.arguments, result: result)
      case "list":
        let states = store.states
        result(store.rules.map { rule in
          var item: [String: Any] = ["rule": rule.wireValue]
          if let state = states[rule.id] { item["state"] = state.wireValue }
          return item
        })
      case "reset":
        let id = try argumentId(call.arguments)
        guard let rule = store.rules.first(where: { $0.id == id }) else {
          result(["id": id, "status": "registration_failed"])
          return
        }
        store.updateState(id) { $0 = NativeTriggerRuntimeState(ruleId: id) }
        cancelRegistrations(id: id)
        scheduleRegistration(rule) { status in
          result(["id": id, "status": status])
        }
      case "restore":
        restoreRegistrations(emitChanges: true, result: result)
      case "resolveLocation":
        try resolveLocation(call.arguments, result: result)
      case "pendingOutcomes":
        result(store.outcomes.map(\.wireValue))
      case "acknowledgeOutcomes":
        let ids = Set(argumentEventIds(call.arguments))
        store.outcomes = store.outcomes.filter { !ids.contains($0.eventId) }
        result(true)
      case "pendingOpens":
        result(store.opens.map(\.wireValue))
      case "acknowledgeOpens":
        let ids = Set(argumentEventIds(call.arguments))
        store.opens = store.opens.filter { !ids.contains($0.eventId) }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(
        FlutterError(
          code: "invalid_native_trigger",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func schedule(
    _ rule: NativeTriggerRule,
    resetState: Bool,
    result: @escaping FlutterResult
  ) {
    let previous = store.rules.first(where: { $0.id == rule.id })
    let scheduleChanged = previous.map {
      $0.alarmSchedule != rule.alarmSchedule || $0.recurrence != rule.recurrence
    } ?? false
    store.upsert(rule, resetState: resetState || scheduleChanged)
    cancelRegistrations(id: rule.id)
    scheduleRegistration(rule) { [weak self] status in
      guard let self else { return }
      self.notificationPermissionGranted { granted in
        result([
          "status": status,
          "persisted": true,
          "notificationPermissionGranted": granted,
          "rule": rule.wireValue,
        ])
      }
    }
  }

  private func sync(_ raw: Any?, result: @escaping FlutterResult) throws {
    let arguments = raw as? [String: Any] ?? [:]
    let rawRules = arguments["rules"] as? [Any] ?? []
    let rules = try rawRules.map(NativeTriggerRule.decode)
    guard Set(rules.map(\.id)).count == rules.count else {
      throw NativeTriggerError.invalid("trigger ids must be unique")
    }
    guard rules.filter({ $0.location != nil }).count <= 20 else {
      result(syncReport(status: "geofence_limit_exceeded", stored: 0, locations: 0, times: 0))
      return
    }
    let resetIds = Set(arguments["resetStateIds"] as? [String] ?? [])
    let previousById = Dictionary(uniqueKeysWithValues: store.rules.map { ($0.id, $0) })
    let scheduleChangedIds = Set(rules.compactMap { rule -> String? in
      guard let previous = previousById[rule.id] else { return nil }
      return previous.alarmSchedule != rule.alarmSchedule || previous.recurrence != rule.recurrence
        ? rule.id
        : nil
    })
    let previousIds = Set(store.rules.map(\.id))
    store.replace(rules, resetStateIds: resetIds.union(scheduleChangedIds))
    previousIds.union(rules.map(\.id)).forEach(cancelRegistrations)
    restoreRegistrations(emitChanges: true, completion: { report in
      var mutable = report
      mutable["storedRuleCount"] = rules.count
      result(mutable)
    })
  }

  private func scheduleRegistration(
    _ rule: NativeTriggerRule,
    completion: @escaping (String) -> Void
  ) {
    guard rule.enabled, store.states[rule.id]?.completedAtMillis == nil else {
      completion("saved_disabled")
      return
    }
    if rule.recurrence == "once", store.states[rule.id]?.firstNotifiedAtMillis != nil {
      completion("saved_disabled")
      return
    }
    if let activeUntil = rule.activeUntilMillis, activeUntil <= NativeTriggerClock.nowMillis {
      completion("saved_disabled")
      return
    }
    ensureNotificationAuthorization { [weak self] _ in
      guard let self else { return }
      if let location = rule.location {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
          completion("registration_failed")
          return
        }
        guard self.locationAuthorizationIsAlways else {
          self.requestLocationAuthorizationIfNeeded()
          completion("location_permission_required")
          return
        }
        let activeLocationCount = self.store.rules.filter { $0.enabled && $0.location != nil }.count
        guard activeLocationCount <= 20 else {
          completion("geofence_limit_exceeded")
          return
        }
        let systemMaximum = self.locationManager.maximumRegionMonitoringDistance
        let effectiveRadius = systemMaximum > 0
          ? min(location.radiusMeters, systemMaximum)
          : location.radiusMeters
        let region = CLCircularRegion(
          center: CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
          ),
          radius: effectiveRadius,
          identifier: self.regionIdentifier(rule.id)
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        self.pendingRegionCompletions[region.identifier]?("registration_failed")
        self.pendingRegionCompletions[region.identifier] = completion
        self.locationManager.startMonitoring(for: region)
        return
      }
      self.scheduleTimeNotification(rule, completion: completion)
    }
  }

  private func scheduleTimeNotification(
    _ rule: NativeTriggerRule,
    completion: @escaping (String) -> Void
  ) {
    guard let alarm = rule.alarmSchedule else {
      completion("registration_failed")
      return
    }
    let date = Date(timeIntervalSince1970: TimeInterval(alarm.firstFireAtMillis) / 1_000)
    let timeZone = alarm.timeZoneId.flatMap(TimeZone.init(identifier:)) ?? .current
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components: DateComponents
    let repeats: Bool
    switch rule.recurrence {
    case "daily":
      components = calendar.dateComponents([.hour, .minute], from: date)
      repeats = true
    case "weekly":
      components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
      repeats = true
    default:
      components = calendar.dateComponents(
        [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
        from: max(date, Date().addingTimeInterval(1))
      )
      repeats = false
    }
    let content = notificationContent(rule)
    let request = UNNotificationRequest(
      identifier: timeIdentifier(rule.id),
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    )
    center.add(request) { [weak self] error in
      DispatchQueue.main.async {
        if error == nil {
          self?.store.updateState(rule.id) { $0.nextAlarmAtMillis = alarm.firstFireAtMillis }
          completion("registered")
        } else {
          completion("registration_failed")
        }
      }
    }
  }

  private func restoreRegistrations(
    emitChanges: Bool,
    result: @escaping FlutterResult
  ) {
    restoreRegistrations(
      emitChanges: emitChanges,
      completion: { report in result(report) }
    )
  }

  private func restoreRegistrations(
    emitChanges: Bool,
    completion: @escaping ([String: Any]) -> Void
  ) {
    center.getDeliveredNotifications { [weak self] notifications in
      DispatchQueue.main.async {
        guard let self else { return }
        self.reconcileDeliveredNotifications(notifications)
        self.performRestoreRegistrations(emitChanges: emitChanges, completion: completion)
      }
    }
  }

  private func performRestoreRegistrations(
    emitChanges: Bool,
    completion: @escaping ([String: Any]) -> Void
  ) {
    cancelAllNativeRegistrations()
    let eligible = store.rules.filter { rule in
      let state = store.states[rule.id]
      return rule.enabled
        && state?.completedAtMillis == nil
        && !(rule.recurrence == "once" && state?.firstNotifiedAtMillis != nil)
    }
    if eligible.filter({ $0.location != nil }).count > 20 {
      completion(syncReport(status: "geofence_limit_exceeded", stored: eligible.count, locations: 0, times: 0))
      return
    }
    guard !eligible.isEmpty else {
      notificationPermissionGranted { granted in
        completion(self.syncReport(
          status: "registered", stored: 0, locations: 0, times: 0,
          notificationPermissionGranted: granted
        ))
      }
      return
    }

    let group = DispatchGroup()
    var locations = 0
    var times = 0
    var snoozes = 0
    var failed = false
    var locationPermissionRequired = false
    for rule in eligible {
      group.enter()
      scheduleRegistration(rule) { status in
        if status == "registered" {
          if rule.location != nil { locations += 1 } else { times += 1 }
        } else if status == "location_permission_required" {
          locationPermissionRequired = true
        } else if status != "saved_disabled" {
          failed = true
        }
        group.leave()
      }
      if let dueAt = store.states[rule.id]?.snoozedUntilMillis {
        group.enter()
        scheduleSnoozeNotification(rule, dueAt: dueAt) { restored in
          if restored { snoozes += 1 } else { failed = true }
          group.leave()
        }
      }
    }
    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      self.notificationPermissionGranted { granted in
        if emitChanges { self.emitPendingInteractions() }
        completion(self.syncReport(
          status: failed
            ? "registration_failed"
            : (locationPermissionRequired ? "location_permission_required" : "registered"),
          stored: eligible.count,
          locations: locations,
          times: times,
          snoozes: snoozes,
          notificationPermissionGranted: granted
        ))
      }
    }
  }

  private func syncReport(
    status: String,
    stored: Int,
    locations: Int,
    times: Int,
    snoozes: Int? = nil,
    notificationPermissionGranted: Bool? = nil
  ) -> [String: Any] {
    var result: [String: Any] = [
      "status": status,
      "storedRuleCount": stored,
      "restoredGeofenceCount": locations,
      "restoredTimeAlarmCount": times,
      "restoredSnoozeCount": snoozes ?? store.states.values.filter {
        $0.snoozedUntilMillis != nil && $0.completedAtMillis == nil
      }.count,
    ]
    if let notificationPermissionGranted {
      result["notificationPermissionGranted"] = notificationPermissionGranted
    }
    return result
  }

  private func resolveLocation(_ raw: Any?, result: @escaping FlutterResult) throws {
    let query = try (raw as? [String: Any] ?? [:]).requiredString("query")
    geocoder.cancelGeocode()
    geocoder.geocodeAddressString(query) { placemarks, _ in
      DispatchQueue.main.async {
        guard let placemark = placemarks?.first, let location = placemark.location else {
          result(["status": "address_not_found"])
          return
        }
        let address = [
          placemark.administrativeArea,
          placemark.locality,
          placemark.subLocality,
          placemark.thoroughfare,
          placemark.subThoroughfare,
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        result([
          "status": "resolved",
          "latitude": location.coordinate.latitude,
          "longitude": location.coordinate.longitude,
          "formattedAddress": address.isEmpty ? query : address,
        ])
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard let id = ruleId(fromRegionIdentifier: region.identifier),
      let rule = store.rules.first(where: { $0.id == id })
    else { return }
    notificationPermissionGranted { [weak self] granted in
      guard granted else { return }
      self?.fireLocationRule(rule)
    }
  }

  func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
    pendingRegionCompletions.removeValue(forKey: region.identifier)?("registered")
  }

  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    if let identifier = region?.identifier {
      pendingRegionCompletions.removeValue(forKey: identifier)?("registration_failed")
      return
    }
    // Core Location may report a manager-level failure without identifying a
    // region. Do not leave Flutter method calls waiting forever in that case.
    pendingRegionCompletions.values.forEach { $0("registration_failed") }
    pendingRegionCompletions.removeAll()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if locationAuthorizationIsAlways {
      restoreRegistrations(emitChanges: false, completion: { _ in })
    }
  }

  private func fireLocationRule(_ rule: NativeTriggerRule) {
    let now = NativeTriggerClock.nowMillis
    guard eligible(rule, at: now) else { return }
    let bucket = now / rule.dedupeWindowMillis
    let eventKey = "geofence-enter:\(bucket)"
    let request = UNNotificationRequest(
      identifier: locationNotificationIdentifier(rule.id),
      content: notificationContent(rule),
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    )
    center.add(request) { [weak self] error in
      DispatchQueue.main.async {
        guard error == nil, let self else { return }
        self.store.updateState(rule.id) { state in
          state.lastEventKey = eventKey
          state.lastEventAtMillis = now
          state.lastNotifiedAtMillis = now
          state.firstNotifiedAtMillis = state.firstNotifiedAtMillis ?? now
          state.snoozedUntilMillis = nil
          state.notificationCount += 1
        }
        _ = self.store.enqueueOutcome(
          ruleId: rule.id,
          kind: "fired",
          occurredAtMillis: now,
          eventKey: eventKey
        )
        self.emitOutcomesChanged()
        if rule.recurrence == "once" {
          self.stopMonitoring(rule.id)
        }
      }
    }
  }

  private func eligible(_ rule: NativeTriggerRule, at now: Int64) -> Bool {
    guard rule.enabled else { return false }
    if let activeFrom = rule.activeFromMillis, now < activeFrom { return false }
    if let activeUntil = rule.activeUntilMillis, now > activeUntil { return false }
    let state = store.states[rule.id] ?? NativeTriggerRuntimeState(ruleId: rule.id)
    if state.completedAtMillis != nil { return false }
    if let snoozedUntil = state.snoozedUntilMillis, now < snoozedUntil { return false }
    if rule.recurrence == "once", state.firstNotifiedAtMillis != nil { return false }
    if let last = state.lastNotifiedAtMillis, now - last < rule.cooldownMillis { return false }
    return matchesTimeWindow(rule.timeWindow, at: now)
  }

  private func matchesTimeWindow(_ window: NativeTriggerTimeWindow?, at millis: Int64) -> Bool {
    guard let window else { return true }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = window.timeZoneId.flatMap(TimeZone.init(identifier:)) ?? .current
    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1_000)
    let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
    guard let appleWeekday = components.weekday, let hour = components.hour,
      let minute = components.minute
    else { return false }
    let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
    let minuteOfDay = hour * 60 + minute
    if window.startMinuteOfDay == window.endMinuteOfDay {
      return window.daysOfWeek.contains(isoWeekday)
    }
    if window.startMinuteOfDay < window.endMinuteOfDay {
      return window.daysOfWeek.contains(isoWeekday)
        && minuteOfDay >= window.startMinuteOfDay
        && minuteOfDay < window.endMinuteOfDay
    }
    if minuteOfDay >= window.startMinuteOfDay {
      return window.daysOfWeek.contains(isoWeekday)
    }
    let previous = isoWeekday == 1 ? 7 : isoWeekday - 1
    return minuteOfDay < window.endMinuteOfDay && window.daysOfWeek.contains(previous)
  }

  private func notificationContent(_ rule: NativeTriggerRule) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = rule.title
    content.body = rule.message
    content.sound = .default
    content.categoryIdentifier = Category.trigger
    content.userInfo = [
      Payload.ruleId: rule.id,
      Payload.destinationId: rule.destinationId,
    ]
    return content
  }

  private func complete(ruleId: String, at millis: Int64) {
    store.updateState(ruleId) { state in
      state.completedAtMillis = millis
      state.snoozedUntilMillis = nil
      state.nextAlarmAtMillis = nil
    }
    cancelRegistrations(id: ruleId)
  }

  private func snooze(ruleId: String, requestedAt: Int64) {
    guard let rule = store.rules.first(where: { $0.id == ruleId }) else { return }
    let dueAt = requestedAt + rule.laterDelayMillis
    store.updateState(ruleId) { state in
      state.snoozedUntilMillis = dueAt
      state.nextAlarmAtMillis = dueAt
    }
    scheduleSnoozeNotification(rule, dueAt: dueAt)
    _ = store.enqueueOutcome(
      ruleId: ruleId,
      kind: "later",
      occurredAtMillis: requestedAt,
      snoozedUntilMillis: dueAt
    )
    emitOutcomesChanged()
  }

  private func scheduleSnoozeNotification(
    _ rule: NativeTriggerRule,
    dueAt: Int64,
    completion: ((Bool) -> Void)? = nil
  ) {
    let now = NativeTriggerClock.nowMillis
    let delay = max(1, TimeInterval(max(dueAt, now + 1_000) - now) / 1_000)
    let request = UNNotificationRequest(
      identifier: snoozeIdentifier(rule.id),
      content: notificationContent(rule),
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
    )
    center.add(request) { error in
      DispatchQueue.main.async { completion?(error == nil) }
    }
  }

  private func recordFired(
    ruleId: String,
    requestId: String,
    occurredAtMillis: Int64 = NativeTriggerClock.nowMillis
  ) {
    let now = occurredAtMillis
    let eventKey = "notification:\(requestId):\(now)"
    store.updateState(ruleId) { state in
      if state.lastEventKey != eventKey {
        state.lastEventKey = eventKey
        state.lastEventAtMillis = now
        state.lastNotifiedAtMillis = now
        state.firstNotifiedAtMillis = state.firstNotifiedAtMillis ?? now
        state.notificationCount += 1
      }
      if requestId.hasPrefix(Identifier.snoozePrefix) {
        state.snoozedUntilMillis = nil
        state.nextAlarmAtMillis = nil
      }
    }
    _ = store.enqueueOutcome(
      ruleId: ruleId,
      kind: "fired",
      occurredAtMillis: now,
      eventKey: eventKey
    )
    emitOutcomesChanged()
  }

  private func registerNotificationCategory() {
    let done = UNNotificationAction(
      identifier: Action.done,
      title: "했어",
      options: []
    )
    let later = UNNotificationAction(
      identifier: Action.later,
      title: "나중에",
      options: []
    )
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: Category.trigger,
        actions: [done, later],
        intentIdentifiers: [],
        options: []
      )
    ])
  }

  private func ensureNotificationAuthorization(completion: @escaping (Bool) -> Void) {
    center.getNotificationSettings { [weak self] settings in
      guard let self else { return }
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        DispatchQueue.main.async { completion(true) }
      case .notDetermined:
        self.center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          DispatchQueue.main.async { completion(granted) }
        }
      default:
        DispatchQueue.main.async { completion(false) }
      }
    }
  }

  private func notificationPermissionGranted(completion: @escaping (Bool) -> Void) {
    center.getNotificationSettings { settings in
      let granted: Bool
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral: granted = true
      default: granted = false
      }
      DispatchQueue.main.async { completion(granted) }
    }
  }

  private var locationAuthorizationIsAlways: Bool {
    locationManager.authorizationStatus == .authorizedAlways
  }

  private func requestLocationAuthorizationIfNeeded() {
    switch locationManager.authorizationStatus {
    case .notDetermined, .authorizedWhenInUse:
      locationManager.requestAlwaysAuthorization()
    default:
      break
    }
  }

  private func cancelRegistrations(id: String) {
    pendingRegionCompletions.removeValue(forKey: regionIdentifier(id))?(
      "registration_failed"
    )
    center.removePendingNotificationRequests(withIdentifiers: [
      timeIdentifier(id), snoozeIdentifier(id), locationNotificationIdentifier(id),
    ])
    center.removeDeliveredNotifications(withIdentifiers: [
      timeIdentifier(id), snoozeIdentifier(id), locationNotificationIdentifier(id),
    ])
    stopMonitoring(id)
  }

  private func cancelAllNativeRegistrations() {
    pendingRegionCompletions.values.forEach { $0("registration_failed") }
    pendingRegionCompletions.removeAll()
    let ids = store.rules.flatMap { rule in
      [timeIdentifier(rule.id), snoozeIdentifier(rule.id), locationNotificationIdentifier(rule.id)]
    }
    center.removePendingNotificationRequests(withIdentifiers: ids)
    locationManager.monitoredRegions
      .filter { $0.identifier.hasPrefix(Identifier.regionPrefix) }
      .forEach(locationManager.stopMonitoring)
  }

  private func reconcileDeliveredNotifications(_ notifications: [UNNotification]) {
    for notification in notifications where isNativeIdentifier(notification.request.identifier) {
      if notification.request.identifier.hasPrefix(Identifier.locationNotificationPrefix) {
        continue
      }
      guard let ruleId = notification.request.content.userInfo[Payload.ruleId] as? String else {
        continue
      }
      recordFired(
        ruleId: ruleId,
        requestId: notification.request.identifier,
        occurredAtMillis: Int64(notification.date.timeIntervalSince1970 * 1_000)
      )
    }
  }

  private func stopMonitoring(_ id: String) {
    let identifier = regionIdentifier(id)
    locationManager.monitoredRegions
      .filter { $0.identifier == identifier }
      .forEach(locationManager.stopMonitoring)
  }

  private func emitPendingInteractions() {
    emitOutcomesChanged()
    emitOpensChanged()
  }

  private func emitOutcomesChanged() {
    let values = store.outcomes.map(\.wireValue)
    guard !values.isEmpty else { return }
    invoke("triggerOutcomesChanged", arguments: values)
  }

  private func emitOpensChanged() {
    let values = store.opens.map(\.wireValue)
    guard !values.isEmpty else { return }
    invoke("triggerOpensChanged", arguments: values)
  }

  private func invoke(_ method: String, arguments: Any?) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod(method, arguments: arguments)
    }
  }

  private func argumentId(_ raw: Any?) throws -> String {
    try (raw as? [String: Any] ?? [:]).requiredString("id")
  }

  private func argumentEventIds(_ raw: Any?) -> [String] {
    (raw as? [String: Any])?["eventIds"] as? [String] ?? []
  }

  private func regionIdentifier(_ id: String) -> String { Identifier.regionPrefix + id }
  private func timeIdentifier(_ id: String) -> String { Identifier.timePrefix + id }
  private func snoozeIdentifier(_ id: String) -> String { Identifier.snoozePrefix + id }
  private func locationNotificationIdentifier(_ id: String) -> String {
    Identifier.locationNotificationPrefix + id
  }

  private func ruleId(fromRegionIdentifier identifier: String) -> String? {
    guard identifier.hasPrefix(Identifier.regionPrefix) else { return nil }
    return String(identifier.dropFirst(Identifier.regionPrefix.count))
  }

  private func isNativeIdentifier(_ identifier: String) -> Bool {
    identifier.hasPrefix("trun.trigger.")
  }

  private enum Identifier {
    static let regionPrefix = "trun.trigger.region."
    static let timePrefix = "trun.trigger.time."
    static let snoozePrefix = "trun.trigger.snooze."
    static let locationNotificationPrefix = "trun.trigger.location-notification."
  }

  private enum Payload {
    static let ruleId = "nativeTriggerRuleId"
    static let destinationId = "nativeTriggerDestinationId"
  }

  private enum Category {
    static let trigger = "TRUN_NATIVE_TRIGGER"
  }

  private enum Action {
    static let done = "TRUN_NATIVE_TRIGGER_DONE"
    static let later = "TRUN_NATIVE_TRIGGER_LATER"
  }
}

private extension Dictionary where Key == String, Value == Any {
  func requiredString(_ key: String) throws -> String {
    guard let value = optionalString(key) else {
      throw NativeTriggerError.invalid("\(key) is required")
    }
    return value
  }

  func optionalString(_ key: String) -> String? {
    (self[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      .nonEmpty
  }

  func requiredDouble(_ key: String) throws -> Double {
    guard let value = self[key] as? NSNumber else {
      throw NativeTriggerError.invalid("\(key) is required")
    }
    return value.doubleValue
  }

  func requiredInt(_ key: String) throws -> Int {
    guard let value = self[key] as? NSNumber else {
      throw NativeTriggerError.invalid("\(key) is required")
    }
    return value.intValue
  }

  func requiredInt64(_ key: String) throws -> Int64 {
    guard let value = self[key] as? NSNumber else {
      throw NativeTriggerError.invalid("\(key) is required")
    }
    return value.int64Value
  }

  func optionalInt64(_ key: String) -> Int64? {
    (self[key] as? NSNumber)?.int64Value
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }
}
