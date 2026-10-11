import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Local official artwork: no external requests or business identity changes.
class CutLinkPdfBrand {
  CutLinkPdfBrand._();
  static Future<pw.MemoryImage> load() async {
    final data = await rootBundle.load(
      'assets/images/CutLink-Horizontal-Burgundy.png',
    );
    return pw.MemoryImage(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  static pw.Widget logo(
    pw.MemoryImage image, {
    double width = 130,
    double height = 34,
  }) => pw.Image(
    image,
    width: width,
    height: height,
    fit: pw.BoxFit.contain,
    alignment: pw.Alignment.centerLeft,
  );
}
