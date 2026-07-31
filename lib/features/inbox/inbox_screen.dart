import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../analysis/analysis_review_screen.dart';
import '../common/product_ui.dart';
import '../product/product_detail_screen.dart';

final class InboxScreen extends StatelessWidget {
  const InboxScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final captures = controller.filteredCaptures;

        return ListView(
          key: const PageStorageKey('content-inbox'),
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
                        '콘텐츠',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SNS에서 받은 원본과 분석 상태를 확인해요',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '링크나 텍스트 붙여넣기',
                  onPressed: () => _showManualInput(context),
                  icon: const Icon(Icons.add_link),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _CaptureSummaryCard(controller: controller),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: CaptureFilter.values
                    .map((filter) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${_filterLabel(filter)} '
                            '${_countForFilter(controller, filter)}',
                          ),
                          selected: controller.filter == filter,
                          onSelected: (_) => controller.setFilter(filter),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 18),
            if (captures.isEmpty)
              _EmptyInbox(
                onShowAll: () {
                  controller.setFilter(CaptureFilter.all);
                },
              )
            else
              ...captures.map(
                (capture) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CaptureCard(
                    capture: capture,
                    controller: controller,
                    onTap: () => _openCapture(context, capture),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showManualInput(BuildContext context) async {
    final captureId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ManualInputSheet(controller: controller),
    );
    if (captureId == null || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AnalysisReviewScreen(controller: controller, captureId: captureId),
      ),
    );
  }

  void _openCapture(BuildContext context, CaptureRecord capture) {
    final groupId = capture.groupId;
    if (capture.status == CaptureStatus.organized && groupId != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ProductDetailScreen(controller: controller, groupId: groupId),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisReviewScreen(
          controller: controller,
          captureId: capture.raw.id,
        ),
      ),
    );
  }

  static int _countForFilter(AppController controller, CaptureFilter filter) {
    return switch (filter) {
      CaptureFilter.all => controller.captures.length,
      CaptureFilter.needsReview => controller.needsReviewCount,
      CaptureFilter.organized => controller.organizedCount,
      CaptureFilter.limitedOrFailed => controller.limitedOrFailedCount,
    };
  }

  static String _filterLabel(CaptureFilter filter) {
    return switch (filter) {
      CaptureFilter.all => '전체',
      CaptureFilter.needsReview => '확인 필요',
      CaptureFilter.organized => '정리 완료',
      CaptureFilter.limitedOrFailed => '자료 부족',
    };
  }
}

final class _CaptureSummaryCard extends StatelessWidget {
  const _CaptureSummaryCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
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
            'INPUT → 정리',
            style: TextStyle(
              color: Color(0xFFD6CDE0),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '현재 원본 ${controller.captures.length}개,\n'
            '${controller.organizedCount}개를 제품별로 정리했어요.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryBadge(
                icon: Icons.help_outline,
                label: '확인 필요 ${controller.needsReviewCount}',
              ),
              _SummaryBadge(
                icon: Icons.link_off,
                label: '자료 부족 ${controller.limitedOrFailedCount}',
              ),
              _SummaryBadge(
                icon: Icons.inventory_2_outlined,
                label: '제품 ${controller.groups.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

final class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.capture,
    required this.controller,
    required this.onTap,
  });

  final CaptureRecord capture;
  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final platform = capture.normalized.urls.isEmpty
        ? SourcePlatform.textOnly
        : capture.normalized.urls.first.platform;
    final mention = capture.primaryMention;
    final productLabel = [
      mention?.brand.value,
      mention?.name.value,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEE9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      sourcePlatformIcon(platform),
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sourcePlatformLabel(platform),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          formatCaptureTime(capture.raw.receivedAt),
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill.forCapture(capture),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                capture.raw.rawText.isEmpty
                    ? '공유된 텍스트가 없어요.'
                    : capture.raw.rawText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, height: 1.45),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      productLabel.isEmpty
                          ? Icons.search_off
                          : Icons.auto_awesome_outlined,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        productLabel.isEmpty ? '제품을 특정하지 못했어요' : productLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (mention != null)
                      Text(
                        confidenceBandLabel(mention.confidenceBand),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: switch (capture.status) {
                  CaptureStatus.failed => TextButton.icon(
                    onPressed: () => controller.retryAnalysis(capture.raw.id),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('다시 분석'),
                  ),
                  CaptureStatus.organized => TextButton(
                    onPressed: onTap,
                    child: const Text('제품별 정리 보기'),
                  ),
                  _ => TextButton(
                    onPressed: onTap,
                    child: const Text('분석 결과 확인'),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ManualInputSheet extends StatefulWidget {
  const _ManualInputSheet({required this.controller});

  final AppController controller;

  @override
  State<_ManualInputSheet> createState() => _ManualInputSheetState();
}

final class _ManualInputSheetState extends State<_ManualInputSheet> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('링크나 공유 텍스트 추가', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '입력한 원문은 그대로 보존하고, 정규화·추출 결과는 별도로 만들어요.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _textController,
            autofocus: true,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              hintText: 'SNS 공유 텍스트와 URL을 붙여넣어보세요.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final text = _textController.text;
                if (text.trim().isEmpty) {
                  return;
                }
                final captureId = widget.controller.addManualInput(text);
                Navigator.of(context).pop(captureId);
              },
              child: const Text('저장하고 분석하기'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                _textController.text =
                    '데이라이트 에어리 선 플루이드 50ml. 백탁이 적고 '
                    '가볍다고 소개했어요. #제품제공 '
                    'https://instagram.com/reel/daylight';
              },
              child: const Text('샘플 입력 채우기'),
            ),
          ),
        ],
      ),
    );
  }
}

final class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.muted),
          const SizedBox(height: 16),
          Text(
            '이 상태의 콘텐츠가 없어요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '다른 상태를 확인하거나 새 입력을 추가해보세요.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onShowAll, child: const Text('전체 보기')),
        ],
      ),
    );
  }
}
