import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/plan_recommendation_service.dart';
import 'package:ori_beauty/data/trigger_plan_store.dart';
import 'package:ori_beauty/data/trigger_scheduler.dart';
import 'package:ori_beauty/domain/trigger_models.dart';
import 'package:ori_beauty/features/plans/plan_editor_screen.dart';
import 'package:ori_beauty/features/plans/plans_screen.dart';
import 'package:ori_beauty/state/plan_controller.dart';

void main() {
  final now = DateTime(2026, 8, 17, 9);

  test('creates, persists, and schedules a one-time plan', () async {
    final store = InMemoryTriggerPlanStore();
    final scheduler = _FakeTriggerScheduler();
    final controller = PlanController(
      store: store,
      scheduler: scheduler,
      clock: () => now,
      idFactory: (_) => 'plan-001',
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    final plan = await controller.create(
      PlanDraft(
        title: '여권 챙기기',
        triggerKind: PlanDraftTriggerKind.time,
        recurrence: PlanDraftRecurrence.once,
        scheduledAt: now.add(const Duration(hours: 2)),
        sourceCaptureId: 'capture-7',
      ),
    );

    expect(plan.id, 'plan-001');
    expect(plan.rule.condition, isA<TimeCondition>());
    expect(plan.delivery.payload['destinationId'], 'capture-7');
    expect(scheduler.scheduled.single.plan.id, plan.id);
    expect(scheduler.scheduled.single.resetState, isTrue);
    expect((await store.load()).single.events.map((event) => event.kind), [
      TriggerPlanEventKind.created,
      TriggerPlanEventKind.scheduled,
    ]);
    expect(controller.items.single.status, PlanListStatus.upcoming);
    expect(controller.items.single.sourceLabel, '연결된 콘텐츠');
  });

  test('resolves an address before creating a location plan', () async {
    final store = InMemoryTriggerPlanStore();
    final scheduler = _FakeTriggerScheduler()
      ..resolvedLocations['서울숲'] = ResolvedTriggerLocation(
        point: GeoPoint(latitude: 37.544, longitude: 127.037),
        formattedAddress: '서울 성동구 서울숲',
      );
    final controller = PlanController(
      store: store,
      scheduler: scheduler,
      clock: () => now,
      idFactory: (_) => 'plan-location',
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    final plan = await controller.create(
      const PlanDraft(
        title: '저장한 카페 들르기',
        triggerKind: PlanDraftTriggerKind.location,
        recurrence: PlanDraftRecurrence.onReentry,
        locationQuery: '서울숲',
      ),
    );

    final condition = plan.rule.condition as LocationCondition;
    expect(condition.radiusMeters, 500);
    expect(condition.center.latitude, 37.544);
    expect(plan.metadata['formattedAddress'], '서울 성동구 서울숲');
    expect(controller.items.single.triggerLabel, contains('서울숲'));
  });

  test('does not persist a location plan when resolution fails', () async {
    final store = InMemoryTriggerPlanStore();
    final controller = PlanController(
      store: store,
      scheduler: _FakeTriggerScheduler(),
      clock: () => now,
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    await expectLater(
      controller.create(
        const PlanDraft(
          title: '찾을 수 없는 곳',
          triggerKind: PlanDraftTriggerKind.location,
          recurrence: PlanDraftRecurrence.once,
          locationQuery: '존재하지 않는 주소',
        ),
      ),
      throwsA(isA<PlanLocationResolutionException>()),
    );
    expect(controller.plans, isEmpty);
    expect(await store.load(), isEmpty);
  });

  test(
    'applies and acknowledges durable done and open events on initialize',
    () async {
      final plan = _plan(
        id: 'plan-existing',
        now: now,
        sourceCaptureId: 'capture-existing',
      );
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final scheduler = _FakeTriggerScheduler()
        ..queuedOutcomes.add(
          NativeTriggerOutcome(
            eventId: 'done-1',
            ruleId: plan.id,
            kind: NativeTriggerOutcomeKind.done,
            occurredAt: now.add(const Duration(minutes: 5)),
          ),
        )
        ..queuedOpens.add(
          NativeTriggerOpen(
            eventId: 'open-1',
            ruleId: plan.id,
            destinationId: 'capture-existing',
            occurredAt: now.add(const Duration(minutes: 6)),
          ),
        );
      final controller = PlanController(
        store: store,
        scheduler: scheduler,
        clock: () => now,
        closeSchedulerOnDispose: false,
      );

      await controller.initialize();

      expect(controller.planById(plan.id)!.lifecycle, PlanLifecycle.completed);
      expect(controller.pendingSourceCaptureId, 'capture-existing');
      expect(scheduler.acknowledgedOutcomeIds, ['done-1']);
      expect(scheduler.acknowledgedOpenIds, ['open-1']);
      expect(scheduler.cancelledIds, contains(plan.id));
      expect(
        controller.recordById(plan.id)!.events.map((event) => event.kind),
        [TriggerPlanEventKind.completed, TriggerPlanEventKind.opened],
      );
      expect(controller.consumePendingOpen()?.eventId, 'open-1');
      expect(controller.pendingOpen, isNull);
    },
  );

  test(
    'does not route a consumed native open twice until controller restart',
    () async {
      final plan = _plan(id: 'plan-open-dedupe', now: now);
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final scheduler = _FakeTriggerScheduler();
      final controller = PlanController(
        store: store,
        scheduler: scheduler,
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await controller.initialize();
      final open = NativeTriggerOpen(
        eventId: 'open-redelivered',
        ruleId: plan.id,
        destinationId: 'capture-open',
        occurredAt: now.add(const Duration(minutes: 1)),
      );

      scheduler.emitOpen(open);
      await _flushController(controller);
      expect(controller.consumePendingOpen()?.eventId, 'open-redelivered');

      scheduler.emitOpens(<NativeTriggerOpen>[open]);
      await _flushController(controller);
      expect(controller.pendingOpen, isNull);
      expect(
        controller
            .recordById(plan.id)!
            .events
            .where((event) => event.kind == TriggerPlanEventKind.opened),
        hasLength(1),
      );
      controller.dispose();

      final restartedScheduler = _FakeTriggerScheduler()..queuedOpens.add(open);
      final restartedController = PlanController(
        store: store,
        scheduler: restartedScheduler,
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await restartedController.initialize();

      expect(restartedController.pendingOpen?.eventId, 'open-redelivered');
      expect(
        restartedController
            .recordById(plan.id)!
            .events
            .where((event) => event.kind == TriggerPlanEventKind.opened),
        hasLength(1),
      );
    },
  );

  test(
    'pause, resume, snooze, and delete keep native and store in sync',
    () async {
      final store = InMemoryTriggerPlanStore();
      final scheduler = _FakeTriggerScheduler();
      final controller = PlanController(
        store: store,
        scheduler: scheduler,
        clock: () => now,
        idFactory: (_) => 'plan-actions',
        closeSchedulerOnDispose: false,
      );
      await controller.initialize();
      final created = await controller.create(
        PlanDraft(
          title: '매일 물 마시기',
          triggerKind: PlanDraftTriggerKind.time,
          recurrence: PlanDraftRecurrence.daily,
          scheduledAt: now.add(const Duration(hours: 1)),
        ),
      );

      await controller.pause(created.id);
      expect(controller.planById(created.id)!.lifecycle, PlanLifecycle.paused);
      await controller.resume(created.id);
      expect(controller.planById(created.id)!.lifecycle, PlanLifecycle.active);
      await controller.snooze(created.id, delay: const Duration(minutes: 45));
      expect(
        controller.planById(created.id)!.metadata['snoozedUntil'],
        now.add(const Duration(minutes: 45)).toIso8601String(),
      );
      await controller.delete(created.id);

      expect(controller.plans, isEmpty);
      expect(await store.load(), isEmpty);
      expect(scheduler.cancelledIds, [created.id]);
    },
  );

  test('snoozing a one-time plan keeps its delivery window valid', () async {
    final controller = PlanController(
      store: InMemoryTriggerPlanStore(),
      scheduler: _FakeTriggerScheduler(),
      clock: () => now,
      idFactory: (_) => 'plan-once-snooze',
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();
    final created = await controller.create(
      PlanDraft(
        title: '잠깐 뒤에 알려줘',
        triggerKind: PlanDraftTriggerKind.time,
        recurrence: PlanDraftRecurrence.once,
        scheduledAt: now.add(const Duration(minutes: 5)),
      ),
    );

    await controller.snooze(created.id, delay: const Duration(hours: 2));

    final condition =
        controller.planById(created.id)!.rule.condition as TimeCondition;
    expect(condition.notBefore, now.add(const Duration(hours: 2)));
    expect(condition.notAfter, now.add(const Duration(hours: 3)));
  });

  test(
    'records notification disabled only when native permission becomes false',
    () async {
      final plan = _plan(
        id: 'plan-permission',
        now: now,
        sourceCaptureId: 'capture-permission',
        metadata: const <String, Object?>{
          'experimentId': 'EXP-001',
          'variant': 'treatment',
          'scenarioId': 'SCN-003',
        },
      );
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final scheduler = _FakeTriggerScheduler()
        ..scheduleResult = const NativeTriggerOperationResult(
          status: 'saved_disabled',
          notificationPermissionGranted: false,
        );
      final controller = PlanController(
        store: store,
        scheduler: scheduler,
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await controller.initialize();

      await controller.pause(plan.id);
      await controller.resume(plan.id);
      expect(
        controller
            .recordById(plan.id)!
            .events
            .where(
              (event) =>
                  event.kind == TriggerPlanEventKind.notificationDisabled,
            ),
        hasLength(1),
      );

      scheduler.scheduleResult = const NativeTriggerOperationResult(
        status: 'registered',
      );
      await controller.pause(plan.id);
      scheduler.scheduleResult = const NativeTriggerOperationResult(
        status: 'saved_disabled',
        notificationPermissionGranted: false,
      );
      await controller.resume(plan.id);
      expect(
        controller
            .recordById(plan.id)!
            .events
            .where(
              (event) =>
                  event.kind == TriggerPlanEventKind.notificationDisabled,
            ),
        hasLength(1),
      );

      scheduler.scheduleResult = const NativeTriggerOperationResult(
        status: 'registration_failed',
        notificationPermissionGranted: true,
      );
      await controller.pause(plan.id);
      scheduler.scheduleResult = const NativeTriggerOperationResult(
        status: 'saved_disabled',
        notificationPermissionGranted: false,
      );
      await controller.resume(plan.id);

      final disabledEvents = (await store.load()).single.events
          .where(
            (event) => event.kind == TriggerPlanEventKind.notificationDisabled,
          )
          .toList(growable: false);
      expect(disabledEvents, hasLength(2));
      expect(
        disabledEvents.last.metadata,
        containsPair('source', 'native-scheduler'),
      );
      expect(
        disabledEvents.last.metadata,
        containsPair('nativeStatus', 'saved_disabled'),
      );
      expect(
        disabledEvents.last.metadata,
        containsPair('experimentId', 'EXP-001'),
      );
      expect(
        disabledEvents.last.metadata,
        containsPair('variant', 'treatment'),
      );
      expect(
        disabledEvents.last.metadata,
        containsPair('scenarioId', 'SCN-003'),
      );
      expect(
        disabledEvents.last.metadata,
        containsPair('sourceCaptureId', 'capture-permission'),
      );
    },
  );

  test(
    'sync records notification permission transitions on initialize and resume',
    () async {
      final plan = _plan(
        id: 'plan-sync-permission',
        now: now,
        sourceCaptureId: 'capture-sync-permission',
        metadata: const <String, Object?>{
          'experimentId': 'EXP-001',
          'variant': 'treatment',
          'scenarioId': 'SCN-003',
        },
      );
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final scheduler = _FakeTriggerScheduler()
        ..syncResult = const NativeTriggerSyncReport(
          status: 'registered',
          notificationPermissionGranted: false,
        );
      final controller = PlanController(
        store: store,
        scheduler: scheduler,
        clock: () => now,
        closeSchedulerOnDispose: false,
      );

      await controller.initialize();
      await controller.refreshScheduling();
      expect(
        controller
            .recordById(plan.id)!
            .events
            .where(
              (event) =>
                  event.kind == TriggerPlanEventKind.notificationDisabled,
            ),
        hasLength(1),
      );

      scheduler.syncResult = const NativeTriggerSyncReport(
        status: 'registered',
        notificationPermissionGranted: true,
      );
      await controller.refreshScheduling();
      scheduler.syncResult = const NativeTriggerSyncReport(
        status: 'registered',
        notificationPermissionGranted: false,
      );
      await controller.refreshScheduling();

      final events = (await store.load()).single.events;
      expect(
        events.where(
          (event) => event.kind == TriggerPlanEventKind.notificationDisabled,
        ),
        hasLength(2),
      );
      final restored = events.last;
      expect(restored.metadata['source'], 'native-sync');
      expect(restored.metadata['experimentId'], 'EXP-001');
      expect(restored.metadata['sourceCaptureId'], 'capture-sync-permission');
    },
  );

  test('local snooze and scheduling events preserve plan context', () async {
    final plan = _plan(
      id: 'plan-context',
      now: now,
      sourceCaptureId: 'capture-context',
      metadata: const <String, Object?>{
        'experimentId': 'EXP-001',
        'variant': 'treatment',
        'scenarioId': 'SCN-003',
      },
    );
    final store = InMemoryTriggerPlanStore();
    await store.save(<PersistedTriggerPlan>[PersistedTriggerPlan(plan: plan)]);
    final controller = PlanController(
      store: store,
      scheduler: _FakeTriggerScheduler(),
      clock: () => now,
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    await controller.snooze(plan.id);

    final events = (await store.load()).single.events;
    for (final kind in <TriggerPlanEventKind>[
      TriggerPlanEventKind.snoozed,
      TriggerPlanEventKind.scheduled,
    ]) {
      final metadata = events
          .firstWhere((event) => event.kind == kind)
          .metadata;
      expect(metadata['experimentId'], 'EXP-001');
      expect(metadata['variant'], 'treatment');
      expect(metadata['scenarioId'], 'SCN-003');
      expect(metadata['sourceCaptureId'], 'capture-context');
    }
  });

  test(
    'recordInteraction persists JSON-safe metadata with canonical plan context',
    () async {
      final plan = _plan(
        id: 'plan-interaction',
        now: now,
        sourceCaptureId: ' capture-plan ',
        metadata: const <String, Object?>{
          'experimentId': ' EXP-001 ',
          'variant': 'treatment',
        },
      );
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final controller = PlanController(
        store: store,
        scheduler: _FakeTriggerScheduler(),
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await controller.initialize();

      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.mapOpened,
        <String, Object?>{
          'experimentId': 'wrong-experiment',
          'variant': 'wrong-variant',
          'scenarioId': ' SCN-003 ',
          'sourceCaptureId': 'wrong-capture',
          'provider': 'naver',
          'eventKey': ' delivery-001 ',
          'nested': <String, Object?>{'success': true, 'attempt': 1},
          'unsafe': Object(),
          'nonFinite': double.nan,
          'unsafeList': <Object?>[Object()],
          '   ': 'ignored',
        },
      );

      final event = (await store.load()).single.events.single;
      expect(event.kind, TriggerPlanEventKind.mapOpened);
      expect(event.occurredAt, now);
      expect(event.metadata, <String, Object?>{
        'experimentId': 'EXP-001',
        'variant': 'treatment',
        'scenarioId': 'SCN-003',
        'sourceCaptureId': 'capture-plan',
        'provider': 'naver',
        'eventKey': 'delivery-001',
        'nested': <String, Object?>{'success': true, 'attempt': 1},
      });
    },
  );

  test(
    'recordInteraction can be retried after a failed snapshot write',
    () async {
      final plan = _plan(id: 'plan-interaction-retry', now: now);
      final store = _FailOnceTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final controller = PlanController(
        store: store,
        scheduler: _FakeTriggerScheduler(),
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await controller.initialize();
      store.failNextSave = true;

      await expectLater(
        controller.recordInteraction(
          plan.id,
          TriggerPlanEventKind.sourceOpened,
          const <String, Object?>{'eventKey': 'retry-open'},
        ),
        throwsStateError,
      );
      expect(controller.recordById(plan.id)!.events, isEmpty);

      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
        const <String, Object?>{'eventKey': 'retry-open'},
      );

      expect((await store.load()).single.events, hasLength(1));
    },
  );

  test('recordInteraction only accepts user interaction event kinds', () async {
    final plan = _plan(id: 'plan-feedback', now: now);
    final store = InMemoryTriggerPlanStore();
    await store.save(<PersistedTriggerPlan>[PersistedTriggerPlan(plan: plan)]);
    final controller = PlanController(
      store: store,
      scheduler: _FakeTriggerScheduler(),
      clock: () => now,
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    const interactionKinds = <TriggerPlanEventKind>[
      TriggerPlanEventKind.sourceOpened,
      TriggerPlanEventKind.mapOpened,
      TriggerPlanEventKind.routeStarted,
      TriggerPlanEventKind.notInterested,
      TriggerPlanEventKind.visitConfirmed,
      TriggerPlanEventKind.didNotVisit,
      TriggerPlanEventKind.visitUnknown,
      TriggerPlanEventKind.notificationDisabled,
    ];
    for (final kind in interactionKinds) {
      await controller.recordInteraction(plan.id, kind);
    }

    expect(
      controller.recordById(plan.id)!.events.map((event) => event.kind),
      interactionKinds,
    );
    expect(
      () => controller.recordInteraction(plan.id, TriggerPlanEventKind.fired),
      throwsArgumentError,
    );
    expect(
      () =>
          controller.recordInteraction(plan.id, TriggerPlanEventKind.eligible),
      throwsArgumentError,
    );
  });

  test(
    'recordInteraction deduplicates identities within the same event kind',
    () async {
      final plan = _plan(id: 'plan-dedupe', now: now);
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final controller = PlanController(
        store: store,
        scheduler: _FakeTriggerScheduler(),
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await controller.initialize();

      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
        const <String, Object?>{'eventKey': ' event-1 '},
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
        const <String, Object?>{'eventKey': 'event-1'},
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.mapOpened,
        const <String, Object?>{'eventKey': 'event-1'},
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
        const <String, Object?>{'deliveryId': ' delivery-2 '},
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
        const <String, Object?>{'deliveryId': 'delivery-2'},
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
        const <String, Object?>{'nativeOpenEventId': ' native-open-3 '},
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
        const <String, Object?>{'nativeOpenEventId': 'native-open-3'},
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
      );
      await controller.recordInteraction(
        plan.id,
        TriggerPlanEventKind.sourceOpened,
      );

      final events = (await store.load()).single.events;
      expect(
        events.where(
          (event) => event.kind == TriggerPlanEventKind.sourceOpened,
        ),
        hasLength(5),
      );
      expect(
        events.where((event) => event.kind == TriggerPlanEventKind.mapOpened),
        hasLength(1),
      );
      expect(events.first.metadata['eventKey'], 'event-1');
      expect(events[2].metadata['deliveryId'], 'delivery-2');
      expect(events[3].metadata['nativeOpenEventId'], 'native-open-3');
    },
  );

  test(
    'foreground eligibility stays distinct from deduplicated native delivery',
    () async {
      final plan = _plan(
        id: 'plan-eligible',
        now: now,
        sourceCaptureId: 'capture-eligible',
        metadata: const <String, Object?>{
          'experimentId': 'EXP-001',
          'variant': 'baseline',
          'scenarioId': 'SCN-004',
        },
      );
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final firstController = PlanController(
        store: store,
        scheduler: _FakeTriggerScheduler(),
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await firstController.initialize();

      final outcome = await firstController.evaluatePlan(
        plan.id,
        context: TriggerEvaluationContext(
          now: now.add(const Duration(hours: 1)),
        ),
      );

      expect(outcome.shouldFire, isTrue);
      final eligible = firstController.recordById(plan.id)!.events.single;
      expect(eligible.kind, TriggerPlanEventKind.eligible);
      expect(eligible.metadata['eventKey'], 'plan-eligible:once');
      expect(eligible.metadata['deliveryKey'], 'plan-eligible:once');
      expect(eligible.metadata['source'], 'foreground-engine');
      expect(eligible.metadata['experimentId'], 'EXP-001');
      final foregroundRecord = firstController.recordById(plan.id)!;
      expect(foregroundRecord.plan.lifecycle, PlanLifecycle.active);
      expect(foregroundRecord.runtimeState.lastFiredAt, isNull);
      expect(foregroundRecord.runtimeState.fireCount, 0);
      expect(foregroundRecord.runtimeState.deliveredDedupeKeys, isEmpty);
      expect(
        firstController.recordById(plan.id)!.events,
        isNot(
          contains(
            isA<TriggerPlanEvent>().having(
              (event) => event.kind,
              'kind',
              TriggerPlanEventKind.fired,
            ),
          ),
        ),
      );
      firstController.dispose();

      final scheduler = _FakeTriggerScheduler()
        ..queuedOutcomes.addAll(<NativeTriggerOutcome>[
          NativeTriggerOutcome(
            eventId: 'native-fired-1',
            ruleId: plan.id,
            kind: NativeTriggerOutcomeKind.fired,
            occurredAt: now.add(const Duration(hours: 1, minutes: 1)),
            eventKey: ' plan-eligible:once ',
          ),
          NativeTriggerOutcome(
            eventId: 'native-fired-duplicate',
            ruleId: plan.id,
            kind: NativeTriggerOutcomeKind.fired,
            occurredAt: now.add(const Duration(hours: 1, minutes: 2)),
            eventKey: 'plan-eligible:once',
          ),
          NativeTriggerOutcome(
            eventId: 'native-later-1',
            ruleId: plan.id,
            kind: NativeTriggerOutcomeKind.later,
            occurredAt: now.add(const Duration(hours: 1, minutes: 3)),
            snoozedUntil: now.add(const Duration(hours: 2)),
            eventKey: 'plan-eligible:once',
          ),
        ]);
      final restoredController = PlanController(
        store: store,
        scheduler: scheduler,
        clock: () => now,
        closeSchedulerOnDispose: false,
      );

      await restoredController.initialize();

      final events = restoredController.recordById(plan.id)!.events;
      expect(
        events.where((event) => event.kind == TriggerPlanEventKind.eligible),
        hasLength(1),
      );
      expect(
        events.where((event) => event.kind == TriggerPlanEventKind.fired),
        hasLength(1),
      );
      expect(
        events.where((event) => event.kind == TriggerPlanEventKind.snoozed),
        hasLength(1),
      );
      expect(
        events
            .firstWhere((event) => event.kind == TriggerPlanEventKind.fired)
            .metadata['eventKey'],
        'plan-eligible:once',
      );
      expect(scheduler.acknowledgedOutcomeIds, <String>[
        'native-fired-1',
        'native-fired-duplicate',
        'native-later-1',
      ]);
    },
  );

  test(
    'foreground eligibility preserves location transition but not delivery state',
    () async {
      final plan = _plan(id: 'plan-reentry', now: now).copyWith(
        rule: TriggerRule(
          condition: LocationCondition(
            center: GeoPoint(latitude: 37.5, longitude: 127),
            radiusMeters: 500,
          ),
          recurrence: TriggerRecurrence.onReentry,
          dedupeKey: 'plan-reentry',
        ),
      );
      final store = InMemoryTriggerPlanStore();
      await store.save(<PersistedTriggerPlan>[
        PersistedTriggerPlan(plan: plan),
      ]);
      final controller = PlanController(
        store: store,
        scheduler: _FakeTriggerScheduler(),
        clock: () => now,
        closeSchedulerOnDispose: false,
      );
      await controller.initialize();
      final context = TriggerEvaluationContext(
        now: now.add(const Duration(minutes: 1)),
        location: GeoPoint(latitude: 37.5, longitude: 127),
      );

      final eligible = await controller.evaluatePlan(plan.id, context: context);
      final afterEligible = controller.recordById(plan.id)!;

      expect(eligible.shouldFire, isTrue);
      expect(afterEligible.runtimeState.wasInsideLocation, isTrue);
      expect(afterEligible.runtimeState.reentrySequence, 1);
      expect(afterEligible.runtimeState.lastFiredAt, isNull);
      expect(afterEligible.runtimeState.fireCount, 0);
      expect(afterEligible.runtimeState.deliveredDedupeKeys, isEmpty);

      final stillInside = await controller.evaluatePlan(
        plan.id,
        context: context,
      );
      expect(stillInside.shouldFire, isFalse);
      expect(
        controller
            .recordById(plan.id)!
            .events
            .where((event) => event.kind == TriggerPlanEventKind.eligible),
        hasLength(1),
      );
    },
  );

  test('ticking a to-do reaches the list card and survives a reload', () async {
    final store = InMemoryTriggerPlanStore();
    final scheduler = _FakeTriggerScheduler();
    final controller = PlanController(
      store: store,
      scheduler: scheduler,
      clock: () => now,
      idFactory: (_) => 'plan-todos',
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    await controller.create(
      PlanDraft(
        title: '베트남 다낭',
        triggerKind: PlanDraftTriggerKind.time,
        recurrence: PlanDraftRecurrence.once,
        scheduledAt: now.add(const Duration(days: 14)),
        endsAt: now.add(const Duration(days: 18)),
      ),
      todos: const <PlanTodoSuggestion>[
        PlanTodoSuggestion(
          title: '숙소 예약하기',
          action: '예약',
          daysBefore: 20,
          note: '',
          selected: true,
        ),
        PlanTodoSuggestion(
          title: '먹을 곳 정하기',
          action: '보기',
          daysBefore: 5,
          note: '',
          selected: true,
        ),
      ],
    );

    expect(controller.items.single.todos.length, 2);
    expect(controller.items.single.doneCount, 0);
    expect(controller.items.single.nextTodo?.title, '숙소 예약하기');
    expect(controller.items.single.endsAt, isNotNull);
    expect(controller.items.single.dayCount, 5);

    await controller.setTodoDone('plan-todos', 0, true);

    // The list card reads the same records the detail screen ticked.
    expect(controller.items.single.doneCount, 1);
    expect(controller.items.single.nextTodo?.title, '먹을 곳 정하기');

    // And it is durable: a fresh controller over the same store agrees.
    final reloaded = PlanController(
      store: store,
      scheduler: _FakeTriggerScheduler(),
      clock: () => now,
      closeSchedulerOnDispose: false,
    );
    await reloaded.initialize();
    expect(reloaded.items.single.doneCount, 1);
    expect(reloaded.items.single.endsAt, isNotNull);
  });

  test('a lead time moves the alarm without moving the plan', () async {
    final store = InMemoryTriggerPlanStore();
    final scheduler = _FakeTriggerScheduler();
    final controller = PlanController(
      store: store,
      scheduler: scheduler,
      clock: () => now,
      idFactory: (_) => 'plan-lead',
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    final happensAt = DateTime(2026, 8, 31, 19);
    final plan = await controller.create(
      PlanDraft(
        title: '성수 저녁 약속',
        triggerKind: PlanDraftTriggerKind.time,
        recurrence: PlanDraftRecurrence.once,
        scheduledAt: happensAt,
        leadTime: PlanLeadTime.twoHours,
      ),
      todos: const <PlanTodoSuggestion>[
        PlanTodoSuggestion(
          title: '자리 예약하기',
          action: '예약',
          daysBefore: 3,
          note: '',
          selected: true,
        ),
      ],
    );

    // The trigger fires two hours early...
    final condition = plan.rule.condition as TimeCondition;
    expect(condition.notBefore, DateTime(2026, 8, 31, 17));

    // ...but everything the reader reads is still measured from seven.
    final item = controller.items.single;
    expect(item.startsAt, happensAt, reason: 'D-day가 리드타임만큼 밀렸습니다');
    expect(item.daysUntil(now), 14);
    expect(item.todos.single.dueDate(item.startsAt!), DateTime(2026, 8, 28));

    // And it survives the trip through the store.
    final reloaded = PlanController(
      store: store,
      scheduler: _FakeTriggerScheduler(),
      clock: () => now,
      closeSchedulerOnDispose: false,
    );
    await reloaded.initialize();
    expect(reloaded.items.single.startsAt, happensAt);
  });

  test('a plan that spans days lives until its last one', () async {
    final store = InMemoryTriggerPlanStore();
    final scheduler = _FakeTriggerScheduler();
    final controller = PlanController(
      store: store,
      scheduler: scheduler,
      clock: () => now,
      idFactory: (_) => 'plan-trip',
      closeSchedulerOnDispose: false,
    );
    await controller.initialize();

    final plan = await controller.create(
      PlanDraft(
        title: '베트남 다낭',
        triggerKind: PlanDraftTriggerKind.time,
        recurrence: PlanDraftRecurrence.once,
        scheduledAt: DateTime(2026, 8, 31, 9),
        endsAt: DateTime(2026, 9, 4),
        leadTime: PlanLeadTime.oneDay,
      ),
    );

    // Without this a five-day trip expired on the afternoon of day one.
    expect(plan.expiresAt, DateTime(2026, 9, 5));
    // The lead counts from the day it starts, never from the last day.
    expect(
      (plan.rule.condition as TimeCondition).notBefore,
      DateTime(2026, 8, 30, 9),
    );
  });
}

Future<void> _flushController(PlanController controller) async {
  await Future<void>.delayed(Duration.zero);
  await controller.refreshScheduling();
}

Plan _plan({
  required String id,
  required DateTime now,
  String? sourceCaptureId,
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  return Plan(
    id: id,
    title: '저장한 장소',
    rule: TriggerRule(
      condition: TimeCondition(notBefore: now.add(const Duration(hours: 1))),
      recurrence: TriggerRecurrence.once,
    ),
    lifecycle: PlanLifecycle.active,
    delivery: TriggerDelivery(
      channel: DeliveryChannel.localNotification,
      title: '저장한 장소',
      body: '확인해 보세요',
    ),
    createdAt: now,
    metadata: <String, Object?>{
      'sourceCaptureId': ?sourceCaptureId,
      ...metadata,
    },
  );
}

final class _ScheduledCall {
  const _ScheduledCall(this.plan, this.resetState);

  final Plan plan;
  final bool resetState;
}

final class _FailOnceTriggerPlanStore implements TriggerPlanStore {
  final InMemoryTriggerPlanStore _delegate = InMemoryTriggerPlanStore();

  bool failNextSave = false;

  @override
  Future<List<PersistedTriggerPlan>> load() => _delegate.load();

  @override
  Future<void> save(List<PersistedTriggerPlan> plans) {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('snapshot write failed');
    }
    return _delegate.save(plans);
  }
}

final class _FakeTriggerScheduler implements TriggerScheduler {
  final StreamController<NativeTriggerOpen> _opened =
      StreamController<NativeTriggerOpen>.broadcast();
  final StreamController<List<NativeTriggerOutcome>> _outcomes =
      StreamController<List<NativeTriggerOutcome>>.broadcast();
  final StreamController<List<NativeTriggerOpen>> _opens =
      StreamController<List<NativeTriggerOpen>>.broadcast();

  final Map<String, ResolvedTriggerLocation> resolvedLocations = {};
  final List<_ScheduledCall> scheduled = [];
  final List<String> cancelledIds = [];
  final List<NativeTriggerOutcome> queuedOutcomes = [];
  final List<NativeTriggerOpen> queuedOpens = [];
  final List<String> acknowledgedOutcomeIds = [];
  final List<String> acknowledgedOpenIds = [];
  NativeTriggerOperationResult scheduleResult =
      const NativeTriggerOperationResult(
        status: 'registered',
        persisted: true,
        notificationPermissionGranted: true,
      );
  NativeTriggerSyncReport syncResult = const NativeTriggerSyncReport(
    status: 'registered',
  );

  void emitOpen(NativeTriggerOpen open) => _opened.add(open);

  void emitOpens(List<NativeTriggerOpen> opens) => _opens.add(opens);

  @override
  Stream<NativeTriggerOpen> get opened => _opened.stream;

  @override
  Stream<List<NativeTriggerOutcome>> get outcomesChanged => _outcomes.stream;

  @override
  Stream<List<NativeTriggerOpen>> get opensChanged => _opens.stream;

  @override
  Future<ResolvedTriggerLocation?> resolveLocation(String query) async =>
      resolvedLocations[query];

  @override
  Future<NativeTriggerOperationResult> schedulePlan(
    Plan plan, {
    bool resetState = false,
  }) async {
    scheduled.add(_ScheduledCall(plan, resetState));
    return scheduleResult;
  }

  @override
  Future<NativeTriggerCancelResult> cancelPlan(String planId) async {
    cancelledIds.add(planId);
    return NativeTriggerCancelResult(id: planId, removed: true);
  }

  @override
  Future<NativeTriggerSyncReport> syncPlans(
    Iterable<Plan> plans, {
    Set<String> resetStateIds = const <String>{},
  }) async => NativeTriggerSyncReport(
    status: syncResult.status,
    storedRuleCount: plans.length,
    restoredGeofenceCount: syncResult.restoredGeofenceCount,
    restoredTimeAlarmCount: syncResult.restoredTimeAlarmCount,
    restoredSnoozeCount: syncResult.restoredSnoozeCount,
    notificationPermissionGranted: syncResult.notificationPermissionGranted,
  );

  @override
  Future<List<NativeTriggerRegistration>> registeredPlans() async => const [];

  @override
  Future<NativeTriggerOperationResult> resetPlan(String planId) async =>
      const NativeTriggerOperationResult(status: 'registered');

  @override
  Future<NativeTriggerSyncReport> restore() async =>
      const NativeTriggerSyncReport(status: 'registered');

  @override
  Future<List<NativeTriggerOutcome>> pendingOutcomes() async =>
      List<NativeTriggerOutcome>.of(queuedOutcomes);

  @override
  Future<bool> acknowledgeOutcomes(Iterable<String> eventIds) async {
    acknowledgedOutcomeIds.addAll(eventIds);
    return true;
  }

  @override
  Future<List<NativeTriggerOpen>> pendingOpens() async =>
      List<NativeTriggerOpen>.of(queuedOpens);

  @override
  Future<bool> acknowledgeOpens(Iterable<String> eventIds) async {
    acknowledgedOpenIds.addAll(eventIds);
    return true;
  }

  @override
  Future<void> close() async {
    await _opened.close();
    await _outcomes.close();
    await _opens.close();
  }
}
