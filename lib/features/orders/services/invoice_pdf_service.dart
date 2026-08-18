import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CutLinkInvoicePdf {
  const CutLinkInvoicePdf._();

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';

  static String _date(dynamic value) {
    if (value == null) return '—';

    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static String _address(List<dynamic> values) {
    return values
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  static String _statusLabel(dynamic value) {
    switch (value?.toString()) {
      case 'ready':
        return 'Ready';
      case 'issued':
        return 'Issued';
      case 'part_paid':
        return 'Part Paid';
      case 'paid':
        return 'Paid';
      case 'void':
        return 'Void';
      default:
        return value?.toString() ?? 'Draft';
    }
  }

  static String _paymentText(Map<String, dynamic> invoice) {
    final method = invoice['payment_method_snapshot']?.toString().trim();
    final days = invoice['payment_terms_days_snapshot'];

    if (method == null || method.isEmpty) return '—';

    if (method.toLowerCase() == 'account' && days != null) {
      return 'Account • $days days';
    }

    if (method.toLowerCase() == 'cod') return 'COD';
    if (method.toLowerCase() == 'prepaid') return 'Prepaid';

    return method;
  }

  static pw.Widget _labelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 92,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(_money(value), style: style),
        ],
      ),
    );
  }

  static Future<Uint8List> build({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) async {
    final document = pw.Document();

    final status = invoice['status']?.toString();
    final issued =
        status == 'issued' ||
        status == 'part_paid' ||
        status == 'paid' ||
        status == 'void';

    final supplierAddress = _address([
      invoice['supplier_address_line_1_snapshot'],
      invoice['supplier_address_line_2_snapshot'],
      invoice['supplier_suburb_snapshot'],
      invoice['supplier_state_snapshot'],
      invoice['supplier_postcode_snapshot'],
    ]);

    final customerAddress = _address([
      invoice['customer_billing_address_line_1_snapshot'],
      invoice['customer_billing_address_line_2_snapshot'],
      invoice['customer_billing_suburb_snapshot'],
      invoice['customer_billing_state_snapshot'],
      invoice['customer_billing_postcode_snapshot'],
    ]);

    final total = _asDouble(invoice['total_amount']);
    final paid = _asDouble(invoice['amount_paid']);
    final outstanding = (total - paid).clamp(0, double.infinity).toDouble();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Row(
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
                pw.SizedBox(height: 3),
                pw.Text(
                  issued ? 'TAX INVOICE' : 'DRAFT INVOICE',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  invoice['invoice_number']?.toString() ?? 'Invoice',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Status: ${_statusLabel(status)}',
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
              'Generated by CutLink',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Supplier',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        invoice['supplier_trading_name_snapshot']?.toString() ??
                            invoice['supplier_legal_name_snapshot']
                                ?.toString() ??
                            'Supplier',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((invoice['supplier_legal_name_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        pw.Text(
                          invoice['supplier_legal_name_snapshot'].toString(),
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                      if ((invoice['supplier_abn_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        _labelValue(
                          'ABN',
                          invoice['supplier_abn_snapshot'].toString(),
                        ),
                      if ((invoice['supplier_licence_number_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        _labelValue(
                          'Licence',
                          invoice['supplier_licence_number_snapshot']
                              .toString(),
                        ),
                      if (supplierAddress.isNotEmpty)
                        _labelValue('Address', supplierAddress),
                      if ((invoice['supplier_phone_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        _labelValue(
                          'Phone',
                          invoice['supplier_phone_snapshot'].toString(),
                        ),
                      if ((invoice['supplier_email_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        _labelValue(
                          'Email',
                          invoice['supplier_email_snapshot'].toString(),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        invoice['customer_legal_name_snapshot']?.toString() ??
                            invoice['customer_name_snapshot']?.toString() ??
                            'Customer',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((invoice['customer_abn_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        _labelValue(
                          'ABN',
                          invoice['customer_abn_snapshot'].toString(),
                        ),
                      if (customerAddress.isNotEmpty)
                        _labelValue('Address', customerAddress),
                      if ((invoice['customer_phone_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        _labelValue(
                          'Phone',
                          invoice['customer_phone_snapshot'].toString(),
                        ),
                      if ((invoice['customer_email_snapshot']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        _labelValue(
                          'Email',
                          invoice['customer_email_snapshot'].toString(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _labelValue('Invoice date', _date(invoice['invoice_date'])),
                _labelValue('Due date', _date(invoice['due_date'])),
                _labelValue('Payment terms', _paymentText(invoice)),
                if ((invoice['customer_reference_snapshot']
                            ?.toString()
                            .trim() ??
                        '')
                    .isNotEmpty)
                  _labelValue(
                    'Customer reference',
                    invoice['customer_reference_snapshot'].toString(),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'Ordered', 'Actual', 'Rate', 'Amount'],
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.2),
            data: [
              for (final item in items)
                [
                  item['product_name_snapshot']?.toString() ?? 'Product',
                  '${item['ordered_quantity'] ?? ''} ${item['ordered_quantity_unit'] ?? ''}',
                  _asDouble(item['actual_weight']) > 0
                      ? '${_asDouble(item['actual_weight']).toStringAsFixed(2)} ${item['actual_weight_unit'] ?? 'kg'}'
                      : '${item['supplied_quantity'] ?? ''} ${item['supplied_quantity_unit'] ?? ''}',
                  '${_money(_asDouble(item['locked_unit_price']))}/${item['price_basis'] == 'kilogram' ? 'kg' : 'unit'}',
                  _money(_asDouble(item['line_amount'])),
                ],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 260,
              child: pw.Column(
                children: [
                  _totalRow(
                    'Products inc GST',
                    _asDouble(invoice['products_subtotal']),
                  ),
                  _totalRow(
                    'Delivery inc GST',
                    _asDouble(invoice['delivery_fee']),
                  ),
                  _totalRow('GST included', _asDouble(invoice['tax_amount'])),
                  pw.Divider(),
                  _totalRow('Total inc GST', total, bold: true),
                  _totalRow('Paid', paid),
                  _totalRow('Outstanding', outstanding, bold: true),
                ],
              ),
            ),
          ),
          if ((invoice['bank_account_name_snapshot']?.toString().trim() ?? '')
                  .isNotEmpty ||
              (invoice['bank_bsb_snapshot']?.toString().trim() ?? '')
                  .isNotEmpty ||
              (invoice['bank_account_number_snapshot']?.toString().trim() ?? '')
                  .isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Payment Details',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  if ((invoice['bank_name_snapshot']?.toString().trim() ?? '')
                      .isNotEmpty)
                    _labelValue(
                      'Bank',
                      invoice['bank_name_snapshot'].toString(),
                    ),
                  if ((invoice['bank_account_name_snapshot']
                              ?.toString()
                              .trim() ??
                          '')
                      .isNotEmpty)
                    _labelValue(
                      'Account name',
                      invoice['bank_account_name_snapshot'].toString(),
                    ),
                  if ((invoice['bank_bsb_snapshot']?.toString().trim() ?? '')
                      .isNotEmpty)
                    _labelValue('BSB', invoice['bank_bsb_snapshot'].toString()),
                  if ((invoice['bank_account_number_snapshot']
                              ?.toString()
                              .trim() ??
                          '')
                      .isNotEmpty)
                    _labelValue(
                      'Account number',
                      invoice['bank_account_number_snapshot'].toString(),
                    ),
                  if ((invoice['payment_instructions_snapshot']
                              ?.toString()
                              .trim() ??
                          '')
                      .isNotEmpty)
                    _labelValue(
                      'Instructions',
                      invoice['payment_instructions_snapshot'].toString(),
                    ),
                ],
              ),
            ),
          ],
          if ((invoice['notes']?.toString().trim() ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Invoice Notes',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              invoice['notes'].toString(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }
}
