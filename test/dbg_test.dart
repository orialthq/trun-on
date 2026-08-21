import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/features/plans/plan_editor_screen.dart';

void main() {
  testWidgets('dbg', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PlanEditorScreen(
          initialDraft: PlanDraft(
            title: '저녁 약속',
            triggerKind: PlanDraftTriggerKind.time,
            recurrence: PlanDraftRecurrence.once,
            scheduledAt: DateTime(2027, 8, 16, 19),
          ),
          onSave: (_) {},
          popOnSave: false,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('plan-date-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-date-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-date-day-18')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-date-confirm')));
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print('--- texts ---');
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      // ignore: avoid_print
      print('  [${w.data}]');
    }
  });
}
