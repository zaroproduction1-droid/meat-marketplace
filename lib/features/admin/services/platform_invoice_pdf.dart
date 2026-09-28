import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Native text/vector PDF, kept separate from supplier trade invoices.
class PlatformInvoicePdf {
  static String _text(dynamic v) => (v?.toString() ?? '')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('•', '-');
  static double _number(dynamic v) => double.tryParse('$v') ?? 0;
  static String _money(dynamic v) => '\$${_number(v).toStringAsFixed(2)}';
  static String _date(dynamic v) {
    final d = DateTime.tryParse('$v');
    return d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static Future<Uint8List> build(Map<String, dynamic> invoice) async {
    final issuer = Map<String, dynamic>.from(
      invoice['issuer_snapshot'] as Map? ?? {},
    );
    final customer = Map<String, dynamic>.from(
      invoice['customer_snapshot'] as Map? ?? {},
    );
    final gst =
        issuer['gst_registered'] == true || issuer['gst_registered'] == 'true';
    final voided = invoice['voided_at'] != null;
    final paid = !voided && _number(invoice['outstanding']) <= 0;
    final doc = pw.Document(
      title: _text(invoice['invoice_number']),
      author: _text(issuer['legal_name']),
    );
    final ink = PdfColor.fromHex('#101D2B');
    final red = PdfColor.fromHex('#741C1C');
    pw.Widget line(String label, dynamic value, {bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              pw.Expanded(child: pw.Text(label)),
              pw.Text(
                _text(value),
                style: pw.TextStyle(
                  fontWeight: strong
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        );
    pw.Widget details(List<dynamic> values) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final v in values)
          if (_text(v).trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(_text(v)),
            ),
      ],
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        footer: (c) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CutLink subscription | ${_text(invoice['invoice_number'])}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                '${c.pageNumber} / ${c.pagesCount}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CutLink',
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: red,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    details([
                      issuer['legal_name'],
                      if (_text(issuer['abn']).isNotEmpty)
                        'ABN ${_text(issuer['abn'])}',
                      issuer['address'],
                      issuer['email'],
                      issuer['phone'],
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      gst ? 'TAX INVOICE' : 'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 21,
                        fontWeight: pw.FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      _text(invoice['invoice_number']),
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Date: ${_date(invoice['invoice_date'])}'),
                    pw.SizedBox(height: 4),
                    pw.Text('Due: ${_date(invoice['due_date'])}'),
                    if (voided || paid)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 14),
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: red, width: 2),
                          ),
                          child: pw.Text(
                            voided ? 'VOID' : 'PAID',
                            style: pw.TextStyle(
                              color: red,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 26),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            color: PdfColor.fromHex('#F3F4F6'),
            child: details([
              'BILL TO',
              customer['billing_name'],
              customer['billing_address'],
              customer['billing_email'],
              if (customer['account_number'] != null)
                'Account CL-${customer['account_number']}',
            ]),
          ),
          pw.SizedBox(height: 22),
          pw.TableHelper.fromTextArray(
            headers: ['DESCRIPTION', 'AMOUNT (AUD)'],
            data: [
              [
                '${_text(invoice['description'])}\n${_date(invoice['period_start'])} - ${_date(invoice['period_end'])}',
                _money(invoice['subtotal']),
              ],
            ],
            headerDecoration: pw.BoxDecoration(color: ink),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
            cellStyle: const pw.TextStyle(fontSize: 12),
            cellPadding: const pw.EdgeInsets.all(12),
            border: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.5),
            },
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 255,
              child: pw.Column(
                children: [
                  line('Subtotal', _money(invoice['subtotal'])),
                  if (gst) line('GST', _money(invoice['gst_amount'])),
                  line(
                    'Invoice total',
                    _money(invoice['total_amount']),
                    strong: true,
                  ),
                  pw.Divider(),
                  line('Payments received', _money(invoice['amount_paid'])),
                  line(
                    'Balance due',
                    _money(invoice['outstanding']),
                    strong: true,
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),
          details([
            if (_text(issuer['bank_name']).isNotEmpty) 'PAYMENT DETAILS',
            issuer['bank_name'],
            issuer['account_name'],
            if (_text(issuer['bsb']).isNotEmpty) 'BSB: ${_text(issuer['bsb'])}',
            if (_text(issuer['account_number']).isNotEmpty)
              'Account: ${_text(issuer['account_number'])}',
            'Payment reference: ${_text(invoice['invoice_number'])}',
            issuer['payment_instructions'],
          ]),
          if (voided)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16),
              child: pw.Text('Void reason: ${_text(invoice['void_reason'])}'),
            ),
        ],
      ),
    );
    return doc.save();
  }
}
