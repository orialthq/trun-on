import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../common/product_ui.dart';

final class AnalysisReviewScreen extends StatefulWidget {
  const AnalysisReviewScreen({
    required this.controller,
    required this.captureId,
    super.key,
  });

  final AppController controller;
  final String captureId;

  @override
  State<AnalysisReviewScreen> createState() => _AnalysisReviewScreenState();
}

final class _AnalysisReviewScreenState extends State<AnalysisReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandController;
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  var _saving = false;

  CaptureRecord? get _capture =>
      widget.controller.captureById(widget.captureId);

  @override
  void initState() {
    super.initState();
    final mention = _capture?.primaryMention;
    _brandController = TextEditingController(text: mention?.brand.value ?? '');
    _nameController = TextEditingController(text: mention?.name.value ?? '');
    _categoryController = TextEditingController(
      text: mention?.category.value ?? '',
    );
    _amountController = TextEditingController(
      text: mention?.amount.value ?? '',
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    if (capture == null) {
      return const Scaffold(body: Center(child: Text('입력 원본을 찾지 못했어요.')));
    }
    final analysis = capture.analysis;
    final mention = capture.primaryMention;
    final platform = capture.normalized.urls.isEmpty
        ? SourcePlatform.textOnly
        : capture.normalized.urls.first.platform;

    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 확인'),
        backgroundColor: AppTheme.background,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
          children: [
            Text(
              '원본과 추출 결과를\n나란히 확인하세요',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '수정해도 원본과 자동 추출값은 덮어쓰지 않고 별도로 남겨요.',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            _OriginalMaterialCard(capture: capture, platform: platform),
            if (capture.normalized.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              InfoBanner(
                icon: Icons.info_outline,
                title: '자료 범위를 확인해주세요',
                body: capture.normalized.warnings.join(' '),
                background: const Color(0xFFFFF1D2),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: SectionTitle('추출된 제품 정보')),
                if (mention != null)
                  StatusPill.forConfidence(mention.overallConfidence),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '제품별 묶음에 영향을 주는 필드라 사용자가 확인해야 해요.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _AnalysisField(
              label: '브랜드',
              controller: _brandController,
              field: mention?.brand,
              requiredField: true,
            ),
            const SizedBox(height: 12),
            _AnalysisField(
              label: '제품명',
              controller: _nameController,
              field: mention?.name,
              requiredField: true,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AnalysisField(
                    label: '카테고리',
                    controller: _categoryController,
                    field: mention?.category,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AnalysisField(
                    label: '용량·규격',
                    controller: _amountController,
                    field: mention?.amount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const SectionTitle('콘텐츠에서 추출한 언급'),
            const SizedBox(height: 6),
            const Text(
              '효능 판정이 아니라 작성자가 실제로 표현한 문장만 보여줘요.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (analysis == null || analysis.statements.isEmpty)
              const _NoStatementsCard()
            else
              ...analysis.statements.map(
                (statement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StatementCard(statement: statement),
                ),
              ),
            const SizedBox(height: 18),
            const SectionTitle('광고·협찬 표시'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.campaign_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            disclosureLabel(
                              analysis?.disclosure ??
                                  DisclosureObservation.unknown,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '표시를 찾지 못한 경우에도 “광고 아님”으로 판단하지 않아요.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const InfoBanner(
              icon: Icons.merge_type,
              title: '확인한 뒤에만 제품별로 묶어요',
              body:
                  '브랜드·제품명·카테고리·용량이 모두 같은 기존 제품이 있으면 '
                  '그 묶음에 출처를 추가하고, 정보가 비어 있으면 새 묶음으로 보관해요.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _confirm,
                  child: Text(_saving ? '정리하는 중…' : '확인하고 제품별로 정리'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _keepUnresolved,
                      child: const Text('제품 특정 못함'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('나중에 확인'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.confirmAndOrganize(
        captureId: widget.captureId,
        identity: ConfirmedProductIdentity(
          brand: _brandController.text.trim(),
          name: _nameController.text.trim(),
          category: _categoryController.text.trim(),
          amount: _amountController.text.trim(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _keepUnresolved() async {
    setState(() => _saving = true);
    try {
      await widget.controller.keepUnresolved(widget.captureId);
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

final class _OriginalMaterialCard extends StatelessWidget {
  const _OriginalMaterialCard({required this.capture, required this.platform});

  final CaptureRecord capture;
  final SourcePlatform platform;

  @override
  Widget build(BuildContext context) {
    final firstUrl = capture.normalized.urls.isEmpty
        ? null
        : capture.normalized.urls.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sourcePlatformIcon(platform), color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sourcePlatformLabel(platform),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatCaptureTime(capture.raw.receivedAt),
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(
              capture.raw.rawText.isEmpty
                  ? '공유된 텍스트가 없어요.'
                  : capture.raw.rawText,
              style: const TextStyle(height: 1.55),
            ),
            if (firstUrl != null) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              const Text(
                '정규화된 URL',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                firstUrl.canonicalValue,
                style: const TextStyle(color: AppTheme.primary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _AnalysisField extends StatelessWidget {
  const _AnalysisField({
    required this.label,
    required this.controller,
    required this.field,
    this.requiredField = false,
  });

  final String label;
  final TextEditingController controller;
  final ExtractedField<String>? field;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final extractedField = field;
    final confidenceBand = extractedField?.confidenceBand;
    return TextFormField(
      key: ValueKey('analysis-field-$label'),
      controller: controller,
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label 입력이 필요해요.';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: extractedField == null || extractedField.value == null
            ? '원문에서 찾지 못함'
            : '자동 추출 · ${confidenceBandLabel(confidenceBand!)}',
        helperStyle: TextStyle(
          color: confidenceBand == ConfidenceBand.high
              ? const Color(0xFF176B4D)
              : const Color(0xFF8A5700),
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}

final class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.statement});

  final ContentStatement statement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEE9FA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statement.topic,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.format_quote, size: 18, color: AppTheme.muted),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '“${statement.originalExpression}”',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              '공유 텍스트에서 직접 확인',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NoStatementsCard extends StatelessWidget {
  const _NoStatementsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.notes_outlined, color: AppTheme.muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '캡처한 자료에서 정리할 수 있는 언급을 찾지 못했어요.',
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
