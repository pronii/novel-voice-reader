import 'package:flutter/material.dart';

/// Horizontal tap zone within the reader body. The middle third toggles the
/// chrome; the outer thirds turn pages in the paged reading modes.
enum ReaderTapZone { left, middle, right }

/// Which horizontal third of [object] the [globalPosition] falls in.
///
/// Accepts any [RenderObject] for convenience at the call site; anything that
/// is not a sized [RenderBox] falls back to [ReaderTapZone.middle] so an early
/// tap still toggles the chrome rather than being silently swallowed.
ReaderTapZone readerTapZoneFor(RenderObject? object, Offset globalPosition) {
  final box = object is RenderBox ? object : null;
  if (box == null || !box.hasSize) {
    return ReaderTapZone.middle;
  }
  final width = box.size.width;
  if (width <= 0) {
    return ReaderTapZone.middle;
  }
  final dx = box.globalToLocal(globalPosition).dx;
  if (dx < width / 3) {
    return ReaderTapZone.left;
  }
  if (dx > width * 2 / 3) {
    return ReaderTapZone.right;
  }
  return ReaderTapZone.middle;
}
