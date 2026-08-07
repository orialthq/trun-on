/// Platform-neutral map search queries and HTTPS links for sharing places.
///
/// The links deliberately use each provider's public web search URL so a
/// recipient can open them on Android, iOS, or desktop without Trun On.
final class PlaceMapLinks {
  const PlaceMapLinks._({
    required this.name,
    required this.address,
    required this.area,
    required this.searchQuery,
    required this.addressQuery,
  });

  static PlaceMapLinks? fromPlace({
    String? name,
    String? address,
    String? searchArea,
  }) {
    final normalizedName = normalizeMapText(name);
    final normalizedAddress = normalizeMapText(address);
    if (normalizedName.isEmpty && normalizedAddress.isEmpty) return null;

    final addressQuery = _buildAddressQuery(address: normalizedAddress);
    // Luna reads the area off the screenshot and keeps colloquial wording that a
    // map actually matches (`가로수길`, `홍대`). Deriving one from the address is
    // the fallback for captures analysed before that field existed, and for
    // screenshots where no area was legible.
    final readArea = normalizeMapText(searchArea);
    final area = readArea.isNotEmpty
        ? readArea
        : _buildCoarseArea(address: normalizedAddress);
    final searchQuery = _buildSearchQuery(name: normalizedName, area: area);
    if (searchQuery.isEmpty) return null;

    return PlaceMapLinks._(
      name: normalizedName,
      address: normalizedAddress,
      area: area,
      searchQuery: searchQuery,
      addressQuery: addressQuery.isEmpty ? searchQuery : addressQuery,
    );
  }

  final String name;
  final String address;

  /// The broad area the capture points at, such as `성수` or `성동`.
  final String area;

  /// `상호명 + 큰 지역`, the query every provider is opened with.
  ///
  /// A captured address is frequently an SNS location tag or a partly misread
  /// street line, and a wrong house number pushes map search away from the shop
  /// rather than towards it. The shop name is the reliable half, so the address
  /// contributes only the district it implies.
  final String searchQuery;

  /// The address on its own, without the place name, a repeated name prefix, or
  /// a trailing floor/room.
  ///
  /// Used only when the user explicitly asks to search by address. It is not the
  /// default because a captured "address" is often an SNS location tag naming a
  /// neighbourhood rather than the shop, and searching that alone lands on
  /// whatever else occupies the area.
  final String addressQuery;

  Uri get naver => Uri.parse(
    'https://map.naver.com/p/search/${Uri.encodeComponent(searchQuery)}',
  );

  Uri get kakao => Uri.parse(
    'https://map.kakao.com/link/search/${Uri.encodeComponent(searchQuery)}',
  );

  Uri get google => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': searchQuery,
  });

  /// Human-readable IRIs for chat apps. Hangul remains visible, while spaces
  /// use `%20` so each URL is still one directly tappable token.
  String get naverShareUrl =>
      'https://map.naver.com/p/search/${_encodeVisibleQuery(searchQuery)}';

  String get kakaoShareUrl =>
      'https://map.kakao.com/link/search/${_encodeVisibleQuery(searchQuery)}';

  String get googleShareUrl =>
      'https://maps.google.com/?q=${_encodeVisibleQuery(searchQuery)}';

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
// Applied repeatedly, so `성수동2가` sheds `2가` and then `동`.
final _neighborhoodSuffix = RegExp(r'(?:\d+가|[읍면동가리])$');
final _administrativeSuffix = RegExp(r'[시군구]$');
final _regionSuffix = RegExp(r'(?:특별자치시|특별자치도|특별시|광역시|시|도)$');
final _roadToken = RegExp(r'^[가-힣0-9·-]{1,20}(?:대로|로|길|번길)$');
final _buildingNumberToken = RegExp(r'^\d+(?:-\d+)?(?:번지|번)?$');
final _terminalFloorOrRoom = RegExp(
  r'(?:^|[\s,]+)(?:(?:지하\s*)?\d+\s*층|B\d+F?|\d+F)(?:[\s,]+\d+\s*호)?\s*$',
  caseSensitive: false,
);
final _terminalRoom = RegExp(r'(?:^|[\s,]+)\d+\s*호\s*$');

String _buildAddressQuery({required String address}) {
  if (address.isEmpty) return '';
  final addressOnly = _stripTrailingUnit(_stripNonAddressPrefix(address));
  return addressOnly.isEmpty ? address : addressOnly;
}

String _buildSearchQuery({required String name, required String area}) {
  if (name.isEmpty) return area;
  if (area.isEmpty) return name;
  if (area == name) return name;
  return '$name $area';
}

/// The broadest locality the captured address supports, stripped of its
/// administrative suffix: `성수동 연무장길 5` becomes `성수`.
///
/// Detail is dropped on purpose. A building number read off a screenshot is
/// often misread, or belongs to a location tag someone attached to the post
/// rather than to the shop, and a wrong number pushes map search away from the
/// place instead of towards it. The district survives a misread, and paired with
/// the shop name it is enough for a provider to land on the right result.
String _buildCoarseArea({required String address}) {
  if (address.isEmpty) return '';
  final tokens = address
      .split(' ')
      .map(_comparableAddressToken)
      .where((token) => token.isNotEmpty)
      .toList();

  for (final token in tokens) {
    if (_neighborhoodToken.hasMatch(token)) {
      return _shortenLocality(token, _neighborhoodSuffix, rounds: 2);
    }
  }
  for (final token in tokens) {
    // `서울특별시` also ends in 시; it belongs to the region branch below, which
    // knows how to shorten it without leaving `서울특별`.
    if (_administrativeToken.hasMatch(token) &&
        !_koreanRegionTokens.contains(token)) {
      return _shortenLocality(token, _administrativeSuffix, rounds: 1);
    }
  }
  for (final token in tokens) {
    if (_koreanRegionTokens.contains(token)) {
      return _shortenLocality(token, _regionSuffix, rounds: 2);
    }
  }
  return '';
}

/// Drops an administrative suffix without shortening a token into an
/// unsearchable fragment. `성수동2가` reduces to `성수`, while `중구` stays whole
/// because `중` alone means nothing to a map.
String _shortenLocality(String token, RegExp suffix, {required int rounds}) {
  var value = token;
  for (var round = 0; round < rounds; round++) {
    final shortened = value.replaceFirst(suffix, '');
    if (shortened.length < 2) break;
    value = shortened;
  }
  return value;
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
