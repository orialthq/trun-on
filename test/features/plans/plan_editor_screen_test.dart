import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/features/plans/plan_editor_screen.dart';

void main() {
  testWidgets('creates a combined time and location draft with a source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scheduledAt = DateTime(2027, 8, 21, 19, 30);
    PlanDraft? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PlanEditorScreen(
          sources: const [
            PlanSourceOption(
              captureId: 'capture-1',
              title: '성수 맛집 캡처',
              subtitle: '식당 세 곳을 정리한 콘텐츠',
            ),
          ],
          initialDraft: PlanDraft(
            title: '',
            triggerKind: PlanDraftTriggerKind.timeAndLocation,
            recurrence: PlanDraftRecurrence.weekly,
            scheduledAt: scheduledAt,
            locationQuery: '',
            sourceCaptureId: 'capture-1',
          ),
          onSave: (draft) => saved = draft,
          popOnSave: false,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('plan-title-field')),
      '금요일에 성수 맛집 가기',
    );
    await tester.ensureVisible(find.byKey(const Key('plan-location-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan-location-field')),
      '성수역 3번 출구',
    );

    // Simulate an open keyboard: the fixed save action must remain usable.
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.tap(find.byKey(const Key('plan-editor-save')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.title, '금요일에 성수 맛집 가기');
    expect(saved!.triggerKind, PlanDraftTriggerKind.timeAndLocation);
    expect(saved!.scheduledAt, scheduledAt);
    expect(saved!.locationQuery, '성수역 3번 출구');
    expect(saved!.recurrence, PlanDraftRecurrence.weekly);
    expect(saved!.sourceCaptureId, 'capture-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches between time and location fields and validates input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlanDraft? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PlanEditorScreen(
          onSave: (draft) => saved = draft,
          popOnSave: false,
        ),
      ),
    );

    expect(find.byKey(const Key('plan-date-picker')), findsOneWidget);
    expect(find.byKey(const Key('plan-location-field')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('plan-trigger-location')));
    await tester.tap(find.byKey(const Key('plan-trigger-location')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-date-picker')), findsNothing);
    expect(find.byKey(const Key('plan-location-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-editor-save')));
    await tester.pump();
    expect(saved, isNull);
    expect(find.text('계획 제목을 입력해 주세요.'), findsOneWidget);
    expect(find.text('알림을 받을 장소를 입력해 주세요.'), findsOneWidget);
    expect(find.byKey(const Key('plan-no-source-notice')), findsOneWidget);
  });
}
