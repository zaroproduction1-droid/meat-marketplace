import 'package:flutter/material.dart';

class MeatHeroMedia extends StatelessWidget {
  const MeatHeroMedia({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/cutlink_hero_poster.webp',
    fit: BoxFit.cover,
    errorBuilder: (context, error, stack) => const ColoredBox(
      color: Color(0xFF263A34),
      child: Center(
        child: Icon(
          Icons.restaurant_outlined,
          color: Color(0xFFA2C7B4),
          size: 64,
        ),
      ),
    ),
  );
}
