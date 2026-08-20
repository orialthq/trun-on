import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/features/plans/plan_editor_screen.dart';

const _sources = <PlanSourceOption>[
  PlanSourceOption(
    captureId: 'c1',
    title: '에어리 선 플루이드',
    folder: ContentFolder.beauty,
    subcategory: '스킨케어',
  ),
  PlanSourceOption(
    captureId: 'c2',
    title: '리쥬란 후기',
    folder: ContentFolder.beauty,
    subcategory: '스킨케어',
  ),
  PlanSourceOption(
    captureId: 'c3',
    title: '향수 레이어링',
    folder: ContentFolder.beauty,
    subcategory: '향수',
  ),
  PlanSourceOption(
    captureId: 'c4',
    title: '화육계 을지로',
    folder: ContentFolder.restaurantCafe,
    subcategory: '한식',
  ),
];

Widget _editor({PlanDraft? initialDraft, ValueChanged<PlanDraft>? onSave}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: PlanEditorScreen(
      sources: _sources,
      initialDraft:
          initialDraft ??
          PlanDraft(
            title: '올리브영 가기',
            triggerKind: PlanDraftTriggerKind.time,
            recurrence: PlanDraftRecurrence.once,
            scheduledAt: DateTime(2027, 8, 21, 19, 30),
          ),
      onSave: onSave,
      popOnSave: false,
    ),
  );
}

void main() {
  group('PlanContentScope', () {
    test('a folder with no child named covers everything inside it', () {
      const scope = PlanContentScope(folder: ContentFolder.beauty);
      expect(scope.matches(ContentFolder.beauty, '스킨케어'), isTrue);
      expect(scope.matches(ContentFolder.beauty, '향수'), isTrue);
      expect(scope.matches(ContentFolder.restaurantCafe, '한식'), isFalse);
    });

    test('naming a child narrows to it alone', () {
      const scope = PlanContentScope(
        folder: ContentFolder.beauty,
        subcategory: '스킨케어',
      );
      expect(scope.matches(ContentFolder.beauty, '스킨케어'), isTrue);
      expect(scope.matches(ContentFolder.beauty, '향수'), isFalse);
    });

    test('survives the trip through a plan\'s metadata', () {
      const scope = PlanContentScope(
        folder: ContentFolder.travelPlace,
        subcategory: '숙소',
      );
      expect(PlanContentScope.fromJson(scope.toJson()), scope);
      // A whole folder round-trips as a whole folder, not as an empty child.
      const whole = PlanContentScope(folder: ContentFolder.shopping);
      expect(PlanContentScope.fromJson(whole.toJson()), whole);
      expect(PlanContentScope.fromJson(<String, Object?>{}), isNull);
    });

    test('an empty list is everywhere, not nowhere', () {
      expect(
        planScopesMatch(const <PlanContentScope>[], ContentFolder.recipe, '한식'),
        isTrue,
      );
    });

    test('any one of several is enough', () {
      const scopes = <PlanContentScope>[
        PlanContentScope(folder: ContentFolder.beauty, subcategory: '향수'),
        PlanContentScope(folder: ContentFolder.restaurantCafe),
      ];
      expect(planScopesMatch(scopes, ContentFolder.beauty, '향수'), isTrue);
      expect(planScopesMatch(scopes, ContentFolder.beauty, '스킨케어'), isFalse);
      expect(
        planScopesMatch(scopes, ContentFolder.restaurantCafe, '한식'),
        isTrue,
      );
      expect(planScopesMatch(scopes, ContentFolder.shopping, '가전'), isFalse);
    });

    test('adding a scope drops the ones it makes redundant', () {
      const skincare = PlanContentScope(
        folder: ContentFolder.beauty,
        subcategory: '스킨케어',
      );
      const perfume = PlanContentScope(
        folder: ContentFolder.beauty,
        subcategory: '향수',
      );
      const wholeBeauty = PlanContentScope(folder: ContentFolder.beauty);
      const restaurant = PlanContentScope(folder: ContentFolder.restaurantCafe);

      // Children of different folders coexist.
      expect(planScopesWith(const <PlanContentScope>[skincare], restaurant), [
        skincare,
        restaurant,
      ]);
      // Children of the same folder coexist.
      expect(planScopesWith(const <PlanContentScope>[skincare], perfume), [
        skincare,
        perfume,
      ]);
      // The parent swallows its children, and leaves other folders alone.
      expect(
        planScopesWith(const <PlanContentScope>[
          skincare,
          perfume,
          restaurant,
        ], wholeBeauty),
        [restaurant, wholeBeauty],
      );
      // A child replaces the parent it sat under.
      expect(planScopesWith(const <PlanContentScope>[wholeBeauty], skincare), [
        skincare,
      ]);
    });
  });

  testWidgets('picking a parent, then a child, narrows what will be searched', (
    tester,
  ) async {
    // Tall enough that the whole form builds: the editor grew a notification
    // row, and a lazily-built list does not create what it cannot show.
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PlanDraft? saved;
    await tester.pumpWidget(_editor(onSave: (draft) => saved = draft));

    // Nothing chosen searches the whole library.
    expect(find.text('어디서든'), findsOneWidget);
    expect(find.text('저장한 것 4개'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();

    // Only folders that hold something are offered.
    expect(find.byKey(const Key('plan-scope-folder-beauty')), findsOneWidget);
    expect(
      find.byKey(const Key('plan-scope-folder-restaurantCafe')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('plan-scope-folder-recipe')), findsNothing);

    // Tapping a parent looks inside rather than committing to it.
    await tester.tap(find.byKey(const Key('plan-scope-folder-beauty')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-scope-whole-beauty')), findsOneWidget);
    expect(find.byKey(const Key('plan-scope-sub-스킨케어')), findsOneWidget);
    expect(find.byKey(const Key('plan-scope-sub-향수')), findsOneWidget);
    // 한식 lives in another folder and must not leak in here.
    expect(find.byKey(const Key('plan-scope-sub-한식')), findsNothing);

    await tester.tap(find.byKey(const Key('plan-scope-sub-스킨케어')));
    await tester.pumpAndSettle();

    // Picking no longer closes the sheet — more can be picked.
    expect(find.byKey(const Key('plan-scope-done')), findsOneWidget);
    expect(find.text('1곳에서 찾기 · 2개'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-scope-done')));
    await tester.pumpAndSettle();

    expect(find.text('뷰티 · 스킨케어'), findsOneWidget);
    expect(find.text('저장한 것 2개'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plan-editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-editor-save')));
    await tester.pump();

    expect(saved?.scopes, const <PlanContentScope>[
      PlanContentScope(folder: ContentFolder.beauty, subcategory: '스킨케어'),
    ]);
  });

  testWidgets('several places can be picked, across folders', (tester) async {
    // Tall enough that the whole form builds: the editor grew a notification
    // row, and a lazily-built list does not create what it cannot show.
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PlanDraft? saved;
    await tester.pumpWidget(_editor(onSave: (draft) => saved = draft));

    await tester.ensureVisible(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plan-scope-folder-beauty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-sub-향수')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-back')));
    await tester.pumpAndSettle();

    // The parent row reports what is on inside it without being opened.
    expect(find.text('향수 선택됨'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-scope-folder-restaurantCafe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-whole-restaurantCafe')));
    await tester.pumpAndSettle();

    expect(find.text('2곳에서 찾기 · 2개'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-scope-done')));
    await tester.pumpAndSettle();

    expect(find.text('뷰티 · 향수 외 1곳'), findsOneWidget);
    expect(find.text('저장한 것 2개'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plan-editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-editor-save')));
    await tester.pump();

    expect(saved?.scopes, const <PlanContentScope>[
      PlanContentScope(folder: ContentFolder.beauty, subcategory: '향수'),
      PlanContentScope(folder: ContentFolder.restaurantCafe),
    ]);
  });

  testWidgets('picking a parent swallows the children already picked', (
    tester,
  ) async {
    // Tall enough that the whole form builds: the editor grew a notification
    // row, and a lazily-built list does not create what it cannot show.
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PlanDraft? saved;
    await tester.pumpWidget(_editor(onSave: (draft) => saved = draft));

    await tester.ensureVisible(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-folder-beauty')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plan-scope-sub-스킨케어')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-sub-향수')));
    await tester.pumpAndSettle();
    expect(find.text('2곳에서 찾기 · 3개'), findsOneWidget);

    // The whole folder covers both, so both go.
    await tester.tap(find.byKey(const Key('plan-scope-whole-beauty')));
    await tester.pumpAndSettle();
    expect(find.text('1곳에서 찾기 · 3개'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-scope-done')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('plan-editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-editor-save')));
    await tester.pump();

    expect(saved?.scopes, const <PlanContentScope>[
      PlanContentScope(folder: ContentFolder.beauty),
    ]);
  });

  testWidgets('choosing everywhere clears what was picked', (tester) async {
    // Tall enough that the whole form builds: the editor grew a notification
    // row, and a lazily-built list does not create what it cannot show.
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PlanDraft? saved;
    await tester.pumpWidget(_editor(onSave: (draft) => saved = draft));

    await tester.ensureVisible(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-folder-beauty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-whole-beauty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-back')));
    await tester.pumpAndSettle();

    // "Everywhere" is the absence of a fence, not another one beside it.
    await tester.tap(find.byKey(const Key('plan-scope-all')));
    await tester.pumpAndSettle();
    expect(find.text('어디서든 찾기 · 4개'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-scope-done')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('plan-editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-editor-save')));
    await tester.pump();

    expect(saved?.scopes, isEmpty);
  });

  testWidgets('the whole folder is a choice of its own', (tester) async {
    // Tall enough that the whole form builds: the editor grew a notification
    // row, and a lazily-built list does not create what it cannot show.
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PlanDraft? saved;
    await tester.pumpWidget(_editor(onSave: (draft) => saved = draft));

    await tester.ensureVisible(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-folder-beauty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-whole-beauty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-scope-done')));
    await tester.pumpAndSettle();

    expect(find.text('뷰티'), findsOneWidget);
    expect(find.text('저장한 것 3개'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plan-editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-editor-save')));
    await tester.pump();

    expect(saved?.scopes, const <PlanContentScope>[
      PlanContentScope(folder: ContentFolder.beauty),
    ]);
  });

  testWidgets('a scope whose folder has been emptied is dropped', (
    tester,
  ) async {
    // Tall enough that the whole form builds: the editor grew a notification
    // row, and a lazily-built list does not create what it cannot show.
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _editor(
        initialDraft: PlanDraft(
          title: '레시피 해보기',
          triggerKind: PlanDraftTriggerKind.time,
          recurrence: PlanDraftRecurrence.once,
          scheduledAt: DateTime(2027, 8, 21),
          // Nothing in the library is filed under 레시피.
          scopes: const <PlanContentScope>[
            PlanContentScope(folder: ContentFolder.recipe),
          ],
        ),
      ),
    );

    // Falls back rather than promising a search over nothing.
    expect(find.text('어디서든'), findsOneWidget);
    expect(find.text('저장한 것 4개'), findsOneWidget);
  });
}
