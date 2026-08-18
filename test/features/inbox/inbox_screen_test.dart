import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/features/inbox/inbox_screen.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('uses the plan canvas and remains usable with large text', (
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
        home: Scaffold(body: InboxScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const PageStorageKey('content-inbox')), findsOneWidget);
    expect(find.byKey(const Key('inbox-add-button')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const PageStorageKey('content-inbox')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == AppTheme.planCanvas,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('inbox-add-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual-input-safe-area')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final needsReview = find.text('확인 필요 ${controller.needsReviewCount}');
    await tester.ensureVisible(needsReview);
    await tester.tap(needsReview);
    await tester.pumpAndSettle();

    expect(controller.filter, CaptureFilter.needsReview);
    expect(tester.takeException(), isNull);
  });
}
