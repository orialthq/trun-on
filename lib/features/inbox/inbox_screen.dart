import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../domain/portable_tip_package.dart';
import '../../state/app_controller.dart';
import '../analysis/analysis_review_screen.dart';
import '../analysis/structured_review_screen.dart';
import '../common/capture_action_ui.dart';
import '../common/product_ui.dart';
import '../product/product_detail_screen.dart';

final class InboxScreen extends StatelessWidget {
  const InboxScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final captures = controller.filteredCaptures;

          return ColoredBox(
            color: AppTheme.planCanvas,
            child: ListView(
              key: const PageStorageKey('content-inbox'),
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
              children: [
                _InboxHeader(onAdd: () => openManualInput(context, controller)),
                const SizedBox(height: 34),
                _CaptureSummaryCard(controller: controller),
                const SizedBox(height: 28),
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
                                    : 8,
                              ),
                              child: _FilterButton(
                                label: _filterLabel(filter),
                                count: _countForFilter(controller, filter),
                                color: _filterColor(filter),
                                selected: controller.filter == filter,
                                onPressed: () => controller.setFilter(filter),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                const Divider(),
                if (captures.isEmpty)
                  _EmptyInbox(
                    onShowAll: () {
                      controller.setFilter(CaptureFilter.all);
                    },
                  )
                else
                  Column(
                    children: [
                      for (var index = 0; index < captures.length; index++) ...[
                        _CaptureCard(
                          capture: captures[index],
                          controller: controller,
                          onTap: () => _openCapture(context, captures[index]),
                          onLongPress: () =>
                              _openCaptureActions(context, captures[index]),
                        ),
                        if (index != captures.length - 1) const Divider(),
                      ],
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> openManualInput(
    BuildContext context,
    AppController controller,
  ) async {
    final captureId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.planSurface,
      builder: (sheetContext) => Theme(
        data: AppTheme.plansTheme(Theme.of(sheetContext)),
        child: _ManualInputSheet(controller: controller),
      ),
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

  Future<void> _openCaptureActions(
    BuildContext context,
    CaptureRecord capture,
  ) async {
    final action = await showCaptureActionSheet(
      context,
      canOrganize: capture.status == CaptureStatus.needsReview,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case CaptureListAction.organize:
        final saved = controller.canQuickOrganize(capture.raw.id)
            ? await controller.quickOrganize(capture.raw.id)
            : false;
        if (!context.mounted) return;
        if (saved) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('정리함에 저장했어요.')));
        }
        if (!saved) {
          final current = controller.captureById(capture.raw.id);
          if (current != null) _openCapture(context, current);
        }
        return;
      case CaptureListAction.delete:
        await confirmCaptureDeletion(
          context,
          controller: controller,
          captureId: capture.raw.id,
        );
        return;
    }
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

  static Color _filterColor(CaptureFilter filter) {
    return switch (filter) {
      CaptureFilter.all => AppTheme.planMauve,
      CaptureFilter.needsReview => AppTheme.planSand,
      CaptureFilter.organized => AppTheme.planSage,
      CaptureFilter.limitedOrFailed => AppTheme.planNegative,
    };
  }
}

final class _InboxHeader extends StatelessWidget {
  const _InboxHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('콘텐츠', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 7),
        const Text(
          '저장한 캡처와 공유 내용을 차례로 살펴봐요.',
          style: TextStyle(
            color: AppTheme.planMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
    final addButton = Tooltip(
      message: '콘텐츠 추가',
      child: OutlinedButton.icon(
        key: const Key('inbox-add-button'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(82, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: AppTheme.planInk,
          backgroundColor: AppTheme.planSurface,
          side: const BorderSide(color: AppTheme.planBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, size: 19),
        label: const Text('추가'),
      ),
    );
    final usesStackedHeader = MediaQuery.textScalerOf(context).scale(14) > 18;
    if (usesStackedHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 14), addButton],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 16),
        addButton,
      ],
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '한눈에 보기',
          style: TextStyle(
            color: AppTheme.planSubtle,
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          headline,
          style: const TextStyle(
            color: AppTheme.planInk,
            fontSize: 19,
            height: 1.4,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 22,
          runSpacing: 9,
          children: [
            _SummaryMetric(label: '전체', value: controller.captures.length),
            _SummaryMetric(label: '확인 필요', value: needsReview),
            _SummaryMetric(label: '분석 중', value: analyzing),
            _SummaryMetric(label: '정리 완료', value: controller.organizedCount),
          ],
        ),
      ],
    );
  }
}

final class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppTheme.planInk,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.planMuted,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

final class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: selected ? 1 : 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$label $count',
                        style: TextStyle(
                          color: selected ? color : AppTheme.planMuted,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    height: 2,
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
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
    final isLinkOnly =
        capture.status == CaptureStatus.sourceLimited &&
        capture.raw.attachments.isEmpty &&
        capture.normalized.completeness == MaterialCompleteness.linkOnly;
    final (label, color) = isLinkOnly
        ? ('링크 저장', AppTheme.planSand)
        : switch (capture.status) {
            CaptureStatus.received ||
            CaptureStatus.analyzing => ('분석 중', AppTheme.planMauve),
            CaptureStatus.sourceLimited => ('내용 부족', AppTheme.planSand),
            CaptureStatus.needsReview => ('확인 필요', AppTheme.planSand),
            CaptureStatus.organized => ('정리 완료', AppTheme.planSage),
            CaptureStatus.failed => ('분석 실패', AppTheme.planNegative),
          };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontSize: 11,
            height: 1.3,
            fontWeight: FontWeight.w600,
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
    required this.onLongPress,
  });

  final CaptureRecord capture;
  final AppController controller;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final platform = capture.normalized.urls.isEmpty
        ? SourcePlatform.textOnly
        : capture.normalized.urls.first.platform;
    final isPortableTip = capture.raw.origin == CaptureOrigin.portableTip;
    final mention = capture.primaryMention;
    final structured = capture.analysis?.structuredContent;
    final isLinkOnly =
        capture.status == CaptureStatus.sourceLimited &&
        capture.raw.attachments.isEmpty &&
        capture.normalized.completeness == MaterialCompleteness.linkOnly;
    final productLabel = [
      mention?.brand.value,
      mention?.name.value,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    final title = structured?.title.value?.trim().isNotEmpty == true
        ? structured!.title.value!
        : isLinkOnly
        ? '링크를 저장했어요'
        : capture.status == CaptureStatus.analyzing
        ? '이미지에서 내용을 읽는 중이에요'
        : capture.status == CaptureStatus.failed
        ? '분석을 완료하지 못했어요'
        : productLabel.isEmpty
        ? capture.raw.attachments.isNotEmpty
              ? '이미지 내용을 확인해 주세요'
              : '제품을 특정하지 못했어요'
        : productLabel;
    final description = _listSummary(
      capture,
      structured: structured,
      isLinkOnly: isLinkOnly,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: capture.status == CaptureStatus.failed
            ? () => controller.retryAnalysis(capture.raw.id)
            : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 0, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (capture.raw.attachments.isNotEmpty) ...[
                _CaptureThumbnail(attachment: capture.raw.attachments.first),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 9,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (capture.raw.attachments.isEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPortableTip
                                    ? Icons.redeem_outlined
                                    : sourcePlatformIcon(platform),
                                color: AppTheme.planMuted,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPortableTip
                                    ? '받은 팁'
                                    : sourcePlatformLabel(platform),
                                style: const TextStyle(
                                  color: AppTheme.planMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        Text(
                          formatCaptureTime(capture.raw.receivedAt),
                          style: const TextStyle(
                            color: AppTheme.planSubtle,
                            fontSize: 11,
                          ),
                        ),
                        _CaptureStatusLabel(capture: capture),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.planInk,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.planMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                capture.status == CaptureStatus.analyzing
                    ? Icons.more_horiz
                    : capture.status == CaptureStatus.failed
                    ? Icons.refresh
                    : Icons.chevron_right,
                color: capture.status == CaptureStatus.failed
                    ? AppTheme.planNegative
                    : AppTheme.planSubtle,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _listSummary(
    CaptureRecord capture, {
    required StructuredContentAnalysis? structured,
    required bool isLinkOnly,
  }) {
    final aiSummary = structured?.summary.trim();
    if (aiSummary != null && aiSummary.isNotEmpty) {
      return _singleLine(aiSummary);
    }
    if (isLinkOnly) {
      return '게시물 내용이 없어 스크린샷이 필요해요.';
    }
    if (capture.status == CaptureStatus.analyzing) {
      return '이미지의 핵심 내용을 정리하고 있어요.';
    }
    if (capture.status == CaptureStatus.failed) {
      return _failureMessage(capture.analysis?.failureCode);
    }
    final statements = capture.analysis?.statements;
    if (statements != null && statements.isNotEmpty) {
      return _singleLine(statements.first.originalExpression);
    }
    return capture.raw.attachments.isNotEmpty
        ? '정리된 세부 내용을 확인해 주세요.'
        : '저장한 내용의 세부 정보를 확인해 주세요.';
  }

  static String _singleLine(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

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
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 54,
        height: 68,
        child: ColoredBox(
          color: AppTheme.planBorder,
          child: Image.file(
            File(attachment.filePath),
            fit: BoxFit.cover,
            cacheWidth: 192,
            errorBuilder: (_, _, _) => const Icon(
              Icons.image_not_supported_outlined,
              color: AppTheme.planSubtle,
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
  var _importingTip = false;
  var _pickingCapture = false;

  /// Both mobile platforms expose the picker in-app. Android also keeps its
  /// quick settings tile as an optional shortcut.
  bool get _showsCapturePicker =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _textController.text.trim().isNotEmpty;

    return SafeArea(
      key: const Key('manual-input-safe-area'),
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(bottom: AppTheme.bottomSheetSafeInset),
      child: SingleChildScrollView(
        key: const Key('manual-input-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  color: AppTheme.planBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('콘텐츠 추가', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            const Text(
              'SNS에서 공유한 본문이나 링크를 붙여넣어 주세요.\n'
              '링크만 입력하면 원본 링크만 저장돼요.',
              style: TextStyle(color: AppTheme.planMuted, height: 1.5),
            ),
            const SizedBox(height: 18),
            if (_showsCapturePicker) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickingCapture ? null : _pickCapture,
                  icon: _pickingCapture
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_rounded, size: 20),
                  label: Text(_pickingCapture ? '스크린샷을 읽고 있어요…' : '스크린샷 가져오기'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importingTip ? null : _importTipFile,
                icon: _importingTip
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.redeem_rounded, size: 20),
                label: Text(_importingTip ? '팁을 확인하고 있어요…' : '받은 팁 파일 가져오기'),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '또는 직접 입력',
                    style: TextStyle(color: AppTheme.planSubtle, fontSize: 12),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              minLines: 5,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '본문 텍스트 또는 URL을 입력해 주세요',
                hintStyle: const TextStyle(color: AppTheme.planSubtle),
                filled: true,
                fillColor: AppTheme.planCanvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.planBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.planBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.planMauve,
                    width: 1.4,
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
                child: const Text('내용 분석하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCapture() async {
    setState(() => _pickingCapture = true);
    try {
      final accepted = await widget.controller.presentCapturePicker();
      if (!mounted) return;
      if (!accepted) {
        // Cancelling the picker is the common case and needs no message; a
        // rejected image does, and the two are indistinguishable here.
        return;
      }
      // The image is already in the pending queue. Closing the sheet lets the
      // controller surface the analysis state card the same way a share does.
      Navigator.of(context).pop();
    } on Object catch (error, stackTrace) {
      debugPrint('Capture picker failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('스크린샷을 가져오지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() => _pickingCapture = false);
      }
    }
  }

  Future<void> _importTipFile() async {
    setState(() => _importingTip = true);
    try {
      const typeGroup = XTypeGroup(
        label: 'Trun On 팁',
        extensions: [PortableTipPackageCodec.fileExtension],
        // Chat and file-provider apps often replace a custom MIME type while
        // preserving the .trunon filename. The codec below still enforces the
        // 64 KiB limit and exact privacy-safe JSON schema after selection.
        mimeTypes: [
          PortableTipPackageCodec.mimeType,
          'application/octet-stream',
          'application/json',
        ],
        uniformTypeIdentifiers: [PortableTipPackageCodec.uniformTypeIdentifier],
      );
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null) return;
      final fileLength = await file.length();
      if (fileLength <= 0 || fileLength > PortableTipLimits.maxPackageBytes) {
        throw const FormatException('팁 파일이 비어 있거나 너무 커서 열 수 없어요.');
      }
      final bytes = await file.readAsBytes();
      final tip = PortableTipPackageCodec.decodeUtf8(bytes);
      if (!mounted) return;
      final transportId = widget.controller.stagePortableTip(
        PortableTipPackageCodec.encode(tip),
        announce: false,
      );
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.announcePortableTip(transportId);
      });
    } on FormatException catch (error) {
      debugPrint('Portable tip manual import rejected: ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error, stackTrace) {
      debugPrint('Portable tip manual import failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('이 파일은 Trun On 팁으로 열 수 없어요.')),
        );
    } finally {
      if (mounted) setState(() => _importingTip = false);
    }
  }
}

final class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 62),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 23,
            color: AppTheme.planSubtle,
          ),
          const SizedBox(height: 16),
          Text(
            '이 상태의 콘텐츠가 없어요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            '다른 상태를 확인하거나 새 콘텐츠를 추가해 보세요.',
            style: TextStyle(color: AppTheme.planMuted),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.planMuted),
            onPressed: onShowAll,
            child: const Text('전체 보기'),
          ),
        ],
      ),
    );
  }
}
