import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';

final class ProductArt extends StatelessWidget {
  const ProductArt({
    required this.brand,
    required this.name,
    required this.category,
    this.width = 76,
    this.height = 92,
    super.key,
  });

  factory ProductArt.forGroup(
    ProductGroup group, {
    double width = 76,
    double height = 92,
  }) {
    return ProductArt(
      brand: group.identity.brand,
      name: group.identity.name,
      category: group.identity.category,
      width: width,
      height: height,
    );
  }

  final String brand;
  final String name;
  final String category;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      '선케어' => const Color(0xFFF1CC55),
      '클렌저' => const Color(0xFF52D0C9),
      '크림' || '로션' => const Color(0xFFA47AF2),
      _ => const Color(0xFFF16AA6),
    };
    final icon = switch (category) {
      '선케어' => Icons.wb_sunny_outlined,
      '클렌저' => Icons.waves_outlined,
      '크림' || '로션' => Icons.spa_outlined,
      _ => Icons.water_drop_outlined,
    };
    return Semantics(
      label: '$brand $name, $category',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.16),
            AppTheme.surfaceRaised,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Center(
          child: Icon(icon, color: color, size: width * 0.34),
        ),
      ),
    );
  }
}

String sourcePlatformLabel(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.instagram => 'Instagram',
    SourcePlatform.youtube => 'YouTube',
    SourcePlatform.tiktok => 'TikTok',
    SourcePlatform.x => 'X',
    SourcePlatform.web => '웹 링크',
    SourcePlatform.textOnly => '붙여넣은 텍스트',
  };
}

IconData sourcePlatformIcon(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.youtube => Icons.play_circle_outline,
    SourcePlatform.instagram || SourcePlatform.tiktok => Icons.smart_display,
    SourcePlatform.x => Icons.alternate_email,
    SourcePlatform.web => Icons.language,
    SourcePlatform.textOnly => Icons.notes,
  };
}

String disclosureLabel(DisclosureObservation disclosure) {
  return switch (disclosure) {
    DisclosureObservation.explicitlyObserved => '명시적 광고·협찬 표시 발견',
    DisclosureObservation.notObservedInCapturedMaterial =>
      '캡처한 자료에서 광고·협찬 표시 미발견',
    DisclosureObservation.unknown => '광고·협찬 표시 확인 불가',
  };
}

final class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.icon,
    required this.title,
    required this.body,
    this.background = AppTheme.fill,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.muted, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
