import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/features/home/trun_home_screen.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('category roulette keeps flat cards with quiet center emphasis', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = AppController(InMemoryIncomingShareService());
    var libraryOpened = false;
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: TrunHomeScreen(
          controller: controller,
          onAdd: () {},
          onOpenInbox: () {},
          onOpenLibrary: () => libraryOpened = true,
          onOpenCapture: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final centerTransform = tester.widget<Transform>(
      find.byKey(const Key('home-category-transform-beauty')),
    );
    final sideTransform = tester.widget<Transform>(
      find.byKey(const Key('home-category-transform-healthFitness')),
    );
    final centerOpacity = tester.widget<Opacity>(
      find.byKey(const Key('home-category-opacity-beauty')),
    );
    final sideOpacity = tester.widget<Opacity>(
      find.byKey(const Key('home-category-opacity-healthFitness')),
    );

    expect(centerTransform.transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(
      sideTransform.transform.getMaxScaleOnAxis(),
      lessThan(centerTransform.transform.getMaxScaleOnAxis()),
    );
    expect(
      sideTransform.transform.entry(1, 3),
      greaterThan(centerTransform.transform.entry(1, 3)),
    );
    expect(sideTransform.transform.entry(2, 3), closeTo(0, 0.001));
    expect(sideTransform.transform.entry(0, 2), closeTo(0, 0.001));
    expect(centerOpacity.opacity, 1);
    expect(sideOpacity.opacity, lessThan(centerOpacity.opacity));
    final centerMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const Key('home-category-beauty')),
        matching: find.byType(Material),
      ),
    );
    final sideMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const Key('home-category-healthFitness')),
        matching: find.byType(Material),
      ),
    );
    expect(centerMaterial.elevation, 0);
    expect(sideMaterial.elevation, 0);
    final centerSemantics = tester.getSemantics(
      find.byKey(const Key('home-category-beauty')),
    );
    expect(centerSemantics.label, contains('뷰티'));
    expect(centerSemantics.label, contains('정리함에서 보기'));

    await tester.tap(find.byKey(const Key('home-category-beauty')));
    expect(libraryOpened, isTrue);
    semantics.dispose();
  });

  testWidgets('home layout stays usable at 150 percent text scale', (
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
        home: TrunHomeScreen(
          controller: controller,
          onAdd: () {},
          onOpenInbox: () {},
          onOpenLibrary: () {},
          onOpenCapture: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
