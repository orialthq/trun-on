import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_snapshot_store.dart';
import '../data/content_analysis_service.dart';
import '../data/demo_catalog.dart';
import '../data/incoming_share_service.dart';
import '../domain/models.dart';

final class AppController extends ChangeNotifier {
  AppController(
    this._incomingShareService, [
    this._contentAnalysisService = const BaselineContentAnalysisService(),
    AppSnapshotStore? snapshotStore,
  ]) : _captures = [...DemoCatalog.captures],
       _groups = [...DemoCatalog.groups],
       _snapshotStore = snapshotStore ?? InMemoryAppSnapshotStore();

  final IncomingShareService _incomingShareService;
  final ContentAnalysisService _contentAnalysisService;
  final AppSnapshotStore _snapshotStore;
  final List<CaptureRecord> _captures;
  final List<ProductGroup> _groups;

  StreamSubscription<void>? _incomingSubscription;
  Future<void> _snapshotWriteTail = Future<void>.value();
  CaptureFilter _filter = CaptureFilter.all;
  bool _initialized = false;

  List<CaptureRecord> get captures => List.unmodifiable(_captures);
  List<ProductGroup> get groups => List.unmodifiable(_groups);
  CaptureFilter get filter => _filter;

  List<CaptureRecord> get filteredCaptures {
    return _captures
        .where((capture) {
          return switch (_filter) {
            CaptureFilter.all => true,
            CaptureFilter.needsReview =>
              capture.status == CaptureStatus.needsReview,
            CaptureFilter.organized =>
              capture.status == CaptureStatus.organized,
            CaptureFilter.limitedOrFailed =>
              capture.status == CaptureStatus.sourceLimited ||
                  capture.status == CaptureStatus.failed,
          };
        })
        .toList(growable: false);
  }

  int get needsReviewCount => _captures
      .where((capture) => capture.status == CaptureStatus.needsReview)
      .length;

  int get organizedCount => _captures
      .where((capture) => capture.status == CaptureStatus.organized)
      .length;

  int get limitedOrFailedCount => _captures
      .where(
        (capture) =>
            capture.status == CaptureStatus.sourceLimited ||
            capture.status == CaptureStatus.failed,
      )
      .length;

  CaptureRecord? captureById(String id) {
    for (final capture in _captures) {
      if (capture.raw.id == id) {
        return capture;
      }
    }
    return null;
  }

  ProductGroup? groupById(String id) {
    for (final group in _groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  List<CaptureRecord> capturesForGroup(String groupId) {
    return _captures
        .where((capture) => capture.groupId == groupId)
        .toList(growable: false);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _restoreSnapshot();
    _incomingSubscription = _incomingShareService.pendingChanged.listen((_) {
      unawaited(_drainIncomingShares());
    });
    await _drainIncomingShares();
  }

  Future<void> _drainIncomingShares() async {
    try {
      final shares = await _incomingShareService.drainPending();
      final knownTransportIds = _captures
          .map((capture) => capture.raw.transportEventId)
          .toSet();
      final safeToAcknowledge = <String>[];
      var changed = false;
      for (final share in shares) {
        if (knownTransportIds.contains(share.id)) {
          final persistedCapture = _captureByTransportId(share.id);
          if (persistedCapture?.raw.origin == CaptureOrigin.androidShare &&
              persistedCapture?.review != null) {
            safeToAcknowledge.add(share.id);
          }
          continue;
        }
        _captures.insert(0, _contentAnalysisService.analyzeShare(share));
        knownTransportIds.add(share.id);
        changed = true;
      }
      if (changed) {
        await _persistState();
        notifyListeners();
      }
      if (safeToAcknowledge.isNotEmpty) {
        await _incomingShareService.acknowledge(safeToAcknowledge);
      }
    } catch (error, stackTrace) {
      debugPrint('Incoming share drain failed: $error\n$stackTrace');
    }
  }

  CaptureRecord? _captureByTransportId(String transportEventId) {
    for (final capture in _captures) {
      if (capture.raw.transportEventId == transportEventId) {
        return capture;
      }
    }
    return null;
  }

  void setFilter(CaptureFilter value) {
    if (_filter == value) {
      return;
    }
    _filter = value;
    notifyListeners();
  }

  String addManualInput(String text) {
    final now = DateTime.now();
    final share = IncomingShare(
      id: 'manual-${now.microsecondsSinceEpoch}',
      receivedAt: now,
      sharedText: text,
      discoveredUrl: IncomingShare.extractFirstUrl(text),
      sourcePackage: 'manual',
    );
    final capture = _contentAnalysisService.analyzeShare(
      share,
      origin: CaptureOrigin.manual,
    );
    _captures.insert(0, capture);
    unawaited(_persistState());
    notifyListeners();
    return capture.raw.id;
  }

  void addDemoInput() {
    addManualInput(
      '데이라이트 에어리 선 플루이드 50ml. 백탁이 적고 가볍게 '
      '발린다고 소개했어요. #제품제공 '
      'https://instagram.com/reel/new-daylight?utm_source=share',
    );
  }

  Future<void> confirmAndOrganize({
    required String captureId,
    required ConfirmedProductIdentity identity,
  }) async {
    final captureIndex = _captures.indexWhere(
      (capture) => capture.raw.id == captureId,
    );
    if (captureIndex == -1) {
      return;
    }
    final capture = _captures[captureIndex];
    final analysis = capture.analysis;
    if (analysis == null) {
      return;
    }

    final candidate = capture.primaryMention;
    final corrected =
        candidate?.brand.value?.trim() != identity.brand.trim() ||
        candidate?.name.value?.trim() != identity.name.trim() ||
        (candidate?.category.value ?? '').trim() != identity.category.trim() ||
        (candidate?.amount.value ?? '').trim() != identity.amount.trim();
    final review = UserReview(
      id: 'review-${capture.raw.id}-${DateTime.now().microsecondsSinceEpoch}',
      captureId: capture.raw.id,
      analysisRunId: analysis.id,
      resolution: corrected
          ? ReviewResolution.corrected
          : ReviewResolution.confirmed,
      reviewedAt: DateTime.now(),
      candidateId: candidate?.id,
      confirmedIdentity: identity,
    );

    final hasCompleteIdentity =
        identity.brand.isNotEmpty &&
        identity.name.isNotEmpty &&
        identity.category.isNotEmpty &&
        identity.amount.isNotEmpty;
    final existingGroupIndex = hasCompleteIdentity
        ? _groups.indexWhere(
            (group) => group.identity.identityKey == identity.identityKey,
          )
        : -1;
    late final String groupId;
    if (existingGroupIndex == -1) {
      final groupKey = hasCompleteIdentity
          ? identity.identityKey
          : '${identity.identityKey}|${capture.raw.id}';
      groupId =
          'group-${BaselineContentAnalysisService.semanticFingerprint(groupKey)}';
      _groups.insert(
        0,
        ProductGroup(
          id: groupId,
          identity: identity,
          sourceCaptureIds: [capture.raw.id],
          statements: analysis.statements,
          updatedAt: DateTime.now(),
          colorValue: _colorForGroup(_groups.length),
        ),
      );
    } else {
      final existing = _groups[existingGroupIndex];
      groupId = existing.id;
      _groups[existingGroupIndex] = existing.addSource(
        captureId: capture.raw.id,
        sourceStatements: analysis.statements,
        at: DateTime.now(),
      );
    }

    _captures[captureIndex] = capture.copyWith(
      status: CaptureStatus.organized,
      review: review,
      groupId: groupId,
    );
    notifyListeners();

    final saved = await _persistState();
    if (saved && capture.raw.origin == CaptureOrigin.androidShare) {
      await _incomingShareService.acknowledge([capture.raw.transportEventId]);
    }
  }

  Future<void> keepUnresolved(String captureId) async {
    final captureIndex = _captures.indexWhere(
      (capture) => capture.raw.id == captureId,
    );
    if (captureIndex == -1) {
      return;
    }
    final capture = _captures[captureIndex];
    final analysis = capture.analysis;
    if (analysis == null) {
      return;
    }

    _captures[captureIndex] = capture.copyWith(
      status: CaptureStatus.needsReview,
      review: UserReview(
        id: 'review-${capture.raw.id}-${DateTime.now().microsecondsSinceEpoch}',
        captureId: capture.raw.id,
        analysisRunId: analysis.id,
        resolution: ReviewResolution.unresolved,
        reviewedAt: DateTime.now(),
        candidateId: capture.primaryMention?.id,
      ),
    );
    notifyListeners();

    final saved = await _persistState();
    if (saved && capture.raw.origin == CaptureOrigin.androidShare) {
      await _incomingShareService.acknowledge([capture.raw.transportEventId]);
    }
  }

  void retryAnalysis(String captureId) {
    final index = _captures.indexWhere(
      (capture) => capture.raw.id == captureId,
    );
    if (index == -1) {
      return;
    }
    final capture = _captures[index];
    final reanalyzed = _contentAnalysisService.analyzeShare(
      IncomingShare(
        id: capture.raw.transportEventId,
        receivedAt: capture.raw.receivedAt,
        sharedText: capture.raw.rawText,
        discoveredUrl: capture.raw.rawUrl,
        sourcePackage: capture.raw.sourcePackage,
        mimeType: capture.raw.mimeType,
        wasTruncated: capture.raw.wasTruncated,
        originalLength: capture.raw.originalLength,
      ),
      origin: capture.raw.origin,
    );
    _captures[index] = reanalyzed;
    unawaited(_persistState());
    notifyListeners();
  }

  Future<void> _restoreSnapshot() async {
    try {
      final persistedCaptures = await _snapshotStore.load();
      final knownTransportIds = _captures
          .map((capture) => capture.raw.transportEventId)
          .toSet();
      final restored = <CaptureRecord>[];
      for (final persisted in persistedCaptures) {
        if (!knownTransportIds.add(persisted.transportEventId)) {
          continue;
        }
        final analyzed = _contentAnalysisService.analyzeShare(
          persisted.toIncomingShare(),
          origin: persisted.origin,
        );
        final reviewResolution = persisted.reviewResolution;
        final identity = persisted.confirmedIdentity;
        final groupId = persisted.groupId;
        if (persisted.status == CaptureStatus.organized &&
            identity != null &&
            groupId != null) {
          final organized = analyzed.copyWith(
            status: CaptureStatus.organized,
            groupId: groupId,
            review: _restoredReview(
              persisted: persisted,
              analyzed: analyzed,
              resolution: reviewResolution ?? ReviewResolution.confirmed,
              identity: identity,
            ),
          );
          _restoreGroup(organized, identity, groupId);
          restored.add(organized);
          continue;
        }
        if (reviewResolution != null) {
          restored.add(
            analyzed.copyWith(
              status: persisted.status == CaptureStatus.organized
                  ? CaptureStatus.needsReview
                  : persisted.status,
              review: _restoredReview(
                persisted: persisted,
                analyzed: analyzed,
                resolution: reviewResolution,
                identity: identity,
              ),
            ),
          );
          continue;
        }
        restored.add(analyzed);
      }
      if (restored.isNotEmpty) {
        _captures.insertAll(0, restored);
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint('App snapshot restore failed: $error\n$stackTrace');
    }
  }

  UserReview _restoredReview({
    required PersistedCapture persisted,
    required CaptureRecord analyzed,
    required ReviewResolution resolution,
    required ConfirmedProductIdentity? identity,
  }) {
    return UserReview(
      id: persisted.reviewId ?? 'review-${analyzed.raw.id}-restored',
      captureId: analyzed.raw.id,
      analysisRunId: analyzed.analysis!.id,
      resolution: resolution,
      reviewedAt: persisted.reviewedAt ?? persisted.receivedAt,
      candidateId: analyzed.primaryMention?.id,
      confirmedIdentity: identity,
    );
  }

  void _restoreGroup(
    CaptureRecord capture,
    ConfirmedProductIdentity identity,
    String groupId,
  ) {
    final existingIndex = _groups.indexWhere((group) => group.id == groupId);
    if (existingIndex == -1) {
      _groups.insert(
        0,
        ProductGroup(
          id: groupId,
          identity: identity,
          sourceCaptureIds: [capture.raw.id],
          statements: [...?capture.analysis?.statements],
          updatedAt: capture.review?.reviewedAt ?? capture.raw.receivedAt,
          colorValue: _colorForGroup(_groups.length),
        ),
      );
      return;
    }
    _groups[existingIndex] = _groups[existingIndex].addSource(
      captureId: capture.raw.id,
      sourceStatements: [...?capture.analysis?.statements],
      at: capture.review?.reviewedAt ?? capture.raw.receivedAt,
    );
  }

  Future<bool> _persistState() async {
    final persisted = _captures
        .where((capture) => capture.raw.origin != CaptureOrigin.demo)
        .map(
          (capture) => PersistedCapture.fromRecord(
            capture,
            capture.groupId == null ? null : groupById(capture.groupId!),
          ),
        )
        .toList(growable: false);
    var saved = false;
    _snapshotWriteTail = _snapshotWriteTail.then((_) async {
      try {
        await _snapshotStore.save(persisted);
        saved = true;
      } catch (error, stackTrace) {
        debugPrint('App snapshot save failed: $error\n$stackTrace');
      }
    });
    await _snapshotWriteTail;
    return saved;
  }

  static int _colorForGroup(int index) {
    const colors = [0xFFB89CD9, 0xFF8FC6A8, 0xFF89B9D5, 0xFFF0C978, 0xFFE49B8B];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    unawaited(_incomingSubscription?.cancel());
    unawaited(_incomingShareService.dispose());
    super.dispose();
  }
}
