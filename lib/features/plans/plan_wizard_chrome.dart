import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// The two steps of making a plan, shown on both of them.
///
/// Making a plan is a walk, not a form: describe it, then decide what it turns
/// into. Carrying the same header across both screens is what tells a reader
/// the second one is still the same act and not somewhere they wandered off to.
final class PlanWizardSteps extends StatelessWidget {
  const PlanWizardSteps({required this.activeStep, this.onBack, super.key});

  /// 1 or 2.
  final int activeStep;

  /// Null leaves the back affordance to whatever chrome already wraps the
  /// screen, so a screen inside an AppBar does not grow a second arrow.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppTheme.planInk,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.planSurface,
                    shape: const CircleBorder(
                      side: BorderSide(color: AppTheme.planBorder),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const Text(
                'NEW PLAN',
                style: TextStyle(
                  color: AppTheme.planSubtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StepChip(
                index: 1,
                label: '무슨 일 · 언제',
                active: activeStep == 1,
              ),
              const SizedBox(width: 8),
              _StepChip(
                index: 2,
                label: 'AI 추천 · 마감',
                active: activeStep == 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.index,
    required this.label,
    required this.active,
  });

  final int index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppTheme.planInk : AppTheme.planSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.planBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$index',
              style: TextStyle(
                color: active ? AppTheme.planCanvas : AppTheme.planSubtle,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppTheme.planCanvas : AppTheme.planMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
