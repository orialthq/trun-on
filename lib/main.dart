import 'package:flutter/widgets.dart';

import 'app/ori_beauty_app.dart';
import 'data/app_snapshot_store.dart';
import 'data/incoming_share_service.dart';
import 'data/portable_tip_service.dart';
import 'data/place_enrichment_service.dart';
import 'data/remote_content_analysis_service.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    MethodChannelIncomingShareService(),
    const RemoteContentAnalysisService(),
    const MethodChannelAppSnapshotStore(),
    MethodChannelPortableTipInbox(),
    const RemotePlaceEnrichmentService(),
  );

  runApp(OriBeautyApp(controller: controller));
  controller.initialize();
}
