import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/trigger_engine.dart';
import 'package:ori_beauty/domain/trigger_models.dart';

void main() {
  const engine = TriggerEngine();

  group('time evaluation', () {
    test('uses an inclusive start and exclusive end', () {
      final plan = _plan(
        condition: TimeCondition(
          windowStart: ClockTime(hour: 9, minute: 0),
          windowEnd: ClockTime(hour: 10, minute: 0),
        ),
      );

      expect(
        _evaluate(engine, plan, DateTime(2026, 8, 17, 9)).shouldFire,
        isTrue,
      );
      expect(
        _evaluate(engine, plan, DateTime(2026, 8, 17, 9, 59)).shouldFire,
        isTrue,
      );
      expect(
        _evaluate(engine, plan, DateTime(2026, 8, 17, 10)).reason,
        TriggerOutcomeReason.outsideTime,
      );
    });

    test(
      'matches an overnight window and attributes after-midnight to start day',
      () {
        final plan = _plan(
          condition: TimeCondition(
            windowStart: ClockTime(hour: 22, minute: 0),
            windowEnd: ClockTime(hour: 2, minute: 0),
            weekdays: const {DateTime.sunday},
          ),
        );

        expect(
          _evaluate(engine, plan, DateTime(2026, 8, 16, 23)).shouldFire,
          isTrue,
        );
        expect(
          _evaluate(engine, plan, DateTime(2026, 8, 17, 1, 59)).shouldFire,
          isTrue,
        );
        expect(
          _evaluate(engine, plan, DateTime(2026, 8, 17, 2)).reason,
          TriggerOutcomeReason.outsideTime,
        );
      },
    );

    test(
      'does not fire before plan creation and expires at the exact boundary',
      () {
        final plan = _plan(
          condition: TimeCondition(
            windowStart: ClockTime(hour: 0, minute: 0),
            windowEnd: ClockTime(hour: 0, minute: 0),
          ),
          createdAt: DateTime(2026, 8, 17, 9),
          expiresAt: DateTime(2026, 8, 17, 10),
        );

        expect(
          _evaluate(engine, plan, DateTime(2026, 8, 17, 8, 59)).reason,
          TriggerOutcomeReason.outsideTime,
        );
        final expired = _evaluate(engine, plan, DateTime(2026, 8, 17, 10));
        expect(expired.kind, TriggerOutcomeKind.expired);
        expect(expired.nextLifecycle, PlanLifecycle.expired);
      },
    );
  });

  group('location and composite evaluation', () {
    final center = GeoPoint(latitude: 37.5445, longitude: 127.0561);

    test('requires every condition in an AND composite', () {
      final plan = _plan(
        condition: AndCondition(
          conditions: [
            TimeCondition(
              windowStart: ClockTime(hour: 11, minute: 0),
              windowEnd: ClockTime(hour: 14, minute: 0),
            ),
            LocationCondition(center: center, radiusMeters: 150),
          ],
        ),
      );

      final matched = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 12),
        location: GeoPoint(latitude: 37.5446, longitude: 127.0562),
      );
      expect(matched.shouldFire, isTrue);

      final outside = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 12),
        location: GeoPoint(latitude: 37.55, longitude: 127.06),
      );
      expect(outside.reason, TriggerOutcomeReason.outsideLocation);
    });

    test('reports missing location without changing known location state', () {
      final plan = _plan(
        condition: LocationCondition(center: center, radiusMeters: 100),
      );
      final previous = TriggerRuntimeState(wasInsideLocation: false);

      final outcome = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 12),
        state: previous,
      );

      expect(outcome.reason, TriggerOutcomeReason.missingLocation);
      expect(outcome.nextState.wasInsideLocation, isFalse);
    });
  });

  group('lifecycle and recurrence', () {
    test('does not evaluate draft, paused, or completed plans', () {
      for (final entry in {
        PlanLifecycle.draft: TriggerOutcomeReason.draft,
        PlanLifecycle.paused: TriggerOutcomeReason.paused,
        PlanLifecycle.completed: TriggerOutcomeReason.completed,
      }.entries) {
        final outcome = _evaluate(
          engine,
          _plan(lifecycle: entry.key),
          DateTime(2026, 8, 17, 12),
        );
        expect(outcome.kind, TriggerOutcomeKind.inactive);
        expect(outcome.reason, entry.value);
      }
    });

    test('fires a once rule only once', () {
      final plan = _plan();
      final first = _evaluate(engine, plan, DateTime(2026, 8, 17, 12));
      final second = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 18, 12),
        state: first.nextState,
      );

      expect(first.shouldFire, isTrue);
      expect(first.deliveryKey, 'plan-1:once');
      expect(second.reason, TriggerOutcomeReason.alreadyFired);
      expect(second.nextState.fireCount, 1);
    });

    test('daily and weekly rules use calendar occurrence boundaries', () {
      final daily = _plan(recurrence: TriggerRecurrence.daily);
      final dailyFirst = _evaluate(engine, daily, DateTime(2026, 8, 17, 9));
      expect(
        _evaluate(
          engine,
          daily,
          DateTime(2026, 8, 17, 20),
          state: dailyFirst.nextState,
        ).reason,
        TriggerOutcomeReason.alreadyFiredToday,
      );
      expect(
        _evaluate(
          engine,
          daily,
          DateTime(2026, 8, 18, 9),
          state: dailyFirst.nextState,
        ).shouldFire,
        isTrue,
      );

      final weekly = _plan(recurrence: TriggerRecurrence.weekly);
      final weeklyFirst = _evaluate(engine, weekly, DateTime(2026, 8, 17, 9));
      expect(
        _evaluate(
          engine,
          weekly,
          DateTime(2026, 8, 23, 9),
          state: weeklyFirst.nextState,
        ).reason,
        TriggerOutcomeReason.alreadyFiredThisWeek,
      );
      expect(
        _evaluate(
          engine,
          weekly,
          DateTime(2026, 8, 24, 9),
          state: weeklyFirst.nextState,
        ).shouldFire,
        isTrue,
      );
    });
  });

  group('re-entry, cooldown, and deduplication', () {
    final center = GeoPoint(latitude: 37.5445, longitude: 127.0561);
    final inside = GeoPoint(latitude: 37.5446, longitude: 127.0562);
    final outside = GeoPoint(latitude: 37.55, longitude: 127.06);

    test('fires only on each outside-to-inside transition', () {
      final plan = _plan(
        condition: LocationCondition(center: center, radiusMeters: 150),
        recurrence: TriggerRecurrence.onReentry,
      );
      final first = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9),
        location: inside,
      );
      final stillInside = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9, 1),
        location: inside,
        state: first.nextState,
      );
      final left = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9, 2),
        location: outside,
        state: stillInside.nextState,
      );
      final reentered = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9, 3),
        location: inside,
        state: left.nextState,
      );

      expect(first.deliveryKey, 'plan-1:reentry:1');
      expect(stillInside.reason, TriggerOutcomeReason.notReentered);
      expect(left.reason, TriggerOutcomeReason.outsideLocation);
      expect(reentered.deliveryKey, 'plan-1:reentry:2');
      expect(reentered.nextState.fireCount, 2);
    });

    test('applies cooldown and consumes an entry that occurs during it', () {
      final plan = _plan(
        condition: LocationCondition(center: center, radiusMeters: 150),
        recurrence: TriggerRecurrence.onReentry,
        cooldown: const Duration(minutes: 10),
      );
      final first = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9),
        location: inside,
      );
      final left = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9, 1),
        location: outside,
        state: first.nextState,
      );
      final tooSoon = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9, 2),
        location: inside,
        state: left.nextState,
      );
      final stillInsideLater = _evaluate(
        engine,
        plan,
        DateTime(2026, 8, 17, 9, 11),
        location: inside,
        state: tooSoon.nextState,
      );

      expect(tooSoon.reason, TriggerOutcomeReason.cooldownActive);
      expect(stillInsideLater.reason, TriggerOutcomeReason.notReentered);
    });

    test('suppresses a delivery key already observed by the caller', () {
      final plan = _plan(
        recurrence: TriggerRecurrence.daily,
        dedupeKey: 'shared-rule',
      );
      final now = DateTime(2026, 8, 17, 12);
      final first = _evaluate(engine, plan, now);
      final duplicate = engine.evaluate(
        plan: plan,
        context: TriggerEvaluationContext(
          now: now,
          deliveredDedupeKeys: {first.deliveryKey!},
        ),
      );

      expect(first.deliveryKey, 'shared-rule:daily:2026-08-17');
      expect(duplicate.kind, TriggerOutcomeKind.duplicate);
      expect(duplicate.reason, TriggerOutcomeReason.duplicateDelivery);
    });
  });
}

TriggerOutcome _evaluate(
  TriggerEngine engine,
  Plan plan,
  DateTime now, {
  GeoPoint? location,
  TriggerRuntimeState? state,
}) {
  return engine.evaluate(
    plan: plan,
    context: TriggerEvaluationContext(now: now, location: location),
    state: state,
  );
}

Plan _plan({
  TriggerCondition? condition,
  TriggerRecurrence recurrence = TriggerRecurrence.once,
  PlanLifecycle lifecycle = PlanLifecycle.active,
  Duration cooldown = Duration.zero,
  String? dedupeKey,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  return Plan(
    id: 'plan-1',
    title: '테스트 계획',
    rule: TriggerRule(
      condition:
          condition ??
          TimeCondition(
            windowStart: ClockTime(hour: 0, minute: 0),
            windowEnd: ClockTime(hour: 0, minute: 0),
          ),
      recurrence: recurrence,
      cooldown: cooldown,
      dedupeKey: dedupeKey,
    ),
    lifecycle: lifecycle,
    delivery: TriggerDelivery(
      channel: DeliveryChannel.localNotification,
      title: '테스트 알림',
      body: '조건이 충족됐어.',
    ),
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    expiresAt: expiresAt,
  );
}
