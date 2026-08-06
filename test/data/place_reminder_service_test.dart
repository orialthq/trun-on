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

  test('opens the selected provider with the full place query', () async {
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
      'name': '동묘집',
      'address': '서울 종로구 종로52길 43-9',
    });
    expect(result.provider, MapProvider.kakao);
    expect(result.openedInApp, isTrue);
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
