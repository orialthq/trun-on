enum CaptureOrigin { androidShare, manual, portableTip, demo }

enum CaptureStatus {
  received,
  sourceLimited,
  analyzing,
  needsReview,
  organized,
  failed,
}

enum CaptureFilter { all, needsReview, organized, limitedOrFailed }

enum SourcePlatform { instagram, youtube, tiktok, x, web, textOnly }

enum MaterialCompleteness { complete, partial, linkOnly }

enum AnalysisRunStatus { succeeded, failed }

enum FieldOrigin { deterministicRule, catalogMatch, user }

enum EvidenceKind { sharedText, url, userInput, ocrText, imageRegion }

enum ShareKind { text, image }

enum ContentDomain { beauty, food, unknown }

enum ContentFolder {
  beauty,
  healthFitness,
  restaurantCafe,
  recipe,
  shopping,
  travelPlace,
  lifeTip,
  other,
  needsClassification,
}

// `~` is allowed so a price band reads as 2~5만원 rather than 25만원.
final _contentSubcategoryPattern = RegExp(
  r'^[가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9]+(?:[ ·ㆍ&/+~\-][가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9]+)*$',
);

/// Keeps AI and user-created subcategory names concise and safe to display.
String normalizeContentSubcategory(String value) {
  final collapsed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final sanitized = collapsed
      .replaceAll(RegExp(r'[^0-9A-Za-z가-힣ㄱ-ㅎㅏ-ㅣ·ㆍ&/+~\- ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (sanitized.isEmpty) {
    return '기타';
  }
  final concise = String.fromCharCodes(sanitized.runes.take(20));
  return concise.runes.length < 2 ? '기타' : concise;
}

bool isValidContentSubcategory(String value) {
  final length = value.runes.length;
  return length >= 2 &&
      length <= 20 &&
      value == normalizeContentSubcategory(value) &&
      _contentSubcategoryPattern.hasMatch(value);
}

enum ContentKind {
  beautyProduct,
  recipe,
  sauceRecipe,
  commerceProduct,
  productReview,
  menuComparison,
  place,
  unknown,
}

enum PlaceCategory {
  restaurant,
  cafe,
  beauty,
  shopping,
  lodging,
  activity,
  other,
}

enum StructuredCompleteness {
  complete,
  partial,
  conflicted,
  needsReview,
  unsupported,
}

enum ObservedStatus { observed, inferred, missing }

enum MissingField { brand, productName, category, amount }

enum StatementType {
  creatorClaim,
  usageExperience,
  usageMethod,
  drawback,
  disclosure,
}

enum DisclosureObservation {
  explicitlyObserved,
  notObservedInCapturedMaterial,
  unknown,
}

enum ReviewResolution { confirmed, corrected, unresolved, deferred }

enum ConfidenceBand { high, reviewRecommended, reviewRequired }

final class IncomingAttachment {
  const IncomingAttachment({
    required this.id,
    required this.filePath,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    this.width,
    this.height,
  });

  factory IncomingAttachment.fromPlatformMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final filePath = map['filePath'];
    final mimeType = map['mimeType'];
    final byteSize = map['byteSize'];
    final sha256 = map['sha256'];
    if (id is! String ||
        id.isEmpty ||
        filePath is! String ||
        filePath.isEmpty ||
        mimeType is! String ||
        !mimeType.startsWith('image/') ||
        byteSize is! int ||
        byteSize <= 0 ||
        sha256 is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('Incoming attachment is invalid.');
    }
    return IncomingAttachment(
      id: id,
      filePath: filePath,
      mimeType: mimeType,
      byteSize: byteSize,
      sha256: sha256,
      width: map['width'] as int?,
      height: map['height'] as int?,
    );
  }

  final String id;
  final String filePath;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
  final String sha256;

  Map<String, Object?> toJson() => {
    'id': id,
    'filePath': filePath,
    'mimeType': mimeType,
    'byteSize': byteSize,
    'width': width,
    'height': height,
    'sha256': sha256,
  };

  factory IncomingAttachment.fromJson(Map<String, Object?> json) {
    return IncomingAttachment.fromPlatformMap(json);
  }
}

final class IncomingShare {
  const IncomingShare({
    required this.id,
    required this.receivedAt,
    required this.sharedText,
    required this.discoveredUrl,
    this.sourcePackage,
    this.mimeType = 'text/plain',
    this.wasTruncated = false,
    this.originalLength,
    this.shareKind = ShareKind.text,
    this.attachments = const [],
    this.sourceDeletionAvailable = false,
  });

  factory IncomingShare.fromPlatformMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final receivedAtEpochMs = map['receivedAtEpochMs'];
    final sharedText = map['sharedText'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Incoming share id is missing.');
    }
    if (receivedAtEpochMs is! int) {
      throw const FormatException('Incoming share timestamp is invalid.');
    }
    if (sharedText is! String) {
      throw const FormatException('Incoming share text is invalid.');
    }

    final rawUrl = map['discoveredUrl'];
    final rawOriginalLength = map['originalLength'];
    final rawAttachments = map['attachments'];
    final attachments = rawAttachments is List<Object?>
        ? rawAttachments
              .whereType<Map<Object?, Object?>>()
              .map(IncomingAttachment.fromPlatformMap)
              .toList(growable: false)
        : const <IncomingAttachment>[];
    final rawShareKind = map['shareKind'];
    final shareKind =
        rawShareKind == ShareKind.image.name || attachments.isNotEmpty
        ? ShareKind.image
        : ShareKind.text;

    return IncomingShare(
      id: id,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedAtEpochMs),
      sharedText: sharedText,
      discoveredUrl: rawUrl is String ? rawUrl : extractFirstUrl(sharedText),
      sourcePackage: map['sourcePackage'] as String?,
      mimeType: map['mimeType'] as String? ?? 'text/plain',
      wasTruncated: map['wasTruncated'] as bool? ?? false,
      originalLength: rawOriginalLength is int
          ? rawOriginalLength
          : sharedText.length,
      shareKind: shareKind,
      attachments: attachments,
      sourceDeletionAvailable: map['sourceDeletionAvailable'] == true,
    );
  }

  final String id;
  final DateTime receivedAt;
  final String sharedText;
  final String? discoveredUrl;
  final String? sourcePackage;
  final String mimeType;
  final bool wasTruncated;
  final int? originalLength;
  final ShareKind shareKind;
  final List<IncomingAttachment> attachments;
  final bool sourceDeletionAvailable;

  static String? extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    return match?.group(0)?.replaceFirst(RegExp(r'''[),.!?'"]+$'''), '');
  }
}

final class RawCapture {
  const RawCapture({
    required this.id,
    required this.transportEventId,
    required this.receivedAt,
    required this.origin,
    required this.mimeType,
    required this.rawText,
    required this.rawUrl,
    required this.semanticFingerprint,
    required this.wasTruncated,
    required this.originalLength,
    this.sourcePackage,
    this.userNote,
    this.attachments = const [],
  });

  final String id;
  final String transportEventId;
  final DateTime receivedAt;
  final CaptureOrigin origin;
  final String mimeType;

  /// Immutable user-provided material. Normalization never mutates this value.
  final String rawText;
  final String? rawUrl;
  final String semanticFingerprint;
  final bool wasTruncated;
  final int originalLength;
  final String? sourcePackage;
  final String? userNote;
  final List<IncomingAttachment> attachments;
}

final class NormalizedUrl {
  const NormalizedUrl({
    required this.rawValue,
    required this.canonicalValue,
    required this.platform,
  });

  final String rawValue;
  final String canonicalValue;
  final SourcePlatform platform;
}

final class NormalizedInput {
  const NormalizedInput({
    required this.inputId,
    required this.normalizerVersion,
    required this.normalizedText,
    required this.urls,
    required this.semanticFingerprint,
    required this.completeness,
    required this.warnings,
  });

  final String inputId;
  final String normalizerVersion;
  final String normalizedText;
  final List<NormalizedUrl> urls;
  final String semanticFingerprint;
  final MaterialCompleteness completeness;
  final List<String> warnings;
}

final class EvidenceRef {
  const EvidenceRef({
    required this.id,
    required this.captureId,
    required this.kind,
    required this.quote,
    this.startOffset,
    this.endOffset,
    this.attachmentId,
    this.region,
  });

  final String id;
  final String captureId;
  final EvidenceKind kind;
  final String quote;
  final int? startOffset;
  final int? endOffset;
  final String? attachmentId;
  final String? region;
}

final class ExtractedField<T> {
  const ExtractedField({
    required this.value,
    required this.confidence,
    required this.origin,
    required this.evidenceIds,
  }) : assert(confidence >= 0 && confidence <= 1);

  final T? value;
  final double confidence;
  final FieldOrigin origin;
  final List<String> evidenceIds;

  ConfidenceBand get confidenceBand {
    if (confidence >= 0.85) {
      return ConfidenceBand.high;
    }
    if (confidence >= 0.6) {
      return ConfidenceBand.reviewRecommended;
    }
    return ConfidenceBand.reviewRequired;
  }
}

final class ProductMention {
  const ProductMention({
    required this.id,
    required this.brand,
    required this.name,
    required this.category,
    required this.amount,
    required this.overallConfidence,
    required this.missingFields,
  }) : assert(overallConfidence >= 0 && overallConfidence <= 1);

  final String id;
  final ExtractedField<String> brand;
  final ExtractedField<String> name;
  final ExtractedField<String> category;
  final ExtractedField<String> amount;
  final double overallConfidence;
  final Set<MissingField> missingFields;

  ConfidenceBand get confidenceBand {
    if (overallConfidence >= 0.85) {
      return ConfidenceBand.high;
    }
    if (overallConfidence >= 0.6) {
      return ConfidenceBand.reviewRecommended;
    }
    return ConfidenceBand.reviewRequired;
  }

  bool get canGroupAutomatically =>
      overallConfidence >= 0.85 && missingFields.isEmpty;
}

final class ContentStatement {
  const ContentStatement({
    required this.id,
    required this.captureId,
    required this.mentionId,
    required this.type,
    required this.topic,
    required this.originalExpression,
    required this.evidenceIds,
  });

  final String id;
  final String captureId;
  final String? mentionId;
  final StatementType type;
  final String topic;
  final String originalExpression;
  final List<String> evidenceIds;
}

final class AnalysisRun {
  const AnalysisRun({
    required this.id,
    required this.inputId,
    required this.normalizerVersion,
    required this.analyzerVersion,
    required this.status,
    required this.completedAt,
    required this.evidence,
    required this.productMentions,
    required this.statements,
    required this.disclosure,
    this.failureCode,
    this.model,
    this.startedAt,
    this.attempt = 1,
    this.structuredContent,
  });

  final String id;
  final String inputId;
  final String normalizerVersion;
  final String analyzerVersion;
  final AnalysisRunStatus status;
  final DateTime completedAt;
  final List<EvidenceRef> evidence;
  final List<ProductMention> productMentions;
  final List<ContentStatement> statements;
  final DisclosureObservation disclosure;
  final String? failureCode;
  final String? model;
  final DateTime? startedAt;
  final int attempt;
  final StructuredContentAnalysis? structuredContent;
}

final class StructuredTitle {
  const StructuredTitle({
    required this.value,
    required this.status,
    required this.confidence,
    required this.evidenceIds,
  }) : assert(confidence >= 0 && confidence <= 1);

  factory StructuredTitle.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'value',
      'status',
      'confidence',
      'evidenceIds',
    }, 'title');
    final value = _nullableString(json['value'], 'title.value');
    final status = _observedStatus(json['status']);
    if ((status == ObservedStatus.missing && value != null) ||
        (status != ObservedStatus.missing && value == null)) {
      throw const FormatException('Structured title status is inconsistent.');
    }
    return StructuredTitle(
      value: value,
      status: status,
      confidence: _confidence(json['confidence'], 'title.confidence'),
      evidenceIds: _strictStringList(json['evidenceIds'], 'title.evidenceIds'),
    );
  }

  final String? value;
  final ObservedStatus status;
  final double confidence;
  final List<String> evidenceIds;

  Map<String, Object?> toJson() => {
    'value': value,
    'status': status.name,
    'confidence': confidence,
    'evidenceIds': evidenceIds,
  };
}

final class StructuredEvidence {
  const StructuredEvidence({
    required this.id,
    required this.text,
    required this.region,
    required this.confidence,
  }) : assert(confidence >= 0 && confidence <= 1);

  factory StructuredEvidence.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'id',
      'text',
      'region',
      'confidence',
    }, 'evidence');
    final region = _requiredString(json['region'], 'evidence.region');
    if (!const {
      'image_text',
      'caption',
      'overlay',
      'product_panel',
      'menu',
      'unknown',
    }.contains(region)) {
      throw const FormatException('Structured evidence.region is invalid.');
    }
    return StructuredEvidence(
      id: _requiredString(json['id'], 'evidence.id'),
      text: _requiredString(json['text'], 'evidence.text'),
      region: region,
      confidence: _confidence(json['confidence'], 'evidence.confidence'),
    );
  }

  final String id;
  final String text;
  final String region;
  final double confidence;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'region': region,
    'confidence': confidence,
  };
}

final class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.preparation,
    required this.optional,
    required this.originalText,
    required this.confidence,
    required this.evidenceIds,
  }) : assert(confidence >= 0 && confidence <= 1);

  factory RecipeIngredient.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'name',
      'amount',
      'unit',
      'preparation',
      'optional',
      'originalText',
      'confidence',
      'evidenceIds',
    }, 'ingredient');
    final optional = json['optional'];
    if (optional is! bool) {
      throw const FormatException('Structured ingredient.optional is invalid.');
    }
    return RecipeIngredient(
      name: _requiredString(json['name'], 'ingredient.name'),
      amount: _nullableString(json['amount'], 'ingredient.amount'),
      unit: _nullableString(json['unit'], 'ingredient.unit'),
      preparation: _nullableString(
        json['preparation'],
        'ingredient.preparation',
      ),
      optional: optional,
      originalText: _requiredString(
        json['originalText'],
        'ingredient.originalText',
      ),
      confidence: _confidence(json['confidence'], 'ingredient.confidence'),
      evidenceIds: _strictStringList(
        json['evidenceIds'],
        'ingredient.evidenceIds',
      ),
    );
  }

  final String name;
  final String? amount;
  final String? unit;
  final String? preparation;
  final bool optional;
  final String originalText;
  final double confidence;
  final List<String> evidenceIds;

  Map<String, Object?> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'preparation': preparation,
    'optional': optional,
    'originalText': originalText,
    'confidence': confidence,
    'evidenceIds': evidenceIds,
  };
}

final class IngredientGroup {
  const IngredientGroup({required this.name, required this.ingredients});

  factory IngredientGroup.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {'name', 'ingredients'}, 'ingredientGroup');
    return IngredientGroup(
      name: _requiredString(json['name'], 'ingredientGroup.name'),
      ingredients: _strictMapList(
        json['ingredients'],
        'ingredientGroup.ingredients',
      ).map(RecipeIngredient.fromJson).toList(growable: false),
    );
  }

  final String name;
  final List<RecipeIngredient> ingredients;

  Map<String, Object?> toJson() => {
    'name': name,
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
  };
}

final class RecipeStep {
  const RecipeStep({
    required this.order,
    required this.instruction,
    required this.durationSeconds,
    required this.temperature,
    required this.evidenceIds,
  });

  factory RecipeStep.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'order',
      'instruction',
      'durationSeconds',
      'temperature',
      'evidenceIds',
    }, 'step');
    final order = json['order'];
    final durationSeconds = json['durationSeconds'];
    if (order is! int || order < 1) {
      throw const FormatException('Structured step.order is invalid.');
    }
    if (durationSeconds != null &&
        (durationSeconds is! int || durationSeconds < 0)) {
      throw const FormatException(
        'Structured step.durationSeconds is invalid.',
      );
    }
    return RecipeStep(
      order: order,
      instruction: _requiredString(json['instruction'], 'step.instruction'),
      durationSeconds: durationSeconds as int?,
      temperature: _nullableString(json['temperature'], 'step.temperature'),
      evidenceIds: _strictStringList(json['evidenceIds'], 'step.evidenceIds'),
    );
  }

  final int order;
  final String instruction;
  final int? durationSeconds;
  final String? temperature;
  final List<String> evidenceIds;

  Map<String, Object?> toJson() => {
    'order': order,
    'instruction': instruction,
    'durationSeconds': durationSeconds,
    'temperature': temperature,
    'evidenceIds': evidenceIds,
  };
}

final class AnalysisFact {
  const AnalysisFact({
    required this.label,
    required this.value,
    required this.confidence,
    required this.evidenceIds,
  }) : assert(confidence >= 0 && confidence <= 1);

  factory AnalysisFact.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'label',
      'value',
      'confidence',
      'evidenceIds',
    }, 'fact');
    return AnalysisFact(
      label: _requiredString(json['label'], 'fact.label'),
      value: _requiredString(json['value'], 'fact.value'),
      confidence: _confidence(json['confidence'], 'fact.confidence'),
      evidenceIds: _strictStringList(json['evidenceIds'], 'fact.evidenceIds'),
    );
  }

  final String label;
  final String value;
  final double confidence;
  final List<String> evidenceIds;

  Map<String, Object?> toJson() => {
    'label': label,
    'value': value,
    'confidence': confidence,
    'evidenceIds': evidenceIds,
  };
}

final class AnalysisConflict {
  const AnalysisConflict({
    required this.field,
    required this.details,
    required this.evidenceIds,
  });

  factory AnalysisConflict.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'field',
      'details',
      'evidenceIds',
    }, 'conflict');
    return AnalysisConflict(
      field: _requiredString(json['field'], 'conflict.field'),
      details: _requiredString(json['details'], 'conflict.details'),
      evidenceIds: _strictStringList(
        json['evidenceIds'],
        'conflict.evidenceIds',
      ),
    );
  }

  final String field;
  final String details;
  final List<String> evidenceIds;

  Map<String, Object?> toJson() => {
    'field': field,
    'details': details,
    'evidenceIds': evidenceIds,
  };
}

final class StructuredPlace {
  const StructuredPlace({
    required this.name,
    required this.address,
    required this.searchArea,
    required this.category,
    required this.confidence,
    required this.evidenceIds,
  });

  factory StructuredPlace.fromJson(Map<String, Object?> json) {
    _requireExactKeys(
      json,
      const {'name', 'address', 'category', 'confidence', 'evidenceIds'},
      'place',
      // Added after the first captures were stored; those snapshots fall back to
      // deriving an area from the address.
      optional: const {'searchArea'},
    );
    return StructuredPlace(
      name: _nullableString(json['name'], 'place.name'),
      address: _nullableString(json['address'], 'place.address'),
      searchArea: _nullableString(json['searchArea'], 'place.searchArea'),
      category: _placeCategory(json['category']),
      confidence: _confidence(json['confidence'], 'place.confidence'),
      evidenceIds: _strictStringList(json['evidenceIds'], 'place.evidenceIds'),
    );
  }

  final String? name;
  final String? address;

  /// The words to search alongside the shop name, exactly as a person would type
  /// them: `성수`, `가로수길`, `홍대`. Read from the capture rather than derived,
  /// so a colloquial area beats the administrative district it sits in.
  final String? searchArea;

  final PlaceCategory? category;
  final double confidence;
  final List<String> evidenceIds;

  bool get hasAddress => address?.trim().isNotEmpty == true;

  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'searchArea': searchArea,
    'category': category?.name,
    'confidence': confidence,
    'evidenceIds': evidenceIds,
  };
}

/// The five fixed axes a saved capture is filed under.
///
/// Fixed because the library's filter row is fixed; a new axis is a product
/// decision, not something an analysis may invent.
enum ContentAxis {
  kind('종류'),
  location('위치'),
  access('예약·대기'),
  savedReason('저장이유');

  const ContentAxis(this.label);

  final String label;

  static ContentAxis? fromKey(Object? key) {
    for (final axis in values) {
      if (axis.name == key) return axis;
    }
    return null;
  }
}

/// Where a label came from, so a suggestion is never mistaken for a decision,
/// and a web finding is never mistaken for something the screenshot showed.
enum AxisLabelSource { screen, user, web }

final class AxisLabel {
  const AxisLabel({
    required this.value,
    required this.confidence,
    required this.evidenceIds,
    this.source = AxisLabelSource.screen,
    this.quotes = const [],
    this.citations = const [],
  });

  factory AxisLabel.fromJson(Map<String, Object?> json, String field) {
    _requireExactKeys(
      json,
      const {'value', 'confidence', 'evidenceIds'},
      field,
      optional: const {'source', 'quotes', 'citations'},
    );
    final value = _requiredString(json['value'], '$field.value');
    if (!isValidContentSubcategory(value)) {
      throw FormatException('Structured $field.value is not a reusable label.');
    }
    return AxisLabel(
      value: value,
      confidence: _confidence(json['confidence'], '$field.confidence'),
      evidenceIds: _strictStringList(json['evidenceIds'], '$field.evidenceIds'),
      source: switch (json['source']) {
        'user' => AxisLabelSource.user,
        'web' => AxisLabelSource.web,
        _ => AxisLabelSource.screen,
      },
      quotes: _optionalStringList(json['quotes'], '$field.quotes'),
      citations: _optionalStringList(json['citations'], '$field.citations'),
    );
  }

  final String value;
  final double confidence;
  final List<String> evidenceIds;
  final AxisLabelSource source;

  /// The text this label was read from — menu lines on the screenshot, or the
  /// sentence a web page stated. A label with nothing to quote is a guess, so
  /// the server drops those before they arrive.
  final List<String> quotes;

  /// Pages a web label came from. Empty for a screen label, which is backed by
  /// [evidenceIds] instead.
  final List<String> citations;

  Map<String, Object?> toJson() => {
    'value': value,
    'confidence': confidence,
    'evidenceIds': evidenceIds,
    'source': source.name,
    'quotes': quotes,
    'citations': citations,
  };
}

final class ContentAxes {
  const ContentAxes({required this.labels});

  const ContentAxes.empty() : labels = const {};

  factory ContentAxes.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'kind',
      'location',
      'access',
      'savedReason',
    }, 'axes');
    final labels = <ContentAxis, List<AxisLabel>>{};
    for (final axis in ContentAxis.values) {
      final raw = _strictMapList(json[axis.name], 'axes.${axis.name}');
      final seen = <String>{};
      final parsed = <AxisLabel>[];
      for (var index = 0; index < raw.length; index++) {
        final label = AxisLabel.fromJson(
          raw[index],
          'axes.${axis.name}[$index]',
        );
        // A repeated label would show the same capture twice on one card.
        if (!seen.add(label.value)) continue;
        parsed.add(label);
      }
      labels[axis] = List.unmodifiable(parsed);
    }
    return ContentAxes(labels: Map.unmodifiable(labels));
  }

  final Map<ContentAxis, List<AxisLabel>> labels;

  List<AxisLabel> operator [](ContentAxis axis) => labels[axis] ?? const [];

  bool get isEmpty => ContentAxis.values.every((axis) => this[axis].isEmpty);

  /// Adds labels found elsewhere without displacing what the screenshot showed.
  ///
  /// Screen labels keep their position at the front of each axis, and an
  /// incoming label whose value is already present is dropped: the same shop
  /// must never appear twice on one card just because two sources agreed.
  ContentAxes mergedWith(ContentAxes other) {
    return ContentAxes(
      labels: Map.unmodifiable({
        for (final axis in ContentAxis.values)
          axis: List<AxisLabel>.unmodifiable([
            ...this[axis],
            for (final label in other[axis])
              if (!this[axis].any((kept) => kept.value == label.value)) label,
          ]),
      }),
    );
  }

  Map<String, Object?> toJson() => {
    for (final axis in ContentAxis.values)
      axis.name: this[axis].map((label) => label.toJson()).toList(),
  };
}

final class StructuredContentAnalysis {
  const StructuredContentAnalysis({
    required this.schemaVersion,
    required this.model,
    required this.domain,
    required this.contentKind,
    required this.primaryCategory,
    required this.categoryConfidence,
    required this.subcategory,
    required this.subcategoryConfidence,
    required this.axes,
    required this.completeness,
    required this.title,
    required this.place,
    required this.summary,
    required this.evidence,
    required this.ingredientGroups,
    required this.steps,
    required this.facts,
    required this.conflicts,
    required this.warnings,
  });

  factory StructuredContentAnalysis.fromJson(Map<String, Object?> json) {
    final normalizedJson = Map<String, Object?>.of(json);
    final declaredVersion = normalizedJson['schemaVersion'];
    normalizedJson.putIfAbsent('place', () => null);
    if (declaredVersion == '1.0') {
      normalizedJson.putIfAbsent(
        'primaryCategory',
        () => _legacyPrimaryCategory(normalizedJson),
      );
      normalizedJson.putIfAbsent(
        'categoryConfidence',
        () => _legacyCategoryConfidence(normalizedJson),
      );
    }
    if (declaredVersion == '1.0' || declaredVersion == '1.1') {
      normalizedJson.putIfAbsent(
        'subcategory',
        () => _legacySubcategory(normalizedJson),
      );
      normalizedJson.putIfAbsent(
        'subcategoryConfidence',
        () => _legacySubcategoryConfidence(normalizedJson),
      );
    }
    if (declaredVersion == '1.0' ||
        declaredVersion == '1.1' ||
        declaredVersion == '1.2') {
      normalizedJson.putIfAbsent('axes', () => _legacyAxes(normalizedJson));
    }
    if (declaredVersion != '1.5') {
      normalizedJson['axes'] = _migratedAxes(normalizedJson['axes']);
    }
    _requireExactKeys(normalizedJson, const {
      'schemaVersion',
      'model',
      'domain',
      'contentKind',
      'primaryCategory',
      'categoryConfidence',
      'subcategory',
      'subcategoryConfidence',
      'axes',
      'completeness',
      'title',
      'place',
      'summary',
      'evidence',
      'ingredientGroups',
      'steps',
      'facts',
      'conflicts',
      'warnings',
    }, 'analysis');
    final schemaVersion = _requiredString(
      normalizedJson['schemaVersion'],
      'analysis.schemaVersion',
    );
    final model = _requiredString(normalizedJson['model'], 'analysis.model');
    if (!const {
          '1.0',
          '1.1',
          '1.2',
          '1.3',
          '1.4',
          '1.5',
        }.contains(schemaVersion) ||
        !const {'gpt-5.6-luna', 'portable-tip-v1'}.contains(model)) {
      throw const FormatException(
        'Structured analysis version or model is unsupported.',
      );
    }
    final result = StructuredContentAnalysis(
      schemaVersion: schemaVersion,
      model: model,
      domain: _contentDomain(normalizedJson['domain']),
      contentKind: _contentKind(normalizedJson['contentKind']),
      primaryCategory: _contentFolder(normalizedJson['primaryCategory']),
      categoryConfidence: _confidence(
        normalizedJson['categoryConfidence'],
        'analysis.categoryConfidence',
      ),
      subcategory: _parsedContentSubcategory(
        normalizedJson['subcategory'],
        schemaVersion: schemaVersion,
      ),
      subcategoryConfidence: _confidence(
        normalizedJson['subcategoryConfidence'],
        'analysis.subcategoryConfidence',
      ),
      axes: ContentAxes.fromJson(_requiredMap(normalizedJson['axes'], 'axes')),
      completeness: _structuredCompleteness(normalizedJson['completeness']),
      title: StructuredTitle.fromJson(
        _requiredMap(normalizedJson['title'], 'title'),
      ),
      place: normalizedJson['place'] == null
          ? null
          : StructuredPlace.fromJson(
              _requiredMap(normalizedJson['place'], 'place'),
            ),
      summary: _stringAllowEmpty(normalizedJson['summary'], 'analysis.summary'),
      evidence: _strictMapList(
        normalizedJson['evidence'],
        'analysis.evidence',
      ).map(StructuredEvidence.fromJson).toList(growable: false),
      ingredientGroups: _strictMapList(
        normalizedJson['ingredientGroups'],
        'analysis.ingredientGroups',
      ).map(IngredientGroup.fromJson).toList(growable: false),
      steps: _strictMapList(
        normalizedJson['steps'],
        'analysis.steps',
      ).map(RecipeStep.fromJson).toList(growable: false),
      facts: _strictMapList(
        normalizedJson['facts'],
        'analysis.facts',
      ).map(AnalysisFact.fromJson).toList(growable: false),
      conflicts: _strictMapList(
        normalizedJson['conflicts'],
        'analysis.conflicts',
      ).map(AnalysisConflict.fromJson).toList(growable: false),
      warnings: _strictStringList(
        normalizedJson['warnings'],
        'analysis.warnings',
      ),
    );
    result._validateEvidenceReferences();
    return result;
  }

  /// A copy carrying merged axes, used when a later pass finds labels the
  /// screenshot could not support.
  StructuredContentAnalysis withAxes(ContentAxes value) =>
      StructuredContentAnalysis(
        schemaVersion: schemaVersion,
        model: model,
        domain: domain,
        contentKind: contentKind,
        primaryCategory: primaryCategory,
        categoryConfidence: categoryConfidence,
        subcategory: subcategory,
        subcategoryConfidence: subcategoryConfidence,
        axes: value,
        completeness: completeness,
        title: title,
        place: place,
        summary: summary,
        evidence: evidence,
        ingredientGroups: ingredientGroups,
        steps: steps,
        facts: facts,
        conflicts: conflicts,
        warnings: warnings,
      );

  final String schemaVersion;
  final String model;
  final ContentDomain domain;
  final ContentKind contentKind;
  final ContentFolder primaryCategory;
  final double categoryConfidence;
  final String subcategory;
  final double subcategoryConfidence;

  /// The five saved-library axes. A capture may sit on several labels of the
  /// same axis, so the cards it appears under deliberately overlap.
  final ContentAxes axes;
  final StructuredCompleteness completeness;
  final StructuredTitle title;
  final StructuredPlace? place;
  final String summary;
  final List<StructuredEvidence> evidence;
  final List<IngredientGroup> ingredientGroups;
  final List<RecipeStep> steps;
  final List<AnalysisFact> facts;
  final List<AnalysisConflict> conflicts;
  final List<String> warnings;

  bool get isRecipe =>
      contentKind == ContentKind.recipe ||
      contentKind == ContentKind.sauceRecipe;

  bool get categoryNeedsReview => categoryConfidence < 0.72;

  void _validateEvidenceReferences() {
    final ids = evidence.map((item) => item.id).toList(growable: false);
    if (ids.toSet().length != ids.length) {
      throw const FormatException(
        'Structured analysis has duplicate evidence ids.',
      );
    }
    final validIds = ids.toSet();
    final references = <String>[
      ...title.evidenceIds,
      ...?place?.evidenceIds,
      for (final group in ingredientGroups)
        for (final ingredient in group.ingredients) ...ingredient.evidenceIds,
      for (final step in steps) ...step.evidenceIds,
      for (final fact in facts) ...fact.evidenceIds,
      for (final conflict in conflicts) ...conflict.evidenceIds,
    ];
    if (references.any((id) => !validIds.contains(id))) {
      throw const FormatException(
        'Structured analysis references unknown evidence.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'model': model,
    'domain': domain.name,
    'contentKind': switch (contentKind) {
      ContentKind.beautyProduct => 'beauty_product',
      ContentKind.sauceRecipe => 'sauce_recipe',
      ContentKind.commerceProduct => 'commerce_product',
      ContentKind.productReview => 'product_review',
      ContentKind.menuComparison => 'menu_comparison',
      ContentKind.place => 'place',
      _ => contentKind.name,
    },
    'primaryCategory': _contentFolderWireName(primaryCategory),
    'categoryConfidence': categoryConfidence,
    'subcategory': subcategory,
    'subcategoryConfidence': subcategoryConfidence,
    'axes': axes.toJson(),
    'completeness': switch (completeness) {
      StructuredCompleteness.needsReview => 'needs_review',
      _ => completeness.name,
    },
    'title': title.toJson(),
    'place': place?.toJson(),
    'summary': summary,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'ingredientGroups': ingredientGroups.map((item) => item.toJson()).toList(),
    'steps': steps.map((item) => item.toJson()).toList(),
    'facts': facts.map((item) => item.toJson()).toList(),
    'conflicts': conflicts.map((item) => item.toJson()).toList(),
    'warnings': warnings,
  };
}

List<Map<String, Object?>> _strictMapList(Object? value, String field) {
  if (value is! List<Object?>) {
    throw FormatException('Structured $field is invalid.');
  }
  final result = <Map<String, Object?>>[];
  for (final item in value) {
    if (item is! Map<String, Object?>) {
      throw FormatException('Structured $field item is invalid.');
    }
    result.add(item);
  }
  return result;
}

Map<String, Object?> _requiredMap(Object? value, String field) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('Structured analysis $field is invalid.');
}

List<String> _strictStringList(Object? value, String field) {
  if (value is! List<Object?> ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    throw FormatException('Structured $field is invalid.');
  }
  return value.cast<String>().toList(growable: false);
}

double _confidence(Object? value, String field) {
  if (value is! num || value < 0 || value > 1) {
    throw FormatException('Structured $field is invalid.');
  }
  return value.toDouble();
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Structured $field is invalid.');
  }
  return value;
}

String _parsedContentSubcategory(
  Object? value, {
  required String schemaVersion,
}) {
  final raw = _requiredString(value, 'analysis.subcategory');
  final normalized = normalizeContentSubcategory(raw);
  if (schemaVersion == '1.2' && !isValidContentSubcategory(raw)) {
    throw const FormatException('Structured analysis.subcategory is invalid.');
  }
  return normalized;
}

String _stringAllowEmpty(Object? value, String field) {
  if (value is! String) {
    throw FormatException('Structured $field is invalid.');
  }
  return value;
}

List<String> _optionalStringList(Object? value, String field) {
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('Structured $field is invalid.');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! String) {
        throw FormatException('Structured $field is invalid.');
      }
      return item;
    }),
  );
}

String? _nullableString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _requiredString(value, field);
}

/// Rejects unknown fields and missing required ones.
///
/// [optional] exists so a field added after a release can be read back from
/// snapshots written before it existed. Unknown keys are still refused, so the
/// contract stays closed.
void _requireExactKeys(
  Map<String, Object?> json,
  Set<String> expected,
  String field, {
  Set<String> optional = const {},
}) {
  final allowed = {...expected, ...optional};
  if (json.keys.any((key) => !allowed.contains(key)) ||
      expected.any((key) => !json.containsKey(key))) {
    throw FormatException('Structured $field has unexpected fields.');
  }
}

ContentDomain _contentDomain(Object? value) {
  return switch (value) {
    'beauty' => ContentDomain.beauty,
    'food' => ContentDomain.food,
    'unknown' => ContentDomain.unknown,
    _ => throw const FormatException('Structured analysis.domain is invalid.'),
  };
}

ContentKind _contentKind(Object? value) {
  return switch (value) {
    'beauty_product' => ContentKind.beautyProduct,
    'recipe' => ContentKind.recipe,
    'sauce_recipe' => ContentKind.sauceRecipe,
    'commerce_product' => ContentKind.commerceProduct,
    'product_review' => ContentKind.productReview,
    'menu_comparison' => ContentKind.menuComparison,
    'place' => ContentKind.place,
    'unknown' => ContentKind.unknown,
    _ => throw const FormatException(
      'Structured analysis.contentKind is invalid.',
    ),
  };
}

ContentFolder _contentFolder(Object? value) {
  return switch (value) {
    'beauty' => ContentFolder.beauty,
    'health_fitness' => ContentFolder.healthFitness,
    'restaurant_cafe' => ContentFolder.restaurantCafe,
    'recipe' => ContentFolder.recipe,
    'shopping' => ContentFolder.shopping,
    'travel_place' => ContentFolder.travelPlace,
    'life_tip' => ContentFolder.lifeTip,
    'other' => ContentFolder.other,
    _ => throw const FormatException(
      'Structured analysis.primaryCategory is invalid.',
    ),
  };
}

String _contentFolderWireName(ContentFolder value) {
  return switch (value) {
    ContentFolder.beauty => 'beauty',
    ContentFolder.healthFitness => 'health_fitness',
    ContentFolder.restaurantCafe => 'restaurant_cafe',
    ContentFolder.recipe => 'recipe',
    ContentFolder.shopping => 'shopping',
    ContentFolder.travelPlace => 'travel_place',
    ContentFolder.lifeTip => 'life_tip',
    ContentFolder.other => 'other',
    ContentFolder.needsClassification => 'other',
  };
}

String _legacyPrimaryCategory(Map<String, Object?> json) {
  final kind = json['contentKind'];
  if (kind == 'recipe' || kind == 'sauce_recipe') {
    return 'recipe';
  }
  final place = json['place'];
  final placeCategory = place is Map<String, Object?>
      ? place['category']
      : null;
  if (placeCategory == 'restaurant' || placeCategory == 'cafe') {
    return 'restaurant_cafe';
  }
  if (placeCategory == 'lodging' || placeCategory == 'activity') {
    return 'travel_place';
  }
  if (placeCategory == 'beauty' || json['domain'] == 'beauty') {
    return 'beauty';
  }
  if (placeCategory == 'shopping') {
    return 'shopping';
  }
  if (kind == 'menu_comparison') {
    return 'restaurant_cafe';
  }
  if (json['domain'] == 'food') {
    return 'shopping';
  }
  return 'other';
}

double _legacyCategoryConfidence(Map<String, Object?> json) {
  return _legacyPrimaryCategory(json) == 'other' ? 0 : 1;
}

/// Rebuilds axes for a capture stored before they existed.
///
/// Only what the older record actually held is carried over: the single
/// subcategory becomes the one kind label, and a place area becomes the one
/// location label. The remaining axes stay empty rather than being guessed from
/// content nobody classified that way.
Map<String, Object?> _legacyAxes(Map<String, Object?> json) {
  Map<String, Object?> label(String value, Object? confidence) => {
    'value': value,
    'confidence': confidence is num ? confidence.toDouble() : 0.0,
    'evidenceIds': const <String>[],
  };

  final kind = <Map<String, Object?>>[];
  final subcategory = json['subcategory'];
  if (subcategory is String && isValidContentSubcategory(subcategory)) {
    kind.add(label(subcategory, json['subcategoryConfidence']));
  }

  final location = <Map<String, Object?>>[];
  final place = json['place'];
  final area = place is Map<String, Object?> ? place['searchArea'] : null;
  if (area is String && isValidContentSubcategory(area)) {
    location.add(
      label(area, place is Map<String, Object?> ? place['confidence'] : 0),
    );
  }

  return {
    'kind': kind,
    'location': location,
    'access': const <Map<String, Object?>>[],
    'savedReason': const <Map<String, Object?>>[],
  };
}

/// Carries a stored capture across every axis change so far.
///
/// 상황 and 가격대 went in 1.4, 인원 in 1.5. Each was dropped rather than
/// remapped: nothing in a 데이트, a 2~5만원, or a 단체 가능 says whether the place
/// takes bookings. Retired labels are discarded and any new axis starts empty,
/// filling on the next web lookup.
///
/// 인원 in particular was not wrong, it was useless — 단체 가능 came back true for
/// all ten shops it was measured on, and a label on every card cannot filter.
///
/// Dropping beats refusing to load. A capture the reader saved is theirs, and
/// losing its title and photo to a schema change they never asked for would be
/// the worse failure.
Map<String, Object?> _migratedAxes(Object? stored) {
  const empty = <Map<String, Object?>>[];
  if (stored is! Map<String, Object?>) {
    return {
      'kind': empty,
      'location': empty,
      'access': empty,
      'savedReason': empty,
    };
  }
  return {
    for (final axis in ContentAxis.values)
      axis.name: stored[axis.name] ?? empty,
  };
}

String _legacySubcategory(Map<String, Object?> json) {
  final kind = json['contentKind'];
  if (kind == 'sauce_recipe') {
    return '소스·양념';
  }
  if (kind == 'recipe') {
    return '요리';
  }

  final place = json['place'];
  final placeCategory = place is Map<String, Object?>
      ? place['category']
      : null;
  final placeSubcategory = switch (placeCategory) {
    'restaurant' => '식당',
    'cafe' => '카페·디저트',
    'beauty' => '뷰티숍',
    'shopping' => '쇼핑 장소',
    'lodging' => '숙소',
    'activity' => '체험',
    'other' => '장소',
    _ => null,
  };
  if (placeSubcategory != null) {
    return placeSubcategory;
  }

  final title = json['title'];
  final titleValue = title is Map<String, Object?>
      ? title['value'] as String?
      : null;
  if (json['domain'] == 'beauty' || kind == 'beauty_product') {
    return _legacyProductSubcategory(
      titleValue,
      preserveUnrecognizedCategory: false,
    );
  }
  if (kind == 'menu_comparison') {
    return '메뉴';
  }
  if (kind == 'commerce_product' || kind == 'product_review') {
    return '상품';
  }
  if (json['domain'] == 'food') {
    return '식품';
  }
  return '기타';
}

double _legacySubcategoryConfidence(Map<String, Object?> json) {
  return _legacySubcategory(json) == '기타' ? 0 : 0.6;
}

String _legacyProductSubcategory(
  String? category, {
  bool preserveUnrecognizedCategory = true,
}) {
  final normalized = category?.toLowerCase().trim() ?? '';
  if (RegExp(r'세럼|앰플|토너|스킨|에센스|크림|로션|선케어|선크림|클렌|마스크|패드').hasMatch(normalized)) {
    return '스킨케어';
  }
  if (RegExp(r'메이크업|립|틴트|파운데이션|쿠션|컨실러|블러셔|아이섀도|마스카라').hasMatch(normalized)) {
    return '메이크업';
  }
  if (RegExp(r'헤어|샴푸|트리트먼트|바디|바디워시').hasMatch(normalized)) {
    return '헤어·바디';
  }
  if (normalized.contains('네일')) {
    return '네일';
  }
  if (normalized.contains('향수') || normalized.contains('퍼퓸')) {
    return '향수';
  }
  if (normalized.isEmpty || !preserveUnrecognizedCategory) {
    return '뷰티';
  }
  return normalizeContentSubcategory(category!);
}

String _defaultSubcategoryForFolder(ContentFolder folder) {
  return switch (folder) {
    ContentFolder.beauty => '뷰티',
    ContentFolder.healthFitness => '건강 루틴',
    ContentFolder.restaurantCafe => '맛집·카페',
    ContentFolder.recipe => '요리',
    ContentFolder.shopping => '상품',
    ContentFolder.travelPlace => '장소',
    ContentFolder.lifeTip => '생활 팁',
    ContentFolder.other || ContentFolder.needsClassification => '기타',
  };
}

PlaceCategory? _placeCategory(Object? value) {
  return switch (value) {
    null => null,
    'restaurant' => PlaceCategory.restaurant,
    'cafe' => PlaceCategory.cafe,
    'beauty' => PlaceCategory.beauty,
    'shopping' => PlaceCategory.shopping,
    'lodging' => PlaceCategory.lodging,
    'activity' => PlaceCategory.activity,
    'other' => PlaceCategory.other,
    _ => throw const FormatException('Structured place.category is invalid.'),
  };
}

StructuredCompleteness _structuredCompleteness(Object? value) {
  return switch (value) {
    'complete' => StructuredCompleteness.complete,
    'partial' => StructuredCompleteness.partial,
    'conflicted' => StructuredCompleteness.conflicted,
    'needs_review' => StructuredCompleteness.needsReview,
    'unsupported' => StructuredCompleteness.unsupported,
    _ => throw const FormatException(
      'Structured analysis.completeness is invalid.',
    ),
  };
}

ObservedStatus _observedStatus(Object? value) {
  return switch (value) {
    'observed' => ObservedStatus.observed,
    'inferred' => ObservedStatus.inferred,
    'missing' => ObservedStatus.missing,
    _ => throw const FormatException('Structured title.status is invalid.'),
  };
}

final class ConfirmedProductIdentity {
  const ConfirmedProductIdentity({
    required this.brand,
    required this.name,
    required this.category,
    required this.amount,
  });

  final String brand;
  final String name;
  final String category;
  final String amount;

  String get identityKey =>
      [brand, name, category, amount].map(_normalizeIdentityPart).join('|');

  static String _normalizeIdentityPart(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  }
}

final class UserReview {
  const UserReview({
    required this.id,
    required this.captureId,
    required this.analysisRunId,
    required this.resolution,
    required this.reviewedAt,
    this.candidateId,
    this.confirmedIdentity,
  });

  final String id;
  final String captureId;
  final String analysisRunId;
  final ReviewResolution resolution;
  final DateTime reviewedAt;
  final String? candidateId;
  final ConfirmedProductIdentity? confirmedIdentity;
}

final class CaptureRecord {
  const CaptureRecord({
    required this.raw,
    required this.normalized,
    required this.status,
    required this.analysis,
    this.review,
    this.groupId,
    this.folderOverride,
    this.subcategoryOverride,
  });

  final RawCapture raw;
  final NormalizedInput normalized;
  final CaptureStatus status;
  final AnalysisRun? analysis;
  final UserReview? review;
  final String? groupId;
  final ContentFolder? folderOverride;
  final String? subcategoryOverride;

  ProductMention? get primaryMention {
    final mentions = analysis?.productMentions;
    return mentions == null || mentions.isEmpty ? null : mentions.first;
  }

  ContentFolder get contentFolder {
    final override = folderOverride;
    if (override != null) {
      return override;
    }
    final structured = analysis?.structuredContent;
    if (structured != null) {
      return structured.categoryNeedsReview
          ? ContentFolder.needsClassification
          : structured.primaryCategory;
    }
    if (primaryMention != null) {
      return ContentFolder.beauty;
    }
    return ContentFolder.needsClassification;
  }

  String get contentSubcategory {
    final override = subcategoryOverride;
    if (override != null) {
      return normalizeContentSubcategory(override);
    }
    final structured = analysis?.structuredContent;
    if (structured != null) {
      return structured.subcategory;
    }
    final mention = primaryMention;
    if (mention != null) {
      return _legacyProductSubcategory(mention.category.value);
    }
    return _defaultSubcategoryForFolder(contentFolder);
  }

  CaptureRecord copyWith({
    CaptureStatus? status,
    AnalysisRun? analysis,
    UserReview? review,
    String? groupId,
    ContentFolder? folderOverride,
    String? subcategoryOverride,
  }) {
    return CaptureRecord(
      raw: raw,
      normalized: normalized,
      status: status ?? this.status,
      analysis: analysis ?? this.analysis,
      review: review ?? this.review,
      groupId: groupId ?? this.groupId,
      folderOverride: folderOverride ?? this.folderOverride,
      subcategoryOverride: subcategoryOverride == null
          ? this.subcategoryOverride
          : normalizeContentSubcategory(subcategoryOverride),
    );
  }
}

final class ProductGroup {
  const ProductGroup({
    required this.id,
    required this.identity,
    required this.sourceCaptureIds,
    required this.statements,
    required this.updatedAt,
    required this.colorValue,
  });

  final String id;
  final ConfirmedProductIdentity identity;
  final List<String> sourceCaptureIds;
  final List<ContentStatement> statements;
  final DateTime updatedAt;
  final int colorValue;

  int get sourceCount => sourceCaptureIds.length;

  ProductGroup addSource({
    required String captureId,
    required List<ContentStatement> sourceStatements,
    required DateTime at,
  }) {
    final sourceIds = {...sourceCaptureIds, captureId}.toList(growable: false);
    final statementIds = statements.map((statement) => statement.id).toSet();

    return ProductGroup(
      id: id,
      identity: identity,
      sourceCaptureIds: sourceIds,
      statements: [
        ...statements,
        ...sourceStatements.where(
          (statement) => !statementIds.contains(statement.id),
        ),
      ],
      updatedAt: at,
      colorValue: colorValue,
    );
  }
}
