import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/app_snapshot_store.dart';
import '../data/content_analysis_service.dart';
import '../data/demo_catalog.dart';
import '../data/incoming_share_service.dart';
import '../data/remote_content_analysis_service.dart';
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
  final Set<String> _durablySavedTransportIds = {};
  final Set<String> _sourceDeletionAvailableCaptureIds = {};
  final StreamController<String> _incomingCaptureController =
      StreamController<String>.broadcast();

  StreamSubscription<void>? _incomingSubscription;
  Future<void> _snapshotWriteTail = Future<void>.value();
  Future<void> _incomingDrainTail = Future<void>.value();
  CaptureFilter _filter = CaptureFilter.all;
  bool _initialized = false;

  List<CaptureRecord> get captures => List.unmodifiable(_captures);
  List<ProductGroup> get groups => List.unmodifiable(_groups);
  CaptureFilter get filter => _filter;
  Stream<String> get incomingCaptureAdded => _incomingCaptureController.stream;

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

  int get analyzingCount => _captures
      .where((capture) => capture.status == CaptureStatus.analyzing)
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

  bool canDeleteSharedSource(String captureId) =>
      _sourceDeletionAvailableCaptureIds.contains(captureId);

  Future<SharedSourceDeletionResult> deleteSharedSource(
    String captureId,
  ) async {
    final capture = captureById(captureId);
    if (capture == null || !canDeleteSharedSource(captureId)) {
      return SharedSourceDeletionResult.unavailable;
    }
    final result = await _incomingShareService.deleteSharedSource(
      capture.raw.transportEventId,
    );
    _sourceDeletionAvailableCaptureIds.remove(captureId);
    return result;
  }

  Future<void> keepSharedSource(String captureId) async {
    final capture = captureById(captureId);
    if (capture == null) {
      return;
    }
    _sourceDeletionAvailableCaptureIds.remove(captureId);
    await _incomingShareService.keepSharedSource(capture.raw.transportEventId);
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

  List<CaptureRecord> get organizedStructuredCaptures => _captures
      .where(
        (capture) =>
            capture.status == CaptureStatus.organized &&
            capture.analysis?.structuredContent != null,
      )
      .toList(growable: false);

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

  Future<void> _drainIncomingShares() {
    final operation = _incomingDrainTail.then(
      (_) => _drainIncomingSharesOnce(),
    );
    _incomingDrainTail = operation;
    return operation;
  }

  Future<void> _drainIncomingSharesOnce() async {
    try {
      final shares = await _incomingShareService.drainPending();
      final knownTransportIds = _captures
          .map((capture) => capture.raw.transportEventId)
          .toSet();
      final safeToAcknowledge = <String>{};
      final pendingAnalysisIds = <String>[];
      final importedCaptureIds = <String>[];
      final sourceDeletionCandidateIds = <String>[];
      var changed = false;
      for (final share in shares) {
        if (knownTransportIds.contains(share.id)) {
          if (_durablySavedTransportIds.contains(share.id)) {
            safeToAcknowledge.add(share.id);
          }
          continue;
        }
        var capture = share.attachments.isEmpty
            ? _contentAnalysisService.analyzeShare(share)
            : _contentAnalysisService.prepareShare(share);
        capture = await _retainAttachments(capture);
        _captures.insert(0, capture);
        importedCaptureIds.add(capture.raw.id);
        if (share.sourceDeletionAvailable) {
          sourceDeletionCandidateIds.add(capture.raw.id);
        }
        if (capture.status == CaptureStatus.analyzing) {
          pendingAnalysisIds.add(capture.raw.id);
        }
        knownTransportIds.add(share.id);
        changed = true;
      }
      if (changed) {
        _filter = CaptureFilter.all;
        final saved = await _persistState();
        if (saved) {
          _sourceDeletionAvailableCaptureIds.addAll(sourceDeletionCandidateIds);
          safeToAcknowledge.addAll(
            shares
                .where((share) => _durablySavedTransportIds.contains(share.id))
                .map((share) => share.id),
          );
        } else {
          for (final captureId in sourceDeletionCandidateIds) {
            final capture = captureById(captureId);
            if (capture != null) {
              await _incomingShareService.keepSharedSource(
                capture.raw.transportEventId,
              );
            }
          }
        }
        notifyListeners();
        for (final captureId in importedCaptureIds) {
          _incomingCaptureController.add(captureId);
        }
      }
      if (safeToAcknowledge.isNotEmpty) {
        await _incomingShareService.acknowledge(safeToAcknowledge);
      }
      for (final captureId in pendingAnalysisIds) {
        await _analyzeCapture(captureId);
      }
    } catch (error, stackTrace) {
      debugPrint('Incoming share drain failed: $error\n$stackTrace');
    }
  }

  Future<void> _analyzeCapture(String captureId) async {
    final initial = captureById(captureId);
    if (initial == null || initial.status != CaptureStatus.analyzing) {
      return;
    }
    try {
      final analysis = await _contentAnalysisService.analyze(initial);
      final index = _captures.indexWhere(
        (capture) => capture.raw.id == captureId,
      );
      if (index == -1) {
        return;
      }
      final current = _captures[index];
      _captures[index] = current.copyWith(
        status: _statusForCompletedAnalysis(current, analysis),
        analysis: analysis,
      );
    } catch (error) {
      final index = _captures.indexWhere(
        (capture) => capture.raw.id == captureId,
      );
      if (index == -1) {
        return;
      }
      final current = _captures[index];
      final code = error is AnalysisServiceException
          ? error.code
          : 'analysis_failed';
      _captures[index] = current.copyWith(
        status: CaptureStatus.failed,
        analysis: AnalysisRun(
          id: 'analysis-${current.raw.transportEventId}-failed',
          inputId: current.raw.id,
          normalizerVersion: current.normalized.normalizerVersion,
          analyzerVersion: 'remote-analysis-v1',
          status: AnalysisRunStatus.failed,
          completedAt: DateTime.now(),
          evidence: const [],
          productMentions: const [],
          statements: const [],
          disclosure: DisclosureObservation.unknown,
          failureCode: code,
        ),
      );
      debugPrint('Content analysis failed with code: $code');
    }
    await _persistState();
    notifyListeners();
  }

  static CaptureStatus _statusForCompletedAnalysis(
    CaptureRecord capture,
    AnalysisRun analysis,
  ) {
    if (analysis.status == AnalysisRunStatus.failed) {
      return CaptureStatus.failed;
    }
    final structured = analysis.structuredContent;
    if (structured?.completeness == StructuredCompleteness.unsupported) {
      return CaptureStatus.sourceLimited;
    }
    return capture.normalized.completeness == MaterialCompleteness.linkOnly
        ? CaptureStatus.sourceLimited
        : CaptureStatus.needsReview;
  }

  Future<CaptureRecord> _retainAttachments(CaptureRecord capture) async {
    if (capture.raw.attachments.isEmpty) {
      return capture;
    }
    final retained = <IncomingAttachment>[];
    for (final attachment in capture.raw.attachments) {
      final source = File(attachment.filePath);
      if (source.parent.path.split(Platform.pathSeparator).last !=
          'incoming_share_attachments') {
        retained.add(attachment);
        continue;
      }
      if (!await source.exists()) {
        throw const FileSystemException('Incoming attachment is missing.');
      }

      final extension = switch (attachment.mimeType) {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => throw const FileSystemException(
          'Incoming attachment type is unsupported.',
        ),
      };
      final libraryDirectory = Directory(
        '${source.parent.parent.path}${Platform.pathSeparator}'
        'ori_library_attachments',
      );
      await libraryDirectory.create(recursive: true);
      final destination = File(
        '${libraryDirectory.path}${Platform.pathSeparator}'
        '${attachment.sha256}.$extension',
      );
      if (await destination.exists()) {
        if (await destination.length() != attachment.byteSize) {
          throw const FileSystemException(
            'Retained attachment does not match its metadata.',
          );
        }
      } else {
        final temporary = File(
          '${libraryDirectory.path}${Platform.pathSeparator}'
          '.${attachment.sha256}.${attachment.id}.part',
        );
        RandomAccessFile? input;
        RandomAccessFile? output;
        try {
          input = await source.open();
          output = await temporary.open(mode: FileMode.write);
          while (true) {
            final bytes = await input.read(64 * 1024);
            if (bytes.isEmpty) {
              break;
            }
            await output.writeFrom(bytes);
          }
          await output.flush();
          await output.close();
          output = null;
          if (await temporary.length() != attachment.byteSize) {
            throw const FileSystemException(
              'Retained attachment does not match its metadata.',
            );
          }
          await temporary.rename(destination.path);
        } finally {
          await input?.close();
          await output?.close();
          if (await temporary.exists()) {
            await temporary.delete();
          }
        }
      }
      retained.add(
        IncomingAttachment(
          id: attachment.id,
          filePath: destination.path,
          mimeType: attachment.mimeType,
          byteSize: attachment.byteSize,
          width: attachment.width,
          height: attachment.height,
          sha256: attachment.sha256,
        ),
      );
    }
    return CaptureRecord(
      raw: RawCapture(
        id: capture.raw.id,
        transportEventId: capture.raw.transportEventId,
        receivedAt: capture.raw.receivedAt,
        origin: capture.raw.origin,
        mimeType: capture.raw.mimeType,
        rawText: capture.raw.rawText,
        rawUrl: capture.raw.rawUrl,
        semanticFingerprint: capture.raw.semanticFingerprint,
        wasTruncated: capture.raw.wasTruncated,
        originalLength: capture.raw.originalLength,
        sourcePackage: capture.raw.sourcePackage,
        userNote: capture.raw.userNote,
        attachments: retained,
      ),
      normalized: capture.normalized,
      status: capture.status,
      analysis: capture.analysis,
      review: capture.review,
      groupId: capture.groupId,
    );
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

  Future<void> confirmStructured(String captureId) async {
    final captureIndex = _captures.indexWhere(
      (capture) => capture.raw.id == captureId,
    );
    if (captureIndex == -1) {
      return;
    }
    final capture = _captures[captureIndex];
    final analysis = capture.analysis;
    if (analysis?.structuredContent == null) {
      return;
    }

    _captures[captureIndex] = capture.copyWith(
      status: CaptureStatus.organized,
      review: UserReview(
        id: 'review-${capture.raw.id}-${DateTime.now().microsecondsSinceEpoch}',
        captureId: capture.raw.id,
        analysisRunId: analysis!.id,
        resolution: ReviewResolution.confirmed,
        reviewedAt: DateTime.now(),
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
    final share = IncomingShare(
      id: capture.raw.transportEventId,
      receivedAt: capture.raw.receivedAt,
      sharedText: capture.raw.rawText,
      discoveredUrl: capture.raw.rawUrl,
      sourcePackage: capture.raw.sourcePackage,
      mimeType: capture.raw.mimeType,
      wasTruncated: capture.raw.wasTruncated,
      originalLength: capture.raw.originalLength,
      shareKind: capture.raw.attachments.isEmpty
          ? ShareKind.text
          : ShareKind.image,
      attachments: capture.raw.attachments,
    );
    final reanalyzed = capture.raw.attachments.isEmpty
        ? _contentAnalysisService.analyzeShare(
            share,
            origin: capture.raw.origin,
          )
        : _contentAnalysisService.prepareShare(
            share,
            origin: capture.raw.origin,
          );
    _captures[index] = reanalyzed;
    unawaited(_persistState());
    notifyListeners();
    if (reanalyzed.status == CaptureStatus.analyzing) {
      unawaited(_analyzeCapture(reanalyzed.raw.id));
    }
  }

  Future<void> _restoreSnapshot() async {
    try {
      final persistedCaptures = await _snapshotStore.load();
      final knownTransportIds = _captures
          .map((capture) => capture.raw.transportEventId)
          .toSet();
      final restored = <CaptureRecord>[];
      final pendingAnalysisIds = <String>[];
      for (final persisted in persistedCaptures) {
        if (!knownTransportIds.add(persisted.transportEventId)) {
          continue;
        }
        final share = persisted.toIncomingShare();
        final prepared = _contentAnalysisService.prepareShare(
          share,
          origin: persisted.origin,
        );
        final analyzed = switch (persisted.analysis) {
          final analysis? => prepared.copyWith(
            status: persisted.status,
            analysis: analysis,
          ),
          null when persisted.attachments.isEmpty =>
            _contentAnalysisService.analyzeShare(
              share,
              origin: persisted.origin,
            ),
          null => prepared,
        };
        if (analyzed.status == CaptureStatus.analyzing) {
          pendingAnalysisIds.add(analyzed.raw.id);
        }
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
              status: persisted.status,
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
        _durablySavedTransportIds.addAll(
          restored.map((capture) => capture.raw.transportEventId),
        );
        notifyListeners();
      }
      for (final captureId in pendingAnalysisIds) {
        await _analyzeCapture(captureId);
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
    final persistedTransportIds = persisted
        .map((capture) => capture.transportEventId)
        .toSet();
    var saved = false;
    _snapshotWriteTail = _snapshotWriteTail.then((_) async {
      try {
        await _snapshotStore.save(persisted);
        _durablySavedTransportIds
          ..clear()
          ..addAll(persistedTransportIds);
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
    unawaited(_incomingCaptureController.close());
    super.dispose();
  }
}
