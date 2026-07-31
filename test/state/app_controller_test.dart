import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/data/app_snapshot_store.dart';
import 'package:ori_beauty/data/content_analysis_service.dart';
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

  test('keeps duplicate transport delivery idempotent', () async {
    final before = controller.captures.length;
    final share = IncomingShare(
      id: 'same-transport-id',
      receivedAt: DateTime(2026, 7, 31),
      sharedText: '리프온 카밍 앰플 40ml가 촉촉하다고 했어요.',
      discoveredUrl: null,
    );
    service
      ..add(share)
      ..add(share);

    await controller.initialize();

    expect(controller.captures, hasLength(before + 1));
    expect(
      controller.captures
          .where(
            (capture) => capture.raw.transportEventId == 'same-transport-id',
          )
          .length,
      1,
    );
  });

  test(
    'user confirmation merges another source into an exact product',
    () async {
      final before = controller
          .groupById('group-baumlab-pore-balance')!
          .sourceCount;
      final captureId = controller.addManualInput(
        '바움랩 포어 밸런스 세럼 30ml. 모공이 신경 쓰일 때 가볍다고 소개했어요.',
      );

      await controller.confirmAndOrganize(
        captureId: captureId,
        identity: const ConfirmedProductIdentity(
          brand: '바움랩',
          name: '포어 밸런스 세럼',
          category: '세럼',
          amount: '30mL',
        ),
      );

      expect(
        controller.captureById(captureId)?.status,
        CaptureStatus.organized,
      );
      expect(
        controller.groupById('group-baumlab-pore-balance')?.sourceCount,
        before + 1,
      );
    },
  );

  test(
    'an unresolved native share remains visible and is acknowledged',
    () async {
      service.add(
        IncomingShare(
          id: 'share-unresolved',
          receivedAt: DateTime(2026, 7, 31),
          sharedText: 'https://example.com/unknown',
          discoveredUrl: 'https://example.com/unknown',
        ),
      );
      await controller.initialize();

      final capture = controller.captures.firstWhere(
        (item) => item.raw.transportEventId == 'share-unresolved',
      );
      await controller.keepUnresolved(capture.raw.id);

      expect(controller.captureById(capture.raw.id), isNotNull);
      expect(
        controller.captureById(capture.raw.id)?.review?.resolution,
        ReviewResolution.unresolved,
      );
      expect(await service.drainPending(), isEmpty);
    },
  );

  test('restores a confirmed organization after app restart', () async {
    final snapshotStore = InMemoryAppSnapshotStore();
    final firstService = InMemoryIncomingShareService();
    final firstController = AppController(
      firstService,
      const BaselineContentAnalysisService(),
      snapshotStore,
    );
    await firstController.initialize();
    final captureId = firstController.addManualInput(
      '오로라랩 워터리 선 세럼 50ml. 가볍고 촉촉했어요.',
    );
    await firstController.confirmAndOrganize(
      captureId: captureId,
      identity: const ConfirmedProductIdentity(
        brand: '오로라랩',
        name: '워터리 선 세럼',
        category: '선케어',
        amount: '50mL',
      ),
    );
    firstController.dispose();

    final secondService = InMemoryIncomingShareService();
    final secondController = AppController(
      secondService,
      const BaselineContentAnalysisService(),
      snapshotStore,
    );
    addTearDown(secondController.dispose);
    await secondController.initialize();

    final restored = secondController.captureById(captureId);
    expect(restored?.status, CaptureStatus.organized);
    expect(restored?.review?.confirmedIdentity?.brand, '오로라랩');
    expect(secondController.groupById(restored!.groupId!)?.sourceCount, 1);
  });

  test(
    'acknowledges a reviewed pending share recovered after restart',
    () async {
      final snapshotStore = InMemoryAppSnapshotStore();
      final share = IncomingShare(
        id: 'share-crash-gap',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: '오로라랩 워터리 선 세럼 50ml. 가볍다고 했어요.',
        discoveredUrl: null,
      );
      final firstService = InMemoryIncomingShareService()..add(share);
      final firstController = AppController(
        firstService,
        const BaselineContentAnalysisService(),
        snapshotStore,
      );
      await firstController.initialize();
      final capture = firstController.captures.firstWhere(
        (item) => item.raw.transportEventId == share.id,
      );
      await firstController.confirmAndOrganize(
        captureId: capture.raw.id,
        identity: const ConfirmedProductIdentity(
          brand: '오로라랩',
          name: '워터리 선 세럼',
          category: '선케어',
          amount: '50mL',
        ),
      );
      firstController.dispose();

      final recoveredPendingService = InMemoryIncomingShareService()
        ..add(share);
      final restoredController = AppController(
        recoveredPendingService,
        const BaselineContentAnalysisService(),
        snapshotStore,
      );
      addTearDown(restoredController.dispose);
      await restoredController.initialize();

      expect(await recoveredPendingService.drainPending(), isEmpty);
      expect(
        restoredController.captures.where(
          (item) => item.raw.transportEventId == share.id,
        ),
        hasLength(1),
      );
    },
  );

  test('does not acknowledge a native share when durable save fails', () async {
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = originalDebugPrint);
    final nativeService = InMemoryIncomingShareService();
    final failingController = AppController(
      nativeService,
      const BaselineContentAnalysisService(),
      const _FailingAppSnapshotStore(),
    );
    addTearDown(failingController.dispose);
    nativeService.add(
      IncomingShare(
        id: 'share-save-failure',
        receivedAt: DateTime(2026, 7, 31),
        sharedText: 'https://example.com/still-pending',
        discoveredUrl: 'https://example.com/still-pending',
      ),
    );
    await failingController.initialize();
    final capture = failingController.captures.firstWhere(
      (item) => item.raw.transportEventId == 'share-save-failure',
    );

    await failingController.keepUnresolved(capture.raw.id);

    expect(await nativeService.drainPending(), hasLength(1));
  });
}

final class _FailingAppSnapshotStore implements AppSnapshotStore {
  const _FailingAppSnapshotStore();

  @override
  Future<List<PersistedCapture>> load() async => const [];

  @override
  Future<void> save(List<PersistedCapture> captures) async {
    throw StateError('simulated durable write failure');
  }
}
