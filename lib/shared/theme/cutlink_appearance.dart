import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only a display preference is persisted. No orders, prices or stock are cached.
class CutLinkAppearance extends ChangeNotifier with WidgetsBindingObserver {
  CutLinkAppearance._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final instance = CutLinkAppearance._();
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isDark =>
      _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  Future<void> load() async {
    final stored = (await SharedPreferences.getInstance()).getString(
      'cutlink.appearance',
    );
    _mode = ThemeMode.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    _mode = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      'cutlink.appearance',
      value.name,
    );
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == ThemeMode.system) {
      notifyListeners();
    }
  }
}

/// Semantic adaptation for legacy workspace paint values. Photos, logos and
/// PDF document colours are deliberately excluded from this palette.
abstract final class CutLinkPalette {
  static Color color(int light) {
    if (!CutLinkAppearance.instance.isDark) {
      return Color(light);
    }
    final alpha = (light >> 24) & 255;
    final r = (light >> 16) & 255;
    final g = (light >> 8) & 255;
    final b = light & 255;
    final luminance = (r * .2126 + g * .7152 + b * .0722);
    final int dark;
    if (luminance >= 246) {
      dark = 0xFF1C1C1E;
    } else if (luminance >= 231) {
      dark = 0xFF242426;
    } else if (luminance >= 195) {
      dark = 0xFF3A3A3C;
    } else if (luminance >= 125) {
      dark = 0xFFAEAEB4;
    } else if (luminance >= 65) {
      dark = 0xFFB8BBC2;
    } else {
      dark = 0xFFF2F2F7;
    }
    return Color((alpha << 24) | (dark & 0xFFFFFF));
  }

  static Color get surface => color(0xFFFFFFFF);
}

/// Depend on the preference even on screens using legacy paint constants.
class AppearanceScope extends InheritedNotifier<CutLinkAppearance> {
  AppearanceScope({super.key, required super.child})
    : super(notifier: CutLinkAppearance.instance);
  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
  }
}

class AppearanceSettingsTile extends StatelessWidget {
  const AppearanceSettingsTile({super.key});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.brightness_6_outlined),
    title: const Text('Appearance'),
    subtitle: const Text('System, light or dark'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: CutLinkAppearance.instance,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Appearance',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(
                    mode == ThemeMode.system
                        ? 'Use device setting'
                        : mode == ThemeMode.light
                        ? 'Light'
                        : 'Dark',
                  ),
                  trailing: CutLinkAppearance.instance.mode == mode
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    await CutLinkAppearance.instance.setMode(mode);
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
