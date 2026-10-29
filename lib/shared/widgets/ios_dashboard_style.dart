import 'package:flutter/material.dart';

/// Explicit colours from the approved dashboard reference, without a seed tint.
class IosDashboardPalette {
  const IosDashboardPalette(this.dark);
  final bool dark;
  static IosDashboardPalette of(BuildContext context) =>
      IosDashboardPalette(Theme.of(context).brightness == Brightness.dark);
  Color get canvas => dark ? const Color(0xFF111113) : const Color(0xFFFCFAF7);
  Color get card => dark ? const Color(0xFF1C1D1F) : const Color(0xFFFCFAF7);
  Color get search => dark ? const Color(0xFF242527) : const Color(0xFFF1EFEC);
  Color get border => dark ? const Color(0xFF303135) : const Color(0xFFE6E2DE);
  Color get ink => dark ? const Color(0xFFFAFAFA) : const Color(0xFF121212);
  Color get muted => dark ? const Color(0xFFB2B2B6) : const Color(0xFF626264);
  Color get accent => dark ? const Color(0xFFD95470) : const Color(0xFF850E25);
  static const burgundy = Color(0xFF850E25);
  ThemeData theme(ThemeData base) => base.copyWith(
    scaffoldBackgroundColor: canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: Colors.white,
      surface: card,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: search,
      surfaceTint: Colors.transparent,
    ),
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    iconTheme: IconThemeData(color: ink, size: 22),
    dividerColor: border,
  );
}
