/// Pure domain models used to describe and evaluate plans.
///
/// This file intentionally has no Flutter or platform dependencies so the same
/// rules can be evaluated by foreground UI, background workers, and servers.
enum PlanLifecycle { draft, active, paused, fired, completed, expired }

enum TriggerRecurrence { once, daily, weekly, onReentry }

enum DeliveryChannel { localNotification, inApp }

enum TriggerOutcomeKind {
  fired,
  conditionNotMet,
  recurrenceNotDue,
  cooldownActive,
  duplicate,
  inactive,
  expired,
}

enum TriggerOutcomeReason {
  matched,
  missingLocation,
  outsideLocation,
  outsideTime,
  notReentered,
  alreadyFired,
  alreadyFiredToday,
  alreadyFiredThisWeek,
  cooldownActive,
  duplicateDelivery,
  draft,
  paused,
  completed,
  expired,
}

final class GeoPoint {
  GeoPoint({required this.latitude, required this.longitude}) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be from -90 to 90.',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be from -180 to 180.',
      );
    }
  }

  factory GeoPoint.fromJson(Map<String, Object?> json) {
    return GeoPoint(
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
    );
  }

  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// A wall-clock value, independent of date and timezone.
final class ClockTime implements Comparable<ClockTime> {
  ClockTime({required this.hour, required this.minute}) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'Must be from 0 to 23.');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'Must be from 0 to 59.');
    }
  }

  factory ClockTime.fromMinutesSinceMidnight(int value) {
    if (value < 0 || value >= minutesPerDay) {
      throw ArgumentError.value(
        value,
        'value',
        'Must be from 0 to ${minutesPerDay - 1}.',
      );
    }
    return ClockTime(hour: value ~/ 60, minute: value % 60);
  }

  factory ClockTime.fromJson(Map<String, Object?> json) {
    return ClockTime(
      hour: _requiredInt(json, 'hour'),
      minute: _requiredInt(json, 'minute'),
    );
  }

  static const int minutesPerDay = 24 * 60;

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  Map<String, Object?> toJson() => {'hour': hour, 'minute': minute};

  @override
  int compareTo(ClockTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

sealed class TriggerCondition {
  const TriggerCondition();

  factory TriggerCondition.fromJson(Map<String, Object?> json) {
    return switch (_requiredString(json, 'type')) {
      'time' => TimeCondition.fromJson(json),
      'location' => LocationCondition.fromJson(json),
      'and' => AndCondition.fromJson(json),
      final type => throw FormatException(
        'Unknown trigger condition type: $type',
      ),
    };
  }

  Map<String, Object?> toJson();
}

/// Matches absolute bounds, selected weekdays, and/or a local time window.
///
/// Window starts are inclusive and ends are exclusive. A window whose start
/// and end are equal represents a full day. When start is later than end, the
/// window crosses midnight (for example 22:00 through 02:00).
final class TimeCondition extends TriggerCondition {
  TimeCondition({
    this.notBefore,
    this.notAfter,
    this.windowStart,
    this.windowEnd,
    Set<int> weekdays = const <int>{},
  }) : weekdays = Set<int>.unmodifiable(weekdays) {
    if ((windowStart == null) != (windowEnd == null)) {
      throw ArgumentError(
        'windowStart and windowEnd must be provided together.',
      );
    }
    if (notBefore != null &&
        notAfter != null &&
        notAfter!.isBefore(notBefore!)) {
      throw ArgumentError('notAfter cannot be before notBefore.');
    }
    if (weekdays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      throw ArgumentError.value(
        weekdays,
        'weekdays',
        'Values must use DateTime.monday through DateTime.sunday.',
      );
    }
    if (notBefore == null &&
        notAfter == null &&
        windowStart == null &&
        weekdays.isEmpty) {
      throw ArgumentError('A time condition needs at least one constraint.');
    }
  }

  factory TimeCondition.fromJson(Map<String, Object?> json) {
    final rawWeekdays = _optionalList(json, 'weekdays');
    return TimeCondition(
      notBefore: _optionalDateTime(json, 'notBefore'),
      notAfter: _optionalDateTime(json, 'notAfter'),
      windowStart: _optionalMap(json, 'windowStart', ClockTime.fromJson),
      windowEnd: _optionalMap(json, 'windowEnd', ClockTime.fromJson),
      weekdays: rawWeekdays == null
          ? const <int>{}
          : rawWeekdays.map((value) {
              if (value is! int) {
                throw const FormatException('weekdays must contain integers.');
              }
              return value;
            }).toSet(),
    );
  }

  final DateTime? notBefore;
  final DateTime? notAfter;
  final ClockTime? windowStart;
  final ClockTime? windowEnd;
  final Set<int> weekdays;

  @override
  Map<String, Object?> toJson() => {
    'type': 'time',
    'notBefore': notBefore?.toIso8601String(),
    'notAfter': notAfter?.toIso8601String(),
    'windowStart': windowStart?.toJson(),
    'windowEnd': windowEnd?.toJson(),
    'weekdays': weekdays.toList()..sort(),
  };
}

final class LocationCondition extends TriggerCondition {
  LocationCondition({required this.center, required this.radiusMeters}) {
    if (!radiusMeters.isFinite || radiusMeters <= 0) {
      throw ArgumentError.value(
        radiusMeters,
        'radiusMeters',
        'Must be a positive finite number.',
      );
    }
  }

  factory LocationCondition.fromJson(Map<String, Object?> json) {
    return LocationCondition(
      center: _requiredMap(json, 'center', GeoPoint.fromJson),
      radiusMeters: _requiredDouble(json, 'radiusMeters'),
    );
  }

  final GeoPoint center;
  final double radiusMeters;

  @override
  Map<String, Object?> toJson() => {
    'type': 'location',
    'center': center.toJson(),
    'radiusMeters': radiusMeters,
  };
}

/// A composite condition that matches only when every child matches.
final class AndCondition extends TriggerCondition {
  AndCondition({required List<TriggerCondition> conditions})
    : conditions = List<TriggerCondition>.unmodifiable(conditions) {
    if (conditions.isEmpty) {
      throw ArgumentError.value(
        conditions,
        'conditions',
        'An AND condition cannot be empty.',
      );
    }
  }

  factory AndCondition.fromJson(Map<String, Object?> json) {
    final rawConditions = json['conditions'];
    if (rawConditions is! List) {
      throw const FormatException('conditions must be a list.');
    }
    return AndCondition(
      conditions: rawConditions
          .map((value) {
            if (value is! Map) {
              throw const FormatException('Each condition must be an object.');
            }
            return TriggerCondition.fromJson(_stringKeyedMap(value));
          })
          .toList(growable: false),
    );
  }

  final List<TriggerCondition> conditions;

  @override
  Map<String, Object?> toJson() => {
    'type': 'and',
    'conditions': conditions.map((condition) => condition.toJson()).toList(),
  };
}

final class TriggerRule {
  TriggerRule({
    required this.condition,
    required this.recurrence,
    this.cooldown = Duration.zero,
    this.dedupeKey,
  }) {
    if (cooldown.isNegative) {
      throw ArgumentError.value(cooldown, 'cooldown', 'Cannot be negative.');
    }
    if (dedupeKey != null && dedupeKey!.trim().isEmpty) {
      throw ArgumentError.value(dedupeKey, 'dedupeKey', 'Cannot be blank.');
    }
    if (recurrence == TriggerRecurrence.onReentry &&
        !condition.containsLocationCondition) {
      throw ArgumentError(
        'onReentry recurrence requires at least one location condition.',
      );
    }
  }

  factory TriggerRule.fromJson(Map<String, Object?> json) {
    return TriggerRule(
      condition: _requiredMap(json, 'condition', TriggerCondition.fromJson),
      recurrence: _enumByName(
        TriggerRecurrence.values,
        _requiredString(json, 'recurrence'),
        'recurrence',
      ),
      cooldown: Duration(
        milliseconds: _optionalInt(json, 'cooldownMilliseconds') ?? 0,
      ),
      dedupeKey: _optionalString(json, 'dedupeKey'),
    );
  }

  final TriggerCondition condition;
  final TriggerRecurrence recurrence;
  final Duration cooldown;
  final String? dedupeKey;

  Map<String, Object?> toJson() => {
    'condition': condition.toJson(),
    'recurrence': recurrence.name,
    'cooldownMilliseconds': cooldown.inMilliseconds,
    'dedupeKey': dedupeKey,
  };
}

extension TriggerConditionInspection on TriggerCondition {
  bool get containsLocationCondition => switch (this) {
    LocationCondition() => true,
    TimeCondition() => false,
    AndCondition(:final conditions) => conditions.any(
      (condition) => condition.containsLocationCondition,
    ),
  };
}

final class TriggerDelivery {
  TriggerDelivery({
    required this.channel,
    required this.title,
    required this.body,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : payload = Map<String, Object?>.unmodifiable(payload) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Cannot be blank.');
    }
  }

  factory TriggerDelivery.fromJson(Map<String, Object?> json) {
    final payload = _optionalObject(json, 'payload');
    return TriggerDelivery(
      channel: _enumByName(
        DeliveryChannel.values,
        _requiredString(json, 'channel'),
        'channel',
      ),
      title: _requiredString(json, 'title'),
      body: _requiredString(json, 'body'),
      payload: payload ?? const <String, Object?>{},
    );
  }

  final DeliveryChannel channel;
  final String title;
  final String body;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'channel': channel.name,
    'title': title,
    'body': body,
    'payload': payload,
  };
}

final class Plan {
  Plan({
    required this.id,
    required this.title,
    required this.rule,
    required this.lifecycle,
    required this.delivery,
    required this.createdAt,
    this.expiresAt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map<String, Object?>.unmodifiable(metadata) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Cannot be blank.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Cannot be blank.');
    }
    if (expiresAt != null && expiresAt!.isBefore(createdAt)) {
      throw ArgumentError('expiresAt cannot be before createdAt.');
    }
  }

  factory Plan.fromJson(Map<String, Object?> json) {
    final metadata = _optionalObject(json, 'metadata');
    return Plan(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      rule: _requiredMap(json, 'rule', TriggerRule.fromJson),
      lifecycle: _enumByName(
        PlanLifecycle.values,
        _requiredString(json, 'lifecycle'),
        'lifecycle',
      ),
      delivery: _requiredMap(json, 'delivery', TriggerDelivery.fromJson),
      createdAt: _requiredDateTime(json, 'createdAt'),
      expiresAt: _optionalDateTime(json, 'expiresAt'),
      metadata: metadata ?? const <String, Object?>{},
    );
  }

  final String id;
  final String title;
  final TriggerRule rule;
  final PlanLifecycle lifecycle;
  final TriggerDelivery delivery;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, Object?> metadata;

  Plan copyWith({
    String? id,
    String? title,
    TriggerRule? rule,
    PlanLifecycle? lifecycle,
    TriggerDelivery? delivery,
    DateTime? createdAt,
    Object? expiresAt = _unset,
    Map<String, Object?>? metadata,
  }) {
    return Plan(
      id: id ?? this.id,
      title: title ?? this.title,
      rule: rule ?? this.rule,
      lifecycle: lifecycle ?? this.lifecycle,
      delivery: delivery ?? this.delivery,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: identical(expiresAt, _unset)
          ? this.expiresAt
          : expiresAt as DateTime?,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'rule': rule.toJson(),
    'lifecycle': lifecycle.name,
    'delivery': delivery.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'metadata': metadata,
  };
}

/// External facts supplied to a deterministic evaluation.
final class TriggerEvaluationContext {
  TriggerEvaluationContext({
    required this.now,
    this.location,
    Set<String> deliveredDedupeKeys = const <String>{},
  }) : deliveredDedupeKeys = Set<String>.unmodifiable(deliveredDedupeKeys);

  factory TriggerEvaluationContext.fromJson(Map<String, Object?> json) {
    final rawDedupeKeys = _optionalList(json, 'deliveredDedupeKeys');
    return TriggerEvaluationContext(
      now: _requiredDateTime(json, 'now'),
      location: _optionalMap(json, 'location', GeoPoint.fromJson),
      deliveredDedupeKeys: rawDedupeKeys == null
          ? const <String>{}
          : rawDedupeKeys.map((value) {
              if (value is! String) {
                throw const FormatException(
                  'deliveredDedupeKeys must contain strings.',
                );
              }
              return value;
            }).toSet(),
    );
  }

  final DateTime now;
  final GeoPoint? location;
  final Set<String> deliveredDedupeKeys;

  Map<String, Object?> toJson() => {
    'now': now.toIso8601String(),
    'location': location?.toJson(),
    'deliveredDedupeKeys': deliveredDedupeKeys.toList()..sort(),
  };
}

/// Persistable runtime facts. The engine returns a new state and never mutates
/// the supplied instance.
final class TriggerRuntimeState {
  TriggerRuntimeState({
    this.lastFiredAt,
    this.fireCount = 0,
    this.wasInsideLocation,
    this.reentrySequence = 0,
    Set<String> deliveredDedupeKeys = const <String>{},
  }) : deliveredDedupeKeys = Set<String>.unmodifiable(deliveredDedupeKeys) {
    if (fireCount < 0) {
      throw ArgumentError.value(fireCount, 'fireCount', 'Cannot be negative.');
    }
    if (reentrySequence < 0) {
      throw ArgumentError.value(
        reentrySequence,
        'reentrySequence',
        'Cannot be negative.',
      );
    }
  }

  factory TriggerRuntimeState.fromJson(Map<String, Object?> json) {
    final rawDedupeKeys = _optionalList(json, 'deliveredDedupeKeys');
    return TriggerRuntimeState(
      lastFiredAt: _optionalDateTime(json, 'lastFiredAt'),
      fireCount: _optionalInt(json, 'fireCount') ?? 0,
      wasInsideLocation: _optionalBool(json, 'wasInsideLocation'),
      reentrySequence: _optionalInt(json, 'reentrySequence') ?? 0,
      deliveredDedupeKeys: rawDedupeKeys == null
          ? const <String>{}
          : rawDedupeKeys.map((value) {
              if (value is! String) {
                throw const FormatException(
                  'deliveredDedupeKeys must contain strings.',
                );
              }
              return value;
            }).toSet(),
    );
  }

  final DateTime? lastFiredAt;
  final int fireCount;
  final bool? wasInsideLocation;
  final int reentrySequence;
  final Set<String> deliveredDedupeKeys;

  TriggerRuntimeState copyWith({
    Object? lastFiredAt = _unset,
    int? fireCount,
    Object? wasInsideLocation = _unset,
    int? reentrySequence,
    Set<String>? deliveredDedupeKeys,
  }) {
    return TriggerRuntimeState(
      lastFiredAt: identical(lastFiredAt, _unset)
          ? this.lastFiredAt
          : lastFiredAt as DateTime?,
      fireCount: fireCount ?? this.fireCount,
      wasInsideLocation: identical(wasInsideLocation, _unset)
          ? this.wasInsideLocation
          : wasInsideLocation as bool?,
      reentrySequence: reentrySequence ?? this.reentrySequence,
      deliveredDedupeKeys: deliveredDedupeKeys ?? this.deliveredDedupeKeys,
    );
  }

  Map<String, Object?> toJson() => {
    'lastFiredAt': lastFiredAt?.toIso8601String(),
    'fireCount': fireCount,
    'wasInsideLocation': wasInsideLocation,
    'reentrySequence': reentrySequence,
    'deliveredDedupeKeys': deliveredDedupeKeys.toList()..sort(),
  };
}

/// Complete, persistable result of one engine evaluation.
final class TriggerOutcome {
  TriggerOutcome({
    required this.kind,
    required this.reason,
    required this.evaluatedAt,
    required this.nextLifecycle,
    required this.nextState,
    this.delivery,
    this.deliveryKey,
  }) {
    if ((delivery == null) != (deliveryKey == null)) {
      throw ArgumentError('delivery and deliveryKey must both be set or null.');
    }
    if (kind == TriggerOutcomeKind.fired && delivery == null) {
      throw ArgumentError('A fired outcome requires a delivery.');
    }
    if (kind != TriggerOutcomeKind.fired && delivery != null) {
      throw ArgumentError('Only a fired outcome can include a delivery.');
    }
  }

  factory TriggerOutcome.fromJson(Map<String, Object?> json) {
    return TriggerOutcome(
      kind: _enumByName(
        TriggerOutcomeKind.values,
        _requiredString(json, 'kind'),
        'kind',
      ),
      reason: _enumByName(
        TriggerOutcomeReason.values,
        _requiredString(json, 'reason'),
        'reason',
      ),
      evaluatedAt: _requiredDateTime(json, 'evaluatedAt'),
      nextLifecycle: _enumByName(
        PlanLifecycle.values,
        _requiredString(json, 'nextLifecycle'),
        'nextLifecycle',
      ),
      nextState: _requiredMap(json, 'nextState', TriggerRuntimeState.fromJson),
      delivery: _optionalMap(json, 'delivery', TriggerDelivery.fromJson),
      deliveryKey: _optionalString(json, 'deliveryKey'),
    );
  }

  final TriggerOutcomeKind kind;
  final TriggerOutcomeReason reason;
  final DateTime evaluatedAt;
  final PlanLifecycle nextLifecycle;
  final TriggerRuntimeState nextState;
  final TriggerDelivery? delivery;
  final String? deliveryKey;

  bool get shouldFire => kind == TriggerOutcomeKind.fired;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'reason': reason.name,
    'evaluatedAt': evaluatedAt.toIso8601String(),
    'nextLifecycle': nextLifecycle.name,
    'nextState': nextState.toJson(),
    'delivery': delivery?.toJson(),
    'deliveryKey': deliveryKey,
  };
}

const _Unset _unset = _Unset();

final class _Unset {
  const _Unset();
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key must be a string or null.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer.');
  }
  return value;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('$key must be an integer or null.');
  }
  return value;
}

double _requiredDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('$key must be a number.');
  }
  return value.toDouble();
}

bool? _optionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    throw FormatException('$key must be a boolean or null.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException('$key must be an ISO-8601 timestamp.');
  }
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) {
    return null;
  }
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException('$key must be an ISO-8601 timestamp or null.');
  }
}

T _requiredMap<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) decode,
) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('$key must be an object.');
  }
  return decode(_stringKeyedMap(value));
}

T? _optionalMap<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) decode,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw FormatException('$key must be an object or null.');
  }
  return decode(_stringKeyedMap(value));
}

List<Object?>? _optionalList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! List) {
    throw FormatException('$key must be a list or null.');
  }
  return value.cast<Object?>();
}

Map<String, Object?>? _optionalObject(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw FormatException('$key must be an object or null.');
  }
  return _stringKeyedMap(value);
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const FormatException('Object keys must be strings.');
    }
    result[entry.key! as String] = entry.value;
  }
  return result;
}

T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  throw FormatException('$field has an unknown value: $name');
}
