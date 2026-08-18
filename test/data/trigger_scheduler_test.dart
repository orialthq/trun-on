import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/trigger_scheduler.dart';
import 'package:ori_beauty/domain/trigger_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeTriggerRuleAdapter', () {
    const adapter = NativeTriggerRuleAdapter();
    final mondayMorning = DateTime.utc(2026, 8, 17, 8);

    test('projects a location plan to one geofence rule', () {
      final plan = _plan(
        condition: LocationCondition(
          center: GeoPoint(latitude: 37.5445, longitude: 127.0561),
          radiusMeters: 350,
        ),
        recurrence: TriggerRecurrence.onReentry,
        payload: const {'destinationId': 'capture-7'},
      );

      final wire = adapter.encode(plan, now: mondayMorning);

      expect(wire['destinationId'], 'capture-7');
      expect(wire['recurrence'], 'on_reentry');
      expect(wire['alarmSchedule'], isNull);
      expect(wire['location'], {
        'latitude': 37.5445,
        'longitude': 127.0561,
        'radiusMeters': 350.0,
      });
    });

    test('projects a time plan to a recurring native alarm', () {
      final plan = _plan(
        condition: TimeCondition(
          windowStart: ClockTime(hour: 9, minute: 30),
          windowEnd: ClockTime(hour: 10, minute: 0),
        ),
        recurrence: TriggerRecurrence.daily,
        metadata: const {'timeZoneId': 'Asia/Seoul'},
      );

      final wire = adapter.encode(plan, now: mondayMorning);
      final alarm = wire['alarmSchedule']! as Map<String, Object?>;

      expect(wire['location'], isNull);
      expect(wire['timeWindow'], isNull);
      expect(wire['recurrence'], 'daily');
      expect(
        alarm['firstFireAtMillis'],
        DateTime.utc(2026, 8, 17, 9, 30).millisecondsSinceEpoch,
      );
      expect(alarm['timeZoneId'], 'Asia/Seoul');
    });

    test('projects location AND time to a time-filtered geofence', () {
      final notBefore = DateTime.utc(2026, 8, 18);
      final notAfter = DateTime.utc(2026, 9);
      final plan = _plan(
        condition: AndCondition(
          conditions: [
            LocationCondition(
              center: GeoPoint(latitude: 35.1, longitude: 129.1),
              radiusMeters: 500,
            ),
            TimeCondition(
              notBefore: notBefore,
              notAfter: notAfter,
              windowStart: ClockTime(hour: 11, minute: 0),
              windowEnd: ClockTime(hour: 14, minute: 0),
              weekdays: const {DateTime.monday, DateTime.friday},
            ),
          ],
        ),
        recurrence: TriggerRecurrence.weekly,
      );

      final wire = adapter.encode(plan, now: mondayMorning);

      expect(wire['location'], isNotNull);
      expect(wire['alarmSchedule'], isNull);
      expect(wire['activeFromMillis'], notBefore.millisecondsSinceEpoch);
      expect(wire['activeUntilMillis'], notAfter.millisecondsSinceEpoch);
      expect(wire['timeWindow'], {
        'daysOfWeek': [DateTime.monday, DateTime.friday],
        'startMinuteOfDay': 11 * 60,
        'endMinuteOfDay': 14 * 60,
        'timeZoneId': null,
      });
    });

    test('can use a persisted geocoder result for a combined draft', () {
      final plan = _plan(
        condition: TimeCondition(notBefore: DateTime.utc(2026, 8, 20)),
        recurrence: TriggerRecurrence.once,
        metadata: const {
          'triggerKind': 'timeAndLocation',
          'resolvedLocation': {
            'latitude': 37.5,
            'longitude': 127.0,
            'radiusMeters': 250,
          },
        },
      );

      final wire = adapter.encode(plan, now: mondayMorning);

      expect(wire['alarmSchedule'], isNull);
      expect(wire['location'], {
        'latitude': 37.5,
        'longitude': 127.0,
        'radiusMeters': 250.0,
      });
    });
  });

  group('MethodChannelTriggerScheduler', () {
    const channel = MethodChannel('test/native-trigger-scheduler');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'resolveLocation' => <String, Object?>{
                'status': 'resolved',
                'latitude': 37.5,
                'longitude': 127.0,
                'formattedAddress': '서울 성동구',
              },
              'schedule' => <String, Object?>{
                'status': 'registered',
                'persisted': true,
                'notificationPermissionGranted': false,
                'rule': (call.arguments! as Map<Object?, Object?>)['rule'],
              },
              'cancel' => <String, Object?>{
                'id': (call.arguments! as Map<Object?, Object?>)['id'],
                'removed': true,
              },
              'sync' => <String, Object?>{
                'status': 'registered',
                'storedRuleCount': 1,
                'restoredGeofenceCount': 1,
                'restoredTimeAlarmCount': 0,
                'restoredSnoozeCount': 0,
                'notificationPermissionGranted': true,
              },
              'list' => <Object?>[
                {
                  'rule': {'id': 'plan-1'},
                  'state': {'notificationCount': 2},
                },
              ],
              'reset' => <String, Object?>{
                'id': 'plan-1',
                'status': 'registered',
              },
              'restore' => <String, Object?>{
                'status': 'registered',
                'restoredGeofenceCount': 1,
                'restoredTimeAlarmCount': 0,
                'restoredSnoozeCount': 1,
                'notificationPermissionGranted': true,
              },
              'pendingOutcomes' => <Object?>[
                {
                  'eventId': 'event-fired',
                  'ruleId': 'plan-1',
                  'kind': 'fired',
                  'occurredAtMillis': 1000,
                  'eventKey': 'time:plan-1:1000',
                },
                {
                  'eventId': 'event-later',
                  'ruleId': 'plan-1',
                  'kind': 'later',
                  'occurredAtMillis': 2000,
                  'snoozedUntilMillis': 3000,
                },
              ],
              'pendingOpens' => <Object?>[
                {
                  'eventId': 'open-1',
                  'ruleId': 'plan-1',
                  'destinationId': 'capture-7',
                  'occurredAtMillis': 4000,
                },
              ],
              'acknowledgeOutcomes' || 'acknowledgeOpens' => true,
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('wraps scheduling, sync, lookup and durable queues', () async {
      final scheduler = MethodChannelTriggerScheduler(channel: channel);
      final plan = _plan(
        condition: LocationCondition(
          center: GeoPoint(latitude: 37.5, longitude: 127),
          radiusMeters: 300,
        ),
        recurrence: TriggerRecurrence.onReentry,
      );

      final resolved = await scheduler.resolveLocation('성수역');
      final scheduled = await scheduler.schedulePlan(plan, resetState: true);
      final synced = await scheduler.syncPlans(
        [plan],
        resetStateIds: {'plan-1'},
      );
      final registrations = await scheduler.registeredPlans();
      final outcomes = await scheduler.pendingOutcomes();
      final opens = await scheduler.pendingOpens();
      final reset = await scheduler.resetPlan('plan-1');
      final restored = await scheduler.restore();
      expect(await scheduler.acknowledgeOutcomes(['event-fired']), isTrue);
      expect(await scheduler.acknowledgeOpens(['open-1']), isTrue);

      expect(resolved?.formattedAddress, '서울 성동구');
      expect(scheduled.status, 'registered');
      expect(scheduled.notificationPermissionGranted, isFalse);
      expect(synced.storedRuleCount, 1);
      expect(registrations.single.id, 'plan-1');
      expect(outcomes.first.kind, NativeTriggerOutcomeKind.fired);
      expect(outcomes.first.eventKey, 'time:plan-1:1000');
      expect(outcomes.last.snoozedUntil?.millisecondsSinceEpoch, 3000);
      expect(opens.single.destinationId, 'capture-7');
      expect(reset.status, 'registered');
      expect(restored.restoredSnoozeCount, 1);
      expect(
        calls.firstWhere((call) => call.method == 'schedule').arguments,
        containsPair('resetState', true),
      );
      expect(
        calls.firstWhere((call) => call.method == 'sync').arguments,
        containsPair('resetStateIds', ['plan-1']),
      );
      await scheduler.close();
    });

    test('forwards native callbacks as typed streams', () async {
      final scheduler = MethodChannelTriggerScheduler(channel: channel);
      final opened = scheduler.opened.first;
      final outcomes = scheduler.outcomesChanged.first;
      final opens = scheduler.opensChanged.first;

      await _sendNativeCall(
        channel,
        const MethodCall('triggerOpened', {
          'eventId': 'open-direct',
          'ruleId': 'plan-1',
          'destinationId': 'capture-1',
          'occurredAtMillis': 1000,
        }),
      );
      await _sendNativeCall(
        channel,
        const MethodCall('triggerOutcomesChanged', [
          {
            'eventId': 'done-1',
            'ruleId': 'plan-1',
            'kind': 'done',
            'occurredAtMillis': 2000,
          },
        ]),
      );
      await _sendNativeCall(
        channel,
        const MethodCall('triggerOpensChanged', [
          {
            'eventId': 'open-queued',
            'ruleId': 'plan-1',
            'destinationId': 'capture-2',
            'occurredAtMillis': 3000,
          },
        ]),
      );

      expect((await opened).destinationId, 'capture-1');
      expect((await outcomes).single.kind, NativeTriggerOutcomeKind.done);
      expect((await opens).single.eventId, 'open-queued');
      await scheduler.close();
    });
  });
}

Plan _plan({
  required TriggerCondition condition,
  required TriggerRecurrence recurrence,
  Map<String, Object?> payload = const {},
  Map<String, Object?> metadata = const {},
}) {
  return Plan(
    id: 'plan-1',
    title: '저장한 곳 가기',
    rule: TriggerRule(
      condition: condition,
      recurrence: recurrence,
      cooldown: const Duration(hours: 2),
    ),
    lifecycle: PlanLifecycle.active,
    delivery: TriggerDelivery(
      channel: DeliveryChannel.localNotification,
      title: '근처에 저장한 곳이 있어',
      body: '지금 확인해 봐.',
      payload: payload,
    ),
    createdAt: DateTime.utc(2026, 8, 17),
    metadata: metadata,
  );
}

Future<void> _sendNativeCall(MethodChannel channel, MethodCall call) async {
  final completer = Completer<void>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(call),
        (ByteData? _) => completer.complete(),
      );
  await completer.future;
}
