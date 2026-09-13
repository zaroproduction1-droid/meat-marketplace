import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ZoomablePdfPreview extends StatefulWidget {
  const ZoomablePdfPreview({
    super.key,
    required this.documentKey,
    required this.buildPdf,
    this.dpi = 240,
    this.minScale = 0.6,
    this.maxScale = 4.5,
    this.maxPageWidth = 900,
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
  late Future<List<Uint8List>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = _renderPages();
  }

  @override
  void didUpdateWidget(covariant ZoomablePdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentKey != widget.documentKey) {
      _controller.value = Matrix4.identity();
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

  void _setScale(double targetScale) {
    final next = targetScale.clamp(widget.minScale, widget.maxScale).toDouble();
    final current = Matrix4.copy(_controller.value);

    current.storage[0] = next;
    current.storage[5] = next;
    current.storage[10] = 1;

    _controller.value = current;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final direction = event.scrollDelta.dy > 0 ? 0.88 : 1.12;
    _setScale(_currentScale * direction);
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
            final pageWidth = (constraints.maxWidth - 32)
                .clamp(320.0, widget.maxPageWidth)
                .toDouble();

            return Container(
              color: const Color(0xFFE9EBEE),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      onPointerSignal: _handlePointerSignal,
                      child: InteractiveViewer(
                        transformationController: _controller,
                        minScale: widget.minScale,
                        maxScale: widget.maxScale,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(260),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: pageWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < pages.length; i++) ...[
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x22000000),
                                          blurRadius: 10,
                                          offset: Offset(0, 3),
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
                                    ),
                                  ),
                                  if (i != pages.length - 1)
                                    const SizedBox(height: 18),
                                ],
                              ],
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
                          IconButton(
                            tooltip: 'Reset zoom',
                            onPressed: () {
                              _controller.value = Matrix4.identity();
                            },
                            icon: const Icon(
                              Icons.center_focus_strong_outlined,
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
                            'Scroll wheel to zoom • drag to move',
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
