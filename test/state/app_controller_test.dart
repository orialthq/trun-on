import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/incoming_share_service.dart';
import 'package:ori_beauty/domain/models.dart';
import 'package:ori_beauty/state/app_controller.dart';

void main() {
  late InMemoryIncomingShareService service;
  late AppController controller;

  setUp(() {
    service = InMemoryIncomingShareService();
    controller = AppController(service);
  });

  tearDown(() {
    controller.dispose();
  });

  test('limits comparison to three products', () {
    expect(controller.comparedProducts, hasLength(3));

    final accepted = controller.toggleComparison('daylight-sun-fluid');

    expect(accepted, isFalse);
    expect(controller.comparedProducts, hasLength(3));
  });

  test('records and changes a purchase decision', () {
    controller.setDecision('slowbreeze-hydra', Decision.candidate);
    expect(
      controller.productById('slowbreeze-hydra')?.decision,
      Decision.candidate,
    );

    controller.setDecision('slowbreeze-hydra', Decision.excluded);
    expect(
      controller.productById('slowbreeze-hydra')?.decision,
      Decision.excluded,
    );
  });

  test(
    'drains a share, confirms it, and acknowledges native storage',
    () async {
      service.add(
        IncomingShare(
          id: 'share-1',
          receivedAt: DateTime(2026, 7, 30),
          sharedText: 'https://example.com/reel',
          discoveredUrl: 'https://example.com/reel',
        ),
      );

      await controller.initialize();
      expect(controller.pendingShare?.id, 'share-1');

      await controller.confirmPendingShare();

      expect(controller.pendingShare, isNull);
      expect(await service.drainPending(), isEmpty);
      expect(
        controller.productById('daylight-sun-fluid')?.analysisStatus,
        AnalysisStatus.ready,
      );
    },
  );
}
