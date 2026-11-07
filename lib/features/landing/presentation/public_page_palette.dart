import '../../../shared/theme/cutlink_appearance.dart';

import 'package:flutter/material.dart';

/// Shared palette for CutLink's public landing and account pages.
abstract final class PublicPagePalette {
  static Color get background => CutLinkPalette.surface;
  static Color get surface => CutLinkPalette.color(0xFFF7F8FA);
  static Color get border => CutLinkPalette.color(0xFFE1E5EA);
  static Color get text => CutLinkPalette.color(0xFF202830);
  static Color get muted =>
      CutLinkPalette.isDark ? const Color(0xFFB5B7BF) : const Color(0xFF586572);
  static const primary = Color(0xFFA51C34);
  static Color get accent => CutLinkPalette.actionRed;
}
