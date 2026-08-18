import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/place_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/place-reminder-open');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'drains and acknowledges durable native notification destinations',
    () async {
      MethodCall? acknowledgement;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'pendingPlaceReminderOpens') {
              return <Object?>['capture-1', 'capture-2'];
            }
            acknowledgement = call;
            return null;
          });
      final inbox = MethodChannelPlaceReminderOpenInbox(channel: channel);

      expect(await inbox.pending(), ['capture-1', 'capture-2']);
      await inbox.acknowledge(['capture-1']);

      expect(acknowledgement?.method, 'acknowledgePlaceReminderOpens');
      expect(acknowledgement?.arguments, {
        'ids': ['capture-1'],
      });
      await inbox.close();
    },
  );
}
