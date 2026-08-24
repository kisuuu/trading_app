import 'package:flutter/material.dart';

/// Semantic colours for market data. Kept off `ColorScheme` because up/down are
/// domain concepts, not brand roles, and must stay stable across themes.
abstract final class MarketColors {
  static const Color up = Color(0xFF26A69A);
  static const Color down = Color(0xFFEF5350);
  static const Color flat = Color(0xFF8B949E);

  /// Colour for a signed figure: green above zero, red below, muted at zero.
  static Color forChange(num value) {
    if (value > 0) return up;
    if (value < 0) return down;
    return flat;
  }
}

abstract final class AppTheme {
  static const Color _background = Color(0xFF0D1117);
  static const Color _surface = Color(0xFF161B22);
  static const Color _outline = Color(0xFF262D36);

  /// Numerals that do not change width as they change value.
  ///
  /// Essential for a live price table: with proportional digits every tick
  /// would shift the column and the eye could never settle on a number.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.dark,
    ).copyWith(
      surface: _background,
      surfaceContainer: _surface,
      surfaceContainerHighest: _surface,
      outlineVariant: _outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      dividerTheme: const DividerThemeData(
        color: _outline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: const CardThemeData(
        color: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Text styles for dense numeric columns.
extension MarketTextStyles on TextTheme {
  TextStyle get price => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFeatures: AppTheme.tabularFigures,
        letterSpacing: -0.1,
      );

  TextStyle get priceLarge => const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        fontFeatures: AppTheme.tabularFigures,
        letterSpacing: -0.5,
      );

  TextStyle get change => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFeatures: AppTheme.tabularFigures,
      );

  TextStyle get columnLabel => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: MarketColors.flat,
      );
}
