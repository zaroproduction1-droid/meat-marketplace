import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreditNotePdf {
  static String money(dynamic value) =>
      '\$${(num.tryParse(value.toString()) ?? 0).toStringAsFixed(2)}';
  static Future<Uint8List> build(Map<String, dynamic> note) async {
    final doc = pw.Document();
    final snapshot = Map<String, dynamic>.from(note['invoice_snapshot'] as Map);
    String field(String name) => snapshot[name]?.toString().trim() ?? '';
    final lines = (note['supplier_credit_note_lines'] as List).cast<Map>();
    final brand = PdfColor.fromHex('#741C1C');
    pw.ImageProvider? logo;
    final path = field('supplier_logo_path_snapshot');
    if (path.isNotEmpty) {
      try {
        logo = await networkImage(
          Supabase.instance.client.storage
              .from('business-branding')
              .getPublicUrl(path),
        );
      } catch (_) {
        /* Text identity remains available. */
      }
    }
    pw.Widget text(String value, {double size = 10, bool bold = false}) =>
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        );
    final supplier = [
      field('supplier_trading_name_snapshot'),
      field('supplier_legal_name_snapshot'),
    ].where((s) => s.isNotEmpty).toSet().join('\n');
    final address = [
      'supplier_address_line_1_snapshot',
      'supplier_address_line_2_snapshot',
      'supplier_suburb_snapshot',
      'supplier_state_snapshot',
      'supplier_postcode_snapshot',
    ].map(field).where((s) => s.isNotEmpty).join(' ');
    final customerAddress = [
      'customer_billing_address_line_1_snapshot',
      'customer_billing_address_line_2_snapshot',
      'customer_billing_suburb_snapshot',
      'customer_billing_state_snapshot',
      'customer_billing_postcode_snapshot',
    ].map(field).where((s) => s.isNotEmpty).join(' ');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (c) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: text('Page ${c.pageNumber} of ${c.pagesCount}', size: 8),
        ),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 85, height: 60, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text(supplier, size: 15, bold: true),
                    if (address.isNotEmpty) text(address),
                    if (field('supplier_abn_snapshot').isNotEmpty)
                      text('ABN ${field('supplier_abn_snapshot')}'),
                    if (field('supplier_phone_snapshot').isNotEmpty)
                      text(field('supplier_phone_snapshot')),
                    if (field('supplier_email_snapshot').isNotEmpty)
                      text(field('supplier_email_snapshot')),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  text('CREDIT NOTE', size: 18, bold: true),
                  text('Adjustment note', size: 9),
                  pw.SizedBox(height: 8),
                  text(note['credit_number'].toString(), bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: brand),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text('CREDIT TO', bold: true),
                    text(field('customer_name_snapshot'), size: 12, bold: true),
                    if (customerAddress.isNotEmpty) text(customerAddress),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  text(
                    'Date: ${note['created_at'].toString().split('T').first}',
                  ),
                  text('Original invoice: ${field('invoice_number')}'),
                  text(
                    'Original invoice total: ${money(snapshot['total_amount'])}',
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          text('Reason: ${note['reason']}', bold: true),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['DESCRIPTION', 'RETURNED', 'KG', 'CREDIT INC GST'],
            headerDecoration: pw.BoxDecoration(color: brand),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 11),
            cellPadding: const pw.EdgeInsets.all(8),
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.7),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
            data: [
              for (final l in lines)
                [
                  l['description'],
                  '${l['quantity']} ${l['quantity_unit'] ?? ''}',
                  l['weight_kg'],
                  money(l['amount']),
                ],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                text(
                  'Credit excluding GST: ${money((num.tryParse(note['total_amount'].toString()) ?? 0) - (num.tryParse(note['tax_amount'].toString()) ?? 0))}',
                ),
                text('GST adjustment: ${money(note['tax_amount'])}'),
                text(
                  'TOTAL CREDIT: ${money(note['total_amount'])}',
                  size: 14,
                  bold: true,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          text(
            'This credit reduces the original invoice consideration by ${money(note['total_amount'])}. It does not itself confirm that money has been refunded.',
          ),
          if ((note['notes']?.toString() ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 12),
            text(note['notes'].toString()),
          ],
        ],
      ),
    );
    return doc.save();
  }
}
