import '../domain/models.dart';
import 'content_analysis_service.dart';

abstract final class DemoCatalog {
  static const _analyzer = BaselineContentAnalysisService();

  static final _baumOne = _organized(
    share: IncomingShare(
      id: 'demo-baum-1',
      receivedAt: DateTime(2026, 7, 29, 21, 10),
      sharedText:
          '#광고 바움랩 포어 밸런스 세럼 30ml. 피지와 모공이 신경 쓰일 때 '
          '산뜻하게 발린다고 소개했어요. '
          'https://instagram.com/reel/baum-1?utm_source=share',
      discoveredUrl: 'https://instagram.com/reel/baum-1?utm_source=share',
      sourcePackage: 'com.instagram.android',
    ),
    groupId: 'group-baumlab-pore-balance',
    identity: const ConfirmedProductIdentity(
      brand: '바움랩',
      name: '포어 밸런스 세럼',
      category: '세럼',
      amount: '30mL',
    ),
  );

  static final _baumTwo = _organized(
    share: IncomingShare(
      id: 'demo-baum-2',
      receivedAt: DateTime(2026, 7, 30, 8, 35),
      sharedText:
          '바움랩 포어 밸런스 세럼을 써봤는데 가벼운 사용감은 좋았고, '
          '건조한 날에는 보습이 조금 아쉬웠어요. '
          'https://youtube.com/shorts/baum-2?si=tracking',
      discoveredUrl: 'https://youtube.com/shorts/baum-2?si=tracking',
      sourcePackage: 'com.google.android.youtube',
    ),
    groupId: 'group-baumlab-pore-balance',
    identity: const ConfirmedProductIdentity(
      brand: '바움랩',
      name: '포어 밸런스 세럼',
      category: '세럼',
      amount: '30mL',
    ),
  );

  static final _leafon = _organized(
    share: IncomingShare(
      id: 'demo-leafon-1',
      receivedAt: DateTime(2026, 7, 30, 18, 20),
      sharedText:
          '리프온 카밍 앰플 40ml 사용 후기. 붉은기가 올라온 날 진정용으로 '
          '사용했고 촉촉한 편이라고 언급했어요. '
          'https://x.com/beautylog/status/100',
      discoveredUrl: 'https://x.com/beautylog/status/100',
      sourcePackage: 'com.twitter.android',
    ),
    groupId: 'group-leafon-calming',
    identity: const ConfirmedProductIdentity(
      brand: '리프온',
      name: '카밍 앰플',
      category: '앰플',
      amount: '40mL',
    ),
  );

  static final _daylightNeedsReview = _analyzer.analyzeShare(
    IncomingShare(
      id: 'demo-daylight-review',
      receivedAt: DateTime(2026, 7, 31, 9, 5),
      sharedText:
          '데이라이트 에어리 선 플루이드가 백탁 없이 가볍다고 소개된 영상. '
          '용량 표시는 잘 안 보여요. '
          'https://instagram.com/reel/daylight?igshid=tracking',
      discoveredUrl: 'https://instagram.com/reel/daylight?igshid=tracking',
      sourcePackage: 'com.instagram.android',
    ),
    origin: CaptureOrigin.demo,
  );

  static final _linkOnly = _analyzer.analyzeShare(
    IncomingShare(
      id: 'demo-link-only',
      receivedAt: DateTime(2026, 7, 31, 9, 40),
      sharedText: 'https://www.tiktok.com/@beauty/video/123?utm_medium=share',
      discoveredUrl:
          'https://www.tiktok.com/@beauty/video/123?utm_medium=share',
      sourcePackage: 'com.zhiliaoapp.musically',
    ),
    origin: CaptureOrigin.demo,
  );

  static final captures = <CaptureRecord>[
    _daylightNeedsReview,
    _linkOnly,
    _leafon,
    _baumTwo,
    _baumOne,
  ];

  static final groups = <ProductGroup>[
    ProductGroup(
      id: 'group-baumlab-pore-balance',
      identity: _baumOne.review!.confirmedIdentity!,
      sourceCaptureIds: [_baumOne.raw.id, _baumTwo.raw.id],
      statements: [
        ...?_baumOne.analysis?.statements,
        ...?_baumTwo.analysis?.statements,
      ],
      updatedAt: _baumTwo.raw.receivedAt,
      colorValue: 0xFFB89CD9,
    ),
    ProductGroup(
      id: 'group-leafon-calming',
      identity: _leafon.review!.confirmedIdentity!,
      sourceCaptureIds: [_leafon.raw.id],
      statements: [...?_leafon.analysis?.statements],
      updatedAt: _leafon.raw.receivedAt,
      colorValue: 0xFF8FC6A8,
    ),
  ];

  static CaptureRecord _organized({
    required IncomingShare share,
    required String groupId,
    required ConfirmedProductIdentity identity,
  }) {
    final analyzed = _analyzer.analyzeShare(share, origin: CaptureOrigin.demo);
    return analyzed.copyWith(
      status: CaptureStatus.organized,
      groupId: groupId,
      review: UserReview(
        id: 'review-${share.id}',
        captureId: analyzed.raw.id,
        analysisRunId: analyzed.analysis!.id,
        resolution: ReviewResolution.confirmed,
        reviewedAt: share.receivedAt,
        candidateId: analyzed.primaryMention?.id,
        confirmedIdentity: identity,
      ),
    );
  }
}
