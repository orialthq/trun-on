import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';
import '../product/product_detail_screen.dart';

final class InboxScreen extends StatelessWidget {
  const InboxScreen({
    required this.controller,
    required this.onOpenCompare,
    super.key,
  });

  final AppController controller;
  final VoidCallback onOpenCompare;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final products = controller.filteredProducts;

        return ListView(
          key: const PageStorageKey('inbox'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '수집함',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SNS에서 발견한 제품을 결정할 차례예요',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '공유 받기 데모',
                  onPressed: controller.simulateShare,
                  icon: const Icon(Icons.add_link),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DecisionSummaryCard(
              productCount: controller.products.length,
              decidedCount: controller.decidedCount,
              comparedCount: controller.comparedProducts.length,
              onCompare: onOpenCompare,
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: InboxFilter.values
                    .map((filter) {
                      final count = _countForFilter(controller, filter);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${_filterLabel(filter)} $count'),
                          selected: controller.filter == filter,
                          onSelected: (_) => controller.setFilter(filter),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 18),
            if (products.isEmpty)
              const _EmptyInbox()
            else
              ...products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProductCard(
                    product: product,
                    isCompared: controller.isCompared(product.id),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProductDetailScreen(
                            controller: controller,
                            productId: product.id,
                          ),
                        ),
                      );
                    },
                    onToggleCompare: () {
                      final accepted = controller.toggleComparison(product.id);
                      if (!accepted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('제품은 3개까지 비교할 수 있어요.')),
                        );
                      }
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  int _countForFilter(AppController controller, InboxFilter filter) {
    return switch (filter) {
      InboxFilter.all => controller.products.length,
      InboxFilter.needsConfirmation => controller.needsConfirmationCount,
      InboxFilter.undecided =>
        controller.products
            .where(
              (product) =>
                  product.analysisStatus == AnalysisStatus.ready &&
                  product.decision == Decision.undecided,
            )
            .length,
      InboxFilter.decided => controller.decidedCount,
    };
  }

  String _filterLabel(InboxFilter filter) {
    return switch (filter) {
      InboxFilter.all => '전체',
      InboxFilter.needsConfirmation => '확인 필요',
      InboxFilter.undecided => '결정 전',
      InboxFilter.decided => '결정 완료',
    };
  }
}

final class _DecisionSummaryCard extends StatelessWidget {
  const _DecisionSummaryCard({
    required this.productCount,
    required this.decidedCount,
    required this.comparedCount,
    required this.onCompare,
  });

  final int productCount;
  final int decidedCount;
  final int comparedCount;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final undecidedCount = productCount - decidedCount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF292032),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 주 결정 현황',
            style: TextStyle(
              color: Color(0xFFD6CDE0),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$productCount개를 모았고,\n$undecidedCount개는 결정만 남았어요.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: comparedCount >= 2 ? onCompare : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF292032),
            ),
            icon: const Icon(Icons.compare_arrows),
            label: Text('$comparedCount개 제품 비교하기'),
          ),
        ],
      ),
    );
  }
}

final class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isCompared,
    required this.onTap,
    required this.onToggleCompare,
  });

  final Product product;
  final bool isCompared;
  final VoidCallback onTap;
  final VoidCallback onToggleCompare;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductArt(product: product),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill.forProduct(product),
                    const SizedBox(height: 10),
                    Text(
                      product.brand,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${product.sizeMl}mL · ${formatWon(product.priceWon)}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          size: 17,
                          color: overlapColor(product.overlap),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            overlapLabel(product.overlap),
                            style: TextStyle(
                              color: overlapColor(product.overlap),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '콘텐츠 ${product.savedSourceCount}개에서 발견',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isCompared ? '비교에서 빼기' : '비교에 담기',
                onPressed: product.analysisStatus == AnalysisStatus.ready
                    ? onToggleCompare
                    : null,
                icon: Icon(
                  isCompared ? Icons.check_box : Icons.add_box_outlined,
                  color: isCompared ? AppTheme.primary : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.muted),
          const SizedBox(height: 16),
          Text(
            '이 조건에 맞는 제품이 없어요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('다른 필터를 선택해보세요.', style: TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }
}
