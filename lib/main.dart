import 'package:flutter/widgets.dart';

import 'app/ori_beauty_app.dart';
import 'data/incoming_share_service.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(MethodChannelIncomingShareService());

  runApp(OriBeautyApp(controller: controller));
  controller.initialize();
}
