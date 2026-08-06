import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/core/app_theme.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/features/sharing/share_tip_screen.dart';

void main() {
  testWidgets('gift card stays within its 4:5 frame at the selection limit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ShareTipScreen(capture: _denseCapture()),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      '이번 주말에 다 같이 가보고 각자 먹고 싶은 메뉴도 하나씩 골라보자!',
    );

    expect(find.byType(Checkbox), findsNWidgets(8));
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -900));
    await tester.pumpAndSettle();
    for (final label in ['대기', '추천']) {
      final choice = find.text(label);
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }

    await tester.fling(list, const Offset(0, 2000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('친구에게 건넬 카드'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

CaptureRecord _denseCapture() {
  const facts = [
    AnalysisFact(
      label: '대표 메뉴',
      value: '철판쭈꾸미와 볶음밥',
      confidence: 1,
      evidenceIds: [],
    ),
    AnalysisFact(
      label: '영업시간',
      value: '매일 11:00~22:00',
      confidence: 1,
      evidenceIds: [],
    ),
    AnalysisFact(
      label: '가격',
      value: '1인분 15,000원',
      confidence: 1,
      evidenceIds: [],
    ),
    AnalysisFact(
      label: '대기',
      value: '주말에는 예약 권장',
      confidence: 1,
      evidenceIds: [],
    ),
    AnalysisFact(
      label: '추천',
      value: '마지막 볶음밥 필수',
      confidence: 1,
      evidenceIds: [],
    ),
    AnalysisFact(
      label: '주차',
      value: '인근 공영주차장 이용',
      confidence: 1,
      evidenceIds: [],
    ),
  ];
  const structured = StructuredContentAnalysis(
    schemaVersion: '1.2',
    model: 'gpt-5.6-luna',
    domain: ContentDomain.food,
    contentKind: ContentKind.place,
    primaryCategory: ContentFolder.restaurantCafe,
    categoryConfidence: 1,
    subcategory: '한식',
    subcategoryConfidence: 1,
    completeness: StructuredCompleteness.complete,
    title: StructuredTitle(
      value: '친구들과 꼭 같이 가보고 싶은 종로 철판쭈꾸미 맛집',
      status: ObservedStatus.observed,
      confidence: 1,
      evidenceIds: [],
    ),
    place: StructuredPlace(
      name: '동묘집',
      address: '서울 종로구 종로52길 43-9',
      category: PlaceCategory.restaurant,
      confidence: 1,
      evidenceIds: [],
    ),
    summary: '매콤한 철판쭈꾸미와 볶음밥을 함께 즐길 수 있는 곳으로 주말 모임에 잘 어울려요.',
    evidence: [],
    ingredientGroups: [],
    steps: [],
    facts: facts,
    conflicts: [],
    warnings: [],
  );
  final receivedAt = DateTime.utc(2026, 8, 5);
  return CaptureRecord(
    raw: RawCapture(
      id: 'share-card-capture',
      transportEventId: 'share-card-transport',
      receivedAt: receivedAt,
      origin: CaptureOrigin.androidShare,
      mimeType: 'image/png',
      rawText: 'raw screenshot text',
      rawUrl: 'https://www.instagram.com/reel/example/?igsh=sample',
      semanticFingerprint: 'share-card-fingerprint',
      wasTruncated: false,
      originalLength: 19,
      sourcePackage: 'Instagram',
    ),
    normalized: const NormalizedInput(
      inputId: 'share-card-input',
      normalizerVersion: 'test',
      normalizedText: 'normalized screenshot text',
      urls: [],
      semanticFingerprint: 'share-card-fingerprint',
      completeness: MaterialCompleteness.complete,
      warnings: [],
    ),
    status: CaptureStatus.organized,
    analysis: AnalysisRun(
      id: 'share-card-analysis',
      inputId: 'share-card-input',
      normalizerVersion: 'test',
      analyzerVersion: 'test',
      status: AnalysisRunStatus.succeeded,
      completedAt: receivedAt,
      evidence: const [],
      productMentions: const [],
      statements: const [],
      disclosure: DisclosureObservation.unknown,
      structuredContent: structured,
    ),
  );
}
