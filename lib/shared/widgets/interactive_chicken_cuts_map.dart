import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

abstract final class CutLinkChickenCutKeys {
  static const wholeChicken = 'whole-chicken';
  static const neck = 'neck';
  static const backFrame = 'back-frame';
  static const wing = 'wing';
  static const breast = 'breast';
  static const tenderloin = 'tenderloin';
  static const tail = 'tail';
  static const maryland = 'maryland';
  static const thigh = 'thigh';
  static const drumstick = 'drumstick';
  static const chickenChopCutlet = 'chicken-chop-cutlet';
  static const minceManufacturing = 'mince-manufacturing';
  static const miscOffalOther = 'misc-offal-other';
}

class InteractiveChickenCutsMap extends StatefulWidget {
  const InteractiveChickenCutsMap({
    super.key,
    required this.onCutSelected,
    this.selectedCut,
    this.assetPath = 'assets/images/CutLink-Chicken-Cuts.svg',
    this.maxWidth = 1000,
    this.borderRadius = 16,
  });

  final ValueChanged<String> onCutSelected;
  final String? selectedCut;
  final String assetPath;
  final double maxWidth;
  final double borderRadius;

  @override
  State<InteractiveChickenCutsMap> createState() =>
      _InteractiveChickenCutsMapState();
}

class _InteractiveChickenCutsMapState extends State<InteractiveChickenCutsMap> {
  static const double _viewBoxWidth = 1536;
  static const double _viewBoxHeight = 1250;
  static const Color _interactionColour = Color(0xFF082A54);

  String? _hoveredCut;

  static final List<_ChickenRegion> _regions = [
    _ChickenRegion(
      cut: 'whole-chicken',
      pathData: const [],
      rects: [
        RRect.fromRectAndRadius(
          Rect.fromLTWH(696, 96, 310, 70),
          Radius.circular(15),
        ),
      ],
    ),
    _ChickenRegion(
      cut: 'neck',
      pathData: const [
        'M390 212 Q425 213 452 180 Q500 200 540 244 Q563 309 620 338 L566 418 Q455 402 396 350 Q388 273 390 212Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'back-frame',
      pathData: const [
        'M540 244 Q582 277 657 288 Q797 284 975 307 Q1050 327 1091 382 Q1135 448 1120 547 L1076 596 L998 569 Q1064 562 1028 519 Q1042 494 1008 484 Q960 411 823 355 Q722 311 620 338 Q563 309 540 244Z',
      ],
      rects: [
        RRect.fromRectAndRadius(
          Rect.fromLTWH(235, 1040, 512, 76),
          Radius.circular(15),
        ),
      ],
    ),
    _ChickenRegion(
      cut: 'wing',
      pathData: const [
        'M566 418 Q574 346 649 333 Q742 315 823 355 Q960 411 1008 484 Q1042 494 1028 519 Q1064 562 998 569 Q983 597 920 594 Q876 611 823 602 L755 582 Q707 576 673 560 Q562 513 566 418Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'breast',
      pathData: const [
        'M396 350 Q455 402 566 418 Q562 513 673 560 Q707 576 755 582 L823 602 L786 730 Q736 750 676 729 Q536 704 467 638 Q385 567 387 453Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'tenderloin',
      pathData: const [
        'M474 538 H601 Q629 538 629 568 Q629 598 601 598 H474 Q446 598 446 568 Q446 538 474 538Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'tail',
      pathData: const [
        'M982 307 Q1028 296 1068 252 Q1136 139 1196 133 Q1239 120 1226 165 Q1260 172 1239 217 Q1271 226 1246 285 Q1264 308 1222 365 Q1224 397 1196 435 Q1194 467 1170 484 Q1170 518 1120 547 Q1135 448 1091 382 Q1050 327 982 307Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'maryland',
      pathData: const [
        'M823 602 Q906 611 998 569 L1076 596 L1120 547 Q1126 622 1050 691 Q1004 737 944 754 Q924 766 905 789 Q879 801 854 786 Q822 770 786 758 L740 744 L786 730Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'thigh',
      pathData: const [
        'M859 682 Q895 638 952 639 Q1015 637 1050 667 Q1058 683 1035 711 Q983 728 957 744 Q914 700 859 699Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'drumstick',
      pathData: const [
        'M859 699 Q914 700 957 744 Q925 762 905 789 Q879 801 854 786 Q822 770 802 763 Q819 731 859 699Z',
      ],
      rects: [],
    ),
    _ChickenRegion(
      cut: 'chicken-chop-cutlet',
      pathData: const [],
      rects: [
        RRect.fromRectAndRadius(
          Rect.fromLTWH(789, 1040, 512, 76),
          Radius.circular(15),
        ),
      ],
    ),
    _ChickenRegion(
      cut: 'mince-manufacturing',
      pathData: const [],
      rects: [
        RRect.fromRectAndRadius(
          Rect.fromLTWH(235, 1140, 512, 76),
          Radius.circular(15),
        ),
      ],
    ),
    _ChickenRegion(
      cut: 'misc-offal-other',
      pathData: const [],
      rects: [
        RRect.fromRectAndRadius(
          Rect.fromLTWH(789, 1140, 512, 76),
          Radius.circular(15),
        ),
      ],
    ),
  ];

  String? _cutAt(Offset localPosition, Size size) {
    if (size.isEmpty) return null;

    final scale = (size.width / _viewBoxWidth < size.height / _viewBoxHeight)
        ? size.width / _viewBoxWidth
        : size.height / _viewBoxHeight;

    final drawnWidth = _viewBoxWidth * scale;
    final drawnHeight = _viewBoxHeight * scale;
    final offsetX = (size.width - drawnWidth) / 2;
    final offsetY = (size.height - drawnHeight) / 2;

    if (localPosition.dx < offsetX ||
        localPosition.dy < offsetY ||
        localPosition.dx > offsetX + drawnWidth ||
        localPosition.dy > offsetY + drawnHeight) {
      return null;
    }

    final svgPoint = Offset(
      (localPosition.dx - offsetX) / scale,
      (localPosition.dy - offsetY) / scale,
    );

    for (final region in _regions.reversed) {
      if (region.contains(svgPoint)) return region.cut;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _viewBoxWidth / _viewBoxHeight;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                return MouseRegion(
                  cursor: _hoveredCut == null
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  onHover: (event) {
                    final cut = _cutAt(event.localPosition, size);
                    if (cut != _hoveredCut) {
                      setState(() => _hoveredCut = cut);
                    }
                  },
                  onExit: (_) {
                    if (_hoveredCut != null) {
                      setState(() => _hoveredCut = null);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final cut = _cutAt(details.localPosition, size);
                      if (cut != null) widget.onCutSelected(cut);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SvgPicture.asset(widget.assetPath, fit: BoxFit.contain),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _ChickenHighlightPainter(
                              regions: _regions,
                              hoveredCut: _hoveredCut,
                              selectedCut: widget.selectedCut,
                              interactionColour: _interactionColour,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ChickenRegion {
  _ChickenRegion({
    required this.cut,
    required List<String> pathData,
    required this.rects,
  }) : paths = pathData.map(parseSvgPathData).toList();

  final String cut;
  final List<Path> paths;
  final List<RRect> rects;

  bool contains(Offset point) {
    for (final path in paths) {
      if (path.contains(point)) return true;
    }
    for (final rect in rects) {
      if (rect.contains(point)) return true;
    }
    return false;
  }
}

class _ChickenHighlightPainter extends CustomPainter {
  const _ChickenHighlightPainter({
    required this.regions,
    required this.hoveredCut,
    required this.selectedCut,
    required this.interactionColour,
  });

  final List<_ChickenRegion> regions;
  final String? hoveredCut;
  final String? selectedCut;
  final Color interactionColour;

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        (size.width / _InteractiveChickenCutsMapState._viewBoxWidth <
            size.height / _InteractiveChickenCutsMapState._viewBoxHeight)
        ? size.width / _InteractiveChickenCutsMapState._viewBoxWidth
        : size.height / _InteractiveChickenCutsMapState._viewBoxHeight;

    final drawnWidth = _InteractiveChickenCutsMapState._viewBoxWidth * scale;
    final drawnHeight = _InteractiveChickenCutsMapState._viewBoxHeight * scale;
    final offsetX = (size.width - drawnWidth) / 2;
    final offsetY = (size.height - drawnHeight) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    for (final region in regions) {
      final selected = region.cut == selectedCut;
      final hovered = region.cut == hoveredCut;
      if (!selected && !hovered) continue;

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = interactionColour.withValues(alpha: selected ? 0.20 : 0.12);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4 : 2.5
        ..color = interactionColour.withValues(alpha: selected ? 0.95 : 0.75);

      for (final path in region.paths) {
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      }

      for (final rect in region.rects) {
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, stroke);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChickenHighlightPainter oldDelegate) {
    return oldDelegate.hoveredCut != hoveredCut ||
        oldDelegate.selectedCut != selectedCut ||
        oldDelegate.interactionColour != interactionColour;
  }
}
