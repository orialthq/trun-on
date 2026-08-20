import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../common/content_folder_ui.dart';
import 'plan_editor_screen.dart';

/// What the reader settled on in the scope sheet.
///
/// Wrapped rather than returning a bare list, because "search everywhere" and
/// "the reader dismissed the sheet" are different answers and both would come
/// back as an empty list otherwise.
final class PlanScopeChoice {
  const PlanScopeChoice(this.scopes);

  final List<PlanContentScope> scopes;
}

/// Picks the folders a plan searches in, one level at a time.
///
/// Two levels rather than a flat list of every child folder. Eight parents fit
/// on a screen and a reader knows which one a thing went into; the children are
/// named by the analyser and there can be dozens, so they are only worth showing
/// once the parent has narrowed things down.
Future<PlanScopeChoice?> showPlanScopeSheet(
  BuildContext context, {
  required List<PlanSourceOption> sources,
  required List<PlanContentScope> selected,
}) {
  return showModalBottomSheet<PlanScopeChoice>(
    context: context,
    backgroundColor: AppTheme.planSurface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlanScopeSheet(sources: sources, selected: selected),
  );
}

final class _PlanScopeSheet extends StatefulWidget {
  const _PlanScopeSheet({required this.sources, required this.selected});

  final List<PlanSourceOption> sources;
  final List<PlanContentScope> selected;

  @override
  State<_PlanScopeSheet> createState() => _PlanScopeSheetState();
}

final class _PlanScopeSheetState extends State<_PlanScopeSheet> {
  late var _scopes = widget.selected;

  /// The parent being looked inside, or null at the top level.
  ContentFolder? _open;

  /// How many saved things the current picks cover between them.
  int get _count => widget.sources
      .where((one) => planScopesMatch(_scopes, one.folder, one.subcategory))
      .length;

  /// Folders that actually hold something, in the order 정리함 shows them.
  Map<ContentFolder, int> get _folders {
    final counts = <ContentFolder, int>{};
    for (final source in widget.sources) {
      counts[source.folder] = (counts[source.folder] ?? 0) + 1;
    }
    return <ContentFolder, int>{
      for (final folder in ContentFolder.values) folder: ?counts[folder],
    };
  }

  Map<String, int> _subcategories(ContentFolder folder) {
    final counts = <String, int>{};
    for (final source in widget.sources) {
      if (source.folder != folder) continue;
      final name = source.subcategory.trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final names = counts.keys.toList()..sort();
    return <String, int>{for (final name in names) name: counts[name]!};
  }

  bool _has(PlanContentScope scope) => _scopes.contains(scope);

  /// How many picks name this folder, so a parent row can say what is on inside
  /// it without opening.
  int _picksIn(ContentFolder folder) =>
      _scopes.where((one) => one.folder == folder).length;

  void _toggle(PlanContentScope scope) {
    setState(() {
      _scopes = _has(scope)
          ? <PlanContentScope>[
              for (final one in _scopes)
                if (one != scope) one,
            ]
          : planScopesWith(_scopes, scope);
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(bottom: AppTheme.bottomSheetSafeInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (open == null) ..._top() else ..._inside(open),
            const SizedBox(height: 12),
            // Picking no longer closes the sheet, so there has to be a way out
            // that means "done" rather than "cancel".
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('plan-scope-done'),
                onPressed: () =>
                    Navigator.of(context).pop(PlanScopeChoice(_scopes)),
                child: Text(
                  _scopes.isEmpty
                      ? '어디서든 찾기 · $_count개'
                      : '${_scopes.length}곳에서 찾기 · $_count개',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _top() {
    final folders = _folders;
    return <Widget>[
      Text('어디서 찾을까요?', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      const Text(
        '고른 폴더 안에서만 저장한 것을 꺼내요. 여러 곳을 고를 수 있어요.',
        style: TextStyle(color: AppTheme.planMuted, fontSize: 14, height: 1.45),
      ),
      const SizedBox(height: 16),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          children: [
            _Choice(
              key: const Key('plan-scope-all'),
              label: '어디서든 찾기',
              detail: '저장한 것 ${widget.sources.length}개 전부',
              icon: Icons.all_inclusive_rounded,
              color: AppTheme.planMuted,
              selected: _scopes.isEmpty,
              // Clearing rather than adding. "Everywhere" is the absence of a
              // fence, so it cannot sit in the list beside one.
              onTap: () => setState(() => _scopes = const <PlanContentScope>[]),
            ),
            const Divider(height: 1, indent: 58),
            for (final entry in folders.entries)
              _Choice(
                key: Key('plan-scope-folder-${entry.key.name}'),
                label: entry.key.label,
                detail: _folderDetail(entry.key, entry.value),
                icon: entry.key.icon,
                color: entry.key.color,
                selected: _picksIn(entry.key) > 0,
                // Straight in rather than picking here. Choosing the whole
                // folder is the first row on the next screen, so one tap always
                // means "look inside" and never silently commits.
                chevron: true,
                onTap: () => setState(() => _open = entry.key),
              ),
          ],
        ),
      ),
    ];
  }

  String _folderDetail(ContentFolder folder, int total) {
    final picks = _scopes.where((one) => one.folder == folder).toList();
    if (picks.isEmpty) return '$total개';
    if (picks.length == 1 && picks.single.subcategory == null) {
      return '전체 선택됨 · $total개';
    }
    return '${picks.map((one) => one.subcategory).join(', ')} 선택됨';
  }

  List<Widget> _inside(ContentFolder folder) {
    final subcategories = _subcategories(folder);
    final total = _folders[folder] ?? 0;
    return <Widget>[
      Row(
        children: [
          IconButton(
            key: const Key('plan-scope-back'),
            onPressed: () => setState(() => _open = null),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: '폴더 목록',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              folder.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          children: [
            _Choice(
              key: Key('plan-scope-whole-${folder.name}'),
              label: '${folder.label} 전체',
              detail: '$total개',
              icon: folder.icon,
              color: folder.color,
              selected: _has(PlanContentScope(folder: folder)),
              onTap: () => _toggle(PlanContentScope(folder: folder)),
            ),
            if (subcategories.isNotEmpty) const Divider(height: 1, indent: 58),
            for (final entry in subcategories.entries)
              _Choice(
                key: Key('plan-scope-sub-${entry.key}'),
                label: entry.key,
                detail: '${entry.value}개',
                icon: Icons.subdirectory_arrow_right_rounded,
                color: folder.color,
                selected: _has(
                  PlanContentScope(folder: folder, subcategory: entry.key),
                ),
                onTap: () => _toggle(
                  PlanContentScope(folder: folder, subcategory: entry.key),
                ),
              ),
          ],
        ),
      ),
    ];
  }
}

final class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.chevron = false,
    super.key,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool chevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 10,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.16),
            AppTheme.planSurface,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Text(
        detail,
        style: const TextStyle(color: AppTheme.planSubtle, fontSize: 12.5),
      ),
      trailing: SizedBox(
        width: 44,
        height: 44,
        child: selected
            ? const Icon(Icons.check_circle_rounded, color: AppTheme.planMauve)
            : (chevron
                  ? const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.planSubtle,
                    )
                  : null),
      ),
      onTap: onTap,
    );
  }
}

/// The row on the editor that says what the plan will search.
final class PlanScopeField extends StatelessWidget {
  const PlanScopeField({
    required this.scopes,
    required this.count,
    required this.onTap,
    super.key,
  });

  final List<PlanContentScope> scopes;
  final int count;
  final VoidCallback onTap;

  /// One place is named outright; several are named by the first and a count.
  /// Folder labels already contain `·`, so listing them all reads as one long
  /// name rather than as a list.
  String get _label {
    if (scopes.isEmpty) return '어디서든';
    final first = _nameOf(scopes.first);
    return scopes.length == 1 ? first : '$first 외 ${scopes.length - 1}곳';
  }

  static String _nameOf(PlanContentScope scope) => scope.subcategory == null
      ? scope.folder.label
      : '${scope.folder.label} · ${scope.subcategory}';

  @override
  Widget build(BuildContext context) {
    final folder = scopes.length == 1 ? scopes.single.folder : null;
    return Material(
      color: AppTheme.planSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.planBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '찾을 범위 $_label, 저장한 것 $count개',
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 66),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      folder?.icon ??
                          (scopes.isEmpty
                              ? Icons.all_inclusive_rounded
                              : Icons.folder_copy_rounded),
                      color: folder?.color ?? AppTheme.planMauve,
                      size: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '찾을 범위',
                            style: TextStyle(
                              color: AppTheme.planSubtle,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.planInk,
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The number is the point of the field: it says how
                            // much the model is about to be handed.
                            count == 0 ? '저장한 것 없음' : '저장한 것 $count개',
                            style: TextStyle(
                              color: count == 0
                                  ? AppTheme.planSand
                                  : AppTheme.planMuted,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
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
