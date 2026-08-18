import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/trigger_models.dart';

/// Durable event types for a plan's delivery and feedback history.
///
/// This is intentionally broader than the native notification actions. It
/// also records lifecycle changes made in Flutter so one ordered history can
/// later feed analytics and personalization without reconstructing state from
/// multiple stores.
enum TriggerPlanEventKind {
  created,
  scheduled,
  eligible,
  fired,
  opened,
  sourceOpened,
  mapOpened,
  routeStarted,
  completed,
  snoozed,
  dismissed,
  notInterested,
  visitConfirmed,
  didNotVisit,
  visitUnknown,
  notificationDisabled,
  paused,
  resumed,
  failed,
}

/// Stable event names exported to the experiment analytics pipeline.
///
/// These names deliberately do not always mirror the durable enum names. In
/// particular, a native [TriggerPlanEventKind.fired] event means the
/// notification was delivered, while [TriggerPlanEventKind.completed] is only
/// a plan action and is not evidence of a visit.
extension TriggerPlanEventKindAnalytics on TriggerPlanEventKind {
  String get analyticsName => switch (this) {
    TriggerPlanEventKind.created => 'created',
    TriggerPlanEventKind.scheduled => 'scheduled',
    TriggerPlanEventKind.eligible => 'candidate_available',
    TriggerPlanEventKind.fired => 'delivered',
    TriggerPlanEventKind.opened => 'notification_opened',
    TriggerPlanEventKind.sourceOpened => 'original_opened',
    TriggerPlanEventKind.mapOpened => 'map_opened',
    TriggerPlanEventKind.routeStarted => 'route_started',
    TriggerPlanEventKind.completed => 'completed',
    TriggerPlanEventKind.snoozed => 'later',
    TriggerPlanEventKind.dismissed => 'dismissed',
    TriggerPlanEventKind.notInterested => 'not_interested',
    TriggerPlanEventKind.visitConfirmed => 'visited_confirmed',
    TriggerPlanEventKind.didNotVisit => 'did_not_visit',
    TriggerPlanEventKind.visitUnknown => 'unknown',
    TriggerPlanEventKind.notificationDisabled => 'notification_disabled',
    TriggerPlanEventKind.paused => 'paused',
    TriggerPlanEventKind.resumed => 'resumed',
    TriggerPlanEventKind.failed => 'failed',
  };
}

final class TriggerPlanEvent {
  TriggerPlanEvent({
    required this.id,
    required this.planId,
    required this.kind,
    required this.occurredAt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map<String, Object?>.unmodifiable(metadata) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Cannot be blank.');
    }
    if (planId.trim().isEmpty) {
      throw ArgumentError.value(planId, 'planId', 'Cannot be blank.');
    }
  }

  factory TriggerPlanEvent.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final planId = json['planId'];
    final rawKind = json['kind'];
    final rawOccurredAt = json['occurredAt'];
    final metadata = json['metadata'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Trigger plan event id is invalid.');
    }
    if (planId is! String || planId.trim().isEmpty) {
      throw const FormatException('Trigger plan event planId is invalid.');
    }
    final kind = _eventKindForName(rawKind);
    if (kind == null) {
      throw FormatException('Unknown trigger plan event kind: $rawKind');
    }
    if (rawOccurredAt is! String) {
      throw const FormatException('Trigger plan event occurredAt is invalid.');
    }
    final occurredAt = DateTime.tryParse(rawOccurredAt);
    if (occurredAt == null) {
      throw const FormatException('Trigger plan event occurredAt is invalid.');
    }
    if (metadata != null && metadata is! Map<String, Object?>) {
      throw const FormatException('Trigger plan event metadata is invalid.');
    }

    return TriggerPlanEvent(
      id: id,
      planId: planId,
      kind: kind,
      occurredAt: occurredAt,
      metadata: metadata as Map<String, Object?>? ?? const <String, Object?>{},
    );
  }

  final String id;
  final String planId;
  final TriggerPlanEventKind kind;
  final DateTime occurredAt;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'kind': kind.name,
    'occurredAt': occurredAt.toIso8601String(),
    'metadata': metadata,
  };
}

/// One independently restorable plan, its evaluator state, and its history.
final class PersistedTriggerPlan {
  PersistedTriggerPlan({
    required this.plan,
    TriggerRuntimeState? runtimeState,
    List<TriggerPlanEvent> events = const <TriggerPlanEvent>[],
  }) : runtimeState = runtimeState ?? TriggerRuntimeState(),
       events = List<TriggerPlanEvent>.unmodifiable(events) {
    if (events.any((event) => event.planId != plan.id)) {
      throw ArgumentError.value(
        events,
        'events',
        'Every event must reference the persisted plan.',
      );
    }
  }

  factory PersistedTriggerPlan.fromJson(Map<String, Object?> json) {
    final rawPlan = json['plan'];
    final rawRuntimeState = json['runtimeState'];
    final rawEvents = json['events'];
    if (rawPlan is! Map<String, Object?>) {
      throw const FormatException('Persisted trigger plan is invalid.');
    }
    if (rawRuntimeState is! Map<String, Object?>) {
      throw const FormatException(
        'Persisted trigger runtime state is invalid.',
      );
    }
    if (rawEvents is! List<Object?>) {
      throw const FormatException('Persisted trigger plan events are invalid.');
    }

    final plan = Plan.fromJson(rawPlan);
    final events = <TriggerPlanEvent>[];
    for (final rawEvent in rawEvents) {
      if (rawEvent is! Map<String, Object?>) {
        throw const FormatException('Persisted trigger plan event is invalid.');
      }
      final rawKind = rawEvent['kind'];
      if (_eventKindForName(rawKind) == null) {
        // An older or newer app may have written an event kind this version
        // does not understand. Event history is additive, so retain the plan
        // and all recognized events instead of rejecting the whole snapshot.
        continue;
      }
      events.add(TriggerPlanEvent.fromJson(rawEvent));
    }
    if (events.any((event) => event.planId != plan.id)) {
      throw const FormatException(
        'Persisted trigger plan event references another plan.',
      );
    }

    return PersistedTriggerPlan(
      plan: plan,
      runtimeState: TriggerRuntimeState.fromJson(rawRuntimeState),
      events: events,
    );
  }

  final Plan plan;
  final TriggerRuntimeState runtimeState;
  final List<TriggerPlanEvent> events;

  PersistedTriggerPlan copyWith({
    Plan? plan,
    TriggerRuntimeState? runtimeState,
    List<TriggerPlanEvent>? events,
  }) {
    return PersistedTriggerPlan(
      plan: plan ?? this.plan,
      runtimeState: runtimeState ?? this.runtimeState,
      events: events ?? this.events,
    );
  }

  Map<String, Object?> toJson() => {
    'plan': plan.toJson(),
    'runtimeState': runtimeState.toJson(),
    'events': events.map((event) => event.toJson()).toList(),
  };
}

abstract interface class TriggerPlanStore {
  Future<List<PersistedTriggerPlan>> load();

  Future<void> save(List<PersistedTriggerPlan> plans);
}

final class MethodChannelTriggerPlanStore implements TriggerPlanStore {
  const MethodChannelTriggerPlanStore({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static const _defaultChannel = MethodChannel(
    'com.orialthq.ori_beauty/incoming_share/v1',
  );

  final MethodChannel _channel;

  @override
  Future<List<PersistedTriggerPlan>> load() async {
    final snapshot = await _channel.invokeMethod<String>('loadPlanSnapshot');
    if (snapshot == null || snapshot.isEmpty) {
      return const <PersistedTriggerPlan>[];
    }
    return TriggerPlanSnapshotCodec.decode(snapshot);
  }

  @override
  Future<void> save(List<PersistedTriggerPlan> plans) async {
    final saved = await _channel.invokeMethod<bool>(
      'savePlanSnapshot',
      TriggerPlanSnapshotCodec.encode(plans),
    );
    if (saved != true) {
      throw StateError('The trigger plan snapshot was not saved.');
    }
  }
}

final class InMemoryTriggerPlanStore implements TriggerPlanStore {
  String? _snapshot;

  String? get snapshot => _snapshot;

  @override
  Future<List<PersistedTriggerPlan>> load() async {
    final snapshot = _snapshot;
    return snapshot == null
        ? const <PersistedTriggerPlan>[]
        : TriggerPlanSnapshotCodec.decode(snapshot);
  }

  @override
  Future<void> save(List<PersistedTriggerPlan> plans) async {
    _snapshot = TriggerPlanSnapshotCodec.encode(plans);
  }
}

abstract final class TriggerPlanSnapshotCodec {
  static const int schemaVersion = 1;

  static String encode(List<PersistedTriggerPlan> plans) {
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'plans': plans.map((plan) => plan.toJson()).toList(),
    });
  }

  static List<PersistedTriggerPlan> decode(String snapshot) {
    final decoded = jsonDecode(snapshot);
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported trigger plan snapshot schema.');
    }
    final rawPlans = decoded['plans'];
    if (rawPlans is! List<Object?>) {
      throw const FormatException('Trigger plan snapshot plans are invalid.');
    }
    return rawPlans
        .map((rawPlan) {
          if (rawPlan is! Map<String, Object?>) {
            throw const FormatException('Persisted trigger plan is invalid.');
          }
          return PersistedTriggerPlan.fromJson(rawPlan);
        })
        .toList(growable: false);
  }
}

TriggerPlanEventKind? _eventKindForName(Object? name) {
  return TriggerPlanEventKind.values
      .where((candidate) => candidate.name == name)
      .firstOrNull;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
