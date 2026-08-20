import '../domain/models.dart';

/// One saved thing, in the shape the recommendation call carries.
///
/// Everything here already sits in a [CaptureRecord]. Nothing is derived,
/// scored, or ranked — that is the point of the baseline, and anything we add
/// later has to earn its place against what this already gets right.
final class RecommendationCandidate {
  const RecommendationCandidate({
    required this.id,
    required this.name,
    required this.folder,
    required this.labels,
    required this.saveCount,
    this.area,
    this.lastSavedAt,
  });

  /// The capture this stands for. The answer comes back as this id, and it is
  /// checked against the list that was sent, so a name the model invented can
  /// never reach a card.
  final String id;

  final String name;
  final ContentFolder folder;

  /// The words a person would type next to the name in a map search: `성수`,
  /// `을지로`. Null for anything that does not sit anywhere — a recipe, a tip.
  final String? area;

  /// Subcategory first, then the axis labels. `닭발`, `술집`, `예약 가능`.
  final List<String> labels;

  /// How many captures of the same thing collapsed into this one.
  final int saveCount;

  final DateTime? lastSavedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    // The enum name rather than its Korean label, because this is a wire value.
    // Screen copy should be free to change without moving what the model reads.
    'folder': folder.name,
    if (area != null) 'area': area,
    if (labels.isNotEmpty) 'labels': labels,
    'saveCount': saveCount,
    if (lastSavedAt != null)
      'lastSavedAt': lastSavedAt!.toUtc().toIso8601String(),
  };
}

/// A product the reader confirmed and filed, as a candidate.
///
/// Groups predate the axis work and carry an identity rather than a place: a
/// brand, a name, an amount. They are half of what the 정리함 tab shows, and a
/// plan like "올리브영에서 뭐 사지" is about exactly this half.
RecommendationCandidate candidateFromGroup(
  ProductGroup group, {
  required ContentFolder folder,
  required String subcategory,
  int maxLabels = 8,
}) {
  final labels = <String>[];
  void add(String? value) {
    final label = value?.trim();
    if (label == null || label.isEmpty) return;
    if (labels.length >= maxLabels || labels.contains(label)) return;
    labels.add(label);
  }

  add(subcategory);
  add(group.identity.brand);
  add(group.identity.category);
  add(group.identity.amount);

  return RecommendationCandidate(
    id: group.id,
    name: group.identity.name,
    folder: folder,
    labels: List<String>.unmodifiable(labels),
    // Every capture filed under this product is the reader saving it again.
    saveCount: group.sourceCaptureIds.isEmpty
        ? 1
        : group.sourceCaptureIds.length,
    lastSavedAt: group.updatedAt,
  );
}

/// Turns what the reader has saved into the list a recommendation runs over.
///
/// Two things happen here and nothing else.
///
/// Captures with no analysis are left out — a card that never got a name is
/// nothing a plan can be pointed at. And captures of the same thing collapse
/// into one candidate carrying a count, because someone who screenshotted the
/// same shop three times has said something, and because three identical rows
/// invite three identical answers.
///
/// Collapsing is not ranking. Order is left exactly as it came in.
List<RecommendationCandidate> candidatesFromCaptures(
  Iterable<CaptureRecord> captures, {
  int maxLabels = 8,
}) {
  final byKey = <String, _Pending>{};
  final order = <String>[];

  for (final capture in captures) {
    final structured = capture.analysis?.structuredContent;
    if (structured == null) continue;

    final name = _nameOf(structured);
    if (name == null) continue;

    final folder = capture.contentFolder;
    final key = '${folder.name}|${_collapse(name)}';

    final pending = byKey[key];
    if (pending == null) {
      order.add(key);
      byKey[key] = _Pending(
        id: capture.raw.id,
        name: name,
        folder: folder,
        area: _areaOf(structured),
        labels: _labelsOf(structured, capture.contentSubcategory, maxLabels),
        saveCount: 1,
        lastSavedAt: capture.raw.receivedAt,
      );
      continue;
    }

    pending.saveCount += 1;
    // The newest capture speaks for the group: its area and labels came from
    // the most recent screenshot, which is the most likely to still be true.
    if (capture.raw.receivedAt.isAfter(pending.lastSavedAt)) {
      pending
        ..id = capture.raw.id
        ..name = name
        ..area = _areaOf(structured) ?? pending.area
        ..labels = _labelsOf(structured, capture.contentSubcategory, maxLabels)
        ..lastSavedAt = capture.raw.receivedAt;
    }
  }

  return List<RecommendationCandidate>.unmodifiable(
    order.map((key) => byKey[key]!.toCandidate()),
  );
}

String? _nameOf(StructuredContentAnalysis structured) {
  // A place's own name beats the caption a post was titled with: `화육계` is
  // what a reader would look for, `을지로 닭발 맛집` is how someone advertised it.
  final place = structured.place?.name?.trim();
  if (place != null && place.isNotEmpty) return place;
  final title = structured.title.value?.trim();
  if (title != null && title.isNotEmpty) return title;
  return null;
}

String? _areaOf(StructuredContentAnalysis structured) {
  final area = structured.place?.searchArea?.trim();
  return area == null || area.isEmpty ? null : area;
}

List<String> _labelsOf(
  StructuredContentAnalysis structured,
  String subcategory,
  int maxLabels,
) {
  final labels = <String>[];
  void add(String? value) {
    final label = value?.trim();
    if (label == null || label.isEmpty) return;
    if (labels.length >= maxLabels) return;
    if (labels.contains(label)) return;
    labels.add(label);
  }

  add(subcategory);
  for (final axis in ContentAxis.values) {
    for (final label in structured.axes[axis]) {
      add(label.value);
    }
  }
  return List<String>.unmodifiable(labels);
}

/// Lowercased and stripped of spaces and separators, so `화육계`, `화 육계`, and
/// `화육계 ` count as the same shop saved three times.
String _collapse(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[\s·ㆍ,./\-_]'), '');

final class _Pending {
  _Pending({
    required this.id,
    required this.name,
    required this.folder,
    required this.area,
    required this.labels,
    required this.saveCount,
    required this.lastSavedAt,
  });

  String id;
  String name;
  ContentFolder folder;
  String? area;
  List<String> labels;
  int saveCount;
  DateTime lastSavedAt;

  RecommendationCandidate toCandidate() => RecommendationCandidate(
    id: id,
    name: name,
    folder: folder,
    area: area,
    labels: labels,
    saveCount: saveCount,
    lastSavedAt: lastSavedAt,
  );
}
