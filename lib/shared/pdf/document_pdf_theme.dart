import 'dart:typed_data' as typed;
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bundle fonts so PDFs render bullets, dashes and accented names offline.
/// Cache bytes, not font instances: each PDF owns its font resources.
class DocumentPdfTheme {
  static Future<List<typed.ByteData>>? _fontData;
  static Future<pw.ThemeData> load() async {
    final fonts = await (_fontData ??= Future.wait([
      rootBundle.load('assets/fonts/DejaVuSans.ttf'),
      rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    ]));
    return pw.ThemeData.withFont(
      base: pw.Font.ttf(fonts[0]),
      bold: pw.Font.ttf(fonts[1]),
      italic: pw.Font.ttf(fonts[0]),
      boldItalic: pw.Font.ttf(fonts[1]),
    );
  }
}
