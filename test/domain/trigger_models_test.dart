import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/trigger_models.dart';

void main() {
  group('trigger model serialization', () {
    test('round-trips a plan with nested AND conditions', () {
      final plan = Plan(
        id: 'plan-lunch-1',
        title: '성수에서 점심 먹기',
        rule: TriggerRule(
          condition: AndCondition(
            conditions: [
              TimeCondition(
                windowStart: ClockTime(hour: 11, minute: 30),
                windowEnd: ClockTime(hour: 14, minute: 0),
                weekdays: const {DateTime.monday, DateTime.tuesday},
              ),
              LocationCondition(
                center: GeoPoint(latitude: 37.5445, longitude: 127.0561),
                radiusMeters: 250,
              ),
            ],
          ),
          recurrence: TriggerRecurrence.daily,
          cooldown: const Duration(hours: 2),
          dedupeKey: 'lunch-in-seongsu',
        ),
        lifecycle: PlanLifecycle.active,
        delivery: TriggerDelivery(
          channel: DeliveryChannel.localNotification,
          title: '점심 후보를 확인해봐',
          body: '저장한 성수 맛집이 근처에 있어.',
          payload: const {
            'route': '/plans/plan-lunch-1',
            'candidateIds': ['place-1', 'place-2'],
          },
        ),
        createdAt: DateTime.utc(2026, 8, 17, 1),
        expiresAt: DateTime.utc(2026, 9, 1),
        metadata: const {'source': 'user'},
      );

      final restored = Plan.fromJson(plan.toJson());

      expect(restored.toJson(), equals(plan.toJson()));
      expect(restored.rule.condition, isA<AndCondition>());
      expect(
        (restored.rule.condition as AndCondition).conditions,
        hasLength(2),
      );
    });

    test('round-trips evaluation context, runtime state, and outcome', () {
      final state = TriggerRuntimeState(
        lastFiredAt: DateTime.utc(2026, 8, 17, 3),
        fireCount: 2,
        wasInsideLocation: true,
        reentrySequence: 3,
        deliveredDedupeKeys: const {'plan:reentry:2', 'plan:reentry:3'},
      );
      final context = TriggerEvaluationContext(
        now: DateTime.utc(2026, 8, 17, 4),
        location: GeoPoint(latitude: 37.5, longitude: 127),
        deliveredDedupeKeys: const {'external-key'},
      );
      final delivery = TriggerDelivery(
        channel: DeliveryChannel.inApp,
        title: '확인해봐',
        body: '본문',
      );
      final outcome = TriggerOutcome(
        kind: TriggerOutcomeKind.fired,
        reason: TriggerOutcomeReason.matched,
        evaluatedAt: context.now,
        nextLifecycle: PlanLifecycle.fired,
        nextState: state,
        delivery: delivery,
        deliveryKey: 'plan:reentry:3',
      );

      expect(
        TriggerEvaluationContext.fromJson(context.toJson()).toJson(),
        context.toJson(),
      );
      expect(
        TriggerRuntimeState.fromJson(state.toJson()).toJson(),
        state.toJson(),
      );
      expect(
        TriggerOutcome.fromJson(outcome.toJson()).toJson(),
        outcome.toJson(),
      );
    });
  });

  group('trigger model validation', () {
    test('requires both ends of a time window', () {
      expect(
        () => TimeCondition(windowStart: ClockTime(hour: 9, minute: 0)),
        throwsArgumentError,
      );
    });

    test('requires a location condition for on-reentry recurrence', () {
      expect(
        () => TriggerRule(
          condition: TimeCondition(
            windowStart: ClockTime(hour: 9, minute: 0),
            windowEnd: ClockTime(hour: 18, minute: 0),
          ),
          recurrence: TriggerRecurrence.onReentry,
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed and unknown condition JSON', () {
      expect(
        () => TriggerCondition.fromJson(const {'type': 'or'}),
        throwsFormatException,
      );
      expect(
        () => TimeCondition.fromJson(const {
          'type': 'time',
          'weekdays': ['monday'],
        }),
        throwsFormatException,
      );
    });
  });
}
