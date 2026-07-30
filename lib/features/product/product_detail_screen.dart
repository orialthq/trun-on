import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';

final class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    required this.controller,
    required this.productId,
    super.key,
  });

  final AppController controller;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final product = controller.productById(productId);
        if (product == null) {
          return const Scaffold(body: Center(child: Text('제품을 찾지 못했어요.')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('제품 정리'),
            backgroundColor: AppTheme.background,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
            children: [
              _ProductHeader(product: product),
              const SizedBox(height: 24),
              InfoBanner(
                icon: _decisionIcon(product.decision),
                title: _decisionTitle(product),
                body: product.summary,
              ),
              const SizedBox(height: 28),
              const SectionTitle('내 기준으로 정리'),
              const SizedBox(height: 12),
              ...product.reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReasonRow(reason),
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('현재 루틴과 겹치는 점'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        color: overlapColor(product.overlap),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              overlapLabel(product.overlap),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '성분 안전성 판정이 아니라 등록한 제품의 목적과 역할을 비교한 결과예요.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const SectionTitle('콘텐츠에서 확인한 표시'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          product.sponsoredSourceCount == 0
                              ? '저장한 콘텐츠에는 광고·협찬 표시가 없었어요.'
                              : '콘텐츠 ${product.savedSourceCount}개 중 '
                                    '${product.sponsoredSourceCount}개에 광고·협찬 표시가 있었어요.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '콘텐츠와 입력한 기준을 정리한 참고 정보이며, 의학적 진단이 아니에요.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DecisionButton(
                      label: '구매 후보',
                      icon: Icons.check_circle_outline,
                      selected: product.decision == Decision.candidate,
                      onPressed: () =>
                          _decide(context, product, Decision.candidate),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DecisionButton(
                      label: '보류',
                      icon: Icons.pause_circle_outline,
                      selected: product.decision == Decision.hold,
                      onPressed: () => _decide(context, product, Decision.hold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DecisionButton(
                      label: '제외',
                      icon: Icons.remove_circle_outline,
                      selected: product.decision == Decision.excluded,
                      onPressed: () =>
                          _decide(context, product, Decision.excluded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _decisionIcon(Decision decision) {
    return switch (decision) {
      Decision.candidate => Icons.check_circle_outline,
      Decision.hold => Icons.pause_circle_outline,
      Decision.excluded => Icons.remove_circle_outline,
      Decision.undecided => Icons.auto_awesome_outlined,
    };
  }

  String _decisionTitle(Product product) {
    return switch (product.decision) {
      Decision.candidate => '내 결정: 구매 후보',
      Decision.hold => '내 결정: 보류',
      Decision.excluded => '내 결정: 제외',
      Decision.undecided => '아직 결정 전이에요',
    };
  }

  void _decide(BuildContext context, Product product, Decision decision) {
    controller.setDecision(product.id, decision);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${_decisionLabel(decision)}로 정리했어요.'),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () {
              controller.setDecision(product.id, product.decision);
            },
          ),
        ),
      );
  }

  String _decisionLabel(Decision decision) {
    return switch (decision) {
      Decision.candidate => '구매 후보',
      Decision.hold => '보류',
      Decision.excluded => '제외',
      Decision.undecided => '결정 전',
    };
  }
}

final class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductArt(product: product, width: 104, height: 126),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill.forProduct(product),
              const SizedBox(height: 12),
              Text(
                product.brand,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(product.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('${product.sizeMl}mL · ${formatWon(product.priceWon)}'),
              const SizedBox(height: 6),
              Text(
                '콘텐츠 ${product.savedSourceCount}개에서 발견',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _ReasonRow extends StatelessWidget {
  const _ReasonRow(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.check_circle, size: 19, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(reason)),
      ],
    );
  }
}

final class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
