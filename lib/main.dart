import 'package:flutter/widgets.dart';

import 'app/ori_beauty_app.dart';
import 'data/app_snapshot_store.dart';
import 'data/incoming_share_service.dart';
import 'data/portable_tip_service.dart';
import 'data/place_enrichment_service.dart';
import 'data/remote_content_analysis_service.dart';
import 'data/trigger_plan_store.dart';
import 'data/trigger_scheduler.dart';
import 'state/app_controller.dart';
import 'state/plan_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    MethodChannelIncomingShareService(),
    const RemoteContentAnalysisService(),
    const MethodChannelAppSnapshotStore(),
    MethodChannelPortableTipInbox(),
    const RemotePlaceEnrichmentService(),
  );
  final planController = PlanController(
    store: const MethodChannelTriggerPlanStore(),
    scheduler: MethodChannelTriggerScheduler(),
  );

  runApp(
    OriBeautyApp(
      controller: controller,
      planController: planController,
    ),
  );
  controller.initialize();
  planController.initialize();
}
