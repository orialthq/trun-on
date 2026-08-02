import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';

const defaultContentFolders = <ContentFolder>[
  ContentFolder.beauty,
  ContentFolder.healthFitness,
  ContentFolder.restaurantCafe,
  ContentFolder.recipe,
  ContentFolder.shopping,
  ContentFolder.travelPlace,
  ContentFolder.lifeTip,
  ContentFolder.other,
];

const contentFolderPickerItems = <ContentFolder>[
  ...defaultContentFolders,
  ContentFolder.needsClassification,
];

extension ContentFolderUi on ContentFolder {
  String get label => switch (this) {
    ContentFolder.beauty => '뷰티',
    ContentFolder.healthFitness => '건강·운동',
    ContentFolder.restaurantCafe => '맛집·카페',
    ContentFolder.recipe => '레시피',
    ContentFolder.shopping => '쇼핑',
    ContentFolder.travelPlace => '여행·장소',
    ContentFolder.lifeTip => '생활·팁',
    ContentFolder.other => '기타',
    ContentFolder.needsClassification => '분류 필요',
  };

  String get description => switch (this) {
    ContentFolder.beauty => '화장품, 헤어·바디, 뷰티숍',
    ContentFolder.healthFitness => '영양제, 운동, 식단과 건강 루틴',
    ContentFolder.restaurantCafe => '식당, 카페와 방문할 메뉴',
    ContentFolder.recipe => '요리법, 소스와 조리 팁',
    ContentFolder.shopping => '패션, 가전과 구매 후보',
    ContentFolder.travelPlace => '숙소, 전시, 체험과 나들이',
    ContentFolder.lifeTip => '청소, 정리와 생활 정보',
    ContentFolder.other => '다른 폴더에 속하지 않는 내용',
    ContentFolder.needsClassification => '어울리는 폴더를 나중에 정해요',
  };

  IconData get icon => switch (this) {
    ContentFolder.beauty => Icons.spa_outlined,
    ContentFolder.healthFitness => Icons.favorite_border_rounded,
    ContentFolder.restaurantCafe => Icons.restaurant_outlined,
    ContentFolder.recipe => Icons.menu_book_outlined,
    ContentFolder.shopping => Icons.shopping_bag_outlined,
    ContentFolder.travelPlace => Icons.map_outlined,
    ContentFolder.lifeTip => Icons.lightbulb_outline_rounded,
    ContentFolder.other => Icons.folder_outlined,
    ContentFolder.needsClassification => Icons.help_outline_rounded,
  };

  Color get color => switch (this) {
    ContentFolder.beauty => const Color(0xFFB15BB6),
    ContentFolder.healthFitness => const Color(0xFF16A085),
    ContentFolder.restaurantCafe => const Color(0xFFE07832),
    ContentFolder.recipe => const Color(0xFFCF5B60),
    ContentFolder.shopping => const Color(0xFF3182F6),
    ContentFolder.travelPlace => const Color(0xFF4F72C9),
    ContentFolder.lifeTip => const Color(0xFF9A7425),
    ContentFolder.other => const Color(0xFF6B7684),
    ContentFolder.needsClassification => const Color(0xFFB26A00),
  };

  Color get softColor =>
      Color.alphaBlend(color.withValues(alpha: 0.11), Colors.white);
}

final class ContentFolderPicker extends StatelessWidget {
  const ContentFolderPicker({
    required this.value,
    required this.onChanged,
    this.needsReview = false,
    super.key,
  });

  final ContentFolder value;
  final ValueChanged<ContentFolder> onChanged;
  final bool needsReview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final selected = await showContentFolderSheet(
            context,
            selected: value,
          );
          if (selected != null) {
            onChanged(selected);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _FolderIcon(folder: value),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsReview ? '저장할 폴더를 확인해 주세요' : '저장할 폴더',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value.label,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
    );
  }
}

/// Shows the AI-created child folder as a compact breadcrumb and lets the
/// user rename it without leaving the current screen.
final class ContentSubcategoryPicker extends StatelessWidget {
  const ContentSubcategoryPicker({
    required this.folder,
    required this.value,
    required this.onChanged,
    this.aiSuggested = true,
    super.key,
  });

  final ContentFolder folder;
  final String value;
  final ValueChanged<String> onChanged;
  final bool aiSuggested;

  @override
  Widget build(BuildContext context) {
    final label = value.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final updated = await showContentSubcategoryEditor(
            context,
            folder: folder,
            initialValue: label,
          );
          if (updated != null && updated != label) {
            onChanged(updated);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: folder.softColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  color: folder.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aiSuggested ? 'AI가 정한 하위 폴더' : '하위 폴더',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label.isEmpty
                          ? '${folder.label} 안에 이름을 정해 주세요'
                          : '${folder.label}  ·  $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: label.isEmpty ? AppTheme.muted : AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, color: AppTheme.subtle, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showContentSubcategoryEditor(
  BuildContext context, {
  required ContentFolder folder,
  required String initialValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ContentSubcategorySheet(folder: folder, initialValue: initialValue),
  );
}

final class _ContentSubcategorySheet extends StatefulWidget {
  const _ContentSubcategorySheet({
    required this.folder,
    required this.initialValue,
  });

  final ContentFolder folder;
  final String initialValue;

  @override
  State<_ContentSubcategorySheet> createState() =>
      _ContentSubcategorySheetState();
}

final class _ContentSubcategorySheetState
    extends State<_ContentSubcategorySheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('하위 폴더 이름', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${widget.folder.label} 안에서 다시 찾기 쉬운 넓은 분류로 적어 주세요.',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('subcategory-name-field'),
              controller: _controller,
              autofocus: true,
              maxLength: 20,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: '예: 스킨케어, 영양제, 카페·디저트',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('save-subcategory-button'),
                onPressed: _save,
                child: const Text('이 이름으로 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final rawValue = _controller.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (rawValue.isEmpty) {
      setState(() => _error = '하위 폴더 이름을 입력해 주세요.');
      return;
    }
    final value = normalizeContentSubcategory(rawValue);
    if (!isValidContentSubcategory(rawValue)) {
      setState(() => _error = '두 글자 이상, 한글·영문·숫자와 간단한 구분 기호만 써 주세요.');
      return;
    }
    Navigator.of(context).pop(value);
  }
}

Future<ContentFolder?> showContentFolderSheet(
  BuildContext context, {
  required ContentFolder selected,
}) {
  return showModalBottomSheet<ContentFolder>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('어디에 저장할까요?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              '나중에 정리함에서도 언제든 바꿀 수 있어요.',
              style: TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: contentFolderPickerItems.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 58),
                itemBuilder: (context, index) {
                  final folder = contentFolderPickerItems[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _FolderIcon(folder: folder, size: 42),
                    title: Text(
                      folder.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(folder.description),
                    trailing: folder == selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppTheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(folder),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _FolderIcon extends StatelessWidget {
  const _FolderIcon({required this.folder, this.size = 46});

  final ContentFolder folder;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: folder.softColor,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(folder.icon, color: folder.color, size: size * 0.48),
    );
  }
}
