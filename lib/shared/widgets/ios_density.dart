import 'package:flutter/material.dart';

import 'ios_workspace.dart';
import 'phone_layout.dart';

/// Compact spacing only; font scaling and minimum touch targets are preserved.
EdgeInsetsGeometry iosInsets(
  BuildContext context,
  EdgeInsetsGeometry original,
) {
  if (!useIosWorkspace(context)) return original;
  final p = original.resolve(Directionality.of(context));
  double compact(double value) =>
      value <= 4 ? value : (value * .7).clamp(4, 24).toDouble();
  return EdgeInsets.fromLTRB(
    compact(p.left),
    compact(p.top),
    compact(p.right),
    compact(p.bottom),
  );
}

class IosPadding extends StatelessWidget {
  const IosPadding({super.key, required this.padding, this.child});
  final EdgeInsetsGeometry padding;
  final Widget? child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: iosInsets(context, padding), child: child);
}

class IosGap extends StatelessWidget {
  const IosGap({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: useIosWorkspace(context) && height > 4 && height <= 48
        ? height * .65
        : height,
  );
}

class IosAdaptiveRow extends StatelessWidget {
  const IosAdaptiveRow({super.key, required this.desktop});
  final Row desktop;
  @override
  Widget build(BuildContext context) => useIosWorkspace(context)
      ? PhoneRow(mode: PhoneRowMode.wrap, desktop: desktop)
      : desktop;
}
