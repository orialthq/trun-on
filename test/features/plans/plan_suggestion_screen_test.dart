import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/plan_recommendation_service.dart';
import 'package:ori_beauty/features/plans/plan_suggestion_screen.dart';

const _recommendation = PlanRecommendation(
  status: PlanRecommendationStatus.ready,
  todoCount: 2,
  attachedCount: 2,
  groups: <PlanTodoGroup>[
    PlanTodoGroup(
      title: '숙소·이동',
      note: '',
      items: <PlanTodoSuggestion>[
        PlanTodoSuggestion(
          title: '숙소 정하기',
          action: '예약',
          daysBefore: 20,
          note: '',
          selected: true,
          saved: <PlanTodoSavedItem>[
            PlanTodoSavedItem(
              id: 'cap-hotel',
              name: '다낭 미케비치 호텔',
              why: '숙소 후보예요',
            ),
            PlanTodoSavedItem(
              id: 'cap-resort',
              name: '나만 알고 싶은 리조트',
              why: '조용한 곳이에요',
            ),
          ],
        ),
        PlanTodoSuggestion(
          title: '항공권 알아보기',
          action: '구매',
          daysBefore: 30,
          note: '',
          selected: true,
        ),
      ],
    ),
  ],
);

Future<List<PlanTodoSuggestion>?> _run(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester) drive,
) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  List<PlanTodoSuggestion>? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await PlanSuggestionScreen.open(
                  context,
                  planTitle: '베트남 다낭',
                  planDate: DateTime(2026, 9, 3),
                  recommendation: _recommendation,
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();

  await drive(tester);
  return result;
}

void main() {
  testWidgets('saved things start kept and open, so they can be unticked', (
    tester,
  ) async {
    final result = await _run(tester, (tester) async {
      // Unlike every other screen, this one shows the contents straight away:
      // it is where they are chosen.
      expect(find.text('다낭 미케비치 호텔'), findsOneWidget);
      expect(find.text('나만 알고 싶은 리조트'), findsOneWidget);
      expect(find.text('정리함 2개'), findsOneWidget);

      await tester.tap(find.byKey(const Key('saved-row-cap-resort')));
      await tester.pumpAndSettle();

      // The header owns up to the one that was dropped.
      expect(find.text('정리함 1 / 2개'), findsOneWidget);

      await tester.tap(find.byKey(const Key('plan-suggestion-create')));
      await tester.pumpAndSettle();
    });

    expect(result, isNotNull);
    expect(result!.length, 2);
    final stay = result.first;
    expect(stay.title, '숙소 정하기');
    expect(stay.saved.map((one) => one.id), [
      'cap-hotel',
    ], reason: '체크를 푼 저장물이 계획에 실려 나갔습니다');
    // The to-do itself survives losing one of its materials.
    expect(result.last.title, '항공권 알아보기');
  });

  testWidgets('unticking every saved thing still keeps the to-do', (
    tester,
  ) async {
    final result = await _run(tester, (tester) async {
      await tester.tap(find.byKey(const Key('saved-row-cap-hotel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saved-row-cap-resort')));
      await tester.pumpAndSettle();

      expect(find.text('정리함 0 / 2개'), findsOneWidget);

      await tester.tap(find.byKey(const Key('plan-suggestion-create')));
      await tester.pumpAndSettle();
    });

    expect(result!.length, 2);
    // What a plan requires does not depend on what the reader kept for it.
    expect(result.first.title, '숙소 정하기');
    expect(result.first.saved, isEmpty);
  });

  testWidgets('unticking the to-do drops what was inside it', (tester) async {
    final result = await _run(tester, (tester) async {
      // Near the checkbox rather than at the row's centre: with the drawer open
      // the middle of the row is inside it, and that tap belongs to the drawer.
      final row = tester.getTopLeft(find.byKey(const Key('todo-숙소 정하기')));
      await tester.tapAt(row + const Offset(25, 26));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-suggestion-create')));
      await tester.pumpAndSettle();
    });

    expect(result!.map((one) => one.title), ['항공권 알아보기']);
  });
}
