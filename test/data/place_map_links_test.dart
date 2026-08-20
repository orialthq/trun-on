import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/place_map_links.dart';

void main() {
  test('builds normalized provider links in Naver Kakao Google order', () {
    final links = PlaceMapLinks.fromPlace(
      name: '  화석  ',
      address: '화석 | 서울  서초구 강남대로 123 1층',
    )!;

    // 서초구 is the broadest locality here, so the street line is dropped.
    expect(links.area, '서초');
    expect(links.searchQuery, '화석 서초');
    expect(links.addressQuery, '서울 서초구 강남대로 123');
    expect(links.naver.host, 'map.naver.com');
    expect(links.kakao.host, 'map.kakao.com');
    expect(links.google.host, 'www.google.com');
    expect(links.google.queryParameters, {'api': '1', 'query': '화석 서초'});

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

    // The in-app search deliberately keeps only the district.
    expect(links.searchQuery, '화석 서초');

    // Shared links carry the same query, so a recipient searches what the
    // sender searched rather than a street line that may be misread.
    expect(links.naverShareUrl, 'https://map.naver.com/p/search/화석%20서초');
    expect(links.kakaoShareUrl, 'https://map.kakao.com/link/search/화석%20서초');
    expect(links.googleShareUrl, 'https://maps.google.com/?q=화석%20서초');
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

  test('keeps an unsearchable district whole in shared links', () {
    final links = PlaceMapLinks.fromPlace(
      name: '토림국밥',
      address: '울산 중구 반구정14길 1 토림국밥',
    )!;

    expect(links.searchQuery, '토림국밥 중구');
    expect(links.naverShareUrl, 'https://map.naver.com/p/search/토림국밥%20중구');
  });

  test('searches the shop name with only the district around it', () {
    // A street line read off a screenshot may be misread or belong to a location
    // tag, so only the district it implies survives into the search.
    final addressed = PlaceMapLinks.fromPlace(
      name: '페스카데리아',
      address: '서울 성동구 성수동2가 연무장길 5 2층',
    )!;

    expect(addressed.area, '성수');
    expect(addressed.searchQuery, '페스카데리아 성수');

    // An SNS area tag already carries nothing but the district.
    final tagged = PlaceMapLinks.fromPlace(name: '페스카데리아', address: '성수동')!;

    expect(tagged.area, '성수');
    expect(tagged.searchQuery, '페스카데리아 성수');
  });

  test(
    'falls back through district and region when no neighbourhood is read',
    () {
      expect(
        PlaceMapLinks.fromPlace(name: '가게', address: '서울 성동구 연무장길 5')?.area,
        '성동',
      );
      expect(PlaceMapLinks.fromPlace(name: '가게', address: '서울특별시')?.area, '서울');
      // A fragment nobody could search for is kept whole instead.
      expect(PlaceMapLinks.fromPlace(name: '가게', address: '울산 중구')?.area, '중구');
    },
  );

  test('prefers the area Luna read over one derived from the address', () {
    // 가로수길 is what a map matches; 신사동 is only the district it sits in.
    final links = PlaceMapLinks.fromPlace(
      name: '커피집',
      address: '서울 강남구 신사동 535-12',
      searchArea: '가로수길',
    )!;

    expect(links.area, '가로수길');
    expect(links.searchQuery, '커피집 가로수길');
    // The address-only escape hatch is untouched by the read area.
    expect(links.addressQuery, '서울 강남구 신사동 535-12');
  });

  test('shares the same query the in-app map opens', () {
    final links = PlaceMapLinks.fromPlace(
      name: '커피집',
      address: '서울 강남구 신사동 535-12',
      searchArea: '가로수길',
    )!;

    expect(links.searchQuery, '커피집 가로수길');
    expect(links.naverShareUrl, 'https://map.naver.com/p/search/커피집%20가로수길');
    expect(links.kakaoShareUrl, 'https://map.kakao.com/link/search/커피집%20가로수길');
    expect(links.googleShareUrl, 'https://maps.google.com/?q=커피집%20가로수길');
    expect(links.shareText.split('\n').first, '📍 커피집');
    expect(links.shareText, isNot(contains('535-12')));
  });

  test('derives an area when Luna read none', () {
    for (final read in <String?>[null, '', '   ']) {
      final links = PlaceMapLinks.fromPlace(
        name: '커피집',
        address: '서울 강남구 신사동 535-12',
        searchArea: read,
      )!;
      expect(links.area, '신사');
      expect(links.searchQuery, '커피집 신사');
    }
  });

  test('searches the name alone when the address carries no locality', () {
    final links = PlaceMapLinks.fromPlace(name: '토림국밥', address: '1층 안쪽')!;

    expect(links.area, '');
    expect(links.searchQuery, '토림국밥');
  });

  test('returns null only when both place fields are blank', () {
    expect(PlaceMapLinks.fromPlace(name: ' ', address: '\n'), isNull);
    expect(
      PlaceMapLinks.fromPlace(name: '동묘집', address: null)?.searchQuery,
      '동묘집',
    );
    expect(
      PlaceMapLinks.fromPlace(name: null, address: '서초구 서초대로73길 38')?.shareText,
      startsWith('📍 지도에서 바로 보기\n'),
    );
  });
}
