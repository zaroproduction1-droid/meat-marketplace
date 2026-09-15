import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CutLinkInvoicePdf {
  const CutLinkInvoicePdf._();

  static final _brand = PdfColor.fromHex('#741C1C');
  static final _navy = PdfColor.fromHex('#0B1F33');
  static final _soft = PdfColor.fromHex('#F5F6F7');
  static final _border = PdfColor.fromHex('#D7DADD');
  static final _muted = PdfColor.fromHex('#687078');
  static final _green = PdfColor.fromHex('#2E7D32');

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _money(dynamic value) =>
      '\$${_asDouble(value).toStringAsFixed(2)}';

  static String _date(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  static String _clean(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static Map<String, dynamic> _order(Map<String, dynamic> invoice) {
    final raw = invoice['orders'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return <String, dynamic>{};
  }

  static String _address({
    dynamic line1,
    dynamic line2,
    dynamic suburb,
    dynamic state,
    dynamic postcode,
  }) {
    return [
      _clean(line1, fallback: ''),
      _clean(line2, fallback: ''),
      [
        _clean(suburb, fallback: ''),
        _clean(state, fallback: ''),
        _clean(postcode, fallback: ''),
      ].where((e) => e.isNotEmpty).join(' '),
    ].where((e) => e.isNotEmpty).join(', ');
  }

  static String _paymentText(Map<String, dynamic> invoice) {
    final method = invoice['payment_method_snapshot']?.toString().trim() ?? '';
    final days = invoice['payment_terms_days_snapshot'];
    if (method.isEmpty) return '-';
    if (method.toLowerCase() == 'account' && days != null) {
      return 'Account - $days days';
    }
    if (method.toLowerCase() == 'cod') return 'COD';
    if (method.toLowerCase() == 'prepaid') return 'Prepaid';
    return method;
  }

  static String _statusLabel(dynamic value) {
    switch (value?.toString()) {
      case 'issued':
        return 'ISSUED';
      case 'part_paid':
        return 'PART PAID';
      case 'paid':
        return 'PAID';
      case 'void':
        return 'VOID';
      default:
        return 'INVOICE';
    }
  }

  static pw.Widget _logo(Uint8List? logoBytes, String supplierName) {
    if (logoBytes != null && logoBytes.isNotEmpty) {
      return pw.Container(
        width: 165,
        height: 68,
        alignment: pw.Alignment.centerLeft,
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          fit: pw.BoxFit.contain,
          alignment: pw.Alignment.centerLeft,
        ),
      );
    }

    return pw.Container(
      width: 165,
      height: 68,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        supplierName,
        maxLines: 2,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _partyBox({
    required String label,
    required String name,
    required List<String> lines,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              color: _brand,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: .7,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            name,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          for (final line in lines.where((e) => e.trim().isNotEmpty)) ...[
            pw.SizedBox(height: 2),
            pw.Text(line, style: const pw.TextStyle(fontSize: 8.4)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _infoCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              color: _muted,
              fontSize: 7.2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8.7, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String value, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _itemDescription(Map<String, dynamic> item) {
    final product = _clean(item['product_name_snapshot'], fallback: 'Product');
    final details = <String>[product];

    final gradeCode = _clean(item['grade_code'], fallback: '');
    final gradeName = _clean(item['grade_name'], fallback: '');
    final specification = _clean(item['specification_name'], fallback: '');
    final hamCode = _clean(item['ham_code'], fallback: '');
    final sku = _clean(item['sku_snapshot'], fallback: '');

    if (specification.isNotEmpty) details.add(specification);
    if (gradeCode.isNotEmpty || gradeName.isNotEmpty) {
      details.add(
        [
          if (gradeCode.isNotEmpty) gradeCode,
          if (gradeName.isNotEmpty && gradeName != gradeCode) gradeName,
        ].join(' - '),
      );
    }
    if (hamCode.isNotEmpty) details.add('HAM $hamCode');
    if (sku.isNotEmpty) details.add('SKU: $sku');

    return details.join('\n');
  }

  static pw.Widget _totalRow(String label, dynamic value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 10 : 8.5,
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
    Uint8List? supplierLogoBytes,
  }) async {
    final document = pw.Document();
    final order = _order(invoice);

    final supplierName =
        _clean(
          invoice['supplier_trading_name_snapshot'],
          fallback: '',
        ).isNotEmpty
        ? _clean(invoice['supplier_trading_name_snapshot'])
        : _clean(invoice['supplier_legal_name_snapshot'], fallback: 'Supplier');
    final supplierLegal = _clean(
      invoice['supplier_legal_name_snapshot'],
      fallback: '',
    );
    final supplierAddress = _address(
      line1: invoice['supplier_address_line_1_snapshot'],
      line2: invoice['supplier_address_line_2_snapshot'],
      suburb: invoice['supplier_suburb_snapshot'],
      state: invoice['supplier_state_snapshot'],
      postcode: invoice['supplier_postcode_snapshot'],
    );

    final customerName = _clean(
      invoice['customer_name_snapshot'] ??
          invoice['customer_legal_name_snapshot'],
      fallback: 'Customer',
    );
    final billingAddress = _address(
      line1: invoice['customer_billing_address_line_1_snapshot'],
      line2: invoice['customer_billing_address_line_2_snapshot'],
      suburb: invoice['customer_billing_suburb_snapshot'],
      state: invoice['customer_billing_state_snapshot'],
      postcode: invoice['customer_billing_postcode_snapshot'],
    );
    final deliveryAddress = _address(
      line1: order['delivery_address_line_1_snapshot'],
      line2: order['delivery_address_line_2_snapshot'],
      suburb: order['delivery_suburb_snapshot'],
      state: order['delivery_state_snapshot'],
      postcode:
          order['delivery_address_postcode_snapshot'] ??
          order['delivery_postcode_snapshot'],
    );

    final total = _asDouble(invoice['total_amount']);
    final paid = _asDouble(invoice['amount_paid']);
    final outstanding = _asDouble(invoice['outstanding_amount']) > 0
        ? _asDouble(invoice['outstanding_amount'])
        : (total - paid).clamp(0, double.infinity).toDouble();

    final invoiceStatus = _statusLabel(invoice['status']);
    final isPaid = invoice['status']?.toString() == 'paid';
    final fulfilment = order['fulfilment_method']?.toString().toLowerCase();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 26),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _border, width: .6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${_clean(invoice['supplier_trading_name_snapshot'], fallback: supplierName)} - CutLink generated tax invoice',
                style: pw.TextStyle(fontSize: 7.4, color: _muted),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 7.4, color: _muted),
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
                    _logo(supplierLogoBytes, supplierName),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      supplierName,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (supplierLegal.isNotEmpty &&
                        supplierLegal != supplierName)
                      pw.Text(
                        supplierLegal,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    if (supplierAddress.isNotEmpty)
                      pw.Text(
                        supplierAddress,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    if (_clean(
                      invoice['supplier_phone_snapshot'],
                      fallback: '',
                    ).isNotEmpty)
                      pw.Text(
                        'PH: ${_clean(invoice['supplier_phone_snapshot'])}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    if (_clean(
                      invoice['supplier_email_snapshot'],
                      fallback: '',
                    ).isNotEmpty)
                      pw.Text(
                        _clean(invoice['supplier_email_snapshot']),
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Container(
                width: 195,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: _soft,
                  borderRadius: pw.BorderRadius.circular(7),
                  border: pw.Border.all(color: _border),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      _clean(invoice['invoice_number'], fallback: 'Invoice'),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date: ${_date(invoice['invoice_date'] ?? invoice['issued_at'])}',
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                    pw.Text(
                      'Due: ${_date(invoice['due_date'])}',
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                    if (_clean(
                      invoice['supplier_abn_snapshot'],
                      fallback: '',
                    ).isNotEmpty)
                      pw.Text(
                        'ABN: ${_clean(invoice['supplier_abn_snapshot'])}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    if (_clean(
                      invoice['supplier_licence_number_snapshot'],
                      fallback: '',
                    ).isNotEmpty)
                      pw.Text(
                        'Licence: ${_clean(invoice['supplier_licence_number_snapshot'])}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    pw.SizedBox(height: 7),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: isPaid ? _green : _brand,
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Text(
                        invoiceStatus,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _partyBox(
                  label: 'Bill To',
                  name: customerName,
                  lines: [
                    _clean(
                      invoice['customer_legal_name_snapshot'],
                      fallback: '',
                    ),
                    if (_clean(
                      invoice['customer_abn_snapshot'],
                      fallback: '',
                    ).isNotEmpty)
                      'ABN: ${_clean(invoice['customer_abn_snapshot'], fallback: '')}',
                    billingAddress,
                    _clean(invoice['customer_phone_snapshot'], fallback: ''),
                    _clean(invoice['customer_email_snapshot'], fallback: ''),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _partyBox(
                  label: fulfilment == 'pickup' ? 'Collection' : 'Ship To',
                  name: fulfilment == 'pickup'
                      ? 'Customer Pickup'
                      : customerName,
                  lines: fulfilment == 'pickup'
                      ? [supplierAddress]
                      : [
                          _clean(
                            order['delivery_contact_name_snapshot'],
                            fallback: '',
                          ),
                          deliveryAddress,
                          _clean(
                            order['delivery_contact_phone_snapshot'],
                            fallback: '',
                          ),
                        ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: _infoCell(
                    'Customer Reference',
                    _clean(invoice['customer_reference_snapshot']),
                  ),
                ),
                pw.Container(width: .6, height: 42, color: _border),
                pw.Expanded(child: _infoCell('Payment', _paymentText(invoice))),
                pw.Container(width: .6, height: 42, color: _border),
                pw.Expanded(
                  child: _infoCell(
                    'Fulfilment',
                    fulfilment == 'pickup' ? 'Pickup' : 'Delivery',
                  ),
                ),
                pw.Container(width: .6, height: 42, color: _border),
                pw.Expanded(
                  child: _infoCell(
                    'Order',
                    _clean(order['order_number'] ?? invoice['order_id']),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _border, width: .5),
              top: pw.BorderSide(color: _border),
              bottom: pw.BorderSide(color: _border),
              left: pw.BorderSide(color: _border),
              right: pw.BorderSide(color: _border),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(4.1),
              1: const pw.FlexColumnWidth(1.05),
              2: const pw.FlexColumnWidth(1.15),
              3: const pw.FlexColumnWidth(1.35),
              4: const pw.FlexColumnWidth(1.45),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _navy),
                children:
                    [
                          _tableCell('DESCRIPTION', bold: true),
                          _tableCell(
                            'SUPPLIED',
                            bold: true,
                            align: pw.TextAlign.center,
                          ),
                          _tableCell(
                            'ACTUAL KG',
                            bold: true,
                            align: pw.TextAlign.center,
                          ),
                          _tableCell(
                            'RATE',
                            bold: true,
                            align: pw.TextAlign.right,
                          ),
                          _tableCell(
                            'TOTAL INC GST',
                            bold: true,
                            align: pw.TextAlign.right,
                          ),
                        ]
                        .map(
                          (w) => pw.DefaultTextStyle(
                            style: const pw.TextStyle(color: PdfColors.white),
                            child: w,
                          ),
                        )
                        .toList(),
              ),
              for (final item in items)
                pw.TableRow(
                  children: [
                    _tableCell(_itemDescription(item)),
                    _tableCell(
                      '${_clean(item['supplied_quantity'] ?? item['ordered_quantity'], fallback: '0')} ${_clean(item['supplied_quantity_unit'] ?? item['ordered_quantity_unit'], fallback: '')}',
                      align: pw.TextAlign.center,
                    ),
                    _tableCell(
                      item['actual_weight'] == null
                          ? '-'
                          : _asDouble(item['actual_weight']).toStringAsFixed(2),
                      align: pw.TextAlign.center,
                    ),
                    _tableCell(
                      '${_money(item['locked_unit_price'])} / ${_clean(item['price_basis'], fallback: 'unit')}',
                      align: pw.TextAlign.right,
                    ),
                    _tableCell(
                      _money(item['line_amount']),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (_clean(
                          invoice['bank_account_name_snapshot'],
                          fallback: '',
                        ).isNotEmpty ||
                        _clean(
                          invoice['bank_bsb_snapshot'],
                          fallback: '',
                        ).isNotEmpty ||
                        _clean(
                          invoice['bank_account_number_snapshot'],
                          fallback: '',
                        ).isNotEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: _soft,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: _border),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'PAYMENT DETAILS',
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: _brand,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            if (_clean(
                              invoice['bank_name_snapshot'],
                              fallback: '',
                            ).isNotEmpty)
                              pw.Text(
                                'Bank: ${_clean(invoice['bank_name_snapshot'])}',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                            if (_clean(
                              invoice['bank_account_name_snapshot'],
                              fallback: '',
                            ).isNotEmpty)
                              pw.Text(
                                'Account: ${_clean(invoice['bank_account_name_snapshot'])}',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                            if (_clean(
                              invoice['bank_bsb_snapshot'],
                              fallback: '',
                            ).isNotEmpty)
                              pw.Text(
                                'BSB: ${_clean(invoice['bank_bsb_snapshot'])}',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                            if (_clean(
                              invoice['bank_account_number_snapshot'],
                              fallback: '',
                            ).isNotEmpty)
                              pw.Text(
                                'Account No: ${_clean(invoice['bank_account_number_snapshot'])}',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                            if (_clean(
                              invoice['payment_instructions_snapshot'],
                              fallback: '',
                            ).isNotEmpty) ...[
                              pw.SizedBox(height: 5),
                              pw.Text(
                                _clean(
                                  invoice['payment_instructions_snapshot'],
                                ),
                                style: const pw.TextStyle(fontSize: 8.2),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_clean(invoice['notes'], fallback: '').isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'NOTES',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: _brand,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _clean(invoice['notes']),
                        style: const pw.TextStyle(fontSize: 8.3),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 205,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    _totalRow('Products inc GST', invoice['products_subtotal']),
                    _totalRow('Delivery inc GST', invoice['delivery_fee']),
                    _totalRow('GST included', invoice['tax_amount']),
                    pw.Divider(color: _border),
                    _totalRow('Total inc GST', total, bold: true),
                    _totalRow('Payments received', paid),
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 5),
                      padding: const pw.EdgeInsets.symmetric(vertical: 7),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: _navy, width: 1.2),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              'BALANCE DUE',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                          ),
                          pw.Text(
                            _money(outstanding),
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }
}
