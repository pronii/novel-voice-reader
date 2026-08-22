import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';

/// Assembles the warm-paper [ThemeData] for light ("paper") and dark ("night
/// reading") modes. Colors are hand-authored (see [PaperPalette]) rather than
/// seeded so the cream/ink/terracotta relationships stay exact; semantic roles
/// outside [ColorScheme] live on the [PaperTheme] extension.
abstract final class AppTheme {
  static ThemeData light() => _build(_lightScheme, PaperTheme.light);

  static ThemeData dark() => _build(_darkScheme, PaperTheme.dark);

  /// The night-reading color scheme. Exposed so the reader's chrome (the bottom
  /// mode bar and its page-mode dialog) can render against the warm dark palette
  /// even when the app itself is in light mode, keeping those immersive overlays
  /// unified with the dark reading aesthetic rather than a seeded generic dark.
  static const ColorScheme darkColorScheme = _darkScheme;

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: PaperPalette.brand,
    onPrimary: Color(0xFFF6F0E1),
    primaryContainer: Color(0xFFCADBCF),
    onPrimaryContainer: Color(0xFF102A20),
    secondary: Color(0xFF8C6D53),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE9DAC5),
    onSecondaryContainer: PaperPalette.ink,
    tertiary: PaperPalette.accent,
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF2DAC5),
    onTertiaryContainer: Color(0xFF4E2611),
    error: Color(0xFFA03A2E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF6D9D2),
    onErrorContainer: Color(0xFF3B0906),
    surface: PaperPalette.paper,
    onSurface: PaperPalette.ink,
    onSurfaceVariant: PaperPalette.inkSecondary,
    surfaceContainerLowest: PaperPalette.surfaceHigh,
    surfaceContainerLow: PaperPalette.surface,
    surfaceContainer: Color(0xFFF1E7D3),
    surfaceContainerHigh: Color(0xFFECE1CB),
    surfaceContainerHighest: Color(0xFFE6DAC0),
    surfaceDim: Color(0xFFE0D4BA),
    surfaceBright: Color(0xFFFDF8EC),
    outline: Color(0xFFB6A986),
    outlineVariant: PaperPalette.divider,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF33302A),
    onInverseSurface: Color(0xFFF3ECDD),
    inversePrimary: PaperPalette.brandDark,
    surfaceTint: PaperPalette.brand,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: PaperPalette.brandDark,
    onPrimary: Color(0xFF10271E),
    primaryContainer: Color(0xFF274A3C),
    onPrimaryContainer: Color(0xFFCDE7DA),
    secondary: Color(0xFFC9AE93),
    onSecondary: Color(0xFF34271A),
    secondaryContainer: Color(0xFF4A3A2A),
    onSecondaryContainer: PaperPalette.inkDark,
    tertiary: PaperPalette.accentDark,
    onTertiary: Color(0xFF3A2410),
    tertiaryContainer: Color(0xFF543A1F),
    onTertiaryContainer: Color(0xFFF5DCC0),
    error: Color(0xFFE79A90),
    onError: Color(0xFF48130C),
    errorContainer: Color(0xFF6A2019),
    onErrorContainer: Color(0xFFF6D9D2),
    surface: PaperPalette.paperDark,
    onSurface: PaperPalette.inkDark,
    onSurfaceVariant: PaperPalette.inkSecondaryDark,
    surfaceContainerLowest: Color(0xFF17130F),
    surfaceContainerLow: Color(0xFF24201A),
    surfaceContainer: PaperPalette.surfaceDark,
    surfaceContainerHigh: PaperPalette.surfaceHighDark,
    surfaceContainerHighest: Color(0xFF3D3629),
    surfaceDim: PaperPalette.paperDark,
    surfaceBright: Color(0xFF453E33),
    outline: Color(0xFF8A7F6C),
    outlineVariant: PaperPalette.dividerDark,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: PaperPalette.inkDark,
    onInverseSurface: PaperPalette.surfaceDark,
    inversePrimary: PaperPalette.brand,
    surfaceTint: PaperPalette.brandDark,
  );

  static ThemeData _build(ColorScheme scheme, PaperTheme paper) {
    final text = _textTheme(ink: scheme.onSurface, faint: scheme.onSurfaceVariant);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: PaperFonts.sans,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[paper],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.15),
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.field),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        helperStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.14),
        trackHeight: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.button),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primaryContainer;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimaryContainer;
            }
            return scheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.sheet),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.button),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
      ),
    );
  }

  /// Serif (book feel) drives display/headline/title + reading; sans keeps
  /// small UI text crisp. Colors are baked per-brightness by the caller.
  static TextTheme _textTheme({required Color ink, required Color faint}) {
    TextStyle serif(double size, {FontWeight weight = FontWeight.w600, double height = 1.3}) =>
        TextStyle(
          fontFamily: PaperFonts.serif,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: ink,
        );
    TextStyle sans(double size,
            {FontWeight weight = FontWeight.w400, double height = 1.5, Color? color}) =>
        TextStyle(
          fontFamily: PaperFonts.sans,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? ink,
        );

    return TextTheme(
      displayLarge: serif(34, weight: FontWeight.w700, height: 1.2),
      displayMedium: serif(30, weight: FontWeight.w700, height: 1.2),
      displaySmall: serif(26, height: 1.25),
      headlineLarge: serif(24),
      headlineMedium: serif(22),
      headlineSmall: serif(20),
      titleLarge: serif(20),
      titleMedium: serif(17, height: 1.35),
      titleSmall: sans(14.5, weight: FontWeight.w600, height: 1.4),
      bodyLarge: sans(16),
      bodyMedium: sans(14),
      bodySmall: sans(12.5, height: 1.45, color: faint),
      labelLarge: sans(14, weight: FontWeight.w600, height: 1.2),
      labelMedium: sans(12, weight: FontWeight.w600, height: 1.2, color: faint),
      labelSmall: sans(11, weight: FontWeight.w600, height: 1.2, color: faint),
    );
  }
}
