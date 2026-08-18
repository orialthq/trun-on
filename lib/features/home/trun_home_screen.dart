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
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: ColoredBox(
        color: AppTheme.planCanvas,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final recent = controller.captures.take(3).toList(growable: false);
            final hasPendingWork =
                controller.needsReviewCount > 0 ||
                controller.analyzingCount > 0;
            return ListView(
              key: const PageStorageKey('trun-home'),
              padding: const EdgeInsets.fromLTRB(22, 27, 22, 48),
              children: [
                _Masthead(onAdd: onAdd),
                const SizedBox(height: 26),
                _NextStepCard(
                  needsReview: controller.needsReviewCount,
                  analyzing: controller.analyzingCount,
                  onTap: hasPendingWork ? onOpenInbox : onAdd,
                ),
                const SizedBox(height: 38),
                const _SectionTitle(
                  title: '카테고리',
                  description: '정리한 내용을 주제별로 둘러보세요.',
                ),
                const SizedBox(height: 16),
                _CategoryRoulette(
                  controller: controller,
                  onOpenLibrary: onOpenLibrary,
                ),
                const SizedBox(height: 40),
                _SectionTitle(
                  title: '최근 콘텐츠',
                  actionLabel: '전체 보기',
                  onAction: onOpenInbox,
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  _EmptyRecent(onAdd: onAdd)
                else
                  Column(
                    children: [
                      const Divider(height: 1),
                      for (var index = 0; index < recent.length; index++) ...[
                        _RecentRow(
                          capture: recent[index],
                          onTap: () => onOpenCapture(recent[index]),
                        ),
                        Divider(
                          height: 1,
                          indent: index == recent.length - 1 ? 0 : 48,
                        ),
                      ],
                    ],
                  ),
              ],
            );
          },
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 9,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'TRUN ON',
                    style: TextStyle(
                      color: AppTheme.planInk,
                      fontSize: 28,
                      height: 1.12,
                      letterSpacing: -1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.fromBorderSide(
                        BorderSide(color: AppTheme.planBorder),
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      child: Text(
                        'BETA',
                        style: TextStyle(
                          color: AppTheme.planSubtle,
                          fontSize: 10,
                          height: 1.2,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 7),
              Text(
                '저장한 정보를 필요한 순간으로 이어요.',
                style: TextStyle(
                  color: AppTheme.planMuted,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: '콘텐츠 추가',
          onPressed: onAdd,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            backgroundColor: AppTheme.planSurface,
            foregroundColor: AppTheme.planInk,
            side: const BorderSide(color: AppTheme.planBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 21),
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
    final icon = analyzing > 0
        ? Icons.hourglass_top_rounded
        : needsReview > 0
        ? Icons.task_alt_rounded
        : Icons.note_add_outlined;
    final accent = needsReview > 0 && analyzing == 0
        ? AppTheme.planSage
        : AppTheme.planMauve;
    final accentSoft = needsReview > 0 && analyzing == 0
        ? AppTheme.planSageSoft
        : AppTheme.planMauveSoft;

    return Material(
      color: AppTheme.planSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: AppTheme.planBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '$title, $actionLabel',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 15, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.planInk,
                          fontSize: 17,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppTheme.planMuted,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: accent,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 9),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.planSubtle,
                    size: 20,
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
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.planInk,
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (description case final description?) ...[
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.planMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel case final actionLabel?)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.planMuted,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(actionLabel),
          ),
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
    _pageController = PageController(viewportFraction: 0.86);
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
          height: textIsLarge ? 156 : 126,
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
                  final pageOffset = (page - index).clamp(-1.0, 1.0);
                  final distance = pageOffset.abs();
                  final scale = 1 - (distance * 0.035);
                  final transform = Matrix4.identity()
                    ..translateByDouble(0, distance * 4, 0, 1)
                    ..scaleByDouble(scale, scale, scale, 1);
                  return Transform(
                    key: Key('home-category-transform-${folder.name}'),
                    transform: transform,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                    child: Opacity(
                      key: Key('home-category-opacity-${folder.name}'),
                      opacity: 1 - (distance * 0.22),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
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
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < defaultContentFolders.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: index == _selectedIndex ? 14 : 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: index == _selectedIndex
                      ? AppTheme.planMauve
                      : AppTheme.planBorder,
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
      color: active
          ? AppTheme.planSurface
          : AppTheme.planSurface.withValues(alpha: 0.72),
      elevation: 0,
      animationDuration: const Duration(milliseconds: 180),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active ? AppTheme.planMauve : AppTheme.planBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${folder.label} $count개, 정리함에서 보기',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 13, 15),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: folder.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(folder.icon, color: folder.color, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.planInk,
                          fontSize: 16,
                          height: 1.3,
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count개 저장됨',
                        style: const TextStyle(
                          color: AppTheme.planMuted,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.planSubtle,
                  size: 15,
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
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: folder.color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(folder.icon, color: folder.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.planInk,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${folder.label} · ${formatCaptureTime(capture.raw.receivedAt)}',
                        style: const TextStyle(
                          color: AppTheme.planMuted,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.planSubtle,
                  size: 18,
                ),
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.planBorder),
          bottom: BorderSide(color: AppTheme.planBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            const Icon(
              Icons.inbox_outlined,
              color: AppTheme.planSubtle,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '아직 들어온 콘텐츠가 없어요.',
                style: TextStyle(
                  color: AppTheme.planMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.planInk,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('추가하기'),
            ),
          ],
        ),
      ),
    );
  }
}
