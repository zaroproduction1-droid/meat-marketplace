import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

/// Reusable CutLink beef-region selector.
///
/// This widget does not contain Sales, Inventory or Marketplace logic.
/// It renders the exact CutLink SVG asset and returns the SVG `data-cut` value
/// when a region is selected.
///
/// Expected asset:
///   assets/images/CutLink-Beef-Cuts.svg
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
  static const double _viewBoxWidth = 1672;
  static const double _viewBoxHeight = 941;
  static const Color _interactionColour = Color(0xFF082A54);

  List<_SvgCutRegion>? _regions;
  Uint8List? _artworkBytes;
  String? _hoveredCut;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSvgRegions();
  }

  @override
  void didUpdateWidget(covariant InteractiveBeefCutsMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assetPath != widget.assetPath) {
      _regions = null;
      _artworkBytes = null;
      _hoveredCut = null;
      _loadError = null;
      _loadSvgRegions();
    }
  }

  Future<void> _loadSvgRegions() async {
    try {
      final svg = await rootBundle.loadString(widget.assetPath);
      final regions = _SvgCutRegionParser.parse(svg);
      final artworkBytes = _SvgCutRegionParser.extractEmbeddedArtwork(svg);

      if (regions.isEmpty) {
        throw StateError(
          'No interactive data-cut regions were found in ${widget.assetPath}.',
        );
      }

      if (artworkBytes == null || artworkBytes.isEmpty) {
        throw StateError(
          'The embedded CutLink beef artwork could not be read from ${widget.assetPath}.',
        );
      }

      if (!mounted) return;

      setState(() {
        _regions = regions;
        _artworkBytes = artworkBytes;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _regions = const [];
        _loadError = error.toString();
      });
    }
  }

  String? _cutAt(Offset localPosition, Size size) {
    final regions = _regions;
    if (regions == null || regions.isEmpty || size.isEmpty) {
      return null;
    }

    final svgPoint = Offset(
      localPosition.dx * _viewBoxWidth / size.width,
      localPosition.dy * _viewBoxHeight / size.height,
    );

    // Reverse order is deliberate. Inner/nested regions occur later in the SVG,
    // so Rib Eye wins over Ribs, Skirt over Plate, and Silverside over Round.
    for (final region in regions.reversed) {
      if (region.hitTest(svgPoint)) {
        return region.cut;
      }
    }

    return null;
  }

  void _updateHover(Offset localPosition, Size size) {
    final next = _cutAt(localPosition, size);

    if (next == _hoveredCut) return;

    setState(() {
      _hoveredCut = next;
    });
  }

  void _handleTap(Offset localPosition, Size size) {
    final cut = _cutAt(localPosition, size);
    if (cut == null) return;

    widget.onCutSelected(cut);
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                return MouseRegion(
                  cursor: _hoveredCut == null
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  onHover: (event) => _updateHover(event.localPosition, size),
                  onExit: (_) {
                    if (_hoveredCut != null) {
                      setState(() => _hoveredCut = null);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _handleTap(details.localPosition, size),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_artworkBytes != null)
                          Image.memory(
                            _artworkBytes!,
                            fit: BoxFit.fill,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                          ),
                        if (_regions != null && _regions!.isNotEmpty)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _SvgCutHighlightPainter(
                                regions: _regions!,
                                selectedCut: widget.selectedCut,
                                hoveredCut: _hoveredCut,
                                interactionColour: _interactionColour,
                                viewBoxWidth: _viewBoxWidth,
                                viewBoxHeight: _viewBoxHeight,
                              ),
                            ),
                          ),
                        if (_regions == null || _artworkBytes == null)
                          const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (_loadError != null)
                          ColoredBox(
                            color: Colors.white.withValues(alpha: 0.92),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'Unable to load interactive beef map.\n'
                                  '$_loadError',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF741C1C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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

class _SvgCutHighlightPainter extends CustomPainter {
  const _SvgCutHighlightPainter({
    required this.regions,
    required this.selectedCut,
    required this.hoveredCut,
    required this.interactionColour,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
  });

  final List<_SvgCutRegion> regions;
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

      if (region.tailStroke) {
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 32
          ..strokeCap = StrokeCap.round
          ..color = interactionColour.withValues(alpha: selected ? 0.24 : 0.18);

        canvas.drawPath(region.path, stroke);
        continue;
      }

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: selected ? 0.30 : 0.22);

      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = interactionColour;

      canvas.drawPath(region.path, fill);
      canvas.drawPath(region.path, outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SvgCutHighlightPainter oldDelegate) {
    return oldDelegate.selectedCut != selectedCut ||
        oldDelegate.hoveredCut != hoveredCut ||
        oldDelegate.regions != regions ||
        oldDelegate.interactionColour != interactionColour;
  }
}

class _SvgCutRegion {
  const _SvgCutRegion({
    required this.cut,
    required this.path,
    this.tailStroke = false,
  });

  final String cut;
  final Path path;
  final bool tailStroke;

  bool hitTest(Offset point) {
    if (!tailStroke) {
      return path.contains(point);
    }

    // The actual ox-tail selector is a stroked path rather than a filled area.
    // Match the SVG's 32-unit interactive stroke as closely as possible.
    const radius = 18.0;

    for (final metric in path.computeMetrics()) {
      final step = math.max(4.0, math.min(10.0, metric.length / 40));

      for (double distance = 0; distance <= metric.length; distance += step) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) continue;

        if ((tangent.position - point).distance <= radius) {
          return true;
        }
      }
    }

    return false;
  }
}

class _SvgCutRegionParser {
  static final RegExp _interactiveElement = RegExp(
    r'<(path|ellipse|rect)\b([^>]*\bdata-cut="[^"]+"[^>]*)/?>',
    caseSensitive: false,
    multiLine: true,
  );

  static final RegExp _attribute = RegExp(
    r'([A-Za-z_:][A-Za-z0-9_.:-]*)\s*=\s*"([^"]*)"',
    multiLine: true,
  );

  static final RegExp _embeddedPng = RegExp(
    r'href="data:image/png;base64,([^"]+)"',
    caseSensitive: false,
    multiLine: true,
  );

  static Uint8List? extractEmbeddedArtwork(String svg) {
    final match = _embeddedPng.firstMatch(svg);
    final encoded = match?.group(1);

    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      return base64Decode(encoded.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  static List<_SvgCutRegion> parse(String svg) {
    final result = <_SvgCutRegion>[];

    for (final match in _interactiveElement.allMatches(svg)) {
      final tag = match.group(1)!.toLowerCase();
      final rawAttributes = match.group(2)!;
      final attributes = <String, String>{};

      for (final attributeMatch in _attribute.allMatches(rawAttributes)) {
        attributes[attributeMatch.group(1)!] = attributeMatch.group(2)!;
      }

      final cut = attributes['data-cut']?.trim();
      if (cut == null || cut.isEmpty) continue;

      final path = switch (tag) {
        'path' => _path(attributes),
        'ellipse' => _ellipse(attributes),
        'rect' => _rect(attributes),
        _ => null,
      };

      if (path == null) continue;

      result.add(
        _SvgCutRegion(
          cut: cut,
          path: path,
          tailStroke:
              attributes['class']?.split(RegExp(r'\s+')).contains('tail-hit') ??
              false,
        ),
      );
    }

    return result;
  }

  static Path? _path(Map<String, String> attributes) {
    final d = attributes['d'];
    if (d == null || d.trim().isEmpty) return null;

    return parseSvgPathData(d);
  }

  static Path? _ellipse(Map<String, String> attributes) {
    final cx = double.tryParse(attributes['cx'] ?? '');
    final cy = double.tryParse(attributes['cy'] ?? '');
    final rx = double.tryParse(attributes['rx'] ?? '');
    final ry = double.tryParse(attributes['ry'] ?? '');

    if (cx == null || cy == null || rx == null || ry == null) {
      return null;
    }

    return Path()..addOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
    );
  }

  static Path? _rect(Map<String, String> attributes) {
    final x = double.tryParse(attributes['x'] ?? '');
    final y = double.tryParse(attributes['y'] ?? '');
    final width = double.tryParse(attributes['width'] ?? '');
    final height = double.tryParse(attributes['height'] ?? '');

    if (x == null || y == null || width == null || height == null) {
      return null;
    }

    final rx = double.tryParse(attributes['rx'] ?? '') ?? 0;
    final ry = double.tryParse(attributes['ry'] ?? '') ?? rx;

    final rect = Rect.fromLTWH(x, y, width, height);

    if (rx <= 0 && ry <= 0) {
      return Path()..addRect(rect);
    }

    return Path()..addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.elliptical(rx, ry),
        topRight: Radius.elliptical(rx, ry),
        bottomLeft: Radius.elliptical(rx, ry),
        bottomRight: Radius.elliptical(rx, ry),
      ),
    );
  }
}

/// Canonical SVG data-cut values used by CutLink.
///
/// Pages can use these constants when mapping the SVG selection into
/// `meat_sections`.
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
