import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

/// Looks a saved place up to fill the axes a screenshot cannot.
///
/// A screenshot almost never shows a price, a queue, or a parking lot. The
/// server keeps what people wrote about the place — review sentences, the
/// shop's own platform notices — and derives three filter values from them at
/// read time: 가격대, 웨이팅, 주차. What arrives here is not a model's claim
/// but a count over sentences the server holds, which is why these labels
/// carry no quote: the deriving code is ours and deterministic, and the
/// sentences behind it stay on the server rather than being re-attached to
/// every capture.
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

  /// The server names filters in Korean because the values are user-facing;
  /// the axis enum names stay English because they are storage keys.
  static const _axisByFilter = {
    '가격대': ContentAxis.price,
    '웨이팅': ContentAxis.waiting,
    '주차': ContentAxis.parking,
  };

  @override
  Future<ContentAxes> enrich({required String name, String? searchArea}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return const ContentAxes.empty();
    }
    final endpoint = Uri.tryParse(baseUrl)?.resolve('/v1/place-facts');
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
    // A lookup the server could not pin to one shop returns no place, and a
    // capture must not wear another shop's filters.
    if (json['place'] is! Map<String, Object?>) {
      return const ContentAxes.empty();
    }
    final filters = json['filters'];
    if (filters is! Map<String, Object?>) {
      return const ContentAxes.empty();
    }
    final labels = <ContentAxis, List<AxisLabel>>{};
    for (final entry in _axisByFilter.entries) {
      final value = filters[entry.key];
      if (value is! String || !isValidContentSubcategory(value)) {
        continue;
      }
      labels[entry.value] = List.unmodifiable([
        AxisLabel(
          value: value,
          confidence: 1.0,
          evidenceIds: const [],
          source: AxisLabelSource.web,
        ),
      ]);
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
