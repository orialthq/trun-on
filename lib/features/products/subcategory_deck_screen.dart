import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/content_folder_ui.dart';
import 'saved_library_item.dart';

final class SubcategoryDeckScreen extends StatefulWidget {
  const SubcategoryDeckScreen({
    required this.controller,
    required this.folder,
    this.initialSubcategory,
    super.key,
  });

  final AppController controller;
  final ContentFolder folder;
  final String? initialSubcategory;

  @override
  State<SubcategoryDeckScreen> createState() => _SubcategoryDeckScreenState();
}

final class _SubcategoryDeckScreenState extends State<SubcategoryDeckScreen> {
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSubcategory;
    if (initial != null) {
      final index = _groupedItems().indexWhere((entry) => entry.key == initial);
      if (index >= 0) {
        _selectedIndex = index;
      }
    }
  }

  List<MapEntry<String, List<SavedLibraryItem>>> _groupedItems() {
    final grouped = <String, List<SavedLibraryItem>>{};
    for (final item in savedLibraryItems(widget.controller)) {
      if (item.folder != widget.folder) {
        continue;
      }
      grouped.putIfAbsent(item.subcategory, () => []).add(item);
    }
    final entries = grouped.entries.toList()
      ..sort((left, right) {
        final countOrder = right.value.length.compareTo(left.value.length);
        return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
      });
    return entries;
  }

  void _moveBy(int amount, int length) {
    if (length < 2) {
      return;
    }
    setState(() {
      _selectedIndex = (_selectedIndex + amount) % length;
      if (_selectedIndex < 0) {
        _selectedIndex += length;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final groupedItems = _groupedItems();
        final selectedIndex = groupedItems.isEmpty
            ? 0
            : _selectedIndex.clamp(0, groupedItems.length - 1);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            titleSpacing: 2,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.folder.archiveCode,
                  style: TextStyle(
                    color: widget.folder.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.folder.label,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
            actions: [
              if (groupedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${selectedIndex + 1}/${groupedItems.length}',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        '하위 분류',
                        style: TextStyle(
                          color: AppTheme.subtle,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: groupedItems.isEmpty
              ? _EmptyDeck(folder: widget.folder)
              : ListView(
                  key: PageStorageKey('subcategory-deck-${widget.folder.name}'),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    36 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: widget.folder.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AI 하위 분류',
                              style: TextStyle(
                                color: Color(0xFF16120F),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() < 180) {
                          return;
                        }
                        _moveBy(velocity < 0 ? 1 : -1, groupedItems.length);
                      },
                      child: _SubcategoryDeck(
                        controller: widget.controller,
                        folder: widget.folder,
                        entries: groupedItems,
                        selectedIndex: selectedIndex,
                        onSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DeckControl(
                          tooltip: '이전 하위 분류',
                          icon: Icons.arrow_upward_rounded,
                          onPressed: groupedItems.length > 1
                              ? () => _moveBy(-1, groupedItems.length)
                              : null,
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              groupedItems.length > 1
                                  ? '카드를 밀거나 버튼으로 넘겨요'
                                  : '하위 분류가 1개예요',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.subtle,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        _DeckControl(
                          tooltip: '다음 하위 분류',
                          icon: Icons.arrow_downward_rounded,
                          onPressed: groupedItems.length > 1
                              ? () => _moveBy(1, groupedItems.length)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

final class _SubcategoryDeck extends StatelessWidget {
  const _SubcategoryDeck({
    required this.controller,
    required this.folder,
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _collapsedHeight = 112.0;
  static const _expandedHeight = 356.0;
  static const _step = 68.0;
  static const _expansionOffset = _expandedHeight - _collapsedHeight;

  final AppController controller;
  final ContentFolder folder;
  final List<MapEntry<String, List<SavedLibraryItem>>> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final height =
        (entries.length - 1) * _step +
        _expandedHeight +
        (entries.isEmpty ? 0 : 0);
    final cards = <Widget>[];
    for (var index = 0; index < entries.length; index++) {
      if (index == selectedIndex) {
        continue;
      }
      cards.add(_positionedCard(context, index));
    }
    cards.add(_positionedCard(context, selectedIndex));

    return SizedBox(
      height: height,
      child: Stack(clipBehavior: Clip.none, children: cards),
    );
  }

  Widget _positionedCard(BuildContext context, int index) {
    final selected = index == selectedIndex;
    final top = index * _step + (index > selectedIndex ? _expansionOffset : 0);
    return AnimatedPositioned(
      key: ValueKey('deck-position-${entries[index].key}'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      top: top,
      height: selected ? _expandedHeight : _collapsedHeight,
      child: _SubcategoryCard(
        key: Key('subcategory-${entries[index].key}'),
        controller: controller,
        folder: folder,
        index: index,
        name: entries[index].key,
        items: entries[index].value,
        expanded: selected,
        onTap: selected ? null : () => onSelected(index),
      ),
    );
  }
}

final class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({
    required this.controller,
    required this.folder,
    required this.index,
    required this.name,
    required this.items,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final AppController controller;
  final ContentFolder folder;
  final int index;
  final String name;
  final List<SavedLibraryItem> items;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _subcategoryColor(index, folder.color);
    final foreground = const Color(0xFF1B100C);
    return Semantics(
      button: !expanded,
      selected: expanded,
      label: '$name 하위 분류, ${items.length}개',
      child: Material(
        color: color,
        elevation: expanded ? 12 : 4,
        shadowColor: color.withValues(alpha: 0.36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showExpandedContent =
                  expanded &&
                  constraints.maxHeight >= _SubcategoryDeck._expandedHeight - 1;
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 29,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${items.length}',
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.62),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    if (showExpandedContent) ...[
                      const SizedBox(height: 17),
                      for (final item in items.take(3)) ...[
                        _DeckItemRow(
                          item: item,
                          onTap: () => openSavedLibraryItem(
                            context,
                            controller: controller,
                            item: item,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (items.length > 3)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: foreground,
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SubcategoryContentsScreen(
                                    controller: controller,
                                    folder: folder,
                                    subcategory: name,
                                  ),
                                ),
                              );
                            },
                            child: Text('전체 ${items.length}개 보기  →'),
                          ),
                        ),
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

final class _DeckItemRow extends StatelessWidget {
  const _DeckItemRow({required this.item, required this.onTap});

  final SavedLibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF32170F).withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF32170F).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    color: Color(0xFF32170F),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1B100C),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF32170F),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _DeckControl extends StatelessWidget {
  const _DeckControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(64),
        backgroundColor: AppTheme.surfaceRaised,
        disabledBackgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.ink,
        disabledForegroundColor: AppTheme.subtle,
        side: const BorderSide(color: AppTheme.border),
      ),
      icon: Icon(icon),
    );
  }
}

final class SubcategoryContentsScreen extends StatelessWidget {
  const SubcategoryContentsScreen({
    required this.controller,
    required this.folder,
    required this.subcategory,
    super.key,
  });

  final AppController controller;
  final ContentFolder folder;
  final String subcategory;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = savedLibraryItems(controller)
            .where(
              (item) =>
                  item.folder == folder && item.subcategory == subcategory,
            )
            .toList(growable: false);
        return Scaffold(
          appBar: AppBar(title: Text(subcategory)),
          body: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              36 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Material(
                color: AppTheme.surfaceRaised,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppTheme.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  minTileHeight: 70,
                  onTap: () => openSavedLibraryItem(
                    context,
                    controller: controller,
                    item: item,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: folder.softColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(folder.icon, color: folder.color, size: 20),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: item.subtitle.isEmpty
                      ? null
                      : Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

final class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.folder});

  final ContentFolder folder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(folder.icon, color: folder.color, size: 40),
            const SizedBox(height: 16),
            Text(
              '${folder.label} 폴더가 비어 있어요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              folder.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

Color _subcategoryColor(int index, Color seed) {
  const palette = <Color>[
    Color(0xFFFFB300),
    Color(0xFFFF6845),
    Color(0xFFE93F91),
    Color(0xFFFF8845),
    Color(0xFFE76867),
    Color(0xFFF2C02F),
    Color(0xFFB061E8),
    Color(0xFF24CFC8),
  ];
  if (index == 0) {
    return seed;
  }
  return palette[(index - 1) % palette.length];
}

extension on ContentFolder {
  String get archiveCode => switch (this) {
    ContentFolder.beauty => 'BEAUTY',
    ContentFolder.healthFitness => 'FITNESS',
    ContentFolder.restaurantCafe => 'EATS & CAFE',
    ContentFolder.recipe => 'RECIPE',
    ContentFolder.shopping => 'SHOPPING',
    ContentFolder.travelPlace => 'TRAVEL & PLACE',
    ContentFolder.lifeTip => 'LIFE TIPS',
    ContentFolder.other => 'OTHER',
    ContentFolder.needsClassification => 'UNSORTED',
  };
}
