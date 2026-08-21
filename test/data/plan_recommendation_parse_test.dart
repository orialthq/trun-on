import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/plan_recommendation_service.dart';

/// Answers every request with [body].
///
/// A real socket rather than an injected client: the parse is private and the
/// service reaches for `HttpClient` itself, so the only way in is the way the
/// app comes in. Kept out of any file with a widget test, where the binding
/// answers 400 to everything and no request leaves.
Future<HttpServer> _serving(Map<String, Object?> body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await request.drain<void>();
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  });
  return server;
}

void main() {
  test('every to-do comes back knowing the group it arrived in', () async {
    // The group is stamped while the response is read. Nothing downstream puts
    // it back: what reaches a plan is a flat list of to-dos.
    final server = await _serving(<String, Object?>{
      'status': 'ready',
      'todoCount': 3,
      'attachedCount': 0,
      'groups': <Object?>[
        <String, Object?>{
          'title': '짐 정리',
          'note': '버릴 것부터',
          'items': <Object?>[
            <String, Object?>{
              'title': '안 쓰는 것 골라내기',
              'action': '정리',
              'daysBefore': 14,
            },
            <String, Object?>{
              'title': '박스 사두기',
              'action': '구매',
              'daysBefore': 10,
            },
          ],
        },
        <String, Object?>{
          'title': '주소 옮기기',
          'note': '',
          'items': <Object?>[
            <String, Object?>{'title': '전입신고', 'action': '준비', 'daysBefore': 0},
          ],
        },
      ],
    });
    addTearDown(() => server.close(force: true));

    final result = await RemotePlanRecommendationService(
      baseUrl: 'http://${server.address.host}:${server.port}',
    ).recommend(planTitle: '이사', candidates: const []);

    expect(result.status, PlanRecommendationStatus.ready);
    expect(result.allItems.map((item) => item.group), <String>[
      '짐 정리',
      '짐 정리',
      '주소 옮기기',
    ]);
    // The order the groups came in is the order the flat list keeps, which is
    // what lets a page rebuild the headers by watching the name change.
    expect(result.allItems.map((item) => item.title), <String>[
      '안 쓰는 것 골라내기',
      '박스 사두기',
      '전입신고',
    ]);
  });

  test('a group with no name of its own still names its to-dos', () async {
    final server = await _serving(<String, Object?>{
      'status': 'ready',
      'todoCount': 1,
      'attachedCount': 0,
      'groups': <Object?>[
        <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'title': '전입신고', 'action': '준비'},
          ],
        },
      ],
    });
    addTearDown(() => server.close(force: true));

    final result = await RemotePlanRecommendationService(
      baseUrl: 'http://${server.address.host}:${server.port}',
    ).recommend(planTitle: '이사', candidates: const []);

    expect(result.allItems.single.group, '할 일');
  });
}
