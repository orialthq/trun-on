import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
            const SizedBox(height: 28),
            _SectionTitle(
              title: '카테고리',
              actionLabel: '정리함 보기',
              onAction: onOpenLibrary,
            ),
            const SizedBox(height: 14),
            _CategoryRoulette(
              controller: controller,
              onOpenLibrary: onOpenLibrary,
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
        : '콘텐츠를 추가해 보세요';
    final String? description = analyzing > 0
        ? '분석이 끝나면 바로 알려드릴게요.'
        : needsReview > 0
        ? null
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
                if (description != null) ...[
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
                ],
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
    final inbox = _StatMetric(
      key: const Key('home-inbox-card'),
      label: '들어온 것',
      value: '$inboxCount',
      unit: '개',
      icon: Icons.inbox_outlined,
      color: AppTheme.accent,
      onTap: onOpenInbox,
    );
    final library = _StatMetric(
      key: const Key('home-library-card'),
      label: '정리함',
      value: '$organizedCount',
      unit: '개',
      icon: Icons.bookmark_border_rounded,
      color: AppTheme.positive,
      onTap: onOpenLibrary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = textIsLarge || constraints.maxWidth < 330;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
          ),
          child: vertical
              ? Column(
                  children: [
                    inbox,
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    library,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: inbox),
                    const SizedBox(
                      height: 54,
                      child: VerticalDivider(width: 1),
                    ),
                    Expanded(child: library),
                  ],
                ),
        );
      },
    );
  }
}

final class _StatMetric extends StatelessWidget {
  const _StatMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '$label $value$unit',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    maxLines: 2,
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 29,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: ' $unit\n$label',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

final class _CategoryRoulette extends StatefulWidget {
  const _CategoryRoulette({
    required this.controller,
    required this.onOpenLibrary,
  });

  final AppController controller;
  final VoidCallback onOpenLibrary;

  @override
  State<_CategoryRoulette> createState() => _CategoryRouletteState();
}

final class _CategoryRouletteState extends State<_CategoryRoulette> {
  late final PageController _pageController;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.72);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textIsLarge = MediaQuery.textScalerOf(context).scale(14) > 18;
    return Column(
      children: [
        SizedBox(
          height: textIsLarge ? 184 : 154,
          child: PageView.builder(
            key: const PageStorageKey('home-category-roulette'),
            controller: _pageController,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            itemCount: defaultContentFolders.length,
            onPageChanged: (index) {
              if (_selectedIndex == index) return;
              setState(() => _selectedIndex = index);
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) {
              final folder = defaultContentFolders[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  final page =
                      _pageController.hasClients &&
                          _pageController.position.hasContentDimensions
                      ? _pageController.page ?? _selectedIndex.toDouble()
                      : _selectedIndex.toDouble();
                  final distance = (page - index).abs().clamp(0.0, 1.0);
                  final scale = 1 - (distance * 0.1);
                  final verticalOffset = distance * 9;
                  return Transform.translate(
                    offset: Offset(0, verticalOffset),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: 1 - (distance * 0.2),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _CategoryCard(
                    key: Key('home-category-${folder.name}'),
                    folder: folder,
                    count: widget.controller.organizedCountForFolder(folder),
                    active: index == _selectedIndex,
                    onTap: widget.onOpenLibrary,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < defaultContentFolders.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: index == _selectedIndex ? 20 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _selectedIndex
                      ? AppTheme.primary
                      : AppTheme.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

final class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.folder,
    required this.count,
    required this.active,
    required this.onTap,
    super.key,
  });

  final ContentFolder folder;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: folder.color,
      elevation: active ? 10 : 0,
      shadowColor: folder.color.withValues(alpha: 0.32),
      animationDuration: const Duration(milliseconds: 180),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${folder.label} $count개, 정리함에서 보기',
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(folder.icon, color: const Color(0xFF171717), size: 25),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF101010).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Color(0xFF171717),
                            fontSize: 13,
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
                    fontSize: 21,
                    height: 1.12,
                    letterSpacing: -0.55,
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
