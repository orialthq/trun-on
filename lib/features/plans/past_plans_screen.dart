import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import 'plans_screen.dart';

/// Whether [day] falls inside the run this plan covered.
///
/// The plan's own days, not the day it was ticked off. A trip is remembered by
/// when it happened; marking it on the evening someone got round to closing it
/// would put a five-day holiday on a Tuesday a week later.
bool planCoversDay(PlanListItem plan, DateTime day) {
  final start = plan.startsAt;
  if (start == null) return false;
  final from = DateUtils.dateOnly(start);
  final until = DateUtils.dateOnly(plan.endsAt ?? start);
  final to = until.isBefore(from) ? from : until;
  final at = DateUtils.dateOnly(day);
  return !at.isBefore(from) && !at.isAfter(to);
}

/// Past plans touching [month], newest first.
List<PlanListItem> pastPlansInMonth(List<PlanListItem> plans, DateTime month) {
  final days = DateUtils.getDaysInMonth(month.year, month.month);
  return _newestFirst(<PlanListItem>[
    for (final plan in plans)
      if (_overlaps(
        plan,
        DateTime(month.year, month.month),
        DateTime(month.year, month.month, days),
      ))
        plan,
  ]);
}

/// Past plans covering [day], newest first.
List<PlanListItem> pastPlansOnDay(List<PlanListItem> plans, DateTime day) =>
    _newestFirst(<PlanListItem>[
      for (final plan in plans)
        if (planCoversDay(plan, day)) plan,
    ]);

/// Past plans that never had a day at all.
///
/// A plan can wait on a place instead of a clock, and one of those can finish
/// without ever naming a date. A calendar has no square for it, so the list
/// keeps a corner: leaving it out would hide a plan the reader really made.
List<PlanListItem> undatedPastPlans(List<PlanListItem> plans) => <PlanListItem>[
  for (final plan in plans)
    if (plan.startsAt == null) plan,
];

bool _overlaps(PlanListItem plan, DateTime from, DateTime to) {
  final start = plan.startsAt;
  if (start == null) return false;
  final planFrom = DateUtils.dateOnly(start);
  final planUntil = DateUtils.dateOnly(plan.endsAt ?? start);
  final planTo = planUntil.isBefore(planFrom) ? planFrom : planUntil;
  return !planFrom.isAfter(to) && !planTo.isBefore(from);
}

List<PlanListItem> _newestFirst(List<PlanListItem> plans) {
  final sorted = [...plans];
  sorted.sort((first, second) {
    final firstAt = first.startsAt;
    final secondAt = second.startsAt;
    if (firstAt == null || secondAt == null) return 0;
    return secondAt.compareTo(firstAt);
  });
  return List<PlanListItem>.unmodifiable(sorted);
}

/// What is already over, laid out on the month it happened in.
///
/// A page over 계획함 rather than a second section inside it. The two are read
/// for opposite reasons — one to see what still needs doing, the other to look
/// back — and finished plans piling up under the live ones pushed the live ones
/// off the screen. Not a tab either: the bar is for where a reader goes daily,
/// and looking back is deliberate and occasional.
///
/// The calendar answers "what did I do that month", which is the question a
/// reader actually arrives with. It cannot answer every question on its own,
/// which is why the list under it is never empty-handed: with no day picked it
/// shows the whole month, and the plans no square could hold sit at the end.
final class PastPlansScreen extends StatefulWidget {
  const PastPlansScreen({
    required this.plans,
    this.onOpenPlan,
    this.today,
    super.key,
  });

  /// Every plan. The screen keeps the finished ones.
  final List<PlanListItem> plans;
  final ValueChanged<PlanListItem>? onOpenPlan;

  /// The month to open on. Defaults to now; tests pin it.
  final DateTime? today;

  @override
  State<PastPlansScreen> createState() => _PastPlansScreenState();
}

final class _PastPlansScreenState extends State<PastPlansScreen> {
  DateTime? _month;
  DateTime? _selected;

  DateTime get _openMonth {
    final month = _month;
    if (month != null) return month;
    final today = widget.today ?? DateTime.now();
    return DateTime(today.year, today.month);
  }

  List<PlanListItem> get _past => <PlanListItem>[
    for (final plan in widget.plans)
      if (plan.status == PlanListStatus.completed) plan,
  ];

  void _moveMonth(int by) {
    setState(() {
      final month = _openMonth;
      _month = DateTime(month.year, month.month + by);
      // A day in the month being left cannot stay picked; the list under it
      // would be about a square no longer on screen.
      _selected = null;
    });
  }

  /// Picking the day already picked lets go of it, which is the only way back
  /// to the whole month without changing month and returning.
  void _pick(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() => _selected = _selected == day ? null : day);
  }

  @override
  Widget build(BuildContext context) {
    final past = _past;
    final month = _openMonth;
    final selected = _selected;
    final listed = selected == null
        ? pastPlansInMonth(past, month)
        : pastPlansOnDay(past, selected);
    final undated = selected == null
        ? undatedPastPlans(past)
        : const <PlanListItem>[];

    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppTheme.planCanvas,
        appBar: AppBar(
          backgroundColor: AppTheme.planCanvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppTheme.planInk,
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            key: const PageStorageKey('past-plans-screen'),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 44),
            children: [
              const _Header(),
              const SizedBox(height: 18),
              _MonthCalendar(
                month: month,
                selected: selected,
                plans: past,
                onPick: _pick,
                onMove: _moveMonth,
              ),
              const SizedBox(height: 22),
              _ListHeading(
                month: month,
                selected: selected,
                count: listed.length,
              ),
              const SizedBox(height: 12),
              if (past.isEmpty)
                const _Notice('아직 지나간 계획이 없어요.\n계획을 다 마치면 여기에 쌓여요.')
              else if (listed.isEmpty)
                _Notice(
                  selected == null
                      ? '이 달에는 지나간 계획이 없어요.'
                      : '이 날에는 지나간 계획이 없어요.',
                )
              else
                for (final plan in listed) ...[
                  _PastCard(
                    plan: plan,
                    onTap: widget.onOpenPlan == null
                        ? null
                        : () => widget.onOpenPlan!(plan),
                  ),
                  const SizedBox(height: 10),
                ],
              if (undated.isNotEmpty) ...[
                const SizedBox(height: 14),
                _UndatedHeading(count: undated.length),
                const SizedBox(height: 12),
                for (final plan in undated) ...[
                  _PastCard(
                    plan: plan,
                    onTap: widget.onOpenPlan == null
                        ? null
                        : () => widget.onOpenPlan!(plan),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ARCHIVE',
          style: TextStyle(
            color: AppTheme.planSubtle,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '지난함',
          style: TextStyle(
            color: AppTheme.planInk,
            fontSize: 27,
            height: 1.26,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// One month, with a band under the days a plan ran through.
final class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.plans,
    required this.onPick,
    required this.onMove,
  });

  final DateTime month;
  final DateTime? selected;
  final List<PlanListItem> plans;
  final ValueChanged<DateTime> onPick;
  final ValueChanged<int> onMove;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  bool _covered(DateTime day) => plans.any((plan) => planCoversDay(plan, day));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // `weekday` is 1..7 from Monday; the grid starts on Sunday.
    final leading = DateTime(month.year, month.month).weekday % 7;
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.planSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${month.year}년 ${month.month}월',
                  style: const TextStyle(
                    color: AppTheme.planInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                key: const Key('past-prev-month'),
                onPressed: () => onMove(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppTheme.planInk,
              ),
              IconButton(
                key: const Key('past-next-month'),
                onPressed: () => onMove(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppTheme.planInk,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var index = 0; index < 7; index += 1)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdays[index],
                      style: TextStyle(
                        color: index == 0
                            ? AppTheme.planNegative
                            : AppTheme.planSubtle,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < rows; row += 1)
            Row(
              children: [
                for (var column = 0; column < 7; column += 1)
                  Expanded(
                    child: _cell(row * 7 + column - leading + 1, daysInMonth),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 46);

    final date = DateTime(month.year, month.month, day);
    final covered = _covered(date);
    // Squared off between covered neighbours so a run of days reads as one
    // stretch rather than as a row of separate marks.
    final openLeft =
        covered && _covered(date.subtract(const Duration(days: 1)));
    final openRight = covered && _covered(date.add(const Duration(days: 1)));
    final isSelected = selected == date;

    return SizedBox(
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (covered)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  left: openLeft ? 0 : 5,
                  right: openRight ? 0 : 5,
                  top: 7,
                  bottom: 7,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.planMauveSoft,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(openLeft ? 0 : 999),
                      right: Radius.circular(openRight ? 0 : 999),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('past-day-$day'),
                onTap: () => onPick(date),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.planMauve
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF14200A)
                            : (covered ? AppTheme.planInk : AppTheme.planMuted),
                        fontSize: 13.5,
                        fontWeight: covered || isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ListHeading extends StatelessWidget {
  const _ListHeading({
    required this.month,
    required this.selected,
    required this.count,
  });

  final DateTime month;
  final DateTime? selected;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = selected == null
        ? '${month.month}월'
        : '${selected!.month}월 ${selected!.day}일';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.planInk,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Text(
          '$count개',
          style: const TextStyle(
            color: AppTheme.planSubtle,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _UndatedHeading extends StatelessWidget {
  const _UndatedHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '날짜 없이 끝난 것',
            style: TextStyle(
              color: AppTheme.planMuted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Text(
          '$count개',
          style: const TextStyle(
            color: AppTheme.planSubtle,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _PastCard extends StatelessWidget {
  const _PastCard({required this.plan, required this.onTap});

  final PlanListItem plan;
  final VoidCallback? onTap;

  String get _when {
    final start = plan.startsAt;
    if (start == null) return plan.triggerLabel;
    if (plan.endsAt != null && plan.dayCount > 1) {
      return '${_short(start)} – ${_short(plan.endsAt!)} · ${plan.dayCount}일간';
    }
    return _short(start);
  }

  static String _short(DateTime value) => '${value.month}.${value.day}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.planSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('past-plan-${plan.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.planBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.planInk,
                        fontSize: 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _when,
                      style: const TextStyle(
                        color: AppTheme.planMuted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.todos.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  '${plan.doneCount}/${plan.todos.length}',
                  style: TextStyle(
                    color: plan.doneCount == plan.todos.length
                        ? AppTheme.planSage
                        : AppTheme.planSubtle,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.planSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.planMuted,
          fontSize: 13.5,
          height: 1.45,
        ),
      ),
    );
  }
}
