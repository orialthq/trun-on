import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/plan_recommendation_service.dart';
import 'package:ori_beauty/features/plans/plans_screen.dart';

void main() {
  testWidgets('probe segment sizes', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final plans = [
      PlanListItem(
        id: 'p',
        title: '베트남 다낭',
        status: PlanListStatus.upcoming,
        triggerLabel: '9월 3일',
        startsAt: DateTime(2026, 9, 3),
        todos: <PlanTodoSuggestion>[
          for (var i = 0; i < 6; i++)
            PlanTodoSuggestion(
              title: '할 일 $i',
              action: '',
              daysBefore: 0,
              note: '',
              selected: true,
              done: i < 2,
            ),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PlansScreen(
            plans: plans,
            today: DateTime(2026, 8, 20),
            onCreatePlan: () {},
          ),
        ),
      ),
    );

    final boxes = find.descendant(
      of: find.byKey(const Key('plan-card-p')),
      matching: find.byType(DecoratedBox),
    );
    // ignore: avoid_print
    print('DecoratedBox count under card: ${boxes.evaluate().length}');
    for (final e in boxes.evaluate()) {
      final size = (e.renderObject as RenderBox?)?.size;
      final deco = (e.widget as DecoratedBox).decoration;
      final color = deco is BoxDecoration ? deco.color : null;
      // ignore: avoid_print
      print('  size=$size color=$color');
    }
  });
}
