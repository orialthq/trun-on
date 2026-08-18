import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/features/analysis/analysis_review_screen.dart';
import 'package:ori_beauty/features/common/capture_action_ui.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('uses the editorial light review surface at 150% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(InMemoryIncomingShareService());
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      _ScaledTestApp(
        child: AnalysisReviewScreen(
          controller: controller,
          captureId: 'capture-demo-daylight-review',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.planCanvas);
    expect(
      Theme.of(tester.element(find.text('이렇게 정리했어요'))).brightness,
      Brightness.light,
    );
    expect(find.byKey(const Key('content-folder-picker')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('content-subcategory-picker')), findsOneWidget);
    expect(find.byKey(const Key('delete-capture-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('content-subcategory-picker')));
    await tester.pumpAndSettle();
    final subcategoryField = find.byKey(const Key('subcategory-name-field'));
    final sheetSafeArea = tester.widget<SafeArea>(
      find
          .ancestor(of: subcategoryField, matching: find.byType(SafeArea))
          .first,
    );
    expect(sheetSafeArea.maintainBottomViewPadding, isTrue);
    expect(sheetSafeArea.minimum.bottom, AppTheme.bottomSheetSafeInset);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(subcategoryField)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-capture-detail')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, AppTheme.planSurface);
    expect(find.text('이 콘텐츠를 삭제할까요?'), findsOneWidget);
    expect(find.byKey(const Key('confirm-capture-delete')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });

  testWidgets('keeps capture actions accessible and functional at 150%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CaptureListAction? selectedAction;
    await tester.pumpWidget(
      _ScaledTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  selectedAction = await showCaptureActionSheet(
                    context,
                    canOrganize: true,
                  );
                },
                child: const Text('액션 열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('액션 열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capture-action-safe-area')), findsOneWidget);
    expect(find.byKey(const Key('capture-action-organize')), findsOneWidget);
    expect(find.byKey(const Key('capture-action-delete')), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('정리함에 저장'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('capture-action-organize')));
    await tester.pumpAndSettle();
    expect(selectedAction, CaptureListAction.organize);
  });
}

final class _ScaledTestApp extends StatelessWidget {
  const _ScaledTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        );
      },
      home: child,
    );
  }
}
