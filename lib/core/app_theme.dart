import 'package:flutter/material.dart';

/// Shared visual language for Trun On.
///
/// The palette intentionally keeps the teammate prototype's near-black canvas
/// and acid-lime action color, while raising secondary-text contrast enough for
/// small Android devices and larger accessibility text sizes.
abstract final class AppTheme {
  static const primary = Color(0xFFC6FF3E);
  static const primarySoft = Color(0xFF293514);
  static const accent = Color(0xFFFF5B2E);
  static const accentSoft = Color(0xFF382018);
  static const background = Color(0xFF0B0B0D);
  static const surface = Color(0xFF151517);
  static const surfaceRaised = Color(0xFF1C1C20);
  static const ink = Color(0xFFF4F4F2);
  static const muted = Color(0xFFB1B1B8);
  static const subtle = Color(0xFF8B8B94);
  static const border = Color(0xFF2E2E34);
  static const fill = Color(0xFF202024);
  static const positive = Color(0xFF2ED9C3);
  static const caution = Color(0xFFFFB84D);
  static const negative = Color(0xFFFF6B67);

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Color(0xFF101208),
      primaryContainer: primarySoft,
      onPrimaryContainer: primary,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      error: negative,
      outline: border,
      outlineVariant: fill,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkRipple.splashFactory,
      fontFamilyFallback: const [
        'Gothic A1',
        'Apple SD Gothic Neo',
        'sans-serif',
      ],
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 38,
          height: 1.08,
          letterSpacing: -1.2,
          fontWeight: FontWeight.w900,
          color: ink,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          height: 1.18,
          letterSpacing: -0.9,
          fontWeight: FontWeight.w900,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 27,
          height: 1.24,
          letterSpacing: -0.7,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          height: 1.3,
          letterSpacing: -0.45,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.38,
          letterSpacing: -0.25,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          letterSpacing: -0.15,
          fontWeight: FontWeight.w400,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          letterSpacing: -0.1,
          fontWeight: FontWeight.w400,
          color: ink,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          height: 1.4,
          letterSpacing: -0.1,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        iconTheme: IconThemeData(size: 24, color: ink),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: primarySoft,
        checkmarkColor: primary,
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
          color: muted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: primary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: primarySoft,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primary : subtle,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? primary : subtle, size: 24);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          backgroundColor: primary,
          foregroundColor: const Color(0xFF101208),
          disabledBackgroundColor: fill,
          disabledForegroundColor: subtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 54),
          foregroundColor: ink,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(44)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
        helperStyle: TextStyle(color: subtle, fontSize: 12),
        hintStyle: TextStyle(color: subtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: background, fontSize: 14),
        actionTextColor: Color(0xFF4C6500),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }

  // Kept as a compatibility alias while feature files migrate to `dark`.
  static ThemeData get light => dark;
}
