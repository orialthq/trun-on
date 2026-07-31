import '../domain/models.dart';

abstract interface class ContentAnalysisService {
  CaptureRecord analyzeShare(
    IncomingShare share, {
    CaptureOrigin origin = CaptureOrigin.androidShare,
  });
}

final class BaselineContentAnalysisService implements ContentAnalysisService {
  const BaselineContentAnalysisService();

  static const normalizerVersion = 'baseline-normalizer-v1';
  static const analyzerVersion = 'baseline-rules-v2';

  @override
  CaptureRecord analyzeShare(
    IncomingShare share, {
    CaptureOrigin origin = CaptureOrigin.androidShare,
  }) {
    final normalizedText = _normalizeText(share.sharedText);
    final rawUrls = _extractUrls(share.sharedText);
    if (share.discoveredUrl case final discoveredUrl?
        when !rawUrls.contains(discoveredUrl)) {
      rawUrls.insert(0, discoveredUrl);
    }

    final urls = rawUrls
        .map(
          (rawUrl) => NormalizedUrl(
            rawValue: rawUrl,
            canonicalValue: canonicalizeUrl(rawUrl),
            platform: platformForUrl(rawUrl),
          ),
        )
        .toList(growable: false);
    final materialText = normalizedText
        .replaceAll(RegExp(r'https?://[^\s]+'), '')
        .trim();
    final completeness = switch ((materialText.isNotEmpty, urls.isNotEmpty)) {
      (false, true) => MaterialCompleteness.linkOnly,
      (true, true) => MaterialCompleteness.partial,
      _ => MaterialCompleteness.complete,
    };
    final fingerprintSource = [
      materialText.toLowerCase(),
      ...urls.map((url) => url.canonicalValue),
    ].join('|');
    final fingerprint = semanticFingerprint(fingerprintSource);

    final raw = RawCapture(
      id: 'capture-${share.id}',
      transportEventId: share.id,
      receivedAt: share.receivedAt,
      origin: origin,
      mimeType: share.mimeType,
      rawText: share.sharedText,
      rawUrl: share.discoveredUrl,
      semanticFingerprint: fingerprint,
      wasTruncated: share.wasTruncated,
      originalLength: share.originalLength ?? share.sharedText.length,
      sourcePackage: share.sourcePackage,
    );
    final warnings = <String>[
      if (completeness == MaterialCompleteness.linkOnly)
        '공유된 링크만으로는 본문을 확인할 수 없어요.',
      if (share.wasTruncated) '전달 한도로 인해 원문 일부만 저장됐어요.',
    ];
    final normalized = NormalizedInput(
      inputId: raw.id,
      normalizerVersion: normalizerVersion,
      normalizedText: normalizedText,
      urls: urls,
      semanticFingerprint: fingerprint,
      completeness: completeness,
      warnings: warnings,
    );

    if (normalizedText.isEmpty && urls.isEmpty) {
      return CaptureRecord(
        raw: raw,
        normalized: normalized,
        status: CaptureStatus.failed,
        analysis: AnalysisRun(
          id: 'analysis-${share.id}',
          inputId: raw.id,
          normalizerVersion: normalizerVersion,
          analyzerVersion: analyzerVersion,
          status: AnalysisRunStatus.failed,
          completedAt: share.receivedAt,
          evidence: const [],
          productMentions: const [],
          statements: const [],
          disclosure: DisclosureObservation.unknown,
          failureCode: 'empty_input',
        ),
      );
    }

    final extraction = _extract(
      captureId: raw.id,
      text: normalizedText,
      completedAt: share.receivedAt,
    );
    final status = completeness == MaterialCompleteness.linkOnly
        ? CaptureStatus.sourceLimited
        : CaptureStatus.needsReview;

    return CaptureRecord(
      raw: raw,
      normalized: normalized,
      status: status,
      analysis: AnalysisRun(
        id: 'analysis-${share.id}',
        inputId: raw.id,
        normalizerVersion: normalizerVersion,
        analyzerVersion: analyzerVersion,
        status: AnalysisRunStatus.succeeded,
        completedAt: share.receivedAt,
        evidence: extraction.evidence,
        productMentions: [extraction.mention],
        statements: extraction.statements,
        disclosure: completeness == MaterialCompleteness.linkOnly
            ? DisclosureObservation.unknown
            : extraction.disclosure,
      ),
    );
  }

  static String canonicalizeUrl(String rawValue) {
    final trimmed = rawValue.replaceFirst(RegExp(r'''[),.!?'"]+$'''), '');
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return trimmed;
    }

    final filteredQuery = <String, String>{};
    final entries = uri.queryParameters.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in entries) {
      final key = entry.key.toLowerCase();
      if (key.startsWith('utm_') ||
          const {'fbclid', 'gclid', 'igshid', 'si'}.contains(key)) {
        continue;
      }
      filteredQuery[entry.key] = entry.value;
    }

    final isDefaultPort =
        (uri.scheme.toLowerCase() == 'https' && uri.port == 443) ||
        (uri.scheme.toLowerCase() == 'http' && uri.port == 80);
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      userInfo: uri.userInfo,
      host: uri.host.toLowerCase(),
      port: uri.hasPort && !isDefaultPort ? uri.port : null,
      path: uri.path,
      queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
    ).toString();
  }

  static SourcePlatform platformForUrl(String rawValue) {
    final host = Uri.tryParse(rawValue)?.host.toLowerCase() ?? '';
    if (host.contains('instagram.com')) {
      return SourcePlatform.instagram;
    }
    if (host.contains('youtube.com') || host == 'youtu.be') {
      return SourcePlatform.youtube;
    }
    if (host.contains('tiktok.com')) {
      return SourcePlatform.tiktok;
    }
    if (host == 'x.com' ||
        host.endsWith('.x.com') ||
        host.contains('twitter.com')) {
      return SourcePlatform.x;
    }
    return host.isEmpty ? SourcePlatform.textOnly : SourcePlatform.web;
  }

  static String semanticFingerprint(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  _Extraction _extract({
    required String captureId,
    required String text,
    required DateTime completedAt,
  }) {
    final lowerText = text.toLowerCase();
    final rule = _productRules.cast<_ProductRule?>().firstWhere(
      (candidate) =>
          candidate!.aliases.any((alias) => lowerText.contains(alias)),
      orElse: () => null,
    );

    final markerBrand = _markerValue(text, '브랜드');
    final markerName = _markerValue(text, '제품명') ?? _markerValue(text, '제품');
    final detectedCategory = _findCategory(lowerText);
    final genericCandidate = rule == null && markerName == null
        ? _inferGenericProduct(text, detectedCategory)
        : null;
    final brand = rule?.brand ?? markerBrand ?? genericCandidate?.brand;
    final name = rule?.name ?? markerName ?? genericCandidate?.name;
    final category =
        rule?.category ?? detectedCategory ?? genericCandidate?.category;
    final amount = _findAmount(text);
    final evidence = <EvidenceRef>[];

    List<String> evidenceFor(String? value, String field) {
      if (value == null || value.isEmpty) {
        return const [];
      }
      final index = lowerText.indexOf(value.toLowerCase());
      final id = 'evidence-$captureId-$field';
      evidence.add(
        EvidenceRef(
          id: id,
          captureId: captureId,
          kind: EvidenceKind.sharedText,
          quote: index == -1
              ? text
              : text.substring(index, index + value.length),
          startOffset: index == -1 ? null : index,
          endOffset: index == -1 ? null : index + value.length,
        ),
      );
      return [id];
    }

    final missingFields = <MissingField>{
      if (brand == null || brand.isEmpty) MissingField.brand,
      if (name == null || name.isEmpty) MissingField.productName,
      if (category == null || category.isEmpty) MissingField.category,
      if (amount == null || amount.isEmpty) MissingField.amount,
    };
    final confidence = rule != null
        ? (missingFields.isEmpty ? 0.94 : 0.86)
        : genericCandidate != null
        ? switch ((brand != null, name != null, amount != null)) {
            (true, true, true) => 0.72,
            (true, true, false) => 0.64,
            (_, true, _) => 0.52,
            _ => 0.34,
          }
        : switch ((brand != null, name != null, category != null)) {
            (true, true, _) => 0.78,
            (_, true, true) => 0.66,
            (_, _, true) => 0.48,
            _ => 0.25,
          };
    final origin = rule == null
        ? FieldOrigin.deterministicRule
        : FieldOrigin.catalogMatch;
    final mentionId = 'mention-$captureId-0';
    final mention = ProductMention(
      id: mentionId,
      brand: ExtractedField(
        value: brand,
        confidence: brand == null ? 0 : confidence,
        origin: origin,
        evidenceIds: evidenceFor(brand, 'brand'),
      ),
      name: ExtractedField(
        value: name,
        confidence: name == null ? 0 : confidence,
        origin: origin,
        evidenceIds: evidenceFor(name, 'name'),
      ),
      category: ExtractedField(
        value: category,
        confidence: category == null ? 0 : confidence,
        origin: origin,
        evidenceIds: evidenceFor(category, 'category'),
      ),
      amount: ExtractedField(
        value: amount,
        confidence: amount == null ? 0 : confidence,
        origin: origin,
        evidenceIds: evidenceFor(amount, 'amount'),
      ),
      overallConfidence: confidence,
      missingFields: missingFields,
    );

    final statements = <ContentStatement>[];
    final sentenceParts = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty);
    var statementIndex = 0;
    for (final sentence in sentenceParts) {
      final topics = _topicsFor(sentence.toLowerCase());
      if (topics.isEmpty) {
        continue;
      }
      final evidenceId = 'evidence-$captureId-sentence-$statementIndex';
      final start = text.indexOf(sentence);
      evidence.add(
        EvidenceRef(
          id: evidenceId,
          captureId: captureId,
          kind: EvidenceKind.sharedText,
          quote: sentence,
          startOffset: start == -1 ? null : start,
          endOffset: start == -1 ? null : start + sentence.length,
        ),
      );
      for (final topic in topics) {
        statements.add(
          ContentStatement(
            id: 'statement-$captureId-$statementIndex',
            captureId: captureId,
            mentionId: mentionId,
            type: _statementTypeFor(sentence.toLowerCase()),
            topic: topic,
            originalExpression: sentence,
            evidenceIds: [evidenceId],
          ),
        );
        statementIndex += 1;
      }
    }

    final disclosureMatch = RegExp(
      r'(#광고|유료\s*광고|협찬|제품\s*제공)',
      caseSensitive: false,
    ).firstMatch(text);
    final disclosure = disclosureMatch == null
        ? DisclosureObservation.notObservedInCapturedMaterial
        : DisclosureObservation.explicitlyObserved;
    if (disclosureMatch != null) {
      final quote = disclosureMatch.group(0)!;
      final evidenceId = 'evidence-$captureId-disclosure';
      evidence.add(
        EvidenceRef(
          id: evidenceId,
          captureId: captureId,
          kind: EvidenceKind.sharedText,
          quote: quote,
          startOffset: disclosureMatch.start,
          endOffset: disclosureMatch.end,
        ),
      );
      statements.add(
        ContentStatement(
          id: 'statement-$captureId-disclosure',
          captureId: captureId,
          mentionId: mentionId,
          type: StatementType.disclosure,
          topic: '광고·협찬 표시',
          originalExpression: quote,
          evidenceIds: [evidenceId],
        ),
      );
    }

    return _Extraction(
      mention: mention,
      evidence: evidence,
      statements: statements,
      disclosure: disclosure,
    );
  }

  static String _normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  static List<String> _extractUrls(String text) {
    return RegExp(r'https?://[^\s]+')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .map((url) => url.replaceFirst(RegExp(r'''[),.!?'"]+$'''), ''))
        .toSet()
        .toList(growable: true);
  }

  static String? _markerValue(String text, String marker) {
    final match = RegExp(
      '$marker\\s*[:：]\\s*([^\\n,|]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static String? _findAmount(String text) {
    final match = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(mL|ml|g)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}${match.group(2)!.toLowerCase() == 'g' ? 'g' : 'mL'}';
  }

  static String? _findCategory(String text) {
    const categoryAliases = <String, String>{
      '선 플루이드': '선케어',
      '선플루이드': '선케어',
      '선 세럼': '선케어',
      '선세럼': '선케어',
      '선 크림': '선케어',
      '선크림': '선케어',
      '선 스틱': '선케어',
      '선스틱': '선케어',
      '선 쿠션': '선케어',
      '선쿠션': '선케어',
      '선케어': '선케어',
      '클렌징 오일': '클렌저',
      '클렌징 폼': '클렌저',
      '클렌저': '클렌저',
      '에센스': '에센스',
      '에멀전': '에멀전',
      '로션': '로션',
      '세럼': '세럼',
      '앰플': '앰플',
      '토너': '토너',
      '크림': '크림',
      '마스크': '마스크',
    };
    for (final entry in categoryAliases.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static _GenericProductCandidate? _inferGenericProduct(
    String text,
    String? category,
  ) {
    if (category == null) {
      return null;
    }

    final materialText = text
        .replaceAll(RegExp(r'https?://[^\s]+'), ' ')
        .replaceAll(
          RegExp(r'(#광고|유료\s*광고|협찬|제품\s*제공)', caseSensitive: false),
          ' ',
        );
    final categoryPattern = switch (category) {
      '선케어' => r'(?:선\s*(?:플루이드|세럼|크림|스틱|쿠션)|선케어|선크림)',
      '클렌저' => r'(?:클렌징\s*(?:오일|폼)|클렌저)',
      _ => RegExp.escape(category),
    };
    final match = RegExp(
      '([가-힣A-Za-z0-9&+.-]+(?:\\s+[가-힣A-Za-z0-9&+.-]+){0,5}\\s*$categoryPattern)',
      caseSensitive: false,
    ).firstMatch(materialText);
    if (match == null) {
      return null;
    }

    var tokens = match
        .group(1)!
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: true);
    while (tokens.length > 4) {
      tokens.removeAt(0);
    }
    const leadingStopwords = {
      '오늘',
      '요즘',
      '최근',
      '이번',
      '제가',
      '내가',
      '직접',
      '써본',
      '사용한',
      '사용해본',
      '추천',
      '추천한',
      '추천하는',
    };
    while (tokens.length > 1 && leadingStopwords.contains(tokens.first)) {
      tokens.removeAt(0);
    }
    if (tokens.isEmpty) {
      return null;
    }

    final first = tokens.first;
    final looksLikeDescription =
        const {'가벼운', '촉촉한', '산뜻한', '순한', '좋은', '데일리'}.contains(first) ||
        RegExp(r'(하고|하고요|한|한데|해서|되는)$').hasMatch(first);
    final hasBrandCandidate = tokens.length >= 2 && !looksLikeDescription;
    final brand = hasBrandCandidate ? first : null;
    final nameTokens = hasBrandCandidate ? tokens.sublist(1) : tokens;
    final name = nameTokens.join(' ').trim();
    if (name.isEmpty) {
      return null;
    }
    return _GenericProductCandidate(
      brand: brand,
      name: name,
      category: category,
    );
  }

  static List<String> _topicsFor(String sentence) {
    const topics = <String, List<String>>{
      '가벼운 사용감': ['가볍', '산뜻'],
      '보습': ['보습', '속건조', '촉촉'],
      '진정': ['진정', '붉은기'],
      '피지·모공': ['피지', '모공'],
      '백탁': ['백탁'],
      '밀림': ['밀림', '밀려'],
      '자극 언급': ['자극', '따가'],
    };
    return topics.entries
        .where((entry) => entry.value.any(sentence.contains))
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  static StatementType _statementTypeFor(String sentence) {
    if (const ['아쉽', '밀림', '밀려', '자극', '따가'].any(sentence.contains)) {
      return StatementType.drawback;
    }
    if (const ['사용했', '써보', '발라보'].any(sentence.contains)) {
      return StatementType.usageExperience;
    }
    if (const ['바른', '사용법', '순서'].any(sentence.contains)) {
      return StatementType.usageMethod;
    }
    return StatementType.creatorClaim;
  }
}

final class _Extraction {
  const _Extraction({
    required this.mention,
    required this.evidence,
    required this.statements,
    required this.disclosure,
  });

  final ProductMention mention;
  final List<EvidenceRef> evidence;
  final List<ContentStatement> statements;
  final DisclosureObservation disclosure;
}

final class _ProductRule {
  const _ProductRule({
    required this.aliases,
    required this.brand,
    required this.name,
    required this.category,
  });

  final List<String> aliases;
  final String brand;
  final String name;
  final String category;
}

final class _GenericProductCandidate {
  const _GenericProductCandidate({
    required this.brand,
    required this.name,
    required this.category,
  });

  final String? brand;
  final String name;
  final String category;
}

const _productRules = <_ProductRule>[
  _ProductRule(
    aliases: ['포어 밸런스 세럼', 'baumlab pore balance'],
    brand: '바움랩',
    name: '포어 밸런스 세럼',
    category: '세럼',
  ),
  _ProductRule(
    aliases: ['카밍 앰플', 'leafon calming'],
    brand: '리프온',
    name: '카밍 앰플',
    category: '앰플',
  ),
  _ProductRule(
    aliases: ['하이드라 세럼', 'slowbreeze hydra'],
    brand: '슬로우브리즈',
    name: '하이드라 세럼',
    category: '세럼',
  ),
  _ProductRule(
    aliases: ['에어리 선 플루이드', 'daylight airy sun'],
    brand: '데이라이트',
    name: '에어리 선 플루이드',
    category: '선케어',
  ),
];
