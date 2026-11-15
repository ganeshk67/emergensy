import 'package:flutter/material.dart';

@immutable
class AppPalette {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.raisedSurface,
    required this.primary,
    required this.tertiary,
    required this.ink,
    required this.muted,
    required this.border,
  });

  final Color canvas;
  final Color surface;
  final Color raisedSurface;
  final Color primary;
  final Color tertiary;
  final Color ink;
  final Color muted;
  final Color border;

  static const light = AppPalette(
    canvas: Color(0xFFF7F7FB),
    surface: Colors.white,
    raisedSurface: Color(0xFFF0F1F6),
    primary: Color(0xFFE94355),
    tertiary: Color(0xFF00AFC6),
    ink: Color(0xFF1F2633),
    muted: Color(0xFF737B89),
    border: Color(0xFFE6E7ED),
  );

  static const dark = AppPalette(
    canvas: Color(0xFF07111E),
    surface: Color(0xFF0D1B2A),
    raisedSurface: Color(0xFF13263A),
    primary: Color(0xFFFF5365),
    tertiary: Color(0xFF43D7E8),
    ink: Color(0xFFF0F7FC),
    muted: Color(0xFF9DB0C1),
    border: Color(0xFF20364A),
  );
}

abstract final class AppTheme {
  static final ThemeData light = _build(AppPalette.light, Brightness.light);
  static final ThemeData dark = _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: palette.primary,
      primary: palette.primary,
      tertiary: palette.tertiary,
      surface: palette.surface,
      onSurface: palette.ink,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.canvas,
      colorScheme: colors,
      textTheme: ThemeData(
        brightness: brightness,
        useMaterial3: true,
      ).textTheme.apply(bodyColor: palette.ink, displayColor: palette.ink),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: palette.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.raisedSurface,
        hintStyle: TextStyle(color: palette.muted),
        labelStyle: TextStyle(color: palette.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: shape,
          side: BorderSide(color: palette.border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.primary.withValues(alpha: .14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.ink,
        contentTextStyle: TextStyle(color: palette.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: palette.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.raisedSurface,
        selectedColor: colors.primaryContainer,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primary.withValues(alpha: .16),
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
    );
  }
}
