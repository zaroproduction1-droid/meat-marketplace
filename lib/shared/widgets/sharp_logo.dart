import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Displays the original logo pixels, trimming only empty outer margins.
/// Stored artwork and uploaded files are never rewritten.
class SharpLogo extends StatefulWidget {
  SharpLogo.network(
    String url, {
    super.key,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.errorBuilder,
  }) : image = NetworkImage(url);

  SharpLogo.memory(
    Uint8List bytes, {
    super.key,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.errorBuilder,
  }) : image = MemoryImage(bytes);

  SharpLogo.asset(
    String asset, {
    super.key,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.errorBuilder,
  }) : image = AssetImage(asset);

  final ImageProvider image;
  final double? width;
  final double? height;
  final Alignment alignment;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<SharpLogo> createState() => _SharpLogoState();
}

class _SharpLogoState extends State<SharpLogo> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  Rect? _bounds;
  Object? _error;
  StackTrace? _stack;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SharpLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _detach();
    final generation = ++_generation;
    _info?.dispose();
    _info = null;
    _bounds = null;
    _error = null;
    _stack = null;
    _stream = stream;
    _listener = ImageStreamListener(
      (info, synchronousCall) async {
        // Each ImageInfo delivered to a listener is owned by that listener.
        Rect bounds;
        try {
          bounds = await _artworkBounds(info.image);
        } catch (_) {
          bounds = Rect.fromLTWH(
            0,
            0,
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        }
        if (!mounted || generation != _generation) {
          info.dispose();
          return;
        }
        setState(() {
          _info?.dispose();
          _info = info;
          _bounds = bounds;
          _error = null;
        });
      },
      onError: (Object error, StackTrace? stack) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _error = error;
          _stack = stack;
        });
      },
    );
    stream.addListener(_listener!);
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    ++_generation;
    _detach();
    _info?.dispose();
    super.dispose();
  }

  static final _boundsCache = Expando<Future<Rect>>();

  static Future<Rect> _artworkBounds(ui.Image image) =>
      _boundsCache[image] ??= _measureBounds(image);

  static Future<Rect> _measureBounds(ui.Image image) async {
    final width = image.width;
    final height = image.height;
    final full = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    // Bound the temporary RGBA allocation. Large originals still render intact.
    if (width * height > 4000000) return full;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return full;
    final pixels = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    bool empty(int x, int y) {
      final offset = (y * width + x) * 4;
      return pixels[offset + 3] <= 8 ||
          (pixels[offset] >= 248 &&
              pixels[offset + 1] >= 248 &&
              pixels[offset + 2] >= 248);
    }

    // Only trim a plain empty border; retain backgrounds and edge-touching art.
    for (var x = 0; x < width; x++) {
      if (!empty(x, 0) || !empty(x, height - 1)) return full;
    }
    for (var y = 0; y < height; y++) {
      if (!empty(0, y) || !empty(width - 1, y)) return full;
    }
    var left = width;
    var top = height;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!empty(x, y)) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    if (right < left || bottom < top) return full;
    // Leave a small margin so thin edges are not clipped by filtering.
    return Rect.fromLTRB(
      (left - 2).clamp(0, width).toDouble(),
      (top - 2).clamp(0, height).toDouble(),
      (right + 3).clamp(0, width).toDouble(),
      (bottom + 3).clamp(0, height).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final info = _info;
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: error != null
            ? widget.errorBuilder?.call(context, error, _stack) ??
                  const Icon(Icons.business_outlined)
            : info == null
            ? const SizedBox.shrink()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final bounds = _bounds!;
                  final size = constraints.constrain(bounds.size);
                  return CustomPaint(
                    size: size,
                    painter: _LogoPainter(info.image, bounds, widget.alignment),
                  );
                },
              ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.image, this.bounds, this.alignment);
  final ui.Image image;
  final Rect bounds;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fitted = applyBoxFit(BoxFit.contain, bounds.size, size);
    final destination = alignment.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      bounds,
      destination,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      image != oldDelegate.image ||
      bounds != oldDelegate.bounds ||
      alignment != oldDelegate.alignment;
}
