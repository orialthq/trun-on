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
    required this.updatedAt,
    this.captureId,
    this.groupId,
  });

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
  final DateTime updatedAt;
  final String? captureId;
  final String? groupId;

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
