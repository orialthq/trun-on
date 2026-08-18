import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'place_map_links.dart';

abstract interface class PlaceReminderOpenInbox {
  Stream<String> get opened;

  Future<List<String>> pending();

  Future<void> acknowledge(Iterable<String> captureIds);

  Future<void> close();
}

/// Delivers durable Android notification destinations to the Flutter router.
///
/// Native code keeps each id until [acknowledge] succeeds, so a cold start or a
/// process death between tapping a notification and rendering the first frame
/// cannot lose the requested destination.
final class MethodChannelPlaceReminderOpenInbox
    implements PlaceReminderOpenInbox {
  MethodChannelPlaceReminderOpenInbox({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channelName = 'com.orialthq.ori_beauty/place_reminders/v1';

  final MethodChannel _channel;
  final StreamController<String> _openedController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get opened => _openedController.stream;

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != 'placeReminderOpened') return null;
    final arguments = call.arguments;
    if (arguments is Map<Object?, Object?>) {
      final captureId = arguments['captureId'];
      if (captureId is String && captureId.trim().isNotEmpty) {
        _openedController.add(captureId.trim());
      }
    }
    return null;
  }

  @override
  Future<List<String>> pending() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'pendingPlaceReminderOpens',
      );
      return [
        for (final value in raw ?? const <Object?>[])
          if (value is String && value.trim().isNotEmpty) value.trim(),
      ];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> acknowledge(Iterable<String> captureIds) async {
    final ids = captureIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('acknowledgePlaceReminderOpens', {
        'ids': ids,
      });
    } on MissingPluginException {
      // Non-Android platforms do not own this durable queue.
    }
  }

  @override
  Future<void> close() async {
    _channel.setMethodCallHandler(null);
    await _openedController.close();
  }
}

final class InMemoryPlaceReminderOpenInbox implements PlaceReminderOpenInbox {
  InMemoryPlaceReminderOpenInbox([Iterable<String> pending = const []])
    : _pending = pending.toList();

  final List<String> _pending;
  final List<String> acknowledged = [];
  final StreamController<String> _openedController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get opened => _openedController.stream;

  @override
  Future<List<String>> pending() async => List.unmodifiable(_pending);

  void emit(String captureId) {
    if (!_pending.contains(captureId)) _pending.add(captureId);
    _openedController.add(captureId);
  }

  @override
  Future<void> acknowledge(Iterable<String> captureIds) async {
    final ids = captureIds.toSet();
    acknowledged.addAll(ids.where((id) => !acknowledged.contains(id)));
    _pending.removeWhere(ids.contains);
  }

  @override
  Future<void> close() => _openedController.close();
}

enum PlaceReminderEnableStatus {
  enabled,
  needsForegroundPermission,
  needsBackgroundPermission,
  addressNotFound,
  failed,
  unavailable,
}

enum MapProvider {
  naver(id: 'naver', label: '네이버 지도'),
  kakao(id: 'kakao', label: '카카오맵'),
  google(id: 'google', label: '구글 지도');

  const MapProvider({required this.id, required this.label});

  final String id;
  final String label;

  static MapProvider? fromId(Object? id) {
    for (final provider in values) {
      if (provider.id == id) {
        return provider;
      }
    }
    return null;
  }
}

final class MapProviderOption {
  const MapProviderOption({
    required this.provider,
    required this.appInstalled,
    required this.available,
  });

  const MapProviderOption.unavailable(this.provider)
    : appInstalled = false,
      available = false;

  final MapProvider provider;
  final bool appInstalled;
  final bool available;

  String get label => provider.label;

  String get destinationLabel => appInstalled ? '앱으로 열기' : '웹으로 열기';
}

final class MapOpenResult {
  const MapOpenResult({required this.provider, required this.openedInApp});

  final MapProvider provider;
  final bool openedInApp;
}

final class PlaceReminderState {
  const PlaceReminderState({
    required this.enabled,
    required this.radiusMeters,
    required this.foregroundGranted,
    required this.backgroundGranted,
    required this.backgroundPermissionLabel,
  });

  const PlaceReminderState.unavailable()
    : enabled = false,
      radiusMeters = PlaceReminderService.defaultRadiusMeters,
      foregroundGranted = false,
      backgroundGranted = false,
      backgroundPermissionLabel = '항상 허용';

  final bool enabled;
  final double radiusMeters;
  final bool foregroundGranted;
  final bool backgroundGranted;
  final String backgroundPermissionLabel;
}

final class PlaceReminderEnableResult {
  const PlaceReminderEnableResult({
    required this.status,
    this.radiusMeters,
    this.backgroundPermissionLabel,
  });

  final PlaceReminderEnableStatus status;
  final double? radiusMeters;
  final String? backgroundPermissionLabel;
}

final class PlaceReminderService {
  const PlaceReminderService();

  static const defaultRadiusMeters = 500.0;
  static const minRadiusMeters = 100.0;
  static const maxRadiusMeters = 5000.0;
  static const _channel = MethodChannel(
    'com.orialthq.ori_beauty/place_reminders/v1',
  );
  static const orderedMapProviders = <MapProvider>[
    MapProvider.naver,
    MapProvider.kakao,
    MapProvider.google,
  ];
  Future<PlaceReminderState> getState(String id) async {
    if (!Platform.isAndroid) {
      return const PlaceReminderState.unavailable();
    }
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'getPlaceReminder',
      {'id': id},
    );
    return PlaceReminderState(
      enabled: raw?['enabled'] == true,
      radiusMeters:
          (raw?['radiusMeters'] as num?)?.toDouble() ?? defaultRadiusMeters,
      foregroundGranted: raw?['foregroundGranted'] == true,
      backgroundGranted: raw?['backgroundGranted'] == true,
      backgroundPermissionLabel:
          raw?['backgroundPermissionLabel'] as String? ?? '항상 허용',
    );
  }

  Future<bool> requestForegroundPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>(
          'requestForegroundLocationPermission',
        ) ??
        false;
  }

  /// Requests permission to post the local notifications used by plans.
  ///
  /// Android versions before 13 grant this capability at install time. Other
  /// platforms do not implement this Android-specific method channel contract,
  /// so they return `false` and can handle notification authorization through
  /// their own native integration.
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openBackgroundLocationSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openBackgroundLocationSettings');
  }

  Future<PlaceReminderEnableResult> enable({
    required String id,
    required String title,
    required String address,
    required double radiusMeters,
  }) async {
    if (!Platform.isAndroid) {
      return const PlaceReminderEnableResult(
        status: PlaceReminderEnableStatus.unavailable,
      );
    }
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'enablePlaceReminder',
      {
        'id': id,
        'title': title,
        'address': address,
        'radiusMeters': radiusMeters,
      },
    );
    final status = switch (raw?['status']) {
      'enabled' => PlaceReminderEnableStatus.enabled,
      'needs_foreground_permission' =>
        PlaceReminderEnableStatus.needsForegroundPermission,
      'needs_background_permission' =>
        PlaceReminderEnableStatus.needsBackgroundPermission,
      'address_not_found' => PlaceReminderEnableStatus.addressNotFound,
      _ => PlaceReminderEnableStatus.failed,
    };
    return PlaceReminderEnableResult(
      status: status,
      radiusMeters: (raw?['radiusMeters'] as num?)?.toDouble(),
      backgroundPermissionLabel: raw?['backgroundPermissionLabel'] as String?,
    );
  }

  Future<bool> disable(String id) async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('disablePlaceReminder', {
          'id': id,
        }) ??
        false;
  }

  Future<List<MapProviderOption>> getMapProviderOptions() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('getMapProviders');
      final optionsByProvider = <MapProvider, MapProviderOption>{};
      for (final entry in raw ?? const <Object?>[]) {
        if (entry is! Map<Object?, Object?>) {
          continue;
        }
        final provider = MapProvider.fromId(entry['id']);
        if (provider == null) {
          continue;
        }
        optionsByProvider[provider] = MapProviderOption(
          provider: provider,
          appInstalled: entry['appInstalled'] == true,
          available: entry['available'] == true,
        );
      }
      return [
        for (final provider in orderedMapProviders)
          optionsByProvider[provider] ??
              MapProviderOption.unavailable(provider),
      ];
    } on MissingPluginException {
      return [
        for (final provider in orderedMapProviders)
          MapProviderOption.unavailable(provider),
      ];
    }
  }

  Future<MapOpenResult> openMapWithProvider({
    required MapProvider provider,
    String? name,
    required String address,
    String? searchArea,
    MapQueryMode mode = MapQueryMode.place,
  }) async {
    final links = PlaceMapLinks.fromPlace(
      name: name,
      address: address,
      searchArea: searchArea,
    );
    if (links == null) {
      throw ArgumentError.value(address, 'address', 'A map query is required.');
    }
    final query = switch (mode) {
      MapQueryMode.address => links.addressQuery,
      MapQueryMode.place => links.searchQuery,
    };
    final raw = await _channel
        .invokeMapMethod<Object?, Object?>('openMapProvider', {
          'provider': provider.id,
          'query': query,
          'name': links.name,
          'address': links.address,
        });
    return MapOpenResult(
      provider: MapProvider.fromId(raw?['provider']) ?? provider,
      openedInApp: raw?['openedInApp'] == true,
    );
  }

  Future<void> openMap({
    String? name,
    required String address,
    String? searchArea,
  }) async {
    await openMapWithProvider(
      provider: MapProvider.naver,
      name: name,
      address: address,
      searchArea: searchArea,
    );
  }
}

/// Which captured fields a map search should use.
enum MapQueryMode {
  /// Place name plus the captured address. Best when the address is really an
  /// area tag, because the name is what identifies the shop.
  place,

  /// The address alone, for when the captured name is wrong or the user wants
  /// the building rather than the business.
  address,
}
