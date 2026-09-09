import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

abstract final class CutLinkBeefCutKeys {
  static const cheek = 'cheek';
  static const neck = 'neck';
  static const shoulder = 'shoulder';
  static const chuck = 'chuck';
  static const blade = 'blade';
  static const brisket = 'brisket';
  static const shinShank = 'shin-shank';
  static const ribs = 'ribs';
  static const ribEye = 'rib-eye';
  static const plate = 'plate';
  static const skirt = 'skirt';
  static const loin = 'loin';
  static const flank = 'flank';
  static const rump = 'rump';
  static const round = 'round';
  static const silversideOutside = 'silverside-outside';
  static const oxTail = 'ox-tail';
  static const miscOffalOther = 'misc-offal-other';

  static const all = <String>[
    cheek,
    neck,
    shoulder,
    chuck,
    blade,
    brisket,
    shinShank,
    ribs,
    ribEye,
    plate,
    skirt,
    loin,
    flank,
    rump,
    round,
    silversideOutside,
    oxTail,
    miscOffalOther,
  ];
}

class InteractiveBeefCutsMap extends StatefulWidget {
  const InteractiveBeefCutsMap({
    super.key,
    required this.onCutSelected,
    this.selectedCut,
    this.assetPath = 'assets/images/CutLink-Beef-Cuts.svg',
    this.maxWidth = 1000,
    this.borderRadius = 16,
  });

  final ValueChanged<String> onCutSelected;
  final String? selectedCut;
  final String assetPath;
  final double maxWidth;
  final double borderRadius;

  @override
  State<InteractiveBeefCutsMap> createState() => _InteractiveBeefCutsMapState();
}

class _InteractiveBeefCutsMapState extends State<InteractiveBeefCutsMap> {
  static const double _viewBoxWidth = 1660;
  static const double _viewBoxHeight = 1125;
  static const Color _interactionColour = Color(0xFF082A54);

  String? _hoveredCut;

  static final List<_BeefRegion> _regions = [
    _BeefRegion.paths(
      cut: 'cheek',
      pathData: const [
        'M 230 248 A 65 31 0 0 0 165 279 A 65 31 0 0 0 295 279 A 65 31 0 0 0 230 248 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'neck',
      pathData: const [
        'M 460 140 L 306 149 L 282.5293 260.76758 A 65 31 0 0 1 295 279 A 65 31 0 0 1 273.92969 301.71484 L 264 349 L 269.40234 358.75586 C 271.29487 361.32091 273.36937 364.3134 275.81055 368.00977 C 280.71053 375.44975 285.45938 382.14064 286.35938 382.89062 C 287.25936 383.63062 288 384.81025 288 385.49023 C 288 386.18023 290.21969 391.40916 292.92969 397.11914 C 295.55221 402.64437 297.86539 408.223 300.03906 413.97852 L 450 330 L 460 140 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'shoulder',
      pathData: const [
        'M 450 330 L 300.03906 413.97852 C 304.02226 424.52535 307.3238 436.27201 310.3457 449.5918 L 325 500 L 430 580 L 550 450 L 450 330 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'chuck',
      pathData: const [
        'M 460 140 L 450 330 L 550 450 L 690 430 L 690 160 L 597.09375 151.92188 L 557.5 151.31055 L 544.32422 147.33203 L 460 140 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'blade',
      pathData: const ['M 690 430 L 550 450 L 430 580 L 680 590 L 690 430 z '],
    ),
    _BeefRegion.paths(
      cut: 'brisket',
      pathData: const [
        'M 325 500 L 356.44531 577.68945 C 360.76493 582.87138 365.95629 589.63158 369.65039 595.2207 C 382.56391 614.78184 396.35887 628.15456 413.875 638.625 L 493 665 L 625 615 L 680 590 L 430 580 L 325 500 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'shin-shank',
      pathData: const [
        'M 607.08008 734.45898 L 505 744 L 511.0918 764.50586 C 511.66971 762.84252 512.08116 760.81787 512.75977 759.25 C 514.72975 754.71 516.59992 751.02078 516.91992 751.05078 C 518.56992 751.19078 528.55086 769.05963 530.63086 775.59961 C 536.42101 793.86086 537.54841 818.53326 533.66406 840.50391 L 535 845 L 532.46484 848.51172 C 531.58455 853.96957 530.5708 859.99661 530.23047 863.17969 C 529.03047 874.43967 526.16029 880.21025 516.57031 890.74023 C 512.44033 895.28023 508.32016 900.45025 507.41016 902.24023 C 506.51016 904.03023 502.73906 910.00002 499.03906 915.5 C 496.63517 919.07386 495.49255 921.13112 493.67383 924 L 589.83984 924 C 590.95458 919.98163 590.70496 916.23916 589.03906 911.08008 C 586.85906 904.32008 587.03008 899.41006 589.58008 895.33008 C 590.80008 893.39008 591.30025 893.27977 594.49023 894.25977 C 599.49023 895.78975 604.54072 893.31023 606.7207 888.24023 C 609.2907 882.28025 608.87023 872.61998 605.74023 865.5 C 598.98025 850.13004 593.03977 801.68996 595.00977 778 C 596.08975 765.05002 596.50922 763.30928 600.94922 753.5293 C 604.06 746.682 605.90339 740.86846 607.08008 734.45898 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'shin-shank',
      pathData: const [
        'M 1398.2344 753.38086 L 1327.6348 775.54492 C 1332.3312 786.42102 1336.6772 799.53463 1340.5195 815 C 1342.17 821.6313 1342.8371 828.07923 1343.4141 838.24023 L 1347 849 L 1344.1543 854.63281 C 1344.9734 880.27751 1343.5585 885.06055 1331.9805 898.5 C 1329.1405 901.8 1325.5898 906.98 1324.0898 910 C 1322.5898 913.02 1319.7796 917.98 1317.8496 921 C 1313.4566 927.89725 1308.8886 936.81661 1305.9824 943.25391 L 1405.375 932.63086 C 1406.4371 930.09802 1407 927.90733 1407 924.99023 C 1407 921.92025 1406.0699 916.77975 1404.9199 913.50977 C 1402.7599 907.34977 1402.8695 901.56078 1405.2695 896.30078 C 1406.2895 894.08078 1406.7807 893.92 1410.9707 894.5 C 1419.2407 895.63 1423.3509 889.83998 1423.3809 877 C 1423.4009 871.82002 1422.7602 869.07998 1420.2402 863.5 C 1416.4202 855.05002 1414.9998 850.00074 1411.0098 830.55078 C 1405.5509 804.0037 1401.2791 777.5262 1398.2344 753.38086 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'ribs',
      pathData: const [
        'M 690 160 L 690 430 L 952 450 L 940 170 L 881.00586 167.64062 C 869.11262 167.96239 857.55011 168.52088 845 168.67969 C 781.84917 169.4704 748.38732 167.50788 704.70312 160.58789 L 690 160 z M 819 223 A 73 31 0 0 1 892 254 A 73 31 0 0 1 746 254 A 73 31 0 0 1 819 223 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'rib-eye',
      pathData: const [
        'M 819 223 A 73 31 0 0 0 746 254 A 73 31 0 0 0 892 254 A 73 31 0 0 0 819 223 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'plate',
      pathData: const [
        'M 690 430 L 680 590 L 625 615 L 652.34375 618.55859 C 660.41149 617.41294 669.24498 616.94624 677 617.42969 C 691.08998 618.30969 705.92008 620.74072 747.5 628.9707 C 762.62497 631.96752 770.99306 633.45298 780.91797 635.29492 L 930 654.69922 L 930.00391 654.69922 C 933.93973 654.49556 937.11139 654.12616 940.13867 653.61523 L 952 450 L 690 430 z M 802 563 A 69 27 0 0 1 871 590 A 69 27 0 0 1 733 590 A 69 27 0 0 1 802 563 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'skirt',
      pathData: const [
        'M 802 563 A 69 27 0 0 0 733 590 A 69 27 0 0 0 871 590 A 69 27 0 0 0 802 563 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'loin',
      pathData: const [
        'M 1130 153 L 940 170 L 952 450 L 1140 420 L 1130 153 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'flank',
      pathData: const [
        'M 1140 420 L 952 450 L 940.13867 653.61523 C 946.92334 652.47018 952.84097 650.25049 964 645.00977 C 974.90774 639.89359 984.84238 635.70141 995.23242 631.64062 L 1135 570 L 1140 420 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'rump',
      pathData: const [
        'M 1291.2109 136.07812 L 1130 153 L 1140 420 C 1143.2077 413.98552 1146.5102 408.21321 1149.8867 402.63281 C 1150.1831 402.14301 1150.4816 401.66029 1150.7793 401.17383 C 1153.985 395.93488 1157.2665 390.88819 1160.623 386.03711 C 1160.8901 385.65109 1161.1538 385.25661 1161.4219 384.87305 C 1164.9664 379.80115 1168.5893 374.93348 1172.3008 370.29102 C 1172.4631 370.08799 1172.6303 369.89557 1172.793 369.69336 C 1176.4006 365.20792 1180.0907 360.93482 1183.8555 356.85352 C 1184.2154 356.46337 1184.5762 356.07591 1184.9375 355.68945 C 1188.6977 351.66778 1192.5316 347.83656 1196.4473 344.21484 C 1196.65 344.02732 1196.8496 343.83099 1197.0527 343.64453 C 1201.1244 339.90779 1205.2824 336.39201 1209.5215 333.08594 C 1209.8071 332.86317 1210.0964 332.6505 1210.3828 332.42969 C 1214.4299 329.3094 1218.555 326.38999 1222.7539 323.66016 C 1223.1588 323.39693 1223.5625 323.13069 1223.9688 322.87109 C 1228.3527 320.07008 1232.8111 317.46039 1237.3594 315.08203 C 1237.4282 315.04606 1237.4956 315.00658 1237.5645 314.9707 C 1242.1699 312.57026 1246.8669 310.40703 1251.6406 308.43945 C 1252.0421 308.27398 1252.447 308.11749 1252.8496 307.95508 C 1257.3775 306.12878 1261.9798 304.49385 1266.6582 303.05469 C 1267.0551 302.9326 1267.4497 302.80485 1267.8477 302.68555 C 1272.7963 301.20204 1277.8233 299.91795 1282.9395 298.86523 C 1283.0953 298.83316 1283.2541 298.80901 1283.4102 298.77734 C 1288.4181 297.76075 1293.5115 296.96403 1298.6797 296.35938 C 1299.1734 296.30162 1299.6689 296.24931 1300.1641 296.19531 C 1305.2393 295.64182 1310.3884 295.27772 1315.6172 295.11914 C 1315.9339 295.10953 1316.2471 295.09019 1316.5645 295.08203 C 1319.3017 295.01166 1322.0548 294.98206 1324.834 295.01953 C 1327.1453 295.05069 1329.4956 295.18331 1331.8359 295.28906 C 1332.7002 295.32811 1333.5536 295.33945 1334.4219 295.38867 C 1339.5564 295.67979 1344.7701 296.17149 1350.043 296.81836 C 1351.1902 296.95911 1352.3462 297.12171 1353.5 297.2793 C 1358.9362 298.02176 1364.4184 298.88368 1370 300 L 1355 250 L 1314.3867 142.92969 C 1312.738 142.34748 1310.8842 141.93782 1309.7598 141.36914 C 1304.9055 138.91665 1298.3299 137.26414 1291.2109 136.07812 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'round',
      pathData: const [
        'M 1324.834 295.01953 C 1246.6115 293.96484 1185 335.62516 1140 420 L 1135 570 L 1240 678 L 1264.9355 707.74414 C 1267.0731 701.9405 1268.2894 697.48506 1268.6699 693.84961 C 1269.0099 690.62961 1269.6405 688 1270.0605 688 C 1272.0505 688 1279.5396 698.60049 1285.5996 709.98047 C 1294.3996 726.49043 1298.9799 733.48049 1308.9199 745.48047 C 1313.4599 750.97045 1318.8902 758.39047 1320.9902 761.98047 C 1323.2878 765.91951 1325.4864 770.56969 1327.6348 775.54492 L 1398.2344 753.38086 C 1395.1509 728.92816 1393.4732 707.26809 1393.5078 690.87695 L 1389.3145 653.97266 L 1373.5586 630.33789 C 1369.4147 624.94231 1365.7844 619.5483 1362.7598 614.13867 L 1350 595 L 1352.1895 586.5332 C 1349.614 574.51784 1349.3647 562.11893 1351.5996 548.92969 C 1352.4696 543.73969 1356.0906 530.72998 1359.6406 520 C 1369.4258 490.4209 1374.8445 469.92055 1378.3438 449.36914 L 1370 300 C 1354.375 296.875 1339.3196 295.21484 1324.834 295.01953 z M 1260 474 A 77 43 0 0 1 1337 517 A 77 43 0 0 1 1183 517 A 77 43 0 0 1 1260 474 z M 1391.4102 657.11523 C 1391.7302 658.08854 1392.0078 659.0997 1392.2539 660.13672 C 1392.0946 659.43715 1392.0962 658.5241 1391.9023 657.85352 L 1391.4102 657.11523 z M 1393.2129 666.375 C 1393.3787 667.97935 1393.5007 669.68714 1393.5664 671.5332 C 1393.5147 669.73564 1393.3577 667.94141 1393.2129 666.375 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'silverside-outside',
      pathData: const [
        'M 1260 474 A 77 43 0 0 0 1183 517 A 77 43 0 0 0 1337 517 A 77 43 0 0 0 1260 474 z ',
      ],
    ),
    _BeefRegion.paths(
      cut: 'ox-tail',
      pathData: const [
        'M 1388 415 L 1387.9961 415.20898 C 1397.1057 497.27574 1398.1757 524.22205 1393.4609 555.92969 C 1391.2909 570.55967 1390.8791 575.45977 1391.7891 575.75977 C 1392.6591 576.04977 1393 579.97087 1393 589.63086 C 1393 602.52085 1394.6092 614.45985 1397.1992 620.83984 L 1398.2793 623.5 L 1398.9492 621 C 1399.4892 618.98 1399.8606 619.76001 1400.8906 625 C 1403.8006 639.85999 1412.1 659.18009 1421 671.83008 C 1423.84 675.87007 1426.3391 678.99906 1426.5391 678.78906 C 1426.7491 678.57906 1425.7997 674.88031 1424.4297 670.57031 C 1421.8697 662.51032 1421.7791 659.16063 1424.2891 665.14062 C 1425.0591 666.99062 1427.3394 671.07071 1429.3594 674.2207 C 1436.6494 685.60069 1445.9395 709.74923 1446.2695 718.19922 C 1446.3595 720.28922 1446.5798 722 1446.7598 722 C 1447.8698 722 1450.9602 712.85 1450.9902 709.5 C 1451.0102 707.3 1451.4206 704.89062 1451.8906 704.14062 C 1452.8506 702.63063 1455.6199 716.12087 1456.6699 727.38086 C 1457.2699 733.83085 1457.3499 733.98984 1459.1699 732.33984 C 1464.8799 727.17985 1471.9894 706.54951 1473.8594 689.76953 C 1474.7094 682.09954 1475.3801 682.28001 1476.5801 690.5 L 1477.3008 695.5 L 1478.6699 691 C 1483.5899 674.88002 1485.5691 649.12967 1483.0391 634.17969 C 1482.3491 630.15969 1482.0398 626.63008 1482.3398 626.33008 C 1482.6298 626.03008 1484.0197 629.33039 1485.4297 633.65039 L 1487.9805 641.5 L 1487.5801 628.5 C 1487.2701 618.49001 1486.5703 613.33937 1484.5703 606.10938 C 1481.6103 595.45939 1476.0291 583.05937 1470.6191 575.10938 C 1466.8291 569.53938 1466.2293 566.92922 1469.7793 571.44922 C 1472.8093 575.29921 1474.1505 574.68968 1472.5605 570.17969 C 1469.3406 561.0597 1464.6007 553.27913 1453.4707 538.86914 C 1448.1407 531.96915 1440 519.00039 1440 517.40039 C 1440 516.99039 1441.01 517.55969 1442.25 518.67969 C 1446.88 522.84968 1446.6698 521.72975 1440.7598 510.75977 C 1431.0181 492.69213 1427.9432 485.57167 1423.707 457.50977 L 1388 415 z M 1389.0312 651.47852 L 1393.6953 692.52539 C 1393.6932 689.85045 1393.43 686.38134 1393.5195 684 C 1394.1402 667.55435 1393.2479 659.50979 1389.0312 651.47852 z ',
      ],
    ),
    _BeefRegion.rects(
      cut: 'ox-tail',
      rects: const [Rect.fromLTWH(1520, 500, 128, 68)],
    ),
    _BeefRegion.rects(
      cut: 'misc-offal-other',
      rects: const [Rect.fromLTWH(534, 1014, 618, 68)],
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
                              painter: _BeefHighlightPainter(
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

class _BeefRegion {
  const _BeefRegion._({
    required this.cut,
    required this.paths,
    required this.rects,
  });

  factory _BeefRegion.paths({
    required String cut,
    required List<String> pathData,
  }) {
    return _BeefRegion._(
      cut: cut,
      paths: pathData.map(parseSvgPathData).toList(),
      rects: const [],
    );
  }

  factory _BeefRegion.rects({required String cut, required List<Rect> rects}) {
    return _BeefRegion._(cut: cut, paths: const [], rects: rects);
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

class _BeefHighlightPainter extends CustomPainter {
  const _BeefHighlightPainter({
    required this.regions,
    required this.selectedCut,
    required this.hoveredCut,
    required this.interactionColour,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
  });

  final List<_BeefRegion> regions;
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
  bool shouldRepaint(covariant _BeefHighlightPainter oldDelegate) {
    return oldDelegate.selectedCut != selectedCut ||
        oldDelegate.hoveredCut != hoveredCut ||
        oldDelegate.interactionColour != interactionColour;
  }
}
