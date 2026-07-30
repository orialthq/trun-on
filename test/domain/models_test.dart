import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/models.dart';

void main() {
  group('IncomingShare', () {
    test('extracts the first URL and removes trailing punctuation', () {
      expect(
        IncomingShare.extractFirstUrl(
          '이 제품 봐주세요 (https://example.com/reel/123).',
        ),
        'https://example.com/reel/123',
      );
    });

    test('decodes the version 1 platform map', () {
      final share = IncomingShare.fromPlatformMap({
        'id': 'share-1',
        'receivedAtEpochMs': 1785402000000,
        'sharedText': 'saved https://example.com/post',
        'discoveredUrl': 'https://example.com/post',
      });

      expect(share.id, 'share-1');
      expect(share.discoveredUrl, 'https://example.com/post');
      expect(share.sharedText, contains('saved'));
    });
  });
}
