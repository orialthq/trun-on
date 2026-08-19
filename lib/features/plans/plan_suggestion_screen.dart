import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/plan_recommendation_service.dart';
import 'plan_wizard_chrome.dart';
import 'saved_inside_todo.dart';

/// Step two of making a plan: what the plan turned into, and what to keep.
///
/// Everything on this screen was decided by the model — the grouping, the
/// actions, how far ahead each thing has to happen. The reader's job here is to
/// uncheck what they do not want, which is why nothing is hidden behind a tap
/// and every row says where it came from.
///
/// The plan does not exist yet. Leaving without confirming leaves nothing
/// behind, so a slow or wrong answer costs the reader a screen and not a plan.
final class PlanSuggestionScreen extends StatefulWidget {
  const PlanSuggestionScreen({
    required this.planTitle,
    required this.planDate,
    required this.recommendation,
    super.key,
  });

  final String planTitle;

  /// The day the plan itself falls on. Every deadline is counted back from it.
  final DateTime planDate;

  final PlanRecommendation recommendation;

  /// Returns the to-dos the reader kept, or null if they backed out.
  static Future<List<PlanTodoSuggestion>?> open(
    BuildContext context, {
    required String planTitle,
    required DateTime planDate,
    required PlanRecommendation recommendation,
  }) {
    return Navigator.of(context).push<List<PlanTodoSuggestion>>(
      MaterialPageRoute<List<PlanTodoSuggestion>>(
        builder: (_) => PlanSuggestionScreen(
          planTitle: planTitle,
          planDate: planDate,
          recommendation: recommendation,
        ),
      ),
    );
  }

  @override
  State<PlanSuggestionScreen> createState() => _PlanSuggestionScreenState();
}

class _PlanSuggestionScreenState extends State<PlanSuggestionScreen> {
  final _kept = <PlanTodoSuggestion>{};

  @override
  void initState() {
    super.initState();
    for (final item in widget.recommendation.allItems) {
      if (item.selected) _kept.add(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = widget.recommendation;
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PlanWizardSteps(
                activeStep: 2,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _Headline(
                      planTitle: widget.planTitle,
                      recommendation: recommendation,
                      keptCount: _kept.length,
                    ),
                    const SizedBox(height: 22),
                    for (final group in recommendation.groups) ...[
                      _GroupHeader(
                        group: group,
                        keptCount: group.items
                            .where(_kept.contains)
                            .length,
                      ),
                      const SizedBox(height: 10),
                      for (final item in group.items) ...[
                        _TodoRow(
                          item: item,
                          planDate: widget.planDate,
                          checked: _kept.contains(item),
                          onChanged: (keep) => setState(() {
                            if (keep) {
                              _kept.add(item);
                            } else {
                              _kept.remove(item);
                            }
                          }),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              _CreateBar(
                count: _kept.length,
                onCreate: _kept.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                        // Back in the order the model grouped them, not the
                        // order the reader happened to tap.
                        recommendation.allItems
                            .where(_kept.contains)
                            .toList(growable: false),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Headline extends StatelessWidget {
  const _Headline({
    required this.planTitle,
    required this.recommendation,
    required this.keptCount,
  });

  final String planTitle;
  final PlanRecommendation recommendation;
  final int keptCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '할 일 ${recommendation.todoCount}개',
      if (recommendation.attachedCount > 0)
        '저장물 ${recommendation.attachedCount}개 담김',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$planTitle,\n${recommendation.todoCount}개 찾았어요',
          style: const TextStyle(
            color: AppTheme.planInk,
            fontSize: 30,
            height: 1.24,
            letterSpacing: -0.9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${parts.join(' · ')} · $keptCount개 선택됨',
          style: const TextStyle(
            color: AppTheme.planMuted,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

final class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.keptCount});

  final PlanTodoGroup group;
  final int keptCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.planMauve,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.title,
                style: const TextStyle(
                  color: AppTheme.planInk,
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (group.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  group.note,
                  style: const TextStyle(
                    color: AppTheme.planSubtle,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '$keptCount/${group.items.length}',
            style: const TextStyle(
              color: AppTheme.planSubtle,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

final class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.item,
    required this.planDate,
    required this.checked,
    required this.onChanged,
  });

  final PlanTodoSuggestion item;
  final DateTime planDate;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('todo-${item.title}'),
      color: AppTheme.planSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!checked),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: checked ? AppTheme.planMauve : AppTheme.planBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Check(checked: checked),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppTheme.planInk,
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.note,
                        style: const TextStyle(
                          color: AppTheme.planMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (item.saved.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SavedInsideTodo(saved: item.saved),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.action.isNotEmpty) _ActionChip(action: item.action),
                  const SizedBox(height: 6),
                  Text(
                    _dueLabel(item, planDate),
                    style: const TextStyle(
                      color: AppTheme.planMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dueLabel(PlanTodoSuggestion item, DateTime planDate) {
    if (item.daysBefore == 0) return '당일';
    return 'D-${item.daysBefore}';
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
        color: checked ? AppTheme.planMauve : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: checked ? AppTheme.planMauve : AppTheme.planBorder,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(
              Icons.check_rounded,
              size: 17,
              color: Color(0xFF101208),
            )
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.planMauveSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        action,
        style: const TextStyle(
          color: AppTheme.planMauve,
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

final class _CreateBar extends StatelessWidget {
  const _CreateBar({required this.count, required this.onCreate});

  final int count;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.planCanvas,
        border: Border(top: BorderSide(color: AppTheme.planBorder)),
      ),
      child: FilledButton(
        onPressed: onCreate,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              count == 0 ? '할 일을 하나는 골라 주세요' : '$count개 할 일로 계획 만들기',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const Text(
              'CREATE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
