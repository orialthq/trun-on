import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/demo_catalog.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';

final class ShareReviewScreen extends StatelessWidget {
  const ShareReviewScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final share = controller.pendingShare;
    final product = DemoCatalog.products.last;

    if (share == null) {
      return const SizedBox.shrink();
    }

    final sourceHost = Uri.tryParse(share.discoveredUrl ?? '')?.host;

    return Scaffold(
      appBar: AppBar(
        title: const Text('공유한 콘텐츠'),
        backgroundColor: AppTheme.background,
        leading: IconButton(
          tooltip: '취소',
          onPressed: controller.discardPendingShare,
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('이 제품이 맞나요?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            '제품 후보를 확인하면 같은 제품의 콘텐츠와 함께 묶을게요.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sourceHost?.isNotEmpty == true
                            ? sourceHost!
                            : '공유된 텍스트',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const StatusPill(
                      label: '제품 후보',
                      icon: Icons.auto_awesome_outlined,
                      foreground: Color(0xFF1A5E99),
                      background: Color(0xFFEAF3FC),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  share.sharedText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ProductArt(product: product, width: 92, height: 110),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '제품 후보를 찾았어요',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.brand,
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text('${product.sizeMl}mL · ${product.category}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '왜 저장했는지 메모하기 · 선택',
              hintText: '예: 백탁 없이 가볍다고 해서',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: controller.confirmPendingShare,
            child: const Text('이 제품이 맞아요'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('제품 직접 검색은 다음 단계에서 연결할게요.')),
              );
            },
            child: const Text('다른 제품이에요'),
          ),
          const SizedBox(height: 18),
          const Text(
            '현재는 공유 수신과 확인 흐름을 검증하는 데모예요. '
            '콘텐츠 원문이나 영상을 서버에 업로드하지 않습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
