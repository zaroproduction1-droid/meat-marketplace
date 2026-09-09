import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

class InteractiveLambCutsMap extends StatefulWidget {
  const InteractiveLambCutsMap({
    super.key,
    required this.onCutSelected,
    this.selectedCut,
    this.assetPath = 'assets/images/CutLink-Lamb-Cuts.svg',
    this.maxWidth = 1000,
    this.borderRadius = 16,
  });

  final ValueChanged<String> onCutSelected;
  final String? selectedCut;
  final String assetPath;
  final double maxWidth;
  final double borderRadius;

  @override
  State<InteractiveLambCutsMap> createState() => _InteractiveLambCutsMapState();
}

class _InteractiveLambCutsMapState extends State<InteractiveLambCutsMap> {
  static const double _viewBoxWidth = 1600;
  static const double _viewBoxHeight = 1190;
  static const Color _interactionColour = Color(0xFF082A54);

  String? _hoveredCut;

  static final List<_LambRegion> _regions = [
    _LambRegion.paths(
      cut: 'Neck',
      pathData: const [
        'M 392 147 L 350 280 L 363.31641 327.875 C 364.04957 328.43972 364.81615 329.00083 365.9707 330.32031 C 368.7807 333.51031 368.88961 333.98008 368.34961 340.58008 C 368.18268 342.6576 368.49236 344.87889 368.6543 347.06641 L 373.91602 365.98438 C 375.85299 369.39183 377.97377 372 380.16016 372 C 381.33016 372 382.15 372.96 382.5 374.75 C 382.79 376.26 383.7907 379.52 384.7207 382 C 385.8707 385.04 386.35094 388.93002 386.21094 394 C 385.83616 407.18686 389.27163 420.55429 394.98828 430.20898 L 528 395 C 532.66666 390.58334 537.02605 385.9427 541.07812 381.07812 C 545.1302 376.21355 548.875 371.125 552.3125 365.8125 C 555.75 360.5 558.88021 354.96354 561.70312 349.20312 C 564.52604 343.44271 567.04167 337.45833 569.25 331.25 C 571.45833 325.04167 573.35938 318.60937 574.95312 311.95312 C 576.54687 305.29688 577.83333 298.41666 578.8125 291.3125 C 579.79167 284.20834 580.46354 276.8802 580.82812 269.32812 C 581.19271 261.77605 581.25 253.99998 581 246 L 529 192 L 392 147 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Shoulder',
      pathData: const [
        'M 581 246 C 583 309.99988 565.33326 359.66674 528 395 L 599 483 L 721 443 L 710.56055 259.8457 L 709.26953 260.25 L 701.24023 257.15039 C 690.21027 252.90039 681.00912 251.49047 672.36914 252.73047 C 666.57916 253.56047 664.88047 253.45023 661.48047 251.99023 C 652.08049 247.96025 634.72912 246.66986 625.86914 249.33984 C 623.36914 250.08984 620.57094 250.34016 619.46094 249.91016 C 618.38094 249.49016 616.42914 249.11031 615.11914 249.07031 C 614.20092 249.04228 612.53079 248.09796 610.84766 246.92578 L 581 246 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Forequarter',
      pathData: const [
        'M 721 443 L 599 483 L 562 597 L 572.80859 677.56836 C 574.08078 675.48862 575.55095 672.65913 576.08984 671.19922 C 577.74984 666.71922 584.45953 653.0693 585.01953 653.0293 C 585.68953 652.9893 589.71064 667.74002 591.14062 675.5 C 591.89062 679.56 591.97969 686.68002 591.42969 697.5 C 590.39969 717.52996 590.63039 726.35963 592.40039 734.84961 C 594.2352 743.65058 598.01299 752.90237 602.5625 761 L 681.84375 761 C 682.05318 755.0032 682.44563 750.78155 683.4707 747.5 C 687.1407 735.76002 685.50045 715.78092 679.98047 704.96094 C 678.35047 701.76094 678.23938 700.42037 679.10938 694.40039 C 679.65936 690.60039 679.97078 685.23092 679.80078 682.46094 C 679.60078 679.02094 680.03016 676.61086 681.16016 674.88086 C 685.53014 668.20088 687.6693 654.51943 686.0293 643.68945 L 684.86914 636.05078 L 688.40039 631.42969 C 693.11039 625.25969 696.06047 617.06998 696.73047 608.25 C 697.45047 598.89002 698.17924 598.30086 706.44922 600.38086 C 706.84524 600.47987 707.41053 600.46536 707.83008 600.55469 L 709 593 L 721 443 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Breast / Flap',
      pathData: const [
        'M 528 395 L 394.98828 430.20898 C 395.83064 431.63162 396.57559 433.21246 397.51953 434.44922 C 400.34448 438.15182 400.68809 439.77446 401.03125 447.4668 L 460 555 L 474.58203 577.35938 C 476.4008 579.02765 478.17553 580.82943 480.10938 582.07031 L 485.24023 585.36914 L 484.69922 591.36914 C 484.66742 591.71892 484.81115 592.5929 484.79492 593.01953 L 490 601 L 562 597 L 599 483 L 528 395 z M 1061 423 L 916 448 C 898.00004 451.49999 880.43748 454.02084 863.3125 455.5625 C 854.75001 456.33333 846.29687 456.85938 837.95312 457.14062 C 829.60938 457.42187 821.375 457.45833 813.25 457.25 C 805.125 457.04167 797.10937 456.58854 789.20312 455.89062 C 781.29688 455.19271 773.49999 454.25 765.8125 453.0625 C 758.12501 451.875 750.54687 450.44271 743.07812 448.76562 C 735.60938 447.08854 728.24999 445.16666 721 443 L 709 593 L 709 600.70117 C 715.42723 601.89363 723.64886 602.19781 728.5 601.06055 C 730.77 600.54055 732.92938 601.07 737.35938 603.25 C 750.66934 609.80998 771.14988 612.03006 784.33984 608.33008 C 789.42984 606.90008 791.12041 606.83086 795.90039 607.88086 C 806.27037 610.16086 819.71049 610.41928 829.23047 608.5293 C 836.38045 607.1093 838.56047 607.01 841.23047 608 C 843.03047 608.67 847.42 609.55094 851 609.96094 C 854.58 610.38094 860.42 611.51047 864 612.48047 C 876.71998 615.93047 896.26979 613.03076 907.25977 606.05078 C 911.80975 603.16078 912.25994 603.08086 917.16992 604.13086 C 926.0999 606.05086 937.58064 604.84922 945.39062 601.19922 C 949.13062 599.44922 953.90025 596.65975 955.99023 595.00977 C 958.08023 593.34977 960.03031 592 960.32031 592 C 960.61031 592 961.3793 593.69 962.0293 595.75 C 963.68422 600.96936 968.40129 609.31538 972.61523 614.60156 L 1054 540 L 1061 423 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Rack / Rib',
      pathData: const [
        'M 909 245 L 783.2832 248.1582 C 778.21613 249.06763 773.69894 250.53462 769 252.83008 L 763.5 255.50977 L 754 254.14062 C 742.35002 252.45064 730.6306 253.5608 717.89062 257.55078 L 710.56055 259.8457 L 721 443 C 778.99988 460.3333 844.00014 461.99998 916 448 L 909 245 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Loin',
      pathData: const [
        'M 1060.0117 215.58398 C 1057.4195 215.58967 1054.7276 215.48562 1052.5 215.89062 C 1049.3217 216.46311 1047.2255 216.45391 1045.0977 216.1582 L 909 245 L 916 448 L 1061 423 L 1060.0117 215.58398 z M 958 367 L 1018 367 A 23 23 0 0 1 1041 390 A 23 23 0 0 1 1018 413 L 958 413 A 23 23 0 0 1 935 390 A 23 23 0 0 1 958 367 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Chump / Rump',
      pathData: const [
        'M 1063.9062 215.42578 C 1062.498 215.32915 1061.3597 215.58119 1060.0176 215.58398 L 1061 354 C 1068.4731 351.91075 1075.9032 350.01002 1083.2988 348.25977 C 1083.7824 348.14532 1084.2668 348.02706 1084.75 347.91406 C 1091.9956 346.21988 1099.2039 344.68867 1106.375 343.32031 C 1106.8534 343.22903 1107.3306 343.14257 1107.8086 343.05273 C 1115.118 341.67918 1122.3931 340.45644 1129.625 339.42188 C 1136.8572 338.38727 1144.0464 337.5413 1151.2012 336.8457 C 1151.6685 336.80027 1152.1366 336.75102 1152.6035 336.70703 C 1159.6134 336.04674 1166.5861 335.54924 1173.5215 335.21484 C 1173.9836 335.19256 1174.4445 335.17513 1174.9062 335.1543 C 1181.9748 334.83538 1189.0089 334.66741 1196 334.6875 C 1203.25 334.70833 1210.4583 334.91146 1217.625 335.29688 C 1224.7917 335.68229 1231.9167 336.25 1239 337 L 1210.7891 281.20703 C 1203.9518 277.46033 1191.5753 273 1187.6094 273 C 1186.2094 273 1184.9193 272.12 1184.2793 270.75 C 1179.4593 260.34002 1155.9408 245 1144.8008 245 C 1143.7108 245 1140.9502 243.39945 1138.6602 241.43945 C 1130.7202 234.63947 1116.4307 229.03977 1106.9707 229.00977 C 1104.4807 229.00977 1101.46 228.31094 1100.25 227.46094 C 1090.845 220.87594 1076.2995 216.27609 1063.9062 215.42578 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Leg',
      pathData: const [
        'M 1196 334.6875 C 1152.5 334.5625 1107.5 341.00002 1061 354 L 1061 423 L 1054 540 L 1118.8457 651.92578 C 1123.0073 653.53457 1149.4081 669.94116 1156.3496 675.36914 C 1167.9596 684.45912 1174.3693 691.64971 1184.2793 706.67969 C 1189.5393 714.65967 1196.1798 723.14041 1201.0898 728.15039 C 1208.2398 735.45037 1210.0194 738.07049 1216.1094 750.23047 C 1219.5661 757.12667 1222.7696 764.14763 1225.7227 771.23242 L 1296.3691 754.15234 C 1295.3122 749.91981 1294.0738 745.73174 1293.1309 741.42969 C 1288.5409 720.44973 1287.1393 710.42002 1285.5293 686.83008 C 1283.8593 662.24012 1281.7804 653.5599 1275.1504 643.41992 C 1273.9818 641.63397 1272.9604 640.20196 1271.9082 638.86719 L 1259.5352 628.76953 C 1257.5909 627.47493 1256.7356 626.66427 1254 624.94922 C 1241.24 616.94924 1233 610.5 1233 608.5 C 1233 607.79741 1230.78 605.38458 1228.1211 603.13281 L 1201 581 L 1214.2363 541.29102 C 1214.1333 539.47648 1214.2752 538.01025 1213.9707 535.7207 C 1212.8507 527.25072 1212.8708 527.04078 1215.3008 523.80078 C 1216.5845 522.08847 1217.6208 520.20293 1218.6484 518.31055 L 1239 337 C 1224.8333 335.5 1210.5 334.72917 1196 334.6875 z M 1123.0645 659.20898 L 1127 666 L 1135.8613 678.33789 C 1133.7862 673.52728 1129.9318 668.06096 1123.0645 659.20898 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Shank',
      pathData: const [
        'M 1296.3691 754.15234 L 1225.7227 771.23242 C 1234.7465 792.88246 1241.348 815.16059 1245.0098 836.55078 C 1247.5798 851.61076 1247.8507 884.27908 1245.4707 893.53906 C 1243.8907 899.68906 1239.62 908.97963 1233.5 919.59961 C 1231.57 922.94961 1229.1907 928.82064 1228.2207 932.64062 C 1227.6292 934.97625 1226.7232 937.43446 1225.5273 940 L 1311.6191 940 C 1311.9117 938.31139 1312.2126 937.57826 1312.5391 935.41016 C 1313.4691 929.19016 1315.2097 923.09992 1317.6797 917.41992 C 1321.7497 908.03994 1320.9598 908.51055 1329.2598 910.56055 C 1331.8196 911.18853 1334.0732 909.85587 1335.7344 907.28906 L 1303.3906 779.28711 C 1300.7758 770.90605 1298.4418 762.45267 1296.3691 754.15234 z M 602.5625 761 C 605.45163 766.14234 608.58762 770.919 611.93945 774.5 C 617.71945 780.66998 623.86994 799.05006 629.16992 826 C 632.01992 840.50998 632.27092 867.76973 629.71094 886.92969 C 627.90094 900.49965 624.9207 908.32947 617.2207 919.68945 C 612.11072 927.23945 609.59039 932.27055 607.65039 938.81055 C 607.17831 940.39499 606.37068 942.2534 605.48242 944 L 687.0332 944 C 689.11811 934.97885 694.1882 923.25082 696.56055 922.33984 C 697.49055 921.97984 699.78969 922.24969 701.67969 922.92969 C 704.58967 923.97969 705.48086 923.92 707.63086 922.5 C 710.79086 920.43 713 915.30928 713 910.0293 C 713 907.8093 713.42922 906 713.94922 906 C 714.18825 906 714.34783 905.56016 714.54297 905.30859 L 706.22656 867.26172 C 705.53669 865.99898 705.38933 865.45807 704.57031 864 C 696.38033 849.43002 689.93914 829.94058 684.36914 802.89062 C 681.95914 791.19066 681.60938 787.22996 681.60938 771.5 C 681.60603 766.55132 681.73854 764.01242 681.84375 761 L 602.5625 761 z ',
      ],
    ),
    _LambRegion.paths(
      cut: 'Tenderloin',
      pathData: const [
        'M 958 367 A 23 23 0 0 0 935 390 A 23 23 0 0 0 958 413 L 1018 413 A 23 23 0 0 0 1041 390 A 23 23 0 0 0 1018 367 L 958 367 z ',
      ],
    ),
    _LambRegion.rects(
      cut: 'Whole Lamb',
      rects: const [Rect.fromLTWH(222, 1042, 287, 76)],
    ),
    _LambRegion.rects(
      cut: 'Trim / Manufacturing',
      rects: const [Rect.fromLTWH(536, 1042, 465, 76)],
    ),
    _LambRegion.rects(
      cut: 'Offal / Other',
      rects: const [Rect.fromLTWH(1028, 1042, 286, 76)],
    ),
  ];

  String? _cutAt(Offset localPosition, Size size) {
    if (size.isEmpty) return null;

    final svgPoint = Offset(
      localPosition.dx * _viewBoxWidth / size.width,
      localPosition.dy * _viewBoxHeight / size.height,
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
                        if (cut != null) {
                          widget.onCutSelected(cut);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SvgPicture.asset(widget.assetPath, fit: BoxFit.fill),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _LambHighlightPainter(
                                regions: _regions,
                                selectedCut: widget.selectedCut,
                                hoveredCut: _hoveredCut,
                                interactionColour: _interactionColour,
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

class _LambRegion {
  const _LambRegion._({
    required this.cut,
    required this.paths,
    required this.rects,
  });

  factory _LambRegion.paths({
    required String cut,
    required List<String> pathData,
  }) {
    return _LambRegion._(
      cut: cut,
      paths: pathData.map(parseSvgPathData).toList(),
      rects: const [],
    );
  }

  factory _LambRegion.rects({required String cut, required List<Rect> rects}) {
    return _LambRegion._(cut: cut, paths: const [], rects: rects);
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

class _LambHighlightPainter extends CustomPainter {
  const _LambHighlightPainter({
    required this.regions,
    required this.selectedCut,
    required this.hoveredCut,
    required this.interactionColour,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
  });

  final List<_LambRegion> regions;
  final String? selectedCut;
  final String? hoveredCut;
  final Color interactionColour;
  final double viewBoxWidth;
  final double viewBoxHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final sx = size.width / viewBoxWidth;
    final sy = size.height / viewBoxHeight;

    canvas.save();
    canvas.scale(sx, sy);

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
        final rounded = RRect.fromRectAndRadius(
          rect,
          const Radius.circular(15),
        );
        canvas.drawRRect(rounded, fill);
        canvas.drawRRect(rounded, outline);
      }

      for (final path in region.paths) {
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LambHighlightPainter oldDelegate) {
    return oldDelegate.selectedCut != selectedCut ||
        oldDelegate.hoveredCut != hoveredCut ||
        oldDelegate.interactionColour != interactionColour;
  }
}
