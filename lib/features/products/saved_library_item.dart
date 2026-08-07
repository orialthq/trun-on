import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../analysis/structured_review_screen.dart';
import '../common/content_folder_ui.dart';
import '../product/product_detail_screen.dart';

/// A display-safe, data-backed item in the organized library.
///
/// The app currently stores legacy product groups and newer structured
/// captures side by side. This adapter lets the archive and its child screens
/// present both without inventing placeholder content.
final class SavedLibraryItem {
  const SavedLibraryItem._({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.searchableText,
    required this.folder,
    required this.subcategory,
    required this.axisLabels,
    required this.updatedAt,
    this.captureId,
    this.groupId,
  });

  /// The kind axis a user override belongs on, kept ahead of what the analysis
  /// proposed so a correction leads the deck.
  static Map<ContentAxis, List<String>> _axisLabelsFor(
    ContentAxes axes,
    String subcategory,
  ) {
    final kind = <String>[
      if (subcategory.trim().isNotEmpty) subcategory,
      for (final label in axes[ContentAxis.kind])
        if (label.value != subcategory) label.value,
    ];
    return {
      ContentAxis.kind: List.unmodifiable(kind),
      for (final axis in ContentAxis.values)
        if (axis != ContentAxis.kind)
          axis: List.unmodifiable(
            axes[axis].map((label) => label.value).toList(),
          ),
    };
  }

  factory SavedLibraryItem.forCapture(CaptureRecord capture) {
    final structured = capture.analysis!.structuredContent!;
    final title = structured.title.value?.trim();
    final facts = structured.facts
        .map((fact) => '${fact.label} ${fact.value}')
        .join(' ');
    return SavedLibraryItem._(
      id: capture.raw.id,
      title: title == null || title.isEmpty ? '제목 없음' : title,
      subtitle: structured.summary.trim(),
      searchableText: <String>[
        capture.contentFolder.label,
        capture.contentSubcategory,
        title ?? '',
        structured.summary,
        structured.place?.name ?? '',
        structured.place?.address ?? '',
        facts,
      ].join(' ').toLowerCase(),
      folder: capture.contentFolder,
      subcategory: capture.contentSubcategory,
      axisLabels: _axisLabelsFor(structured.axes, capture.contentSubcategory),
      updatedAt: capture.raw.receivedAt,
      captureId: capture.raw.id,
    );
  }

  factory SavedLibraryItem.forGroup(
    ProductGroup group,
    AppController controller,
  ) {
    final subcategory = controller.subcategoryForGroup(group.id);
    final folder = controller.folderForGroup(group.id);
    final statements = group.statements
        .map(
          (statement) => '${statement.topic} ${statement.originalExpression}',
        )
        .join(' ');
    return SavedLibraryItem._(
      id: group.id,
      title: group.identity.name,
      subtitle: <String>[
        group.identity.brand,
        group.identity.category,
        group.identity.amount,
      ].where((value) => value.trim().isNotEmpty).join(' · '),
      searchableText: <String>[
        folder.label,
        subcategory,
        group.identity.brand,
        group.identity.name,
        group.identity.category,
        group.identity.amount,
        statements,
      ].join(' ').toLowerCase(),
      folder: folder,
      subcategory: subcategory,
      // Legacy product groups predate axes and carry only a subcategory.
      axisLabels: _axisLabelsFor(const ContentAxes.empty(), subcategory),
      updatedAt: group.updatedAt,
      groupId: group.id,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String searchableText;
  final ContentFolder folder;
  final String subcategory;

  /// Labels per axis. A capture may appear on several cards of one axis, which
  /// is what lets the deck overlap.
  final Map<ContentAxis, List<String>> axisLabels;

  final DateTime updatedAt;
  final String? captureId;
  final String? groupId;

  List<String> labelsOn(ContentAxis axis) => axisLabels[axis] ?? const [];

  bool matches(String query) => searchableText.contains(query.toLowerCase());
}

List<SavedLibraryItem> savedLibraryItems(AppController controller) {
  final items = <SavedLibraryItem>[
    for (final capture in controller.organizedStructuredCaptures)
      SavedLibraryItem.forCapture(capture),
    for (final group in controller.groups)
      SavedLibraryItem.forGroup(group, controller),
  ];
  items.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return items;
}

void openSavedLibraryItem(
  BuildContext context, {
  required AppController controller,
  required SavedLibraryItem item,
}) {
  final captureId = item.captureId;
  final Route<void> route;
  if (captureId != null) {
    route = MaterialPageRoute<void>(
      builder: (_) =>
          StructuredReviewScreen(controller: controller, captureId: captureId),
    );
  } else {
    route = MaterialPageRoute<void>(
      builder: (_) =>
          ProductDetailScreen(controller: controller, groupId: item.groupId!),
    );
  }
  Navigator.of(context).push(route);
}
