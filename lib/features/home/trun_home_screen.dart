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
        return ListView(
          key: const PageStorageKey('trun-home'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            _Masthead(onAdd: onAdd),
            const SizedBox(height: 34),
            Text(
              '발견에서 멈추지 말고,\n내 것으로 켜.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'SNS에서 건진 정보를 이해하기 쉽게 정리하고,\n필요한 순간 다시 찾을 수 있게 모아요.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            _NextStepCard(
              needsReview: controller.needsReviewCount,
              analyzing: controller.analyzingCount,
              onTap: onOpenInbox,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    key: const Key('home-inbox-card'),
                    eyebrow: '받은 콘텐츠',
                    value: '${controller.captures.length}',
                    unit: '개',
                    icon: Icons.inbox_outlined,
                    color: AppTheme.accent,
                    onTap: onOpenInbox,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    key: const Key('home-library-card'),
                    eyebrow: '정리 완료',
                    value: '${controller.organizedCount}',
                    unit: '개',
                    icon: Icons.bookmark_border_rounded,
                    color: AppTheme.positive,
                    onTap: onOpenLibrary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            _SectionTitle(
              title: '카테고리',
              actionLabel: '정리함 보기',
              onAction: onOpenLibrary,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
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
        : '새로운 발견을 가져와요';
    final description = analyzing > 0
        ? '분석이 끝나면 바로 알려드릴게요.'
        : needsReview > 0
        ? 'AI가 정리한 내용을 확인하고 저장해 주세요.'
        : '캡처나 링크·텍스트를 추가해 시작할 수 있어요.';

    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEXT',
                      style: TextStyle(
                        color: Color(0xFF3E5010),
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF101208),
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF35430E),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const SizedBox.square(
                dimension: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF101208),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.primary,
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
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 24),
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
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
                        fontSize: 28,
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
    return SizedBox(
      width: 126,
      child: Material(
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(folder.icon, color: folder.color, size: 22),
                      const Spacer(),
                      Text(
                        folder.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: folder.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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
