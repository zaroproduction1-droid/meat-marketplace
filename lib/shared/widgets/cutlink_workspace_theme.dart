import 'package:flutter/material.dart';

/// Shared commercial workspace styling. Keep new screens consistent with Sales.
class CutLinkWorkspaceTheme extends StatelessWidget {
  const CutLinkWorkspaceTheme({super.key, required this.child});
  final Widget child;
  static const ink = Color(0xFF101D2B);
  static const red = Color(0xFF741C1C);
  static const canvas = Color(0xFFF7F8FA);
  static const border = Color(0xFFE3E5E8);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: border),
    );
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: canvas,
        colorScheme: base.colorScheme.copyWith(
          primary: red,
          surface: Colors.white,
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: const TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          shape: const Border(bottom: BorderSide(color: border)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
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
            side: const BorderSide(color: border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFF4E5E5),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: const TextStyle(
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF4E5E5),
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
                style: const TextStyle(
                  color: CutLinkWorkspaceTheme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF6A6E75), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6A6E75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: CutLinkWorkspaceTheme.ink,
          ),
        ),
      ],
    ),
  );
}
