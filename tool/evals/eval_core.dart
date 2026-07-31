import 'dart:convert';
import 'dart:io';

enum EvalDomain { food }

enum EvalKind {
  recipe,
  sauceRecipe,
  commerceProduct,
  productReview,
  menuComparison,
}

enum EvalCompleteness { complete, partial, conflicted, needsReview }

enum EvalScenario {
  recipePartialMixedText,
  recipeConflictedQuantity,
  recipeRatioUnits,
  recipePartialNoSteps,
  recipeGroupedSeasoning,
  recipeMissingTitle,
  commerceProduct,
  infographicRecipe,
  productReview,
  bilingualDuplicateRecipe,
  recipePartialSauceOnly,
  recipeUnitMissing,
  menuComparison,
  recipeSubstitution,
  recipeAffiliatePartial,
  sauceRecipeFractional,
  recipeUiNumberNoise,
}

extension EvalDomainWireName on EvalDomain {
  String get wireName => name;
}

extension EvalKindWireName on EvalKind {
  String get wireName => switch (this) {
    EvalKind.recipe => 'recipe',
    EvalKind.sauceRecipe => 'sauce_recipe',
    EvalKind.commerceProduct => 'commerce_product',
    EvalKind.productReview => 'product_review',
    EvalKind.menuComparison => 'menu_comparison',
  };
}

extension EvalCompletenessWireName on EvalCompleteness {
  String get wireName => switch (this) {
    EvalCompleteness.complete => 'complete',
    EvalCompleteness.partial => 'partial',
    EvalCompleteness.conflicted => 'conflicted',
    EvalCompleteness.needsReview => 'needs_review',
  };
}

extension EvalScenarioWireName on EvalScenario {
  String get wireName => switch (this) {
    EvalScenario.recipePartialMixedText => 'recipe_partial_mixed_text',
    EvalScenario.recipeConflictedQuantity => 'recipe_conflicted_quantity',
    EvalScenario.recipeRatioUnits => 'recipe_ratio_units',
    EvalScenario.recipePartialNoSteps => 'recipe_partial_no_steps',
    EvalScenario.recipeGroupedSeasoning => 'recipe_grouped_seasoning',
    EvalScenario.recipeMissingTitle => 'recipe_missing_title',
    EvalScenario.commerceProduct => 'commerce_product',
    EvalScenario.infographicRecipe => 'infographic_recipe',
    EvalScenario.productReview => 'product_review',
    EvalScenario.bilingualDuplicateRecipe => 'bilingual_duplicate_recipe',
    EvalScenario.recipePartialSauceOnly => 'recipe_partial_sauce_only',
    EvalScenario.recipeUnitMissing => 'recipe_unit_missing',
    EvalScenario.menuComparison => 'menu_comparison',
    EvalScenario.recipeSubstitution => 'recipe_substitution',
    EvalScenario.recipeAffiliatePartial => 'recipe_affiliate_partial',
    EvalScenario.sauceRecipeFractional => 'sauce_recipe_fractional',
    EvalScenario.recipeUiNumberNoise => 'recipe_ui_number_noise',
  };
}

final class EvalInput {
  const EvalInput({required this.imageFile, required this.mimeType});

  final String imageFile;
  final String mimeType;

  factory EvalInput.fromJson(Map<String, Object?> json, String path) {
    _rejectUnknownKeys(json, const {'imageFile', 'mimeType'}, path);
    final imageFile = _requiredString(json, 'imageFile', path);
    final mimeType = _requiredString(json, 'mimeType', path);

    _validatePrivateRelativePath(imageFile, '$path.imageFile');
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw FormatException('$path.mimeType is not an allowed image MIME.');
    }

    return EvalInput(imageFile: imageFile, mimeType: mimeType);
  }
}

final class EvalExpectation {
  const EvalExpectation({
    required this.domain,
    required this.kind,
    required this.completeness,
    required this.allowedCompleteness,
    required this.requiredErrorCodes,
    required this.allowedErrorCodes,
    required this.forbiddenErrorCodes,
  });

  final EvalDomain domain;
  final EvalKind kind;
  final EvalCompleteness completeness;
  final Set<EvalCompleteness> allowedCompleteness;
  final Set<String> requiredErrorCodes;
  final Set<String> allowedErrorCodes;
  final Set<String> forbiddenErrorCodes;

  factory EvalExpectation.fromJson(Map<String, Object?> json, String path) {
    _rejectUnknownKeys(json, const {
      'domain',
      'kind',
      'completeness',
      'allowedCompleteness',
      'requiredErrorCodes',
      'allowedErrorCodes',
      'forbiddenErrorCodes',
    }, path);

    final requiredErrorCodes = _errorCodes(
      json['requiredErrorCodes'],
      '$path.requiredErrorCodes',
    );
    final allowedErrorCodes = _errorCodes(
      json['allowedErrorCodes'],
      '$path.allowedErrorCodes',
    );
    final forbiddenErrorCodes = _errorCodes(
      json['forbiddenErrorCodes'],
      '$path.forbiddenErrorCodes',
    );

    if (requiredErrorCodes.intersection(forbiddenErrorCodes).isNotEmpty) {
      throw FormatException(
        '$path cannot require and forbid the same error code.',
      );
    }
    if (allowedErrorCodes.intersection(forbiddenErrorCodes).isNotEmpty) {
      throw FormatException(
        '$path cannot allow and forbid the same error code.',
      );
    }

    final completeness = _parseCompleteness(
      _requiredString(json, 'completeness', path),
    );
    final allowedCompleteness = _completenessSet(
      json['allowedCompleteness'],
      '$path.allowedCompleteness',
    );
    if (allowedCompleteness.contains(completeness)) {
      throw FormatException(
        '$path.allowedCompleteness must not repeat completeness.',
      );
    }

    return EvalExpectation(
      domain: _parseDomain(_requiredString(json, 'domain', path)),
      kind: _parseKind(_requiredString(json, 'kind', path)),
      completeness: completeness,
      allowedCompleteness: allowedCompleteness,
      requiredErrorCodes: requiredErrorCodes,
      allowedErrorCodes: allowedErrorCodes,
      forbiddenErrorCodes: forbiddenErrorCodes,
    );
  }
}

final class EvalSample {
  const EvalSample({
    required this.sampleId,
    required this.scenario,
    required this.input,
    required this.expected,
  });

  final String sampleId;
  final EvalScenario scenario;
  final EvalInput input;
  final EvalExpectation expected;

  factory EvalSample.fromJson(Map<String, Object?> json, int index) {
    final path = 'samples[$index]';
    _rejectUnknownKeys(json, const {
      'sampleId',
      'scenario',
      'input',
      'expected',
    }, path);
    final sampleId = _requiredString(json, 'sampleId', path);
    if (!RegExp(r'^holdout-[0-9]{2}$').hasMatch(sampleId)) {
      throw FormatException(
        '$path.sampleId must use the opaque holdout-NN format.',
      );
    }

    return EvalSample(
      sampleId: sampleId,
      scenario: _parseScenario(_requiredString(json, 'scenario', path)),
      input: EvalInput.fromJson(
        _object(json['input'], '$path.input'),
        '$path.input',
      ),
      expected: EvalExpectation.fromJson(
        _object(json['expected'], '$path.expected'),
        '$path.expected',
      ),
    );
  }
}

final class EvalManifest {
  const EvalManifest({required this.schemaVersion, required this.samples});

  final int schemaVersion;
  final List<EvalSample> samples;

  factory EvalManifest.fromJsonString(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Manifest is not valid JSON.');
    }
    return EvalManifest.fromJson(_object(decoded, 'manifest'));
  }

  factory EvalManifest.fromJson(Map<String, Object?> json) {
    _rejectUnknownKeys(json, const {'schemaVersion', 'samples'}, 'manifest');
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw const FormatException('manifest.schemaVersion must be 1.');
    }
    final rawSamples = json['samples'];
    if (rawSamples is! List<Object?>) {
      throw const FormatException('manifest.samples must be a list.');
    }
    final samples = [
      for (var index = 0; index < rawSamples.length; index++)
        EvalSample.fromJson(
          _object(rawSamples[index], 'samples[$index]'),
          index,
        ),
    ];

    final ids = <String>{};
    final scenarios = <EvalScenario>{};
    for (final sample in samples) {
      if (!ids.add(sample.sampleId)) {
        throw const FormatException('Manifest contains a duplicate sample ID.');
      }
      if (!scenarios.add(sample.scenario)) {
        throw const FormatException('Manifest contains a duplicate scenario.');
      }
    }

    return EvalManifest(schemaVersion: schemaVersion, samples: samples);
  }

  void validateFullHoldoutCoverage() {
    final expectedScenarios = EvalScenario.values.toSet();
    final actualScenarios = samples.map((sample) => sample.scenario).toSet();
    if (samples.length != expectedScenarios.length ||
        !actualScenarios.containsAll(expectedScenarios)) {
      throw const FormatException(
        'Manifest must cover each of the 17 holdout scenarios exactly once.',
      );
    }
  }
}

final class EvalCheck {
  const EvalCheck({
    required this.name,
    required this.passed,
    required this.expected,
    required this.actual,
  });

  final String name;
  final bool passed;
  final Object? expected;
  final Object? actual;

  Map<String, Object?> toJson() => {
    'name': name,
    'passed': passed,
    'expected': expected,
    'actual': actual,
  };
}

final class EvalSampleResult {
  const EvalSampleResult({
    required this.sampleId,
    required this.scenario,
    required this.checks,
    this.runnerErrorCode,
  });

  factory EvalSampleResult.runnerFailure(
    EvalSample sample,
    String runnerErrorCode,
  ) {
    return EvalSampleResult(
      sampleId: sample.sampleId,
      scenario: sample.scenario,
      checks: const [],
      runnerErrorCode: runnerErrorCode,
    );
  }

  final String sampleId;
  final EvalScenario scenario;
  final List<EvalCheck> checks;
  final String? runnerErrorCode;

  bool get passed =>
      runnerErrorCode == null && checks.every((check) => check.passed);

  Map<String, Object?> toJson() => {
    'sampleId': sampleId,
    'scenario': scenario.wireName,
    'passed': passed,
    if (runnerErrorCode != null) 'runnerErrorCode': runnerErrorCode,
    'checks': checks.map((check) => check.toJson()).toList(growable: false),
  };
}

final class EvalAggregate {
  const EvalAggregate({required this.generatedAt, required this.results});

  final DateTime generatedAt;
  final List<EvalSampleResult> results;

  int get passedCount => results.where((result) => result.passed).length;
  int get failedCount => results.length - passedCount;

  Map<String, Object?> toJson() {
    final byScenario = <String, Object?>{};
    for (final scenario in EvalScenario.values) {
      final scenarioResults = results
          .where((result) => result.scenario == scenario)
          .toList(growable: false);
      if (scenarioResults.isEmpty) {
        continue;
      }
      byScenario[scenario.wireName] = {
        'total': scenarioResults.length,
        'passed': scenarioResults.where((result) => result.passed).length,
        'failed': scenarioResults.where((result) => !result.passed).length,
      };
    }

    return {
      'schemaVersion': 1,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'totals': {
        'samples': results.length,
        'passed': passedCount,
        'failed': failedCount,
      },
      'byScenario': byScenario,
      'results': results
          .map((result) => result.toJson())
          .toList(growable: false),
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

abstract interface class EvalBackend {
  Future<Map<String, Object?>> analyze(
    EvalSample sample,
    Directory dataDirectory,
  );
}

final class EvalBackendException implements Exception {
  const EvalBackendException(this.code);

  final String code;
}

final class EvalRunner {
  const EvalRunner({required this.backend, this.now = DateTime.now});

  final EvalBackend backend;
  final DateTime Function() now;

  Future<EvalAggregate> run(
    EvalManifest manifest,
    Directory dataDirectory, {
    Set<String>? onlySampleIds,
  }) async {
    manifest.validateFullHoldoutCoverage();
    final results = <EvalSampleResult>[];

    for (final sample in manifest.samples) {
      if (onlySampleIds != null && !onlySampleIds.contains(sample.sampleId)) {
        continue;
      }
      try {
        final response = await backend.analyze(sample, dataDirectory);
        results.add(evaluateResponse(sample, response));
      } on EvalBackendException catch (error) {
        results.add(
          EvalSampleResult.runnerFailure(
            sample,
            _safeRunnerErrorCode(error.code),
          ),
        );
      } on Object {
        results.add(
          EvalSampleResult.runnerFailure(sample, 'runner_unexpected_error'),
        );
      }
    }

    if (onlySampleIds != null) {
      final knownIds = manifest.samples
          .map((sample) => sample.sampleId)
          .toSet();
      if (!knownIds.containsAll(onlySampleIds)) {
        throw const FormatException('Requested sample ID is not in manifest.');
      }
    }

    return EvalAggregate(generatedAt: now(), results: results);
  }
}

EvalSampleResult evaluateResponse(
  EvalSample sample,
  Map<String, Object?> response,
) {
  final nestedAnalysis = response['analysis'];
  final analysis = nestedAnalysis is Map<Object?, Object?>
      ? _object(nestedAnalysis, 'response.analysis')
      : response;
  final actualDomain = _safeWireValue(analysis['domain']);
  final actualKind = _safeWireValue(
    analysis['contentKind'] ?? analysis['kind'],
  );
  final actualCompleteness = _safeWireValue(analysis['completeness']);
  final expected = sample.expected;
  final acceptedCompleteness = {
    expected.completeness,
    ...expected.allowedCompleteness,
  }.map((value) => value.wireName).toSet();
  final knownErrorCodes = {
    ...expected.requiredErrorCodes,
    ...expected.allowedErrorCodes,
    ...expected.forbiddenErrorCodes,
    'malformed_error_code',
    'malformed_error_response',
  };
  final actualErrors = _responseErrorCodes(analysis['errors'])
      .map(
        (code) =>
            knownErrorCodes.contains(code) ? code : 'unrecognized_error_code',
      )
      .toSet();
  final requiredMissing = expected.requiredErrorCodes.difference(actualErrors);
  final forbiddenPresent = expected.forbiddenErrorCodes.intersection(
    actualErrors,
  );
  final acceptedErrors = {
    ...expected.requiredErrorCodes,
    ...expected.allowedErrorCodes,
  };
  final unexpectedErrors = actualErrors.difference(acceptedErrors);

  return EvalSampleResult(
    sampleId: sample.sampleId,
    scenario: sample.scenario,
    checks: [
      EvalCheck(
        name: 'domain',
        passed: actualDomain == expected.domain.wireName,
        expected: expected.domain.wireName,
        actual: actualDomain,
      ),
      EvalCheck(
        name: 'kind',
        passed: actualKind == expected.kind.wireName,
        expected: expected.kind.wireName,
        actual: actualKind,
      ),
      EvalCheck(
        name: 'completeness',
        passed: acceptedCompleteness.contains(actualCompleteness),
        expected: _sorted(acceptedCompleteness),
        actual: actualCompleteness,
      ),
      EvalCheck(
        name: 'required_error_codes',
        passed: requiredMissing.isEmpty,
        expected: _sorted(expected.requiredErrorCodes),
        actual: _sorted(actualErrors),
      ),
      EvalCheck(
        name: 'forbidden_error_codes',
        passed: forbiddenPresent.isEmpty,
        expected: _sorted(expected.forbiddenErrorCodes),
        actual: _sorted(actualErrors),
      ),
      EvalCheck(
        name: 'unexpected_error_codes',
        passed: unexpectedErrors.isEmpty,
        expected: _sorted(acceptedErrors),
        actual: _sorted(actualErrors),
      ),
    ],
  );
}

EvalDomain _parseDomain(String value) {
  return EvalDomain.values.firstWhere(
    (candidate) => candidate.wireName == value,
    orElse: () => throw const FormatException(
      'Expected domain contains an unsupported enum.',
    ),
  );
}

EvalKind _parseKind(String value) {
  return EvalKind.values.firstWhere(
    (candidate) => candidate.wireName == value,
    orElse: () => throw const FormatException(
      'Expected kind contains an unsupported enum.',
    ),
  );
}

EvalCompleteness _parseCompleteness(String value) {
  return EvalCompleteness.values.firstWhere(
    (candidate) => candidate.wireName == value,
    orElse: () => throw const FormatException(
      'Expected completeness contains an unsupported enum.',
    ),
  );
}

EvalScenario _parseScenario(String value) {
  return EvalScenario.values.firstWhere(
    (candidate) => candidate.wireName == value,
    orElse: () =>
        throw const FormatException('Scenario contains an unsupported enum.'),
  );
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$path must be an object.');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$path keys must be strings.');
    }
    result[entry.key! as String] = entry.value;
  }
  return result;
}

void _rejectUnknownKeys(
  Map<String, Object?> json,
  Set<String> allowed,
  String path,
) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('$path has unsupported field "$key".');
    }
  }
}

String _requiredString(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$path.$key must be a non-empty string.');
  }
  return value;
}

Set<String> _errorCodes(Object? value, String path) {
  if (value is! List<Object?>) {
    throw FormatException('$path must be a list.');
  }
  final result = <String>{};
  for (final item in value) {
    if (item is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(item)) {
      throw FormatException('$path contains an invalid error code.');
    }
    result.add(item);
  }
  return result;
}

Set<EvalCompleteness> _completenessSet(Object? value, String path) {
  if (value == null) {
    return {};
  }
  if (value is! List<Object?>) {
    throw FormatException('$path must be a list.');
  }
  final result = <EvalCompleteness>{};
  for (final item in value) {
    if (item is! String) {
      throw FormatException('$path contains an invalid completeness value.');
    }
    result.add(_parseCompleteness(item));
  }
  return result;
}

Set<String> _responseErrorCodes(Object? value) {
  if (value == null) {
    return {};
  }
  if (value is! List<Object?>) {
    return {'malformed_error_response'};
  }
  final result = <String>{};
  for (final item in value) {
    final code = switch (item) {
      final String value => value,
      final Map<Object?, Object?> value when value['code'] is String =>
        value['code']! as String,
      _ => 'malformed_error_response',
    };
    if (RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(code)) {
      result.add(code);
    } else {
      result.add('malformed_error_code');
    }
  }
  return result;
}

String? _safeWireValue(Object? value) {
  if (value is String &&
      RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(value)) {
    return value;
  }
  return null;
}

String _safeRunnerErrorCode(String value) {
  const allowed = {
    'image_missing',
    'image_too_large',
    'shared_text_missing',
    'shared_text_too_large',
    'shared_text_invalid_utf8',
    'unsafe_local_path',
    'backend_unreachable',
    'backend_request_failed',
    'backend_response_too_large',
    'backend_response_invalid_json',
    'backend_response_invalid_shape',
  };
  if (allowed.contains(value) ||
      RegExp(r'^backend_http_[1-5][0-9]{2}$').hasMatch(value)) {
    return value;
  }
  return 'runner_backend_error';
}

List<String> _sorted(Iterable<String> values) {
  return values.toList(growable: false)..sort();
}

void _validatePrivateRelativePath(String value, String path) {
  final normalized = value.replaceAll(r'\', '/');
  if (normalized.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:/').hasMatch(normalized) ||
      normalized.split('/').contains('..') ||
      Uri.tryParse(value)?.hasScheme == true) {
    throw FormatException('$path must be a relative local path.');
  }
}
