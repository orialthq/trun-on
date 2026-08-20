import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/plan_recommendation_service.dart';
import 'package:ori_beauty/features/plans/plan_detail_screen.dart';
import 'package:ori_beauty/features/plans/saved_inside_todo.dart';

const _saved = <PlanTodoSavedItem>[
  PlanTodoSavedItem(id: 'cap-1', name: '다낭 미케비치 호텔', why: '숙소 후보로 저장해 뒀어요'),
  PlanTodoSavedItem(id: 'cap-2', name: '반쎄오 맛집', why: '근처에서 먹을 곳이에요'),
];

void main() {
  testWidgets('shut, it says how many; open, it says which', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SavedInsideTodo(saved: _saved)),
      ),
    );

    // Shut is the starting state: a count, and not one name.
    expect(find.text('정리함 2개'), findsOneWidget);
    expect(find.text('다낭 미케비치 호텔'), findsNothing);
    expect(find.text('반쎄오 맛집'), findsNothing);

    await tester.tap(find.byKey(const Key('saved-inside-todo-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('다낭 미케비치 호텔'), findsOneWidget);
    expect(find.text('반쎄오 맛집'), findsOneWidget);
    expect(find.text('숙소 후보로 저장해 뒀어요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saved-inside-todo-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('다낭 미케비치 호텔'), findsNothing);
  });

  testWidgets('opening the drawer does not tick the to-do off', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final toggles = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PlanDetailScreen(
          title: '베트남 다낭',
          triggerLabel: '9월 3일 오전 08:00',
          planDate: DateTime(2026, 9, 3),
          todos: const <PlanTodoSuggestion>[
            PlanTodoSuggestion(
              title: '먹을 곳 정하기',
              action: '보기',
              daysBefore: 5,
              note: '',
              selected: true,
              saved: _saved,
            ),
          ],
          onToggle: (_, done) => toggles.add(done),
        ),
      ),
    );

    expect(find.text('다낭 미케비치 호텔'), findsNothing);

    await tester.tap(find.byKey(const Key('saved-inside-todo-toggle')));
    await tester.pumpAndSettle();

    // The whole to-do row is tappable to tick it. The drawer sits inside that
    // row, so its tap has to win the gesture arena outright.
    expect(toggles, isEmpty, reason: '펼치기가 할 일 체크를 건드렸습니다');
    expect(find.text('다낭 미케비치 호텔'), findsOneWidget);
  });
}
