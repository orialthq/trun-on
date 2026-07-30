import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';

final class CriteriaScreen extends StatelessWidget {
  const CriteriaScreen({required this.controller, super.key});

  static const availableConcerns = ['붉은기', '피지·모공', '속건조', '칙칙함', '탄력'];

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final criteria = controller.criteria;
        return ListView(
          key: const PageStorageKey('criteria'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('내 기준', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              '기준을 알려주면 역할이 겹치는 제품을 더 잘 정리할 수 있어요',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 22),
            const InfoBanner(
              icon: Icons.science_outlined,
              title: '데모 데이터로 둘러보는 중이에요',
              body: '실제 계정·피부 정보·구매 데이터는 아직 저장하지 않아요.',
            ),
            const SizedBox(height: 28),
            const SectionTitle('피부 기준'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _CriteriaRow(
                      icon: Icons.water_drop_outlined,
                      label: '피부 타입',
                      value: criteria.skinType,
                    ),
                    const Divider(height: 28),
                    _CriteriaRow(
                      icon: Icons.shield_outlined,
                      label: '민감 여부',
                      value: criteria.isSensitive ? '민감함' : '보통',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('요즘 고민 · 최대 3개'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableConcerns
                  .map((concern) {
                    final selected = criteria.concerns.contains(concern);
                    return FilterChip(
                      label: Text(concern),
                      selected: selected,
                      onSelected: (_) {
                        if (!selected && criteria.concerns.length >= 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('고민은 3개까지 선택할 수 있어요.'),
                            ),
                          );
                          return;
                        }
                        controller.toggleConcern(concern);
                      },
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 28),
            const SectionTitle('현재 루틴'),
            const SizedBox(height: 12),
            ...criteria.routine.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEEE9FA),
                      child: Icon(Icons.spa_outlined, color: AppTheme.primary),
                    ),
                    title: Text(
                      item,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('아침 · 저녁'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ori Beauty는 구매 결정을 돕는 정보 도구이며 의료 서비스가 아니에요. '
              '피부 질환, 알레르기 또는 이상 반응은 의료 전문가와 상의하세요.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _CriteriaRow extends StatelessWidget {
  const _CriteriaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
