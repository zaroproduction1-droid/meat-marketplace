import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ZoomablePdfPreview extends StatefulWidget {
  const ZoomablePdfPreview({
    super.key,
    required this.documentKey,
    required this.buildPdf,
    this.dpi = 420,
    this.minScale = 0.55,
    this.maxScale = 5,
    this.maxPageWidth = 920,
  });

  final String documentKey;
  final Future<Uint8List> Function() buildPdf;
  final double dpi;
  final double minScale;
  final double maxScale;
  final double maxPageWidth;

  @override
  State<ZoomablePdfPreview> createState() => _ZoomablePdfPreviewState();
}

class _ZoomablePdfPreviewState extends State<ZoomablePdfPreview> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();
  late Future<List<Uint8List>> _pagesFuture;
  double _lastViewportWidth = 0;
  bool _needsInitialCentre = true;

  @override
  void initState() {
    super.initState();
    _pagesFuture = _renderPages();
  }

  @override
  void didUpdateWidget(covariant ZoomablePdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentKey != widget.documentKey) {
      _needsInitialCentre = true;
      _pagesFuture = _renderPages();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Uint8List>> _renderPages() async {
    final pdfBytes = await widget.buildPdf();
    final pages = <Uint8List>[];
    await for (final page in Printing.raster(pdfBytes, dpi: widget.dpi)) {
      pages.add(await page.toPng());
    }
    return pages;
  }

  double get _currentScale => _controller.value.getMaxScaleOnAxis();

  Offset _viewportCentre() {
    final object = _viewportKey.currentContext?.findRenderObject();
    return object is RenderBox ? object.size.center(Offset.zero) : Offset.zero;
  }

  void _setScale(double targetScale, {Offset? focalPoint}) {
    final next = targetScale.clamp(widget.minScale, widget.maxScale).toDouble();
    final currentScale = _currentScale;
    if ((next - currentScale).abs() < 0.001) return;

    final focal = focalPoint ?? _viewportCentre();
    final factor = next / currentScale;
    final adjustment = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(_controller.value);

    _controller.value = adjustment;
    setState(() {});
  }

  void _applyCentredTransform() {
    if (_lastViewportWidth <= 0) return;
    const sidePanSpace = 900.0;
    _controller.value = Matrix4.identity()
      ..translateByDouble(-sidePanSpace, 0, 0, 1);
  }

  void _reset() {
    _applyCentredTransform();
    if (mounted) setState(() {});
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final direction = event.scrollDelta.dy > 0 ? 0.90 : 1.10;
    _setScale(_currentScale * direction, focalPoint: event.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _pagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to render PDF preview: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final pages = snapshot.data ?? const <Uint8List>[];
        if (pages.isEmpty) {
          return const Center(child: Text('No PDF pages to preview.'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth;
            _lastViewportWidth = viewportWidth;
            const sidePanSpace = 900.0;
            final canvasWidth = viewportWidth + (sidePanSpace * 2);
            final pageWidth = (viewportWidth - 40)
                .clamp(320.0, widget.maxPageWidth)
                .toDouble();

            if (_needsInitialCentre) {
              _needsInitialCentre = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _applyCentredTransform();
                setState(() {});
              });
            }

            return Container(
              key: _viewportKey,
              color: const Color(0xFFE9EBEE),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: Listener(
                        onPointerSignal: _handlePointerSignal,
                        child: InteractiveViewer(
                          transformationController: _controller,
                          minScale: widget.minScale,
                          maxScale: widget.maxScale,
                          panEnabled: true,
                          scaleEnabled: true,
                          constrained: false,
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          boundaryMargin: const EdgeInsets.all(1200),
                          child: SizedBox(
                            width: canvasWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: sidePanSpace + 20,
                                vertical: 18,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: pageWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < pages.length;
                                        i++
                                      ) ...[
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x22000000),
                                                blurRadius: 12,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: const Color(0xFFD5D8DC),
                                            ),
                                          ),
                                          child: Image.memory(
                                            pages[i],
                                            width: pageWidth,
                                            fit: BoxFit.fitWidth,
                                            filterQuality: FilterQuality.high,
                                            gaplessPlayback: true,
                                            isAntiAlias: true,
                                          ),
                                        ),
                                        if (i != pages.length - 1)
                                          const SizedBox(height: 20),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Zoom out',
                            onPressed: () => _setScale(_currentScale / 1.15),
                            icon: const Icon(Icons.remove),
                          ),
                          TextButton.icon(
                            onPressed: _reset,
                            icon: const Icon(
                              Icons.center_focus_strong_outlined,
                              size: 17,
                            ),
                            label: Text(
                              '${(_currentScale * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Zoom in',
                            onPressed: () => _setScale(_currentScale * 1.15),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 16,
                    bottom: 12,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xD9000000),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            'Scroll to zoom - drag in any direction - Reset to centre',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
