import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/models.dart';

Map<String, Object?> _label(String value, {double confidence = 0.9}) => {
  'value': value,
  'confidence': confidence,
  'evidenceIds': const ['e1'],
};

Map<String, Object?> _analysis({
  String schemaVersion = '1.5',
  Map<String, Object?>? axes,
  Map<String, Object?>? place,
}) => {
  'schemaVersion': schemaVersion,
  'model': 'gpt-5.6-luna',
  'domain': 'food',
  'contentKind': 'place',
  'primaryCategory': 'restaurant_cafe',
  'categoryConfidence': 0.9,
  'subcategory': '파스타',
  'subcategoryConfidence': 0.9,
  // Omitted entirely for the legacy versions, which is what triggers the
  // migration path.
  'axes': ?axes,
  'completeness': 'complete',
  'title': {
    'value': '리스토란테 오늘',
    'status': 'observed',
    'confidence': 0.9,
    'evidenceIds': const ['e1'],
  },
  'place': place,
  'summary': '성수의 파스타집이에요.',
  'evidence': [
    {'id': 'e1', 'text': '리스토란테 오늘', 'region': 'image_text', 'confidence': 0.9},
  ],
  'ingredientGroups': const [],
  'steps': const [],
  'facts': const [],
  'conflicts': const [],
  'warnings': const [],
};

void main() {
  test('a capture can sit on several labels of one axis', () {
    final analysis = StructuredContentAnalysis.fromJson(
      _analysis(
        axes: {
          'kind': [_label('파스타'), _label('와인바', confidence: 0.6)],
          'location': [_label('성수')],
          'access': [_label('예약 필수', confidence: 0.5)],
          'savedReason': const <Map<String, Object?>>[],
        },
      ),
    );

    // The same place is reachable from both the 파스타 card and the 와인바 card.
    expect(analysis.axes[ContentAxis.kind].map((label) => label.value), [
      '파스타',
      '와인바',
    ]);
    expect(analysis.axes[ContentAxis.location].single.value, '성수');
    expect(analysis.axes[ContentAxis.access].single.value, '예약 필수');
    expect(analysis.axes.isEmpty, isFalse);
  });

  test('drops a repeated label so one card cannot list a capture twice', () {
    final analysis = StructuredContentAnalysis.fromJson(
      _analysis(
        axes: {
          'kind': [_label('파스타'), _label('파스타', confidence: 0.4)],
          'location': const <Map<String, Object?>>[],
          'access': const <Map<String, Object?>>[],
          'savedReason': const <Map<String, Object?>>[],
        },
      ),
    );

    expect(analysis.axes[ContentAxis.kind], hasLength(1));
  });

  test('rejects a label that is not reusable', () {
    expect(
      () => StructuredContentAnalysis.fromJson(
        _analysis(
          axes: {
            'kind': [_label('파스타 #맛집 🍝')],
            'location': const <Map<String, Object?>>[],
            'access': const <Map<String, Object?>>[],
            'savedReason': const <Map<String, Object?>>[],
          },
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects an analysis that renames or drops an axis', () {
    expect(
      () => StructuredContentAnalysis.fromJson(
        _analysis(
          axes: {
            'kind': [_label('파스타')],
            'location': const <Map<String, Object?>>[],
            'access': const <Map<String, Object?>>[],
            'mood': const <Map<String, Object?>>[],
          },
        ),
      ),
      throwsFormatException,
    );
  });

  test('rebuilds axes for a capture stored before they existed', () {
    final analysis = StructuredContentAnalysis.fromJson(
      _analysis(
        schemaVersion: '1.2',
        place: {
          'name': '리스토란테 오늘',
          'address': '서울 성동구 성수동2가 1',
          'searchArea': '성수',
          'category': 'restaurant',
          'confidence': 0.8,
          'evidenceIds': const ['e1'],
        },
      ),
    );

    // The single old subcategory becomes the one kind label, and a stored area
    // becomes the one location label. Nothing else is invented.
    expect(analysis.axes[ContentAxis.kind].single.value, '파스타');
    expect(analysis.axes[ContentAxis.location].single.value, '성수');
    expect(analysis.axes[ContentAxis.access], isEmpty);
    expect(analysis.axes[ContentAxis.savedReason], isEmpty);
  });

  test('a capture stored under retired axes still opens', () {
    // 상황 and 가격대 went in 1.4, 인원 in 1.5. A reader's saved capture must
    // survive every one of those: retired labels are dropped, everything else is
    // kept, and a new axis starts empty until the next web lookup fills it.
    final analysis = StructuredContentAnalysis.fromJson(
      _analysis(
        schemaVersion: '1.3',
        axes: {
          'kind': [_label('파스타')],
          'location': [_label('성수')],
          'occasion': [_label('데이트')],
          'priceRange': [_label('2~5만원')],
          'seating': [_label('단체 가능')],
          'savedReason': const <Map<String, Object?>>[],
        },
      ),
    );

    expect(analysis.axes[ContentAxis.kind].single.value, '파스타');
    expect(analysis.axes[ContentAxis.location].single.value, '성수');
    expect(analysis.axes[ContentAxis.access], isEmpty);
  });

  test('leaves location empty for a legacy capture with no place', () {
    final analysis = StructuredContentAnalysis.fromJson(
      _analysis(schemaVersion: '1.1'),
    );

    expect(analysis.axes[ContentAxis.kind].single.value, '파스타');
    expect(analysis.axes[ContentAxis.location], isEmpty);
  });

  test('round-trips through a snapshot', () {
    final original = StructuredContentAnalysis.fromJson(
      _analysis(
        axes: {
          'kind': [_label('파스타'), _label('와인바')],
          'location': [_label('성수')],
          'access': const <Map<String, Object?>>[],
          'savedReason': const <Map<String, Object?>>[],
        },
      ),
    );

    final restored = StructuredContentAnalysis.fromJson(original.toJson());

    expect(restored.axes[ContentAxis.kind].map((label) => label.value), [
      '파스타',
      '와인바',
    ]);
    expect(
      restored.axes[ContentAxis.kind].first.source,
      AxisLabelSource.screen,
    );
  });
}
