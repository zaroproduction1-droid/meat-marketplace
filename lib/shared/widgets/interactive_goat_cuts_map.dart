import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

abstract final class CutLinkGoatCutKeys {
  static const wholeGoat = 'Whole Goat';
  static const forequarter = 'Forequarter';
  static const hindquarter = 'Hindquarter';
  static const leg = 'Leg';
  static const shoulder = 'Shoulder';
  static const loin = 'Loin';
  static const rackRib = 'Rack / Rib';
  static const breastFlap = 'Breast / Flap';
  static const neck = 'Neck';
  static const shank = 'Shank';
  static const trimManufacturing = 'Trim / Manufacturing';
  static const offalOther = 'Offal / Other';
}

class InteractiveGoatCutsMap extends StatefulWidget {
  const InteractiveGoatCutsMap({
    super.key,
    required this.onCutSelected,
    this.selectedCut,
    this.assetPath = 'assets/images/CutLink-Goat-Cuts.svg',
    this.maxWidth = 1000,
    this.borderRadius = 16,
  });

  final ValueChanged<String> onCutSelected;
  final String? selectedCut;
  final String assetPath;
  final double maxWidth;
  final double borderRadius;

  @override
  State<InteractiveGoatCutsMap> createState() => _InteractiveGoatCutsMapState();
}

class _InteractiveGoatCutsMapState extends State<InteractiveGoatCutsMap> {
  static const double _viewBoxLeft = 100;
  static const double _viewBoxTop = 0;
  static const double _viewBoxWidth = 1360;
  static const double _viewBoxHeight = 1260;
  static const Color _interactionColour = Color(0xFF082A54);

  String? _hoveredCut;

  static final List<_GoatRegion> _regions = [
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.neck,
      pathData:
          'M351 241 Q427 245 452 152 L570 270 Q565 359 516 411 L396 448 L344 272Z',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.shoulder,
      pathData:
          'M570 270 L674 278 Q714 376 700 486 L675 635 L579 695 L479 616 L396 448 L516 411 Q565 359 570 270Z',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.rackRib,
      pathData:
          'M674 278 Q789 316 915 294 L927 493 Q802 530 700 486 Q714 376 674 278Z',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.loin,
      pathData: 'M915 294 L1040 273 L1081 290 Q1094 402 1070 476 L927 493Z',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.breastFlap,
      pathData:
          'M700 486 Q802 530 927 493 L1070 476 L1042 589 Q972 655 890 661 L675 635Z',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.leg,
      pathData:
          'M1081 290 L1146 321 L1207 385 L1230 581 L1258 702 L1252 759 L1187 775 Q1158 717 1114 682 L1042 589 L1070 476 Q1094 402 1081 290Z',
    ),
    _GoatRegion.paths(
      cut: CutLinkGoatCutKeys.shank,
      pathData: const [
        'M579 695 L675 680 L665 801 L679 929 L566 967 L594 901 L610 819Z',
        'M1187 775 L1252 759 L1255 836 L1284 932 L1163 978 L1207 895 L1200 824Z',
      ],
    ),
    _GoatRegion.rect(
      cut: CutLinkGoatCutKeys.forequarter,
      rect: Rect.fromLTWH(619, 110, 238, 70),
    ),
    _GoatRegion.rect(
      cut: CutLinkGoatCutKeys.hindquarter,
      rect: Rect.fromLTWH(883, 110, 248, 70),
    ),
    _GoatRegion.rect(
      cut: CutLinkGoatCutKeys.wholeGoat,
      rect: Rect.fromLTWH(247, 1068, 280, 70),
    ),
    _GoatRegion.rect(
      cut: CutLinkGoatCutKeys.trimManufacturing,
      rect: Rect.fromLTWH(555, 1068, 438, 70),
    ),
    _GoatRegion.rect(
      cut: CutLinkGoatCutKeys.offalOther,
      rect: Rect.fromLTWH(1021, 1068, 280, 70),
    ),
  ];

  String? _cutAt(Offset localPosition, Size size) {
    if (size.isEmpty) return null;

    final svgPoint = Offset(
      _viewBoxLeft + (localPosition.dx * _viewBoxWidth / size.width),
      _viewBoxTop + (localPosition.dy * _viewBoxHeight / size.height),
    );

    for (final region in _regions.reversed) {
      if (region.hitTest(svgPoint)) return region.cut;
    }
    return null;
  }

  void _updateHover(Offset localPosition, Size size) {
    final next = _cutAt(localPosition, size);
    if (next == _hoveredCut) return;
    setState(() => _hoveredCut = next);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: AspectRatio(
          aspectRatio: _viewBoxWidth / _viewBoxHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F6),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return MouseRegion(
                    cursor: _hoveredCut == null
                        ? MouseCursor.defer
                        : SystemMouseCursors.click,
                    onHover: (event) => _updateHover(event.localPosition, size),
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
                          SvgPicture.asset(widget.assetPath, fit: BoxFit.fill),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _GoatHighlightPainter(
                                regions: _regions,
                                selectedCut: widget.selectedCut,
                                hoveredCut: _hoveredCut,
                                interactionColour: _interactionColour,
                                viewBoxLeft: _viewBoxLeft,
                                viewBoxTop: _viewBoxTop,
                                viewBoxWidth: _viewBoxWidth,
                                viewBoxHeight: _viewBoxHeight,
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
      ),
    );
  }
}

class _GoatRegion {
  const _GoatRegion._({
    required this.cut,
    required this.paths,
    required this.rects,
  });

  factory _GoatRegion.path({required String cut, required String pathData}) {
    return _GoatRegion._(
      cut: cut,
      paths: [parseSvgPathData(pathData)],
      rects: const [],
    );
  }

  factory _GoatRegion.paths({
    required String cut,
    required List<String> pathData,
  }) {
    return _GoatRegion._(
      cut: cut,
      paths: pathData.map(parseSvgPathData).toList(),
      rects: const [],
    );
  }

  factory _GoatRegion.rect({required String cut, required Rect rect}) {
    return _GoatRegion._(cut: cut, paths: const [], rects: [rect]);
  }

  final String cut;
  final List<Path> paths;
  final List<Rect> rects;

  bool hitTest(Offset point) {
    for (final rect in rects) {
      if (rect.contains(point)) return true;
    }
    for (final path in paths) {
      if (path.contains(point)) return true;
    }
    return false;
  }
}

class _GoatHighlightPainter extends CustomPainter {
  const _GoatHighlightPainter({
    required this.regions,
    required this.selectedCut,
    required this.hoveredCut,
    required this.interactionColour,
    required this.viewBoxLeft,
    required this.viewBoxTop,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
  });

  final List<_GoatRegion> regions;
  final String? selectedCut;
  final String? hoveredCut;
  final Color interactionColour;
  final double viewBoxLeft;
  final double viewBoxTop;
  final double viewBoxWidth;
  final double viewBoxHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final sx = size.width / viewBoxWidth;
    final sy = size.height / viewBoxHeight;

    canvas.save();
    canvas.scale(sx, sy);
    canvas.translate(-viewBoxLeft, -viewBoxTop);

    for (final region in regions) {
      final selected = region.cut == selectedCut;
      final hovered = region.cut == hoveredCut;
      if (!selected && !hovered) continue;

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = interactionColour.withValues(alpha: selected ? 0.20 : 0.12);

      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4 : 3
        ..color = interactionColour;

      for (final rect in region.rects) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(15)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(15)),
          outline,
        );
      }

      for (final path in region.paths) {
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoatHighlightPainter oldDelegate) {
    return oldDelegate.selectedCut != selectedCut ||
        oldDelegate.hoveredCut != hoveredCut;
  }
}
