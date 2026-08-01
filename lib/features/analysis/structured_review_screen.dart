import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';

final class StructuredReviewScreen extends StatefulWidget {
  const StructuredReviewScreen({
    required this.controller,
    required this.captureId,
    super.key,
  });

  final AppController controller;
  final String captureId;

  @override
  State<StructuredReviewScreen> createState() => _StructuredReviewScreenState();
}

final class _StructuredReviewScreenState extends State<StructuredReviewScreen> {
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final capture = widget.controller.captureById(widget.captureId);
    final structured = capture?.analysis?.structuredContent;
    if (capture == null || structured == null) {
      return const Scaffold(body: Center(child: Text('분석 결과를 찾지 못했어요.')));
    }
    final isOrganized = capture.status == CaptureStatus.organized;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, isOrganized ? 40 : 124),
        children: [
          Row(
            children: [
              _KindBadge(kind: structured.contentKind),
              const SizedBox(width: 8),
              _CompletenessBadge(completeness: structured.completeness),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            structured.title.value?.trim().isNotEmpty == true
                ? structured.title.value!
                : '제목을 확인해 주세요',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (structured.title.status != ObservedStatus.observed) ...[
            const SizedBox(height: 6),
            Text(
              structured.title.status == ObservedStatus.inferred
                  ? '이미지 내용으로 추정한 제목이에요.'
                  : '이미지에서 제목을 확인하지 못했어요.',
              style: const TextStyle(
                color: Color(0xFFB26A00),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (structured.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              structured.summary,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ],
          if (capture.raw.attachments.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SourceImage(attachment: capture.raw.attachments.first),
          ],
          if (structured.conflicts.isNotEmpty ||
              structured.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ReviewNotice(structured: structured),
          ],
          if (structured.ingredientGroups.isNotEmpty) ...[
            const SizedBox(height: 32),
            const _SectionTitle(title: '재료'),
            const SizedBox(height: 12),
            for (final group in structured.ingredientGroups) ...[
              _IngredientGroupCard(group: group),
              const SizedBox(height: 12),
            ],
          ],
          if (structured.steps.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle(title: '만드는 순서'),
            const SizedBox(height: 12),
            _StepsCard(steps: structured.steps),
          ],
          if (structured.facts.isNotEmpty) ...[
            const SizedBox(height: 32),
            const _SectionTitle(title: '화면에서 확인한 정보'),
            const SizedBox(height: 12),
            _FactsCard(facts: structured.facts),
          ],
          if (structured.evidence.isNotEmpty) ...[
            const SizedBox(height: 32),
            const _SectionTitle(
              title: '근거',
              subtitle: '이미지에서 실제로 읽힌 내용만 모았어요.',
            ),
            const SizedBox(height: 12),
            _EvidenceCard(evidence: structured.evidence),
          ],
        ],
      ),
      bottomNavigationBar: isOrganized
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _confirm,
                    child: Text(_saving ? '저장하고 있어요…' : '확인하고 정리하기'),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      await widget.controller.confirmStructured(widget.captureId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

final class _SourceImage extends StatelessWidget {
  const _SourceImage({required this.attachment});

  final IncomingAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ColoredBox(
          color: const Color(0xFFF1F3F5),
          child: Image.file(
            File(attachment.filePath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppTheme.subtle,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final ContentKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (kind) {
      ContentKind.recipe => ('레시피', Icons.restaurant_menu_rounded),
      ContentKind.sauceRecipe => ('소스 레시피', Icons.soup_kitchen_outlined),
      ContentKind.commerceProduct => ('상품', Icons.shopping_bag_outlined),
      ContentKind.productReview => ('리뷰', Icons.rate_review_outlined),
      ContentKind.menuComparison => ('메뉴 비교', Icons.compare_arrows_rounded),
      ContentKind.beautyProduct => ('뷰티 제품', Icons.spa_outlined),
      ContentKind.unknown => ('기타', Icons.image_outlined),
    };
    return _Badge(label: label, icon: icon, color: AppTheme.primary);
  }
}

final class _CompletenessBadge extends StatelessWidget {
  const _CompletenessBadge({required this.completeness});

  final StructuredCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (completeness) {
      StructuredCompleteness.complete => ('내용 충분', const Color(0xFF16815D)),
      StructuredCompleteness.partial => ('일부만 확인', const Color(0xFFB26A00)),
      StructuredCompleteness.conflicted => (
        '서로 다른 내용',
        const Color(0xFFD14343),
      ),
      StructuredCompleteness.needsReview => ('확인 필요', const Color(0xFFB26A00)),
      StructuredCompleteness.unsupported => ('분류 어려움', AppTheme.muted),
    };
    return _Badge(label: label, icon: Icons.check_circle_outline, color: color);
  }
}

final class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle case final value?) ...[
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

final class _IngredientGroupCard extends StatelessWidget {
  const _IngredientGroupCard({required this.group});

  final IngredientGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.name.trim().isNotEmpty) ...[
            Text(
              group.name,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final ingredient in group.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ingredient.name,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _ingredientAmount(ingredient),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color:
                          ingredient.amount == null && ingredient.unit == null
                          ? AppTheme.subtle
                          : AppTheme.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _ingredientAmount(RecipeIngredient ingredient) {
    final amount = [
      ingredient.amount,
      ingredient.unit,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
    if (amount.isNotEmpty) {
      return ingredient.optional ? '$amount · 선택' : amount;
    }
    return ingredient.optional ? '분량 미표기 · 선택' : '분량 미표기';
  }
}

final class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${step.order}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.instruction,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        if (step.durationSeconds != null ||
                            step.temperature != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            [
                              if (step.durationSeconds case final seconds?)
                                _formatDuration(seconds),
                              ?step.temperature,
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds초';
    }
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return remainder == 0 ? '$minutes분' : '$minutes분 $remainder초';
  }
}

final class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.facts});

  final List<AnalysisFact> facts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final fact in facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 94,
                    child: Text(
                      fact.label,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fact.value,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
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

final class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.evidence});

  final List<StructuredEvidence> evidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var index = 0; index < evidence.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 17,
                    color: AppTheme.subtle,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      evidence[index].text,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index != evidence.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

final class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.structured});

  final StructuredContentAnalysis structured;

  @override
  Widget build(BuildContext context) {
    final messages = [
      ...structured.conflicts.map(
        (conflict) => '${conflict.field}: ${conflict.details}',
      ),
      ...structured.warnings,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFB26A00),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messages.join('\n'),
              style: const TextStyle(
                color: Color(0xFF7A4A00),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
