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
    this.assetPath = 'assets/images/CutLink-Goat-Cuts-v2.svg',
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
  static const double _viewBoxHeight = 1190;
  static const Color _interactionColour = Color(0xFF082A54);

  String? _hoveredCut;

  static final List<_GoatRegion> _regions = [
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.neck,
      pathData:
          'M 452 152 C 435.33335 213.99994 401.66662 243.66666 351 241 L 346.99609 258.73633 C 347.4507 259.36358 348.00179 259.81589 348.42969 260.46094 C 355.07968 270.47093 369.47078 302.26001 371.55078 311.5 C 371.92078 313.15 375.05953 324.40001 378.51953 336.5 C 390.03952 376.81996 392.42961 391.76017 390.09961 409.16016 C 389.62145 412.76642 388.73625 416.72713 387.89648 420.57227 L 396 448 L 516 411 C 548.66663 376.33337 566.66667 329.33327 570 270 L 547.90234 247.90234 C 541.97317 243.14483 535.66239 236.88937 528.49414 228.49414 L 452 152 z ',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.shoulder,
      pathData:
          'M 570 270 C 566.66667 329.33327 548.66663 376.33337 516 411 L 396 448 L 479 616 L 563.81445 683.00391 C 568.08295 668.31366 572 652.11992 572 647.14062 C 572 642.88063 573.50969 645.80001 578.92969 660.5 C 583.32643 672.43736 585.93105 680.9825 587.54688 689.6582 L 675 635 L 700 486 C 708.87322 416.28186 701.44219 350.18668 677.77734 287.69922 C 676.05307 287.10358 674.14751 286.56621 672.5 285.94922 C 659.76387 281.17317 641.64509 276.83388 624.48633 274.19141 L 570 270 z ',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.rackRib,
      pathData:
          'M 677.77734 287.69922 C 701.44219 350.18668 708.87322 416.28186 700 486 C 767.99993 515.3333 843.66675 517.66664 927 493 L 915 294 C 888.47685 298.63103 862.32132 301.25734 836.5293 301.90039 C 832.9087 302.22177 828.69176 302.80363 825 303.08984 C 802.01002 304.86984 761.46998 304.60054 744.5 302.56055 C 720.54085 299.67003 696.98496 294.33433 677.77734 287.69922 z ',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.loin,
      pathData:
          'M 1017.8789 279.39453 C 1007.5984 279.84455 994.53783 281.25074 979.57617 283.15039 L 915 294 L 927 493 L 1070 476 C 1086 426.66672 1089.6667 364.66659 1081 290 L 1066.6152 284.03516 C 1064.7048 283.55035 1062.658 282.93847 1060.8906 282.58008 C 1047.1856 279.80008 1034.8126 278.65328 1017.8789 279.39453 z ',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.breastFlap,
      pathData:
          'M 1070 476 L 927 493 C 843.66675 517.66664 767.99993 515.3333 700 486 L 675 635 L 681.07422 635.73438 L 681.32031 631.74023 L 690.41016 632.26953 C 695.41015 632.55953 705.58001 634.01953 713 635.51953 C 720.41999 637.00953 730.33 638.58023 735 638.99023 C 739.67 639.41023 749.12001 640.88906 756 642.28906 C 762.87999 643.67906 773.45001 645.3693 779.5 646.0293 C 785.54999 646.6893 795.45001 648.28055 801.5 649.56055 C 806.71302 650.66384 809.8031 651.02744 813.91016 651.79883 L 851.48633 656.3418 C 854.43012 656.51417 856.15522 656.79654 859.64062 656.96094 C 870.72061 657.48094 884.1693 658.62047 889.5293 659.48047 C 893.39155 660.09901 895.10803 660.21254 896.80859 660.34375 C 897.65239 660.25572 898.50188 660.19533 899.34375 660.09766 C 899.2485 659.54811 898.68264 658.32946 897.48047 656.56055 L 894.92969 652.81055 L 899.2207 653.4707 C 901.5707 653.8407 905.93039 654.81063 908.90039 655.64062 C 915.34038 657.43062 918.41039 656.82914 921.90039 653.11914 C 924.25039 650.61914 933.74 646.40992 934.75 647.41992 C 934.98 647.63992 934.38945 648.99945 933.43945 650.43945 C 932.49945 651.87945 931.92969 653.25977 932.17969 653.50977 C 932.41969 653.75977 940.25056 651.05 949.56055 647.5 C 956.75982 644.75779 960.60034 643.43365 963.41797 642.49414 C 990.75968 630.4014 1016.9613 612.6079 1042 589 L 1070 476 z ',
    ),
    _GoatRegion.path(
      cut: CutLinkGoatCutKeys.leg,
      pathData:
          'M 1081 290 C 1089.6667 364.66659 1086 426.66672 1070 476 L 1042 589 L 1079.2832 637.1582 C 1078.1996 628.2395 1081.4173 631.48298 1102.5 652.58984 C 1115.15 665.25983 1131.58 680.85954 1139 687.26953 C 1157.93 703.60951 1163.3006 710.29002 1174.5605 731.5 C 1177.7705 737.54999 1182.9009 746.33 1185.9609 751 C 1189.8712 756.97096 1193.4156 764.38827 1196.5645 772.64648 L 1252 759 L 1258 702 L 1256.0859 693.72656 C 1254.6272 690.7609 1252.2109 687.95424 1246.0898 681.61914 C 1240.7198 676.04915 1234.4499 669.09992 1232.1699 666.16992 C 1222.5499 653.81993 1214.6991 635.49006 1209.8691 614.08008 C 1208.0791 606.12009 1207.8195 603.56023 1208.7695 603.24023 C 1209.7395 602.92023 1209.8691 598.14014 1209.3691 581.66016 C 1208.8091 563.50017 1208.9594 559.82093 1210.3594 555.71094 C 1214.0594 544.90095 1217.19 523.86998 1217.75 506 C 1218.05 496.38001 1218.6102 489.39047 1218.9902 490.48047 C 1219.1246 490.86032 1219.2702 490.93479 1219.4199 490.83594 L 1207 385 L 1146 321 L 1081 290 z ',
    ),
    _GoatRegion.pathsAndRects(
      cut: CutLinkGoatCutKeys.shank,
      pathData: const [
        'M 675 680 L 588.18555 693.56445 C 589.48105 702.22688 589.89047 711.35846 589.7793 724.5 C 589.72766 730.37411 589.78119 735.01649 590.01758 739.07227 L 595.95312 762.81445 C 597.14285 765.60655 598.2895 768.31083 599.98047 771.88086 C 609.03046 790.99084 612.3193 808.92003 612.2793 839 C 612.2593 853.42999 611.80922 858.94064 609.69922 870.39062 C 606.67922 886.76061 603.89991 893.08001 594.91992 904 C 592.56936 906.86103 591.42764 908.59377 589.89648 910.67188 L 566 967 L 659.12109 935.68555 C 658.90465 931.80552 658.5846 927.24429 658.00977 924 C 656.75977 916.95001 656.8093 916.22 658.7793 911.75 C 661.09929 906.53001 663.19047 905.77008 667.48047 908.58008 C 671.42822 911.16384 674.40092 909.52902 676.37109 904.9668 L 671.51562 860.5625 C 661.68727 827.02536 657.33994 784.00346 662.08008 760 C 663.41008 753.27001 664.45047 742.56038 664.98047 730.15039 C 665.47047 718.5104 666.24039 710.35922 666.90039 709.69922 C 667.70039 708.89922 668.0093 709.13078 668.0293 710.55078 C 668.0593 712.45078 668.09016 712.45961 669.16016 710.59961 C 669.77016 709.54961 670.48953 704.74968 670.76953 699.92969 C 671.14953 693.30969 671.58055 691.29016 672.56055 691.66016 C 673.13723 691.88245 673.6616 691.20163 674.16602 690.09375 L 675 680 z ',
        'M 1252 759 L 1196.5645 772.64648 C 1205.044 794.88478 1210.4029 823.70893 1210.4102 850.5 C 1210.4158 866.42549 1209.3422 876.61661 1206.0645 885.50586 L 1207 895 L 1168.3965 967.82031 C 1169.8989 967.91656 1171.638 967.95449 1173.9805 967.84961 L 1182 967.49023 L 1182 970.21094 C 1182 970.40265 1182.1018 970.54546 1182.1211 970.73047 L 1260.7383 940.84375 C 1261.0133 937.461 1260.6549 933.42891 1259.5996 929.35938 C 1256.9896 919.32939 1257.9008 907.98922 1261.5508 904.94922 C 1262.8008 903.91922 1263.9497 904.1007 1267.9297 905.9707 C 1270.6097 907.2207 1273.3002 907.93078 1273.9102 907.55078 C 1274.5332 907.16909 1275.2023 906.25449 1275.8711 905.09375 L 1255 836 L 1252 759 z ',
      ],
      rects: const [
        Rect.fromLTWH(716, 793, 146, 68),
        Rect.fromLTWH(1270, 793, 155, 68),
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
      rect: Rect.fromLTWH(247, 1037, 280, 70),
    ),
    _GoatRegion.rect(
      cut: CutLinkGoatCutKeys.trimManufacturing,
      rect: Rect.fromLTWH(555, 1037, 438, 70),
    ),
    _GoatRegion.rect(
      cut: CutLinkGoatCutKeys.offalOther,
      rect: Rect.fromLTWH(1021, 1037, 280, 70),
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

  factory _GoatRegion.rect({required String cut, required Rect rect}) {
    return _GoatRegion._(cut: cut, paths: const [], rects: [rect]);
  }

  factory _GoatRegion.pathsAndRects({
    required String cut,
    required List<String> pathData,
    required List<Rect> rects,
  }) {
    return _GoatRegion._(
      cut: cut,
      paths: pathData.map(parseSvgPathData).toList(),
      rects: rects,
    );
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
