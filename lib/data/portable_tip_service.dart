import 'dart:async';

import 'package:flutter/services.dart';

/// Receives versioned Trun On packages opened from another app.
///
/// The native layer keeps the raw package until Dart drains it, so cold-start
/// hand-offs are not lost while Flutter is booting.
abstract interface class PortableTipInbox {
  Stream<void> get pendingChanged;

  Future<List<PendingPortableTipEnvelope>> pending();

  Future<void> acknowledge(Iterable<String> transportIds);

  Future<void> dispose();
}

final class MethodChannelPortableTipInbox implements PortableTipInbox {
  MethodChannelPortableTipInbox() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pendingPackagesChanged') {
        _pendingController.add(null);
      }
    });
  }

  static const _channel = MethodChannel(
    'com.orialthq.ori_beauty/portable_tip/v1',
  );

  final _pendingController = StreamController<void>.broadcast();

  @override
  Stream<void> get pendingChanged => _pendingController.stream;

  @override
  Future<List<PendingPortableTipEnvelope>> pending() async {
    final raw = await _channel.invokeListMethod<Object?>('pendingPackages');
    if (raw == null) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(PendingPortableTipEnvelope.fromPlatformMap)
        .toList(growable: false);
  }

  @override
  Future<void> acknowledge(Iterable<String> transportIds) {
    return _channel.invokeMethod<void>('acknowledgePackages', {
      'transportIds': transportIds.toList(growable: false),
    });
  }

  @override
  Future<void> dispose() => _pendingController.close();
}

final class InMemoryPortableTipInbox implements PortableTipInbox {
  final _pendingController = StreamController<void>.broadcast();
  final List<PendingPortableTipEnvelope> _pending = [];

  @override
  Stream<void> get pendingChanged => _pendingController.stream;

  void add(String encodedPackage, {String? transportId}) {
    _pending.add(
      PendingPortableTipEnvelope(
        transportId:
            transportId ?? 'portable-${DateTime.now().microsecondsSinceEpoch}',
        contents: encodedPackage,
      ),
    );
    _pendingController.add(null);
  }

  @override
  Future<List<PendingPortableTipEnvelope>> pending() async =>
      List.unmodifiable(_pending);

  @override
  Future<void> acknowledge(Iterable<String> transportIds) async {
    final ids = transportIds.toSet();
    _pending.removeWhere((item) => ids.contains(item.transportId));
  }

  @override
  Future<void> dispose() => _pendingController.close();
}

final class PendingPortableTipEnvelope {
  const PendingPortableTipEnvelope({
    required this.transportId,
    required this.contents,
  });

  factory PendingPortableTipEnvelope.fromPlatformMap(
    Map<Object?, Object?> map,
  ) {
    final transportId = map['transportId'];
    final contents = map['contents'];
    if (transportId is! String ||
        transportId.isEmpty ||
        contents is! String ||
        contents.isEmpty) {
      throw const FormatException('Portable tip envelope is invalid.');
    }
    return PendingPortableTipEnvelope(
      transportId: transportId,
      contents: contents,
    );
  }

  final String transportId;
  final String contents;
}
