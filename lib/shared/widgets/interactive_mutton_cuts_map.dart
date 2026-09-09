import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

class InteractiveMuttonCutsMap extends StatefulWidget {
  const InteractiveMuttonCutsMap({
    super.key,
    required this.onCutSelected,
    this.selectedCut,
    this.assetPath = 'assets/images/CutLink-Mutton-Cuts.svg',
    this.maxWidth = 1000,
    this.borderRadius = 16,
  });

  final ValueChanged<String> onCutSelected;
  final String? selectedCut;
  final String assetPath;
  final double maxWidth;
  final double borderRadius;

  @override
  State<InteractiveMuttonCutsMap> createState() =>
      _InteractiveMuttonCutsMapState();
}

class _InteractiveMuttonCutsMapState extends State<InteractiveMuttonCutsMap> {
  static const double _viewBoxWidth = 1600;
  static const double _viewBoxHeight = 1190;
  static const Color _interactionColour = Color(0xFF082A54);

  String? _hoveredCut;

  static final List<_MuttonRegion> _regions = [
    _MuttonRegion.paths(
      cut: 'Neck',
      pathData: const [
        'M 373 122 L 306 273 L 337 462 L 499 392 C 503.66666 386.66668 508.16146 381.02603 512.48438 375.07812 C 516.80729 369.13022 520.95834 362.875 524.9375 356.3125 C 528.91666 349.75 532.72396 342.8802 536.35938 335.70312 C 539.99479 328.52605 543.45834 321.04166 546.75 313.25 C 550.04166 305.45834 553.16146 297.35937 556.10938 288.95312 C 559.05729 280.54688 561.83333 271.83332 564.4375 262.8125 C 567.04167 253.79168 569.47396 244.46353 571.73438 234.82812 C 573.99479 225.19272 576.08334 215.24998 578 205 L 518 164 L 373 122 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Shoulder',
      pathData: const [
        'M 578 205 C 562.6667 286.99984 536.33326 349.33342 499 392 L 563 510 L 725 463 L 712.15234 220.87109 C 706.43655 218.39316 695.81 216.00487 688.5 215.80078 C 684.90098 215.70481 682.69241 215.46669 680.84375 214.97656 L 578 205 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Forequarter',
      pathData: const [
        'M 725 463 L 563 510 L 513 671 L 531 782 L 535.76172 782 C 537.40992 772.45454 539.04211 764.01416 539.94922 761.67969 C 540.52922 760.20969 541.47078 757.79078 542.05078 756.30078 C 543.05078 753.75078 543.46094 754.34088 549.96094 767.63086 C 552.60199 773.03124 554.44133 777.52523 556.01562 782 L 612.77539 782 C 612.78039 770.61994 613.15385 766.37215 615.30078 757.5 C 618.40078 744.70002 619.98023 735.20006 619.99023 729.33008 C 620.00023 726.35008 620.7107 724.3107 622.4707 722.2207 C 625.6507 718.44072 627 714.81984 627 710.08984 C 627 707.51986 627.66961 705.70014 629.09961 704.41016 C 633.31961 700.59016 636.97023 690.30084 636.99023 682.13086 C 637.00023 678.71086 637.65 677.01961 640 674.34961 C 641.65 672.46961 643 670.54055 643 670.06055 C 643 669.58055 645.36 670.1007 648.25 671.2207 C 651.68296 672.53864 653.67499 672.73296 656.2207 672.45312 L 661 658 L 725 463 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Breast / Flap',
      pathData: const [
        'M 499 392 L 337 462 L 337 525.31641 C 339.33209 532.82765 342.34889 539.94922 346.50977 545.48047 C 350.14975 550.34045 351 552.23914 351 555.61914 C 351 567.98912 361.17963 587.81955 371.84961 596.26953 C 375.04961 598.79953 376.94039 601.52947 379.40039 607.18945 C 381.20039 611.33945 383.72977 616.25914 385.00977 618.11914 C 395.20975 632.87912 409.49088 643.87938 422.63086 647.10938 C 425.92086 647.90936 428.97078 649.66 432.05078 652.5 C 439.77076 659.62998 453.74986 665 464.58984 665 L 467.82031 665 L 467.9375 665.69922 L 513 671 L 563 510 L 499 392 z M 1102 447 L 940 471 C 930.75002 473.16666 921.53645 475.02084 912.35938 476.5625 C 903.1823 478.10416 894.04166 479.33334 884.9375 480.25 C 875.83334 481.16666 866.76562 481.77083 857.73438 482.0625 C 848.70313 482.35417 839.70833 482.33333 830.75 482 C 821.79167 481.66667 812.86979 481.02083 803.98438 480.0625 C 795.09896 479.10417 786.24999 477.83333 777.4375 476.25 C 768.62501 474.66667 759.84895 472.77083 751.10938 470.5625 C 742.3698 468.35417 733.66665 465.83333 725 463 L 661 658 L 661 672.05469 C 662.93057 671.94251 664.36725 672.2454 666.64062 673.78906 C 674.99062 679.45906 687.09002 681.48031 695.25 678.57031 C 698.66 677.36031 699.53916 677.44961 704.86914 679.59961 C 712.23912 682.57961 722.48977 684.07031 730.50977 683.32031 C 735.25975 682.87031 738.19961 683.22031 743.09961 684.82031 C 746.61961 685.96031 752.16969 687.36922 755.42969 687.94922 C 762.86967 689.26922 778.12033 689.27094 783.82031 687.96094 C 787.35031 687.14094 789.34033 687.34078 794.82031 689.05078 C 803.27029 691.69078 821.00955 692.72936 830.26953 691.10938 C 836.55951 690.01938 837.28977 690.1 843.00977 692.5 C 857.12973 698.44998 875.44988 700.98078 886.83984 698.55078 C 893.40984 697.15078 894.78047 697.15 899.98047 698.5 C 908.12045 700.61 918.47041 700.41928 925.40039 698.0293 C 930.81039 696.1693 931.4393 696.15039 937.2793 697.65039 C 948.63928 700.56039 961.73986 697.53062 970.83984 689.89062 C 974.49984 686.82064 975.05963 686.66984 983.59961 686.58984 C 991.58959 686.50984 993.25947 686.15047 999.18945 683.23047 C 1003.4894 681.11047 1007.5702 678.05984 1010.7402 674.58984 C 1014.8102 670.13986 1016.3803 669.12078 1020.0703 668.55078 C 1029.0303 667.17078 1039.6399 660.50092 1043.6699 653.71094 C 1044.1299 652.94094 1045.8994 652.04094 1047.6094 651.71094 C 1051.0694 651.04094 1051.26 651.29002 1055.25 662 C 1055.7976 663.46847 1056.8181 665.15274 1057.6309 666.78906 L 1100 599 L 1102 447 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Rack / Rib',
      pathData: const [
        'M 940 200.35938 C 939.38333 200.37979 939.17554 200.44318 938.5 200.46094 C 929.65002 200.69094 924.65998 201.3507 919.5 202.9707 C 915.65 204.1707 911.6 205.16945 910.5 205.18945 C 906.02 205.25945 896.11904 207.31 888.53906 209.75 C 881.10908 212.15 879.31998 212.31984 865 212.08984 C 846.94004 211.79984 833.99951 213.92016 820.26953 219.41016 C 812.75955 222.41014 811.53967 222.63031 806.42969 221.82031 C 799.93969 220.81031 784.27998 222.18025 776 224.49023 C 766.42002 227.17023 764.75998 227.21928 758.5 225.0293 C 749.11002 221.7493 735.67928 220.39945 725.2793 221.68945 C 718.1693 222.57945 715.99984 222.52016 713.83984 221.41016 C 713.46371 221.2163 712.59802 221.06431 712.15234 220.87109 L 725 463 C 794.33319 485.66662 866.00014 488.3333 940 471 L 940 200.35938 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Loin',
      pathData: const [
        'M 1083.7207 181.24609 L 1051.8281 185.18555 C 1050.6121 185.63195 1049.0495 185.95929 1048.0605 186.4707 C 1045.9905 187.5407 1041.67 188.14008 1034.75 188.33008 C 1026.85 188.55008 1023.13 189.15094 1018.5 190.96094 C 1015.2 192.25094 1011.38 193.24969 1010 193.17969 C 1000.5864 192.72594 997.14867 192.66846 992.42969 192.52344 L 961.84375 196.30078 C 960.25102 196.79057 958.31698 197.181 957.16016 197.61914 C 952.04516 199.55706 948.41147 200.08076 940 200.35938 L 940 471 L 1102 447 L 1109.8809 181.99023 C 1108.8799 182.16282 1107.671 182.18414 1106.7402 182.40039 C 1100.7202 183.80039 1099.3102 183.81 1093.7402 182.5 C 1090.8109 181.81022 1087.3178 181.46057 1083.7207 181.24609 z M 985 380 L 1062 380 A 23 23 0 0 1 1085 403 A 23 23 0 0 1 1062 426 L 985 426 A 23 23 0 0 1 962 403 A 23 23 0 0 1 985 380 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Chump / Rump',
      pathData: const [
        'M 1118.3223 180.88672 C 1115.26 181.04475 1112.577 181.52511 1109.8887 181.98828 L 1105 356 C 1113.2854 353.85193 1121.5817 351.98205 1129.8848 350.27539 C 1130.9735 350.05161 1132.0614 349.80603 1133.1504 349.58984 C 1141.0473 348.02215 1148.9543 346.68231 1156.8672 345.51367 C 1158.285 345.30428 1159.7028 345.09502 1161.1211 344.89844 C 1168.9655 343.8112 1176.8176 342.91018 1184.6777 342.21484 C 1185.993 342.09849 1187.3093 342.00577 1188.625 341.90039 C 1196.7053 341.25321 1204.7918 340.76844 1212.8887 340.53516 C 1213.6109 340.51435 1214.3342 340.51947 1215.0566 340.50195 C 1219.0805 340.40438 1223.1049 340.3157 1227.1328 340.32031 C 1231.5111 340.32533 1235.8922 340.4055 1240.2754 340.53125 C 1240.7641 340.54527 1241.2534 340.57237 1241.7422 340.58789 C 1250.1269 340.85416 1258.5215 341.34672 1266.9238 342.05469 C 1267.7798 342.12681 1268.636 342.20649 1269.4922 342.2832 C 1277.7292 343.0212 1285.9745 343.96856 1294.2285 345.13086 C 1294.9603 345.23391 1295.6919 345.32721 1296.4238 345.43359 C 1305.2731 346.71982 1314.1312 348.22625 1323 350 L 1272.3066 235.73633 C 1265.8655 229.39127 1256.4423 223.07356 1247.5195 219.5293 C 1242.7095 217.6093 1238.6209 214.99936 1234.3809 211.10938 C 1229.9081 207.00773 1223.4749 202.85529 1216.3926 199.2793 L 1124.8652 180.97266 C 1122.6743 180.94374 1120.4144 180.77875 1118.3223 180.88672 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Leg',
      pathData: const [
        'M 1227.1328 340.32031 C 1186.2111 340.27344 1145.5 345.50002 1105 356 L 1102 447 L 1100 599 L 1186.8867 700.99805 C 1185.9259 699.32107 1185 697.62685 1185 697.40039 C 1185 695.72039 1193.1109 698.81977 1196.3809 701.75977 C 1201.2209 706.08975 1209.1395 709.77945 1215.0195 710.43945 C 1223.1795 711.35945 1230.3303 715.81055 1236.0703 723.56055 C 1238.9003 727.38053 1242.4507 731.85 1243.9707 733.5 C 1246.5807 736.34 1259.9005 755.7708 1264.7305 763.80078 C 1266.1331 766.13116 1268.6125 772.90156 1271.1582 780.62891 L 1332.5625 764.43359 C 1331.9711 750.74287 1331.885 735.62711 1332.9492 724.4707 C 1334.0377 713.08168 1333.0412 704.96982 1329.8574 697.48828 L 1288 658 L 1315.2168 594.94727 C 1315.1236 594.02046 1315.1233 593.09936 1314.9297 592.16992 C 1313.8497 586.95994 1313.9095 586.63914 1316.2695 584.61914 C 1322.6295 579.14916 1327 568.0699 1327 557.41992 C 1327 551.62994 1327.3391 550.57086 1330.5391 546.38086 C 1334.8591 540.73088 1336.6302 537.36984 1339.1602 530.08984 C 1341.4102 523.58986 1342.5503 510.22084 1341.3203 504.63086 C 1340.6003 501.36086 1340.9005 499.87084 1343.2305 495.13086 C 1343.592 494.39405 1343.7732 493.38871 1344.0918 492.58008 L 1323 350 C 1290.9167 343.58335 1258.9609 340.35677 1227.1328 340.32031 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Shank',
      pathData: const [
        'M 1332.5625 764.43359 L 1271.1582 780.62891 C 1274.4022 790.47594 1277.7755 802.04293 1279.4004 809.76953 C 1282.4745 824.3663 1283.6884 835.70895 1284.3184 848.30859 L 1289 856 L 1284.9141 862.37109 C 1284.9175 863.13218 1285 863.59637 1285 864.38086 C 1285 881.64082 1284.7191 885.51064 1283.1191 890.14062 C 1280.3591 898.18062 1277.4404 903.47041 1271.4004 911.40039 C 1268.4304 915.30039 1265.2995 920.58992 1264.4395 923.16992 C 1263.5895 925.73992 1262.1996 928.41914 1261.3496 929.11914 C 1259.3882 930.75361 1253.2546 939.55059 1247.9609 948 L 1333.2832 948 C 1335.6294 943.07567 1336.4079 940.21201 1336.9902 932.35938 C 1337.6102 923.98938 1338.3195 920.96936 1341.0195 915.10938 C 1342.8195 911.19938 1344.5704 908.0093 1344.9004 908.0293 C 1345.2304 908.0493 1346.3695 908.7193 1347.4395 909.5293 C 1348.5095 910.3393 1350.11 911 1351 911 C 1353.48 911 1357.5191 906.06998 1359.6191 900.5 C 1363.4191 890.39002 1360.7993 871.88998 1354.0293 861 C 1347.3493 850.25002 1336.8897 809.54025 1333.4297 780.82031 C 1332.9071 776.48037 1332.8102 770.16883 1332.5625 764.43359 z M 531 782 L 534.34961 790.55859 C 534.81293 787.57818 535.27601 784.81294 535.76172 782 L 531 782 z M 556.01562 782 C 558.83448 790.01222 560.48825 797.9682 562.13086 811 C 564.03086 826.09996 563.8307 854.08088 561.7207 867.13086 C 560.7707 872.97084 560 879.40992 560 881.41992 C 560 886.90992 553.53912 899.00963 545.61914 908.34961 C 541.81914 912.82959 537.82023 918.48016 536.74023 920.91016 C 535.65025 923.33014 532.79086 927.73922 530.38086 930.69922 C 527.97086 933.65922 523.25039 940.16064 519.90039 945.14062 C 519.57779 945.62039 519.4435 945.89221 519.13867 946.35156 L 610.48047 927.94141 C 610.93964 923.38749 611.60911 920.61684 613.83008 916.75977 L 617.14062 911.01953 L 620.11914 912.56055 C 624.15914 914.65053 626.53025 913.64936 629.49023 908.60938 C 630.94814 906.12156 631.90673 903.17101 632.55273 899.99023 L 629.53906 871.66406 C 629.47088 871.47802 629.45086 871.29538 629.38086 871.10938 C 617.56088 839.74944 612.85094 815.29994 612.71094 784.5 C 612.70516 783.33914 612.77494 783.02336 612.77539 782 L 556.01562 782 z ',
      ],
    ),
    _MuttonRegion.paths(
      cut: 'Tenderloin',
      pathData: const [
        'M 985 380 A 23 23 0 0 0 962 403 A 23 23 0 0 0 985 426 L 1062 426 A 23 23 0 0 0 1085 403 A 23 23 0 0 0 1062 380 L 985 380 z ',
      ],
    ),
    _MuttonRegion.rects(
      cut: 'Whole Mutton',
      rects: const [Rect.fromLTWH(222, 1042, 287, 76)],
    ),
    _MuttonRegion.rects(
      cut: 'Trim / Manufacturing',
      rects: const [Rect.fromLTWH(536, 1042, 465, 76)],
    ),
    _MuttonRegion.rects(
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
                              painter: _MuttonHighlightPainter(
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

class _MuttonRegion {
  const _MuttonRegion._({
    required this.cut,
    required this.paths,
    required this.rects,
  });

  factory _MuttonRegion.paths({
    required String cut,
    required List<String> pathData,
  }) {
    return _MuttonRegion._(
      cut: cut,
      paths: pathData.map(parseSvgPathData).toList(),
      rects: const [],
    );
  }

  factory _MuttonRegion.rects({
    required String cut,
    required List<Rect> rects,
  }) {
    return _MuttonRegion._(cut: cut, paths: const [], rects: rects);
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

class _MuttonHighlightPainter extends CustomPainter {
  const _MuttonHighlightPainter({
    required this.regions,
    required this.selectedCut,
    required this.hoveredCut,
    required this.interactionColour,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
  });

  final List<_MuttonRegion> regions;
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
  bool shouldRepaint(covariant _MuttonHighlightPainter oldDelegate) {
    return oldDelegate.selectedCut != selectedCut ||
        oldDelegate.hoveredCut != hoveredCut ||
        oldDelegate.interactionColour != interactionColour;
  }
}
