import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/app_snapshot_store.dart';
import 'package:ori_beauty/data/content_analysis_service.dart';
import 'package:ori_beauty/data/remote_content_analysis_service.dart';
import 'package:ori_beauty/domain/models.dart';

void main() {
  test('parses the exact Luna analysis contract', () {
    final analysis = StructuredContentAnalysis.fromJson(_validResponse());

    expect(analysis.model, 'gpt-5.6-luna');
    expect(analysis.domain, ContentDomain.food);
    expect(analysis.contentKind, ContentKind.recipe);
    expect(analysis.primaryCategory, ContentFolder.recipe);
    expect(analysis.categoryNeedsReview, isFalse);
    expect(analysis.subcategory, '밑반찬');
    expect(analysis.subcategoryConfidence, 0.93);
    expect(analysis.ingredientGroups.single.ingredients.single.unit, '큰술');
    expect(analysis.steps.single.evidenceIds, ['e2']);
  });

  test('parses observed place data and keeps old snapshots readable', () {
    final response = _validResponse();
    response['contentKind'] = 'place';
    response['place'] = <String, Object?>{
      'name': '챙김 식당',
      'address': '서울특별시 중구 세종대로 110',
      'category': 'restaurant',
      'confidence': 0.94,
      'evidenceIds': ['e1'],
    };

    final analysis = StructuredContentAnalysis.fromJson(response);
    expect(analysis.contentKind, ContentKind.place);
    expect(analysis.place?.category, PlaceCategory.restaurant);
    expect(analysis.place?.hasAddress, isTrue);

    final legacy = _validResponse()
      ..['schemaVersion'] = '1.0'
      ..remove('place')
      ..remove('primaryCategory')
      ..remove('categoryConfidence')
      ..remove('subcategory')
      ..remove('subcategoryConfidence');
    final migrated = StructuredContentAnalysis.fromJson(legacy);
    expect(migrated.place, isNull);
    expect(migrated.primaryCategory, ContentFolder.recipe);
    expect(migrated.subcategory, '요리');

    final categoryEra = _validResponse()
      ..['schemaVersion'] = '1.1'
      ..remove('subcategory')
      ..remove('subcategoryConfidence');
    final categoryEraMigrated = StructuredContentAnalysis.fromJson(categoryEra);
    expect(categoryEraMigrated.subcategory, '요리');
    expect(categoryEraMigrated.subcategoryConfidence, 0.6);

    final legacyBeauty = _validResponse()
      ..['schemaVersion'] = '1.1'
      ..['domain'] = 'beauty'
      ..['contentKind'] = 'beauty_product'
      ..['primaryCategory'] = 'beauty'
      ..remove('subcategory')
      ..remove('subcategoryConfidence');
    (legacyBeauty['title']! as Map<String, Object?>)['value'] = '오로라 글로우';
    expect(StructuredContentAnalysis.fromJson(legacyBeauty).subcategory, '뷰티');
  });

  test('rejects unknown versions and enum values', () {
    final wrongVersion = _validResponse()..['schemaVersion'] = '2.0';
    expect(
      () => StructuredContentAnalysis.fromJson(wrongVersion),
      throwsFormatException,
    );

    final wrongKind = _validResponse()..['contentKind'] = 'social_post';
    expect(
      () => StructuredContentAnalysis.fromJson(wrongKind),
      throwsFormatException,
    );

    final wrongCategory = _validResponse()..['primaryCategory'] = 'finance';
    expect(
      () => StructuredContentAnalysis.fromJson(wrongCategory),
      throwsFormatException,
    );
  });

  test('rejects missing fields and dangling evidence references', () {
    final missingField = _validResponse()..remove('warnings');
    expect(
      () => StructuredContentAnalysis.fromJson(missingField),
      throwsFormatException,
    );

    final missingV12Subcategory = _validResponse()..remove('subcategory');
    expect(
      () => StructuredContentAnalysis.fromJson(missingV12Subcategory),
      throwsFormatException,
    );

    final dangling = _validResponse();
    final steps = dangling['steps']! as List<Object?>;
    (steps.single as Map<String, Object?>)['evidenceIds'] = ['not-emitted'];
    expect(
      () => StructuredContentAnalysis.fromJson(dangling),
      throwsFormatException,
    );
  });

  test('rejects malformed confidence instead of silently clamping it', () {
    final malformed = _validResponse();
    final evidence = malformed['evidence']! as List<Object?>;
    (evidence.first as Map<String, Object?>)['confidence'] = 1.5;

    expect(
      () => StructuredContentAnalysis.fromJson(malformed),
      throwsFormatException,
    );
  });

  test('rejects unsafe Luna 1.2 subcategory labels', () {
    for (final invalid in [
      '뷰',
      '향수✨',
      '  스킨케어  ',
      '스킨--케어',
      '123456789012345678901',
    ]) {
      final response = _validResponse()..['subcategory'] = invalid;
      expect(
        () => StructuredContentAnalysis.fromJson(response),
        throwsFormatException,
        reason: invalid,
      );
    }
  });

  test('normalizes concise user and AI subcategory names', () {
    expect(normalizeContentSubcategory('  카페   디저트  '), '카페 디저트');
    expect(normalizeContentSubcategory('향수✨'), '향수');
    expect(normalizeContentSubcategory('✨'), '기타');
    expect(normalizeContentSubcategory('뷰'), '기타');
    expect(isValidContentSubcategory('정리ㆍ수납'), isTrue);
    expect(isValidContentSubcategory('정리--수납'), isFalse);
    expect(
      normalizeContentSubcategory('1234567890123456789012345'),
      '12345678901234567890',
    );

    const baseline = BaselineContentAnalysisService();
    final legacyProduct = baseline.analyzeShare(
      IncomingShare(
        id: 'legacy-serum-subcategory',
        receivedAt: DateTime(2026, 8, 2),
        sharedText: '바움랩 포어 밸런스 세럼 30ml',
        discoveredUrl: null,
      ),
    );
    expect(legacyProduct.contentSubcategory, '스킨케어');
  });

  test('routes a low-confidence category to classification review', () {
    final response = _validResponse()..['categoryConfidence'] = 0.4;
    final structured = StructuredContentAnalysis.fromJson(response);
    const baseline = BaselineContentAnalysisService();
    final prepared = baseline.prepareShare(
      IncomingShare(
        id: 'low-category-confidence',
        receivedAt: DateTime(2026, 8, 2),
        sharedText: 'image placeholder',
        discoveredUrl: null,
      ),
    );
    final record = prepared.copyWith(
      analysis: AnalysisRun(
        id: 'analysis-low-category-confidence',
        inputId: prepared.raw.id,
        normalizerVersion: prepared.normalized.normalizerVersion,
        analyzerVersion: 'luna-structured-v1',
        status: AnalysisRunStatus.succeeded,
        completedAt: DateTime(2026, 8, 2),
        evidence: const [],
        productMentions: const [],
        statements: const [],
        disclosure: DisclosureObservation.unknown,
        structuredContent: structured,
      ),
    );

    expect(record.contentFolder, ContentFolder.needsClassification);
  });

  test('persists the completed structured result without re-analysis', () {
    const baseline = BaselineContentAnalysisService();
    final prepared = baseline.prepareShare(
      IncomingShare(
        id: 'persisted-structured',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: 'private image placeholder',
        discoveredUrl: null,
      ),
    );
    final structured = StructuredContentAnalysis.fromJson(_validResponse());
    final record = prepared.copyWith(
      status: CaptureStatus.needsReview,
      folderOverride: ContentFolder.travelPlace,
      subcategoryOverride: '숙소',
      analysis: AnalysisRun(
        id: 'analysis-persisted-structured',
        inputId: prepared.raw.id,
        normalizerVersion: prepared.normalized.normalizerVersion,
        analyzerVersion: 'luna-structured-v1',
        status: AnalysisRunStatus.succeeded,
        completedAt: DateTime(2026, 7, 31, 12),
        evidence: const [],
        productMentions: const [],
        statements: const [],
        disclosure: DisclosureObservation.unknown,
        model: 'gpt-5.6-luna',
        structuredContent: structured,
      ),
    );

    final encoded = AppSnapshotCodec.encode([
      PersistedCapture.fromRecord(record, null),
    ]);
    final restored = AppSnapshotCodec.decode(encoded).single;

    expect(restored.analysis?.id, 'analysis-persisted-structured');
    expect(restored.folderOverride, ContentFolder.travelPlace);
    expect(restored.subcategoryOverride, '숙소');
    expect(
      restored.analysis?.structuredContent?.contentKind,
      ContentKind.recipe,
    );
    expect(
      restored.analysis?.structuredContent?.ingredientGroups.single.ingredients,
      hasLength(1),
    );
  });

  test(
    'remote analysis sends only the source origin and parses the result',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ori-remote-test-',
      );
      final image = File('${directory.path}/capture.jpg');
      await image.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9], flush: true);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, Object?>? received;
      server.listen((request) async {
        received =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_validResponse()));
        await request.response.close();
      });

      try {
        const baseline = BaselineContentAnalysisService();
        final capture = baseline.prepareShare(
          IncomingShare(
            id: 'remote-contract',
            receivedAt: DateTime.utc(2026, 7, 31),
            sharedText: '',
            discoveredUrl:
                'https://example.com/private/path?token=secret#fragment',
            sourcePackage: 'com.example.source',
            mimeType: 'image/jpeg',
            shareKind: ShareKind.image,
            attachments: [
              IncomingAttachment(
                id: 'attachment-1',
                filePath: '',
                mimeType: 'image/jpeg',
                byteSize: 4,
                sha256:
                    '0000000000000000000000000000000000000000000000000000000000000000',
              ),
            ],
          ),
        );
        final attachment = IncomingAttachment(
          id: capture.raw.attachments.single.id,
          filePath: image.path,
          mimeType: 'image/jpeg',
          byteSize: 4,
          sha256: capture.raw.attachments.single.sha256,
        );
        final prepared = CaptureRecord(
          raw: RawCapture(
            id: capture.raw.id,
            transportEventId: capture.raw.transportEventId,
            receivedAt: capture.raw.receivedAt,
            origin: capture.raw.origin,
            mimeType: capture.raw.mimeType,
            rawText: capture.raw.rawText,
            rawUrl: capture.raw.rawUrl,
            semanticFingerprint: capture.raw.semanticFingerprint,
            wasTruncated: capture.raw.wasTruncated,
            originalLength: capture.raw.originalLength,
            sourcePackage: capture.raw.sourcePackage,
            attachments: [attachment],
          ),
          normalized: capture.normalized,
          status: capture.status,
          analysis: null,
        );
        final service = RemoteContentAnalysisService(
          baseUrl: 'http://127.0.0.1:${server.port}',
        );

        final analysis = await service.analyze(prepared);
        final captureJson = received!['capture']! as Map<String, Object?>;

        expect(analysis.structuredContent?.contentKind, ContentKind.recipe);
        expect(captureJson['sourceUrl'], 'https://example.com');
        expect(jsonEncode(received), isNot(contains('private/path')));
        expect(jsonEncode(received), isNot(contains('secret')));
      } finally {
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );
}

Map<String, Object?> _validResponse() {
  const source = '''
{
  "schemaVersion": "1.2",
  "model": "gpt-5.6-luna",
  "domain": "food",
  "contentKind": "recipe",
  "primaryCategory": "recipe",
  "categoryConfidence": 0.98,
  "subcategory": "밑반찬",
  "subcategoryConfidence": 0.93,
  "completeness": "partial",
  "title": {
    "value": "화면에 보이는 요리",
    "status": "observed",
    "confidence": 0.98,
    "evidenceIds": ["e1"]
  },
  "place": {
    "name": null,
    "address": null,
    "category": null,
    "confidence": 0,
    "evidenceIds": []
  },
  "summary": "화면에서 확인한 재료와 순서예요.",
  "evidence": [
    {
      "id": "e1",
      "text": "화면에 보이는 요리",
      "region": "overlay",
      "confidence": 0.99
    },
    {
      "id": "e2",
      "text": "양념을 섞어요",
      "region": "image_text",
      "confidence": 0.96
    }
  ],
  "ingredientGroups": [
    {
      "name": "재료",
      "ingredients": [
        {
          "name": "양념",
          "amount": "1",
          "unit": "큰술",
          "preparation": null,
          "optional": false,
          "originalText": "양념 1큰술",
          "confidence": 0.95,
          "evidenceIds": ["e1"]
        }
      ]
    }
  ],
  "steps": [
    {
      "order": 1,
      "instruction": "양념을 섞어요.",
      "durationSeconds": null,
      "temperature": null,
      "evidenceIds": ["e2"]
    }
  ],
  "facts": [],
  "conflicts": [],
  "warnings": ["일부 재료의 분량은 보이지 않아요."]
}
''';
  return jsonDecode(source) as Map<String, Object?>;
}
