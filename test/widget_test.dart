import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/app/ori_beauty_app.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/features/product/product_detail_screen.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('renders the Trun On home and organized library navigation', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Trun On');
    expect(find.text('TRUN ON'), findsOneWidget);
    expect(find.text('1개만 확인하면 끝'), findsOneWidget);
    expect(find.textContaining('TODAY'), findsNothing);
    expect(find.textContaining('READY TO SAVE'), findsNothing);
    expect(find.textContaining('오늘 들어온 걸'), findsNothing);
    expect(find.text('CAPTURE INBOX'), findsNothing);
    expect(find.text('들어온 내용을 확인하고 정리해요'), findsNothing);
    expect(find.text('발견만으로는 달라지지 않으니까.'), findsNothing);
    expect(find.text('정리된 내용을 확인하고 폴더에 넣어 두세요.'), findsNothing);
    expect(find.text('정리된 내용을 확인하고 저장해 주세요.'), findsNothing);
    expect(
      find.byKey(const PageStorageKey('home-category-roulette')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-inbox-card')), findsOneWidget);
    expect(find.byKey(const Key('home-library-card')), findsOneWidget);
    expect(find.text('콘텐츠'), findsOneWidget);
    expect(find.text('INPUT → 정리'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    expect(find.text('비교'), findsNothing);
    expect(find.text('내 기준'), findsNothing);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('정리함'), findsWidgets);
    expect(find.text('A R C H I V E'), findsNothing);
    expect(find.byKey(const Key('folder-roulette')), findsOneWidget);
    expect(find.byKey(const Key('library-search-field')), findsNothing);

    final recentItem = find.text('카밍 앰플').last;
    await tester.ensureVisible(recentItem);
    await tester.pumpAndSettle();
    await tester.tap(recentItem);
    await tester.pumpAndSettle();

    expect(find.text('콘텐츠에서 나온 이야기'), findsOneWidget);
    expect(find.byKey(const Key('content-subcategory-picker')), findsOneWidget);
    expect(find.textContaining('사용자 확인 완료'), findsNothing);
    expect(find.textContaining('베이스라인'), findsNothing);
  });

  testWidgets('collapses and expands long saved source text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailScreen(
          controller: controller,
          groupId: 'group-baumlab-pore-balance',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sourceToggle = find.byKey(
      const ValueKey('source-toggle-capture-demo-baum-1'),
    );
    await tester.scrollUntilVisible(
      sourceToggle,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    final rawSource = find.byKey(
      const ValueKey('source-raw-capture-demo-baum-1'),
    );
    final collapsedText = tester.widget<Text>(rawSource);
    expect(collapsedText.maxLines, 3);
    expect(collapsedText.overflow, TextOverflow.ellipsis);

    await tester.tap(sourceToggle);
    await tester.pumpAndSettle();

    expect(tester.widget(rawSource), isA<SelectableText>());
    expect(find.text('접기'), findsWidgets);
  });

  testWidgets('filters the organized library by folder', (tester) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();
    final beautySubcategory = controller.subcategoryForGroup(
      'group-baumlab-pore-balance',
    );

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).last);
    await tester.pumpAndSettle();
    final archive = find.byKey(const PageStorageKey<String>('products'));
    final archiveScroll = find
        .descendant(of: archive, matching: find.byType(Scrollable))
        .first;

    expect(find.byKey(const Key('folder-beauty')), findsOneWidget);
    expect(find.byKey(const Key('folder-healthFitness')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('folder-healthFitness')),
      220,
      scrollable: archiveScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-healthFitness')));
    await tester.pumpAndSettle();

    expect(find.text('건강·운동 폴더가 비어 있어요'), findsOneWidget);
    expect(find.text('포어 밸런스 세럼'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('folder-beauty')),
      -220,
      scrollable: archiveScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-beauty')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('subcategory-$beautySubcategory')), findsOneWidget);
    await tester.tap(find.byKey(Key('subcategory-$beautySubcategory')));
    await tester.pumpAndSettle();
    expect(find.text('세부 분류'), findsOneWidget);
    expect(find.text('하위 분류'), findsOneWidget);
    expect(find.text('포어 밸런스 세럼'), findsOneWidget);
  });

  testWidgets('keeps the archive focused on the folder roulette', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('folder-roulette')), findsOneWidget);
    expect(find.byKey(const Key('top-folder-wheel')), findsOneWidget);
    expect(find.byKey(const Key('library-search-field')), findsNothing);
    expect(find.textContaining('CROSS'), findsNothing);
    expect(find.text('B E A U T Y'), findsNothing);
  });

  testWidgets('content filters use distinct selected colors', (tester) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.inbox_outlined).last);
    await tester.pumpAndSettle();

    final cases = <(String, Color)>[
      ('전체 ${controller.captures.length}', AppTheme.primary),
      ('확인 필요 ${controller.needsReviewCount}', AppTheme.caution),
      ('정리 완료 ${controller.organizedCount}', AppTheme.positive),
      ('내용 부족 ${controller.limitedOrFailedCount}', AppTheme.negative),
    ];
    for (final (label, color) in cases) {
      final filter = find.text(label);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(filter).style?.color, color);
    }
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

    await tester.tap(find.byIcon(Icons.inbox_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('데이라이트 에어리 선 플루이드'));
    await tester.pumpAndSettle();

    expect(find.text('이렇게 정리했어요'), findsOneWidget);
    expect(find.text('저장하기 전에 잘못 읽힌 부분만 확인해 주세요.'), findsOneWidget);
    expect(find.textContaining('정규화된 URL'), findsNothing);
    expect(find.textContaining('신뢰도'), findsNothing);

    final subcategoryPicker = find.byKey(
      const Key('content-subcategory-picker'),
    );
    await tester.scrollUntilVisible(
      subcategoryPicker,
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(subcategoryPicker, findsOneWidget);
    await tester.tap(subcategoryPicker);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('subcategory-name-field')),
      '선케어',
    );
    await tester.tap(find.byKey(const Key('save-subcategory-button')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final amountField = find
        .byKey(const ValueKey('analysis-field-용량·규격'))
        .first;
    await tester.enterText(amountField, '50mL');
    final organizeButton = find.widgetWithText(FilledButton, '정리함에 저장');
    await tester.ensureVisible(organizeButton);
    await tester.pumpAndSettle();
    await tester.tap(organizeButton);
    await tester.pumpAndSettle();

    expect(
      controller.captureById('capture-demo-daylight-review')?.status,
      CaptureStatus.organized,
    );
    expect(
      controller
          .captureById('capture-demo-daylight-review')
          ?.contentSubcategory,
      '선케어',
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
    expect(await service.drainPending(), isEmpty);
  });

  testWidgets('URL-only share explains that a screenshot is needed', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService()
      ..add(
        IncomingShare(
          id: 'share-link-only',
          receivedAt: DateTime(2026, 8, 1),
          sharedText: 'https://www.instagram.com/reel/example/',
          discoveredUrl: 'https://www.instagram.com/reel/example/',
        ),
      );
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    expect(find.text('링크를 저장했어요'), findsWidgets);
    expect(find.textContaining('게시물 내용은 전달되지 않았어요'), findsWidgets);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('링크를 저장했어요').first);
    await tester.pumpAndSettle();

    expect(find.text('링크는 저장했어요'), findsOneWidget);
    expect(find.text('스크린샷으로 이어서 저장하기'), findsOneWidget);
    expect(find.textContaining('캡처 미리보기의 공유 버튼'), findsOneWidget);
  });

  testWidgets('incoming screenshot returns to the content tab', (tester) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('정리함'), findsWidgets);

    service.add(
      IncomingShare(
        id: 'share-screenshot-open',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: '방금 연 스크린샷',
        discoveredUrl: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('콘텐츠'), findsWidgets);
    expect(find.text('방금 연 스크린샷'), findsNothing);
    final compactSummary = find.text('저장한 내용의 세부 정보를 확인해 주세요.');
    expect(compactSummary, findsOneWidget);
    expect(tester.widget<Text>(compactSummary).maxLines, 2);
    expect(find.text('정리가 준비됐어요'), findsOneWidget);
    expect(find.text('탭해서 내용을 확인해 주세요'), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('정리가 준비됐어요'), findsNothing);
  });

  testWidgets('gallery source choice clears the Android system inset', (
    tester,
  ) async {
    final service = InMemoryIncomingShareService()
      ..add(
        IncomingShare(
          id: 'share-with-source-choice',
          receivedAt: DateTime(2026, 8, 5),
          sharedText: '갤러리 원본 선택 테스트',
          discoveredUrl: null,
          sourceDeletionAvailable: true,
        ),
      );
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();

    final deleteAction = find.widgetWithText(TextButton, '갤러리 원본 삭제');
    expect(deleteAction, findsOneWidget);
    final safeArea = tester.widget<SafeArea>(
      find.ancestor(of: deleteAction, matching: find.byType(SafeArea)).first,
    );
    expect(safeArea.bottom, isTrue);
    expect(safeArea.maintainBottomViewPadding, isTrue);
    expect(
      find.ancestor(
        of: deleteAction,
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, '갤러리에 두기'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Android back returns to home before arming app exit',
    (tester) async {
      final service = InMemoryIncomingShareService();
      final controller = AppController(service);
      addTearDown(controller.dispose);

      await tester.pumpWidget(OriBeautyApp(controller: controller));
      await controller.initialize();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('정리함'), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('TRUN ON'), findsOneWidget);
      expect(find.text('한 번 더 누르면 앱을 종료해요.'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('한 번 더 누르면 앱을 종료해요.'), findsOneWidget);
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isTrue,
      );

      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isFalse,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android share flow returns to the source app from home',
    (tester) async {
      const navigationChannel = MethodChannel(
        'com.orialthq.ori_beauty/app_navigation/v1',
      );
      var returnRequested = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(navigationChannel, (call) async {
            if (call.method == 'returnToPreviousApp') {
              returnRequested = true;
              return true;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(navigationChannel, null),
      );

      final service = InMemoryIncomingShareService();
      final controller = AppController(service);
      addTearDown(controller.dispose);

      await tester.pumpWidget(OriBeautyApp(controller: controller));
      await controller.initialize();
      await tester.pumpAndSettle();

      service.add(
        IncomingShare(
          id: 'share-return-to-source',
          receivedAt: DateTime(2026, 8, 5),
          sharedText: '인스타그램에서 보낸 캡처',
          discoveredUrl: null,
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('TRUN ON'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(returnRequested, isTrue);
      expect(find.text('한 번 더 누르면 앱을 종료해요.'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('core screens remain usable at 150 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.inbox_outlined).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
