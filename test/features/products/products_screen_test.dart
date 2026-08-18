import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/features/products/products_screen.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('uses an ivory flat folder list and keeps folder selection', (
    tester,
  ) async {
    final controller = AppController(InMemoryIncomingShareService());
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: ProductsScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('저장한 내용을 폴더별로 차분히 모아 봐요.'), findsOneWidget);
    expect(find.byKey(const Key('folder-roulette')), findsOneWidget);
    expect(find.byKey(const Key('top-folder-wheel')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('folder-roulette')),
        matching: find.byType(ListWheelScrollView),
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == AppTheme.planCanvas,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('folder-healthFitness')));
    await tester.pumpAndSettle();

    expect(find.text('건강·운동 폴더가 비어 있어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flat archive remains usable at 150 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final controller = AppController(InMemoryIncomingShareService());
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: ProductsScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const PageStorageKey('products')), findsOneWidget);
    expect(find.byKey(const Key('folder-lifeTip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
