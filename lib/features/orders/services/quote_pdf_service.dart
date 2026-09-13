import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CutLinkQuotePdf {
  const CutLinkQuotePdf._();

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _money(dynamic value) =>
      '\$${_number(value).toStringAsFixed(2)}';

  static String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '—';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  static String _address(Map<String, dynamic> account) =>
      <dynamic>[
            account['delivery_address_line_1'],
            account['delivery_address_line_2'],
            account['delivery_suburb'],
            account['delivery_state'],
            account['delivery_postcode'],
          ]
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .join(', ');

  static Future<Uint8List> build({
    required Map<String, dynamic> quote,
    required Map<String, dynamic> supplier,
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
  }) async {
    final document = pw.Document();
    final revision = (quote['quote_revision'] as num?)?.toInt() ?? 0;
    final baseNumber =
        quote['quote_number']?.toString() ??
        quote['order_number']?.toString() ??
        'Quote';
    final quoteNumber = revision > 0 ? '$baseNumber R$revision' : baseNumber;
    final supplierName =
        supplier['trading_name']?.toString().trim().isNotEmpty == true
        ? supplier['trading_name'].toString()
        : supplier['legal_name']?.toString() ?? 'Supplier';
    final customerName =
        customer['customer_name']?.toString().trim().isNotEmpty == true
        ? customer['customer_name'].toString()
        : customer['legal_name']?.toString() ?? 'Customer';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUTLINK',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'QUOTE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  quoteNumber,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Date: ${_date(quote['quote_last_saved_at'] ?? quote['created_at'])}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This document is a quote, not a tax invoice.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (_) => [
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _party('From', supplierName, <dynamic>[
                  supplier['legal_name'],
                  supplier['business_email'],
                  supplier['business_phone'],
                ]),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _party('Quote for', customerName, <dynamic>[
                  customer['legal_name'],
                  if ((customer['abn']?.toString().trim() ?? '').isNotEmpty)
                    'ABN ${customer['abn']}',
                  customer['contact_name'],
                  customer['email'],
                  customer['phone'],
                  _address(customer),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .6),
            columnWidths: {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Product', bold: true),
                  _cell('Qty', bold: true),
                  _cell('Rate', bold: true),
                ],
              ),
              for (final item in items)
                pw.TableRow(
                  children: [
                    _cell(
                      [
                        item['product_name_snapshot'] ?? 'Product',
                        if ((item['sku_snapshot']?.toString() ?? '').isNotEmpty)
                          'SKU ${item['sku_snapshot']}',
                      ].join('\n'),
                    ),
                    _cell(
                      '${item['quantity'] ?? 0} ${item['quantity_unit'] ?? ''}',
                    ),
                    _cell(
                      '${_money(item['unit_price'])} / ${item['price_basis'] ?? 'unit'}',
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Quoted rates are shown per pricing unit. Quantities and final weights are not totalled on this quote.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          if (_number(quote['delivery_fee']) > 0)
            pw.Text(
              'Delivery fee: ${_money(quote['delivery_fee'])}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          if ((quote['delivery_notes']?.toString().trim() ?? '')
              .isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Delivery notes',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              quote['delivery_notes'].toString(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Payment: ${quote['payment_method_snapshot'] ?? '—'}${quote['payment_terms_days_snapshot'] == null ? '' : ' • ${quote['payment_terms_days_snapshot']} days'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Fulfilment: ${quote['fulfilment_method'] ?? '—'} • requested ${_date(quote['requested_fulfilment_date'])}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if ((quote['customer_reference']?.toString().trim() ?? '').isNotEmpty)
            pw.Text(
              'Customer reference: ${quote['customer_reference']}',
              style: const pw.TextStyle(fontSize: 9),
            ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _party(String label, String name, List<dynamic> details) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              name,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            for (final value
                in details
                    .map((e) => e?.toString().trim() ?? '')
                    .where((e) => e.isNotEmpty))
              pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
          ],
        ),
      );

  static pw.Widget _cell(String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      value,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
