/// Platform-neutral map search queries and HTTPS links for sharing places.
///
/// The links deliberately use each provider's public web search URL so a
/// recipient can open them on Android, iOS, or desktop without Trun On.
final class PlaceMapLinks {
  const PlaceMapLinks._({
    required this.name,
    required this.address,
    required this.naverQuery,
    required this.combinedQuery,
    required this.shareQuery,
  });

  static PlaceMapLinks? fromPlace({String? name, String? address}) {
    final normalizedName = normalizeMapText(name);
    final normalizedAddress = normalizeMapText(address);
    if (normalizedName.isEmpty && normalizedAddress.isEmpty) return null;

    final naverQuery = _buildNaverQuery(
      name: normalizedName,
      address: normalizedAddress,
    );
    final combinedQuery = _buildCombinedQuery(
      name: normalizedName,
      address: normalizedAddress,
    );
    if (naverQuery.isEmpty || combinedQuery.isEmpty) return null;
    final shareQuery = _buildCompactShareQuery(
      name: normalizedName,
      address: normalizedAddress,
      fallback: naverQuery,
    );

    return PlaceMapLinks._(
      name: normalizedName,
      address: normalizedAddress,
      naverQuery: naverQuery,
      combinedQuery: combinedQuery,
      shareQuery: shareQuery,
    );
  }

  final String name;
  final String address;
  final String naverQuery;
  final String combinedQuery;

  /// A shorter address-only query used only in text shared to other apps.
  ///
  /// The full provider queries above remain unchanged for in-app map opening.
  /// Shared links favor district + road + building number so chat bubbles stay
  /// readable without sacrificing the location signals map search needs.
  final String shareQuery;

  Uri get naver => Uri.parse(
    'https://map.naver.com/p/search/${Uri.encodeComponent(naverQuery)}',
  );

  Uri get kakao => Uri.parse(
    'https://map.kakao.com/link/search/${Uri.encodeComponent(combinedQuery)}',
  );

  Uri get google => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': combinedQuery,
  });

  /// Human-readable IRIs for chat apps. Hangul remains visible, while spaces
  /// use `%20` so each URL is still one directly tappable token.
  String get naverShareUrl =>
      'https://map.naver.com/p/search/${_encodeVisibleQuery(shareQuery)}';

  String get kakaoShareUrl =>
      'https://map.kakao.com/link/search/${_encodeVisibleQuery(shareQuery)}';

  String get googleShareUrl =>
      'https://maps.google.com/?q=${_encodeVisibleQuery(shareQuery)}';

  /// Labeled, directly tappable URLs in the product's preferred order.
  String get shareText => <String>[
    name.isEmpty ? '📍 지도에서 바로 보기' : '📍 $name',
    '네이버 $naverShareUrl',
    '카카오 $kakaoShareUrl',
    '구글 $googleShareUrl',
  ].join('\n');
}

String normalizeMapText(String? value) => (value ?? '')
    .replaceAll(RegExp(r'[,|\u2022]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _koreanRegionTokens = <String>{
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

final _administrativeToken = RegExp(r'^[가-힣0-9·-]{1,12}(?:시|군|구)$');
final _neighborhoodToken = RegExp(r'^[가-힣0-9·-]{1,16}(?:읍|면|동|가|리)$');
final _roadToken = RegExp(r'^[가-힣0-9·-]{1,20}(?:대로|로|길|번길)$');
final _buildingNumberToken = RegExp(r'^\d+(?:-\d+)?(?:번지|번)?$');
final _terminalFloorOrRoom = RegExp(
  r'(?:^|[\s,]+)(?:(?:지하\s*)?\d+\s*층|B\d+F?|\d+F)(?:[\s,]+\d+\s*호)?\s*$',
  caseSensitive: false,
);
final _terminalRoom = RegExp(r'(?:^|[\s,]+)\d+\s*호\s*$');
const _ambiguousDistrictTokens = <String>{'중구', '동구', '서구', '남구', '북구'};

String _buildCombinedQuery({required String name, required String address}) {
  if (name.isEmpty) return address;
  if (address.isEmpty) return name;
  // OCR/model output sometimes prefixes an address with the place name. Do
  // not repeat it, as repeated words reduce search quality on some providers.
  if (address == name || address.startsWith('$name ')) return address;
  return '$name $address';
}

String _buildNaverQuery({required String name, required String address}) {
  if (address.isEmpty) return name;
  final addressOnly = _stripTrailingUnit(_stripNonAddressPrefix(address));
  return addressOnly.isEmpty ? address : addressOnly;
}

String _buildCompactShareQuery({
  required String name,
  required String address,
  required String fallback,
}) {
  if (address.isEmpty) return name;

  final addressOnly = _stripTrailingUnit(_stripNonAddressPrefix(address));
  if (addressOnly.isEmpty) return fallback;
  final tokens = addressOnly.split(' ');
  final comparable = tokens.map(_comparableAddressToken).toList();

  for (var index = 0; index < comparable.length; index++) {
    if (!_roadToken.hasMatch(comparable[index])) continue;
    final numberIndex = _firstBuildingNumberIndex(comparable, index + 1);
    if (numberIndex == null) continue;
    final start = _compactAddressStart(comparable, index);
    return tokens.sublist(start, numberIndex + 1).join(' ');
  }

  for (var index = 0; index < comparable.length; index++) {
    if (!_neighborhoodToken.hasMatch(comparable[index])) continue;
    final numberIndex = _firstBuildingNumberIndex(comparable, index + 1);
    if (numberIndex == null) continue;
    final start = _compactAddressStart(comparable, index);
    return tokens.sublist(start, numberIndex + 1).join(' ');
  }

  // Unstructured addresses cannot be safely trimmed around a road/building
  // pair. Keep a bounded prefix instead of risking a misleading link.
  return tokens.take(6).join(' ');
}

int? _firstBuildingNumberIndex(List<String> tokens, int startIndex) {
  final end = (startIndex + 3).clamp(0, tokens.length);
  for (var index = startIndex; index < end; index++) {
    if (_buildingNumberToken.hasMatch(tokens[index])) return index;
  }
  return null;
}

int _compactAddressStart(List<String> tokens, int anchorIndex) {
  var start = anchorIndex;
  var administrativeCount = 0;
  for (var index = anchorIndex - 1; index >= 0; index--) {
    final token = tokens[index];
    if (_administrativeToken.hasMatch(token)) {
      start = index;
      administrativeCount++;
      if (administrativeCount == 2) break;
      continue;
    }
    if (_neighborhoodToken.hasMatch(token) && administrativeCount == 0) {
      start = index;
      continue;
    }
    if (_koreanRegionTokens.contains(token) &&
        start < tokens.length &&
        _ambiguousDistrictTokens.contains(tokens[start])) {
      start = index;
    }
    break;
  }
  return start;
}

String _encodeVisibleQuery(String value) {
  final output = StringBuffer();
  for (final rune in value.runes) {
    if (rune == 0x20) {
      output.write('%20');
      continue;
    }
    final isAsciiUnreserved =
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0x30 && rune <= 0x39) ||
        rune == 0x2D ||
        rune == 0x2E ||
        rune == 0x5F ||
        rune == 0x7E;
    final character = String.fromCharCode(rune);
    output.write(
      isAsciiUnreserved || rune > 0x7F
          ? character
          : Uri.encodeComponent(character),
    );
  }
  return output.toString();
}

String _stripNonAddressPrefix(String value) {
  final normalized = normalizeMapText(value);
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
      if ((_neighborhoodToken.hasMatch(token) || _roadToken.hasMatch(token)) &&
          _hasBuildingNumber(comparableTokens, index + 1)) {
        anchorIndex = index;
        break;
      }
    }
  }

  if (anchorIndex == null || anchorIndex == 0) return normalized;
  return tokens
      .sublist(anchorIndex)
      .join(' ')
      .replaceFirst(RegExp(r'^[^0-9A-Za-z가-힣]+'), '')
      .trim();
}

bool _hasAddressEvidence(List<String> tokens, int startIndex) {
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

bool _hasBuildingNumber(List<String> tokens, int startIndex) {
  final end = (startIndex + 4).clamp(0, tokens.length);
  for (var index = startIndex; index < end; index++) {
    if (_buildingNumberToken.hasMatch(tokens[index])) return true;
  }
  return false;
}

String _comparableAddressToken(String value) =>
    value.replaceAll(RegExp(r'^[^0-9A-Za-z가-힣]+|[^0-9A-Za-z가-힣]+$'), '');

String _stripTrailingUnit(String value) {
  final withoutFloor = value.replaceFirst(_terminalFloorOrRoom, '').trim();
  return withoutFloor.replaceFirst(_terminalRoom, '').trim();
}
