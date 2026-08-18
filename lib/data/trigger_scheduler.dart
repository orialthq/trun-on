import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/trigger_models.dart';

/// Status returned by Android after registering or restoring native triggers.
///
/// The value intentionally remains a string. Native can add a recoverable
/// status (for example, a new permission state) without breaking persisted
/// plans or forcing an app release in lockstep.
final class NativeTriggerOperationResult {
  const NativeTriggerOperationResult({
    required this.status,
    this.persisted,
    this.notificationPermissionGranted,
    this.rule = const <String, Object?>{},
  });

  factory NativeTriggerOperationResult.fromWire(Object? value) {
    final map = _wireMap(value, name: 'operation result');
    return NativeTriggerOperationResult(
      status: _optionalString(map, 'status') ?? 'unknown',
      persisted: map['persisted'] as bool?,
      notificationPermissionGranted:
          map['notificationPermissionGranted'] as bool?,
      rule: _optionalWireMap(map['rule']),
    );
  }

  const NativeTriggerOperationResult.unavailable()
    : status = 'unavailable',
      persisted = false,
      notificationPermissionGranted = null,
      rule = const <String, Object?>{};

  final String status;
  final bool? persisted;
  final bool? notificationPermissionGranted;
  final Map<String, Object?> rule;
}

final class NativeTriggerCancelResult {
  const NativeTriggerCancelResult({required this.id, required this.removed});

  factory NativeTriggerCancelResult.fromWire(Object? value) {
    final map = _wireMap(value, name: 'cancel result');
    return NativeTriggerCancelResult(
      id: _requiredString(map, 'id'),
      removed: map['removed'] as bool? ?? false,
    );
  }

  final String id;
  final bool removed;
}

final class NativeTriggerSyncReport {
  const NativeTriggerSyncReport({
    required this.status,
    this.storedRuleCount = 0,
    this.restoredGeofenceCount = 0,
    this.restoredTimeAlarmCount = 0,
    this.restoredSnoozeCount = 0,
    this.notificationPermissionGranted,
  });

  factory NativeTriggerSyncReport.fromWire(Object? value) {
    final map = _wireMap(value, name: 'sync report');
    return NativeTriggerSyncReport(
      status: _optionalString(map, 'status') ?? 'unknown',
      storedRuleCount: _optionalInt(map, 'storedRuleCount') ?? 0,
      restoredGeofenceCount: _optionalInt(map, 'restoredGeofenceCount') ?? 0,
      restoredTimeAlarmCount: _optionalInt(map, 'restoredTimeAlarmCount') ?? 0,
      restoredSnoozeCount: _optionalInt(map, 'restoredSnoozeCount') ?? 0,
      notificationPermissionGranted:
          map['notificationPermissionGranted'] as bool?,
    );
  }

  const NativeTriggerSyncReport.unavailable()
    : status = 'unavailable',
      storedRuleCount = 0,
      restoredGeofenceCount = 0,
      restoredTimeAlarmCount = 0,
      restoredSnoozeCount = 0,
      notificationPermissionGranted = null;

  final String status;
  final int storedRuleCount;
  final int restoredGeofenceCount;
  final int restoredTimeAlarmCount;
  final int restoredSnoozeCount;
  final bool? notificationPermissionGranted;
}

final class NativeTriggerRegistration {
  const NativeTriggerRegistration({required this.rule, required this.state});

  factory NativeTriggerRegistration.fromWire(Object? value) {
    final map = _wireMap(value, name: 'registered trigger');
    return NativeTriggerRegistration(
      rule: _wireMap(map['rule'], name: 'registered trigger rule'),
      state: map['state'] == null
          ? null
          : _wireMap(map['state'], name: 'registered trigger state'),
    );
  }

  final Map<String, Object?> rule;
  final Map<String, Object?>? state;

  String get id => _requiredString(rule, 'id');
}

enum NativeTriggerOutcomeKind { fired, done, later }

final class NativeTriggerOutcome {
  const NativeTriggerOutcome({
    required this.eventId,
    required this.ruleId,
    required this.kind,
    required this.occurredAt,
    this.snoozedUntil,
    this.eventKey,
  });

  factory NativeTriggerOutcome.fromWire(Object? value) {
    final map = _wireMap(value, name: 'trigger outcome');
    final kindName = _requiredString(map, 'kind');
    final kind = NativeTriggerOutcomeKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    if (kind == null) {
      throw FormatException('Unknown trigger outcome kind: $kindName');
    }
    return NativeTriggerOutcome(
      eventId: _requiredString(map, 'eventId'),
      ruleId: _requiredString(map, 'ruleId'),
      kind: kind,
      occurredAt: _requiredEpoch(map, 'occurredAtMillis'),
      snoozedUntil: _optionalEpoch(map, 'snoozedUntilMillis'),
      eventKey: _optionalString(map, 'eventKey'),
    );
  }

  final String eventId;
  final String ruleId;
  final NativeTriggerOutcomeKind kind;
  final DateTime occurredAt;
  final DateTime? snoozedUntil;
  final String? eventKey;
}

final class NativeTriggerOpen {
  const NativeTriggerOpen({
    required this.eventId,
    required this.ruleId,
    required this.destinationId,
    required this.occurredAt,
  });

  factory NativeTriggerOpen.fromWire(Object? value) {
    final map = _wireMap(value, name: 'trigger open');
    return NativeTriggerOpen(
      eventId: _requiredString(map, 'eventId'),
      ruleId: _requiredString(map, 'ruleId'),
      destinationId: _requiredString(map, 'destinationId'),
      occurredAt: _requiredEpoch(map, 'occurredAtMillis'),
    );
  }

  final String eventId;
  final String ruleId;
  final String destinationId;
  final DateTime occurredAt;
}

final class ResolvedTriggerLocation {
  const ResolvedTriggerLocation({
    required this.point,
    required this.formattedAddress,
  });

  final GeoPoint point;
  final String formattedAddress;
}

/// Native scheduling boundary used by the plan controller.
abstract interface class TriggerScheduler {
  Stream<NativeTriggerOpen> get opened;

  Stream<List<NativeTriggerOutcome>> get outcomesChanged;

  Stream<List<NativeTriggerOpen>> get opensChanged;

  Future<ResolvedTriggerLocation?> resolveLocation(String query);

  Future<NativeTriggerOperationResult> schedulePlan(
    Plan plan, {
    bool resetState = false,
  });

  Future<NativeTriggerCancelResult> cancelPlan(String planId);

  Future<NativeTriggerSyncReport> syncPlans(
    Iterable<Plan> plans, {
    Set<String> resetStateIds = const <String>{},
  });

  Future<List<NativeTriggerRegistration>> registeredPlans();

  Future<NativeTriggerOperationResult> resetPlan(String planId);

  Future<NativeTriggerSyncReport> restore();

  Future<List<NativeTriggerOutcome>> pendingOutcomes();

  Future<bool> acknowledgeOutcomes(Iterable<String> eventIds);

  Future<List<NativeTriggerOpen>> pendingOpens();

  Future<bool> acknowledgeOpens(Iterable<String> eventIds);

  Future<void> close();
}

/// Method-channel implementation backed by Android's durable trigger store.
///
/// On platforms where the native plugin is not installed, mutation methods
/// return an `unavailable` result and read methods return an empty collection.
/// This lets an iOS or widget-test plan remain stored without pretending that
/// background delivery was scheduled.
final class MethodChannelTriggerScheduler implements TriggerScheduler {
  MethodChannelTriggerScheduler({
    MethodChannel? channel,
    NativeTriggerRuleAdapter? adapter,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _adapter = adapter ?? const NativeTriggerRuleAdapter() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const channelName = 'com.orialthq.ori_beauty/native_triggers/v1';

  final MethodChannel _channel;
  final NativeTriggerRuleAdapter _adapter;
  final StreamController<NativeTriggerOpen> _openedController =
      StreamController<NativeTriggerOpen>.broadcast();
  final StreamController<List<NativeTriggerOutcome>>
  _outcomesChangedController =
      StreamController<List<NativeTriggerOutcome>>.broadcast();
  final StreamController<List<NativeTriggerOpen>> _opensChangedController =
      StreamController<List<NativeTriggerOpen>>.broadcast();
  bool _closed = false;

  @override
  Stream<NativeTriggerOpen> get opened => _openedController.stream;

  @override
  Stream<List<NativeTriggerOutcome>> get outcomesChanged =>
      _outcomesChangedController.stream;

  @override
  Stream<List<NativeTriggerOpen>> get opensChanged =>
      _opensChangedController.stream;

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (_closed) return null;
    switch (call.method) {
      case 'triggerOpened':
        _openedController.add(NativeTriggerOpen.fromWire(call.arguments));
        return null;
      case 'triggerOutcomesChanged':
        _outcomesChangedController.add(
          _decodeList(call.arguments, NativeTriggerOutcome.fromWire),
        );
        return null;
      case 'triggerOpensChanged':
        _opensChangedController.add(
          _decodeList(call.arguments, NativeTriggerOpen.fromWire),
        );
        return null;
    }
    return null;
  }

  @override
  Future<ResolvedTriggerLocation?> resolveLocation(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return null;
    try {
      final raw = await _channel.invokeMethod<Object?>('resolveLocation', {
        'query': normalized,
      });
      final map = _wireMap(raw, name: 'resolved location');
      if (_optionalString(map, 'status') != 'resolved') return null;
      final latitude = map['latitude'];
      final longitude = map['longitude'];
      if (latitude is! num || longitude is! num) return null;
      return ResolvedTriggerLocation(
        point: GeoPoint(
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
        ),
        formattedAddress:
            _optionalString(map, 'formattedAddress') ?? normalized,
      );
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<NativeTriggerOperationResult> schedulePlan(
    Plan plan, {
    bool resetState = false,
  }) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('schedule', {
        'rule': _adapter.encode(plan),
        'resetState': resetState,
      });
      return NativeTriggerOperationResult.fromWire(raw);
    } on MissingPluginException {
      return const NativeTriggerOperationResult.unavailable();
    }
  }

  @override
  Future<NativeTriggerCancelResult> cancelPlan(String planId) async {
    final id = _requiredNonBlank(planId, 'planId');
    try {
      final raw = await _channel.invokeMethod<Object?>('cancel', {'id': id});
      return NativeTriggerCancelResult.fromWire(raw);
    } on MissingPluginException {
      return NativeTriggerCancelResult(id: id, removed: false);
    }
  }

  @override
  Future<NativeTriggerSyncReport> syncPlans(
    Iterable<Plan> plans, {
    Set<String> resetStateIds = const <String>{},
  }) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('sync', {
        'rules': plans.map(_adapter.encode).toList(growable: false),
        'resetStateIds': resetStateIds.toList(growable: false)..sort(),
      });
      return NativeTriggerSyncReport.fromWire(raw);
    } on MissingPluginException {
      return const NativeTriggerSyncReport.unavailable();
    }
  }

  @override
  Future<List<NativeTriggerRegistration>> registeredPlans() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('list');
      return _decodeList(raw, NativeTriggerRegistration.fromWire);
    } on MissingPluginException {
      return const <NativeTriggerRegistration>[];
    }
  }

  @override
  Future<NativeTriggerOperationResult> resetPlan(String planId) async {
    final id = _requiredNonBlank(planId, 'planId');
    try {
      final raw = await _channel.invokeMethod<Object?>('reset', {'id': id});
      final map = _wireMap(raw, name: 'reset result');
      return NativeTriggerOperationResult(
        status: _optionalString(map, 'status') ?? 'unknown',
      );
    } on MissingPluginException {
      return const NativeTriggerOperationResult.unavailable();
    }
  }

  @override
  Future<NativeTriggerSyncReport> restore() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('restore');
      return NativeTriggerSyncReport.fromWire(raw);
    } on MissingPluginException {
      return const NativeTriggerSyncReport.unavailable();
    }
  }

  @override
  Future<List<NativeTriggerOutcome>> pendingOutcomes() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('pendingOutcomes');
      return _decodeList(raw, NativeTriggerOutcome.fromWire);
    } on MissingPluginException {
      return const <NativeTriggerOutcome>[];
    }
  }

  @override
  Future<bool> acknowledgeOutcomes(Iterable<String> eventIds) async {
    final ids = _normalizedIds(eventIds);
    if (ids.isEmpty) return true;
    try {
      return await _channel.invokeMethod<bool>('acknowledgeOutcomes', {
            'eventIds': ids,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<NativeTriggerOpen>> pendingOpens() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('pendingOpens');
      return _decodeList(raw, NativeTriggerOpen.fromWire);
    } on MissingPluginException {
      return const <NativeTriggerOpen>[];
    }
  }

  @override
  Future<bool> acknowledgeOpens(Iterable<String> eventIds) async {
    final ids = _normalizedIds(eventIds);
    if (ids.isEmpty) return true;
    try {
      return await _channel.invokeMethod<bool>('acknowledgeOpens', {
            'eventIds': ids,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _channel.setMethodCallHandler(null);
    await Future.wait([
      _openedController.close(),
      _outcomesChangedController.close(),
      _opensChangedController.close(),
    ]);
  }
}

/// Converts the platform-independent plan model to Android's flat rule DTO.
///
/// Android registers exactly one primitive: either an alarm or a geofence.
/// Therefore an AND rule is represented by a geofence with an attached local
/// time window, never as two independently firing registrations.
final class NativeTriggerRuleAdapter {
  const NativeTriggerRuleAdapter();

  Map<String, Object?> encode(Plan plan, {DateTime? now}) {
    final encodedAt = now ?? DateTime.now();
    final projection = _project(plan);
    final time = projection.time;
    final location = projection.location;
    if (location == null && time == null) {
      throw UnsupportedError('A plan must contain a time or location trigger.');
    }

    final timeZoneId = _metadataString(plan.metadata, 'timeZoneId');
    final activeFrom = time?.notBefore;
    final activeUntil = _earlier(time?.notAfter, plan.expiresAt);
    final destinationId =
        _payloadString(plan.delivery.payload, 'destinationId') ??
        _metadataString(plan.metadata, 'destinationId') ??
        _metadataString(plan.metadata, 'sourceCaptureId') ??
        plan.id;

    final result = <String, Object?>{
      'id': plan.id,
      'destinationId': destinationId,
      'title': plan.delivery.title,
      'message': plan.delivery.body,
      'enabled': plan.lifecycle == PlanLifecycle.active,
      'activeFromMillis': activeFrom?.millisecondsSinceEpoch,
      'activeUntilMillis': activeUntil?.millisecondsSinceEpoch,
      'cooldownMillis': plan.rule.cooldown.inMilliseconds,
      'dedupeWindowMillis':
          _metadataInt(plan.metadata, 'dedupeWindowMillis') ??
          const Duration(minutes: 1).inMilliseconds,
      'recurrence': _wireRecurrence(plan.rule.recurrence),
      'laterDelayMillis':
          _metadataInt(plan.metadata, 'laterDelayMillis') ??
          const Duration(minutes: 30).inMilliseconds,
      'createdAtMillis': plan.createdAt.millisecondsSinceEpoch,
      'updatedAtMillis':
          _metadataDateTime(
            plan.metadata,
            'updatedAt',
          )?.millisecondsSinceEpoch ??
          encodedAt.millisecondsSinceEpoch,
    };

    if (location != null) {
      result['location'] = <String, Object?>{
        'latitude': location.center.latitude,
        'longitude': location.center.longitude,
        'radiusMeters': location.radiusMeters.clamp(50, 10000).toDouble(),
      };
      final window = _encodeTimeWindow(time, timeZoneId: timeZoneId);
      if (window != null) result['timeWindow'] = window;
    } else {
      result['alarmSchedule'] = <String, Object?>{
        'firstFireAtMillis': _firstFireAt(
          time!,
          recurrence: plan.rule.recurrence,
          now: encodedAt,
        ).millisecondsSinceEpoch,
        'timeZoneId': timeZoneId,
      };
    }
    return result;
  }

  _ConditionProjection _project(Plan plan) {
    LocationCondition? location;
    TimeCondition? time;

    void visit(TriggerCondition condition) {
      switch (condition) {
        case LocationCondition():
          if (location != null) {
            throw UnsupportedError(
              'Native scheduling supports one location per plan.',
            );
          }
          location = condition;
        case TimeCondition():
          if (time != null) {
            throw UnsupportedError(
              'Native scheduling supports one time condition per plan.',
            );
          }
          time = condition;
        case AndCondition(:final conditions):
          for (final child in conditions) {
            visit(child);
          }
      }
    }

    visit(plan.rule.condition);

    // A geocoder result can be persisted in metadata before a controller has
    // rebuilt its strongly typed condition. Only use it for an explicitly
    // location-bearing draft, never as an accidental context location.
    if (location == null && _metadataUsesResolvedLocation(plan.metadata)) {
      final resolved = _metadataLocation(plan.metadata);
      if (resolved != null) location = resolved;
    }
    return _ConditionProjection(location: location, time: time);
  }

  Map<String, Object?>? _encodeTimeWindow(
    TimeCondition? time, {
    required String? timeZoneId,
  }) {
    if (time == null) return null;
    final start = time.windowStart;
    final end = time.windowEnd;
    if (start == null && time.weekdays.isEmpty) return null;
    return <String, Object?>{
      'daysOfWeek':
          (time.weekdays.isEmpty ? <int>{1, 2, 3, 4, 5, 6, 7} : time.weekdays)
              .toList(growable: false)
            ..sort(),
      'startMinuteOfDay': start?.minutesSinceMidnight ?? 0,
      'endMinuteOfDay': end?.minutesSinceMidnight ?? 0,
      'timeZoneId': timeZoneId,
    };
  }

  DateTime _firstFireAt(
    TimeCondition time, {
    required TriggerRecurrence recurrence,
    required DateTime now,
  }) {
    final threshold = _later(now, time.notBefore) ?? now;
    final start = time.windowStart;
    if (start != null) {
      final occurrence = _nextWallClockOccurrence(
        threshold,
        start,
        time.weekdays,
      );
      if (time.notAfter != null && !occurrence.isBefore(time.notAfter!)) {
        throw StateError('The next trigger time falls after the plan expires.');
      }
      return occurrence;
    }
    if (time.notBefore != null) return time.notBefore!;
    if (recurrence == TriggerRecurrence.once && time.notAfter != null) {
      return now;
    }
    throw UnsupportedError(
      'A time-only plan needs notBefore or a concrete windowStart.',
    );
  }
}

final class _ConditionProjection {
  const _ConditionProjection({required this.location, required this.time});

  final LocationCondition? location;
  final TimeCondition? time;
}

DateTime _nextWallClockOccurrence(
  DateTime threshold,
  ClockTime time,
  Set<int> weekdays,
) {
  final allowed = weekdays.isEmpty
      ? const <int>{1, 2, 3, 4, 5, 6, 7}
      : weekdays;
  for (var offset = 0; offset <= 7; offset += 1) {
    final date = threshold.add(Duration(days: offset));
    final candidate = threshold.isUtc
        ? DateTime.utc(date.year, date.month, date.day, time.hour, time.minute)
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (allowed.contains(candidate.weekday) && !candidate.isBefore(threshold)) {
      return candidate;
    }
  }
  throw StateError('Could not find the next matching weekday.');
}

LocationCondition? _metadataLocation(Map<String, Object?> metadata) {
  Object? raw = metadata['resolvedLocation'];
  if (raw is! Map) raw = metadata;
  final map = _optionalWireMap(raw);
  final latitude = map['latitude'];
  final longitude = map['longitude'];
  if (latitude is! num || longitude is! num) return null;
  final radius = map['radiusMeters'] ?? metadata['radiusMeters'];
  return LocationCondition(
    center: GeoPoint(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    ),
    radiusMeters: radius is num ? radius.toDouble() : 500,
  );
}

bool _metadataUsesResolvedLocation(Map<String, Object?> metadata) {
  final kind = _metadataString(metadata, 'triggerKind');
  return kind == 'location' ||
      kind == 'timeAndLocation' ||
      kind == 'time_and_location';
}

String _wireRecurrence(TriggerRecurrence recurrence) => switch (recurrence) {
  TriggerRecurrence.once => 'once',
  TriggerRecurrence.daily => 'daily',
  TriggerRecurrence.weekly => 'weekly',
  TriggerRecurrence.onReentry => 'on_reentry',
};

List<String> _normalizedIds(Iterable<String> values) =>
    values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

List<T> _decodeList<T>(Object? raw, T Function(Object?) decode) {
  if (raw is! List) return <T>[];
  return raw.map(decode).toList(growable: false);
}

Map<String, Object?> _wireMap(Object? raw, {required String name}) {
  if (raw is! Map) throw FormatException('$name must be a map.');
  return <String, Object?>{
    for (final entry in raw.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

Map<String, Object?> _optionalWireMap(Object? raw) {
  if (raw is! Map) return const <String, Object?>{};
  return <String, Object?>{
    for (final entry in raw.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _requiredString(Map<String, Object?> map, String key) =>
    _optionalString(map, key) ?? (throw FormatException('$key is required.'));

String? _optionalString(Map<String, Object?> map, String key) =>
    (map[key] as String?)?.trim().takeIf((value) => value.isNotEmpty);

String _requiredNonBlank(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, name, 'Required.');
  return normalized;
}

int? _optionalInt(Map<String, Object?> map, String key) =>
    (map[key] as num?)?.toInt();

DateTime _requiredEpoch(Map<String, Object?> map, String key) {
  final value = _optionalInt(map, key);
  if (value == null) throw FormatException('$key is required.');
  return DateTime.fromMillisecondsSinceEpoch(value);
}

DateTime? _optionalEpoch(Map<String, Object?> map, String key) {
  final value = _optionalInt(map, key);
  return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
}

String? _metadataString(Map<String, Object?> values, String key) =>
    (values[key] as String?)?.trim().takeIf((value) => value.isNotEmpty);

String? _payloadString(Map<String, Object?> values, String key) =>
    (values[key] as String?)?.trim().takeIf((value) => value.isNotEmpty);

int? _metadataInt(Map<String, Object?> values, String key) =>
    (values[key] as num?)?.toInt();

DateTime? _metadataDateTime(Map<String, Object?> values, String key) {
  final value = values[key];
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _earlier(DateTime? first, DateTime? second) {
  if (first == null) return second;
  if (second == null) return first;
  return first.isBefore(second) ? first : second;
}

DateTime? _later(DateTime? first, DateTime? second) {
  if (first == null) return second;
  if (second == null) return first;
  return first.isAfter(second) ? first : second;
}

extension _TakeIf<T> on T {
  T? takeIf(bool Function(T value) predicate) => predicate(this) ? this : null;
}
