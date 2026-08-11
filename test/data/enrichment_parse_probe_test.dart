import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/place_enrichment_service.dart';
import 'package:ori_beauty/domain/models.dart';

/// Feeds a verbatim server reply through the client parser.
///
/// The two ends of this contract live in different languages, so a field the
/// server renamed shows up here as a silently empty axis rather than a failure.
/// This test is the tripwire for that.
const _serverReply = r'''
{
  "place": {
    "fid": "0x357ca3110d881915:0x66c78cca87fb7bda",
    "name": "금돼지식당",
    "address": "대한민국 서울특별시 중구 다산로 149",
    "latitude": 37.55712,
    "longitude": 127.011665,
    "category": "한국식 BBQ",
    "priceLevel": "₩20,000~60,000",
    "openingHours": {"월요일": "11:30~23:00"},
    "bookingLinks": ["https://app.catchtable.co.kr/ct/shop/Goldpig"],
    "fetchedAt": 1765000000000
  },
  "filters": {
    "가격대": "2~5만원",
    "웨이팅": "상시 웨이팅",
    "주차": null
  },
  "tips": [
    {
      "topic": "현장대기",
      "quote": "웨이팅은 현장에서 폰 번호 입력하면 캐치테이블 앱을 통해 웨이팅 등록이 됩니다.",
      "saidAt": "2026-07-01T00:00:00.000Z",
      "count": 2
    }
  ],
  "fromStore": false
}
''';

const _missReply = r'''
{"place": null, "reason": "ambiguous"}
''';

void main() {
  Future<RemotePlaceEnrichmentService> serve(String reply) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain();
      request.response.headers.contentType = ContentType.json;
      request.response.write(reply);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    return RemotePlaceEnrichmentService(
      baseUrl: 'http://127.0.0.1:${server.port}',
    );
  }

  test('a verbatim server reply survives the client parser', () async {
    final service = await serve(_serverReply);
    final axes = await service.enrich(name: '금돼지식당', searchArea: '신당');

    expect(axes[ContentAxis.price].single.value, '2~5만원');
    expect(axes[ContentAxis.waiting].single.value, '상시 웨이팅');
    // A null filter is an honest absence, not a label.
    expect(axes[ContentAxis.parking], isEmpty);
    expect(axes[ContentAxis.price].single.source, AxisLabelSource.web);
  });

  test('a lookup the server refused to pin attaches nothing', () async {
    final service = await serve(_missReply);
    final axes = await service.enrich(name: '어니언', searchArea: '');
    expect(axes.isEmpty, isTrue);
  });
}
