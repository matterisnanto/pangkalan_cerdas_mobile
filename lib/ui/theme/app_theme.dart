import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const emerald = Color(0xFF00AA5B);
  static const darkEmerald = Color(0xFF10B981);
  static const indigo = Color(0xFF0063F7);
  static const ink = Color(0xFF0F172A);
  static const secondaryLight = Color(0xFF475569);
  static const ice = Color(0xFFF8FAFC);
  static const lightScaffold = Color(0xFFF8FAFC);
  static const darkScaffold = Color(0xFF0F172A);

  static ThemeData light() => _build(
    Brightness.light,
    emerald,
    lightScaffold,
    Colors.white,
    ink,
    const Color(0xFFE9ECEF),
    const Color(0xFFF1F3F5),
  );
  static ThemeData dark() => _build(
    Brightness.dark,
    darkEmerald,
    darkScaffold,
    const Color(0xFF1E293B),
    ice,
    const Color(0xFF334155),
    const Color(0xFF1E293B),
  );

  static ThemeData _build(
    Brightness brightness,
    Color primary,
    Color scaffold,
    Color surface,
    Color text,
    Color border,
    Color field,
  ) {
    final secondary = brightness == Brightness.light
        ? secondaryLight
        : const Color(0xFF94A3B8);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: indigo,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: secondary,
      error: const Color(0xFFD64545),
      onError: Colors.white,
    );
    final textTheme = ThemeData(brightness: brightness, useMaterial3: true)
        .textTheme
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          bodyMedium: TextStyle(
            color: text,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          bodySmall: TextStyle(color: secondary, fontSize: 12),
          labelLarge: TextStyle(color: text, fontWeight: FontWeight.w700),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Roboto',
      textTheme: textTheme,
      dividerColor: border,
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: text),
        side: BorderSide(color: border),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: brightness == Brightness.dark ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1.1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: .16),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
    );
  }
}
