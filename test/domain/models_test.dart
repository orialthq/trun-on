import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/models.dart';

void main() {
  group('IncomingShare', () {
    test('extracts the first URL without mutating the shared text', () {
      const original = '  이 제품 봐주세요 (https://example.com/reel/123).  ';

      expect(
        IncomingShare.extractFirstUrl(original),
        'https://example.com/reel/123',
      );

      final share = IncomingShare(
        id: 'share-1',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: original,
        discoveredUrl: 'https://example.com/reel/123',
      );
      expect(share.sharedText, original);
    });

    test('decodes version 1 metadata without silent id fallback', () {
      final share = IncomingShare.fromPlatformMap({
        'id': 'share-1',
        'receivedAtEpochMs': 1785402000000,
        'sharedText': 'saved https://example.com/post',
        'discoveredUrl': 'https://example.com/post',
        'mimeType': 'text/plain',
        'wasTruncated': true,
        'originalLength': 120000,
      });

      expect(share.id, 'share-1');
      expect(share.discoveredUrl, 'https://example.com/post');
      expect(share.wasTruncated, isTrue);
      expect(share.originalLength, 120000);
    });

    test('rejects a malformed platform payload', () {
      expect(
        () => IncomingShare.fromPlatformMap({
          'receivedAtEpochMs': 1785402000000,
          'sharedText': 'missing id',
        }),
        throwsFormatException,
      );
    });

    test('decodes a validated private image attachment payload', () {
      final share = IncomingShare.fromPlatformMap({
        'id': 'share-image-1',
        'receivedAtEpochMs': 1785402000000,
        'sharedText': '',
        'discoveredUrl': null,
        'mimeType': 'image/jpeg',
        'shareKind': 'image',
        'attachments': [
          {
            'id': 'attachment-1',
            'filePath': '/private/app/incoming_share_attachments/a.jpg',
            'mimeType': 'image/jpeg',
            'byteSize': 1200,
            'width': 1080,
            'height': 1920,
            'sha256': List.filled(64, 'a').join(),
          },
        ],
      });

      expect(share.shareKind, ShareKind.image);
      expect(share.attachments.single.mimeType, 'image/jpeg');
      expect(share.attachments.single.width, 1080);
    });
  });

  test('normalizes product identity only for grouping keys', () {
    const identity = ConfirmedProductIdentity(
      brand: '바움 랩',
      name: '포어-밸런스 세럼',
      category: '세럼',
      amount: '30 mL',
    );

    expect(identity.identityKey, '바움랩|포어밸런스세럼|세럼|30ml');
    expect(identity.name, '포어-밸런스 세럼');
  });
}
