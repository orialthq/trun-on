import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/features/plans/plans_screen.dart';

void main() {
  testWidgets('groups active, upcoming, and completed plans', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var createPressed = false;
    PlanListItem? opened;
    const plans = [
      PlanListItem(
        id: 'active',
        title: '퇴근길에 장보기',
        status: PlanListStatus.active,
        triggerLabel: '회사에서 나갈 때',
        recurrenceLabel: '장소를 다시 방문할 때',
      ),
      PlanListItem(
        id: 'upcoming',
        title: '저장한 식당 예약하기',
        status: PlanListStatus.upcoming,
        triggerLabel: '8월 21일 오후 7:00',
        sourceLabel: '성수 맛집 캡처',
      ),
      PlanListItem(
        id: 'completed',
        title: '선크림 다시 사기',
        status: PlanListStatus.completed,
        triggerLabel: '8월 10일 완료',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PlansScreen(
            plans: plans,
            onCreatePlan: () => createPressed = true,
            onOpenPlan: (plan) => opened = plan,
          ),
        ),
      ),
    );

    expect(find.text('계획함'), findsOneWidget);
    expect(find.text('활성 계획'), findsOneWidget);
    expect(find.text('예정된 계획'), findsOneWidget);
    expect(find.text('완료한 계획'), findsOneWidget);
    expect(find.byKey(const Key('plan-card-active')), findsOneWidget);
    expect(find.byKey(const Key('plan-card-upcoming')), findsOneWidget);
    expect(find.byKey(const Key('plan-card-completed')), findsOneWidget);
    expect(find.text('활성 1개 · 예정 1개'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plans-create-button')));
    expect(createPressed, isTrue);

    await tester.tap(find.byKey(const Key('plan-card-active')));
    expect(opened?.id, 'active');
  });

  testWidgets('shows useful empty states without requiring a controller', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PlansScreen(plans: const [], onCreatePlan: () {}),
        ),
      ),
    );

    expect(find.text('첫 계획을 만들어 보세요'), findsOneWidget);
    expect(find.text('지금 조건을 기다리는 계획이 없어요.'), findsOneWidget);
    expect(find.text('다가오는 계획이 없어요.'), findsOneWidget);
    expect(find.text('완료한 계획이 여기에 쌓여요.'), findsOneWidget);
  });
}
