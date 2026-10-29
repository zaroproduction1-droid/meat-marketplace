import '../theme/cutlink_appearance.dart';

import 'package:flutter/material.dart';

import 'ios_workspace.dart';

/// Shared commercial workspace styling. Keep new screens consistent with Sales.
class CutLinkWorkspaceTheme extends StatelessWidget {
  const CutLinkWorkspaceTheme({super.key, required this.child});
  final Widget child;
  static Color get ink => CutLinkPalette.color(0xFF101D2B);
  static const red = Color(0xFF741C1C);
  static Color get canvas => CutLinkPalette.color(0xFFF7F8FA);
  static Color get border => CutLinkPalette.color(0xFFE3E5E8);

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    final base = Theme.of(context);
    if (useIosWorkspace(context)) {
      return Theme(data: IosWorkspaceStyle.theme(base), child: child);
    }
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: border),
    );
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: canvas,
        colorScheme: base.colorScheme.copyWith(
          primary: base.brightness == Brightness.dark
              ? base.colorScheme.primary
              : red,
          surface: CutLinkPalette.surface,
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: CutLinkPalette.surface,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          shape: Border(bottom: BorderSide(color: border)),
        ),
        cardTheme: CardThemeData(
          color: CutLinkPalette.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: CutLinkPalette.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: red, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: BorderSide(color: border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: CutLinkPalette.surface,
          selectedColor: CutLinkPalette.color(0xFFF4E5E5),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: child,
    );
  }
}

class CutLinkSectionHeading extends StatelessWidget {
  const CutLinkSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: CutLinkPalette.color(0xFFF4E5E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: CutLinkWorkspaceTheme.red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: CutLinkWorkspaceTheme.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: CutLinkPalette.color(0xFF6A6E75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CutLinkMetricTile extends StatelessWidget {
  const CutLinkMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CutLinkPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CutLinkWorkspaceTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: CutLinkWorkspaceTheme.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: CutLinkPalette.color(0xFF6A6E75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: CutLinkWorkspaceTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}
