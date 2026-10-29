import 'ios_dashboard_style.dart';

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UIKit owns the glass material; Flutter keeps navigation, badges and guards.
/// A probe also makes this safe in widget tests and older app installations.
class NativeGlassSurface extends StatefulWidget {
  const NativeGlassSurface({super.key, required this.child});
  final Widget child;
  @override
  State<NativeGlassSurface> createState() => _NativeGlassSurfaceState();
}

class _NativeGlassSurfaceState extends State<NativeGlassSurface> {
  bool _native = false;
  @override
  void initState() {
    super.initState();
    _checkNative();
  }

  Future<void> _checkNative() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      final available = await const MethodChannel(
        'cutlink/glass',
      ).invokeMethod<bool>('available');
      if (mounted) {
        setState(() => _native = available == true);
      }
    } on MissingPluginException {
      // Flutter test host, or an app built before the native bridge was added.
    } on PlatformException {
      // Retain the accessible Flutter material if native setup fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = IosDashboardPalette.of(context);
    final dark = palette.dark;
    final reduce =
        MediaQuery.of(context).accessibleNavigation ||
        MediaQuery.of(context).highContrast;
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _native && !reduce
                  ? UiKitView(
                      key: ValueKey(dark),
                      viewType: 'cutlink/glass-surface',
                      creationParams: {'dark': dark},
                      creationParamsCodec: const StandardMessageCodec(),
                    )
                  : BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: reduce ? 0 : 22,
                        sigmaY: reduce ? 0 : 22,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              (dark
                                      ? const Color(0xFF252629)
                                      : const Color(0xFFFCFAF7))
                                  .withValues(alpha: reduce ? 1 : .72),
                          borderRadius: BorderRadius.circular(38),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: dark ? .16 : .75,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
