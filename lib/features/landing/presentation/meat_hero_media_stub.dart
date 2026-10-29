import '../../../shared/theme/cutlink_appearance.dart';

import 'package:flutter/material.dart';

class MeatHeroMedia extends StatelessWidget {
  const MeatHeroMedia({super.key});
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Image.asset(
      'assets/images/cutlink_hero_poster.webp',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: CutLinkPalette.color(0xFF263A34),
        child: Center(
          child: Icon(
            Icons.restaurant_outlined,
            color: CutLinkPalette.color(0xFFA2C7B4),
            size: 64,
          ),
        ),
      ),
    );
  }
}
