import '../domain/models.dart';
import '../domain/portable_tip_package.dart';
import 'content_analysis_service.dart';

/// Adapts the privacy-safe portable format to the app's existing organized
/// content model. Imported packages skip OCR/AI because the sender already
/// selected the information that should be transferred.
CaptureRecord captureFromImportedPortableTip(ImportedPortableTip imported) {
  final tip = imported.tip;
  final importedAt = imported.importedAt.toLocal();
  final sourceUrl = tip.source?.url;

  final facts = <AnalysisFact>[
    if (tip.message case final message?)
      AnalysisFact(
        label: '보낸 메시지',
        value: message,
        confidence: 1,
        evidenceIds: const [],
      ),
    for (final fact in tip.facts)
      AnalysisFact(
        label: fact.label,
        value: fact.value,
        confidence: 1,
        evidenceIds: const [],
      ),
    for (final note in tip.notes)
      AnalysisFact(
        label: '메모',
        value: note,
        confidence: 1,
        evidenceIds: const [],
      ),
  ];

  final ingredientGroups = <IngredientGroup>[
    for (final group in tip.ingredientGroups)
      IngredientGroup(
        name: group.name,
        ingredients: [
          for (final ingredient in group.ingredients)
            RecipeIngredient(
              name: ingredient.name,
              amount: ingredient.amount,
              unit: ingredient.unit,
              preparation: ingredient.preparation,
              optional: ingredient.optional,
              originalText: ingredient.originalText,
              confidence: 1,
              evidenceIds: const [],
            ),
        ],
      ),
  ];
  final steps = <RecipeStep>[
    for (final step in tip.steps)
      RecipeStep(
        order: step.order,
        instruction: step.instruction,
        durationSeconds: step.durationSeconds,
        temperature: step.temperature,
        evidenceIds: const [],
      ),
  ];
  final place = tip.place;
  final contentKind = _contentKindFor(
    tip.category,
    hasRecipe: ingredientGroups.isNotEmpty || steps.isNotEmpty,
    hasPlace: place != null,
  );

  final structured = StructuredContentAnalysis(
    schemaVersion: '1.2',
    model: 'portable-tip-v1',
    domain: _domainFor(tip.category),
    contentKind: contentKind,
    primaryCategory: tip.category,
    categoryConfidence: 1,
    subcategory: tip.subcategory,
    subcategoryConfidence: 1,
    // A received tip carries one subcategory and no axis breakdown, so it lands
    // on the kind axis alone.
    axes: ContentAxes(
      labels: {
        ContentAxis.kind: [
          AxisLabel(
            value: tip.subcategory,
            confidence: 1,
            evidenceIds: const [],
          ),
        ],
      },
    ),
    completeness: StructuredCompleteness.complete,
    title: StructuredTitle(
      value: tip.title,
      status: ObservedStatus.observed,
      confidence: 1,
      evidenceIds: const [],
    ),
    place: place == null
        ? null
        : StructuredPlace(
            name: place.name,
            address: place.address,
            // The portable tip format carries no area; the address still
            // yields one on the receiving side.
            searchArea: null,
            category: _placeCategoryFor(tip.category),
            confidence: 1,
            evidenceIds: const [],
          ),
    summary: tip.summary,
    evidence: const [],
    ingredientGroups: ingredientGroups,
    steps: steps,
    facts: facts,
    conflicts: const [],
    warnings: const [],
  );
  final normalizedUrls = sourceUrl == null
      ? const <NormalizedUrl>[]
      : <NormalizedUrl>[
          NormalizedUrl(
            rawValue: sourceUrl,
            canonicalValue: sourceUrl,
            platform: _sourcePlatform(sourceUrl),
          ),
        ];
  final semanticMaterial = [
    tip.title,
    tip.summary,
    tip.category.name,
    tip.subcategory,
    ...tip.sections.expand((section) => section.items),
    ?sourceUrl,
  ].join('\n');
  final fingerprint = BaselineContentAnalysisService.semanticFingerprint(
    semanticMaterial,
  );
  final captureId = 'capture-${imported.localId}';
  final inputId = 'input-${imported.localId}';
  final analysisId = 'analysis-${imported.localId}';

  return CaptureRecord(
    raw: RawCapture(
      id: captureId,
      transportEventId: 'portable-${imported.sourcePackageId}',
      receivedAt: importedAt,
      origin: CaptureOrigin.portableTip,
      mimeType: PortableTipPackageCodec.mimeType,
      rawText: semanticMaterial,
      rawUrl: sourceUrl,
      semanticFingerprint: fingerprint,
      wasTruncated: false,
      originalLength: semanticMaterial.length,
      sourcePackage: 'Trun On',
    ),
    normalized: NormalizedInput(
      inputId: inputId,
      normalizerVersion: 'portable-tip-v1',
      normalizedText: semanticMaterial,
      urls: normalizedUrls,
      semanticFingerprint: fingerprint,
      completeness: MaterialCompleteness.complete,
      warnings: const [],
    ),
    status: CaptureStatus.organized,
    analysis: AnalysisRun(
      id: analysisId,
      inputId: inputId,
      normalizerVersion: 'portable-tip-v1',
      analyzerVersion: 'portable-tip-v1',
      status: AnalysisRunStatus.succeeded,
      completedAt: importedAt,
      evidence: const [],
      productMentions: const [],
      statements: const [],
      disclosure: DisclosureObservation.unknown,
      model: 'portable-tip-v1',
      structuredContent: structured,
    ),
    review: UserReview(
      id: 'review-${imported.localId}',
      captureId: captureId,
      analysisRunId: analysisId,
      resolution: ReviewResolution.confirmed,
      reviewedAt: importedAt,
    ),
    folderOverride: tip.category,
    subcategoryOverride: tip.subcategory,
  );
}

ContentDomain _domainFor(ContentFolder folder) => switch (folder) {
  ContentFolder.beauty => ContentDomain.beauty,
  ContentFolder.restaurantCafe || ContentFolder.recipe => ContentDomain.food,
  _ => ContentDomain.unknown,
};

ContentKind _contentKindFor(
  ContentFolder folder, {
  required bool hasRecipe,
  required bool hasPlace,
}) {
  if (hasRecipe || folder == ContentFolder.recipe) return ContentKind.recipe;
  if (hasPlace ||
      folder == ContentFolder.restaurantCafe ||
      folder == ContentFolder.travelPlace) {
    return ContentKind.place;
  }
  if (folder == ContentFolder.beauty) return ContentKind.beautyProduct;
  if (folder == ContentFolder.shopping) return ContentKind.commerceProduct;
  return ContentKind.unknown;
}

PlaceCategory _placeCategoryFor(ContentFolder folder) => switch (folder) {
  ContentFolder.restaurantCafe => PlaceCategory.restaurant,
  ContentFolder.beauty => PlaceCategory.beauty,
  ContentFolder.shopping => PlaceCategory.shopping,
  ContentFolder.travelPlace => PlaceCategory.activity,
  _ => PlaceCategory.other,
};

SourcePlatform _sourcePlatform(String rawUrl) {
  final host = Uri.tryParse(rawUrl)?.host.toLowerCase() ?? '';
  if (host.contains('instagram.com')) return SourcePlatform.instagram;
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return SourcePlatform.youtube;
  }
  if (host.contains('tiktok.com')) return SourcePlatform.tiktok;
  if (host == 'x.com' ||
      host.endsWith('.x.com') ||
      host.contains('twitter.com')) {
    return SourcePlatform.x;
  }
  return SourcePlatform.web;
}
