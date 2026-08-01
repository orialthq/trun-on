import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';
import '../analysis/structured_review_screen.dart';
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
        final structuredCaptures = controller.organizedStructuredCaptures;
        final total = groups.length + structuredCaptures.length;

        return ListView(
          key: const PageStorageKey('products'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Text('정리함', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              total == 0 ? '확인한 내용을 이곳에 차곡차곡 모아요' : '확인한 내용 $total개를 모아봤어요',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            if (groups.isEmpty && structuredCaptures.isEmpty)
              const _EmptyProducts()
            else ...[
              if (structuredCaptures.isNotEmpty) ...[
                const _ListHeading(title: '레시피와 콘텐츠'),
                const SizedBox(height: 12),
                _StructuredList(
                  captures: structuredCaptures,
                  onSelected: (capture) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StructuredReviewScreen(
                          controller: controller,
                          captureId: capture.raw.id,
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (groups.isNotEmpty) ...[
                if (structuredCaptures.isNotEmpty) const SizedBox(height: 28),
                const _ListHeading(title: '뷰티 제품'),
                const SizedBox(height: 12),
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
            ],
          ],
        );
      },
    );
  }
}

final class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

final class _StructuredList extends StatelessWidget {
  const _StructuredList({required this.captures, required this.onSelected});

  final List<CaptureRecord> captures;
  final ValueChanged<CaptureRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < captures.length; index++) ...[
            _StructuredRow(
              capture: captures[index],
              onTap: () => onSelected(captures[index]),
            ),
            if (index != captures.length - 1)
              const Divider(height: 1, indent: 92, endIndent: 18),
          ],
        ],
      ),
    );
  }
}

final class _StructuredRow extends StatelessWidget {
  const _StructuredRow({required this.capture, required this.onTap});

  final CaptureRecord capture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final structured = capture.analysis!.structuredContent!;
    final attachment = capture.raw.attachments.isEmpty
        ? null
        : capture.raw.attachments.first;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 62,
                height: 72,
                child: ColoredBox(
                  color: AppTheme.primarySoft,
                  child: attachment == null
                      ? const Icon(
                          Icons.restaurant_menu_rounded,
                          color: AppTheme.primary,
                        )
                      : Image.file(
                          File(attachment.filePath),
                          fit: BoxFit.cover,
                          cacheWidth: 186,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      _contentKindLabel(structured.contentKind),
                      if (structured.title.status == ObservedStatus.inferred)
                        '제목 추정',
                      if (structured.title.status == ObservedStatus.missing)
                        '제목 없음',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    structured.title.value ?? '제목 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (structured.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      structured.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.subtle,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  static String _contentKindLabel(ContentKind kind) {
    return switch (kind) {
      ContentKind.recipe => '레시피',
      ContentKind.sauceRecipe => '소스 레시피',
      ContentKind.commerceProduct => '상품',
      ContentKind.productReview => '제품 리뷰',
      ContentKind.menuComparison => '메뉴 비교',
      ContentKind.beautyProduct => '뷰티 제품',
      ContentKind.place => '장소',
      ContentKind.unknown => '기타',
    };
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
