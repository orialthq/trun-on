import 'dart:io';

import 'package:flutter/services.dart';

enum PlaceReminderEnableStatus {
  enabled,
  needsForegroundPermission,
  needsBackgroundPermission,
  addressNotFound,
  failed,
  unavailable,
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

  Future<void> openMap({String? name, required String address}) async {
    if (!Platform.isAndroid) {
      throw MissingPluginException('Map opening is not implemented.');
    }
    await _channel.invokeMethod<void>('openMap', {
      'name': name,
      'address': address,
    });
  }
}
