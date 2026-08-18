import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/trigger_plan_store.dart';
import 'package:ori_beauty/domain/trigger_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TriggerPlanSnapshotCodec', () {
    test('round-trips plans, runtime state, and ordered event history', () {
      final record = _record();

      final decoded = TriggerPlanSnapshotCodec.decode(
        TriggerPlanSnapshotCodec.encode(<PersistedTriggerPlan>[record]),
      ).single;

      expect(decoded.plan.id, 'plan-1');
      expect(decoded.plan.title, '퇴근길에 화석 들르기');
      expect(decoded.plan.lifecycle, PlanLifecycle.active);
      expect(decoded.plan.rule.recurrence, TriggerRecurrence.onReentry);
      expect(decoded.plan.rule.cooldown, const Duration(hours: 12));
      expect(decoded.plan.rule.condition, isA<AndCondition>());
      expect(decoded.plan.metadata, {
        'sourceCaptureId': 'capture-1',
        'locationQuery': '화석 서울 서초구',
      });
      expect(decoded.runtimeState.lastFiredAt, DateTime.utc(2026, 8, 17, 3));
      expect(decoded.runtimeState.fireCount, 2);
      expect(decoded.runtimeState.wasInsideLocation, isTrue);
      expect(decoded.runtimeState.reentrySequence, 1);
      expect(decoded.runtimeState.deliveredDedupeKeys, {'plan-1:2'});
      expect(decoded.events.map((event) => event.kind), <TriggerPlanEventKind>[
        TriggerPlanEventKind.created,
        TriggerPlanEventKind.fired,
        TriggerPlanEventKind.opened,
      ]);
      expect(decoded.events.last.metadata, {'destination': 'plans'});
    });

    test('round-trips experiment events and delivery identifiers', () {
      const experimentKinds = <TriggerPlanEventKind>[
        TriggerPlanEventKind.eligible,
        TriggerPlanEventKind.sourceOpened,
        TriggerPlanEventKind.mapOpened,
        TriggerPlanEventKind.routeStarted,
        TriggerPlanEventKind.notInterested,
        TriggerPlanEventKind.visitConfirmed,
        TriggerPlanEventKind.didNotVisit,
        TriggerPlanEventKind.visitUnknown,
        TriggerPlanEventKind.notificationDisabled,
      ];
      final record = _record().copyWith(
        events: <TriggerPlanEvent>[
          for (final (index, kind) in experimentKinds.indexed)
            TriggerPlanEvent(
              id: 'experiment-event-$index',
              planId: 'plan-1',
              kind: kind,
              occurredAt: DateTime.utc(2026, 8, 18, 1, index),
              metadata: <String, Object?>{
                'experimentId': 'EXP-001',
                'variant': 'treatment',
                'scenarioId': 'SCN-003',
                'sourceCaptureId': 'capture-1',
                'eventKey': 'plan-1:delivery-$index',
                'deliveryId': 'delivery-$index',
                'source': 'flutter',
              },
            ),
        ],
      );

      final decoded = TriggerPlanSnapshotCodec.decode(
        TriggerPlanSnapshotCodec.encode(<PersistedTriggerPlan>[record]),
      ).single;

      expect(decoded.events.map((event) => event.kind), experimentKinds);
      expect(decoded.events.first.metadata, {
        'experimentId': 'EXP-001',
        'variant': 'treatment',
        'scenarioId': 'SCN-003',
        'sourceCaptureId': 'capture-1',
        'eventKey': 'plan-1:delivery-0',
        'deliveryId': 'delivery-0',
        'source': 'flutter',
      });
      expect(
        decoded.events.last.metadata['eventKey'],
        'plan-1:delivery-${experimentKinds.length - 1}',
      );
    });

    test('skips unknown history kind values without dropping the snapshot', () {
      final snapshot =
          jsonDecode(
                TriggerPlanSnapshotCodec.encode(<PersistedTriggerPlan>[
                  _record(),
                ]),
              )
              as Map<String, Object?>;
      final plans = snapshot['plans']! as List<Object?>;
      final plan = plans.single! as Map<String, Object?>;
      final events = plan['events']! as List<Object?>;
      events.insert(1, <String, Object?>{
        'id': 'legacy-event',
        'planId': 'plan-1',
        'kind': 'legacy_delivery_attempt',
        'occurredAt': DateTime.utc(2026, 8, 17, 2).toIso8601String(),
        'metadata': const <String, Object?>{'eventKey': 'legacy-delivery-1'},
      });
      events.insert(2, <String, Object?>{
        'id': 'malformed-kind-event',
        'planId': 'plan-1',
        'kind': 404,
        'occurredAt': DateTime.utc(2026, 8, 17, 2, 1).toIso8601String(),
        'metadata': const <String, Object?>{},
      });

      final decoded = TriggerPlanSnapshotCodec.decode(
        jsonEncode(snapshot),
      ).single;

      expect(decoded.plan.id, 'plan-1');
      expect(decoded.events.map((event) => event.id), <String>[
        'event-1',
        'event-2',
        'event-3',
      ]);
      expect(decoded.events.last.metadata, {'destination': 'plans'});
    });

    test('rejects unknown snapshot versions', () {
      expect(
        () => TriggerPlanSnapshotCodec.decode(
          jsonEncode({'schemaVersion': 2, 'plans': <Object?>[]}),
        ),
        throwsFormatException,
      );
    });

    test('rejects history events that reference another plan', () {
      final snapshot =
          jsonDecode(
                TriggerPlanSnapshotCodec.encode(<PersistedTriggerPlan>[
                  _record(),
                ]),
              )
              as Map<String, Object?>;
      final plans = snapshot['plans']! as List<Object?>;
      final plan = plans.single! as Map<String, Object?>;
      final events = plan['events']! as List<Object?>;
      final event = events.first! as Map<String, Object?>;
      event['planId'] = 'another-plan';

      expect(
        () => TriggerPlanSnapshotCodec.decode(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });
  });

  test('maps event kinds to stable analytics names', () {
    expect(
      <TriggerPlanEventKind, String>{
        TriggerPlanEventKind.eligible: 'candidate_available',
        TriggerPlanEventKind.fired: 'delivered',
        TriggerPlanEventKind.opened: 'notification_opened',
        TriggerPlanEventKind.snoozed: 'later',
        TriggerPlanEventKind.sourceOpened: 'original_opened',
        TriggerPlanEventKind.mapOpened: 'map_opened',
        TriggerPlanEventKind.routeStarted: 'route_started',
        TriggerPlanEventKind.notInterested: 'not_interested',
        TriggerPlanEventKind.visitConfirmed: 'visited_confirmed',
        TriggerPlanEventKind.didNotVisit: 'did_not_visit',
        TriggerPlanEventKind.visitUnknown: 'unknown',
        TriggerPlanEventKind.notificationDisabled: 'notification_disabled',
      }.map((kind, name) => MapEntry(kind.analyticsName, name)),
      {
        'candidate_available': 'candidate_available',
        'delivered': 'delivered',
        'notification_opened': 'notification_opened',
        'later': 'later',
        'original_opened': 'original_opened',
        'map_opened': 'map_opened',
        'route_started': 'route_started',
        'not_interested': 'not_interested',
        'visited_confirmed': 'visited_confirmed',
        'did_not_visit': 'did_not_visit',
        'unknown': 'unknown',
        'notification_disabled': 'notification_disabled',
      },
    );
    expect(TriggerPlanEventKind.completed.analyticsName, 'completed');
    expect(
      TriggerPlanEventKind.completed.analyticsName,
      isNot(TriggerPlanEventKind.visitConfirmed.analyticsName),
    );
  });

  test(
    'InMemoryTriggerPlanStore starts empty and restores a saved snapshot',
    () async {
      final store = InMemoryTriggerPlanStore();

      expect(await store.load(), isEmpty);
      await store.save(<PersistedTriggerPlan>[_record()]);

      expect(store.snapshot, contains('"schemaVersion":1'));
      expect((await store.load()).single.plan.id, 'plan-1');
    },
  );

  group('MethodChannelTriggerPlanStore', () {
    const channel = MethodChannel('test/trigger_plan_store');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('uses the dedicated plan snapshot platform methods', () async {
      String? storedSnapshot;
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            switch (call.method) {
              case 'loadPlanSnapshot':
                return storedSnapshot;
              case 'savePlanSnapshot':
                storedSnapshot = call.arguments! as String;
                return true;
            }
            return null;
          });
      const store = MethodChannelTriggerPlanStore(channel: channel);

      expect(await store.load(), isEmpty);
      await store.save(<PersistedTriggerPlan>[_record()]);
      expect((await store.load()).single.plan.id, 'plan-1');
      expect(methods, <String>[
        'loadPlanSnapshot',
        'savePlanSnapshot',
        'loadPlanSnapshot',
      ]);
    });

    test('surfaces a rejected platform write', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      const store = MethodChannelTriggerPlanStore(channel: channel);

      expect(
        store.save(<PersistedTriggerPlan>[_record()]),
        throwsA(isA<StateError>()),
      );
    });
  });
}

PersistedTriggerPlan _record() {
  final plan = Plan(
    id: 'plan-1',
    title: '퇴근길에 화석 들르기',
    rule: TriggerRule(
      condition: AndCondition(
        conditions: <TriggerCondition>[
          LocationCondition(
            center: GeoPoint(latitude: 37.4979, longitude: 127.0276),
            radiusMeters: 400,
          ),
          TimeCondition(
            windowStart: ClockTime(hour: 17, minute: 30),
            windowEnd: ClockTime(hour: 21, minute: 0),
            weekdays: const <int>{
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
            },
          ),
        ],
      ),
      recurrence: TriggerRecurrence.onReentry,
      cooldown: const Duration(hours: 12),
      dedupeKey: 'plan-1',
    ),
    lifecycle: PlanLifecycle.active,
    delivery: TriggerDelivery(
      channel: DeliveryChannel.localNotification,
      title: '근처에 저장한 곳이 있어요',
      body: '퇴근길이면 화석에 들러볼까요?',
      payload: const <String, Object?>{'destination': 'plans'},
    ),
    createdAt: DateTime.utc(2026, 8, 16, 9),
    metadata: const <String, Object?>{
      'sourceCaptureId': 'capture-1',
      'locationQuery': '화석 서울 서초구',
    },
  );
  return PersistedTriggerPlan(
    plan: plan,
    runtimeState: TriggerRuntimeState(
      lastFiredAt: DateTime.utc(2026, 8, 17, 3),
      fireCount: 2,
      wasInsideLocation: true,
      reentrySequence: 1,
      deliveredDedupeKeys: const <String>{'plan-1:2'},
    ),
    events: <TriggerPlanEvent>[
      TriggerPlanEvent(
        id: 'event-1',
        planId: 'plan-1',
        kind: TriggerPlanEventKind.created,
        occurredAt: DateTime.utc(2026, 8, 16, 9),
      ),
      TriggerPlanEvent(
        id: 'event-2',
        planId: 'plan-1',
        kind: TriggerPlanEventKind.fired,
        occurredAt: DateTime.utc(2026, 8, 17, 3),
      ),
      TriggerPlanEvent(
        id: 'event-3',
        planId: 'plan-1',
        kind: TriggerPlanEventKind.opened,
        occurredAt: DateTime.utc(2026, 8, 17, 3, 1),
        metadata: const <String, Object?>{'destination': 'plans'},
      ),
    ],
  );
}
