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
  static const _koreanRegionTokens = <String>{
    '서울',
    '서울시',
    '서울특별시',
    '부산',
    '부산시',
    '부산광역시',
    '대구',
    '대구시',
    '대구광역시',
    '인천',
    '인천시',
    '인천광역시',
    '광주',
    '광주시',
    '광주광역시',
    '대전',
    '대전시',
    '대전광역시',
    '울산',
    '울산시',
    '울산광역시',
    '세종',
    '세종시',
    '세종특별자치시',
    '경기',
    '경기도',
    '강원',
    '강원도',
    '강원특별자치도',
    '충북',
    '충청북도',
    '충남',
    '충청남도',
    '전북',
    '전라북도',
    '전북특별자치도',
    '전남',
    '전라남도',
    '경북',
    '경상북도',
    '경남',
    '경상남도',
    '제주',
    '제주도',
    '제주특별자치도',
  };
  static final _administrativeToken = RegExp(r'^[가-힣0-9·-]{1,12}(?:시|군|구)$');
  static final _neighborhoodToken = RegExp(r'^[가-힣0-9·-]{1,16}(?:읍|면|동|가|리)$');
  static final _roadToken = RegExp(r'^[가-힣0-9·-]{1,20}(?:대로|로|길|번길)$');
  static final _buildingNumberToken = RegExp(r'^\d+(?:-\d+)?(?:번지|번)?$');
  static final _terminalFloorOrRoom = RegExp(
    r'(?:^|[\s,]+)(?:(?:지하\s*)?\d+\s*층|B\d+F?|\d+F)(?:[\s,]+\d+\s*호)?\s*$',
    caseSensitive: false,
  );
  static final _terminalRoom = RegExp(r'(?:^|[\s,]+)\d+\s*호\s*$');

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
  }) async {
    final normalizedName = _normalizeMapText(name);
    final normalizedAddress = _normalizeMapText(address);
    final query = switch (provider) {
      MapProvider.naver => _buildNaverQuery(
        name: normalizedName,
        address: normalizedAddress,
      ),
      MapProvider.kakao || MapProvider.google => [
        normalizedName,
        normalizedAddress,
      ].where((value) => value.isNotEmpty).join(' '),
    };
    if (query.isEmpty) {
      throw ArgumentError.value(query, 'address', 'A map query is required.');
    }
    final raw = await _channel
        .invokeMapMethod<Object?, Object?>('openMapProvider', {
          'provider': provider.id,
          'query': query,
          'name': normalizedName,
          'address': normalizedAddress,
        });
    return MapOpenResult(
      provider: MapProvider.fromId(raw?['provider']) ?? provider,
      openedInApp: raw?['openedInApp'] == true,
    );
  }

  Future<void> openMap({String? name, required String address}) async {
    await openMapWithProvider(
      provider: MapProvider.naver,
      name: name,
      address: address,
    );
  }

  static String _normalizeMapText(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _buildNaverQuery({
    required String name,
    required String address,
  }) {
    if (address.isEmpty) {
      return name;
    }

    final addressOnly = _stripTrailingUnit(_stripNonAddressPrefix(address));
    return addressOnly.isEmpty ? address : addressOnly;
  }

  static String _stripNonAddressPrefix(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[,|\u2022]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final tokens = normalized.split(' ');
    final comparableTokens = tokens.map(_comparableAddressToken).toList();

    int? anchorIndex;
    for (var index = 0; index < comparableTokens.length; index++) {
      if (_koreanRegionTokens.contains(comparableTokens[index]) &&
          _hasAddressEvidence(comparableTokens, index + 1)) {
        anchorIndex = index;
        break;
      }
    }
    if (anchorIndex == null) {
      for (var index = 0; index < comparableTokens.length; index++) {
        if (_administrativeToken.hasMatch(comparableTokens[index]) &&
            _hasAddressEvidence(comparableTokens, index + 1)) {
          anchorIndex = index;
          break;
        }
      }
    }
    if (anchorIndex == null) {
      for (var index = 0; index < comparableTokens.length - 1; index++) {
        final token = comparableTokens[index];
        if ((_neighborhoodToken.hasMatch(token) ||
                _roadToken.hasMatch(token)) &&
            _hasBuildingNumber(comparableTokens, index + 1)) {
          anchorIndex = index;
          break;
        }
      }
    }

    if (anchorIndex == null || anchorIndex == 0) {
      return normalized;
    }
    return tokens
        .sublist(anchorIndex)
        .join(' ')
        .replaceFirst(RegExp(r'^[^0-9A-Za-z가-힣]+'), '')
        .trim();
  }

  static bool _hasAddressEvidence(List<String> tokens, int startIndex) {
    final end = (startIndex + 5).clamp(0, tokens.length);
    for (var index = startIndex; index < end; index++) {
      final token = tokens[index];
      if (_administrativeToken.hasMatch(token) ||
          _neighborhoodToken.hasMatch(token) ||
          _roadToken.hasMatch(token) ||
          _buildingNumberToken.hasMatch(token)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasBuildingNumber(List<String> tokens, int startIndex) {
    final end = (startIndex + 4).clamp(0, tokens.length);
    for (var index = startIndex; index < end; index++) {
      if (_buildingNumberToken.hasMatch(tokens[index])) {
        return true;
      }
    }
    return false;
  }

  static String _comparableAddressToken(String value) =>
      value.replaceAll(RegExp(r'^[^0-9A-Za-z가-힣]+|[^0-9A-Za-z가-힣]+$'), '');

  static String _stripTrailingUnit(String value) {
    final withoutFloor = value.replaceFirst(_terminalFloorOrRoom, '').trim();
    final withoutRoom = withoutFloor.replaceFirst(_terminalRoom, '').trim();
    return withoutRoom;
  }
}
