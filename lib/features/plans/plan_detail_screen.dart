import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/plan_recommendation_service.dart';
import 'saved_inside_todo.dart';

/// One plan and the to-dos it turned into.
///
/// The suggestion screen is where a reader decides what a plan is; this is
/// where they work through it. Same rows, same words, but now they tick off
/// rather than choose, and the deadline is a date rather than a countdown from
/// a day that had not happened yet.
final class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({
    required this.title,
    required this.triggerLabel,
    required this.planDate,
    required this.todos,
    required this.onToggle,
    this.onOpenActions,
    this.onOpenSaved,
    super.key,
  });

  final String title;
  final String triggerLabel;

  /// The day the plan falls on. Null when it is a place with no time, in which
  /// case a to-do can only say how far ahead it belongs, not when.
  final DateTime? planDate;

  final List<PlanTodoSuggestion> todos;

  /// Called with the to-do's position and its new state.
  final void Function(int index, bool done) onToggle;

  final VoidCallback? onOpenActions;

  /// Opens the capture or product a to-do points at.
  final ValueChanged<PlanTodoSavedItem>? onOpenSaved;

  @override
  Widget build(BuildContext context) {
    final doneCount = todos.where((todo) => todo.done).length;
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('계획'),
          actions: [
            if (onOpenActions != null)
              IconButton(
                key: const Key('plan-detail-actions'),
                onPressed: onOpenActions,
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: '계획 관리',
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.planInk,
                  fontSize: 27,
                  height: 1.26,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                triggerLabel,
                style: const TextStyle(
                  color: AppTheme.planMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              if (todos.isEmpty)
                const _Empty()
              else ...[
                _Progress(doneCount: doneCount, total: todos.length),
                const SizedBox(height: 16),
                for (var index = 0; index < todos.length; index += 1) ...[
                  // A header wherever the group changes, which is wherever one
                  // ends: the to-dos arrive in the order the groups came in and
                  // are kept that way. Deriving it from the list rather than
                  // storing a structure means a group whose to-dos were all
                  // dropped has nothing left to draw a header for.
                  if (_startsGroup(todos, index)) ...[
                    if (index != 0) const SizedBox(height: 14),
                    _GroupHeader(
                      title: todos[index].group,
                      todos: _groupAt(todos, index),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _TodoTile(
                    todo: todos[index],
                    planDate: planDate,
                    onChanged: (done) => onToggle(index, done),
                    onOpenSaved: onOpenSaved,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the to-do at [index] opens a group the one before it was not in.
///
/// An unnamed group never opens one: a plan written by hand, or made before
/// to-dos knew what they belonged to, reads as the plain list it always was.
bool _startsGroup(List<PlanTodoSuggestion> todos, int index) {
  final group = todos[index].group;
  if (group.isEmpty) return false;
  return index == 0 || todos[index - 1].group != group;
}

/// The run of to-dos sharing the group that starts at [index].
List<PlanTodoSuggestion> _groupAt(List<PlanTodoSuggestion> todos, int index) {
  final group = todos[index].group;
  final run = <PlanTodoSuggestion>[];
  for (var at = index; at < todos.length && todos[at].group == group; at += 1) {
    run.add(todos[at]);
  }
  return run;
}

/// Names a run of to-dos and says how far through it the reader is.
///
/// The count is the group's own, not the plan's. The bar above already says
/// how much of the whole is left; what this answers is which part is holding
/// the rest up.
final class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.todos});

  final String title;
  final List<PlanTodoSuggestion> todos;

  @override
  Widget build(BuildContext context) {
    final done = todos.where((todo) => todo.done).length;
    final complete = done == todos.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: complete ? AppTheme.planMuted : AppTheme.planInk,
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$done/${todos.length}',
          style: TextStyle(
            color: complete ? AppTheme.planSage : AppTheme.planSubtle,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _Progress extends StatelessWidget {
  const _Progress({required this.doneCount, required this.total});

  final int doneCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = doneCount == total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: AppTheme.planSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.checklist_rtl_rounded,
            color: complete ? AppTheme.planSage : AppTheme.planMauve,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              complete ? '할 일을 다 했어요' : '$total개 중 $doneCount개 했어요',
              style: const TextStyle(
                color: AppTheme.planInk,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : doneCount / total,
                minHeight: 6,
                backgroundColor: AppTheme.planCanvas,
                color: complete ? AppTheme.planSage : AppTheme.planMauve,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.planDate,
    required this.onChanged,
    required this.onOpenSaved,
  });

  final PlanTodoSuggestion todo;
  final DateTime? planDate;
  final ValueChanged<bool> onChanged;
  final ValueChanged<PlanTodoSavedItem>? onOpenSaved;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('plan-todo-${todo.title}'),
      color: AppTheme.planSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!todo.done),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.planBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Check(checked: todo.done),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        color: todo.done
                            ? AppTheme.planSubtle
                            : AppTheme.planInk,
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        decoration: todo.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AppTheme.planSubtle,
                      ),
                    ),
                    if (todo.action.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _ActionChip(action: todo.action),
                    ],
                    if (todo.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        todo.note,
                        style: const TextStyle(
                          color: AppTheme.planMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (todo.saved.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SavedInsideTodo(saved: todo.saved, onOpen: onOpenSaved),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _dueLabel(todo, planDate),
                style: TextStyle(
                  color: todo.done ? AppTheme.planSubtle : AppTheme.planMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A date once the plan has a day to count back from, and the countdown
  /// itself when it does not.
  static String _dueLabel(PlanTodoSuggestion todo, DateTime? planDate) {
    if (planDate == null) {
      return todo.daysBefore == 0 ? '당일' : 'D-${todo.daysBefore}';
    }
    final due = todo.dueDate(planDate);
    return '${due.month}/${due.day}';
  }
}

final class _Check extends StatelessWidget {
  const _Check({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? AppTheme.planSage : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: checked ? AppTheme.planSage : AppTheme.planBorder,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 17, color: Color(0xFF06201C))
          : null,
    );
  }
}

final class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.planMauveSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        action,
        style: const TextStyle(
          color: AppTheme.planMauve,
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

final class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      decoration: BoxDecoration(
        color: AppTheme.planSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.checklist_rounded, color: AppTheme.planSubtle, size: 26),
          SizedBox(height: 10),
          Text(
            '이 계획에는 할 일이 없어요.',
            style: TextStyle(
              color: AppTheme.planMuted,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
