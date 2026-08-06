import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/place_map_links.dart';

void main() {
  test('builds normalized provider links in Naver Kakao Google order', () {
    final links = PlaceMapLinks.fromPlace(
      name: '  화석  ',
      address: '화석 | 서울  서초구 강남대로 123 1층',
    )!;

    expect(links.naverQuery, '서울 서초구 강남대로 123');
    expect(links.combinedQuery, '화석 서울 서초구 강남대로 123 1층');
    expect(links.naver.host, 'map.naver.com');
    expect(links.kakao.host, 'map.kakao.com');
    expect(links.google.host, 'www.google.com');
    expect(links.google.queryParameters, {
      'api': '1',
      'query': '화석 서울 서초구 강남대로 123 1층',
    });

    final text = links.shareText;
    expect(text, startsWith('📍 화석\n'));
    expect(
      text.indexOf('네이버 https://'),
      lessThan(text.indexOf('카카오 https://')),
    );
    expect(text.indexOf('카카오 https://'), lessThan(text.indexOf('구글 https://')));
    expect(RegExp(r'https://').allMatches(text), hasLength(3));
    expect(text.split('\n'), hasLength(4));
  });

  test('shares compact readable links without leaking a place-name prefix', () {
    final links = PlaceMapLinks.fromPlace(
      name: '화석',
      address: '화석 서울 서초구 서초대로73길 38 1층',
    )!;

    // Provider queries used inside Trun On retain their existing precision.
    expect(links.naverQuery, '서울 서초구 서초대로73길 38');
    expect(links.combinedQuery, '화석 서울 서초구 서초대로73길 38 1층');

    expect(links.shareQuery, '서초구 서초대로73길 38');
    expect(
      links.naverShareUrl,
      'https://map.naver.com/p/search/서초구%20서초대로73길%2038',
    );
    expect(
      links.kakaoShareUrl,
      'https://map.kakao.com/link/search/서초구%20서초대로73길%2038',
    );
    expect(
      links.googleShareUrl,
      'https://maps.google.com/?q=서초구%20서초대로73길%2038',
    );
    expect(links.shareText, isNot(contains('%EC')));
    expect(links.shareText.split('\n').first, '📍 화석');
    expect(links.shareText, isNot(contains('1층')));
    expect(links.shareText.split('\n'), hasLength(4));
    for (final url in <String>[
      links.naverShareUrl,
      links.kakaoShareUrl,
      links.googleShareUrl,
    ]) {
      expect(Uri.parse(url).scheme, 'https');
      expect(url, isNot(contains(' ')));
    }
  });

  test('keeps a top-level region for ambiguous district names', () {
    final links = PlaceMapLinks.fromPlace(
      name: '토림국밥',
      address: '울산 중구 반구정14길 1 토림국밥',
    )!;

    expect(links.shareQuery, '울산 중구 반구정14길 1');
  });

  test('returns null only when both place fields are blank', () {
    expect(PlaceMapLinks.fromPlace(name: ' ', address: '\n'), isNull);
    expect(
      PlaceMapLinks.fromPlace(name: '동묘집', address: null)?.naverQuery,
      '동묘집',
    );
    expect(
      PlaceMapLinks.fromPlace(name: null, address: '서초구 서초대로73길 38')?.shareText,
      startsWith('📍 지도에서 바로 보기\n'),
    );
  });
}
