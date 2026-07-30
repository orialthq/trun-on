import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/models.dart';

abstract interface class IncomingShareService {
  Stream<void> get pendingChanged;

  Future<List<IncomingShare>> drainPending();

  Future<void> acknowledge(Iterable<String> ids);

  Future<void> dispose();
}

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
  Future<void> acknowledge(Iterable<String> ids) {
    return _channel.invokeMethod<void>('acknowledgeShares', <String, Object?>{
      'ids': ids.toList(growable: false),
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

  @override
  Future<void> acknowledge(Iterable<String> ids) async {
    _shares.removeWhere((share) => ids.contains(share.id));
  }

  @override
  Future<void> dispose() => _pendingController.close();
}
