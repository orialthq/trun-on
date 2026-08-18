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
        final itemsByFolder = <ContentFolder, List<SavedLibraryItem>>{
          for (final folder in defaultContentFolders) folder: [],
        };
        for (final item in items) {
          itemsByFolder[item.folder]?.add(item);
        }
        final needsClassificationCount = items
            .where((item) => item.folder == ContentFolder.needsClassification)
            .length;

        return Theme(
          data: AppTheme.plansTheme(Theme.of(context)),
          child: ColoredBox(
            color: AppTheme.planCanvas,
            child: ListView(
              key: const PageStorageKey('products'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                22,
                28,
                22,
                44 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _ArchiveHeader(total: items.length),
                if (needsClassificationCount > 0) ...[
                  const SizedBox(height: 24),
                  _NeedsClassificationBanner(
                    count: needsClassificationCount,
                    onTap: () => _openSubcategories(
                      folder: ContentFolder.needsClassification,
                    ),
                  ),
                ],
                const SizedBox(height: 34),
                _FolderList(
                  selected: _selectedFolder,
                  itemsByFolder: itemsByFolder,
                  onSelected: (folder) {
                    setState(() => _selectedFolder = folder);
                  },
                  onOpenSubcategories: ({initialSubcategory}) =>
                      _openSubcategories(
                        initialSubcategory: initialSubcategory,
                      ),
                  onOpenItem: (item) => openSavedLibraryItem(
                    context,
                    controller: widget.controller,
                    item: item,
                  ),
                ),
              ],
            ),
          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('정리함', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 7),
              const Text(
                '저장한 내용을 폴더별로 차분히 모아 봐요.',
                style: TextStyle(
                  color: AppTheme.planMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Semantics(
          label: '저장된 콘텐츠 $total개',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '$total개',
                style: const TextStyle(
                  color: AppTheme.planSubtle,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
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
      color: Colors.transparent,
      shape: const Border(
        top: BorderSide(color: AppTheme.planBorder),
        bottom: BorderSide(color: AppTheme.planBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '분류가 필요한 콘텐츠 $count개, 세부 분류 확인',
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 36,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.planSandSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          folder.icon,
                          color: AppTheme.planSand,
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '분류가 필요한 콘텐츠 $count개',
                            style: const TextStyle(
                              color: AppTheme.planInk,
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '폴더를 정해 정리함에 넣어 주세요.',
                            style: TextStyle(
                              color: AppTheme.planMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.planSubtle,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _FolderList extends StatefulWidget {
  const _FolderList({
    required this.selected,
    required this.itemsByFolder,
    required this.onSelected,
    required this.onOpenSubcategories,
    required this.onOpenItem,
  });

  final ContentFolder selected;
  final Map<ContentFolder, List<SavedLibraryItem>> itemsByFolder;
  final ValueChanged<ContentFolder> onSelected;
  final void Function({String? initialSubcategory}) onOpenSubcategories;
  final ValueChanged<SavedLibraryItem> onOpenItem;

  @override
  State<_FolderList> createState() => _FolderListState();
}

final class _FolderListState extends State<_FolderList> {
  late int _centeredIndex;

  @override
  void initState() {
    super.initState();
    _centeredIndex = _folderIndex(widget.selected);
  }

  @override
  void didUpdateWidget(covariant _FolderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _folderIndex(widget.selected);
    if (nextIndex == _centeredIndex) {
      return;
    }
    _centeredIndex = nextIndex;
  }

  int _folderIndex(ContentFolder folder) {
    final index = defaultContentFolders.indexOf(folder);
    return index < 0 ? 0 : index;
  }

  void _selectIndex(int index) {
    final boundedIndex = index.clamp(0, defaultContentFolders.length - 1);
    if (boundedIndex == _centeredIndex) return;
    setState(() => _centeredIndex = boundedIndex);
    widget.onSelected(defaultContentFolders[boundedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final folder = defaultContentFolders[_centeredIndex];
    final items = widget.itemsByFolder[folder] ?? const <SavedLibraryItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('폴더', style: Theme.of(context).textTheme.titleLarge),
            ),
            const Text(
              '8개',
              style: TextStyle(
                color: AppTheme.planSubtle,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Semantics(
          label: '상위 폴더 목록, ${folder.label} 선택됨',
          child: Material(
            key: const Key('folder-roulette'),
            color: Colors.transparent,
            shape: const Border(
              top: BorderSide(color: AppTheme.planBorder),
              bottom: BorderSide(color: AppTheme.planBorder),
            ),
            child: Column(
              key: const Key('top-folder-wheel'),
              children: [
                for (
                  var index = 0;
                  index < defaultContentFolders.length;
                  index++
                ) ...[
                  _FolderOptionRow(
                    key: Key('folder-${defaultContentFolders[index].name}'),
                    folder: defaultContentFolders[index],
                    count:
                        widget
                            .itemsByFolder[defaultContentFolders[index]]
                            ?.length ??
                        0,
                    selected: index == _centeredIndex,
                    onTap: () => _selectIndex(index),
                  ),
                  if (index == _centeredIndex)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 2, 10, 22),
                      child: _FolderDetails(
                        key: Key('folder-detail-${folder.name}'),
                        folder: folder,
                        items: items,
                        onOpenSubcategories: widget.onOpenSubcategories,
                        onOpenItem: widget.onOpenItem,
                      ),
                    ),
                  if (index != defaultContentFolders.length - 1)
                    const Divider(indent: 30),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _FolderOptionRow extends StatelessWidget {
  const _FolderOptionRow({
    required this.folder,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ContentFolder folder;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${folder.label} 폴더, $count개',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 48),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppTheme.planMauveSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 8 : 6,
                    height: selected ? 8 : 6,
                    decoration: BoxDecoration(
                      color: selected
                          ? folder.color.withValues(alpha: 0.82)
                          : AppTheme.planBorder,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      folder.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? AppTheme.planInk : AppTheme.planMuted,
                        fontSize: selected ? 17 : 14,
                        height: 1.35,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: selected
                          ? AppTheme.planMuted
                          : AppTheme.planSubtle,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _FolderDetails extends StatelessWidget {
  const _FolderDetails({
    required this.folder,
    required this.items,
    required this.onOpenSubcategories,
    required this.onOpenItem,
    super.key,
  });

  final ContentFolder folder;
  final List<SavedLibraryItem> items;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          folder.description,
          style: const TextStyle(
            color: AppTheme.planMuted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        const Divider(),
        if (items.isEmpty)
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: _EmptyFolderMessage(folder: folder),
            ),
          )
        else ...[
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '하위 분류',
                  style: TextStyle(
                    color: AppTheme.planInk,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${subcategories.length}',
                style: const TextStyle(
                  color: AppTheme.planSubtle,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subcategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final entry = subcategories[index];
                return _SubcategoryChip(
                  key: Key('subcategory-${entry.key}'),
                  label: entry.key,
                  count: entry.value,
                  onTap: () =>
                      onOpenSubcategories(initialSubcategory: entry.key),
                );
              },
            ),
          ),
          const SizedBox(height: 27),
          const Text(
            '최근 저장',
            style: TextStyle(
              color: AppTheme.planInk,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          _RecentItemRow(
            item: items.first,
            onTap: () => onOpenItem(items.first),
          ),
          const SizedBox(height: 17),
          _OpenSubcategoriesButton(
            folder: folder,
            subcategoryCount: subcategories.length,
            onTap: () => onOpenSubcategories(),
          ),
        ],
      ],
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
    return Semantics(
      button: true,
      label: '$label 하위 분류, $count개',
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: AppTheme.planBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Center(
                  child: Text(
                    '$label  $count',
                    style: const TextStyle(
                      color: AppTheme.planMuted,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
    return Semantics(
      button: true,
      label: '최근 저장, ${item.title}, 열기',
      child: Material(
        color: Colors.transparent,
        shape: const Border(
          top: BorderSide(color: AppTheme.planBorder),
          bottom: BorderSide(color: AppTheme.planBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 62),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bookmark_border_rounded,
                      size: 19,
                      color: AppTheme.planSubtle,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.planInk,
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subcategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.planSubtle,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppTheme.planSubtle,
                    ),
                  ],
                ),
              ),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${folder.label} 세부 분류 $subcategoryCount개 열기',
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '세부 분류 열기 · $subcategoryCount',
                      style: const TextStyle(
                        color: AppTheme.planInk,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.planMuted,
                    size: 18,
                  ),
                ],
              ),
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
        Icon(folder.icon, size: 28, color: AppTheme.planSubtle),
        const SizedBox(height: 12),
        Text(
          '${folder.label} 폴더가 비어 있어요',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.planMuted,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          '새로 정리한 콘텐츠가 여기에 모여요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.planSubtle,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
