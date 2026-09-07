import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 theme definitions for 'أكلة النهاردة'
/// Built with a warm Egyptian culinary palette (terracotta, saffron amber, nile teal)
/// and a modern Material 3 dark mode palette (deep grays, soft contrast, cohesive tones).
class AppTheme {
  AppTheme._();

  // Egyptian spice & culinary seed colors
  static const Color seedColor = Color(0xFFC04A26); // Warm Terracotta Brick
  static const Color secondaryColor = Color(0xFFE08E45); // Saffron amber
  static const Color tertiaryColor = Color(0xFF388E3C); // Nile parsley green

  /// Tailored Material 3 dark color scheme
  /// Conforms to modern Material 3 dark specifications with deep modern grays
  /// (#121212 - #1E1E1E) instead of pitch black or jarring high contrasts.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF8B66), // Polished warm terracotta
    onPrimary: Color(0xFF4A1808),
    primaryContainer: Color(0xFF6B2713),
    onPrimaryContainer: Color(0xFFFFDBD2),
    secondary: Color(0xFFFFB879), // Saffron amber
    onSecondary: Color(0xFF472700),
    secondaryContainer: Color(0xFF643C08),
    onSecondaryContainer: Color(0xFFFFDCBE),
    tertiary: Color(0xFF81C784), // Nile parsley green
    onTertiary: Color(0xFF003912),
    tertiaryContainer: Color(0xFF165225),
    onTertiaryContainer: Color(0xFFA6F5AF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1A1A1A), // Deep modern gray
    onSurface: Color(0xFFEDEDED), // Soft white text
    surfaceDim: Color(0xFF141414), // Deepest dark gray
    surfaceBright: Color(0xFF383838),
    surfaceContainerLowest: Color(0xFF0F0F0F),
    surfaceContainerLow: Color(0xFF1E1E1E), // Subtle card / panel level
    surfaceContainer: Color(0xFF242424),
    surfaceContainerHigh: Color(0xFF2A2A2A),
    surfaceContainerHighest: Color(0xFF343434),
    onSurfaceVariant: Color(0xFFC7C5C4),
    outline: Color(0xFF8A8886),
    outlineVariant: Color(0xFF444240),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFEDEDED),
    onInverseSurface: Color(0xFF1A1A1A),
    inversePrimary: Color(0xFFC04A26),
  );

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    final baseTextTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: GoogleFonts.cairoTextTheme(baseTextTheme),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.cairo(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: GoogleFonts.cairoTextTheme(baseTextTheme),
      scaffoldBackgroundColor: darkColorScheme.surfaceDim,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: darkColorScheme.surfaceDim,
        foregroundColor: darkColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: darkColorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: darkColorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkColorScheme.surfaceContainer,
        side: BorderSide(
          color: darkColorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: darkColorScheme.surfaceContainerLowest,
        indicatorColor: darkColorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkColorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkColorScheme.primary,
        foregroundColor: darkColorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkColorScheme.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.cairo(color: darkColorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: darkColorScheme.outlineVariant.withValues(alpha: 0.3),
        thickness: 1,
      ),
    );
  }
}
