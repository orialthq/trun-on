import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/data/place_reminder_service.dart';
import 'package:ori_beauty/data/trigger_plan_store.dart';
import 'package:ori_beauty/data/trigger_scheduler.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/domain/trigger_models.dart';
import 'package:ori_beauty/features/analysis/analysis_review_screen.dart';
import 'package:ori_beauty/features/analysis/structured_review_screen.dart';
import 'package:ori_beauty/features/home/home_shell.dart';
import 'package:ori_beauty/features/plans/plan_editor_screen.dart';
import 'package:ori_beauty/features/plans/plans_screen.dart';
import 'package:ori_beauty/state/app_controller.dart';
import 'package:ori_beauty/state/plan_controller.dart';

void main() {
  testWidgets(
    'shows an injected plan controller as the fourth HomeShell destination',
    (tester) async {
      final fixture = await _HomeShellPlansFixture.create();
      addTearDown(fixture.dispose);

      await _pumpHomeShell(tester, fixture);

      final navigationBarFinder = find.byType(NavigationBar);
      final navigationBar = tester.widget<NavigationBar>(navigationBarFinder);
      final plansDestination = find.descendant(
        of: navigationBarFinder,
        matching: find.text('계획함'),
      );

      expect(navigationBar.destinations, hasLength(4));
      expect(plansDestination, findsOneWidget);

      await tester.tap(plansDestination);
      await tester.pumpAndSettle();

      expect(
        tester.widget<NavigationBar>(navigationBarFinder).selectedIndex,
        3,
      );
      expect(find.byType(PlansScreen), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey<String>('plans-screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets('opens the plan creation flow from the HomeShell plans tab', (
    tester,
  ) async {
    final fixture = await _HomeShellPlansFixture.create();
    addTearDown(fixture.dispose);

    await _pumpHomeShell(tester, fixture);

    final plansDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('계획함'),
    );
    await tester.tap(plansDestination);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plans-create-button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlanEditorScreen), findsOneWidget);
    expect(find.byKey(const Key('plan-title-field')), findsOneWidget);
    expect(find.byKey(const Key('plan-editor-save')), findsOneWidget);
  });

  testWidgets(
    'records sourceOpened only after a plan action opens linked content',
    (tester) async {
      final fixture = await _HomeShellPlansFixture.create();
      addTearDown(fixture.dispose);
      final target = fixture.appController.captures.firstWhere(
        (capture) => capture.status != CaptureStatus.analyzing,
      );
      final plan = await fixture.createPlan(sourceCaptureId: target.raw.id);

      await _pumpHomeShell(tester, fixture);
      await _openPlanActions(tester, plan.id);

      final openSource = find.text('연결된 콘텐츠 보기');
      expect(
        find.ancestor(of: openSource, matching: find.byType(SafeArea)),
        findsWidgets,
      );
      await tester.tap(openSource);
      await tester.pumpAndSettle();

      _expectCaptureDetail(target, tester);
      final event = _interactionEvents(
        fixture,
        plan.id,
        TriggerPlanEventKind.sourceOpened,
      ).single;
      expect(event.metadata['captureId'], target.raw.id);
      expect(event.metadata['source'], 'plan_actions');
      expect(event.metadata['planId'], plan.id);
    },
  );

  testWidgets('does not record sourceOpened for an ordinary recent item open', (
    tester,
  ) async {
    final fixture = await _HomeShellPlansFixture.create();
    addTearDown(fixture.dispose);
    final target = fixture.appController.captures
        .take(3)
        .firstWhere((capture) => capture.status != CaptureStatus.analyzing);
    final plan = await fixture.createPlan(sourceCaptureId: target.raw.id);

    await _pumpHomeShell(tester, fixture);
    final recentTitle = find.text(_captureTitle(target));
    await tester.ensureVisible(recentTitle);
    await tester.tap(recentTitle);
    await tester.pumpAndSettle();

    _expectCaptureDetail(target, tester);
    expect(
      _interactionEvents(fixture, plan.id, TriggerPlanEventKind.sourceOpened),
      isEmpty,
    );
  });

  testWidgets(
    'notification navigation records sourceOpened with native open identity',
    (tester) async {
      final fixture = await _HomeShellPlansFixture.create();
      addTearDown(fixture.dispose);
      final target = fixture.appController.captures.firstWhere(
        (capture) => capture.status != CaptureStatus.analyzing,
      );
      final plan = await fixture.createPlan(sourceCaptureId: target.raw.id);

      await _pumpHomeShell(tester, fixture);
      final open = NativeTriggerOpen(
        eventId: 'native-open-1',
        ruleId: plan.id,
        destinationId: target.raw.id,
        occurredAt: DateTime.utc(2026, 8, 18, 12, 1),
      );
      fixture.scheduler.emitOpen(open);
      await tester.pumpAndSettle();
      fixture.scheduler.emitOpen(open);
      await tester.pumpAndSettle();

      _expectCaptureDetail(target, tester);
      final event = _interactionEvents(
        fixture,
        plan.id,
        TriggerPlanEventKind.sourceOpened,
      ).single;
      expect(event.metadata['source'], 'notification');
      expect(event.metadata['nativeOpenEventId'], 'native-open-1');
      expect(event.metadata, isNot(contains('deliveryId')));
      expect(event.metadata, isNot(contains('eventKey')));
    },
  );

  testWidgets('not interested records feedback before pausing the plan', (
    tester,
  ) async {
    final fixture = await _HomeShellPlansFixture.create();
    addTearDown(fixture.dispose);
    final plan = await fixture.createPlan();

    await _pumpHomeShell(tester, fixture);
    await _openPlanActions(tester, plan.id);
    final notInterested = find.text('이런 알림 그만 받기');
    await tester.ensureVisible(notInterested);
    await tester.tap(notInterested);
    await tester.pumpAndSettle();

    expect(
      fixture.planController.planById(plan.id)?.lifecycle,
      PlanLifecycle.paused,
    );
    final kinds = fixture.planController
        .recordById(plan.id)!
        .events
        .map((event) => event.kind)
        .toList();
    expect(kinds, contains(TriggerPlanEventKind.notInterested));
    expect(
      kinds.indexOf(TriggerPlanEventKind.notInterested),
      lessThan(kinds.indexOf(TriggerPlanEventKind.paused)),
    );
  });

  testWidgets('visit result choices record three distinct interactions', (
    tester,
  ) async {
    final fixture = await _HomeShellPlansFixture.create();
    addTearDown(fixture.dispose);
    final plan = await fixture.createPlan();

    await _pumpHomeShell(tester, fixture);
    for (final (label, kind) in [
      ('다녀왔어요', TriggerPlanEventKind.visitConfirmed),
      ('안 갔어요', TriggerPlanEventKind.didNotVisit),
      ('아직 몰라요', TriggerPlanEventKind.visitUnknown),
    ]) {
      await _openPlanActions(tester, plan.id);
      await tester.tap(find.text('방문 결과 남기기'));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(SafeArea)),
        findsWidgets,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(_interactionEvents(fixture, plan.id, kind), hasLength(1));
    }
  });
}

Future<void> _openPlanActions(WidgetTester tester, String planId) async {
  final plansDestination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('계획함'),
  );
  final navigationBar = tester.widget<NavigationBar>(
    find.byType(NavigationBar),
  );
  if (navigationBar.selectedIndex != 3) {
    await tester.tap(plansDestination);
    await tester.pumpAndSettle();
  }
  final card = find.byKey(Key('plan-card-$planId'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

List<TriggerPlanEvent> _interactionEvents(
  _HomeShellPlansFixture fixture,
  String planId,
  TriggerPlanEventKind kind,
) => fixture.planController
    .recordById(planId)!
    .events
    .where((event) => event.kind == kind)
    .toList(growable: false);

String _captureTitle(CaptureRecord capture) {
  final structured = capture.analysis?.structuredContent?.title.value?.trim();
  if (structured != null && structured.isNotEmpty) return structured;
  final mention = capture.primaryMention?.name.value?.trim();
  if (mention != null && mention.isNotEmpty) return mention;
  return capture.normalized.normalizedText.trim();
}

void _expectCaptureDetail(CaptureRecord capture, WidgetTester tester) {
  if (capture.analysis?.structuredContent != null) {
    expect(find.byType(StructuredReviewScreen), findsOneWidget);
  } else {
    expect(find.byType(AnalysisReviewScreen), findsOneWidget);
  }
}

Future<void> _pumpHomeShell(
  WidgetTester tester,
  _HomeShellPlansFixture fixture,
) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: HomeShell(
        controller: fixture.appController,
        planController: fixture.planController,
        placeReminderOpenInbox: fixture.placeReminderOpenInbox,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _HomeShellPlansFixture {
  _HomeShellPlansFixture._({
    required this.appController,
    required this.planController,
    required this.placeReminderOpenInbox,
    required this.scheduler,
  });

  final AppController appController;
  final PlanController planController;
  final InMemoryPlaceReminderOpenInbox placeReminderOpenInbox;
  final _TestTriggerScheduler scheduler;

  static Future<_HomeShellPlansFixture> create() async {
    final appController = AppController(InMemoryIncomingShareService());
    final scheduler = _TestTriggerScheduler();
    final planController = PlanController(
      store: InMemoryTriggerPlanStore(),
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 8, 18, 9),
      idFactory: (_) => 'plan-ui',
      closeSchedulerOnDispose: false,
    );
    final placeReminderOpenInbox = InMemoryPlaceReminderOpenInbox();
    await Future.wait([
      appController.initialize(),
      planController.initialize(),
    ]);
    return _HomeShellPlansFixture._(
      appController: appController,
      planController: planController,
      placeReminderOpenInbox: placeReminderOpenInbox,
      scheduler: scheduler,
    );
  }

  Future<Plan> createPlan({String? sourceCaptureId}) {
    return planController.create(
      PlanDraft(
        title: '저장한 맛집 방문하기',
        triggerKind: PlanDraftTriggerKind.time,
        recurrence: PlanDraftRecurrence.daily,
        scheduledAt: DateTime.utc(2026, 8, 19, 17),
        sourceCaptureId: sourceCaptureId,
      ),
    );
  }

  Future<void> dispose() async {
    planController.dispose();
    appController.dispose();
    await scheduler.close();
    await placeReminderOpenInbox.close();
  }
}

final class _TestTriggerScheduler implements TriggerScheduler {
  final _openedController = StreamController<NativeTriggerOpen>.broadcast();
  final _outcomesController =
      StreamController<List<NativeTriggerOutcome>>.broadcast();

  @override
  Stream<NativeTriggerOpen> get opened => _openedController.stream;

  @override
  Stream<List<NativeTriggerOutcome>> get outcomesChanged =>
      _outcomesController.stream;

  @override
  Stream<List<NativeTriggerOpen>> get opensChanged =>
      const Stream<List<NativeTriggerOpen>>.empty();

  void emitOpen(NativeTriggerOpen open) => _openedController.add(open);

  void emitOutcomes(List<NativeTriggerOutcome> outcomes) =>
      _outcomesController.add(outcomes);

  @override
  Future<ResolvedTriggerLocation?> resolveLocation(String query) async => null;

  @override
  Future<NativeTriggerOperationResult> schedulePlan(
    Plan plan, {
    bool resetState = false,
  }) async => const NativeTriggerOperationResult(
    status: 'registered',
    persisted: true,
    notificationPermissionGranted: true,
  );

  @override
  Future<NativeTriggerCancelResult> cancelPlan(String planId) async =>
      NativeTriggerCancelResult(id: planId, removed: true);

  @override
  Future<NativeTriggerSyncReport> syncPlans(
    Iterable<Plan> plans, {
    Set<String> resetStateIds = const <String>{},
  }) async => NativeTriggerSyncReport(
    status: 'registered',
    storedRuleCount: plans.length,
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
  Future<List<NativeTriggerOutcome>> pendingOutcomes() async => const [];

  @override
  Future<bool> acknowledgeOutcomes(Iterable<String> eventIds) async => true;

  @override
  Future<List<NativeTriggerOpen>> pendingOpens() async => const [];

  @override
  Future<bool> acknowledgeOpens(Iterable<String> eventIds) async => true;

  @override
  Future<void> close() async {
    await _openedController.close();
    await _outcomesController.close();
  }
}
