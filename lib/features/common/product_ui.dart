import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';

final class ProductArt extends StatelessWidget {
  const ProductArt({
    required this.product,
    this.width = 76,
    this.height = 92,
    super.key,
  });

  final Product product;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Color(product.colorValue);
    return Semantics(
      label: '${product.brand} ${product.name} 제품 이미지',
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
              product.category == '선케어'
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

  factory StatusPill.forProduct(Product product) {
    if (product.analysisStatus == AnalysisStatus.needsConfirmation) {
      return const StatusPill(
        label: '확인 필요',
        icon: Icons.help_outline,
        foreground: Color(0xFF8A5700),
        background: Color(0xFFFFF1D2),
      );
    }
    return switch (product.decision) {
      Decision.candidate => const StatusPill(
        label: '구매 후보',
        icon: Icons.check_circle_outline,
        foreground: Color(0xFF176B4D),
        background: Color(0xFFE6F5EE),
      ),
      Decision.hold => const StatusPill(
        label: '보류',
        icon: Icons.pause_circle_outline,
        foreground: Color(0xFF8A5700),
        background: Color(0xFFFFF1D2),
      ),
      Decision.excluded => const StatusPill(
        label: '제외',
        icon: Icons.remove_circle_outline,
        foreground: Color(0xFF6C6461),
        background: Color(0xFFF0ECEA),
      ),
      Decision.undecided => const StatusPill(
        label: '결정 전',
        icon: Icons.pending_outlined,
        foreground: Color(0xFF1A5E99),
        background: Color(0xFFEAF3FC),
      ),
    };
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

String overlapLabel(OverlapLevel level) {
  return switch (level) {
    OverlapLevel.low => '루틴 중복 낮음',
    OverlapLevel.medium => '루틴 일부 중복',
    OverlapLevel.high => '루틴 중복 높음',
  };
}

Color overlapColor(OverlapLevel level) {
  return switch (level) {
    OverlapLevel.low => const Color(0xFF176B4D),
    OverlapLevel.medium => const Color(0xFF8A5700),
    OverlapLevel.high => const Color(0xFFB42318),
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
