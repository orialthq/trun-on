import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/features/plans/past_plans_screen.dart';
import 'package:ori_beauty/features/plans/plans_screen.dart';

PlanListItem _plan({
  required String id,
  required String title,
  PlanListStatus status = PlanListStatus.completed,
  DateTime? startsAt,
  DateTime? endsAt,
}) => PlanListItem(
  id: id,
  title: title,
  status: status,
  triggerLabel: '성수에 도착하면',
  startsAt: startsAt,
  endsAt: endsAt,
);

final _danang = _plan(
  id: 'danang',
  title: '베트남 다낭',
  startsAt: DateTime(2026, 8, 16, 9),
  endsAt: DateTime(2026, 8, 20),
);
final _dinner = _plan(
  id: 'dinner',
  title: '성수 저녁 약속',
  startsAt: DateTime(2026, 8, 25, 19),
);
final _july = _plan(
  id: 'july',
  title: '제주 가족여행',
  startsAt: DateTime(2026, 7, 4, 10),
);
final _place = _plan(id: 'place', title: '성수 카페 들르기');
final _live = _plan(
  id: 'live',
  title: '아직 안 끝난 계획',
  status: PlanListStatus.upcoming,
  startsAt: DateTime(2026, 8, 18, 9),
);

Future<void> _pump(WidgetTester tester, List<PlanListItem> plans) async {
  tester.view.physicalSize = const Size(430, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: PastPlansScreen(plans: plans, today: DateTime(2026, 8, 21)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a run of days counts as covered from end to end', () {
    for (final day in <int>[16, 17, 20]) {
      expect(planCoversDay(_danang, DateTime(2026, 8, day)), isTrue);
    }
    expect(planCoversDay(_danang, DateTime(2026, 8, 15)), isFalse);
    expect(planCoversDay(_danang, DateTime(2026, 8, 21)), isFalse);
    // A single day covers itself and nothing either side of it.
    expect(planCoversDay(_dinner, DateTime(2026, 8, 25)), isTrue);
    expect(planCoversDay(_dinner, DateTime(2026, 8, 26)), isFalse);
    // A plan waiting on a place never had a day to be on.
    expect(planCoversDay(_place, DateTime(2026, 8, 25)), isFalse);
  });

  test('a month keeps what touches it, newest first', () {
    final plans = <PlanListItem>[_july, _danang, _dinner, _place];
    expect(
      pastPlansInMonth(plans, DateTime(2026, 8)).map((plan) => plan.id),
      <String>['dinner', 'danang'],
    );
    expect(
      pastPlansInMonth(plans, DateTime(2026, 7)).map((plan) => plan.id),
      <String>['july'],
    );
    expect(pastPlansInMonth(plans, DateTime(2026, 9)), isEmpty);
    expect(pastPlansOnDay(plans, DateTime(2026, 8, 18)).single.id, 'danang');
    expect(undatedPastPlans(plans).single.id, 'place');
  });

  testWidgets('the month is what the list shows until a day is picked', (
    tester,
  ) async {
    await _pump(tester, <PlanListItem>[_july, _danang, _dinner]);

    expect(find.text('2026년 8월'), findsOneWidget);
    expect(find.text('8월'), findsOneWidget);
    expect(find.text('2개'), findsOneWidget);
    expect(find.text('베트남 다낭'), findsOneWidget);
    expect(find.text('성수 저녁 약속'), findsOneWidget);
    // July's plan is a month away and stays there.
    expect(find.text('제주 가족여행'), findsNothing);

    // A day inside the trip narrows to it, and picking it again lets go.
    await tester.tap(find.byKey(const Key('past-day-18')));
    await tester.pumpAndSettle();
    expect(find.text('8월 18일'), findsOneWidget);
    expect(find.text('베트남 다낭'), findsOneWidget);
    expect(find.text('성수 저녁 약속'), findsNothing);

    await tester.tap(find.byKey(const Key('past-day-18')));
    await tester.pumpAndSettle();
    expect(find.text('성수 저녁 약속'), findsOneWidget);
  });

  testWidgets('a day with nothing on it says so rather than going blank', (
    tester,
  ) async {
    await _pump(tester, <PlanListItem>[_danang]);

    await tester.tap(find.byKey(const Key('past-day-3')));
    await tester.pumpAndSettle();
    expect(find.text('이 날에는 지나간 계획이 없어요.'), findsOneWidget);
  });

  testWidgets('moving month lets go of the day left behind', (tester) async {
    await _pump(tester, <PlanListItem>[_july, _danang]);

    await tester.tap(find.byKey(const Key('past-day-18')));
    await tester.pumpAndSettle();
    expect(find.text('8월 18일'), findsOneWidget);

    await tester.tap(find.byKey(const Key('past-prev-month')));
    await tester.pumpAndSettle();
    expect(find.text('2026년 7월'), findsOneWidget);
    expect(find.text('7월'), findsOneWidget);
    expect(find.text('제주 가족여행'), findsOneWidget);
  });

  testWidgets('a plan no square could hold still gets a place', (tester) async {
    await _pump(tester, <PlanListItem>[_danang, _place]);

    expect(find.text('날짜 없이 끝난 것'), findsOneWidget);
    expect(find.text('성수 카페 들르기'), findsOneWidget);

    // It is not one of the month's, so a picked day puts it away with the rest.
    await tester.tap(find.byKey(const Key('past-day-16')));
    await tester.pumpAndSettle();
    expect(find.text('성수 카페 들르기'), findsNothing);
  });

  testWidgets('only what is finished is here', (tester) async {
    await _pump(tester, <PlanListItem>[_live]);

    expect(find.text('아직 안 끝난 계획'), findsNothing);
    expect(find.text('아직 지나간 계획이 없어요.\n계획을 다 마치면 여기에 쌓여요.'), findsOneWidget);
  });
}
