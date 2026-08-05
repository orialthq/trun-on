import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/content_folder_ui.dart';
import '../common/product_ui.dart';
import '../analysis/structured_review_screen.dart';
import '../product/product_detail_screen.dart';

final class ProductsScreen extends StatefulWidget {
  const ProductsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

final class _ProductsScreenState extends State<ProductsScreen> {
  ContentFolder? _selectedFolder;
  String? _selectedSubcategory;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allGroups = widget.controller.groups;
        final allStructuredCaptures =
            widget.controller.organizedStructuredCaptures;
        final total = allGroups.length + allStructuredCaptures.length;
        final selectedFolder = _selectedFolder;
        final folderGroups = selectedFolder == null
            ? allGroups
            : allGroups
                  .where(
                    (group) =>
                        widget.controller.folderForGroup(group.id) ==
                        selectedFolder,
                  )
                  .toList(growable: false);
        final folderStructuredCaptures = selectedFolder == null
            ? allStructuredCaptures
            : allStructuredCaptures
                  .where((capture) => capture.contentFolder == selectedFolder)
                  .toList(growable: false);
        final subcategoryCounts = <String, int>{};
        if (selectedFolder != null) {
          for (final group in folderGroups) {
            final name = widget.controller.subcategoryForGroup(group.id).trim();
            if (name.isNotEmpty) {
              subcategoryCounts.update(
                name,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
          for (final capture in folderStructuredCaptures) {
            final name = capture.contentSubcategory.trim();
            if (name.isNotEmpty) {
              subcategoryCounts.update(
                name,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
        }
        final sortedSubcategories = subcategoryCounts.entries.toList()
          ..sort((left, right) {
            final countOrder = right.value.compareTo(left.value);
            return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
          });
        final selectedSubcategory =
            _selectedSubcategory != null &&
                subcategoryCounts.containsKey(_selectedSubcategory)
            ? _selectedSubcategory
            : null;
        final subcategoryGroups = selectedSubcategory == null
            ? folderGroups
            : folderGroups
                  .where(
                    (group) =>
                        widget.controller.subcategoryForGroup(group.id) ==
                        selectedSubcategory,
                  )
                  .toList(growable: false);
        final subcategoryStructuredCaptures = selectedSubcategory == null
            ? folderStructuredCaptures
            : folderStructuredCaptures
                  .where(
                    (capture) =>
                        capture.contentSubcategory == selectedSubcategory,
                  )
                  .toList(growable: false);
        final query = _query.trim().toLowerCase();
        final groups = query.isEmpty
            ? subcategoryGroups
            : subcategoryGroups
                  .where((group) => _groupMatches(group, query))
                  .toList(growable: false);
        final structuredCaptures = query.isEmpty
            ? subcategoryStructuredCaptures
            : subcategoryStructuredCaptures
                  .where((capture) => _captureMatches(capture, query))
                  .toList(growable: false);
        final visibleTotal = groups.length + structuredCaptures.length;

        return ListView(
          key: const PageStorageKey('products'),
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            40 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '정리함',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$total',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              total == 0 ? '확인한 내용을 이곳에 차곡차곡 모아요' : '확인한 내용 $total개를 모아봤어요',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('library-search-field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppTheme.ink, fontSize: 15),
              decoration: InputDecoration(
                hintText: '제목, 장소, 태그 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색어 지우기',
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            _FolderGrid(
              controller: widget.controller,
              total: total,
              selected: selectedFolder,
              onSelected: (folder) {
                setState(() {
                  _selectedFolder = folder;
                  _selectedSubcategory = null;
                });
              },
            ),
            if (selectedFolder != null && sortedSubcategories.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SubcategoryFilters(
                folder: selectedFolder,
                entries: sortedSubcategories,
                selected: selectedSubcategory,
                onSelected: (subcategory) {
                  setState(() => _selectedSubcategory = subcategory);
                },
              ),
            ],
            const SizedBox(height: 32),
            if (total == 0)
              const _EmptyProducts()
            else if (visibleTotal == 0)
              query.isNotEmpty
                  ? const _EmptySearch()
                  : _EmptyFolder(folder: selectedFolder!)
            else ...[
              if (structuredCaptures.isNotEmpty) ...[
                const _ListHeading(title: '저장한 콘텐츠'),
                const SizedBox(height: 12),
                _StructuredList(
                  captures: structuredCaptures,
                  onSelected: (capture) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StructuredReviewScreen(
                          controller: widget.controller,
                          captureId: capture.raw.id,
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (groups.isNotEmpty) ...[
                if (structuredCaptures.isNotEmpty) const SizedBox(height: 28),
                const _ListHeading(title: '제품'),
                const SizedBox(height: 12),
                _ProductList(
                  groups: groups,
                  subcategoryForGroup: widget.controller.subcategoryForGroup,
                  onSelected: (group) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailScreen(
                          controller: widget.controller,
                          groupId: group.id,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  bool _captureMatches(CaptureRecord capture, String query) {
    final structured = capture.analysis?.structuredContent;
    final searchable = <String>[
      capture.contentFolder.label,
      capture.contentSubcategory,
      structured?.title.value ?? '',
      structured?.summary ?? '',
      structured?.place?.name ?? '',
      structured?.place?.address ?? '',
      for (final fact in structured?.facts ?? const <AnalysisFact>[])
        '${fact.label} ${fact.value}',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  bool _groupMatches(ProductGroup group, String query) {
    final searchable = <String>[
      group.identity.brand,
      group.identity.name,
      group.identity.category,
      group.identity.amount,
      widget.controller.subcategoryForGroup(group.id),
      for (final statement in group.statements)
        '${statement.topic} ${statement.originalExpression}',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }
}

final class _FolderGrid extends StatelessWidget {
  const _FolderGrid({
    required this.controller,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  final AppController controller;
  final int total;
  final ContentFolder? selected;
  final ValueChanged<ContentFolder?> onSelected;

  @override
  Widget build(BuildContext context) {
    final needsClassificationCount = controller.organizedCountForFolder(
      ContentFolder.needsClassification,
    );
    final folders = <ContentFolder>[
      ...defaultContentFolders,
      if (needsClassificationCount > 0) ContentFolder.needsClassification,
    ];
    final items = <Widget>[
      _FolderCard(
        key: const Key('folder-all'),
        label: '전체',
        count: total,
        icon: Icons.grid_view_rounded,
        color: AppTheme.primary,
        selected: selected == null,
        onTap: () => onSelected(null),
      ),
      for (final folder in folders)
        _FolderCard(
          key: Key('folder-${folder.name}'),
          label: folder.label,
          count: controller.organizedCountForFolder(folder),
          icon: folder.icon,
          color: folder.color,
          selected: selected == folder,
          onTap: () => onSelected(folder),
        ),
    ];

    final cardHeight = (72 + MediaQuery.textScalerOf(context).scale(14))
        .clamp(90.0, 128.0)
        .toDouble();
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) => SizedBox(width: 138, child: items[index]),
      ),
    );
  }
}

final class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 폴더, $count개',
      child: Material(
        color: selected ? AppTheme.primarySoft : AppTheme.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      color.withValues(alpha: 0.16),
                      AppTheme.surfaceRaised,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count개',
                        style: TextStyle(
                          color: selected ? AppTheme.primary : AppTheme.subtle,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SubcategoryFilters extends StatelessWidget {
  const _SubcategoryFilters({
    required this.folder,
    required this.entries,
    required this.selected,
    required this.onSelected,
  });

  final ContentFolder folder;
  final List<MapEntry<String, int>> entries;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    final chipHeight = (20 + MediaQuery.textScalerOf(context).scale(13))
        .clamp(44.0, 68.0)
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              '${folder.label} 하위 폴더',
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'AI 분류 · 선택해서 보기',
              style: TextStyle(color: AppTheme.subtle, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: chipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SubcategoryChip(
                  key: const Key('subcategory-all'),
                  label: '전체',
                  count: total,
                  selected: selected == null,
                  color: folder.color,
                  onTap: () => onSelected(null),
                );
              }
              final entry = entries[index - 1];
              return _SubcategoryChip(
                key: Key('subcategory-${entry.key}'),
                label: entry.key,
                count: entry.value,
                selected: selected == entry.key,
                color: folder.color,
                onTap: () => onSelected(entry.key),
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count개',
      child: Material(
        color: selected ? color : AppTheme.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? color : AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Center(
              child: Text(
                '$label $count',
                style: TextStyle(
                  color: selected ? const Color(0xFF0B0B0D) : AppTheme.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

final class _StructuredList extends StatelessWidget {
  const _StructuredList({required this.captures, required this.onSelected});

  final List<CaptureRecord> captures;
  final ValueChanged<CaptureRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < captures.length; index++) ...[
            _StructuredRow(
              capture: captures[index],
              onTap: () => onSelected(captures[index]),
            ),
            if (index != captures.length - 1)
              const Divider(height: 1, indent: 92, endIndent: 18),
          ],
        ],
      ),
    );
  }
}

final class _StructuredRow extends StatelessWidget {
  const _StructuredRow({required this.capture, required this.onTap});

  final CaptureRecord capture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final structured = capture.analysis!.structuredContent!;
    final folder = capture.contentFolder;
    final attachment = capture.raw.attachments.isEmpty
        ? null
        : capture.raw.attachments.first;
    return Semantics(
      button: true,
      label: '${structured.title.value ?? '제목 없음'}, ${folder.label}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 62,
                  height: 72,
                  child: ColoredBox(
                    color: folder.softColor,
                    child: attachment == null
                        ? Icon(folder.icon, color: folder.color)
                        : Image.file(
                            File(attachment.filePath),
                            fit: BoxFit.cover,
                            cacheWidth: 186,
                            errorBuilder: (_, _, _) =>
                                Icon(folder.icon, color: folder.color),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        folder.label,
                        capture.contentSubcategory,
                        _contentKindLabel(structured.contentKind),
                        if (structured.title.status == ObservedStatus.inferred)
                          '제목 추정',
                        if (structured.title.status == ObservedStatus.missing)
                          '제목 없음',
                      ].join(' · '),
                      style: TextStyle(
                        color: folder.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      structured.title.value ?? '제목 없음',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (structured.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        structured.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.subtle,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _contentKindLabel(ContentKind kind) {
    return switch (kind) {
      ContentKind.recipe => '레시피',
      ContentKind.sauceRecipe => '소스 레시피',
      ContentKind.commerceProduct => '상품',
      ContentKind.productReview => '제품 리뷰',
      ContentKind.menuComparison => '메뉴 비교',
      ContentKind.beautyProduct => '뷰티 제품',
      ContentKind.place => '장소',
      ContentKind.unknown => '정보',
    };
  }
}

final class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.groups,
    required this.subcategoryForGroup,
    required this.onSelected,
  });

  final List<ProductGroup> groups;
  final String Function(String groupId) subcategoryForGroup;
  final ValueChanged<ProductGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var index = 0; index < groups.length; index++) ...[
              _ProductRow(
                group: groups[index],
                subcategory: subcategoryForGroup(groups[index].id),
                onTap: () => onSelected(groups[index]),
              ),
              if (index != groups.length - 1)
                const Divider(indent: 100, endIndent: 20),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.group,
    required this.subcategory,
    required this.onTap,
  });

  final ProductGroup group;
  final String subcategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final repeatedTopic = _mostRepeatedTopic(group);
    final meta = [
      group.identity.category,
      group.identity.amount,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Semantics(
      button: true,
      label: '${group.identity.brand} ${group.identity.name}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: [
              ProductArt.forGroup(group, width: 68, height: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        subcategory,
                        group.identity.brand,
                      ].where((value) => value.trim().isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.identity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.subtle,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Text(
                      repeatedTopic == null
                          ? '콘텐츠 ${group.sourceCount}개'
                          : '콘텐츠 ${group.sourceCount}개 · ${repeatedTopic.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: repeatedTopic == null
                            ? AppTheme.muted
                            : AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.subtle,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TopicSummary? _mostRepeatedTopic(ProductGroup group) {
    final sourcesByTopic = <String, Set<String>>{};
    for (final statement in group.statements) {
      if (statement.type == StatementType.disclosure) {
        continue;
      }
      sourcesByTopic
          .putIfAbsent(statement.topic, () => <String>{})
          .add(statement.captureId);
    }

    final topics =
        sourcesByTopic.entries
            .map(
              (entry) => _TopicSummary(
                label: entry.key,
                sourceCount: entry.value.length,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final countOrder = right.sourceCount.compareTo(left.sourceCount);
            return countOrder != 0
                ? countOrder
                : left.label.compareTo(right.label);
          });

    if (topics.isEmpty || topics.first.sourceCount < 2) {
      return null;
    }
    return topics.first;
  }
}

final class _TopicSummary {
  const _TopicSummary({required this.label, required this.sourceCount});

  final String label;
  final int sourceCount;
}

final class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({required this.folder});

  final ContentFolder folder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
      child: Column(
        children: [
          Icon(folder.icon, size: 34, color: folder.color),
          const SizedBox(height: 16),
          Text(
            '${folder.label} 폴더가 비어 있어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            folder.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

final class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: AppTheme.subtle,
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과가 없어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          const Text(
            '다른 제목, 장소 또는 태그로 찾아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

final class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 40),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppTheme.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 30,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '아직 정리된 내용이 없어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '캡처를 확인하면 알맞은 폴더에\n차곡차곡 정리해 드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }
}
