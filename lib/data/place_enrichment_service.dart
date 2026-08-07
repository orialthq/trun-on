import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

/// Looks a saved place up on the web to fill the axes a screenshot cannot.
///
/// A screenshot almost never shows a price, and rarely says who a place suits.
/// This pass searches for `상호명 + 지역` — the same query the map opens with —
/// and returns labels that each carry the page supporting them.
///
/// Every failure mode resolves to an empty result rather than an exception the
/// caller has to reason about. The enrichment is an optional extra on top of a
/// capture that is already saved and already useful.
abstract interface class PlaceEnrichmentService {
  Future<ContentAxes> enrich({required String name, String? searchArea});
}

final class RemotePlaceEnrichmentService implements PlaceEnrichmentService {
  const RemotePlaceEnrichmentService({
    this.baseUrl = const String.fromEnvironment(
      'ORI_ANALYSIS_BASE_URL',
      defaultValue: 'http://10.0.2.2:8787',
    ),
    this.timeout = const Duration(seconds: 60),
  });

  final String baseUrl;
  final Duration timeout;

  static const _axisByField = {
    'kind': ContentAxis.kind,
    'occasion': ContentAxis.occasion,
    'priceRange': ContentAxis.priceRange,
  };

  @override
  Future<ContentAxes> enrich({required String name, String? searchArea}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return const ContentAxes.empty();
    }
    final endpoint = Uri.tryParse(baseUrl)?.resolve('/v1/enrich-place');
    if (endpoint == null ||
        !const {'http', 'https'}.contains(endpoint.scheme) ||
        endpoint.host.isEmpty) {
      return const ContentAxes.empty();
    }

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(endpoint).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'name': trimmedName,
          'searchArea': searchArea?.trim().isEmpty ?? true
              ? null
              : searchArea!.trim(),
        }),
      );
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ContentAxes.empty();
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        return const ContentAxes.empty();
      }
      return _axesFrom(decoded);
    } on Object {
      // Offline, unreachable server, malformed reply: all the same outcome.
      return const ContentAxes.empty();
    } finally {
      client.close(force: true);
    }
  }

  ContentAxes _axesFrom(Map<String, Object?> json) {
    final labels = <ContentAxis, List<AxisLabel>>{};
    for (final entry in _axisByField.entries) {
      final raw = json[entry.key];
      if (raw is! List) continue;
      final parsed = <AxisLabel>[];
      for (final item in raw) {
        if (item is! Map<String, Object?>) continue;
        final value = item['value'];
        final citation = item['citation'];
        // A web label without a source is indistinguishable from a guess.
        if (value is! String ||
            !isValidContentSubcategory(value) ||
            citation is! String ||
            !citation.startsWith('https://')) {
          continue;
        }
        final confidence = item['confidence'];
        parsed.add(
          AxisLabel(
            value: value,
            confidence: confidence is num
                ? confidence.toDouble().clamp(0.0, 1.0)
                : 0.0,
            evidenceIds: const [],
            source: AxisLabelSource.web,
            citation: citation,
          ),
        );
      }
      labels[entry.value] = List.unmodifiable(parsed);
    }
    return ContentAxes(labels: Map.unmodifiable(labels));
  }
}

final class NoPlaceEnrichmentService implements PlaceEnrichmentService {
  const NoPlaceEnrichmentService();

  @override
  Future<ContentAxes> enrich({required String name, String? searchArea}) async {
    return const ContentAxes.empty();
  }
}
