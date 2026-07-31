import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';

final class ProductArt extends StatelessWidget {
  const ProductArt({
    required this.brand,
    required this.name,
    required this.category,
    required this.colorValue,
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
      colorValue: group.colorValue,
      width: width,
      height: height,
    );
  }

  final String brand;
  final String name;
  final String category;
  final int colorValue;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return Semantics(
      label: '$brand $name 제품 이미지 자리',
      image: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Container(
            width: width * 0.48,
            height: height * 0.66,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              category == '선케어'
                  ? Icons.wb_sunny_outlined
                  : Icons.water_drop_outlined,
              color: Colors.white,
              size: width * 0.25,
            ),
          ),
        ),
      ),
    );
  }
}

final class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    super.key,
  });

  factory StatusPill.forCapture(CaptureRecord capture) {
    return switch (capture.status) {
      CaptureStatus.received || CaptureStatus.analyzing => const StatusPill(
        label: '분석 중',
        icon: Icons.autorenew,
        foreground: Color(0xFF1A5E99),
        background: Color(0xFFEAF3FC),
      ),
      CaptureStatus.sourceLimited => const StatusPill(
        label: '자료 부족',
        icon: Icons.link_off,
        foreground: Color(0xFF8A5700),
        background: Color(0xFFFFF1D2),
      ),
      CaptureStatus.needsReview => const StatusPill(
        label: '확인 필요',
        icon: Icons.help_outline,
        foreground: Color(0xFF8A5700),
        background: Color(0xFFFFF1D2),
      ),
      CaptureStatus.organized => const StatusPill(
        label: '정리 완료',
        icon: Icons.inventory_2_outlined,
        foreground: Color(0xFF176B4D),
        background: Color(0xFFE6F5EE),
      ),
      CaptureStatus.failed => const StatusPill(
        label: '분석 실패',
        icon: Icons.error_outline,
        foreground: Color(0xFFB42318),
        background: Color(0xFFFFE9E6),
      ),
    };
  }

  factory StatusPill.forConfidence(double confidence) {
    if (confidence >= 0.85) {
      return const StatusPill(
        label: '신뢰도 높음',
        icon: Icons.verified_outlined,
        foreground: Color(0xFF176B4D),
        background: Color(0xFFE6F5EE),
      );
    }
    if (confidence >= 0.6) {
      return const StatusPill(
        label: '확인 권장',
        icon: Icons.manage_search,
        foreground: Color(0xFF8A5700),
        background: Color(0xFFFFF1D2),
      );
    }
    return const StatusPill(
      label: '확인 필요',
      icon: Icons.help_outline,
      foreground: Color(0xFFB42318),
      background: Color(0xFFFFE9E6),
    );
  }

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

String confidenceBandLabel(ConfidenceBand band) {
  return switch (band) {
    ConfidenceBand.high => '높은 신뢰',
    ConfidenceBand.reviewRecommended => '확인 권장',
    ConfidenceBand.reviewRequired => '확인 필요',
  };
}

final class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

final class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.icon,
    required this.title,
    required this.body,
    this.background = const Color(0xFFEEE9FA),
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(body, style: const TextStyle(color: AppTheme.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
