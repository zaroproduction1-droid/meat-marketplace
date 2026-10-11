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
  Widget build(BuildContext context) => Image.asset(
    'assets/images/CutLink-${symbolOnly ? 'Symbol' : 'Horizontal'}-${onDark ? 'White' : 'Burgundy'}.png',
    width: width,
    height: height,
    fit: BoxFit.contain,
    alignment: Alignment.centerLeft,
    semanticLabel: 'CutLink',
    filterQuality: FilterQuality.high,
  );
}
