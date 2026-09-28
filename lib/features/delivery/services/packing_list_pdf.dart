import '../../../shared/pdf/document_pdf_theme.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PackingListPdf {
  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static Future<Uint8List> build(
    Map<String, dynamic> data, {
    Uint8List? logo,
  }) async {
    final document = pw.Document(theme: await DocumentPdfTheme.load());
    final supplier = Map<String, dynamic>.from(data['supplier'] as Map? ?? {});
    final run = Map<String, dynamic>.from(data['run'] as Map? ?? {});
    final orders = List<Map<String, dynamic>>.from(
      data['orders'] as List? ?? [],
    );
    if (orders.isEmpty) {
      throw StateError('No invoiced delivery orders to print.');
    }
    for (final order in orders) {
      final items = List<Map<String, dynamic>>.from(
        order['items'] as List? ?? [],
      );
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logo != null)
                          pw.Image(
                            pw.MemoryImage(logo),
                            width: 100,
                            height: 45,
                            fit: pw.BoxFit.contain,
                          ),
                        pw.Text(
                          _text(supplier['name']),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          [
                            supplier['phone'],
                            supplier['email'],
                          ].map(_text).where((s) => s.isNotEmpty).join(' | '),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PACKING LIST',
                        style: pw.TextStyle(
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Order ${_text(order['number'])}'),
                      if (_text(run['number']).isNotEmpty)
                        pw.Text('Run ${_text(run['number'])}'),
                      if (_text(run['date']).isNotEmpty)
                        pw.Text(_text(run['date'])),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
            ],
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Packing list | Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          build: (_) => [
            pw.Text(
              'DELIVER TO',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _text(order['customer']),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            for (final key in ['contact', 'phone', 'address'])
              if (_text(order[key]).isNotEmpty) pw.Text(_text(order[key])),
            if (_text(order['instructions']).isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(
                  'Delivery instructions: ${_text(order['instructions'])}',
                ),
              ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['SKU / DESCRIPTION', 'SUPPLIED', 'WEIGHT'],
              data: items
                  .map(
                    (item) => [
                      [
                        item['sku'],
                        item['name'],
                        item['comment'],
                      ].map(_text).where((s) => s.isNotEmpty).join('\n'),
                      [
                        item['quantity'],
                        item['unit'],
                      ].map(_text).where((s) => s.isNotEmpty).join(' '),
                      [
                        item['weight'],
                        item['weight_unit'],
                      ].map(_text).where((s) => s.isNotEmpty).join(' '),
                    ],
                  )
                  .toList(),
              columnWidths: {
                0: const pw.FlexColumnWidth(5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
              },
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 11),
              cellPadding: const pw.EdgeInsets.all(7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Received by: ____________________    Date: ______________',
            ),
            pw.SizedBox(height: 18),
            pw.Text('Signature: __________________________________________'),
          ],
        ),
      );
    }
    return document.save();
  }
}
