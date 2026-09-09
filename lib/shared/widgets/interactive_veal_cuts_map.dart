import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

abstract final class CutLinkVealCutKeys {
  static const wholeVeal = 'Whole Veal';
  static const forequarter = 'Forequarter';
  static const shoulderBlade = 'Shoulder / Blade';
  static const neck = 'Neck';
  static const brisketBreast = 'Brisket / Breast';
  static const rackRib = 'Rack / Rib';
  static const loin = 'Loin';
  static const tenderloin = 'Tenderloin';
  static const legRound = 'Leg / Round';
  static const rump = 'Rump';
  static const shinShank = 'Shin / Shank';
  static const flankFlap = 'Flank / Flap';
  static const trimManufacturing = 'Trim / Manufacturing';
  static const bonesOffal = 'Bones / Offal';
}

class InteractiveVealCutsMap extends StatefulWidget {
  const InteractiveVealCutsMap({
    super.key,
    required this.onCutSelected,
    this.selectedCut,
    this.assetPath = 'assets/images/CutLink-Veal-Cuts.svg',
    this.maxWidth = 1000,
    this.borderRadius = 16,
  });

  final ValueChanged<String> onCutSelected;
  final String? selectedCut;
  final String assetPath;
  final double maxWidth;
  final double borderRadius;

  @override
  State<InteractiveVealCutsMap> createState() => _InteractiveVealCutsMapState();
}

class _InteractiveVealCutsMapState extends State<InteractiveVealCutsMap> {
  static const double _viewBoxLeft = 0;
  static const double _viewBoxTop = 0;
  static const double _viewBoxWidth = 1600;
  static const double _viewBoxHeight = 1190;
  static const Color _interactionColour = Color(0xFF082A54);

  String? _hoveredCut;

  static final List<_VealRegion> _regions = [
    _VealRegion.paths(
      cut: 'Neck',
      pathData: const [
        'M 408 148 L 382 342 L 460 406 L 531 350 C 534.50294 344.29755 537.77078 338.46017 540.80469 332.48828 C 543.8386 326.51639 546.6379 320.40911 549.20312 314.16797 C 551.76835 307.92683 554.10041 301.55122 556.19727 295.04102 C 558.29413 288.53082 560.15632 281.88649 561.78516 275.10742 C 563.41399 268.32836 564.80957 261.41493 565.9707 254.36719 C 567.13184 247.31944 568.05818 240.13849 568.75195 232.82227 C 569.44573 225.50604 569.90607 218.05523 570.13281 210.4707 C 570.35955 202.88618 570.35324 195.16708 570.11328 187.31445 C 561.65243 186.63028 554.93843 185.22231 546.5 182.49023 C 539.69702 180.28887 533.68067 177.73174 525.57227 173.40039 L 408 148 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Shoulder / Blade',
      pathData: const [
        'M 570.11328 187.31445 C 572.03294 250.13547 559.02348 304.38037 531 350 L 603 438 L 729 388 L 716.91211 202.96289 C 713.51463 202.59511 709.37707 202.41489 706.5 201.91992 C 703.2 201.34992 693.07998 199.14 684 197 C 648.52008 188.63002 631.89992 186.90047 595 187.73047 C 584.17896 187.97501 576.67219 187.84483 570.11328 187.31445 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Forequarter',
      pathData: const [
        'M 729 388 L 603 438 L 550 567 L 558.83008 635.54297 C 560.30169 631.70069 562.68554 625.68025 563 624.67969 C 563.66 622.57969 564.45 621.11992 564.75 621.41992 C 566.71 623.37992 568.19922 638.60006 568.94922 664.5 C 569.84922 695.50994 570.22094 697.98018 575.96094 711.91016 C 578.33457 717.65542 582.25482 723.83949 586.73438 730 L 663.42969 730 C 664.02077 726.25157 664.69597 722.55719 665.58008 719 C 667.24008 712.30002 668.24984 705.35053 668.33984 699.81055 L 668.5 691.11914 L 670.15039 694.30078 L 671.80078 697.49023 L 672.55078 692.51953 C 673.04078 689.22953 672.65969 683.13928 671.42969 674.5293 C 666.89969 642.76936 669.41955 596.26941 677.01953 571.68945 L 679.0293 565.17969 L 685.75977 562 C 689.46975 560.25 693.54078 558.62086 694.80078 558.38086 C 695.08417 558.3273 696.8305 557.63204 697.47852 557.42773 L 729 388 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Brisket / Breast',
      pathData: const [
        'M 382 342 L 387.53711 410.60547 C 389.42778 415.40595 391.67159 420.97804 394.15039 425.85938 C 400.57037 438.48934 402.37025 443.74002 403.99023 454.5 C 407.03023 474.77996 411.95916 488.58088 420.36914 500.38086 C 425.83914 508.04084 436.24977 518.74047 436.75977 517.23047 C 437.70975 514.38047 462.33961 544.21986 464.09961 550.33984 C 465.30203 554.50824 466.05319 567.59704 466.42773 581.38477 L 550 602 L 550 567 L 603 438 L 531 350 L 460 406 L 382 342 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Rack / Rib',
      pathData: const [
        'M 903.13672 192.01367 C 901.3089 192.25649 901.41525 192.22591 899.5 192.48047 C 876.95004 195.48047 851.74998 198.62094 843.5 199.46094 C 789.42607 204.95665 745.02046 206.00566 716.91211 202.96289 L 729 388 C 741.83331 393.99999 755.37501 398.66667 769.625 402 C 776.74999 403.66666 784.05209 405 791.53125 406 C 799.01041 407 806.66667 407.66667 814.5 408 C 822.33333 408.33333 830.34376 408.33333 838.53125 408 C 846.71874 407.66667 855.08334 407 863.625 406 C 872.16666 405 880.88543 403.66666 889.78125 402 C 898.67707 400.33334 907.75002 398.33333 917 396 L 903.13672 192.01367 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Loin',
      pathData: const [
        'M 1090.0566 168.76562 C 1086.3262 169.46251 1084.7235 169.58385 1080 170.50977 C 1045.41 177.27974 1041.22 177.87026 1015.5 179.49023 C 982.65614 181.55884 976.70242 182.24072 903.13672 192.01367 L 917 396 L 1094 392 L 1092 300 L 1090.0566 168.76562 z M 1092 300 C 1092.1245 299.96127 1092.2524 299.92923 1092.377 299.89062 L 1092.377 299.88867 C 1092.2521 299.92736 1092.1248 299.96119 1092 300 z M 958 324 L 1034 324 A 23 23 0 0 1 1038.25 324.41797 A 23 23 0 0 1 1038.582 324.4707 A 23 23 0 0 1 1042.4883 325.6543 A 23 23 0 0 1 1042.9688 325.83984 A 23 23 0 0 1 1046.4785 327.7168 A 23 23 0 0 1 1046.9766 328.03906 A 23 23 0 0 1 1050.0137 330.53125 A 23 23 0 0 1 1050.4688 330.98633 A 23 23 0 0 1 1052.9609 334.02344 A 23 23 0 0 1 1053.2832 334.52148 A 23 23 0 0 1 1055.1602 338.03125 A 23 23 0 0 1 1055.3457 338.51172 A 23 23 0 0 1 1056.5293 342.41797 A 23 23 0 0 1 1056.582 342.75 A 23 23 0 0 1 1057 347 A 23 23 0 0 1 1054.2305 357.33594 A 23 23 0 0 1 1053.3438 359.07422 A 23 23 0 0 1 1046.0742 366.34375 A 23 23 0 0 1 1044.3359 367.23047 A 23 23 0 0 1 1034 370 L 958 370 A 23 23 0 0 1 947.66406 367.23047 A 23 23 0 0 1 945.92578 366.34375 A 23 23 0 0 1 938.65625 359.07422 A 23 23 0 0 1 937.76953 357.33594 A 23 23 0 0 1 935 347 A 23 23 0 0 1 937.76953 336.66406 A 23 23 0 0 1 938.65625 334.92578 A 23 23 0 0 1 945.92578 327.65625 A 23 23 0 0 1 947.66406 326.76953 A 23 23 0 0 1 958 324 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Tenderloin',
      pathData: const [
        'M 958 324 A 23 23 0 0 0 935 347 A 23 23 0 0 0 958 370 L 1034 370 A 23 23 0 0 0 1057 347 A 23 23 0 0 0 1034 324 L 958 324 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Rump',
      pathData: const [
        'M 1138.4434 163.56641 L 1121.6348 164.06445 C 1113.4777 164.58772 1103.1009 166.32743 1090.0566 168.76562 L 1092 300 C 1099.4048 297.69628 1106.9265 295.62453 1114.5547 293.76758 C 1114.7955 293.70896 1115.0383 293.65388 1115.2793 293.5957 C 1122.6945 291.80597 1130.2159 290.22967 1137.8418 288.86133 C 1138.2227 288.79298 1138.6049 288.72745 1138.9863 288.66016 C 1146.5484 287.32599 1154.2137 286.19828 1161.9824 285.27734 C 1162.3743 285.23088 1162.7658 285.18408 1163.1582 285.13867 C 1171.0147 284.22963 1178.9758 283.52857 1187.043 283.04102 C 1187.302 283.02536 1187.5591 283.00545 1187.8184 282.99023 C 1196.1334 282.50205 1204.5552 282.22865 1213.0938 282.1875 C 1221.4228 282.14736 1229.8704 282.34329 1238.4121 282.72852 C 1238.9919 282.75466 1239.5696 282.77658 1240.1504 282.80469 C 1248.5213 283.20982 1256.9939 283.82054 1265.5684 284.63281 C 1266.1633 284.68918 1266.7615 284.75027 1267.3574 284.80859 C 1276.136 285.66771 1285.0088 286.71554 1294 288 L 1266.3242 186.78711 C 1254.9141 181.49422 1244.7795 179.07586 1206.3594 172.10938 C 1161.739 164.02001 1158.0271 163.5545 1138.4434 163.56641 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Leg / Round',
      pathData: const [
        'M 1213.0938 282.1875 C 1169.8646 282.39583 1129.5 288.33336 1092 300 L 1094 392 L 1040 500 L 1180 649 L 1194.8027 671.31445 C 1200.0162 657.39641 1200.1505 647.03115 1195.1602 634.66992 C 1193.4202 630.36994 1192 626.55922 1192 626.19922 C 1192 624.71922 1210.3404 644.61047 1214.1504 650.23047 C 1216.4304 653.58047 1220.6398 661.99016 1223.5098 668.91016 C 1231.6998 688.71012 1236.1993 696.83088 1246.6191 710.63086 C 1255.0163 721.76518 1261.4185 732.95378 1266.957 746.33789 L 1333.2012 734.18359 C 1332.6325 727.18244 1332.0028 720.75376 1331.5098 712.93945 C 1330.0898 690.53951 1329.5602 684.52918 1327.4102 666.69922 C 1327.0302 663.50922 1327.2998 652.0292 1328.0098 641.19922 C 1330.0898 609.64928 1328.4503 604.51918 1310.5703 586.69922 C 1304.3903 580.53922 1296.8298 572.12 1293.7598 568 C 1281.9698 552.12004 1272.4098 529.62051 1270.0098 512.06055 C 1269.3898 507.52055 1268.4595 502.69984 1267.9395 501.33984 C 1266.4995 497.54986 1266.8205 477.03996 1268.5605 462 C 1270.7005 443.49004 1273.7902 428.22994 1281.9102 396 C 1285.2221 382.87169 1287.3341 373.35247 1289.4258 363.80273 L 1294 288 C 1266 284 1239.0311 282.0625 1213.0938 282.1875 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Shin / Shank',
      pathData: const [
        'M 586.73438 730 C 588.89779 732.97526 590.94675 735.97393 593.48047 738.85938 C 602.32045 748.90934 606.33064 758.7102 611.39062 782.66016 C 616.08062 804.8701 617.20975 832.27049 614.00977 845.73047 C 611.73977 855.26045 611.0207 864.07002 611.9707 870.75 C 613.5007 881.56998 609.48084 893.96041 600.63086 905.65039 C 598.08086 909.03039 595.3293 913.31039 594.5293 915.15039 C 594.01707 916.32851 591.52396 919.93327 589.48438 923 L 664.76758 923 C 664.86272 921.82128 664.99702 920.94366 665.08008 919.57031 C 666.00008 904.45035 667.51072 899.46943 673.7207 891.18945 C 676.0707 888.03947 676.30055 887.96055 678.06055 889.56055 C 680.47053 891.74053 682.48008 890.89961 684.58008 886.84961 C 689.07006 878.16963 687.3599 865.81924 677.91992 838.7793 C 663.45473 797.31655 658.61205 760.55147 663.42969 730 L 586.73438 730 z M 1333.2012 734.18359 L 1266.957 746.33789 C 1268.8849 750.99666 1270.7169 755.90143 1272.4805 761.18945 C 1282.6605 791.73939 1286.0802 810.56022 1286.7402 839.66016 C 1287.2702 863.5201 1286.6609 869.68988 1282.4609 882.83984 C 1280.1509 890.09984 1278.66 892.96002 1270.4102 906 C 1268.4902 909.02 1266.6505 912.62 1266.3105 914 C 1266.0905 914.92003 1263.3105 919.30651 1261.043 923 L 1334.7695 923 C 1334.7795 921.55881 1334.9224 921.0689 1334.9004 919 C 1334.7604 905.88002 1336.5592 898.47006 1341.9492 890.08008 C 1346.5892 882.8401 1347.7907 882.07094 1349.9707 884.96094 C 1352.3207 888.07092 1354.3591 887.17078 1357.1191 881.80078 C 1358.6291 878.86078 1359.4602 875.12998 1359.7402 870 C 1360.1902 861.85002 1359.57 859.34994 1350.6602 833.5 C 1341.9175 808.16088 1336.7852 778.30481 1333.2012 734.18359 z ',
      ],
    ),
    _VealRegion.paths(
      cut: 'Flank / Flap',
      pathData: const [
        'M 729 388 L 697.47852 557.42773 C 699.73452 556.71648 702.66015 555.74853 706.80078 554.10938 C 719.88076 548.93938 727.13004 546.63906 742.5 542.78906 C 755.02998 539.64908 756.22004 539.53055 775.5 539.56055 C 792.76996 539.58055 797.48002 539.94025 810 542.24023 C 817.97998 543.70023 829.67002 545.3807 836 545.9707 C 851.86996 547.4607 858.81018 548.67033 870.91016 552.07031 C 883.67012 555.65031 895.67955 557.74992 907.26953 558.41992 C 916.16951 558.92992 923.32961 561.20908 927.34961 564.78906 C 929.18961 566.42906 929.23953 566.41 928.51953 564 C 928.09953 562.62 926.67008 560.04 925.33008 558.25 C 923.99008 556.46 923.21938 555 923.60938 555 C 925.79936 555 934.92 563.37908 937 567.28906 L 937.99414 569.16406 L 942.15039 569.32031 L 944.88086 566.82031 C 952.55084 559.82033 964.42992 552 967.41992 552 C 970.97992 552 990.7808 541.70014 999.30078 535.41016 C 999.62444 535.17108 999.96897 534.9792 1000.2949 534.74219 L 1040 500 L 1094 392 L 917 396 C 843.00014 414.66663 780.33323 411.99996 729 388 z ',
      ],
    ),
    _VealRegion.rects(
      cut: 'Whole Veal',
      rects: const [Rect.fromLTWH(222, 1042, 287, 76)],
    ),
    _VealRegion.rects(
      cut: 'Trim / Manufacturing',
      rects: const [Rect.fromLTWH(536, 1042, 465, 76)],
    ),
    _VealRegion.rects(
      cut: 'Bones / Offal',
      rects: const [Rect.fromLTWH(1028, 1042, 286, 76)],
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
                              painter: _VealHighlightPainter(
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

class _VealRegion {
  const _VealRegion._({
    required this.cut,
    required this.paths,
    required this.rects,
  });

  factory _VealRegion.paths({
    required String cut,
    required List<String> pathData,
  }) {
    return _VealRegion._(
      cut: cut,
      paths: pathData.map(parseSvgPathData).toList(),
      rects: const [],
    );
  }

  factory _VealRegion.rects({required String cut, required List<Rect> rects}) {
    return _VealRegion._(cut: cut, paths: const [], rects: rects);
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

class _VealHighlightPainter extends CustomPainter {
  const _VealHighlightPainter({
    required this.regions,
    required this.selectedCut,
    required this.hoveredCut,
    required this.interactionColour,
    required this.viewBoxLeft,
    required this.viewBoxTop,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
  });

  final List<_VealRegion> regions;
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
  bool shouldRepaint(covariant _VealHighlightPainter oldDelegate) {
    return oldDelegate.selectedCut != selectedCut ||
        oldDelegate.hoveredCut != hoveredCut ||
        oldDelegate.interactionColour != interactionColour;
  }
}
