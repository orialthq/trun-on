import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.orialthq.ori_beauty/incoming_share/v1');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('capture picker returns the platform acceptance result', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });
    final service = MethodChannelIncomingShareService();
    addTearDown(service.dispose);

    expect(await service.presentCapturePicker(), isTrue);
    expect(receivedCall?.method, 'presentCapturePicker');
  });

  test('capture picker treats a cancelled platform picker as false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'presentCapturePicker');
          return false;
        });
    final service = MethodChannelIncomingShareService();
    addTearDown(service.dispose);

    expect(await service.presentCapturePicker(), isFalse);
  });
}
