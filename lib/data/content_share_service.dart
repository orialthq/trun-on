import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/portable_tip_package.dart';

final class ContentShareService {
  const ContentShareService();

  Future<ShareResult> shareCard({
    required GlobalKey previewKey,
    required String title,
    Rect? sharePositionOrigin,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Share card preview is not ready.');
    }
    // The preview is 360×450 logical pixels; 3× produces a social-ready
    // 1080×1350 (4:5) card consistently across devices.
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Share card could not be rendered.');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return SharePlus.instance.share(
        ShareParams(
          title: 'Trun On 정보 카드',
          files: [
            XFile.fromData(Uint8List.fromList(bytes), mimeType: 'image/png'),
          ],
          fileNameOverrides: ['${_safeFileName(title)}-card.png'],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } finally {
      image.dispose();
    }
  }

  Future<ShareResult> sharePortableTip({
    required PortableTipPackage tip,
    Rect? sharePositionOrigin,
  }) {
    final bytes = PortableTipPackageCodec.encodeUtf8(tip);
    return SharePlus.instance.share(
      ShareParams(
        title: 'Trun On으로 보내기',
        subject: tip.title,
        files: [
          XFile.fromData(bytes, mimeType: PortableTipPackageCodec.mimeType),
        ],
        fileNameOverrides: [
          '${_safeFileName(tip.title)}.${PortableTipPackageCodec.fileExtension}',
        ],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

String _safeFileName(String value) {
  final normalized = value
      .replaceAll(RegExp(r'[^0-9A-Za-z가-힣 _-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final shortened = String.fromCharCodes(normalized.runes.take(40));
  return shortened.isEmpty ? 'trun-on-tip' : shortened;
}
