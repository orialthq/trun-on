import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/plan_recommendation_service.dart';

/// What the reader already saved that serves one to-do.
///
/// Indented under the to-do rather than beside it, because that is the claim:
/// these are not things to do, they are what you look at while doing the thing
/// above them.
///
/// Folded shut. A list of to-dos is meant to be read down, and spelling out the
/// contents of every one turns four rows into a page — the names are material
/// for the moment you are doing that one thing, not for scanning the plan. Shut,
/// it says only that there is something in there; open, it says what.
final class SavedInsideTodo extends StatefulWidget {
  const SavedInsideTodo({
    required this.saved,
    this.onOpen,
    this.keptIds,
    this.onKeep,
    this.initiallyOpen = false,
    super.key,
  });

  final List<PlanTodoSavedItem> saved;

  /// Null in the suggestion step, where the plan does not exist yet and there is
  /// nowhere to navigate back from.
  final ValueChanged<PlanTodoSavedItem>? onOpen;

  /// Which of these the reader is keeping. Null everywhere the choice has
  /// already been made, which is every screen except the suggestion step.
  final Set<String>? keptIds;

  /// Called with the id and whether to keep it. Only read when [keptIds] is set.
  final void Function(String id, bool keep)? onKeep;

  /// Whether the drawer starts open. It does where the contents are being
  /// chosen, because a checkbox behind a tap is a checkbox nobody finds.
  final bool initiallyOpen;

  bool get selectable => keptIds != null && onKeep != null;

  @override
  State<SavedInsideTodo> createState() => _SavedInsideTodoState();
}

final class _SavedInsideTodoState extends State<SavedInsideTodo> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final saved = widget.saved;
    final keptIds = widget.keptIds;
    final keptCount = keptIds == null
        ? saved.length
        : saved.where((one) => keptIds.contains(one.id)).length;
    return Material(
      color: AppTheme.planCanvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.planBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Its own tap target inside the to-do's. The row behind this one ticks
          // the to-do off, and opening the drawer must not do that by accident.
          InkWell(
            key: const Key('saved-inside-todo-toggle'),
            onTap: () => setState(() => _open = !_open),
            child: Semantics(
              button: true,
              expanded: _open,
              label: _label(keptCount, saved.length),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bookmark_rounded,
                        color: AppTheme.planSage,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _label(keptCount, saved.length),
                          style: const TextStyle(
                            color: AppTheme.planSage,
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        _open
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.planSage,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in saved) ...[
                    const SizedBox(height: 6),
                    _Row(
                      item: item,
                      onOpen: widget.onOpen,
                      kept: keptIds?.contains(item.id),
                      onKeep: widget.onKeep,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// `정리함 2개` once the choice is made, `정리함 1 / 2개` while it is being
  /// made — a bare count would hide that one was dropped.
  String _label(int kept, int total) => widget.selectable && kept != total
      ? '정리함 $kept / $total개'
      : '정리함 $total개';
}

final class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.onOpen,
    required this.kept,
    required this.onKeep,
  });

  final PlanTodoSavedItem item;
  final ValueChanged<PlanTodoSavedItem>? onOpen;

  /// Null where this is not being chosen, which reads as "kept" for styling.
  final bool? kept;
  final void Function(String id, bool keep)? onKeep;

  bool get _dropped => kept == false;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (kept != null) ...[
              _SavedCheck(checked: kept!),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _dropped ? AppTheme.planSubtle : AppTheme.planInk,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  decoration: _dropped ? TextDecoration.lineThrough : null,
                  decorationColor: AppTheme.planSubtle,
                ),
              ),
            ),
            if (onOpen != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.planSubtle,
                size: 17,
              ),
          ],
        ),
        if (item.why.isNotEmpty) ...[
          const SizedBox(height: 2),
          Padding(
            // Lines up under the name rather than under the box.
            padding: EdgeInsets.only(left: kept == null ? 0 : 26),
            child: Text(
              item.why,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _dropped ? AppTheme.planSubtle : AppTheme.planMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );

    // Choosing wins over opening. Where both could apply the reader is still
    // deciding what belongs, and a tap that navigated away mid-decision would
    // cost them the screen.
    final onTap = kept != null && onKeep != null
        ? () => onKeep!(item.id, !kept!)
        : (onOpen == null ? null : () => onOpen!(item));
    if (onTap == null) return content;
    return InkWell(
      key: Key('saved-row-${item.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

/// Smaller than the to-do's own box, because this sits inside one.
final class _SavedCheck extends StatelessWidget {
  const _SavedCheck({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: checked ? AppTheme.planSage : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? AppTheme.planSage : AppTheme.planBorder,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 12, color: Color(0xFF06201C))
          : null,
    );
  }
}
