import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ZoomablePdfPreview extends StatefulWidget {
  const ZoomablePdfPreview({
    super.key,
    required this.documentKey,
    required this.buildPdf,
    this.dpi = 540,
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
  bool _needsInitialCentre = true;
  final List<GlobalKey> _pageKeys = [];
  double _gestureStartScale = 1;
  Offset _gestureSceneFocal = Offset.zero;

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
    final sceneFocal = _controller.toScene(focal);
    final adjustment = Matrix4.copy(_controller.value)
      ..translateByDouble(sceneFocal.dx, sceneFocal.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-sceneFocal.dx, -sceneFocal.dy, 0, 1);

    _controller.value = adjustment;
    setState(() {});
  }

  void _applyCentredTransform() {
    _controller.value = Matrix4.identity();
  }

  void _reset() {
    _applyCentredTransform();
    if (mounted) setState(() {});
  }

  bool _isOverPaper(Offset globalPosition) {
    for (final key in _pageKeys) {
      final object = key.currentContext?.findRenderObject();
      if (object is RenderBox && object.hasSize) {
        final local = object.globalToLocal(globalPosition);
        if ((Offset.zero & object.size).contains(local)) return true;
      }
    }
    return false;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted) return;
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (viewport is! RenderBox) return;
      if (_isOverPaper(event.position)) {
        final factor = math.exp(
          -event.scrollDelta.dy.clamp(-240.0, 240.0) / 400,
        );
        _setScale(
          _currentScale * factor,
          focalPoint: viewport.globalToLocal(event.position),
        );
      } else {
        final next = Matrix4.copy(_controller.value);
        next.setTranslationRaw(
          next.storage[12] - event.scrollDelta.dx,
          next.storage[13] - event.scrollDelta.dy,
          0,
        );
        _controller.value = next;
      }
    });
  }

  void _startGesture(ScaleStartDetails details) {
    _gestureStartScale = _currentScale;
    _gestureSceneFocal = _controller.toScene(details.localFocalPoint);
  }

  void _updateGesture(ScaleUpdateDetails details) {
    final scale = (_gestureStartScale * details.scale)
        .clamp(widget.minScale, widget.maxScale)
        .toDouble();
    final offset = details.localFocalPoint - _gestureSceneFocal * scale;
    _controller.value = Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    setState(() {});
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

        while (_pageKeys.length < pages.length) {
          _pageKeys.add(GlobalKey());
        }
        if (_pageKeys.length > pages.length) {
          _pageKeys.removeRange(pages.length, _pageKeys.length);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth;
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
                        behavior: HitTestBehavior.opaque,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _startGesture,
                          onScaleUpdate: _updateGesture,
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: ValueListenableBuilder<Matrix4>(
                              valueListenable: _controller,
                              builder: (context, transform, child) => Transform(
                                transform: transform,
                                alignment: Alignment.topLeft,
                                child: child,
                              ),
                              child: SizedBox(
                                width: viewportWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
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
                                              key: _pageKeys[i],
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
                                                  color: const Color(
                                                    0xFFD5D8DC,
                                                  ),
                                                ),
                                              ),
                                              child: Image.memory(
                                                pages[i],
                                                width: pageWidth,
                                                fit: BoxFit.fitWidth,
                                                filterQuality:
                                                    FilterQuality.high,
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
                              'Reset  ${(_currentScale * 100).round()}%',
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
                    right: 16,
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
                            'Wheel over paper to zoom • Outside paper to scroll • Drag to pan',
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
