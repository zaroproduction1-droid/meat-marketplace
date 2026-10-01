import 'package:flutter/material.dart';

// The public website uses the native browser player. This fallback allows
// non-web builds and widget tests to render the same bundled film poster.
class CutLinkExplainerVideo extends StatelessWidget {
  const CutLinkExplainerVideo({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Watch the CutLink film on the website',
    image: true,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/cutlink_explainer_poster.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) =>
              const ColoredBox(color: Color(0xFF202830)),
        ),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 64,
          ),
        ),
      ],
    ),
  );
}
