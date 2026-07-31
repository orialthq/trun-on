import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final group = controller.groupById(groupId);
        if (group == null) {
          return const Scaffold(body: Center(child: Text('제품 묶음을 찾지 못했어요.')));
        }
        final captures = controller.capturesForGroup(groupId);
        final topics = _topicGroups(group.statements);

        return Scaffold(
          appBar: AppBar(
            title: const Text('제품별 정리'),
            backgroundColor: AppTheme.background,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _ProductHeader(group: group),
              const SizedBox(height: 24),
              const InfoBanner(
                icon: Icons.fact_check_outlined,
                title: '원문에 나온 내용만 모았어요',
                body:
                    '아래 내용은 여러 콘텐츠의 표현을 출처별로 정리한 것이며, '
                    '제품 효능이나 사실을 검증한 결과가 아니에요.',
              ),
              const SizedBox(height: 28),
              const SectionTitle('반복해서 언급된 주제'),
              const SizedBox(height: 6),
              const Text(
                '같은 주제라도 출처마다 표현과 맥락이 다를 수 있어요.',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (topics.isEmpty)
                const _EmptyTopics()
              else
                ...topics.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TopicCard(
                      topic: entry.key,
                      statements: entry.value,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const SectionTitle('광고·협찬 표시 현황'),
              const SizedBox(height: 12),
              _DisclosureSummary(captures: captures),
              const SizedBox(height: 28),
              SectionTitle('연결된 원본 ${captures.length}개'),
              const SizedBox(height: 12),
              ...captures.map(
                (capture) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SourceCard(capture: capture),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '제품 정보가 잘못 묶였거나 원문과 다른 내용이 있다면 다음 단계에서 '
                '분리·수정 기능을 연결합니다. 현재는 분석 계약과 근거 추적을 검증하는 베이스라인입니다.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<ContentStatement>> _topicGroups(
    List<ContentStatement> statements,
  ) {
    final grouped = <String, List<ContentStatement>>{};
    for (final statement in statements) {
      if (statement.type == StatementType.disclosure) {
        continue;
      }
      grouped.putIfAbsent(statement.topic, () => []).add(statement);
    }
    final entries = grouped.entries.toList()
      ..sort((left, right) {
        final countOrder = right.value
            .map((statement) => statement.captureId)
            .toSet()
            .length
            .compareTo(
              left.value.map((statement) => statement.captureId).toSet().length,
            );
        return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
      });
    return Map.fromEntries(entries);
  }
}

final class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.group});

  final ProductGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductArt.forGroup(group, width: 104, height: 126),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill(
                label: '사용자 확인 완료',
                icon: Icons.verified_outlined,
                foreground: Color(0xFF176B4D),
                background: Color(0xFFE6F5EE),
              ),
              const SizedBox(height: 12),
              Text(
                group.identity.brand,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                group.identity.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                [
                  group.identity.category,
                  group.identity.amount,
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
              const SizedBox(height: 6),
              Text(
                '콘텐츠 ${group.sourceCount}개가 연결됨',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.statements});

  final String topic;
  final List<ContentStatement> statements;

  @override
  Widget build(BuildContext context) {
    final sourceCount = statements
        .map((statement) => statement.captureId)
        .toSet()
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$sourceCount개 출처',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...statements
                .take(3)
                .map(
                  (statement) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.format_quote,
                            size: 16,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statement.originalExpression,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DisclosureRow(
              icon: Icons.campaign_outlined,
              label: '명시적 표시 발견',
              count: observed,
            ),
            const Divider(height: 24),
            _DisclosureRow(
              icon: Icons.search,
              label: '캡처 자료에서 표시 미발견',
              count: notObserved,
            ),
            if (unknown > 0) ...[
              const Divider(height: 24),
              _DisclosureRow(
                icon: Icons.help_outline,
                label: '확인 불가',
                count: unknown,
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              '표시 미발견은 비광고 판정이 아니에요.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text('$count개', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

final class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.capture});

  final CaptureRecord capture;

  @override
  Widget build(BuildContext context) {
    final platform = capture.normalized.urls.isEmpty
        ? SourcePlatform.textOnly
        : capture.normalized.urls.first.platform;
    return Card(
      child: ExpansionTile(
        leading: Icon(sourcePlatformIcon(platform), color: AppTheme.primary),
        title: Text(
          sourcePlatformLabel(platform),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(formatCaptureTime(capture.raw.receivedAt)),
        trailing: const Icon(Icons.expand_more),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              capture.raw.rawText,
              style: const TextStyle(color: AppTheme.muted, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              disclosureLabel(
                capture.analysis?.disclosure ?? DisclosureObservation.unknown,
              ),
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          '연결된 원본에서 공통 주제를 찾지 못했어요.',
          style: TextStyle(color: AppTheme.muted),
        ),
      ),
    );
  }
}
