import 'dart:math' as math;

import 'trigger_models.dart';

/// Deterministically evaluates a [Plan] against explicitly supplied facts.
///
/// The engine reads no clock, location service, storage, or platform API. The
/// caller persists [TriggerOutcome.nextState] and performs a delivery only when
/// [TriggerOutcome.shouldFire] is true.
final class TriggerEngine {
  const TriggerEngine();

  TriggerOutcome evaluate({
    required Plan plan,
    required TriggerEvaluationContext context,
    TriggerRuntimeState? state,
  }) {
    final currentState = state ?? TriggerRuntimeState();

    if (plan.lifecycle == PlanLifecycle.expired ||
        (plan.expiresAt != null && !context.now.isBefore(plan.expiresAt!))) {
      return _outcome(
        plan: plan,
        context: context,
        state: currentState,
        kind: TriggerOutcomeKind.expired,
        reason: TriggerOutcomeReason.expired,
        lifecycle: PlanLifecycle.expired,
      );
    }

    final inactiveReason = switch (plan.lifecycle) {
      PlanLifecycle.draft => TriggerOutcomeReason.draft,
      PlanLifecycle.paused => TriggerOutcomeReason.paused,
      PlanLifecycle.completed => TriggerOutcomeReason.completed,
      PlanLifecycle.active || PlanLifecycle.fired => null,
      PlanLifecycle.expired => TriggerOutcomeReason.expired,
    };
    if (inactiveReason != null) {
      return _outcome(
        plan: plan,
        context: context,
        state: currentState,
        kind: TriggerOutcomeKind.inactive,
        reason: inactiveReason,
      );
    }

    if (context.now.isBefore(plan.createdAt)) {
      return _outcome(
        plan: plan,
        context: context,
        state: currentState,
        kind: TriggerOutcomeKind.conditionNotMet,
        reason: TriggerOutcomeReason.outsideTime,
      );
    }

    final locationTransition = _locationTransition(
      condition: plan.rule.condition,
      location: context.location,
      state: currentState,
    );
    final transitionedState = locationTransition.nextState;
    final conditionResult = _matches(plan.rule.condition, context);
    if (!conditionResult.matches) {
      return _outcome(
        plan: plan,
        context: context,
        state: transitionedState,
        kind: TriggerOutcomeKind.conditionNotMet,
        reason: conditionResult.reason,
      );
    }

    final recurrenceReason = _recurrenceBlockReason(
      recurrence: plan.rule.recurrence,
      now: context.now,
      state: currentState,
      enteredLocation: locationTransition.entered,
    );
    if (recurrenceReason != null) {
      return _outcome(
        plan: plan,
        context: context,
        state: transitionedState,
        kind: TriggerOutcomeKind.recurrenceNotDue,
        reason: recurrenceReason,
      );
    }

    if (_cooldownIsActive(
      now: context.now,
      lastFiredAt: currentState.lastFiredAt,
      cooldown: plan.rule.cooldown,
    )) {
      return _outcome(
        plan: plan,
        context: context,
        state: transitionedState,
        kind: TriggerOutcomeKind.cooldownActive,
        reason: TriggerOutcomeReason.cooldownActive,
      );
    }

    final deliveryKey = _deliveryKey(
      plan: plan,
      now: context.now,
      reentrySequence: transitionedState.reentrySequence,
    );
    if (currentState.deliveredDedupeKeys.contains(deliveryKey) ||
        context.deliveredDedupeKeys.contains(deliveryKey)) {
      return _outcome(
        plan: plan,
        context: context,
        state: transitionedState,
        kind: TriggerOutcomeKind.duplicate,
        reason: TriggerOutcomeReason.duplicateDelivery,
      );
    }

    final nextDedupeKeys = <String>{
      ...currentState.deliveredDedupeKeys,
      deliveryKey,
    };
    final firedState = transitionedState.copyWith(
      lastFiredAt: context.now,
      fireCount: currentState.fireCount + 1,
      deliveredDedupeKeys: nextDedupeKeys,
    );
    return TriggerOutcome(
      kind: TriggerOutcomeKind.fired,
      reason: TriggerOutcomeReason.matched,
      evaluatedAt: context.now,
      nextLifecycle: PlanLifecycle.fired,
      nextState: firedState,
      delivery: plan.delivery,
      deliveryKey: deliveryKey,
    );
  }

  TriggerOutcome _outcome({
    required Plan plan,
    required TriggerEvaluationContext context,
    required TriggerRuntimeState state,
    required TriggerOutcomeKind kind,
    required TriggerOutcomeReason reason,
    PlanLifecycle? lifecycle,
  }) {
    return TriggerOutcome(
      kind: kind,
      reason: reason,
      evaluatedAt: context.now,
      nextLifecycle: lifecycle ?? plan.lifecycle,
      nextState: state,
    );
  }
}

_ConditionMatch _matches(
  TriggerCondition condition,
  TriggerEvaluationContext context,
) {
  return switch (condition) {
    TimeCondition() => _matchesTime(condition, context.now),
    LocationCondition() => _matchesLocation(condition, context.location),
    AndCondition(:final conditions) => _matchesAll(conditions, context),
  };
}

_ConditionMatch _matchesAll(
  List<TriggerCondition> conditions,
  TriggerEvaluationContext context,
) {
  for (final condition in conditions) {
    final result = _matches(condition, context);
    if (!result.matches) {
      return result;
    }
  }
  return const _ConditionMatch.matched();
}

_ConditionMatch _matchesTime(TimeCondition condition, DateTime now) {
  if (condition.notBefore != null && now.isBefore(condition.notBefore!)) {
    return const _ConditionMatch.notMatched(TriggerOutcomeReason.outsideTime);
  }
  if (condition.notAfter != null && now.isAfter(condition.notAfter!)) {
    return const _ConditionMatch.notMatched(TriggerOutcomeReason.outsideTime);
  }

  final minute = now.hour * 60 + now.minute;
  final start = condition.windowStart?.minutesSinceMidnight;
  final end = condition.windowEnd?.minutesSinceMidnight;

  var effectiveWeekday = now.weekday;
  if (start != null && end != null && start > end && minute < end) {
    effectiveWeekday = effectiveWeekday == DateTime.monday
        ? DateTime.sunday
        : effectiveWeekday - 1;
  }
  if (condition.weekdays.isNotEmpty &&
      !condition.weekdays.contains(effectiveWeekday)) {
    return const _ConditionMatch.notMatched(TriggerOutcomeReason.outsideTime);
  }

  if (start == null || end == null || start == end) {
    return const _ConditionMatch.matched();
  }

  final inWindow = start < end
      ? minute >= start && minute < end
      : minute >= start || minute < end;
  return inWindow
      ? const _ConditionMatch.matched()
      : const _ConditionMatch.notMatched(TriggerOutcomeReason.outsideTime);
}

_ConditionMatch _matchesLocation(
  LocationCondition condition,
  GeoPoint? location,
) {
  if (location == null) {
    return const _ConditionMatch.notMatched(
      TriggerOutcomeReason.missingLocation,
    );
  }
  final distance = _distanceMeters(condition.center, location);
  return distance <= condition.radiusMeters
      ? const _ConditionMatch.matched()
      : const _ConditionMatch.notMatched(TriggerOutcomeReason.outsideLocation);
}

_LocationTransition _locationTransition({
  required TriggerCondition condition,
  required GeoPoint? location,
  required TriggerRuntimeState state,
}) {
  if (!condition.containsLocationCondition || location == null) {
    return _LocationTransition(nextState: state, entered: false);
  }

  final isInside = _allLocationConditionsMatch(condition, location);
  final entered = isInside && state.wasInsideLocation != true;
  return _LocationTransition(
    nextState: state.copyWith(
      wasInsideLocation: isInside,
      reentrySequence: entered
          ? state.reentrySequence + 1
          : state.reentrySequence,
    ),
    entered: entered,
  );
}

bool _allLocationConditionsMatch(
  TriggerCondition condition,
  GeoPoint location,
) {
  return switch (condition) {
    TimeCondition() => true,
    LocationCondition() =>
      _distanceMeters(condition.center, location) <= condition.radiusMeters,
    AndCondition(:final conditions) => conditions.every(
      (child) => _allLocationConditionsMatch(child, location),
    ),
  };
}

TriggerOutcomeReason? _recurrenceBlockReason({
  required TriggerRecurrence recurrence,
  required DateTime now,
  required TriggerRuntimeState state,
  required bool enteredLocation,
}) {
  return switch (recurrence) {
    TriggerRecurrence.once =>
      state.fireCount > 0 || state.lastFiredAt != null
          ? TriggerOutcomeReason.alreadyFired
          : null,
    TriggerRecurrence.daily =>
      state.lastFiredAt != null && _isSameCalendarDate(now, state.lastFiredAt!)
          ? TriggerOutcomeReason.alreadyFiredToday
          : null,
    TriggerRecurrence.weekly =>
      state.lastFiredAt != null && _isSameCalendarWeek(now, state.lastFiredAt!)
          ? TriggerOutcomeReason.alreadyFiredThisWeek
          : null,
    TriggerRecurrence.onReentry =>
      enteredLocation ? null : TriggerOutcomeReason.notReentered,
  };
}

bool _cooldownIsActive({
  required DateTime now,
  required DateTime? lastFiredAt,
  required Duration cooldown,
}) {
  if (lastFiredAt == null || cooldown == Duration.zero) {
    return false;
  }
  final elapsed = now.difference(lastFiredAt);
  return elapsed.isNegative || elapsed < cooldown;
}

String _deliveryKey({
  required Plan plan,
  required DateTime now,
  required int reentrySequence,
}) {
  final base = plan.rule.dedupeKey ?? plan.id;
  return switch (plan.rule.recurrence) {
    TriggerRecurrence.once => '$base:once',
    TriggerRecurrence.daily => '$base:daily:${_dateKey(now)}',
    TriggerRecurrence.weekly => '$base:weekly:${_dateKey(_weekStart(now))}',
    TriggerRecurrence.onReentry => '$base:reentry:$reentrySequence',
  };
}

bool _isSameCalendarDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool _isSameCalendarWeek(DateTime first, DateTime second) =>
    _isSameCalendarDate(_weekStart(first), _weekStart(second));

DateTime _weekStart(DateTime value) {
  final date = value.isUtc
      ? DateTime.utc(value.year, value.month, value.day)
      : DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: value.weekday - DateTime.monday));
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

double _distanceMeters(GeoPoint first, GeoPoint second) {
  const earthRadiusMeters = 6371008.8;
  final latitude1 = _toRadians(first.latitude);
  final latitude2 = _toRadians(second.latitude);
  final latitudeDelta = latitude2 - latitude1;
  final longitudeDelta = _toRadians(second.longitude - first.longitude);

  final sinLatitude = math.sin(latitudeDelta / 2);
  final sinLongitude = math.sin(longitudeDelta / 2);
  final haversine =
      sinLatitude * sinLatitude +
      math.cos(latitude1) * math.cos(latitude2) * sinLongitude * sinLongitude;
  final angularDistance = 2 * math.asin(math.sqrt(haversine.clamp(0, 1)));
  return earthRadiusMeters * angularDistance;
}

double _toRadians(double degrees) => degrees * math.pi / 180;

final class _ConditionMatch {
  const _ConditionMatch.matched()
    : matches = true,
      reason = TriggerOutcomeReason.matched;

  const _ConditionMatch.notMatched(this.reason) : matches = false;

  final bool matches;
  final TriggerOutcomeReason reason;
}

final class _LocationTransition {
  const _LocationTransition({required this.nextState, required this.entered});

  final TriggerRuntimeState nextState;
  final bool entered;
}
