import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../analysis/analysis_review_screen.dart';
import '../analysis/structured_review_screen.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        '모아둔 콘텐츠를 확인하고 정리해요',
                        style: TextStyle(color: AppTheme.muted, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(82, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _showManualInput(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _CaptureSummaryCard(controller: controller),
            const SizedBox(height: 22),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < CaptureFilter.values.length;
                    index++
                  )
                    Builder(
                      builder: (context) {
                        final filter = CaptureFilter.values[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == CaptureFilter.values.length - 1
                                ? 0
                                : 4,
                          ),
                          child: _FilterButton(
                            label: _filterLabel(filter),
                            count: _countForFilter(controller, filter),
                            selected: controller.filter == filter,
                            onPressed: () => controller.setFilter(filter),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (captures.isEmpty)
              _EmptyInbox(
                onShowAll: () {
                  controller.setFilter(CaptureFilter.all);
                },
              )
            else
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < captures.length; index++) ...[
                      _CaptureCard(
                        capture: captures[index],
                        controller: controller,
                        onTap: () => _openCapture(context, captures[index]),
                      ),
                      if (index != captures.length - 1)
                        const Divider(height: 1, indent: 18, endIndent: 18),
                    ],
                  ],
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
    if (capture.status == CaptureStatus.analyzing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 읽고 있어요. 잠시만 기다려 주세요.')),
      );
      return;
    }
    if (capture.analysis?.structuredContent != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StructuredReviewScreen(
            controller: controller,
            captureId: capture.raw.id,
          ),
        ),
      );
      return;
    }
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
      CaptureFilter.limitedOrFailed => '내용 부족',
    };
  }
}

final class _CaptureSummaryCard extends StatelessWidget {
  const _CaptureSummaryCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final needsReview = controller.needsReviewCount;
    final analyzing = controller.analyzingCount;
    final headline = analyzing > 0
        ? '콘텐츠 $analyzing개를 정리하고 있어요'
        : needsReview == 0
        ? '들어온 콘텐츠를 모두 확인했어요'
        : '확인할 콘텐츠가 $needsReview개 있어요';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '전체 ${controller.captures.length}개  ·  '
              '정리 완료 ${controller.organizedCount}개  ·  '
              '분석 중 ${controller.analyzingCount}개',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            '$label $count',
            style: TextStyle(
              color: selected ? AppTheme.primary : AppTheme.muted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

final class _CaptureStatusLabel extends StatelessWidget {
  const _CaptureStatusLabel({required this.capture});

  final CaptureRecord capture;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (capture.status) {
      CaptureStatus.received ||
      CaptureStatus.analyzing => ('분석 중', AppTheme.primary),
      CaptureStatus.sourceLimited => ('내용 부족', const Color(0xFFB26A00)),
      CaptureStatus.needsReview => ('확인 필요', const Color(0xFFB26A00)),
      CaptureStatus.organized => ('정리 완료', const Color(0xFF16815D)),
      CaptureStatus.failed => ('분석 실패', const Color(0xFFD14343)),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
    final structured = capture.analysis?.structuredContent;
    final productLabel = [
      mention?.brand.value,
      mention?.name.value,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    final title = structured?.title.value?.trim().isNotEmpty == true
        ? structured!.title.value!
        : capture.status == CaptureStatus.analyzing
        ? '이미지에서 내용을 읽는 중이에요'
        : capture.status == CaptureStatus.failed
        ? '분석을 완료하지 못했어요'
        : productLabel.isEmpty
        ? capture.raw.attachments.isNotEmpty
              ? '이미지 내용을 확인해 주세요'
              : '제품을 특정하지 못했어요'
        : productLabel;
    final description = structured?.summary.trim().isNotEmpty == true
        ? structured!.summary
        : capture.status == CaptureStatus.failed
        ? _failureMessage(capture.analysis?.failureCode)
        : capture.raw.rawText.isNotEmpty
        ? capture.raw.rawText
        : capture.status == CaptureStatus.analyzing
        ? '원본을 보존한 채 재료와 순서를 나누고 있어요.'
        : '공유된 이미지';

    return InkWell(
      onTap: capture.status == CaptureStatus.failed
          ? () => controller.retryAnalysis(capture.raw.id)
          : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (capture.raw.attachments.isNotEmpty) ...[
              _CaptureThumbnail(attachment: capture.raw.attachments.first),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        capture.raw.attachments.isNotEmpty
                            ? Icons.image_outlined
                            : sourcePlatformIcon(platform),
                        color: AppTheme.muted,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        capture.raw.attachments.isNotEmpty
                            ? '이미지'
                            : sourcePlatformLabel(platform),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        width: 2,
                        height: 2,
                        decoration: const BoxDecoration(
                          color: AppTheme.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        formatCaptureTime(capture.raw.receivedAt),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      _CaptureStatusLabel(capture: capture),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              capture.status == CaptureStatus.analyzing
                  ? Icons.more_horiz
                  : capture.status == CaptureStatus.failed
                  ? Icons.refresh
                  : Icons.chevron_right,
              color: capture.status == CaptureStatus.failed
                  ? const Color(0xFFD14343)
                  : const Color(0xFFB0B8C1),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  static String _failureMessage(String? code) {
    return switch (code) {
      'multiple_images_not_supported' => '여러 장은 아직 분석할 수 없어요. 한 장씩 공유해 주세요.',
      'analysis_server_unreachable' => '로컬 분석 서버를 확인한 뒤 다시 눌러 주세요.',
      'rate_limited' => '요청이 잠시 몰렸어요. 조금 뒤 다시 눌러 주세요.',
      'image_too_large' => '이미지 용량이 커서 읽지 못했어요.',
      'invalid_image' || 'source_file_changed' => '원본 이미지를 확인하지 못했어요.',
      'analysis_timed_out' => '분석 시간이 길어졌어요. 다시 시도해 주세요.',
      _ => '오른쪽 새로고침을 눌러 다시 시도할 수 있어요.',
    };
  }
}

final class _CaptureThumbnail extends StatelessWidget {
  const _CaptureThumbnail({required this.attachment});

  final IncomingAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 80,
        child: ColoredBox(
          color: const Color(0xFFF1F3F5),
          child: Image.file(
            File(attachment.filePath),
            fit: BoxFit.cover,
            cacheWidth: 192,
            errorBuilder: (_, _, _) => const Icon(
              Icons.image_not_supported_outlined,
              color: AppTheme.subtle,
            ),
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
    final canSubmit = _textController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D6DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('콘텐츠 추가', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          const Text(
            'SNS에서 공유한 텍스트나 링크를 붙여넣어 주세요.\n원문은 수정하지 않고 그대로 보관해요.',
            style: TextStyle(color: AppTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _textController,
            autofocus: true,
            minLines: 5,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '텍스트 또는 URL을 입력해 주세요',
              hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit
                  ? () {
                      final captureId = widget.controller.addManualInput(
                        _textController.text,
                      );
                      Navigator.of(context).pop(captureId);
                    }
                  : null,
              child: const Text('콘텐츠 추가하기'),
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
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 24,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '이 상태의 콘텐츠가 없어요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            '다른 상태를 확인하거나 새 콘텐츠를 추가해 보세요.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: onShowAll, child: const Text('전체 보기')),
        ],
      ),
    );
  }
}
