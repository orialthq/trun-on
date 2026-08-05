import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/incoming_share_service.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../analysis/analysis_review_screen.dart';
import '../analysis/structured_review_screen.dart';
import '../inbox/inbox_screen.dart';
import '../products/products_screen.dart';
import 'trun_home_screen.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell> {
  var _selectedIndex = 0;
  String? _incomingCaptureId;
  late StreamSubscription<String> _incomingCaptureSubscription;
  Future<void> _sourceChoiceTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _listenForIncomingCaptures();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    unawaited(_incomingCaptureSubscription.cancel());
    _listenForIncomingCaptures();
  }

  void _listenForIncomingCaptures() {
    _incomingCaptureSubscription = widget.controller.incomingCaptureAdded
        .listen((captureId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _selectedIndex = 1;
              _incomingCaptureId = captureId;
            });
            Navigator.of(context).popUntil((route) => route.isFirst);
            if (widget.controller.canDeleteSharedSource(captureId)) {
              _sourceChoiceTail = _sourceChoiceTail.then(
                (_) => _showSourceChoice(captureId),
              );
            }
          });
        });
  }

  Future<void> _showSourceChoice(String captureId) async {
    if (!mounted || !widget.controller.canDeleteSharedSource(captureId)) {
      return;
    }
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => const _SourceImageChoiceSheet(),
    );
    if (!mounted) return;

    if (shouldDelete != true) {
      await widget.controller.keepSharedSource(captureId);
      if (mounted) _showMessage('갤러리 원본을 그대로 두었어요.');
      return;
    }
    final result = await widget.controller.deleteSharedSource(captureId);
    if (!mounted) return;
    _showMessage(switch (result) {
      SharedSourceDeletionResult.deleted => '갤러리 원본을 삭제했어요.',
      SharedSourceDeletionResult.kept => '갤러리 원본을 그대로 두었어요.',
      SharedSourceDeletionResult.unavailable =>
        '이 이미지의 원본은 Trun On에서 삭제할 수 없어요.',
      SharedSourceDeletionResult.failed => '갤러리 원본을 삭제하지 못했어요.',
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    unawaited(_incomingCaptureSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TrunHomeScreen(
        controller: widget.controller,
        onAdd: () => InboxScreen.openManualInput(context, widget.controller),
        onOpenInbox: () => setState(() => _selectedIndex = 1),
        onOpenLibrary: () => setState(() => _selectedIndex = 2),
        onOpenCapture: _openCapture,
      ),
      InboxScreen(controller: widget.controller),
      ProductsScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: IndexedStack(index: _selectedIndex, children: screens),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.12),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _incomingCaptureId == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(_incomingCaptureId),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: _IncomingCaptureCard(
                          controller: widget.controller,
                          captureId: _incomingCaptureId!,
                          onDismiss: () {
                            setState(() => _incomingCaptureId = null);
                          },
                          onOpen: () =>
                              _openIncomingCapture(_incomingCaptureId!),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            height: 72,
            indicatorColor: AppTheme.primarySoft,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? AppTheme.primary : AppTheme.subtle,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox),
                label: '콘텐츠',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: '정리함',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openIncomingCapture(String captureId) {
    final capture = widget.controller.captureById(captureId);
    if (capture == null) {
      setState(() => _incomingCaptureId = null);
      return;
    }
    if (capture.status == CaptureStatus.analyzing) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('이미지를 정리하고 있어요. 잠시만 기다려 주세요.')),
        );
      return;
    }

    setState(() => _incomingCaptureId = null);
    _openCapture(capture);
  }

  void _openCapture(CaptureRecord capture) {
    if (capture.status == CaptureStatus.analyzing) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('이미지를 정리하고 있어요. 잠시만 기다려 주세요.')),
        );
      return;
    }
    if (capture.analysis?.structuredContent != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StructuredReviewScreen(
            controller: widget.controller,
            captureId: capture.raw.id,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisReviewScreen(
          controller: widget.controller,
          captureId: capture.raw.id,
        ),
      ),
    );
  }
}

final class _IncomingCaptureCard extends StatelessWidget {
  const _IncomingCaptureCard({
    required this.controller,
    required this.captureId,
    required this.onDismiss,
    required this.onOpen,
  });

  final AppController controller;
  final String captureId;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final capture = controller.captureById(captureId);
        if (capture == null) {
          return const SizedBox.shrink();
        }
        final state = _CaptureArrivalState.from(capture);

        return Material(
          color: AppTheme.surfaceRaised,
          elevation: 14,
          shadowColor: const Color(0x99000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: state.iconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: state.isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppTheme.primary,
                            ),
                          )
                        : Icon(state.icon, color: state.iconColor, size: 23),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.title,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 16,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.description,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: onDismiss,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _CaptureArrivalState {
  const _CaptureArrivalState({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.isLoading = false,
  });

  factory _CaptureArrivalState.from(CaptureRecord capture) {
    if (capture.status == CaptureStatus.sourceLimited &&
        capture.raw.attachments.isEmpty &&
        capture.normalized.completeness == MaterialCompleteness.linkOnly) {
      return const _CaptureArrivalState(
        title: '링크를 저장했어요',
        description: '게시물 내용은 전달되지 않았어요 · 스크린샷을 보내 주세요',
        icon: Icons.link_rounded,
        iconColor: AppTheme.caution,
        iconBackground: AppTheme.accentSoft,
      );
    }
    return switch (capture.status) {
      CaptureStatus.received => const _CaptureArrivalState(
        title: '캡처를 받았어요',
        description: '이미지 정리를 준비하고 있어요',
        icon: Icons.image_outlined,
        iconColor: AppTheme.primary,
        iconBackground: AppTheme.primarySoft,
      ),
      CaptureStatus.analyzing => const _CaptureArrivalState(
        title: '캡처를 받았어요',
        description: '이미지를 정리하고 있어요',
        icon: Icons.auto_awesome_rounded,
        iconColor: AppTheme.primary,
        iconBackground: AppTheme.primarySoft,
        isLoading: true,
      ),
      CaptureStatus.needsReview => const _CaptureArrivalState(
        title: '정리가 준비됐어요',
        description: '탭해서 내용을 확인해 주세요',
        icon: Icons.check_rounded,
        iconColor: AppTheme.positive,
        iconBackground: Color(0xFF15322D),
      ),
      CaptureStatus.organized => const _CaptureArrivalState(
        title: '정리를 완료했어요',
        description: '콘텐츠에 안전하게 보관했어요',
        icon: Icons.bookmark_added_rounded,
        iconColor: AppTheme.primary,
        iconBackground: AppTheme.primarySoft,
      ),
      CaptureStatus.sourceLimited ||
      CaptureStatus.failed => const _CaptureArrivalState(
        title: '내용을 확인해 주세요',
        description: '탭해서 결과를 살펴볼 수 있어요',
        icon: Icons.error_outline_rounded,
        iconColor: AppTheme.negative,
        iconBackground: Color(0xFF381D1E),
      ),
    };
  }

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool isLoading;
}

final class _SourceImageChoiceSheet extends StatelessWidget {
  const _SourceImageChoiceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppTheme.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_done_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Trun On에 안전하게 저장했어요',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            '갤러리의 원본도 남겨둘까요? 어떤 선택을 해도 Trun On 안의 복사본은 유지돼요.',
            style: TextStyle(color: AppTheme.muted, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('갤러리에 두기'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.negative),
              child: const Text('갤러리 원본 삭제'),
            ),
          ),
        ],
      ),
    );
  }
}
