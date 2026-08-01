enum CaptureOrigin { androidShare, manual, demo }

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
    required this.category,
    required this.confidence,
    required this.evidenceIds,
  });

  factory StructuredPlace.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'name',
      'address',
      'category',
      'confidence',
      'evidenceIds',
    }, 'place');
    return StructuredPlace(
      name: _nullableString(json['name'], 'place.name'),
      address: _nullableString(json['address'], 'place.address'),
      category: _placeCategory(json['category']),
      confidence: _confidence(json['confidence'], 'place.confidence'),
      evidenceIds: _strictStringList(json['evidenceIds'], 'place.evidenceIds'),
    );
  }

  final String? name;
  final String? address;
  final PlaceCategory? category;
  final double confidence;
  final List<String> evidenceIds;

  bool get hasAddress => address?.trim().isNotEmpty == true;

  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'category': category?.name,
    'confidence': confidence,
    'evidenceIds': evidenceIds,
  };
}

final class StructuredContentAnalysis {
  const StructuredContentAnalysis({
    required this.schemaVersion,
    required this.model,
    required this.domain,
    required this.contentKind,
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
    normalizedJson.putIfAbsent('place', () => null);
    _requireExactKeys(normalizedJson, const {
      'schemaVersion',
      'model',
      'domain',
      'contentKind',
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
    if (schemaVersion != '1.0' || model != 'gpt-5.6-luna') {
      throw const FormatException(
        'Structured analysis version or model is unsupported.',
      );
    }
    final result = StructuredContentAnalysis(
      schemaVersion: schemaVersion,
      model: model,
      domain: _contentDomain(normalizedJson['domain']),
      contentKind: _contentKind(normalizedJson['contentKind']),
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

  final String schemaVersion;
  final String model;
  final ContentDomain domain;
  final ContentKind contentKind;
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

String _stringAllowEmpty(Object? value, String field) {
  if (value is! String) {
    throw FormatException('Structured $field is invalid.');
  }
  return value;
}

String? _nullableString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _requiredString(value, field);
}

void _requireExactKeys(
  Map<String, Object?> json,
  Set<String> expected,
  String field,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
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
  });

  final RawCapture raw;
  final NormalizedInput normalized;
  final CaptureStatus status;
  final AnalysisRun? analysis;
  final UserReview? review;
  final String? groupId;

  ProductMention? get primaryMention {
    final mentions = analysis?.productMentions;
    return mentions == null || mentions.isEmpty ? null : mentions.first;
  }

  CaptureRecord copyWith({
    CaptureStatus? status,
    AnalysisRun? analysis,
    UserReview? review,
    String? groupId,
  }) {
    return CaptureRecord(
      raw: raw,
      normalized: normalized,
      status: status ?? this.status,
      analysis: analysis ?? this.analysis,
      review: review ?? this.review,
      groupId: groupId ?? this.groupId,
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
