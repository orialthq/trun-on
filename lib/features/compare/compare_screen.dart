import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';

final class CompareScreen extends StatefulWidget {
  const CompareScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

final class _CompareScreenState extends State<CompareScreen> {
  var _differencesOnly = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final products = widget.controller.comparedProducts;

        return ListView(
          key: const PageStorageKey('compare'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('비교', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              '내 기준에 가까운 차이만 모아봤어요',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 22),
            if (products.length < 2)
              const _CompareEmpty()
            else ...[
              SizedBox(
                height: 152,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: products
                      .map((product) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _SelectedProduct(
                              product: product,
                              onRemove: () => widget.controller
                                  .toggleComparison(product.id),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '차이만 보기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('공통 정보는 접어두고 결정에 필요한 차이를 보여줘요.'),
                value: _differencesOnly,
                onChanged: (value) => setState(() => _differencesOnly = value),
              ),
              const SizedBox(height: 14),
              InfoBanner(
                icon: Icons.auto_awesome_outlined,
                title: '하나만 남긴다면 ${_recommended(products).brand}',
                body:
                    '${_recommended(products).name}은 현재 고민과 연결되고 '
                    '루틴 중복이 가장 낮아요.',
              ),
              const SizedBox(height: 28),
              _ComparisonSection(
                title: '내 고민과 연결',
                products: products,
                valueFor: (product) => product.concerns.join(' · '),
              ),
              _ComparisonSection(
                title: '현재 루틴 중복',
                products: products,
                valueFor: (product) => overlapLabel(product.overlap),
              ),
              _ComparisonSection(
                title: '광고·협찬 표시',
                products: products,
                valueFor: (product) =>
                    '${product.savedSourceCount}개 중 '
                    '${product.sponsoredSourceCount}개',
              ),
              if (!_differencesOnly)
                _ComparisonSection(
                  title: '저장한 콘텐츠',
                  products: products,
                  valueFor: (product) => '${product.savedSourceCount}개',
                ),
              _ComparisonSection(
                title: '가격 / 10mL',
                products: products,
                valueFor: (product) => formatWon(product.pricePerTenMl),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  final recommended = _recommended(products);
                  widget.controller.setDecision(
                    recommended.id,
                    Decision.candidate,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${recommended.name}을 구매 후보로 정리했어요.'),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: Text('${_recommended(products).brand}을 구매 후보로'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  for (final product in products) {
                    widget.controller.setDecision(product.id, Decision.hold);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비교한 제품을 모두 보류했어요.')),
                  );
                },
                child: const Text('모두 보류'),
              ),
            ],
          ],
        );
      },
    );
  }

  Product _recommended(List<Product> products) {
    return products.firstWhere(
      (product) => product.overlap == OverlapLevel.low,
      orElse: () => products.first,
    );
  }
}

final class _SelectedProduct extends StatelessWidget {
  const _SelectedProduct({required this.product, required this.onRemove});

  final Product product;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ProductArt(product: product, width: 74, height: 86),
            Positioned(
              right: -9,
              top: -9,
              child: IconButton.filled(
                tooltip: '${product.name} 비교에서 빼기',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          product.brand,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

final class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({
    required this.title,
    required this.products,
    required this.valueFor,
  });

  final String title;
  final List<Product> products;
  final String Function(Product) valueFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ...products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: Color(product.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${product.brand} · ${valueFor(product)}'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _CompareEmpty extends StatelessWidget {
  const _CompareEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 88),
      child: Column(
        children: [
          const Icon(
            Icons.compare_arrows_outlined,
            size: 52,
            color: AppTheme.muted,
          ),
          const SizedBox(height: 16),
          Text(
            '비교할 제품을 2개 이상 골라주세요',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '수집함 카드의 비교 버튼으로 최대 3개까지 담을 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
