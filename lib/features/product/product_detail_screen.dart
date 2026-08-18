import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/content_folder_ui.dart';
import '../common/product_ui.dart';

final class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    required this.controller,
    required this.groupId,
    super.key,
  });

  final AppController controller;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final group = controller.groupById(groupId);
          if (group == null) {
            return const Scaffold(body: Center(child: Text('제품을 찾지 못했어요.')));
          }

          final captures = controller.capturesForGroup(groupId);
          final captureById = {
            for (final capture in captures) capture.raw.id: capture,
          };
          final evidenceGroups = _evidenceGroups(group.statements);

          return Scaffold(
            appBar: AppBar(title: const Text('제품별 정리')),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                44 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _ProductHeader(group: group),
                const SizedBox(height: 24),
                ContentFolderPicker(
                  value: controller.folderForGroup(groupId),
                  onChanged: (folder) {
                    unawaited(
                      controller.updateGroupContentFolder(groupId, folder),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ContentSubcategoryPicker(
                  key: const Key('content-subcategory-picker'),
                  folder: controller.folderForGroup(groupId),
                  value: controller.subcategoryForGroup(groupId),
                  aiSuggested: false,
                  onChanged: (subcategory) {
                    unawaited(
                      controller.updateGroupContentSubcategory(
                        groupId,
                        subcategory,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                _SectionHeading(
                  title: '콘텐츠에서 나온 이야기',
                  description: '저장한 원문의 표현을 주제별로 모았어요.',
                ),
                const SizedBox(height: 14),
                if (evidenceGroups.isEmpty)
                  const _EmptyTopics()
                else
                  _EvidenceList(
                    evidenceGroups: evidenceGroups,
                    captureById: captureById,
                  ),
                const SizedBox(height: 36),
                const _SectionHeading(title: '광고·협찬 표시'),
                const SizedBox(height: 14),
                _DisclosureSummary(captures: captures),
                const SizedBox(height: 36),
                _SectionHeading(
                  title: '저장한 원문',
                  description: '${captures.length}개의 콘텐츠가 연결되어 있어요.',
                ),
                const SizedBox(height: 14),
                _SourceList(captures: captures),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_EvidenceGroup> _evidenceGroups(List<ContentStatement> statements) {
    final grouped = <String, _EvidenceGroupBuilder>{};
    for (final statement in statements) {
      if (statement.type == StatementType.disclosure) {
        continue;
      }
      final key = '${statement.captureId}\u0000${statement.originalExpression}';
      grouped
          .putIfAbsent(
            key,
            () => _EvidenceGroupBuilder(
              captureId: statement.captureId,
              expression: statement.originalExpression,
            ),
          )
          .topics
          .add(statement.topic);
    }

    return grouped.values
        .map(
          (group) => _EvidenceGroup(
            captureId: group.captureId,
            expression: group.expression,
            topics: group.topics.toList(growable: false)..sort(),
          ),
        )
        .toList(growable: false);
  }
}

final class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.group});

  final ProductGroup group;

  @override
  Widget build(BuildContext context) {
    final meta = [
      group.identity.category,
      group.identity.amount,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.planBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorialProductArt(group: group),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.identity.brand,
                  style: const TextStyle(
                    color: AppTheme.planMuted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group.identity.name,
                  style: const TextStyle(
                    color: AppTheme.planInk,
                    fontSize: 23,
                    height: 1.25,
                    letterSpacing: -0.55,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    style: const TextStyle(
                      color: AppTheme.planMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  '연결된 콘텐츠 ${group.sourceCount}개',
                  style: const TextStyle(
                    color: AppTheme.planMauve,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
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

final class _EditorialProductArt extends StatelessWidget {
  const _EditorialProductArt({required this.group});

  final ProductGroup group;

  @override
  Widget build(BuildContext context) {
    final icon = switch (group.identity.category) {
      '선케어' => Icons.wb_sunny_outlined,
      '클렌저' => Icons.waves_outlined,
      '크림' || '로션' => Icons.spa_outlined,
      _ => Icons.water_drop_outlined,
    };

    return Semantics(
      label:
          '${group.identity.brand} ${group.identity.name}, ${group.identity.category}',
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppTheme.planMauveSoft,
          border: Border.all(color: AppTheme.planBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppTheme.planMauve, size: 25),
      ),
    );
  }
}

final class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: const TextStyle(
              color: AppTheme.planMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

final class _EvidenceList extends StatelessWidget {
  const _EvidenceList({
    required this.evidenceGroups,
    required this.captureById,
  });

  final List<_EvidenceGroup> evidenceGroups;
  final Map<String, CaptureRecord> captureById;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.planSurface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.planBorder),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < evidenceGroups.length; index++) ...[
            _EvidenceRow(
              evidence: evidenceGroups[index],
              capture: captureById[evidenceGroups[index].captureId],
            ),
            if (index != evidenceGroups.length - 1)
              const Divider(indent: 20, endIndent: 20),
          ],
        ],
      ),
    );
  }
}

final class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.evidence, required this.capture});

  final _EvidenceGroup evidence;
  final CaptureRecord? capture;

  @override
  Widget build(BuildContext context) {
    final platform = capture == null
        ? null
        : capture!.normalized.urls.isEmpty
        ? SourcePlatform.textOnly
        : capture!.normalized.urls.first.platform;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evidence.topics.join(' · '),
            style: const TextStyle(
              color: AppTheme.planMauve,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.planMauve, width: 2),
              ),
            ),
            child: Text(
              evidence.expression,
              style: const TextStyle(
                color: AppTheme.planInk,
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ),
          if (capture != null && platform != null) ...[
            const SizedBox(height: 9),
            Text(
              '${sourcePlatformLabel(platform)} · '
              '${formatCaptureTime(capture!.raw.receivedAt)}',
              style: const TextStyle(color: AppTheme.planSubtle, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

final class _EvidenceGroupBuilder {
  _EvidenceGroupBuilder({required this.captureId, required this.expression});

  final String captureId;
  final String expression;
  final Set<String> topics = {};
}

final class _EvidenceGroup {
  const _EvidenceGroup({
    required this.captureId,
    required this.expression,
    required this.topics,
  });

  final String captureId;
  final String expression;
  final List<String> topics;
}

final class _DisclosureSummary extends StatelessWidget {
  const _DisclosureSummary({required this.captures});

  final List<CaptureRecord> captures;

  @override
  Widget build(BuildContext context) {
    final observed = captures
        .where(
          (capture) =>
              capture.analysis?.disclosure ==
              DisclosureObservation.explicitlyObserved,
        )
        .length;
    final notObserved = captures
        .where(
          (capture) =>
              capture.analysis?.disclosure ==
              DisclosureObservation.notObservedInCapturedMaterial,
        )
        .length;
    final unknown = captures.length - observed - notObserved;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.planSurface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.planBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Column(
          children: [
            _DisclosureRow(
              label: '표시가 있는 콘텐츠',
              count: observed,
              color: AppTheme.planSage,
            ),
            const Divider(),
            _DisclosureRow(
              label: '표시를 찾지 못한 콘텐츠',
              count: notObserved,
              color: AppTheme.planSubtle,
            ),
            if (unknown > 0) ...[
              const Divider(),
              _DisclosureRow(
                label: '확인할 수 없는 콘텐츠',
                count: unknown,
                color: AppTheme.planSubtle,
              ),
            ],
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '표시가 보이지 않는다고 해서 비광고라는 뜻은 아니에요.',
                style: TextStyle(
                  color: AppTheme.planSubtle,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.planInk, fontSize: 14),
            ),
          ),
          Text(
            '$count개',
            style: const TextStyle(
              color: AppTheme.planInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

final class _SourceList extends StatelessWidget {
  const _SourceList({required this.captures});

  final List<CaptureRecord> captures;

  @override
  Widget build(BuildContext context) {
    if (captures.isEmpty) {
      return const _EmptySources();
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.planSurface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.planBorder),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < captures.length; index++) ...[
            _SourceSection(capture: captures[index]),
            if (index != captures.length - 1)
              const Divider(indent: 20, endIndent: 20),
          ],
        ],
      ),
    );
  }
}

final class _SourceSection extends StatefulWidget {
  const _SourceSection({required this.capture});

  final CaptureRecord capture;

  @override
  State<_SourceSection> createState() => _SourceSectionState();
}

final class _SourceSectionState extends State<_SourceSection> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final capture = widget.capture;
    final platform = capture.normalized.urls.isEmpty
        ? SourcePlatform.textOnly
        : capture.normalized.urls.first.platform;
    final disclosure =
        capture.analysis?.disclosure ?? DisclosureObservation.unknown;
    final hasExplicitDisclosure =
        disclosure == DisclosureObservation.explicitlyObserved;
    final rawText = capture.raw.rawText.trim();
    final content = rawText.isEmpty ? '공유된 내용이 없어요.' : rawText;
    const sourceTextStyle = TextStyle(
      color: AppTheme.planInk,
      fontSize: 14,
      height: 1.6,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.planMauveSoft,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(
                  sourcePlatformIcon(platform),
                  color: AppTheme.planMauve,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourcePlatformLabel(platform),
                      style: const TextStyle(
                        color: AppTheme.planInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatCaptureTime(capture.raw.receivedAt),
                      style: const TextStyle(
                        color: AppTheme.planSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final previewPainter = TextPainter(
                text: TextSpan(text: content, style: sourceTextStyle),
                maxLines: 3,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final canExpand = previewPainter.didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_expanded)
                    SelectableText(
                      content,
                      key: ValueKey('source-raw-${capture.raw.id}'),
                      style: sourceTextStyle,
                    )
                  else
                    Text(
                      content,
                      key: ValueKey('source-raw-${capture.raw.id}'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: sourceTextStyle,
                    ),
                  if (canExpand) ...[
                    const SizedBox(height: 2),
                    TextButton(
                      key: ValueKey('source-toggle-${capture.raw.id}'),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(_expanded ? '접기' : '원문 전체 보기'),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasExplicitDisclosure
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: hasExplicitDisclosure
                    ? AppTheme.planSage
                    : AppTheme.planSubtle,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  disclosureLabel(disclosure),
                  style: TextStyle(
                    color: hasExplicitDisclosure
                        ? AppTheme.planSage
                        : AppTheme.planMuted,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _EmptyTopics extends StatelessWidget {
  const _EmptyTopics();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.planSurface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.planBorder),
        ),
      ),
      child: const Text(
        '아직 함께 묶을 만한 이야기가 없어요.',
        style: TextStyle(color: AppTheme.planMuted, fontSize: 14),
      ),
    );
  }
}

final class _EmptySources extends StatelessWidget {
  const _EmptySources();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.planSurface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.planBorder),
        ),
      ),
      child: const Text(
        '연결된 원문이 없어요.',
        style: TextStyle(color: AppTheme.planMuted, fontSize: 14),
      ),
    );
  }
}
