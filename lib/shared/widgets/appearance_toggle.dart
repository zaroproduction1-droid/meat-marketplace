import 'package:flutter/material.dart';
import '../theme/cutlink_appearance.dart';

/// Available before sign-in and uses the same persisted preference as Settings.
class AppearanceToggle extends StatelessWidget {
  const AppearanceToggle({super.key});

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    final appearance = CutLinkAppearance.instance;
    final dark = appearance.isDark;
    return IconButton(
      key: const ValueKey('appearance-toggle'),
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () =>
          appearance.setMode(dark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}
