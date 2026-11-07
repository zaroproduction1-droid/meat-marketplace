import 'package:flutter/material.dart';

import 'workspace_message_theme.dart';

/// Explicit neutral surfaces shared by desktop, iPhone and every overlay.
ThemeData cutLinkAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xFF111113) : const Color(0xFFF7F7F5);
  final surface = dark ? const Color(0xFF1C1C1E) : Colors.white;
  final raised = dark ? const Color(0xFF262629) : const Color(0xFFF1F2F4);
  final ink = dark ? const Color(0xFFF2F2F7) : const Color(0xFF202124);
  final muted = dark ? const Color(0xFFB5B7BF) : const Color(0xFF62666D);
  final border = dark ? const Color(0xFF3A3A40) : const Color(0xFFDDE0E4);
  final accent = dark ? const Color(0xFFFF7187) : const Color(0xFFA51C34);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFA51C34),
        brightness: brightness,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xFF37000D) : Colors.white,
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: muted,
        surfaceContainerLowest: background,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: raised,
        surfaceContainerHighest: raised,
        surfaceTint: Colors.transparent,
        outline: border,
        outlineVariant: border,
        error: dark ? const Color(0xFFFF9B9B) : const Color(0xFFB3261E),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Arial',
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    cardColor: surface,
    dividerColor: border,
    disabledColor: muted.withValues(alpha: .55),
    textTheme: ThemeData(
      brightness: brightness,
    ).textTheme.apply(fontFamily: 'Arial', bodyColor: ink, displayColor: ink),
    iconTheme: IconThemeData(color: muted),
    appBarTheme: AppBarThemeData(
      backgroundColor: surface,
      foregroundColor: ink,
      titleTextStyle: TextStyle(
        fontFamily: 'Arial',
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: raised,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: ink, fontSize: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: ink, fontSize: 14),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: ink),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: raised,
      selectedColor: dark ? const Color(0xFF482430) : const Color(0xFFF6DFE4),
      labelStyle: TextStyle(color: ink, fontFamily: 'Arial'),
      secondaryLabelStyle: TextStyle(color: ink, fontFamily: 'Arial'),
      side: BorderSide(color: border),
      checkmarkColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFA51C34),
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: border),
        minimumSize: const Size(44, 40),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    listTileTheme: ListTileThemeData(textColor: ink, iconColor: muted),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(raised),
      headingTextStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
      dataTextStyle: TextStyle(color: ink),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      textColor: ink,
      collapsedTextColor: ink,
      iconColor: muted,
      collapsedIconColor: muted,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF404046) : const Color(0xFF202124),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    snackBarTheme: workspaceMessageTheme(brightness),
  );
}
