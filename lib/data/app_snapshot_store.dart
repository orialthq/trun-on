import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models.dart';

abstract interface class AppSnapshotStore {
  Future<List<PersistedCapture>> load();

  Future<void> save(List<PersistedCapture> captures);
}

final class MethodChannelAppSnapshotStore implements AppSnapshotStore {
  const MethodChannelAppSnapshotStore();

  static const _channel = MethodChannel(
    'com.orialthq.ori_beauty/incoming_share/v1',
  );

  @override
  Future<List<PersistedCapture>> load() async {
    final snapshot = await _channel.invokeMethod<String>('loadAppSnapshot');
    if (snapshot == null || snapshot.isEmpty) {
      return const [];
    }
    return AppSnapshotCodec.decode(snapshot);
  }

  @override
  Future<void> save(List<PersistedCapture> captures) async {
    final saved = await _channel.invokeMethod<bool>(
      'saveAppSnapshot',
      AppSnapshotCodec.encode(captures),
    );
    if (saved != true) {
      throw StateError('The Android app snapshot was not saved.');
    }
  }
}

final class InMemoryAppSnapshotStore implements AppSnapshotStore {
  String? _snapshot;

  String? get snapshot => _snapshot;

  @override
  Future<List<PersistedCapture>> load() async {
    final snapshot = _snapshot;
    return snapshot == null ? const [] : AppSnapshotCodec.decode(snapshot);
  }

  @override
  Future<void> save(List<PersistedCapture> captures) async {
    _snapshot = AppSnapshotCodec.encode(captures);
  }
}

abstract final class AppSnapshotCodec {
  static const schemaVersion = 1;

  static String encode(List<PersistedCapture> captures) {
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'captures': captures.map((capture) => capture.toJson()).toList(),
    });
  }

  static List<PersistedCapture> decode(String snapshot) {
    final decoded = jsonDecode(snapshot);
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported app snapshot schema.');
    }
    final captures = decoded['captures'];
    if (captures is! List<Object?>) {
      throw const FormatException('App snapshot captures are invalid.');
    }
    return captures
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Persisted capture is invalid.');
          }
          return PersistedCapture.fromJson(item);
        })
        .toList(growable: false);
  }
}

final class PersistedCapture {
  const PersistedCapture({
    required this.transportEventId,
    required this.receivedAt,
    required this.origin,
    required this.sharedText,
    required this.discoveredUrl,
    required this.sourcePackage,
    required this.mimeType,
    required this.wasTruncated,
    required this.originalLength,
    required this.status,
    required this.reviewId,
    required this.reviewResolution,
    required this.reviewedAt,
    required this.confirmedIdentity,
    required this.groupId,
  });

  factory PersistedCapture.fromRecord(
    CaptureRecord capture,
    ProductGroup? group,
  ) {
    return PersistedCapture(
      transportEventId: capture.raw.transportEventId,
      receivedAt: capture.raw.receivedAt,
      origin: capture.raw.origin,
      sharedText: capture.raw.rawText,
      discoveredUrl: capture.raw.rawUrl,
      sourcePackage: capture.raw.sourcePackage,
      mimeType: capture.raw.mimeType,
      wasTruncated: capture.raw.wasTruncated,
      originalLength: capture.raw.originalLength,
      status: capture.status,
      reviewId: capture.review?.id,
      reviewResolution: capture.review?.resolution,
      reviewedAt: capture.review?.reviewedAt,
      confirmedIdentity: capture.review?.confirmedIdentity ?? group?.identity,
      groupId: capture.groupId,
    );
  }

  factory PersistedCapture.fromJson(Map<String, Object?> json) {
    final transportEventId = json['transportEventId'];
    final receivedAtEpochMs = json['receivedAtEpochMs'];
    final sharedText = json['sharedText'];
    final originalLength = json['originalLength'];
    if (transportEventId is! String ||
        receivedAtEpochMs is! int ||
        sharedText is! String ||
        originalLength is! int) {
      throw const FormatException('Persisted capture fields are invalid.');
    }

    final identityJson = json['confirmedIdentity'];
    return PersistedCapture(
      transportEventId: transportEventId,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedAtEpochMs),
      origin: _enumByName(
        CaptureOrigin.values,
        json['origin'],
        CaptureOrigin.manual,
      ),
      sharedText: sharedText,
      discoveredUrl: json['discoveredUrl'] as String?,
      sourcePackage: json['sourcePackage'] as String?,
      mimeType: json['mimeType'] as String? ?? 'text/plain',
      wasTruncated: json['wasTruncated'] as bool? ?? false,
      originalLength: originalLength,
      status: _enumByName(
        CaptureStatus.values,
        json['status'],
        CaptureStatus.needsReview,
      ),
      reviewId: json['reviewId'] as String?,
      reviewResolution: json['reviewResolution'] == null
          ? null
          : _enumByName(
              ReviewResolution.values,
              json['reviewResolution'],
              ReviewResolution.deferred,
            ),
      reviewedAt: json['reviewedAtEpochMs'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              json['reviewedAtEpochMs']! as int,
            )
          : null,
      confirmedIdentity: identityJson is Map<String, Object?>
          ? ConfirmedProductIdentity(
              brand: identityJson['brand'] as String? ?? '',
              name: identityJson['name'] as String? ?? '',
              category: identityJson['category'] as String? ?? '',
              amount: identityJson['amount'] as String? ?? '',
            )
          : null,
      groupId: json['groupId'] as String?,
    );
  }

  final String transportEventId;
  final DateTime receivedAt;
  final CaptureOrigin origin;
  final String sharedText;
  final String? discoveredUrl;
  final String? sourcePackage;
  final String mimeType;
  final bool wasTruncated;
  final int originalLength;
  final CaptureStatus status;
  final String? reviewId;
  final ReviewResolution? reviewResolution;
  final DateTime? reviewedAt;
  final ConfirmedProductIdentity? confirmedIdentity;
  final String? groupId;

  IncomingShare toIncomingShare() {
    return IncomingShare(
      id: transportEventId,
      receivedAt: receivedAt,
      sharedText: sharedText,
      discoveredUrl: discoveredUrl,
      sourcePackage: sourcePackage,
      mimeType: mimeType,
      wasTruncated: wasTruncated,
      originalLength: originalLength,
    );
  }

  Map<String, Object?> toJson() {
    final identity = confirmedIdentity;
    return {
      'transportEventId': transportEventId,
      'receivedAtEpochMs': receivedAt.millisecondsSinceEpoch,
      'origin': origin.name,
      'sharedText': sharedText,
      'discoveredUrl': discoveredUrl,
      'sourcePackage': sourcePackage,
      'mimeType': mimeType,
      'wasTruncated': wasTruncated,
      'originalLength': originalLength,
      'status': status.name,
      'reviewId': reviewId,
      'reviewResolution': reviewResolution?.name,
      'reviewedAtEpochMs': reviewedAt?.millisecondsSinceEpoch,
      'confirmedIdentity': identity == null
          ? null
          : {
              'brand': identity.brand,
              'name': identity.name,
              'category': identity.category,
              'amount': identity.amount,
            },
      'groupId': groupId,
    };
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    if (raw is! String) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }
}
