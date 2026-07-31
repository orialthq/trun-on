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

enum EvidenceKind { sharedText, url, userInput }

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
  });

  final String id;
  final String captureId;
  final EvidenceKind kind;
  final String quote;
  final int? startOffset;
  final int? endOffset;
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
