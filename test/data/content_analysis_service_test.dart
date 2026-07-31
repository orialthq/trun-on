import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/content_analysis_service.dart';
import 'package:ori_beauty/domain/models.dart';

void main() {
  const analyzer = BaselineContentAnalysisService();

  test('canonicalizes tracking parameters while preserving content ids', () {
    expect(
      BaselineContentAnalysisService.canonicalizeUrl(
        'https://YouTube.com/watch?utm_source=sns&v=abc123&si=nope#comments',
      ),
      'https://youtube.com/watch?v=abc123',
    );
  });

  test(
    'preserves raw input and links every extracted statement to evidence',
    () {
      const rawText =
          '  #광고 바움랩 포어 밸런스 세럼 30ml. '
          '가볍게 발린다고 소개했어요.  ';
      final capture = analyzer.analyzeShare(
        IncomingShare(
          id: 'share-1',
          receivedAt: DateTime(2026, 7, 31),
          sharedText: rawText,
          discoveredUrl: null,
        ),
      );

      expect(capture.raw.rawText, rawText);
      expect(capture.primaryMention?.brand.value, '바움랩');
      expect(capture.primaryMention?.amount.value, '30mL');
      expect(
        capture.analysis?.disclosure,
        DisclosureObservation.explicitlyObserved,
      );
      expect(capture.analysis?.statements, isNotEmpty);

      final evidenceIds = capture.analysis!.evidence
          .map((evidence) => evidence.id)
          .toSet();
      for (final statement in capture.analysis!.statements) {
        expect(statement.evidenceIds, isNotEmpty);
        expect(statement.evidenceIds.every(evidenceIds.contains), isTrue);
      }
    },
  );

  test('keeps URL-only input as source limited instead of guessing', () {
    final capture = analyzer.analyzeShare(
      IncomingShare(
        id: 'share-link',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: 'https://instagram.com/reel/abc?igshid=tracking',
        discoveredUrl: 'https://instagram.com/reel/abc?igshid=tracking',
      ),
    );

    expect(capture.status, CaptureStatus.sourceLimited);
    expect(capture.primaryMention?.overallConfidence, lessThan(0.6));
    expect(
      capture.normalized.urls.single.canonicalValue,
      'https://instagram.com/reel/abc',
    );
    expect(capture.analysis?.disclosure, DisclosureObservation.unknown);
  });

  test('does not infer an amount that is absent from captured material', () {
    final capture = analyzer.analyzeShare(
      IncomingShare(
        id: 'share-daylight',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: '데이라이트 에어리 선 플루이드가 가볍다고 소개됐어요.',
        discoveredUrl: null,
      ),
    );

    expect(capture.primaryMention?.name.value, '에어리 선 플루이드');
    expect(capture.primaryMention?.amount.value, isNull);
    expect(
      capture.primaryMention?.missingFields,
      contains(MissingField.amount),
    );
  });

  test('extracts an unknown beauty product as a reviewable candidate', () {
    final capture = analyzer.analyzeShare(
      IncomingShare(
        id: 'share-generic',
        receivedAt: DateTime(2026, 7, 31),
        sharedText:
            '바움랩 워터리 선 세럼 50ml. 백탁 없이 가볍고 촉촉했어요. '
            'https://instagram.com/reel/generic',
        discoveredUrl: 'https://instagram.com/reel/generic',
      ),
    );

    expect(capture.status, CaptureStatus.needsReview);
    expect(capture.primaryMention?.brand.value, '바움랩');
    expect(capture.primaryMention?.name.value, '워터리 선 세럼');
    expect(capture.primaryMention?.category.value, '선케어');
    expect(capture.primaryMention?.amount.value, '50mL');
    expect(capture.primaryMention?.overallConfidence, lessThan(0.8));
    expect(
      capture.analysis!.statements.map((statement) => statement.topic),
      containsAll(['가벼운 사용감', '보습', '백탁']),
    );
  });
}
