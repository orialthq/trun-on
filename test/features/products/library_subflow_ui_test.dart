import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/features/product/product_detail_screen.dart';
import 'package:ori_beauty/features/products/subcategory_deck_screen.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  void useLargeTextPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets(
    'product detail stays light and usable at 150 percent text scale',
    (tester) async {
      useLargeTextPhone(tester);
      final controller = AppController(InMemoryIncomingShareService());
      addTearDown(controller.dispose);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ProductDetailScreen(
            controller: controller,
            groupId: 'group-baumlab-pore-balance',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('제품별 정리'), findsOneWidget);
      expect(
        find.byKey(const Key('content-subcategory-picker')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Theme &&
              widget.data.scaffoldBackgroundColor == AppTheme.planCanvas,
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('content-subcategory-picker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('subcategory-name-field')), findsOneWidget);
      expect(find.byKey(const Key('save-subcategory-button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(
        tester.element(find.byKey(const Key('subcategory-name-field'))),
      ).pop();
      await tester.pumpAndSettle();

      final sourceToggle = find.byKey(
        const ValueKey('source-toggle-capture-demo-baum-1'),
      );
      await tester.scrollUntilVisible(
        sourceToggle,
        320,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(sourceToggle);
      await tester.pumpAndSettle();

      expect(
        tester.widget(
          find.byKey(const ValueKey('source-raw-capture-demo-baum-1')),
        ),
        isA<SelectableText>(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subcategory list stays flat and usable at 150 percent text scale',
    (tester) async {
      useLargeTextPhone(tester);
      final controller = AppController(InMemoryIncomingShareService());
      addTearDown(controller.dispose);
      await controller.initialize();
      final subcategory = controller.subcategoryForGroup(
        'group-baumlab-pore-balance',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: SubcategoryDeckScreen(
            controller: controller,
            folder: ContentFolder.beauty,
            initialSubcategory: subcategory,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('하위 분류'), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('subcategory-deck-beauty')),
        findsOneWidget,
      );
      expect(find.byKey(Key('subcategory-$subcategory')), findsOneWidget);
      for (final axis in ContentAxis.values) {
        expect(find.byKey(Key('axis-chip-${axis.name}')), findsOneWidget);
      }
      expect(
        tester
            .widgetList<Material>(find.byType(Material))
            .every((material) => material.elevation == 0),
        isTrue,
      );
      expect(tester.takeException(), isNull);

      final locationAxis = find.byKey(const Key('axis-chip-location'));
      await tester.ensureVisible(locationAxis);
      await tester.tap(locationAxis);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('subcategory-분류 필요')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
