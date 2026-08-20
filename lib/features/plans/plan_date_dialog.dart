import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

/// Picks a day, or a run of days, in one compact month.
///
/// Flutter's own range picker takes over the whole screen and scrolls through
/// every month between the bounds. That is a lot of screen for a question that
/// is almost always answered inside the month already on show, and it reads
/// nothing like the small dialog the single-date picker uses.
///
/// So: one month at a time, arrows to move, and a range that is simply a second
/// tap. Tapping one day and confirming is a one-day plan, which keeps the common
/// case at the same cost it had before spans existed.
Future<DateTimeRange?> showPlanDateDialog(
  BuildContext context, {
  required DateTime initialStart,
  DateTime? initialEnd,
  required DateTime firstDate,
  required DateTime lastDate,
  required bool allowRange,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _PlanDateDialog(
      initialStart: DateUtils.dateOnly(initialStart),
      initialEnd: initialEnd == null ? null : DateUtils.dateOnly(initialEnd),
      firstDate: DateUtils.dateOnly(firstDate),
      lastDate: DateUtils.dateOnly(lastDate),
      allowRange: allowRange,
    ),
  );
}

final class _PlanDateDialog extends StatefulWidget {
  const _PlanDateDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    required this.allowRange,
  });

  final DateTime initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool allowRange;

  @override
  State<_PlanDateDialog> createState() => _PlanDateDialogState();
}

final class _PlanDateDialogState extends State<_PlanDateDialog> {
  late DateTime _start = widget.initialStart;
  late DateTime? _end = widget.initialEnd;
  late DateTime _month = DateTime(
    widget.initialStart.year,
    widget.initialStart.month,
  );

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  int get _dayCount => _end == null ? 1 : _end!.difference(_start).inDays + 1;

  bool get _canGoBack =>
      _month.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));

  bool get _canGoForward =>
      _month.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  /// Whether the start on screen was put there by a tap in this dialog.
  ///
  /// The dialog opens on the date the plan already had, and that date is not a
  /// run someone is halfway through choosing. Without this, opening a one-day
  /// plan and tapping a later day silently turned it into a span instead of
  /// moving it.
  var _fresh = false;

  /// A tap either starts a new run or closes the one in progress.
  ///
  /// Closing only happens on a day after a start this dialog placed; anything
  /// else reads as "I meant this day instead", which is what a reader correcting
  /// themselves is doing.
  void _tap(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!widget.allowRange ||
          !_fresh ||
          _end != null ||
          !day.isAfter(_start)) {
        _start = day;
        _end = null;
        _fresh = widget.allowRange;
        return;
      }
      _end = day;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.planSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.planBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 14),
            _monthBar(),
            const SizedBox(height: 10),
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
            _grid(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.allowRange && _end == null
                        ? '다른 날을 한 번 더 누르면 기간이 돼요'
                        : '$_dayCount일간',
                    style: const TextStyle(
                      color: AppTheme.planMuted,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  key: const Key('plan-date-confirm'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DateTimeRange(start: _start, end: _end ?? _start)),
                  child: const Text('선택'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final label = _end == null
        ? _long(_start)
        : '${_long(_start)} – ${_long(_end!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '계획 날짜',
          style: TextStyle(
            color: AppTheme.planSubtle,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.planInk,
            fontSize: 19,
            height: 1.3,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _monthBar() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_month.year}년 ${_month.month}월',
            style: const TextStyle(
              color: AppTheme.planInk,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          key: const Key('plan-date-prev-month'),
          onPressed: _canGoBack
              ? () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                )
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppTheme.planInk,
          disabledColor: AppTheme.planBorder,
        ),
        IconButton(
          key: const Key('plan-date-next-month'),
          onPressed: _canGoForward
              ? () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                )
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: AppTheme.planInk,
          disabledColor: AppTheme.planBorder,
        ),
      ],
    );
  }

  Widget _grid() {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    // `weekday` is 1..7 from Monday; the grid starts on Sunday.
    final leading = DateTime(_month.year, _month.month).weekday % 7;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
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
    );
  }

  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 42);
    }
    final date = DateTime(_month.year, _month.month, day);
    final disabled =
        date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);
    final isStart = date == _start;
    final isEnd = _end != null && date == _end;
    final inside = _end != null && date.isAfter(_start) && date.isBefore(_end!);
    final capped = isStart || isEnd;

    return SizedBox(
      height: 42,
      child: Stack(
        children: [
          // The band under the run, squared off between the ends so the days
          // read as one stretch rather than as separate picks.
          if (inside || (capped && _end != null))
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Align(
                  alignment: isStart
                      ? Alignment.centerRight
                      : (isEnd ? Alignment.centerLeft : Alignment.center),
                  child: FractionallySizedBox(
                    widthFactor: capped ? 0.5 : 1,
                    child: const ColoredBox(color: AppTheme.planMauveSoft),
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
                key: Key('plan-date-day-$day'),
                onTap: disabled ? null : () => _tap(date),
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: capped ? AppTheme.planMauve : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: disabled
                            ? AppTheme.planBorder
                            : (capped
                                  ? const Color(0xFF14200A)
                                  : AppTheme.planInk),
                        fontSize: 14,
                        fontWeight: capped ? FontWeight.w800 : FontWeight.w600,
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

  static String _long(DateTime value) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return '${value.month}월 ${value.day}일 (${names[value.weekday - 1]})';
  }
}
