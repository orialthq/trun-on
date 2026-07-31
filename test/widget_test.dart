import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/app/ori_beauty_app.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('renders only content and organized product navigation', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    expect(find.text('콘텐츠'), findsWidgets);
    expect(find.text('확인할 콘텐츠가 1개 있어요'), findsOneWidget);
    expect(find.text('INPUT → 정리'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    expect(find.text('비교'), findsNothing);
    expect(find.text('내 기준'), findsNothing);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('제품별 정리'), findsOneWidget);
    expect(find.text('포어 밸런스 세럼'), findsOneWidget);

    await tester.tap(find.text('포어 밸런스 세럼'));
    await tester.pumpAndSettle();

    expect(find.text('콘텐츠에서 나온 이야기'), findsOneWidget);
    expect(find.textContaining('사용자 확인 완료'), findsNothing);
    expect(find.textContaining('베이스라인'), findsNothing);
  });

  testWidgets('reviews extracted fields and organizes a capture', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    await tester.tap(find.text('데이라이트 에어리 선 플루이드'));
    await tester.pumpAndSettle();

    expect(find.text('제품 정보를 확인해 주세요'), findsOneWidget);
    expect(find.text('잘못된 부분만 고치면 돼요.'), findsOneWidget);
    expect(find.textContaining('정규화된 URL'), findsNothing);
    expect(find.textContaining('신뢰도'), findsNothing);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final amountField = find
        .byKey(const ValueKey('analysis-field-용량·규격'))
        .first;
    await tester.enterText(amountField, '50mL');
    final organizeButton = find.widgetWithText(FilledButton, '이 제품으로 정리하기');
    await tester.ensureVisible(organizeButton);
    await tester.pumpAndSettle();
    await tester.tap(organizeButton);
    await tester.pumpAndSettle();

    expect(
      controller.captureById('capture-demo-daylight-review')?.status,
      CaptureStatus.organized,
    );
    expect(find.text('콘텐츠'), findsWidgets);
  });

  testWidgets('incoming Android share is preserved in content list', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);
    service.add(
      IncomingShare(
        id: 'share-android',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: '리프온 카밍 앰플 40ml가 촉촉하다고 했어요.',
        discoveredUrl: null,
      ),
    );

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    expect(find.text('리프온 카밍 앰플 40ml가 촉촉하다고 했어요.'), findsOneWidget);
    final capture = controller.captures.firstWhere(
      (item) => item.raw.transportEventId == 'share-android',
    );
    expect(capture.status, CaptureStatus.needsReview);
    expect(await service.drainPending(), isNotEmpty);
  });
}
