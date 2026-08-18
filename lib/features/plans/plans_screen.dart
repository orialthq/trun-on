import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Presentation-only lifecycle used by [PlansScreen].
///
/// Domain plans can be mapped to this small view model without making the
/// screen depend on persistence or scheduling implementations.
enum PlanListStatus { active, upcoming, completed }

/// A display-ready plan row.
///
/// [triggerLabel] deliberately stays presentation-ready. The domain layer owns
/// timezone, recurrence, and geofence semantics; this screen only renders the
/// resulting explanation.
final class PlanListItem {
  const PlanListItem({
    required this.id,
    required this.title,
    required this.status,
    required this.triggerLabel,
    this.recurrenceLabel,
    this.sourceLabel,
  });

  final String id;
  final String title;
  final PlanListStatus status;
  final String triggerLabel;
  final String? recurrenceLabel;
  final String? sourceLabel;
}

/// Plan inbox grouped by lifecycle state.
///
/// This widget intentionally does not own a controller. Integrators can map
/// domain plans to [PlanListItem] and rebuild this screen whenever the source
/// of truth changes.
final class PlansScreen extends StatelessWidget {
  const PlansScreen({
    required this.plans,
    required this.onCreatePlan,
    this.onOpenPlan,
    super.key,
  });

  final List<PlanListItem> plans;
  final VoidCallback onCreatePlan;
  final ValueChanged<PlanListItem>? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final active = _plansWithStatus(PlanListStatus.active);
    final upcoming = _plansWithStatus(PlanListStatus.upcoming);
    final completed = _plansWithStatus(PlanListStatus.completed);

    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: ColoredBox(
        color: AppTheme.planCanvas,
        child: SafeArea(
          bottom: false,
          child: ListView(
            key: const PageStorageKey('plans-screen'),
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 44),
            children: [
              _PlansHeader(onCreatePlan: onCreatePlan),
              const SizedBox(height: 26),
              _PlanSummary(
                activeCount: active.length,
                upcomingCount: upcoming.length,
              ),
              const SizedBox(height: 34),
              _PlanSection(
                key: const Key('plans-active-section'),
                title: '활성 계획',
                emptyLabel: '지금 조건을 기다리는 계획이 없어요.',
                plans: active,
                onOpenPlan: onOpenPlan,
              ),
              const SizedBox(height: 34),
              _PlanSection(
                key: const Key('plans-upcoming-section'),
                title: '예정된 계획',
                emptyLabel: '다가오는 계획이 없어요.',
                plans: upcoming,
                onOpenPlan: onOpenPlan,
              ),
              const SizedBox(height: 34),
              _PlanSection(
                key: const Key('plans-completed-section'),
                title: '완료한 계획',
                emptyLabel: '완료한 계획이 여기에 쌓여요.',
                plans: completed,
                onOpenPlan: onOpenPlan,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PlanListItem> _plansWithStatus(PlanListStatus status) {
    return plans.where((plan) => plan.status == status).toList(growable: false);
  }
}

final class _PlansHeader extends StatelessWidget {
  const _PlansHeader({required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('계획함', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 7),
              const Text(
                '저장한 정보를 필요한 순간에 꺼내요.',
                style: TextStyle(
                  color: AppTheme.planMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          key: const Key('plans-create-button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(86, 44),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            backgroundColor: AppTheme.planMauveSoft,
            foregroundColor: AppTheme.planInk,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.planBorder),
            ),
          ),
          onPressed: onCreatePlan,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('추가'),
        ),
      ],
    );
  }
}

final class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.activeCount, required this.upcomingCount});

  final int activeCount;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    final hasPlans = activeCount > 0 || upcomingCount > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.planSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: hasPlans ? AppTheme.planMauveSoft : AppTheme.planCanvas,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(
                hasPlans
                    ? Icons.auto_awesome_motion_rounded
                    : Icons.note_add_outlined,
                color: hasPlans ? AppTheme.planMauve : AppTheme.planSubtle,
                size: 21,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPlans
                        ? '활성 $activeCount개 · 예정 $upcomingCount개'
                        : '첫 계획을 만들어 보세요',
                    style: const TextStyle(
                      color: AppTheme.planInk,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPlans
                        ? '조건이 맞으면 Trun On이 알려드릴게요.'
                        : '시간이나 장소를 정하면 잊지 않게 알려드려요.',
                    style: const TextStyle(
                      color: AppTheme.planMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.title,
    required this.emptyLabel,
    required this.plans,
    required this.onOpenPlan,
    super.key,
  });

  final String title;
  final String emptyLabel;
  final List<PlanListItem> plans;
  final ValueChanged<PlanListItem>? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Text(
              '${plans.length}',
              style: const TextStyle(
                color: AppTheme.planSubtle,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (plans.isEmpty)
          _EmptySection(label: emptyLabel)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.planSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.planBorder),
            ),
            child: Column(
              children: [
                for (var index = 0; index < plans.length; index++) ...[
                  _PlanRow(
                    plan: plans[index],
                    onTap: onOpenPlan == null
                        ? null
                        : () => onOpenPlan!(plans[index]),
                  ),
                  if (index != plans.length - 1)
                    const Divider(indent: 70, endIndent: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

final class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.planSurface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Icon(
              Icons.horizontal_rule_rounded,
              color: AppTheme.planSubtle,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.planSubtle,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, this.onTap});

  final PlanListItem plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final appearance = _PlanStatusAppearance.from(plan.status);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 17, 10, 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: appearance.background,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(appearance.icon, color: appearance.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: plan.status == PlanListStatus.completed
                              ? AppTheme.planMuted
                              : AppTheme.planInk,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(appearance: appearance),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  plan.triggerLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.planMuted,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (plan.recurrenceLabel case final recurrence?) ...[
                  const SizedBox(height: 4),
                  Text(
                    recurrence,
                    style: const TextStyle(
                      color: AppTheme.planSubtle,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                if (plan.sourceLabel case final source?) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        color: AppTheme.planSubtle,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.planSubtle,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.planSubtle,
                size: 22,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      key: Key('plan-card-${plan.id}'),
      color: Colors.transparent,
      child: onTap == null
          ? Semantics(label: _semanticsLabel(appearance.label), child: content)
          : InkWell(
              onTap: onTap,
              child: Semantics(
                button: true,
                label: _semanticsLabel(appearance.label),
                child: ExcludeSemantics(child: content),
              ),
            ),
    );
  }

  String _semanticsLabel(String statusLabel) {
    final details = [
      statusLabel,
      plan.title,
      plan.triggerLabel,
      ?plan.recurrenceLabel,
      if (plan.sourceLabel case final source?) '연결 콘텐츠 $source',
    ];
    return details.join(', ');
  }
}

final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.appearance});

  final _PlanStatusAppearance appearance;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appearance.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          appearance.label,
          style: TextStyle(
            color: appearance.color,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

final class _PlanStatusAppearance {
  const _PlanStatusAppearance({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  factory _PlanStatusAppearance.from(PlanListStatus status) {
    return switch (status) {
      PlanListStatus.active => const _PlanStatusAppearance(
        label: '활성',
        icon: Icons.notifications_none_rounded,
        color: AppTheme.planMauve,
        background: AppTheme.planMauveSoft,
      ),
      PlanListStatus.upcoming => const _PlanStatusAppearance(
        label: '예정',
        icon: Icons.schedule_rounded,
        color: AppTheme.planSand,
        background: AppTheme.planSandSoft,
      ),
      PlanListStatus.completed => const _PlanStatusAppearance(
        label: '완료',
        icon: Icons.check_rounded,
        color: AppTheme.planSage,
        background: AppTheme.planSageSoft,
      ),
    };
  }

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}
