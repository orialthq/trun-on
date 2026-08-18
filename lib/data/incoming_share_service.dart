import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/models.dart';

abstract interface class IncomingShareService {
  Stream<void> get pendingChanged;

  Future<List<IncomingShare>> drainPending();

  /// Opens the platform picture picker so a screenshot can be imported from
  /// inside the app. Accepted images are staged into the same pending queue a
  /// share intent uses, so the caller waits for [pendingChanged] rather than a
  /// returned image. Resolves to true when at least one image was accepted.
  ///
  /// Supported on both iOS and Android. Android also keeps its quick settings
  /// tile as a shortcut to the same picker.
  Future<bool> presentCapturePicker();

  Future<void> acknowledge(Iterable<String> ids);

  Future<SharedSourceDeletionResult> deleteSharedSource(String transportId);

  Future<void> keepSharedSource(String transportId);

  Future<void> dispose();
}

enum SharedSourceDeletionResult { deleted, kept, unavailable, failed }

final class MethodChannelIncomingShareService implements IncomingShareService {
  MethodChannelIncomingShareService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pendingSharesChanged') {
        _pendingController.add(null);
      }
    });
  }

  static const _channel = MethodChannel(
    'com.orialthq.ori_beauty/incoming_share/v1',
  );

  final _pendingController = StreamController<void>.broadcast();

  @override
  Stream<void> get pendingChanged => _pendingController.stream;

  @override
  Future<List<IncomingShare>> drainPending() async {
    final payload = await _channel.invokeListMethod<Object?>(
      'drainPendingShares',
    );
    if (payload == null) {
      return const [];
    }

    return payload
        .whereType<Map<Object?, Object?>>()
        .map(IncomingShare.fromPlatformMap)
        .toList(growable: false);
  }

  @override
  Future<bool> presentCapturePicker() async {
    final accepted = await _channel.invokeMethod<bool>('presentCapturePicker');
    return accepted ?? false;
  }

  @override
  Future<void> acknowledge(Iterable<String> ids) {
    return _channel.invokeMethod<void>('acknowledgeShares', <String, Object?>{
      'ids': ids.toList(growable: false),
    });
  }

  @override
  Future<SharedSourceDeletionResult> deleteSharedSource(
    String transportId,
  ) async {
    final value = await _channel.invokeMethod<String>('deleteSharedSource', {
      'transportId': transportId,
    });
    return switch (value) {
      'deleted' => SharedSourceDeletionResult.deleted,
      'kept' => SharedSourceDeletionResult.kept,
      'unavailable' => SharedSourceDeletionResult.unavailable,
      _ => SharedSourceDeletionResult.failed,
    };
  }

  @override
  Future<void> keepSharedSource(String transportId) {
    return _channel.invokeMethod<void>('keepSharedSource', {
      'transportId': transportId,
    });
  }

  @override
  Future<void> dispose() => _pendingController.close();
}

final class InMemoryIncomingShareService implements IncomingShareService {
  final _pendingController = StreamController<void>.broadcast();
  final List<IncomingShare> _shares = [];

  @override
  Stream<void> get pendingChanged => _pendingController.stream;

  void add(IncomingShare share) {
    _shares.add(share);
    _pendingController.add(null);
  }

  @override
  Future<List<IncomingShare>> drainPending() async =>
      List.unmodifiable(_shares);

  /// Number of times [presentCapturePicker] was called, for widget tests.
  int presentCapturePickerCount = 0;

  /// Value [presentCapturePicker] resolves to, for widget tests.
  bool capturePickerAccepts = false;

  @override
  Future<bool> presentCapturePicker() async {
    presentCapturePickerCount += 1;
    return capturePickerAccepts;
  }

  @override
  Future<void> acknowledge(Iterable<String> ids) async {
    _shares.removeWhere((share) => ids.contains(share.id));
  }

  @override
  Future<SharedSourceDeletionResult> deleteSharedSource(
    String transportId,
  ) async => SharedSourceDeletionResult.unavailable;

  @override
  Future<void> keepSharedSource(String transportId) async {}

  @override
  Future<void> dispose() => _pendingController.close();
}
