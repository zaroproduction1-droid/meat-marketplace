import 'sharp_logo.dart';

import 'package:flutter/material.dart';

/// Official artwork, with its original proportions and accessible brand label.
class CutLinkLogo extends StatelessWidget {
  const CutLinkLogo({
    super.key,
    this.width = 150,
    this.height = 36,
    this.onDark = false,
    this.symbolOnly = false,
  });
  final double width;
  final double height;
  final bool onDark;
  final bool symbolOnly;

  @override
  Widget build(BuildContext context) => SharpLogo.asset(
    'assets/images/CutLink-${symbolOnly ? 'Symbol' : 'Horizontal'}-${onDark || Theme.of(context).brightness == Brightness.dark ? 'White' : 'Burgundy'}.png',
    width: width,
    height: height,
    alignment: Alignment.centerLeft,
    semanticLabel: 'CutLink',
  );
}
