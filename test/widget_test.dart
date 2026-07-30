import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/app/ori_beauty_app.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('renders the decision inbox and comparison flow', (tester) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    expect(find.text('수집함'), findsWidgets);
    expect(find.text('포어 밸런스 세럼'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.compare_arrows_outlined));
    await tester.pumpAndSettle();

    expect(find.text('하나만 남긴다면 리프온'), findsOneWidget);
  });

  testWidgets('opens a product and records a decision', (tester) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    await tester.tap(find.text('포어 밸런스 세럼'));
    await tester.pumpAndSettle();

    expect(find.text('내 결정: 보류'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '제외'));
    await tester.pump();

    expect(
      controller.productById('baumlab-pore-balance')?.decision,
      Decision.excluded,
    );
  });

  testWidgets('reviews an incoming Android share before importing it', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    service.add(
      IncomingShare(
        id: 'share-1',
        receivedAt: DateTime(2026, 7, 30),
        sharedText: '추천 선케어 https://example.com/reel',
        discoveredUrl: 'https://example.com/reel',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 제품이 맞나요?'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);

    final confirmButton = find.widgetWithText(FilledButton, '이 제품이 맞아요');
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.text('수집함'), findsWidgets);
    expect(
      controller.productById('daylight-sun-fluid')?.analysisStatus,
      AnalysisStatus.ready,
    );
  });
}
