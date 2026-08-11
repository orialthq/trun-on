import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/models.dart';

AxisLabel _screen(String value) =>
    AxisLabel(value: value, confidence: 0.9, evidenceIds: const ['e1']);

AxisLabel _web(String value) => AxisLabel(
  value: value,
  confidence: 0.8,
  evidenceIds: const [],
  source: AxisLabelSource.web,
  quotes: ['$value 라고 적힌 문장'],
  citations: ['https://example.com/$value'],
);

void main() {
  test('web labels fill an axis the screenshot said nothing about', () {
    final screen = ContentAxes(
      labels: {
        ContentAxis.kind: [_screen('파스타')],
      },
    );
    final web = ContentAxes(
      labels: {
        ContentAxis.waiting: [_web('상시 웨이팅')],
              },
    );

    final merged = screen.mergedWith(web);

    expect(merged[ContentAxis.waiting].single.value, '상시 웨이팅');
    expect(merged[ContentAxis.waiting].single.source, AxisLabelSource.web);
    expect(merged[ContentAxis.waiting].single.citations, isNotEmpty);
    expect(merged[ContentAxis.waiting].single.quotes, isNotEmpty);
  });

  test('a web label extends an axis the screenshot already used', () {
    final screen = ContentAxes(
      labels: {
        ContentAxis.kind: [_screen('파스타')],
      },
    );
    final web = ContentAxes(
      labels: {
        ContentAxis.kind: [_web('와인바')],
      },
    );

    final merged = screen.mergedWith(web);

    // The point of overlapping axes: the shop reaches the reader from both.
    expect(
      merged[ContentAxis.kind].map((label) => label.value),
      ['파스타', '와인바'],
    );
    expect(merged[ContentAxis.kind].first.source, AxisLabelSource.screen);
  });

  test('a web label never duplicates what the screenshot showed', () {
    final screen = ContentAxes(
      labels: {
        ContentAxis.kind: [_screen('파스타')],
      },
    );
    final web = ContentAxes(
      labels: {
        ContentAxis.kind: [_web('파스타'), _web('와인바')],
      },
    );

    final merged = screen.mergedWith(web);

    expect(merged[ContentAxis.kind], hasLength(2));
    // The screenshot's own evidence keeps the label.
    expect(merged[ContentAxis.kind].first.source, AxisLabelSource.screen);
  });

  test('merging an empty result changes nothing', () {
    final screen = ContentAxes(
      labels: {
        ContentAxis.kind: [_screen('파스타')],
      },
    );

    final merged = screen.mergedWith(const ContentAxes.empty());

    expect(merged[ContentAxis.kind].single.value, '파스타');
    expect(merged[ContentAxis.waiting], isEmpty);
  });

  test('a merged web label survives a snapshot round-trip', () {
    final merged = const ContentAxes.empty().mergedWith(
      ContentAxes(
        labels: {
          ContentAxis.waiting: [_web('상시 웨이팅')],
        },
      ),
    );

    final restored = ContentAxes.fromJson(merged.toJson());
    final label = restored[ContentAxis.waiting].single;

    expect(label.source, AxisLabelSource.web);
    expect(label.citations, ['https://example.com/상시 웨이팅']);
    expect(label.quotes, ['상시 웨이팅 라고 적힌 문장']);
  });
}
