import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';

/// A synthesized placeholder cover for books with no artwork.
///
/// Imported TXT/EPUB novels rarely carry a cover image, so we generate a
/// recognizable "spine" cover instead of a blank box: a warm color chosen by a
/// stable hash of the title (so a given book always looks the same), a darker
/// spine strip, and the title's first character as a large serif monogram.
///
/// The monogram is deliberately a single glyph rather than the full title: the
/// full title is always shown next to the cover, and rendering it here too
/// would create a second `Text` with the same string (breaking `find.text`
/// lookups and, visually, cluttering a small thumbnail). Rendered small in the
/// library list and large on the player screen.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.width = 56,
    this.height = 78,
  });

  final String title;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = CoverPalette.forTitle(title, dark: isDark);
    final spine = Color.alphaBlend(const Color(0x33000000), base);
    final sheen = Color.alphaBlend(const Color(0x1FFFFFFF), base);
    final initial = title.runes.isEmpty
        ? ''
        : String.fromCharCode(title.runes.first);
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Corners.cover),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sheen, base],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, isDark ? 0.45 : 0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: (width * 0.11).clamp(4.0, 12.0),
            child: ColoredBox(color: spine),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(left: width * 0.08),
              child: Text(
                initial,
                maxLines: 1,
                // Cover art is graphic, not body text: keep it stable across
                // the user's reading text-scale preference.
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: PaperFonts.serif,
                  color: const Color(0xFFFBF6EA),
                  fontSize: width * 0.46,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
