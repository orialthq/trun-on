import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/evals/eval_core.dart';
import '../../tool/evals/local_backend_client.dart';

void main() {
  late EvalManifest manifest;

  setUpAll(() async {
    manifest = EvalManifest.fromJsonString(
      await File('tool/evals/manifest.template.json').readAsString(),
    );
  });

  test('template covers all 17 private holdout scenarios', () {
    expect(manifest.samples, hasLength(17));
    expect(manifest.samples.map((sample) => sample.sampleId).toSet(), {
      for (var index = 1; index <= 17; index++)
        'holdout-${index.toString().padLeft(2, '0')}',
    });
    expect(() => manifest.validateFullHoldoutCoverage(), returnsNormally);
  });

  test(
    'deterministic mock backend produces an aggregate pass report',
    () async {
      final backend = _DeterministicBackend();
      final aggregate = await EvalRunner(
        backend: backend,
        now: () => DateTime.utc(2026, 8, 1, 3, 4, 5),
      ).run(manifest, Directory('.'));

      expect(aggregate.passedCount, 17);
      expect(aggregate.failedCount, 0);
      expect(backend.requestedIds, [
        for (var index = 1; index <= 17; index++)
          'holdout-${index.toString().padLeft(2, '0')}',
      ]);
      expect(aggregate.toJson()['generatedAt'], '2026-08-01T03:04:05.000Z');
      expect(
        aggregate.toPrettyJson(),
        isNot(contains(_DeterministicBackend.privateResponseMarker)),
      );
    },
  );

  test('classification and error invariants fail independently', () {
    final sample = manifest.samples.firstWhere(
      (candidate) =>
          candidate.scenario == EvalScenario.recipeConflictedQuantity,
    );
    final result = evaluateResponse(sample, {
      'analysis': {
        'domain': 'food',
        'contentKind': 'recipe',
        'completeness': 'complete',
        'errors': [
          {'code': 'raw_content_exposed', 'message': 'not copied to report'},
          {'code': 'account_private_marker'},
        ],
        'rawText': _DeterministicBackend.privateResponseMarker,
      },
    });

    expect(result.passed, isFalse);
    expect(
      result.checks.firstWhere((check) => check.name == 'completeness').passed,
      isFalse,
    );
    expect(
      result.checks
          .firstWhere((check) => check.name == 'forbidden_error_codes')
          .passed,
      isFalse,
    );
    expect(
      result.toJson().toString(),
      isNot(contains(_DeterministicBackend.privateResponseMarker)),
    );
    expect(result.toJson().toString(), isNot(contains('not copied to report')));
    expect(
      result.toJson().toString(),
      isNot(contains('account_private_marker')),
    );
    expect(result.toJson().toString(), contains('unrecognized_error_code'));
  });

  test('adjudicated completeness boundary accepts either safe state', () {
    final sample = manifest.samples.firstWhere(
      (candidate) => candidate.scenario == EvalScenario.recipeRatioUnits,
    );

    final result = evaluateResponse(sample, {
      'analysis': {
        'domain': 'food',
        'contentKind': 'recipe',
        'completeness': 'partial',
        'errors': const <Object?>[],
      },
    });

    expect(result.passed, isTrue);
    expect(
      result.checks
          .firstWhere((check) => check.name == 'completeness')
          .expected,
      ['complete', 'partial'],
    );
  });

  test('runner sanitizes backend exception codes', () async {
    final aggregate = await EvalRunner(
      backend: const _LeakyErrorBackend(),
      now: () => DateTime.utc(2026, 8, 1),
    ).run(manifest, Directory('.'), onlySampleIds: {'holdout-01'});

    expect(aggregate.failedCount, 1);
    expect(aggregate.results.single.runnerErrorCode, 'runner_backend_error');
    expect(aggregate.toPrettyJson(), isNot(contains('account_private_marker')));
  });

  test('manifest rejects inline content and unsafe paths', () {
    final base = _singleSampleJson();
    final sample =
        (base['samples']! as List<Object?>).single as Map<String, Object?>;
    final input = sample['input']! as Map<String, Object?>;
    input['sharedText'] = 'synthetic private content';

    expect(() => EvalManifest.fromJson(base), throwsA(isA<FormatException>()));

    final unsafe = _singleSampleJson();
    final unsafeSample =
        (unsafe['samples']! as List<Object?>).single as Map<String, Object?>;
    final unsafeInput = unsafeSample['input']! as Map<String, Object?>;
    unsafeInput['imageFile'] = '../private.jpg';

    expect(
      () => EvalManifest.fromJson(unsafe),
      throwsA(isA<FormatException>()),
    );
  });

  test('local backend client refuses non-loopback and credential URLs', () {
    expect(
      () => LocalBackendClient(
        endpoint: Uri.parse('https://example.com/v1/analyze'),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => LocalBackendClient(
        endpoint: Uri.parse(
          'http://localhost:8080/v1/analyze?api_key=synthetic',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

final class _DeterministicBackend implements EvalBackend {
  static const privateResponseMarker = 'SYNTHETIC_PRIVATE_RESPONSE_MARKER';

  final requestedIds = <String>[];

  @override
  Future<Map<String, Object?>> analyze(
    EvalSample sample,
    Directory dataDirectory,
  ) async {
    requestedIds.add(sample.sampleId);
    return {
      'analysis': {
        'domain': sample.expected.domain.wireName,
        'contentKind': sample.expected.kind.wireName,
        'completeness': sample.expected.completeness.wireName,
        'errors': [
          for (final code in sample.expected.requiredErrorCodes) {'code': code},
        ],
        'rawText': privateResponseMarker,
        'accountName': privateResponseMarker,
      },
    };
  }
}

final class _LeakyErrorBackend implements EvalBackend {
  const _LeakyErrorBackend();

  @override
  Future<Map<String, Object?>> analyze(
    EvalSample sample,
    Directory dataDirectory,
  ) {
    throw const EvalBackendException('account_private_marker');
  }
}

Map<String, Object?> _singleSampleJson() {
  return {
    'schemaVersion': 1,
    'samples': <Object?>[
      <String, Object?>{
        'sampleId': 'holdout-01',
        'scenario': 'recipe_partial_mixed_text',
        'input': <String, Object?>{
          'imageFile': 'holdout-01.jpg',
          'mimeType': 'image/jpeg',
        },
        'expected': <String, Object?>{
          'domain': 'food',
          'kind': 'recipe',
          'completeness': 'partial',
          'allowedCompleteness': <Object?>[],
          'requiredErrorCodes': <Object?>[],
          'allowedErrorCodes': <Object?>[],
          'forbiddenErrorCodes': <Object?>['raw_content_exposed'],
        },
      },
    ],
  };
}
