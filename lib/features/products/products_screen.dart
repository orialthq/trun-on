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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Text('제품별 정리', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              groups.isEmpty
                  ? '확인한 제품이 이곳에 차곡차곡 모여요'
                  : '확인한 제품 ${groups.length}개를 모아봤어요',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            if (groups.isEmpty)
              const _EmptyProducts()
            else
              _ProductList(
                groups: groups,
                onSelected: (group) {
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
          ],
        );
      },
    );
  }
}

final class _ProductList extends StatelessWidget {
  const _ProductList({required this.groups, required this.onSelected});

  final List<ProductGroup> groups;
  final ValueChanged<ProductGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var index = 0; index < groups.length; index++) ...[
              _ProductRow(
                group: groups[index],
                onTap: () => onSelected(groups[index]),
              ),
              if (index != groups.length - 1)
                const Divider(indent: 100, endIndent: 20),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.group, required this.onTap});

  final ProductGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final repeatedTopic = _mostRepeatedTopic(group);
    final meta = [
      group.identity.category,
      group.identity.amount,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Semantics(
      button: true,
      label: '${group.identity.brand} ${group.identity.name}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: [
              ProductArt.forGroup(group, width: 68, height: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.identity.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.identity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.subtle,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Text(
                      repeatedTopic == null
                          ? '콘텐츠 ${group.sourceCount}개'
                          : '콘텐츠 ${group.sourceCount}개 · ${repeatedTopic.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: repeatedTopic == null
                            ? AppTheme.muted
                            : AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.subtle,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TopicSummary? _mostRepeatedTopic(ProductGroup group) {
    final sourcesByTopic = <String, Set<String>>{};
    for (final statement in group.statements) {
      if (statement.type == StatementType.disclosure) {
        continue;
      }
      sourcesByTopic
          .putIfAbsent(statement.topic, () => <String>{})
          .add(statement.captureId);
    }

    final topics =
        sourcesByTopic.entries
            .map(
              (entry) => _TopicSummary(
                label: entry.key,
                sourceCount: entry.value.length,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final countOrder = right.sourceCount.compareTo(left.sourceCount);
            return countOrder != 0
                ? countOrder
                : left.label.compareTo(right.label);
          });

    if (topics.isEmpty || topics.first.sourceCount < 2) {
      return null;
    }
    return topics.first;
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
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 40),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppTheme.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 30,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '아직 정리된 제품이 없어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '콘텐츠에서 찾은 제품을 확인하면\n같은 제품끼리 모아서 보여드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }
}
