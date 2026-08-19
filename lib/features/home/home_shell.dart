import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/external_app_navigation_service.dart';
import '../../data/incoming_share_service.dart';
import '../../data/place_reminder_service.dart';
import '../../data/trigger_plan_store.dart';
import '../../domain/models.dart';
import '../../domain/trigger_models.dart';
import '../../state/app_controller.dart';
import '../../state/plan_controller.dart';
import '../analysis/analysis_review_screen.dart';
import '../analysis/structured_review_screen.dart';
import '../common/content_folder_ui.dart';
import '../inbox/inbox_screen.dart';
import '../plans/plan_editor_screen.dart';
import '../plans/plans_screen.dart';
import '../products/products_screen.dart';
import '../sharing/received_tip_sheet.dart';
import 'trun_home_screen.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.controller,
    this.planController,
    this.placeReminderOpenInbox,
    super.key,
  });

  final AppController controller;
  final PlanController? planController;
  final PlaceReminderOpenInbox? placeReminderOpenInbox;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver {
  static const _exitConfirmationWindow = Duration(seconds: 2);

  var _selectedIndex = 0;
  String? _incomingCaptureId;
  var _exitArmed = false;
  var _canReturnToSourceApp = false;
  var _returningToSourceApp = false;
  var _planOpenInFlight = false;
  Timer? _exitConfirmationTimer;
  late StreamSubscription<String> _incomingCaptureSubscription;
  late StreamSubscription<String> _portableTipSubscription;
  late StreamSubscription<String> _placeReminderOpenSubscription;
  late final PlaceReminderOpenInbox _placeReminderOpenInbox;
  late final bool _ownsPlaceReminderOpenInbox;
  final Set<String> _activePlaceReminderOpenIds = {};
  Future<void> _sourceChoiceTail = Future<void>.value();
  Future<void> _portableTipChoiceTail = Future<void>.value();
  Future<void> _placeReminderOpenTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsPlaceReminderOpenInbox = widget.placeReminderOpenInbox == null;
    _placeReminderOpenInbox =
        widget.placeReminderOpenInbox ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? MethodChannelPlaceReminderOpenInbox()
            : InMemoryPlaceReminderOpenInbox());
    _listenForIncomingCaptures();
    _listenForPortableTips();
    _placeReminderOpenSubscription = _placeReminderOpenInbox.opened.listen(
      _queuePlaceReminderOpen,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_drainPendingPlaceReminderOpens());
    });
    widget.planController?.addListener(_handlePlanControllerChanged);
    if (widget.planController != null) {
      unawaited(_initializePlans());
    }
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      unawaited(_incomingCaptureSubscription.cancel());
      unawaited(_portableTipSubscription.cancel());
      _listenForIncomingCaptures();
      _listenForPortableTips();
    }
    if (oldWidget.planController != widget.planController) {
      oldWidget.planController?.removeListener(_handlePlanControllerChanged);
      widget.planController?.addListener(_handlePlanControllerChanged);
      if (widget.planController != null) {
        unawaited(_initializePlans());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final controller = widget.planController;
    if (controller == null) return;
    if (controller.isInitialized) {
      unawaited(controller.refreshScheduling());
    } else {
      unawaited(_initializePlans());
    }
  }

  Future<void> _initializePlans() async {
    final controller = widget.planController;
    if (controller == null) return;
    try {
      await controller.initialize();
      if (!mounted || controller != widget.planController) return;
      setState(() {});
      _queuePendingPlanOpen();
    } catch (error, stackTrace) {
      debugPrint('Plan initialization failed: $error\n$stackTrace');
      if (mounted) _showMessage('계획을 불러오지 못했어요.');
    }
  }

  void _handlePlanControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _queuePendingPlanOpen();
  }

  void _queuePendingPlanOpen() {
    final controller = widget.planController;
    if (controller?.pendingOpen == null || _planOpenInFlight) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_routePendingPlanOpen());
    });
  }

  Future<void> _routePendingPlanOpen() async {
    final planController = widget.planController;
    if (planController == null ||
        planController.pendingOpen == null ||
        _planOpenInFlight) {
      return;
    }
    _planOpenInFlight = true;
    try {
      await widget.controller.initialize();
      if (!mounted || planController != widget.planController) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final pendingOpen = planController.pendingOpen!;
      final planId = pendingOpen.ruleId;
      final captureId = planController.pendingSourceCaptureId;
      planController.consumePendingOpen();
      Navigator.of(context).popUntil((route) => route.isFirst);
      _exitConfirmationTimer?.cancel();
      final capture = captureId == null
          ? null
          : widget.controller.captureById(captureId);
      setState(() {
        _selectedIndex = capture == null ? 3 : 2;
        _exitArmed = false;
        _canReturnToSourceApp = false;
      });
      if (capture != null) {
        _openCapture(
          capture,
          planContext: _PlanCaptureOpenContext(
            planId: planId,
            origin: _PlanCaptureOpenOrigin.notification,
            nativeOpenEventId: pendingOpen.eventId,
          ),
        );
      } else if (captureId != null) {
        _showMessage('연결된 콘텐츠가 없어 계획함으로 이동했어요.');
      }
    } finally {
      _planOpenInFlight = false;
      _queuePendingPlanOpen();
    }
  }

  void _listenForPortableTips() {
    _portableTipSubscription = widget.controller.portableTipReceived.listen((
      transportId,
    ) {
      _portableTipChoiceTail = _portableTipChoiceTail.then(
        (_) => _showPortableTip(transportId),
      );
    });
  }

  Future<void> _drainPendingPlaceReminderOpens() async {
    final captureIds = await _placeReminderOpenInbox.pending();
    for (final captureId in captureIds) {
      _queuePlaceReminderOpen(captureId);
    }
  }

  void _queuePlaceReminderOpen(String captureId) {
    final normalized = captureId.trim();
    if (normalized.isEmpty || !_activePlaceReminderOpenIds.add(normalized)) {
      return;
    }
    _placeReminderOpenTail = _placeReminderOpenTail
        .then((_) => _routePlaceReminderOpen(normalized))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Place reminder navigation failed: $error\n$stackTrace');
        })
        .whenComplete(() => _activePlaceReminderOpenIds.remove(normalized));
  }

  Future<void> _routePlaceReminderOpen(String captureId) async {
    // initialize() is shared, so this waits for durable snapshot restoration
    // even when the notification cold-started the app before the first frame.
    await widget.controller.initialize();
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    final capture = widget.controller.captureById(captureId);
    setState(() {
      _selectedIndex = 2;
      _exitArmed = false;
      _canReturnToSourceApp = false;
    });
    _exitConfirmationTimer?.cancel();

    if (capture == null) {
      _showMessage('이미 삭제된 콘텐츠예요. 정리함으로 이동했어요.');
    } else {
      _openCapture(capture);
    }
    await _placeReminderOpenInbox.acknowledge([captureId]);
  }

  Future<void> _showPortableTip(String transportId) async {
    if (!mounted) return;
    final tip = widget.controller.pendingPortableTip(transportId);
    if (tip == null) return;
    final decision = await showReceivedTipSheet(context, tip);
    if (!mounted) return;
    if (decision == ReceivedTipDecision.discard) {
      await widget.controller.discardPortableTip(transportId);
      if (mounted) _showMessage('받은 팁을 저장하지 않았어요.');
      return;
    }
    final captureId = await widget.controller.acceptPortableTip(transportId);
    if (!mounted) return;
    if (captureId == null) {
      _showMessage('팁을 저장하지 못했어요. 다시 시도해 주세요.');
      return;
    }
    final capture = widget.controller.captureById(captureId);
    if (capture == null) return;
    setState(() {
      _selectedIndex = 2;
      _canReturnToSourceApp = true;
      _exitArmed = false;
    });
    _openCapture(capture);
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
              _exitArmed = false;
              _canReturnToSourceApp = true;
              _returningToSourceApp = false;
            });
            _exitConfirmationTimer?.cancel();
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
      isScrollControlled: true,
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

  bool get _handlesSystemBack =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _selectDestination(int index) {
    if (_selectedIndex == index) {
      if (_exitArmed) {
        _exitConfirmationTimer?.cancel();
        setState(() => _exitArmed = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      return;
    }
    setState(() {
      _selectedIndex = index;
      _exitArmed = false;
    });
    _exitConfirmationTimer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  Future<void> _handleSystemBack() async {
    if (_selectedIndex != 0) {
      _exitConfirmationTimer?.cancel();
      setState(() {
        _selectedIndex = 0;
        _exitArmed = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return;
    }

    if (_canReturnToSourceApp) {
      if (_returningToSourceApp) return;
      setState(() => _returningToSourceApp = true);
      final returned = await const ExternalAppNavigationService()
          .returnToPreviousApp();
      if (!mounted) return;
      setState(() {
        _canReturnToSourceApp = false;
        _returningToSourceApp = false;
      });
      if (returned) return;
    }

    _exitConfirmationTimer?.cancel();
    setState(() => _exitArmed = true);
    _exitConfirmationTimer = Timer(_exitConfirmationWindow, () {
      if (mounted) {
        setState(() => _exitArmed = false);
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('한 번 더 누르면 앱을 종료해요.'),
          duration: _exitConfirmationWindow,
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.planController?.removeListener(_handlePlanControllerChanged);
    _exitConfirmationTimer?.cancel();
    unawaited(_incomingCaptureSubscription.cancel());
    unawaited(_portableTipSubscription.cancel());
    unawaited(_placeReminderOpenSubscription.cancel());
    if (_ownsPlaceReminderOpenInbox) {
      unawaited(_placeReminderOpenInbox.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planController = widget.planController;
    final screens = <Widget>[
      TrunHomeScreen(
        controller: widget.controller,
        onAdd: () => InboxScreen.openManualInput(context, widget.controller),
        onOpenInbox: () => _selectDestination(1),
        onOpenLibrary: () => _selectDestination(2),
        onOpenCapture: _openCapture,
      ),
      InboxScreen(controller: widget.controller),
      ProductsScreen(controller: widget.controller),
      if (planController != null)
        PlansScreen(
          plans: planController.isInitialized
              ? _planItems(planController)
              : const <PlanListItem>[],
          onCreatePlan: _openPlanEditor,
          onOpenPlan: _openPlanActions,
        ),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: '홈',
      ),
      const NavigationDestination(
        icon: Icon(Icons.inbox_outlined),
        selectedIcon: Icon(Icons.inbox),
        label: '콘텐츠',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bookmark_border_rounded),
        selectedIcon: Icon(Icons.bookmark_rounded),
        label: '정리함',
      ),
      if (planController != null)
        const NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: '계획함',
        ),
    ];
    final showingPlans = planController != null && _selectedIndex == 3;
    final navigationBackground = showingPlans
        ? AppTheme.planSurface
        : AppTheme.surface;
    final navigationBorder = showingPlans
        ? AppTheme.planBorder
        : AppTheme.border;
    final navigationIndicator = showingPlans
        ? AppTheme.planMauveSoft
        : AppTheme.primarySoft;
    final navigationSelected = showingPlans
        ? AppTheme.planMauve
        : AppTheme.primary;
    final navigationUnselected = showingPlans
        ? AppTheme.planSubtle
        : AppTheme.subtle;
    final systemUiStyle = showingPlans
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: AppTheme.planSurface,
            systemNavigationBarDividerColor: AppTheme.planSurface,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: AppTheme.background,
            systemNavigationBarDividerColor: AppTheme.background,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: PopScope<void>(
        canPop: !_handlesSystemBack || _exitArmed,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _handlesSystemBack) {
            unawaited(_handleSystemBack());
          }
        },
        child: Scaffold(
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
            decoration: BoxDecoration(
              color: navigationBackground,
              border: Border(top: BorderSide(color: navigationBorder)),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: navigationBackground,
                elevation: 0,
                height: 72,
                indicatorColor: navigationIndicator,
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected ? navigationSelected : navigationUnselected,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    color: selected ? navigationSelected : navigationUnselected,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectDestination,
                destinations: destinations,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PlanListItem> _planItems(PlanController controller) {
    return controller.items
        .map((item) {
          final plan = controller.planById(item.id);
          final sourceId = plan?.metadata['sourceCaptureId'];
          final capture = sourceId is String
              ? widget.controller.captureById(sourceId)
              : null;
          return PlanListItem(
            id: item.id,
            title: item.title,
            status: item.status,
            triggerLabel: item.triggerLabel,
            recurrenceLabel: item.recurrenceLabel,
            sourceLabel: capture == null
                ? item.sourceLabel
                : _captureTitle(capture),
          );
        })
        .toList(growable: false);
  }

  List<PlanSourceOption> _planSources() {
    return widget.controller.captures.reversed
        .map(
          (capture) => PlanSourceOption(
            captureId: capture.raw.id,
            title: _captureTitle(capture),
            subtitle: capture.contentFolder.label,
          ),
        )
        .toList(growable: false);
  }

  String _captureTitle(CaptureRecord capture) {
    final structured = capture.analysis?.structuredContent?.title.value?.trim();
    if (structured != null && structured.isNotEmpty) return structured;

    final mention = capture.primaryMention?.name.value?.trim();
    if (mention != null && mention.isNotEmpty) return mention;

    final normalized = capture.normalized.normalizedText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isNotEmpty) {
      return normalized.length <= 42
          ? normalized
          : '${normalized.substring(0, 42).trimRight()}…';
    }
    return '${capture.contentFolder.label} 콘텐츠';
  }

  Future<void> _openPlanEditor() async {
    final controller = widget.planController;
    if (controller == null) return;
    if (!controller.isInitialized) {
      await _initializePlans();
      if (!mounted || !controller.isInitialized) return;
    }

    final draft = await PlanEditorScreen.open(context, sources: _planSources());
    if (!mounted || draft == null) return;

    final usesLocation = draft.triggerKind != PlanDraftTriggerKind.time;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    var notificationGranted = true;
    if (isAndroid) {
      const reminderService = PlaceReminderService();
      notificationGranted = await reminderService
          .requestNotificationPermission();
      if (usesLocation) {
        await reminderService.requestForegroundPermission();
      }
      if (!mounted) return;
    }

    try {
      final plan = await controller.create(draft);
      if (!mounted) return;
      setState(() => _selectedIndex = 3);

      if (isAndroid && usesLocation) {
        final permissionState = await const PlaceReminderService().getState(
          plan.id,
        );
        if (!mounted) return;
        if (!permissionState.foregroundGranted ||
            !permissionState.backgroundGranted) {
          await _showLocationPermissionGuide(permissionState);
        }
      }
      if (!mounted) return;
      if (!notificationGranted) {
        _showMessage('계획은 저장했어요. 알림 권한을 켜면 제때 알려드릴게요.');
      } else if (controller.lastError != null) {
        _showMessage('계획은 저장했지만 알림 설정을 마치지 못했어요.');
        controller.clearLastError();
      } else {
        _showMessage('계획을 저장했어요. 조건이 맞으면 알려드릴게요.');
      }
    } on PlanLocationResolutionException {
      if (mounted) {
        _showMessage('장소를 찾지 못했어요. 주소를 조금 더 정확히 입력해 주세요.');
      }
    } catch (error, stackTrace) {
      debugPrint('Plan creation failed: $error\n$stackTrace');
      if (mounted) _showMessage('계획을 저장하지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<void> _showLocationPermissionGuide(PlaceReminderState state) async {
    final needsForeground = !state.foregroundGranted;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.plansTheme(Theme.of(dialogContext)),
        child: AlertDialog(
          backgroundColor: AppTheme.planSurface,
          surfaceTintColor: Colors.transparent,
          title: Text(needsForeground ? '위치 허용이 필요해요' : '항상 허용으로 바꿔 주세요'),
          content: Text(
            needsForeground
                ? '장소에 도착했을 때 알려드리려면 위치를 허용해 주세요. 계획은 안전하게 저장해 뒀어요.'
                : '앱을 닫아도 알려드리려면 위치 권한을 ${state.backgroundPermissionLabel}으로 바꿔 주세요. 계획은 저장해 뒀어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('설정 열기'),
            ),
          ],
        ),
      ),
    );
    if (openSettings == true && mounted) {
      await const PlaceReminderService().openBackgroundLocationSettings();
    }
  }

  Future<void> _openPlanActions(PlanListItem item) async {
    final controller = widget.planController;
    final plan = controller?.planById(item.id);
    if (controller == null || plan == null) return;

    final sourceId = plan.metadata['sourceCaptureId'];
    final hasSource = sourceId is String && sourceId.trim().isNotEmpty;
    final action = await showModalBottomSheet<_PlanMenuAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.planSurface,
      builder: (sheetContext) => Theme(
        data: AppTheme.plansTheme(Theme.of(sheetContext)),
        child: _PlanActionsSheet(plan: plan, hasSource: hasSource),
      ),
    );
    if (!mounted || action == null) return;

    try {
      switch (action) {
        case _PlanMenuAction.openSource:
          final capture = sourceId is String
              ? widget.controller.captureById(sourceId)
              : null;
          if (capture == null) {
            _showMessage('연결된 콘텐츠를 찾지 못했어요.');
          } else {
            setState(() => _selectedIndex = 2);
            _openCapture(
              capture,
              planContext: _PlanCaptureOpenContext(
                planId: plan.id,
                origin: _PlanCaptureOpenOrigin.planActions,
              ),
            );
          }
        case _PlanMenuAction.pause:
          await controller.pause(plan.id);
          if (mounted) _showMessage('계획을 잠시 멈췄어요.');
        case _PlanMenuAction.resume:
          await controller.resume(plan.id);
          if (mounted) _showMessage('계획을 다시 시작했어요.');
        case _PlanMenuAction.snooze:
          await controller.snooze(plan.id, delay: const Duration(minutes: 30));
          if (mounted) _showMessage('30분 뒤에 다시 알려드릴게요.');
        case _PlanMenuAction.complete:
          await controller.complete(plan.id);
          if (mounted) _showMessage('완료한 계획으로 옮겼어요.');
        case _PlanMenuAction.notInterested:
          await controller.recordInteraction(
            plan.id,
            TriggerPlanEventKind.notInterested,
            const <String, Object?>{'source': 'plan_actions'},
          );
          await controller.pause(plan.id);
          if (mounted) _showMessage('이런 알림은 그만 보낼게요.');
        case _PlanMenuAction.visitResult:
          final result = await _showVisitResultSheet(plan);
          if (result == null) return;
          await controller.recordInteraction(
            plan.id,
            result.eventKind,
            const <String, Object?>{'source': 'plan_actions_visit_result'},
          );
          if (mounted) _showMessage('방문 결과를 남겼어요.');
        case _PlanMenuAction.delete:
          final confirmed = await _confirmPlanDelete(plan.title);
          if (confirmed == true) {
            await controller.delete(plan.id);
            if (mounted) _showMessage('계획을 삭제했어요.');
          }
      }
    } catch (error, stackTrace) {
      debugPrint('Plan action failed: $error\n$stackTrace');
      if (mounted) _showMessage('처리하지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<_VisitResult?> _showVisitResultSheet(Plan plan) {
    return showModalBottomSheet<_VisitResult>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.planSurface,
      builder: (sheetContext) => Theme(
        data: AppTheme.plansTheme(Theme.of(sheetContext)),
        child: _VisitResultSheet(planTitle: plan.title),
      ),
    );
  }

  Future<bool?> _confirmPlanDelete(String title) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.plansTheme(Theme.of(dialogContext)),
        child: AlertDialog(
          backgroundColor: AppTheme.planSurface,
          surfaceTintColor: Colors.transparent,
          title: const Text('이 계획을 삭제할까요?'),
          content: Text('“$title” 알림과 기록이 함께 삭제돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.planNegative,
              ),
              child: const Text('삭제'),
            ),
          ],
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

  void _openCapture(
    CaptureRecord capture, {
    _PlanCaptureOpenContext? planContext,
  }) {
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
            planId: planContext?.planId,
            onMapOpened: planContext == null
                ? null
                : ({required provider, required captureId, planId}) async {
                    final controller = widget.planController;
                    if (controller == null || planId == null) return;
                    await controller.recordInteraction(
                      planId,
                      TriggerPlanEventKind.mapOpened,
                      <String, Object?>{
                        'provider': provider.id,
                        'captureId': captureId,
                        'planId': planId,
                        'source': planContext.origin.analyticsSource,
                        if (planContext.nativeOpenEventId != null)
                          'nativeOpenEventId': planContext.nativeOpenEventId!,
                      },
                    );
                  },
          ),
        ),
      );
      if (planContext != null) {
        unawaited(_recordSourceOpened(capture, planContext));
      }
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
    if (planContext != null) {
      unawaited(_recordSourceOpened(capture, planContext));
    }
  }

  Future<void> _recordSourceOpened(
    CaptureRecord capture,
    _PlanCaptureOpenContext planContext,
  ) async {
    final metadata = <String, Object?>{
      'captureId': capture.raw.id,
      'planId': planContext.planId,
      'source': planContext.origin.analyticsSource,
      if (planContext.nativeOpenEventId != null)
        'nativeOpenEventId': planContext.nativeOpenEventId!,
    };
    final controller = widget.planController;
    if (controller == null) return;
    await _recordPlanInteraction(
      controller,
      planContext.planId,
      TriggerPlanEventKind.sourceOpened,
      metadata,
    );
  }

  Future<void> _recordPlanInteraction(
    PlanController controller,
    String planId,
    TriggerPlanEventKind kind,
    Map<String, Object?> metadata,
  ) async {
    try {
      await controller.recordInteraction(planId, kind, metadata);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Plan interaction recording failed '
        '(${kind.name}, $planId): $error\n$stackTrace',
      );
    }
  }
}

enum _PlanMenuAction {
  openSource,
  pause,
  resume,
  snooze,
  complete,
  notInterested,
  visitResult,
  delete,
}

enum _PlanCaptureOpenOrigin {
  notification('notification'),
  planActions('plan_actions');

  const _PlanCaptureOpenOrigin(this.analyticsSource);

  final String analyticsSource;
}

final class _PlanCaptureOpenContext {
  const _PlanCaptureOpenContext({
    required this.planId,
    required this.origin,
    this.nativeOpenEventId,
  });

  final String planId;
  final _PlanCaptureOpenOrigin origin;
  final String? nativeOpenEventId;
}

enum _VisitResult {
  confirmed(TriggerPlanEventKind.visitConfirmed),
  didNotVisit(TriggerPlanEventKind.didNotVisit),
  unknown(TriggerPlanEventKind.visitUnknown);

  const _VisitResult(this.eventKind);

  final TriggerPlanEventKind eventKind;
}

final class _PlanActionsSheet extends StatelessWidget {
  const _PlanActionsSheet({required this.plan, required this.hasSource});

  final Plan plan;
  final bool hasSource;

  bool get _canPause =>
      plan.lifecycle == PlanLifecycle.active ||
      plan.lifecycle == PlanLifecycle.fired;

  bool get _canResume =>
      plan.lifecycle == PlanLifecycle.paused ||
      plan.lifecycle == PlanLifecycle.draft;

  bool get _canSnooze =>
      plan.lifecycle != PlanLifecycle.completed &&
      plan.lifecycle != PlanLifecycle.expired;

  bool get _canComplete =>
      plan.lifecycle != PlanLifecycle.completed &&
      plan.lifecycle != PlanLifecycle.expired;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(bottom: AppTheme.bottomSheetSafeInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            const Text(
              '계획을 관리하거나 연결된 내용을 다시 볼 수 있어요.',
              style: TextStyle(
                color: AppTheme.planMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.planCanvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.planBorder),
              ),
              child: Column(
                children: [
                  if (hasSource)
                    _PlanActionTile(
                      icon: Icons.article_outlined,
                      label: '연결된 콘텐츠 보기',
                      onTap: () =>
                          Navigator.pop(context, _PlanMenuAction.openSource),
                    ),
                  _PlanActionTile(
                    icon: Icons.how_to_reg_outlined,
                    label: '방문 결과 남기기',
                    onTap: () =>
                        Navigator.pop(context, _PlanMenuAction.visitResult),
                  ),
                  if (_canPause)
                    _PlanActionTile(
                      icon: Icons.pause_circle_outline_rounded,
                      label: '잠시 멈추기',
                      onTap: () =>
                          Navigator.pop(context, _PlanMenuAction.pause),
                    ),
                  if (_canResume)
                    _PlanActionTile(
                      icon: Icons.play_circle_outline_rounded,
                      label: '다시 시작하기',
                      onTap: () =>
                          Navigator.pop(context, _PlanMenuAction.resume),
                    ),
                  if (_canSnooze)
                    _PlanActionTile(
                      icon: Icons.snooze_rounded,
                      label: '30분 뒤에 다시 알리기',
                      onTap: () =>
                          Navigator.pop(context, _PlanMenuAction.snooze),
                    ),
                  if (_canComplete)
                    _PlanActionTile(
                      icon: Icons.check_circle_outline_rounded,
                      label: '완료로 표시',
                      onTap: () =>
                          Navigator.pop(context, _PlanMenuAction.complete),
                    ),
                  if (_canSnooze)
                    _PlanActionTile(
                      icon: Icons.notifications_off_outlined,
                      label: '이런 알림 그만 받기',
                      destructive: true,
                      onTap: () =>
                          Navigator.pop(context, _PlanMenuAction.notInterested),
                    ),
                  _PlanActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: '계획 삭제',
                    destructive: true,
                    showDivider: false,
                    onTap: () => Navigator.pop(context, _PlanMenuAction.delete),
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

final class _VisitResultSheet extends StatelessWidget {
  const _VisitResultSheet({required this.planTitle});

  final String planTitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(bottom: AppTheme.bottomSheetSafeInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('방문 결과', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              '“$planTitle”에 대한 결과를 알려 주세요.',
              style: const TextStyle(
                color: AppTheme.planMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.planCanvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.planBorder),
              ),
              child: Column(
                children: [
                  _PlanActionTile(
                    icon: Icons.check_circle_outline_rounded,
                    label: '다녀왔어요',
                    onTap: () => Navigator.pop(context, _VisitResult.confirmed),
                  ),
                  _PlanActionTile(
                    icon: Icons.cancel_outlined,
                    label: '안 갔어요',
                    onTap: () =>
                        Navigator.pop(context, _VisitResult.didNotVisit),
                  ),
                  _PlanActionTile(
                    icon: Icons.help_outline_rounded,
                    label: '아직 몰라요',
                    showDivider: false,
                    onTap: () => Navigator.pop(context, _VisitResult.unknown),
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

final class _PlanActionTile extends StatelessWidget {
  const _PlanActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.planNegative : AppTheme.planInk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          type: MaterialType.transparency,
          child: ListTile(
            minTileHeight: 54,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Icon(icon, color: color, size: 21),
            title: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.planSubtle,
              size: 20,
            ),
            onTap: onTap,
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 50, color: AppTheme.planBorder),
      ],
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
    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(bottom: AppTheme.bottomSheetSafeInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              child: ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppTheme.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_done_rounded,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Trun On에 안전하게 저장했어요',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              '갤러리의 원본도 남겨둘까요? 어떤 선택을 해도 Trun On 안의 복사본은 유지돼요.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('갤러리에 두기'),
              ),
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }
}
