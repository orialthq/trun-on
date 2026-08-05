import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/content_folder_ui.dart';
import 'saved_library_item.dart';
import 'subcategory_deck_screen.dart';

final class ProductsScreen extends StatefulWidget {
  const ProductsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

final class _ProductsScreenState extends State<ProductsScreen> {
  ContentFolder _selectedFolder = ContentFolder.beauty;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSubcategories({String? initialSubcategory, ContentFolder? folder}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubcategoryDeckScreen(
          controller: widget.controller,
          folder: folder ?? _selectedFolder,
          initialSubcategory: initialSubcategory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final items = savedLibraryItems(widget.controller);
        final query = _query.trim().toLowerCase();
        final searchResults = query.isEmpty
            ? const <SavedLibraryItem>[]
            : items
                  .where((item) => item.matches(query))
                  .toList(growable: false);
        final itemsByFolder = <ContentFolder, List<SavedLibraryItem>>{
          for (final folder in defaultContentFolders) folder: [],
        };
        for (final item in items) {
          itemsByFolder[item.folder]?.add(item);
        }
        final needsClassificationCount = items
            .where((item) => item.folder == ContentFolder.needsClassification)
            .length;

        return ListView(
          key: const PageStorageKey('products'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            22,
            20,
            40 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _ArchiveHeader(total: items.length),
            const SizedBox(height: 24),
            _UnifiedSearch(
              controller: _searchController,
              query: _query,
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                FocusScope.of(context).unfocus();
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            if (query.isEmpty && needsClassificationCount > 0) ...[
              const SizedBox(height: 14),
              _NeedsClassificationBanner(
                count: needsClassificationCount,
                onTap: () => _openSubcategories(
                  folder: ContentFolder.needsClassification,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (query.isNotEmpty)
              _SearchResults(
                query: _query.trim(),
                items: searchResults,
                onSelected: (item) => openSavedLibraryItem(
                  context,
                  controller: widget.controller,
                  item: item,
                ),
              )
            else
              _FolderStack(
                selected: _selectedFolder,
                itemsByFolder: itemsByFolder,
                onSelected: (folder) {
                  setState(() => _selectedFolder = folder);
                },
                onOpenSubcategories: ({initialSubcategory}) =>
                    _openSubcategories(initialSubcategory: initialSubcategory),
                onOpenItem: (item) => openSavedLibraryItem(
                  context,
                  controller: widget.controller,
                  item: item,
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _ArchiveHeader extends StatelessWidget {
  const _ArchiveHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A R C H I V E',
                style: TextStyle(
                  color: AppTheme.subtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '정리함',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 42,
                  letterSpacing: -1.8,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                '저장됨',
                style: TextStyle(
                  color: AppTheme.subtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _UnifiedSearch extends StatelessWidget {
  const _UnifiedSearch({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 9),
              child: Row(
                children: [
                  Text(
                    'CROSS',
                    style: TextStyle(
                      color: AppTheme.subtle,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '8개 폴더를 한 번에 찾기',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              key: const Key('library-search-field'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppTheme.ink, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                hintText: '제목, 장소, 태그 검색',
                prefixIcon: const Icon(Icons.search_rounded, size: 21),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색어 지우기',
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NeedsClassificationBanner extends StatelessWidget {
  const _NeedsClassificationBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final folder = ContentFolder.needsClassification;
    return Material(
      key: const Key('folder-needsClassification'),
      color: AppTheme.accentSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: folder.color.withValues(alpha: 0.46)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                Icon(folder.icon, color: folder.color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '분류가 필요한 콘텐츠 $count개',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '눌러서 AI 분류 결과를 확인해요',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.caution,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _FolderStack extends StatelessWidget {
  const _FolderStack({
    required this.selected,
    required this.itemsByFolder,
    required this.onSelected,
    required this.onOpenSubcategories,
    required this.onOpenItem,
  });

  static const _collapsedHeight = 116.0;
  static const _expandedHeight = 322.0;
  static const _step = 72.0;
  static const _expansionOffset = _expandedHeight - _collapsedHeight;

  final ContentFolder selected;
  final Map<ContentFolder, List<SavedLibraryItem>> itemsByFolder;
  final ValueChanged<ContentFolder> onSelected;
  final void Function({String? initialSubcategory}) onOpenSubcategories;
  final ValueChanged<SavedLibraryItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = defaultContentFolders.indexOf(selected);
    final cards = <Widget>[];
    for (var index = 0; index < defaultContentFolders.length; index++) {
      if (index == selectedIndex) {
        continue;
      }
      cards.add(_positionedCard(index, selectedIndex));
    }
    cards.add(_positionedCard(selectedIndex, selectedIndex));

    final height = (defaultContentFolders.length - 1) * _step + _expandedHeight;
    return SizedBox(
      height: height,
      child: Stack(clipBehavior: Clip.none, children: cards),
    );
  }

  Widget _positionedCard(int index, int selectedIndex) {
    final folder = defaultContentFolders[index];
    final expanded = index == selectedIndex;
    final top = index * _step + (index > selectedIndex ? _expansionOffset : 0);
    return AnimatedPositioned(
      key: ValueKey('folder-position-${folder.name}'),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      top: top,
      height: expanded ? _expandedHeight : _collapsedHeight,
      child: _FolderCard(
        key: Key('folder-${folder.name}'),
        folder: folder,
        items: itemsByFolder[folder] ?? const [],
        expanded: expanded,
        onTap: expanded ? null : () => onSelected(folder),
        onOpenSubcategories: onOpenSubcategories,
        onOpenItem: onOpenItem,
      ),
    );
  }
}

final class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.items,
    required this.expanded,
    required this.onTap,
    required this.onOpenSubcategories,
    required this.onOpenItem,
    super.key,
  });

  final ContentFolder folder;
  final List<SavedLibraryItem> items;
  final bool expanded;
  final VoidCallback? onTap;
  final void Function({String? initialSubcategory}) onOpenSubcategories;
  final ValueChanged<SavedLibraryItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final subcategoryCounts = <String, int>{};
    for (final item in items) {
      subcategoryCounts.update(
        item.subcategory,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final subcategories = subcategoryCounts.entries.toList()
      ..sort((left, right) {
        final countOrder = right.value.compareTo(left.value);
        return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
      });

    return Semantics(
      button: !expanded,
      selected: expanded,
      label: '${folder.label} 폴더, ${items.length}개',
      child: Material(
        color: folder.color,
        elevation: expanded ? 12 : 5,
        shadowColor: folder.color.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showExpandedContent =
                  expanded &&
                  constraints.maxHeight >= _FolderStack._expandedHeight - 1;
              final showArchiveCode =
                  showExpandedContent ||
                  MediaQuery.textScalerOf(context).scale(10) <= 13;
              return Padding(
                padding: const EdgeInsets.fromLTRB(25, 19, 25, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            folder.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1B100C),
                              fontSize: 31,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1B100C,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${items.length}',
                            style: const TextStyle(
                              color: Color(0xFF1B100C),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showArchiveCode) ...[
                      const SizedBox(height: 5),
                      Text(
                        folder.archiveCode,
                        style: TextStyle(
                          color: const Color(
                            0xFF1B100C,
                          ).withValues(alpha: 0.58),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ],
                    if (showExpandedContent) ...[
                      const SizedBox(height: 14),
                      if (items.isEmpty)
                        Expanded(child: _EmptyFolderMessage(folder: folder))
                      else ...[
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: subcategories.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 7),
                            itemBuilder: (context, index) {
                              final entry = subcategories[index];
                              return _SubcategoryChip(
                                key: Key('subcategory-${entry.key}'),
                                label: entry.key,
                                count: entry.value,
                                onTap: () => onOpenSubcategories(
                                  initialSubcategory: entry.key,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 11),
                        _RecentItemRow(
                          item: items.first,
                          onTap: () => onOpenItem(items.first),
                        ),
                        const Spacer(),
                        _OpenSubcategoriesButton(
                          folder: folder,
                          subcategoryCount: subcategories.length,
                          onTap: () => onOpenSubcategories(),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.label,
    required this.count,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B100C).withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                '$label $count',
                style: const TextStyle(
                  color: Color(0xFF1B100C),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _RecentItemRow extends StatelessWidget {
  const _RecentItemRow({required this.item, required this.onTap});

  final SavedLibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B100C).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_rounded,
                  size: 18,
                  color: Color(0xFF1B100C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1B100C),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Color(0xFF1B100C),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _OpenSubcategoriesButton extends StatelessWidget {
  const _OpenSubcategoriesButton({
    required this.folder,
    required this.subcategoryCount,
    required this.onTap,
  });

  final ContentFolder folder;
  final int subcategoryCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('open-subcategories-${folder.name}'),
      color: const Color(0xFF24100A),
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'AI 하위 분류 열기 · $subcategoryCount',
                    style: TextStyle(
                      color: folder.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: folder.color,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _EmptyFolderMessage extends StatelessWidget {
  const _EmptyFolderMessage({required this.folder});

  final ContentFolder folder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          folder.icon,
          size: 28,
          color: const Color(0xFF1B100C).withValues(alpha: 0.64),
        ),
        const SizedBox(height: 10),
        Text(
          '${folder.label} 폴더가 비어 있어요',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1B100C),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          folder.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF1B100C).withValues(alpha: 0.65),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

final class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.items,
    required this.onSelected,
  });

  final String query;
  final List<SavedLibraryItem> items;
  final ValueChanged<SavedLibraryItem> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 72),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 38, color: AppTheme.subtle),
            SizedBox(height: 14),
            Text(
              '검색 결과가 없어요',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '다른 제목, 장소 또는 태그로 찾아보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '“$query” ${items.length}개',
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < items.length; index++) ...[
          _SearchResultRow(
            item: items[index],
            onTap: () => onSelected(items[index]),
          ),
          if (index != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

final class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.item, required this.onTap});

  final SavedLibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 76,
        onTap: onTap,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: item.folder.softColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.folder.icon, color: item.folder.color, size: 21),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${item.folder.label} · ${item.subcategory}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.muted),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

extension on ContentFolder {
  String get archiveCode => switch (this) {
    ContentFolder.beauty => 'B E A U T Y',
    ContentFolder.healthFitness => 'F I T N E S S',
    ContentFolder.restaurantCafe => 'E A T S  &  C A F E',
    ContentFolder.recipe => 'R E C I P E',
    ContentFolder.shopping => 'S H O P P I N G',
    ContentFolder.travelPlace => 'T R A V E L  &  P L A C E',
    ContentFolder.lifeTip => 'L I F E  T I P S',
    ContentFolder.other => 'O T H E R',
    ContentFolder.needsClassification => 'U N S O R T E D',
  };
}
