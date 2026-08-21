import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/app/ori_beauty_app.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  testWidgets('probe', (tester) async {
    final service = InMemoryIncomingShareService();
    final controller = AppController(service);
    addTearDown(controller.dispose);
    await tester.pumpWidget(OriBeautyApp(controller: controller));
    await controller.initialize();
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('--- icons ---');
    for (final w in tester.widgetList<Icon>(find.byType(Icon))) {
      // ignore: avoid_print
      print('  ${w.icon}');
    }
    // ignore: avoid_print
    print('navbar: ${find.byType(NavigationBar).evaluate().length}');
    // ignore: avoid_print
    print(
      'bookmark_border_rounded: ${find.byIcon(Icons.bookmark_border_rounded).evaluate().length}',
    );
    // ignore: avoid_print
    print(
      'move_to_inbox_outlined: ${find.byIcon(Icons.move_to_inbox_outlined).evaluate().length}',
    );
    // ignore: avoid_print
    print(
      'home_outlined: ${find.byIcon(Icons.home_outlined).evaluate().length}',
    );
    // ignore: avoid_print
    print(
      'codes: bm=${Icons.bookmark_border_rounded.codePoint} mti=${Icons.move_to_inbox_outlined.codePoint} ho=${Icons.home_outlined.codePoint}',
    );
  });
}
