import 'package:flutter/material.dart';

/// Warm-paper design tokens for 声阅.
///
/// The palette evokes aged cream paper with ink-dark text and a terracotta
/// "bookmark" accent. Everything the standard [ColorScheme] can express lives
/// there (see `theme.dart`); the semantic roles it cannot — the bookmark
/// accent, the reading highlight wash, the raised "paper" surface — live on the
/// [PaperTheme] extension below so screens can read them via
/// `Theme.of(context).paper`.
abstract final class PaperPalette {
  // ---- Light / paper -------------------------------------------------------
  static const paper = Color(0xFFF5EEDD); // page background
  static const surface = Color(0xFFFBF6EA); // cards / list rows
  static const surfaceHigh = Color(0xFFFFFDF7); // floating layers
  static const ink = Color(0xFF2B2620); // primary text (warm black)
  static const inkSecondary = Color(0xFF6E6659); // secondary text
  static const brand = Color(0xFF2E5E4E); // deep pine — brand
  static const accent = Color(0xFFC4703A); // terracotta bookmark accent
  static const divider = Color(0xFFE4D9C1); // low-contrast warm rule
  static const highlightWash = Color(0xFFF0E0B8); // now-reading paragraph

  // ---- Dark / night reading ------------------------------------------------
  static const paperDark = Color(0xFF1F1B16);
  static const surfaceDark = Color(0xFF2A251E);
  static const surfaceHighDark = Color(0xFF332D24);
  static const inkDark = Color(0xFFECE3D2);
  static const inkSecondaryDark = Color(0xFFA99E8B);
  static const brandDark = Color(0xFF7FB49B);
  static const accentDark = Color(0xFFD9A05B);
  static const dividerDark = Color(0xFF3C352B);
  static const highlightWashDark = Color(0xFF4A3F27);
}

/// The two app font families, bundled as subsetted assets (see pubspec.yaml).
/// Serif carries the "book" feel (titles + reading body); sans keeps UI chrome
/// crisp. Any glyph outside the bundled subset falls back to the platform CJK
/// font automatically.
abstract final class PaperFonts {
  static const serif = 'NotoSerifSC';
  static const sans = 'NotoSansSC';
}

/// A single spacing scale so padding/gaps are consistent across screens.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Default horizontal page padding.
  static const page = 20.0;
}

/// Corner radii — softer than stock Material to read as paper cards.
abstract final class Corners {
  static const card = 14.0;
  static const button = 12.0;
  static const field = 12.0;
  static const chip = 10.0;
  static const cover = 10.0;
  static const sheet = 20.0;
}

/// Warm spine colors used to generate placeholder covers for imported books
/// that have no artwork. Picked by a stable hash of the title so a book always
/// gets the same spine.
abstract final class CoverPalette {
  static const light = <Color>[
    Color(0xFF2E5E4E), // pine
    Color(0xFFC4703A), // terracotta
    Color(0xFF7A5230), // walnut
    Color(0xFF4E6B8A), // dusk blue
    Color(0xFF8A4B57), // rosewood
    Color(0xFF5B6236), // olive
    Color(0xFF9A6A2E), // amber-brown
    Color(0xFF525E63), // slate
  ];

  static const dark = <Color>[
    Color(0xFF3C6F5D),
    Color(0xFFB9743F),
    Color(0xFF8A6A45),
    Color(0xFF5E7B9C),
    Color(0xFF9C5F6B),
    Color(0xFF6E7645),
    Color(0xFFAE7F3F),
    Color(0xFF697579),
  ];

  static Color forTitle(String title, {required bool dark}) {
    final list = dark ? CoverPalette.dark : CoverPalette.light;
    var hash = 0;
    for (final code in title.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return list[hash % list.length];
  }
}

/// Semantic colors [ColorScheme] has no slot for. Read via `context.paper`.
@immutable
class PaperTheme extends ThemeExtension<PaperTheme> {
  const PaperTheme({
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.highlightWash,
    required this.surfaceHigh,
    required this.readingLineHeight,
  });

  /// Terracotta bookmark accent — progress, "now reading", key highlights.
  final Color accent;
  final Color onAccent;

  /// A soft accent-tinted fill (e.g. progress track background, chips).
  final Color accentContainer;
  final Color onAccentContainer;

  /// Background behind the paragraph currently being narrated.
  final Color highlightWash;

  /// A surface raised above cards (bottom bars, sheets, overlays).
  final Color surfaceHigh;

  /// Line height for flowing reading text.
  final double readingLineHeight;

  static const light = PaperTheme(
    accent: PaperPalette.accent,
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFF2DAC5),
    onAccentContainer: Color(0xFF4E2611),
    highlightWash: PaperPalette.highlightWash,
    surfaceHigh: PaperPalette.surfaceHigh,
    readingLineHeight: 1.7,
  );

  static const dark = PaperTheme(
    accent: PaperPalette.accentDark,
    onAccent: Color(0xFF3A2410),
    accentContainer: Color(0xFF543A1F),
    onAccentContainer: Color(0xFFF5DCC0),
    highlightWash: PaperPalette.highlightWashDark,
    surfaceHigh: PaperPalette.surfaceHighDark,
    readingLineHeight: 1.7,
  );

  @override
  PaperTheme copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? highlightWash,
    Color? surfaceHigh,
    double? readingLineHeight,
  }) {
    return PaperTheme(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
      highlightWash: highlightWash ?? this.highlightWash,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      readingLineHeight: readingLineHeight ?? this.readingLineHeight,
    );
  }

  @override
  PaperTheme lerp(covariant PaperTheme? other, double t) {
    if (other == null) return this;
    return PaperTheme(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      onAccentContainer:
          Color.lerp(onAccentContainer, other.onAccentContainer, t)!,
      highlightWash: Color.lerp(highlightWash, other.highlightWash, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      readingLineHeight:
          lerpDouble(readingLineHeight, other.readingLineHeight, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Convenience accessor: `context.paper.accent`.
extension PaperThemeContext on BuildContext {
  PaperTheme get paper =>
      Theme.of(this).extension<PaperTheme>() ?? PaperTheme.light;
}
