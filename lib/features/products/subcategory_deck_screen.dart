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

/// Shown for items an axis says nothing about, so nothing disappears when the
/// reader switches axes.
const _unlabelledDeckCard = '분류 필요';

final class _SubcategoryDeckScreenState extends State<SubcategoryDeckScreen> {
  var _selectedIndex = 0;
  var _axis = ContentAxis.kind;

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

  void _selectAxis(ContentAxis axis) {
    if (axis == _axis) return;
    setState(() {
      _axis = axis;
      // Card positions mean nothing across axes, so start from the largest.
      _selectedIndex = 0;
    });
  }

  /// Groups the folder's items by the selected axis.
  ///
  /// An item carrying two labels on this axis is filed under both, which is the
  /// point: a pasta place that also pours wine should be reachable from either
  /// card rather than forced into one.
  List<MapEntry<String, List<SavedLibraryItem>>> _groupedItems() {
    final grouped = <String, List<SavedLibraryItem>>{};
    for (final item in savedLibraryItems(widget.controller)) {
      if (item.folder != widget.folder) {
        continue;
      }
      final labels = item.labelsOn(_axis);
      if (labels.isEmpty) {
        grouped.putIfAbsent(_unlabelledDeckCard, () => []).add(item);
        continue;
      }
      for (final label in labels) {
        grouped.putIfAbsent(label, () => []).add(item);
      }
    }
    final entries = grouped.entries.toList()
      ..sort((left, right) {
        // Items nobody classified stay last whatever their count.
        if (left.key == _unlabelledDeckCard) return 1;
        if (right.key == _unlabelledDeckCard) return -1;
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
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: AnimatedBuilder(
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
              title: Text(widget.folder.label),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DeckIntro(
                  folder: widget.folder,
                  selectedIndex: selectedIndex,
                  total: groupedItems.length,
                ),
                // Kept outside the empty branch so an axis with nothing on it
                // can still be swapped back out.
                _AxisFilterRow(selected: _axis, onSelected: _selectAxis),
                const Divider(height: 1),
                Expanded(
                  child: groupedItems.isEmpty
                      ? _EmptyDeck(folder: widget.folder)
                      : _deckList(context, groupedItems, selectedIndex),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _deckList(
    BuildContext context,
    List<MapEntry<String, List<SavedLibraryItem>>> groupedItems,
    int selectedIndex,
  ) {
    return ListView(
      key: PageStorageKey('subcategory-deck-${widget.folder.name}'),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        36 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
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
        const SizedBox(height: 20),
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
                  groupedItems.length > 1 ? '목록을 밀거나 버튼으로 옮겨요' : '하위 분류가 1개예요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.planSubtle,
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
    );
  }
}

final class _DeckIntro extends StatelessWidget {
  const _DeckIntro({
    required this.folder,
    required this.selectedIndex,
    required this.total,
  });

  final ContentFolder folder;
  final int selectedIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.planSageSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(folder.icon, color: AppTheme.planSage, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    '하위 분류',
                    style: TextStyle(
                      color: AppTheme.planInk,
                      fontSize: 21,
                      height: 1.3,
                      letterSpacing: -0.45,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  folder.description,
                  style: const TextStyle(
                    color: AppTheme.planMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${selectedIndex + 1}/$total  ·  $total개 분류',
                    style: const TextStyle(
                      color: AppTheme.planMauve,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The fixed five axes as a scrolling chip row.
///
/// Fixed order and fixed membership: an axis is a product decision, so this row
/// never grows from analysis output.
final class _AxisFilterRow extends StatelessWidget {
  const _AxisFilterRow({required this.selected, required this.onSelected});

  final ContentAxis selected;
  final ValueChanged<ContentAxis> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          for (var index = 0; index < ContentAxis.values.length; index++) ...[
            Builder(
              builder: (context) {
                final axis = ContentAxis.values[index];
                final isSelected = axis == selected;
                return Semantics(
                  selected: isSelected,
                  button: true,
                  child: InkWell(
                    key: Key('axis-chip-${axis.name}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelected(axis),
                    child: Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(
                        minHeight: 42,
                        minWidth: 58,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.planMauveSoft
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.planMauve
                              : AppTheme.planBorder,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        axis.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.planMauve
                              : AppTheme.planMuted,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (index != ContentAxis.values.length - 1)
              const SizedBox(width: 7),
          ],
        ],
      ),
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

  final AppController controller;
  final ContentFolder folder;
  final List<MapEntry<String, List<SavedLibraryItem>>> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.planSurface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.planBorder),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            KeyedSubtree(
              key: ValueKey('deck-position-${entries[index].key}'),
              child: _SubcategoryCard(
                key: Key('subcategory-${entries[index].key}'),
                controller: controller,
                folder: folder,
                name: entries[index].key,
                items: entries[index].value,
                expanded: index == selectedIndex,
                onTap: index == selectedIndex ? null : () => onSelected(index),
              ),
            ),
            if (index != entries.length - 1)
              const Divider(height: 1, indent: 50),
          ],
        ],
      ),
    );
  }
}

final class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({
    required this.controller,
    required this.folder,
    required this.name,
    required this.items,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final AppController controller;
  final ContentFolder folder;
  final String name;
  final List<SavedLibraryItem> items;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !expanded,
      selected: expanded,
      label: '$name 하위 분류, ${items.length}개',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: expanded
                            ? AppTheme.planMauveSoft
                            : AppTheme.planSageSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        expanded
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined,
                        color: expanded
                            ? AppTheme.planMauve
                            : AppTheme.planSage,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AppTheme.planInk,
                          fontSize: expanded ? 18 : 16,
                          height: 1.35,
                          letterSpacing: -0.3,
                          fontWeight: expanded
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(minWidth: 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.planCanvas,
                        border: Border.all(color: AppTheme.planBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: AppTheme.planMuted,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, indent: 41),
                  for (
                    var index = 0;
                    index < items.take(3).length;
                    index++
                  ) ...[
                    _DeckItemRow(
                      item: items[index],
                      onTap: () => openSavedLibraryItem(
                        context,
                        controller: controller,
                        item: items[index],
                      ),
                    ),
                    if (index != items.take(3).length - 1)
                      const Divider(height: 1, indent: 41),
                  ],
                  if (items.length > 3)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.planMauve,
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(41, 12, 2, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.bookmark_border_rounded,
                color: AppTheme.planSubtle,
                size: 17,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.planInk,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.planSubtle,
                size: 19,
              ),
            ],
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: AppTheme.planSurface,
        disabledBackgroundColor: AppTheme.planCanvas,
        foregroundColor: AppTheme.planInk,
        disabledForegroundColor: AppTheme.planSubtle,
        side: const BorderSide(color: AppTheme.planBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: AnimatedBuilder(
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
                10,
                20,
                36 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 50),
              itemBuilder: (context, index) {
                final item = items[index];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    minTileHeight: 70,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    onTap: () => openSavedLibraryItem(
                      context,
                      controller: controller,
                      item: item,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.planSageSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        folder.icon,
                        color: AppTheme.planSage,
                        size: 19,
                      ),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.planInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: item.subtitle.isEmpty
                        ? null
                        : Text(
                            item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.planMuted),
                          ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.planSubtle,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.planSageSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(folder.icon, color: AppTheme.planSage, size: 24),
            ),
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
              style: const TextStyle(color: AppTheme.planMuted),
            ),
          ],
        ),
      ),
    );
  }
}
