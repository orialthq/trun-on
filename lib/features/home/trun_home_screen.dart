import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/content_folder_ui.dart';

final class TrunHomeScreen extends StatelessWidget {
  const TrunHomeScreen({
    required this.controller,
    required this.onAdd,
    required this.onOpenInbox,
    required this.onOpenLibrary,
    required this.onOpenCapture,
    super.key,
  });

  final AppController controller;
  final VoidCallback onAdd;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenLibrary;
  final ValueChanged<CaptureRecord> onOpenCapture;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final recent = controller.captures.take(3).toList(growable: false);
        final hasPendingWork =
            controller.needsReviewCount > 0 || controller.analyzingCount > 0;
        final organizedLibraryCount =
            controller.groups.length +
            controller.organizedStructuredCaptures.length;
        return ListView(
          key: const PageStorageKey('trun-home'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            _Masthead(onAdd: onAdd),
            const SizedBox(height: 20),
            _NextStepCard(
              needsReview: controller.needsReviewCount,
              analyzing: controller.analyzingCount,
              onTap: hasPendingWork ? onOpenInbox : onAdd,
            ),
            const SizedBox(height: 14),
            _StatsGrid(
              inboxCount: controller.captures.length,
              organizedCount: organizedLibraryCount,
              onOpenInbox: onOpenInbox,
              onOpenLibrary: onOpenLibrary,
            ),
            const SizedBox(height: 18),
            const _BrandStatement(),
            const SizedBox(height: 32),
            _SectionTitle(
              title: '카테고리',
              actionLabel: '정리함 보기',
              onAction: onOpenLibrary,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(14) > 18
                  ? 148
                  : 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: defaultContentFolders.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final folder = defaultContentFolders[index];
                  return _CategoryCard(
                    folder: folder,
                    count: controller.organizedCountForFolder(folder),
                    onTap: onOpenLibrary,
                  );
                },
              ),
            ),
            const SizedBox(height: 34),
            _SectionTitle(
              title: '최근 들어온 것',
              actionLabel: '전체 보기',
              onAction: onOpenInbox,
            ),
            const SizedBox(height: 14),
            if (recent.isEmpty)
              _EmptyRecent(onAdd: onAdd)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < recent.length; index++) ...[
                      _RecentRow(
                        capture: recent[index],
                        onTap: () => onOpenCapture(recent[index]),
                      ),
                      if (index != recent.length - 1)
                        const Divider(indent: 68, endIndent: 16),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _BrandStatement extends StatelessWidget {
  const _BrandStatement();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(18, 17, 18, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 4,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '발견만으로는 달라지지 않으니까.',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'AI가 읽은 내용을 확인하고 폴더에 넣어 두세요.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Masthead extends StatelessWidget {
  const _Masthead({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Row(
            children: [
              Text(
                'TRUN ON',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 20,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'BETA',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          tooltip: '콘텐츠 추가',
          onPressed: onAdd,
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: const Color(0xFF101208),
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

final class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.needsReview,
    required this.analyzing,
    required this.onTap,
  });

  final int needsReview;
  final int analyzing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = analyzing > 0
        ? '$analyzing개를 읽고 있어요'
        : needsReview > 0
        ? '$needsReview개만 확인하면 끝'
        : '콘텐츠를 추가해 보세요';
    final description = analyzing > 0
        ? '분석이 끝나면 바로 알려드릴게요.'
        : needsReview > 0
        ? 'AI가 정리한 내용을 확인하고 저장해 주세요.'
        : '캡처나 링크·텍스트를 추가해 시작할 수 있어요.';
    final actionLabel = analyzing > 0
        ? '분석 상태 보기'
        : needsReview > 0
        ? '확인하고 정리하기'
        : '콘텐츠 가져오기';

    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '$title, $actionLabel',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF101208),
                    fontSize: 25,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.65,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF35430E),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101208),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 11, 10, 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox.square(
                            dimension: 28,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.inboxCount,
    required this.organizedCount,
    required this.onOpenInbox,
    required this.onOpenLibrary,
  });

  final int inboxCount;
  final int organizedCount;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final textIsLarge = MediaQuery.textScalerOf(context).scale(14) > 18;
    final inbox = _StatCard(
      key: const Key('home-inbox-card'),
      eyebrow: '받은 콘텐츠',
      value: '$inboxCount',
      unit: '개',
      icon: Icons.inbox_outlined,
      color: AppTheme.accent,
      onTap: onOpenInbox,
    );
    final library = _StatCard(
      key: const Key('home-library-card'),
      eyebrow: '정리 완료',
      value: '$organizedCount',
      unit: '개',
      icon: Icons.bookmark_border_rounded,
      color: AppTheme.positive,
      onTap: onOpenLibrary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (textIsLarge || constraints.maxWidth < 330) {
          return Column(children: [inbox, const SizedBox(height: 10), library]);
        }
        return Row(
          children: [
            Expanded(child: inbox),
            const SizedBox(width: 12),
            Expanded(child: library),
          ],
        );
      },
    );
  }
}

final class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.eyebrow,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String eyebrow;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '$eyebrow $value$unit',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eyebrow,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: value,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontSize: 27,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              text: ' $unit',
                              style: const TextStyle(
                                color: AppTheme.subtle,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

final class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.folder,
    required this.count,
    required this.onTap,
  });

  final ContentFolder folder;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textIsLarge = MediaQuery.textScalerOf(context).scale(14) > 18;
    return SizedBox(
      width: textIsLarge ? 160 : 142,
      child: Material(
        color: folder.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: '${folder.label} $count개, 정리함에서 보기',
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        folder.icon,
                        color: const Color(0xFF171717),
                        size: 22,
                      ),
                      const Spacer(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF101010,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Color(0xFF171717),
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    folder.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF171717),
                      fontSize: 17,
                      height: 1.15,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w900,
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

final class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.capture, required this.onTap});

  final CaptureRecord capture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final analysis = capture.analysis?.structuredContent;
    final title = analysis?.title.value?.trim();
    final mentionName = capture.primaryMention?.name.value?.trim();
    final normalizedText = capture.normalized.normalizedText.trim();
    final displayTitle = title?.isNotEmpty == true
        ? title!
        : mentionName?.isNotEmpty == true
        ? mentionName!
        : normalizedText.isNotEmpty
        ? normalizedText
        : '제목을 확인해 주세요';
    final folder = capture.contentFolder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: folder.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(folder.icon, color: folder.color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${folder.label} · ${formatCaptureTime(capture.raw.receivedAt)}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.subtle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '아직 들어온 콘텐츠가 없어요.',
                style: TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ),
            TextButton(onPressed: onAdd, child: const Text('추가하기')),
          ],
        ),
      ),
    );
  }
}
