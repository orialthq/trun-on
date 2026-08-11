import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/features/products/saved_library_item.dart';

/// The deck groups by the labels an item carries on the selected axis, which is
/// where overlap comes from. This exercises that grouping directly rather than
/// through the widget, so the rule stays pinned independently of layout.
List<MapEntry<String, List<SavedLibraryItem>>> groupBy(
  ContentAxis axis,
  List<SavedLibraryItem> items, {
  String unlabelled = '분류 필요',
}) {
  final grouped = <String, List<SavedLibraryItem>>{};
  for (final item in items) {
    final labels = item.labelsOn(axis);
    if (labels.isEmpty) {
      grouped.putIfAbsent(unlabelled, () => []).add(item);
      continue;
    }
    for (final label in labels) {
      grouped.putIfAbsent(label, () => []).add(item);
    }
  }
  return grouped.entries.toList();
}

CaptureRecord _organizedCapture({
  required String id,
  required String title,
  required Map<ContentAxis, List<String>> axisLabels,
}) {
  final axes = ContentAxes(
    labels: {
      for (final entry in axisLabels.entries)
        entry.key: [
          for (final value in entry.value)
            AxisLabel(value: value, confidence: 0.9, evidenceIds: const ['e1']),
        ],
    },
  );
  final kind = axisLabels[ContentAxis.kind] ?? const <String>[];
  final receivedAt = DateTime.utc(2026, 8, 7);
  return CaptureRecord(
    raw: RawCapture(
      id: id,
      transportEventId: id,
      receivedAt: receivedAt,
      origin: CaptureOrigin.androidShare,
      mimeType: 'image/png',
      rawText: title,
      rawUrl: null,
      semanticFingerprint: id,
      wasTruncated: false,
      originalLength: title.length,
      sourcePackage: 'Instagram',
    ),
    normalized: NormalizedInput(
      inputId: '$id-input',
      normalizerVersion: 'test',
      normalizedText: title,
      urls: const [],
      semanticFingerprint: id,
      completeness: MaterialCompleteness.complete,
      warnings: const [],
    ),
    status: CaptureStatus.organized,
    folderOverride: ContentFolder.restaurantCafe,
    subcategoryOverride: kind.isEmpty ? null : kind.first,
    analysis: AnalysisRun(
      id: '$id-analysis',
      inputId: '$id-input',
      normalizerVersion: 'test',
      analyzerVersion: 'test',
      status: AnalysisRunStatus.succeeded,
      completedAt: receivedAt,
      evidence: const [],
      productMentions: const [],
      statements: const [],
      disclosure: DisclosureObservation.unknown,
      structuredContent: StructuredContentAnalysis(
        schemaVersion: '1.3',
        model: 'gpt-5.6-luna',
        domain: ContentDomain.food,
        contentKind: ContentKind.place,
        primaryCategory: ContentFolder.restaurantCafe,
        categoryConfidence: 0.9,
        subcategory: kind.isEmpty ? '기타' : kind.first,
        subcategoryConfidence: 0.9,
        axes: axes,
        completeness: StructuredCompleteness.complete,
        title: StructuredTitle(
          value: title,
          status: ObservedStatus.observed,
          confidence: 0.9,
          evidenceIds: const ['e1'],
        ),
        place: null,
        summary: '',
        evidence: const [],
        ingredientGroups: const [],
        steps: const [],
        facts: const [],
        conflicts: const [],
        warnings: const [],
      ),
    ),
  );
}

void main() {
  test('one capture lands on every kind card it carries', () {
    final item = SavedLibraryItem.forCapture(
      _organizedCapture(
        id: 'ristorante',
        title: '리스토란테 오늘',
        axisLabels: {
          ContentAxis.kind: ['파스타', '와인바'],
          ContentAxis.location: ['성수'],
        },
      ),
    );

    final byKind = Map.fromEntries(groupBy(ContentAxis.kind, [item]));

    expect(byKind.keys, containsAll(['파스타', '와인바']));
    expect(byKind['파스타']!.single.title, '리스토란테 오늘');
    expect(byKind['와인바']!.single.title, '리스토란테 오늘');
  });

  test('switching axes regroups the same captures', () {
    final items = [
      SavedLibraryItem.forCapture(
        _organizedCapture(
          id: 'a',
          title: '리스토란테 오늘',
          axisLabels: {
            ContentAxis.kind: ['파스타'],
            ContentAxis.location: ['성수'],
          },
        ),
      ),
      SavedLibraryItem.forCapture(
        _organizedCapture(
          id: 'b',
          title: '파스타바 논나',
          axisLabels: {
            ContentAxis.kind: ['파스타'],
            ContentAxis.location: ['연남'],
          },
        ),
      ),
    ];

    final byKind = Map.fromEntries(groupBy(ContentAxis.kind, items));
    final byLocation = Map.fromEntries(groupBy(ContentAxis.location, items));

    expect(byKind['파스타'], hasLength(2));
    expect(byLocation.keys, containsAll(['성수', '연남']));
    expect(byLocation['성수'], hasLength(1));
  });

  test('an axis with no labels keeps the capture under 분류 필요', () {
    final item = SavedLibraryItem.forCapture(
      _organizedCapture(
        id: 'c',
        title: '오스테리아 초이',
        axisLabels: {
          ContentAxis.kind: ['파스타'],
        },
      ),
    );

    final byAccess = Map.fromEntries(groupBy(ContentAxis.waiting, [item]));

    // Nothing vanishes when an axis has nothing to say about it.
    expect(byAccess.keys, ['분류 필요']);
    expect(byAccess['분류 필요']!.single.title, '오스테리아 초이');
  });

  test('a user correction leads the kind axis', () {
    final item = SavedLibraryItem.forCapture(
      _organizedCapture(
        id: 'd',
        title: '리스토란테 오늘',
        axisLabels: {
          ContentAxis.kind: ['파스타', '와인바'],
        },
      ),
    );

    expect(item.labelsOn(ContentAxis.kind).first, '파스타');
    expect(item.labelsOn(ContentAxis.kind), hasLength(2));
  });
}
