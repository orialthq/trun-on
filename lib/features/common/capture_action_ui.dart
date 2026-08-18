import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../state/app_controller.dart';

enum CaptureListAction { organize, delete }

Future<CaptureListAction?> showCaptureActionSheet(
  BuildContext context, {
  required bool canOrganize,
}) {
  return showModalBottomSheet<CaptureListAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.planSurface,
    elevation: 0,
    builder: (sheetContext) => Theme(
      data: AppTheme.plansTheme(Theme.of(sheetContext)),
      child: SafeArea(
        key: const Key('capture-action-safe-area'),
        top: false,
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.only(bottom: AppTheme.bottomSheetSafeInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canOrganize) ...[
                ListTile(
                  key: const Key('capture-action-organize'),
                  leading: const Icon(
                    Icons.bookmark_add_outlined,
                    color: AppTheme.planMuted,
                  ),
                  title: const Text('정리함에 저장'),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(CaptureListAction.organize),
                ),
                const Divider(indent: 56, endIndent: 8),
              ],
              ListTile(
                key: const Key('capture-action-delete'),
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.planNegative,
                ),
                title: const Text(
                  '삭제',
                  style: TextStyle(color: AppTheme.planNegative),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(CaptureListAction.delete),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirmCaptureDeletion(
  BuildContext context, {
  required AppController controller,
  required String captureId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Theme(
      data: AppTheme.plansTheme(Theme.of(dialogContext)),
      child: AlertDialog(
        backgroundColor: AppTheme.planSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.planBorder),
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('이 콘텐츠를 삭제할까요?'),
        content: const Text(
          'Trun On에 보관된 내용만 삭제해요. 갤러리 원본은 그대로 남아요.',
          style: TextStyle(color: AppTheme.planMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppTheme.planMuted),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('confirm-capture-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.planNegative),
            child: const Text('삭제'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }

  final deleted = await controller.deleteCapture(captureId);
  if (!deleted && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('삭제하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
  }
  return deleted;
}
