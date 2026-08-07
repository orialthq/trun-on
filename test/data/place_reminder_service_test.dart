import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/place_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.orialthq.ori_beauty/place_reminders/v1');
  const service = PlaceReminderService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns map choices in product priority order', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getMapProviders');
          return <Object?>[
            <Object?, Object?>{
              'id': 'google',
              'appInstalled': true,
              'available': true,
            },
            <Object?, Object?>{
              'id': 'naver',
              'appInstalled': false,
              'available': true,
            },
          ];
        });

    final options = await service.getMapProviderOptions();

    expect(options.map((option) => option.provider), <MapProvider>[
      MapProvider.naver,
      MapProvider.kakao,
      MapProvider.google,
    ]);
    expect(options[0].destinationLabel, '웹으로 열기');
    expect(options[1].available, isFalse);
    expect(options[2].destinationLabel, '앱으로 열기');
  });

  test('opens the selected provider with the name and district', () async {
    MethodCall? recordedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          recordedCall = call;
          return <Object?, Object?>{'provider': 'kakao', 'openedInApp': true};
        });

    final result = await service.openMapWithProvider(
      provider: MapProvider.kakao,
      name: '동묘집',
      address: '서울 종로구 종로52길 43-9',
    );

    expect(recordedCall?.method, 'openMapProvider');
    expect(recordedCall?.arguments, <String, Object?>{
      'provider': 'kakao',
      'query': '동묘집 종로',
      'name': '동묘집',
      'address': '서울 종로구 종로52길 43-9',
    });
    expect(result.provider, MapProvider.kakao);
    expect(result.openedInApp, isTrue);
  });

  test('drops the street line from the in-app map query', () async {
    MethodCall? recordedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          recordedCall = call;
          return <Object?, Object?>{'provider': 'naver', 'openedInApp': true};
        });

    await service.openMapWithProvider(
      provider: MapProvider.naver,
      name: '화석',
      address: '화석 서울 서초구 강남대로 123 1층',
    );

    expect(recordedCall?.arguments, <String, Object?>{
      'provider': 'naver',
      'query': '화석 서초',
      'name': '화석',
      'address': '화석 서울 서초구 강남대로 123 1층',
    });
  });

  test('searches the address alone when asked to', () async {
    MethodCall? recordedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          recordedCall = call;
          return <Object?, Object?>{'provider': 'naver', 'openedInApp': true};
        });

    await service.openMapWithProvider(
      provider: MapProvider.naver,
      name: '화석',
      address: '화석 서울 서초구 강남대로 123 1층',
      mode: MapQueryMode.address,
    );

    expect(
      (recordedCall?.arguments as Map<Object?, Object?>)['query'],
      '서울 서초구 강남대로 123',
    );
  });

  test(
    'reduces a detailed address to the neighbourhood it implies',
    () async {
      MethodCall? recordedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            recordedCall = call;
            return <Object?, Object?>{
              'provider': 'naver',
              'openedInApp': false,
            };
          });

      await service.openMapWithProvider(
        provider: MapProvider.naver,
        name: '동묘집',
        address: '서울 종로구 종로52길 43-9 (창신동) 지하 1층 101호',
      );

      expect(
        (recordedCall?.arguments as Map<Object?, Object?>)['query'],
        '동묘집 창신',
      );
    },
  );

  test(
    'uses the place name for Naver only when the address is blank',
    () async {
      MethodCall? recordedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            recordedCall = call;
            return <Object?, Object?>{'provider': 'naver', 'openedInApp': true};
          });

      await service.openMapWithProvider(
        provider: MapProvider.naver,
        name: '화석',
        address: '  ',
      );

      expect((recordedCall?.arguments as Map<Object?, Object?>)['query'], '화석');
    },
  );

  test('uses the same name-and-district query for every provider', () async {
    final queries = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map<Object?, Object?>;
          queries.add(arguments['query']! as String);
          return <Object?, Object?>{
            'provider': arguments['provider'],
            'openedInApp': true,
          };
        });

    for (final provider in [MapProvider.kakao, MapProvider.google]) {
      await service.openMapWithProvider(
        provider: provider,
        name: '화석',
        address: '화석 서울 서초구 강남대로 123 1층',
      );
    }

    expect(queries, <String>['화석 서초', '화석 서초']);
  });

  test('rejects a blank map query before calling the platform', () async {
    expect(
      () => service.openMapWithProvider(
        provider: MapProvider.naver,
        name: ' ',
        address: ' ',
      ),
      throwsArgumentError,
    );
  });
}
