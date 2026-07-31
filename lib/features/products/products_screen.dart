import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';
import '../product/product_detail_screen.dart';

final class ProductsScreen extends StatelessWidget {
  const ProductsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final groups = controller.groups;

        return ListView(
          key: const PageStorageKey('products'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('제품별 정리', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              '확인한 콘텐츠를 같은 제품끼리 모았어요',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            if (groups.isEmpty)
              const _EmptyProducts()
            else ...[
              _ProductsSummary(groups: groups),
              const SizedBox(height: 18),
              ...groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProductGroupCard(
                    group: group,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProductDetailScreen(
                            controller: controller,
                            groupId: group.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

final class _ProductsSummary extends StatelessWidget {
  const _ProductsSummary({required this.groups});

  final List<ProductGroup> groups;

  @override
  Widget build(BuildContext context) {
    final sourceCount = groups.fold<int>(
      0,
      (total, group) => total + group.sourceCount,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF292032),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF44364F),
            child: Icon(Icons.inventory_2_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '정리된 결과',
                  style: TextStyle(
                    color: Color(0xFFD6CDE0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '콘텐츠 $sourceCount개를 제품 ${groups.length}개로 묶었어요',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({required this.group, required this.onTap});

  final ProductGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topics = _topicSummaries(group);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductArt.forGroup(group),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.identity.brand,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.identity.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _productMeta(group.identity),
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.collections_bookmark_outlined,
                          size: 17,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '출처 ${group.sourceCount}개',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (topics.isEmpty)
                      const Text(
                        '아직 반복해서 언급된 주제가 없어요',
                        style: TextStyle(color: AppTheme.muted, fontSize: 12),
                      )
                    else ...[
                      const Text(
                        '반복 언급',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: topics
                            .map(
                              (topic) => _TopicChip(
                                label: topic.label,
                                sourceCount: topic.sourceCount,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 26),
                child: Icon(Icons.chevron_right, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _productMeta(ConfirmedProductIdentity identity) {
    return [
      identity.category,
      identity.amount,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
  }

  List<_TopicSummary> _topicSummaries(ProductGroup group) {
    final sourceIdsByTopic = <String, Set<String>>{};
    for (final statement in group.statements) {
      if (statement.type == StatementType.disclosure) {
        continue;
      }
      sourceIdsByTopic
          .putIfAbsent(statement.topic, () => <String>{})
          .add(statement.captureId);
    }

    final repeated =
        sourceIdsByTopic.entries
            .where((entry) => entry.value.length >= 2)
            .map(
              (entry) => _TopicSummary(
                label: entry.key,
                sourceCount: entry.value.length,
              ),
            )
            .toList(growable: true)
          ..sort((a, b) {
            final countOrder = b.sourceCount.compareTo(a.sourceCount);
            return countOrder != 0 ? countOrder : a.label.compareTo(b.label);
          });

    return repeated.take(3).toList(growable: false);
  }
}

final class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label, required this.sourceCount});

  final String label;
  final int sourceCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE9FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · $sourceCount',
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

final class _TopicSummary {
  const _TopicSummary({required this.label, required this.sourceCount});

  final String label;
  final int sourceCount;
}

final class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 76, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEEE9FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 34,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '아직 제품별로 정리된 내용이 없어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '콘텐츠에서 찾은 제품을 확인하면\n같은 제품끼리 이곳에 모아드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
