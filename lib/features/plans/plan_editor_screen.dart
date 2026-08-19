import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import 'plan_wizard_chrome.dart';

/// Trigger shape selected in the manual plan editor.
///
/// These cases map directly to a time condition, a location condition, or an
/// AND condition in the domain layer.
enum PlanDraftTriggerKind { time, location, timeAndLocation }

/// Recurrence choices supported by the baseline scheduler contract.
enum PlanDraftRecurrence { once, daily, weekly, onReentry }

/// Optional captured content that can be linked to a manually created plan.
final class PlanSourceOption {
  const PlanSourceOption({
    required this.captureId,
    required this.title,
    this.subtitle,
  }) : assert(captureId != ''),
       assert(title != '');

  final String captureId;
  final String title;
  final String? subtitle;
}

/// Validated output from [PlanEditorScreen].
///
/// A location remains a user-entered query here. The integration layer can
/// resolve it to coordinates before creating a schedulable domain plan.
final class PlanDraft {
  const PlanDraft({
    required this.title,
    required this.triggerKind,
    required this.recurrence,
    this.scheduledAt,
    this.locationQuery,
    this.sourceCaptureId,
  });

  final String title;
  final PlanDraftTriggerKind triggerKind;
  final PlanDraftRecurrence recurrence;
  final DateTime? scheduledAt;
  final String? locationQuery;
  final String? sourceCaptureId;
}

/// Manual plan creation flow.
///
/// Use [open] to receive a [PlanDraft] from navigation, or pass [onSave] and
/// set [popOnSave] to false when embedding the editor in another flow.
final class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    this.sources = const [],
    this.initialDraft,
    this.onSave,
    this.popOnSave = true,
    super.key,
  });

  final List<PlanSourceOption> sources;
  final PlanDraft? initialDraft;
  final ValueChanged<PlanDraft>? onSave;
  final bool popOnSave;

  static Future<PlanDraft?> open(
    BuildContext context, {
    List<PlanSourceOption> sources = const [],
    PlanDraft? initialDraft,
  }) {
    return Navigator.of(context).push<PlanDraft>(
      MaterialPageRoute<PlanDraft>(
        builder: (_) =>
            PlanEditorScreen(sources: sources, initialDraft: initialDraft),
      ),
    );
  }

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

final class _PlanEditorScreenState extends State<PlanEditorScreen> {
  static const _noSourceValue = '';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late PlanDraftTriggerKind _triggerKind;
  late PlanDraftRecurrence _recurrence;
  late DateTime _scheduledAt;
  late String _sourceValue;

  bool get _usesTime =>
      _triggerKind == PlanDraftTriggerKind.time ||
      _triggerKind == PlanDraftTriggerKind.timeAndLocation;

  bool get _usesLocation =>
      _triggerKind == PlanDraftTriggerKind.location ||
      _triggerKind == PlanDraftTriggerKind.timeAndLocation;

  List<PlanDraftRecurrence> get _availableRecurrences {
    if (_triggerKind == PlanDraftTriggerKind.location) {
      return const [PlanDraftRecurrence.once, PlanDraftRecurrence.onReentry];
    }
    if (_triggerKind == PlanDraftTriggerKind.time) {
      return const [
        PlanDraftRecurrence.once,
        PlanDraftRecurrence.daily,
        PlanDraftRecurrence.weekly,
      ];
    }
    return PlanDraftRecurrence.values;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDraft;
    final defaultSchedule = DateTime.now().add(const Duration(hours: 1));
    _titleController = TextEditingController(text: initial?.title ?? '');
    _locationController = TextEditingController(
      text: initial?.locationQuery ?? '',
    );
    _triggerKind = initial?.triggerKind ?? PlanDraftTriggerKind.time;
    _recurrence = initial?.recurrence ?? PlanDraftRecurrence.once;
    if (!_availableRecurrences.contains(_recurrence)) {
      _recurrence = PlanDraftRecurrence.once;
    }
    final initialSchedule = initial?.scheduledAt ?? defaultSchedule;
    _scheduledAt = DateTime(
      initialSchedule.year,
      initialSchedule.month,
      initialSchedule.day,
      initialSchedule.hour,
      initialSchedule.minute,
    );
    final requestedSource = initial?.sourceCaptureId;
    _sourceValue =
        requestedSource != null &&
            widget.sources.any((source) => source.captureId == requestedSource)
        ? requestedSource
        : _noSourceValue;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.plansTheme(Theme.of(context)),
      child: Builder(
        builder: (planContext) => Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(widget.initialDraft == null ? '계획 만들기' : '계획 수정'),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Form(
              key: _formKey,
              child: ListView(
                key: const Key('plan-editor-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
                children: [
                  if (widget.initialDraft == null) ...[
                    const PlanWizardSteps(activeStep: 1),
                    const SizedBox(height: 4),
                  ],
                  const _EditorIntroduction(),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: '무엇을 기억할까요?',
                    description: '알림에서 바로 알아볼 수 있게 적어 주세요.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('plan-title-field'),
                    controller: _titleController,
                    autofocus: false,
                    textInputAction: TextInputAction.next,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: '계획 제목',
                      hintText: '예: 성수에서 저장한 식당 가보기',
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '계획 제목을 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: '언제 알려드릴까요?',
                    description: '시간, 장소 또는 두 조건을 함께 고를 수 있어요.',
                  ),
                  const SizedBox(height: 12),
                  for (final kind in PlanDraftTriggerKind.values) ...[
                    _TriggerOption(
                      kind: kind,
                      selected: _triggerKind == kind,
                      onTap: () => _selectTriggerKind(kind),
                    ),
                    if (kind != PlanDraftTriggerKind.values.last)
                      const SizedBox(height: 8),
                  ],
                  if (_usesTime) ...[
                    const SizedBox(height: 20),
                    _PickerField(
                      key: const Key('plan-date-picker'),
                      icon: Icons.calendar_today_rounded,
                      label: '날짜',
                      value: _formatDate(_scheduledAt),
                      onTap: () => _pickDate(planContext),
                    ),
                    const SizedBox(height: 10),
                    _PickerField(
                      key: const Key('plan-time-picker'),
                      icon: Icons.schedule_rounded,
                      label: '시간',
                      value: _formatTime(planContext, _scheduledAt),
                      onTap: () => _pickTime(planContext),
                    ),
                  ],
                  if (_usesLocation) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('plan-location-field'),
                      controller: _locationController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '장소 이름 또는 주소',
                        hintText: '예: 성수역, 서울숲길 24',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        helperText: '저장할 때 정확한 위치를 한 번 확인해요.',
                      ),
                      validator: (value) {
                        if (_usesLocation &&
                            (value == null || value.trim().isEmpty)) {
                          return '알림을 받을 장소를 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: '반복',
                    description: '한 번 알린 뒤 다시 기다릴지 정해요.',
                  ),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: const Key('plan-recurrence-field'),
                    child: DropdownButtonFormField<PlanDraftRecurrence>(
                      key: ValueKey(
                        'plan-recurrence-${_triggerKind.name}-${_recurrence.name}',
                      ),
                      initialValue: _recurrence,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '반복 방식',
                        prefixIcon: Icon(Icons.repeat_rounded),
                      ),
                      items: [
                        for (final recurrence in _availableRecurrences)
                          DropdownMenuItem(
                            value: recurrence,
                            child: Text(_recurrenceLabel(recurrence)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _recurrence = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: '콘텐츠 연결',
                    description: '계획을 만든 이유가 된 캡처를 함께 열 수 있어요.',
                  ),
                  const SizedBox(height: 12),
                  if (widget.sources.isEmpty)
                    const _NoSourceNotice()
                  else ...[
                    DropdownButtonFormField<String>(
                      key: const Key('plan-source-field'),
                      initialValue: _sourceValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '연결할 콘텐츠 (선택)',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _noSourceValue,
                          child: Text('연결 안 함'),
                        ),
                        for (final source in widget.sources)
                          DropdownMenuItem(
                            value: source.captureId,
                            child: Text(
                              source.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sourceValue = value);
                      },
                    ),
                    if (_selectedSource case final selected?) ...[
                      const SizedBox(height: 8),
                      _SelectedSourceDetail(source: selected),
                    ],
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.planSurface,
              border: Border(top: BorderSide(color: AppTheme.planBorder)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('plan-editor-save'),
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded, size: 19),
                  label: Text(widget.initialDraft == null ? '계획 저장' : '변경 저장'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PlanSourceOption? get _selectedSource {
    if (_sourceValue == _noSourceValue) return null;
    for (final source in widget.sources) {
      if (source.captureId == _sourceValue) return source;
    }
    return null;
  }

  void _selectTriggerKind(PlanDraftTriggerKind kind) {
    if (kind == _triggerKind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _triggerKind = kind;
      if (!_availableRecurrences.contains(_recurrence)) {
        _recurrence = PlanDraftRecurrence.once;
      }
    });
  }

  Future<void> _pickDate(BuildContext pickerContext) async {
    FocusScope.of(pickerContext).unfocus();
    final today = DateUtils.dateOnly(DateTime.now());
    final current = DateUtils.dateOnly(_scheduledAt);
    final selected = await showDatePicker(
      context: pickerContext,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
      helpText: '계획 날짜',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime(BuildContext pickerContext) async {
    FocusScope.of(pickerContext).unfocus();
    final selected = await showTimePicker(
      context: pickerContext,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
      helpText: '계획 시간',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    final draft = PlanDraft(
      title: _titleController.text.trim(),
      triggerKind: _triggerKind,
      recurrence: _recurrence,
      scheduledAt: _usesTime ? _scheduledAt : null,
      locationQuery: _usesLocation ? _locationController.text.trim() : null,
      sourceCaptureId: _sourceValue == _noSourceValue ? null : _sourceValue,
    );
    widget.onSave?.call(draft);
    if (widget.popOnSave) Navigator.of(context).pop(draft);
  }

  static String _formatDate(DateTime value) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${value.year}. ${value.month}. ${value.day}. '
        '(${weekdays[value.weekday - 1]})';
  }

  static String _formatTime(BuildContext context, DateTime value) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value));
  }

  static String _recurrenceLabel(PlanDraftRecurrence recurrence) {
    return switch (recurrence) {
      PlanDraftRecurrence.once => '한 번만',
      PlanDraftRecurrence.daily => '매일',
      PlanDraftRecurrence.weekly => '매주',
      PlanDraftRecurrence.onReentry => '장소를 다시 방문할 때',
    };
  }
}

final class _EditorIntroduction extends StatelessWidget {
  const _EditorIntroduction();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.planMauveSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.planMauve,
              size: 21,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '시간이나 장소가 맞으면 저장해 둔 정보를 다시 꺼내 드릴게요.',
                style: TextStyle(
                  color: AppTheme.planInk,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: AppTheme.planMuted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

final class _TriggerOption extends StatelessWidget {
  const _TriggerOption({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final PlanDraftTriggerKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = _TriggerDetails.from(kind);
    return Material(
      key: Key('plan-trigger-${kind.name}'),
      color: selected ? AppTheme.planMauveSoft : AppTheme.planSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: selected ? AppTheme.planMauve : AppTheme.planBorder,
          width: selected ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          label: '${details.title}, ${details.description}',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.planSurface
                          : AppTheme.planCanvas,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      details.icon,
                      color: selected ? AppTheme.planMauve : AppTheme.planMuted,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          details.title,
                          style: TextStyle(
                            color: AppTheme.planInk,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details.description,
                          style: const TextStyle(
                            color: AppTheme.planMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? AppTheme.planMauve : AppTheme.planSubtle,
                    size: 21,
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

final class _TriggerDetails {
  const _TriggerDetails({
    required this.title,
    required this.description,
    required this.icon,
  });

  factory _TriggerDetails.from(PlanDraftTriggerKind kind) {
    return switch (kind) {
      PlanDraftTriggerKind.time => const _TriggerDetails(
        title: '시간',
        description: '정한 날짜와 시간에 알려드려요.',
        icon: Icons.schedule_rounded,
      ),
      PlanDraftTriggerKind.location => const _TriggerDetails(
        title: '장소',
        description: '선택한 장소에 도착하면 알려드려요.',
        icon: Icons.location_on_rounded,
      ),
      PlanDraftTriggerKind.timeAndLocation => const _TriggerDetails(
        title: '시간 + 장소',
        description: '정한 시간 이후 그 장소에 도착하면 알려드려요.',
        icon: Icons.share_location_rounded,
      ),
    };
  }

  final String title;
  final String description;
  final IconData icon;
}

final class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.planSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.planBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '$label, $value',
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(icon, color: AppTheme.planMauve, size: 21),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: AppTheme.planSubtle,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: const TextStyle(
                              color: AppTheme.planInk,
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.planSubtle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _NoSourceNotice extends StatelessWidget {
  const _NoSourceNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('plan-no-source-notice'),
      decoration: BoxDecoration(
        color: AppTheme.planSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.planBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.link_off_rounded, color: AppTheme.planSubtle, size: 20),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                '연결할 콘텐츠가 없어도 계획은 만들 수 있어요.',
                style: TextStyle(
                  color: AppTheme.planMuted,
                  fontSize: 13,
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

final class _SelectedSourceDetail extends StatelessWidget {
  const _SelectedSourceDetail({required this.source});

  final PlanSourceOption source;

  @override
  Widget build(BuildContext context) {
    final subtitle = source.subtitle;
    if (subtitle == null || subtitle.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.subdirectory_arrow_right,
            color: AppTheme.planSubtle,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.planSubtle,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
