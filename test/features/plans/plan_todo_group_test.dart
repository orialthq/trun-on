import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/plan_recommendation_service.dart';
import 'package:ori_beauty/features/plans/plan_detail_screen.dart';
import 'package:ori_beauty/features/plans/plans_screen.dart';

PlanTodoSuggestion _todo(
  String title, {
  String group = '',
  bool done = false,
}) => PlanTodoSuggestion(
  title: title,
  action: '준비',
  daysBefore: 3,
  note: '',
  selected: true,
  group: group,
  done: done,
);

Future<void> _pumpDetail(
  WidgetTester tester,
  List<PlanTodoSuggestion> todos,
) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: PlanDetailScreen(
        title: '이사',
        triggerLabel: '9월 3일 오전 09:00',
        planDate: DateTime(2026, 9, 3),
        todos: todos,
        onToggle: (_, _) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the group survives the trip through the plan store', () {
    final todo = _todo('박스 사두기', group: '짐 정리');
    expect(PlanTodoSuggestion.fromJson(todo.toJson())?.group, '짐 정리');
    // An older plan has no group written, and reads as one without.
    expect(
      PlanTodoSuggestion.fromJson(<String, Object?>{'title': '전입신고'})?.group,
      '',
    );
  });

  testWidgets('a plan page names each run of to-dos and counts it', (
    tester,
  ) async {
    await _pumpDetail(tester, <PlanTodoSuggestion>[
      _todo('안 쓰는 것 골라내기', group: '짐 정리', done: true),
      _todo('박스 사두기', group: '짐 정리'),
      _todo('전입신고', group: '주소 옮기기'),
    ]);

    expect(find.text('짐 정리'), findsOneWidget);
    expect(find.text('주소 옮기기'), findsOneWidget);
    // The group's own count, not the plan's — the bar above already has that.
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('3개 중 1개 했어요'), findsOneWidget);
  });

  testWidgets('a plan whose to-dos have no group draws no headers', (
    tester,
  ) async {
    await _pumpDetail(tester, <PlanTodoSuggestion>[
      _todo('안 쓰는 것 골라내기'),
      _todo('박스 사두기'),
    ]);

    expect(find.text('0/2'), findsNothing);
    expect(find.text('박스 사두기'), findsOneWidget);
  });

  testWidgets('the card says which group the next to-do belongs to', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PlansScreen(
          plans: <PlanListItem>[
            PlanListItem(
              id: 'move',
              title: '이사',
              status: PlanListStatus.upcoming,
              triggerLabel: '9월 3일 오전 09:00',
              startsAt: DateTime(2026, 9, 3, 9),
              todos: <PlanTodoSuggestion>[
                _todo('안 쓰는 것 골라내기', group: '짐 정리', done: true),
                _todo('전입신고', group: '주소 옮기기'),
              ],
            ),
          ],
          today: DateTime(2026, 8, 21),
          onCreatePlan: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('다음 · 주소 옮기기 · 전입신고'), findsOneWidget);
  });
}
