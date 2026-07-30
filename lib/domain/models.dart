enum AnalysisStatus { processing, needsConfirmation, ready, failed }

enum Decision { undecided, candidate, hold, excluded }

enum OverlapLevel { low, medium, high }

enum InboxFilter { all, needsConfirmation, undecided, decided }

final class Product {
  const Product({
    required this.id,
    required this.brand,
    required this.name,
    required this.category,
    required this.sizeMl,
    required this.priceWon,
    required this.savedSourceCount,
    required this.sponsoredSourceCount,
    required this.concerns,
    required this.overlap,
    required this.summary,
    required this.reasons,
    required this.colorValue,
    this.analysisStatus = AnalysisStatus.ready,
    this.decision = Decision.undecided,
  });

  final String id;
  final String brand;
  final String name;
  final String category;
  final int sizeMl;
  final int priceWon;
  final int savedSourceCount;
  final int sponsoredSourceCount;
  final List<String> concerns;
  final OverlapLevel overlap;
  final String summary;
  final List<String> reasons;
  final int colorValue;
  final AnalysisStatus analysisStatus;
  final Decision decision;

  double get pricePerTenMl => priceWon / sizeMl * 10;

  Product copyWith({
    AnalysisStatus? analysisStatus,
    Decision? decision,
    int? savedSourceCount,
  }) {
    return Product(
      id: id,
      brand: brand,
      name: name,
      category: category,
      sizeMl: sizeMl,
      priceWon: priceWon,
      savedSourceCount: savedSourceCount ?? this.savedSourceCount,
      sponsoredSourceCount: sponsoredSourceCount,
      concerns: concerns,
      overlap: overlap,
      summary: summary,
      reasons: reasons,
      colorValue: colorValue,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      decision: decision ?? this.decision,
    );
  }
}

final class IncomingShare {
  const IncomingShare({
    required this.id,
    required this.receivedAt,
    required this.sharedText,
    required this.discoveredUrl,
    this.sourcePackage,
  });

  factory IncomingShare.fromPlatformMap(Map<Object?, Object?> map) {
    final text = map['sharedText'] as String? ?? '';
    final rawUrl = map['discoveredUrl'] as String?;

    return IncomingShare(
      id: map['id'] as String? ?? 'unknown-share',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        map['receivedAtEpochMs'] as int? ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      sharedText: text,
      discoveredUrl: rawUrl ?? extractFirstUrl(text),
      sourcePackage: map['sourcePackage'] as String?,
    );
  }

  final String id;
  final DateTime receivedAt;
  final String sharedText;
  final String? discoveredUrl;
  final String? sourcePackage;

  static String? extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    return match?.group(0)?.replaceFirst(RegExp(r'''[),.!?'"]+$'''), '');
  }
}

final class UserCriteria {
  const UserCriteria({
    required this.skinType,
    required this.isSensitive,
    required this.concerns,
    required this.routine,
  });

  final String skinType;
  final bool isSensitive;
  final List<String> concerns;
  final List<String> routine;

  UserCriteria copyWith({List<String>? concerns}) {
    return UserCriteria(
      skinType: skinType,
      isSensitive: isSensitive,
      concerns: concerns ?? this.concerns,
      routine: routine,
    );
  }
}
