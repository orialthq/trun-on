import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/plan_recommendation_service.dart';

/// What the reader already saved that serves one to-do.
///
/// Indented under the to-do rather than beside it, because that is the claim:
/// these are not things to do, they are what you look at while doing the thing
/// above them.
final class SavedInsideTodo extends StatelessWidget {
  const SavedInsideTodo({required this.saved, this.onOpen, super.key});

  final List<PlanTodoSavedItem> saved;

  /// Null in the suggestion step, where the plan does not exist yet and there is
  /// nowhere to navigate back from.
  final ValueChanged<PlanTodoSavedItem>? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppTheme.planCanvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bookmark_rounded,
                color: AppTheme.planSage,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                '정리함 ${saved.length}개',
                style: const TextStyle(
                  color: AppTheme.planSage,
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          for (final item in saved) ...[
            const SizedBox(height: 6),
            _Row(item: item, onOpen: onOpen),
          ],
        ],
      ),
    );
  }
}

final class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onOpen});

  final PlanTodoSavedItem item;
  final ValueChanged<PlanTodoSavedItem>? onOpen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.planInk,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
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
          Text(
            item.why,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.planMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ],
    );

    if (onOpen == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onOpen!(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}
