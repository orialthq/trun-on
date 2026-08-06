import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/features/home/trun_home_screen.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('category roulette keeps the center card ahead of a side card', (
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
    expect(
      sideTransform.transform.entry(2, 3),
      greaterThan(centerTransform.transform.entry(2, 3)),
    );
    expect(sideTransform.transform.entry(0, 2).abs(), greaterThan(0.01));
    expect(centerOpacity.opacity, 1);
    expect(sideOpacity.opacity, lessThan(centerOpacity.opacity));
    final centerSemantics = tester.getSemantics(
      find.byKey(const Key('home-category-beauty')),
    );
    expect(centerSemantics.label, contains('뷰티'));
    expect(centerSemantics.label, contains('정리함에서 보기'));

    await tester.tap(find.byKey(const Key('home-category-beauty')));
    expect(libraryOpened, isTrue);
    semantics.dispose();
  });
}
