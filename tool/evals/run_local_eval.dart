import 'dart:io';

import 'eval_core.dart';
import 'local_backend_client.dart';

const _defaultManifestPath = 'tool/evals/local/manifest.json';
const _defaultDataDirectory = 'tool/evals/local/samples';
const _defaultOutputPath = 'tool/evals/reports/latest.json';
const _defaultEndpoint = 'http://127.0.0.1:8787/v1/analyze';

Future<void> main(List<String> arguments) async {
  _CliOptions options;
  try {
    options = _CliOptions.parse(arguments);
  } on FormatException {
    stderr.writeln('Invalid eval arguments. Use --help for usage.');
    exitCode = 64;
    return;
  }
  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  final endpointSource =
      Platform.environment['ORI_EVAL_ENDPOINT'] ?? _defaultEndpoint;
  final apiKey = Platform.environment['ORI_EVAL_API_KEY'];
  final endpoint = Uri.tryParse(endpointSource);
  if (endpoint == null) {
    stderr.writeln('Eval configuration is invalid.');
    exitCode = 64;
    return;
  }

  EvalManifest manifest;
  try {
    manifest = EvalManifest.fromJsonString(
      await File(options.manifestPath).readAsString(),
    );
    manifest.validateFullHoldoutCoverage();
  } on Object {
    stderr.writeln(
      'Could not load the private eval manifest. '
      'See tool/evals/README.md.',
    );
    exitCode = 66;
    return;
  }

  LocalBackendClient backend;
  try {
    backend = LocalBackendClient(endpoint: endpoint, apiKey: apiKey);
  } on FormatException {
    stderr.writeln('ORI_EVAL_ENDPOINT must point to a loopback server.');
    exitCode = 64;
    return;
  }

  try {
    final aggregate = await EvalRunner(backend: backend).run(
      manifest,
      Directory(options.dataDirectory),
      onlySampleIds: options.sampleIds.isEmpty ? null : options.sampleIds,
    );
    final outputFile = File(options.outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString('${aggregate.toPrettyJson()}\n');

    stdout.writeln(
      'Eval complete: ${aggregate.passedCount} passed, '
      '${aggregate.failedCount} failed.',
    );
    stdout.writeln('Aggregate report written without sample content.');
    if (aggregate.failedCount > 0) {
      exitCode = 1;
    }
  } on FormatException {
    stderr.writeln('Eval selection or manifest coverage is invalid.');
    exitCode = 64;
  } on FileSystemException {
    stderr.writeln('Could not write the aggregate report.');
    exitCode = 73;
  } finally {
    backend.close();
  }
}

final class _CliOptions {
  const _CliOptions({
    required this.manifestPath,
    required this.dataDirectory,
    required this.outputPath,
    required this.sampleIds,
    required this.showHelp,
  });

  final String manifestPath;
  final String dataDirectory;
  final String outputPath;
  final Set<String> sampleIds;
  final bool showHelp;

  factory _CliOptions.parse(List<String> arguments) {
    var manifestPath = _defaultManifestPath;
    var dataDirectory = _defaultDataDirectory;
    var outputPath = _defaultOutputPath;
    final sampleIds = <String>{};
    var showHelp = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
        continue;
      }
      if (argument == '--manifest' ||
          argument == '--data-dir' ||
          argument == '--output' ||
          argument == '--sample') {
        if (index + 1 >= arguments.length) {
          throw FormatException('$argument requires a value.');
        }
        final value = arguments[++index];
        switch (argument) {
          case '--manifest':
            manifestPath = value;
          case '--data-dir':
            dataDirectory = value;
          case '--output':
            outputPath = value;
          case '--sample':
            if (!RegExp(r'^holdout-[0-9]{2}$').hasMatch(value)) {
              throw const FormatException(
                '--sample must use an opaque holdout-NN ID.',
              );
            }
            sampleIds.add(value);
        }
        continue;
      }
      throw FormatException('Unknown argument.');
    }

    return _CliOptions(
      manifestPath: manifestPath,
      dataDirectory: dataDirectory,
      outputPath: outputPath,
      sampleIds: sampleIds,
      showHelp: showHelp,
    );
  }
}

const _usage =
    '''
Run private local holdout evaluation.

Usage:
  dart run tool/evals/run_local_eval.dart [options]

Options:
  --manifest <path>  Private manifest (default: $_defaultManifestPath)
  --data-dir <path>  Private sample directory (default: $_defaultDataDirectory)
  --output <path>    Aggregate JSON output (default: $_defaultOutputPath)
  --sample <id>      Run one opaque ID; repeat to run more than one
  -h, --help         Show this help

Environment:
  ORI_EVAL_ENDPOINT  Loopback endpoint (default: $_defaultEndpoint)
  ORI_EVAL_API_KEY   Optional bearer key; never written to output
''';
