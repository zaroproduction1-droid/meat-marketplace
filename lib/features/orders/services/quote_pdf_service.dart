import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CutLinkQuotePdf {
  const CutLinkQuotePdf._();

  static final _brand = PdfColor.fromHex('#741C1C');
  static final _navy = PdfColor.fromHex('#0B1F33');
  static final _soft = PdfColor.fromHex('#F5F6F7');
  static final _border = PdfColor.fromHex('#D7DADD');
  static final _muted = PdfColor.fromHex('#687078');

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _money(dynamic value) =>
      '\$${_number(value).toStringAsFixed(2)}';

  static String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '-';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  static String _clean(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _addressFromSupplier(Map<String, dynamic> supplier) =>
      [
            supplier['address_line_1'],
            supplier['address_line_2'],
            [supplier['suburb'], supplier['state'], supplier['postcode']]
                .map((e) => e?.toString().trim() ?? '')
                .where((e) => e.isNotEmpty)
                .join(' '),
          ]
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .join(', ');

  static String _customerAddress(
    Map<String, dynamic> customer, {
    required bool delivery,
  }) {
    final prefix = delivery ? 'delivery_' : 'billing_';
    final fallbackToDelivery = !delivery;

    String value(String suffix) {
      final primary = customer['$prefix$suffix']?.toString().trim() ?? '';
      if (primary.isNotEmpty) return primary;
      if (fallbackToDelivery) {
        return customer['delivery_$suffix']?.toString().trim() ?? '';
      }
      return '';
    }

    return [
      value('address_line_1'),
      value('address_line_2'),
      [
        value('suburb'),
        value('state'),
        value('postcode'),
      ].where((e) => e.isNotEmpty).join(' '),
    ].where((e) => e.isNotEmpty).join(', ');
  }

  static String _paymentText(Map<String, dynamic> quote) {
    final method = quote['payment_method_snapshot']?.toString().trim() ?? '';
    final days = quote['payment_terms_days_snapshot'];
    if (method.isEmpty) return '-';
    if (method.toLowerCase() == 'account' && days != null) {
      return 'Account - $days days';
    }
    if (method.toLowerCase() == 'cod') return 'COD';
    if (method.toLowerCase() == 'prepaid') return 'Prepaid';
    return method;
  }

  static String _fulfilmentText(Map<String, dynamic> quote) {
    final method = quote['fulfilment_method']?.toString().trim().toLowerCase();
    if (method == 'delivery') return 'Delivery';
    if (method == 'pickup') return 'Pickup';
    return '-';
  }

  static pw.Widget _logo(Uint8List? logoBytes, String supplierName) {
    if (logoBytes != null && logoBytes.isNotEmpty) {
      return pw.Container(
        width: 150,
        height: 62,
        alignment: pw.Alignment.centerLeft,
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          fit: pw.BoxFit.contain,
          alignment: pw.Alignment.centerLeft,
        ),
      );
    }

    return pw.Container(
      width: 150,
      height: 62,
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
            style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<Uint8List> build({
    required Map<String, dynamic> quote,
    required Map<String, dynamic> supplier,
    required Map<String, dynamic> supplierProfile,
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
    Uint8List? supplierLogoBytes,
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
        ? supplier['trading_name'].toString().trim()
        : _clean(supplier['legal_name'], fallback: 'Supplier');
    final supplierLegal = _clean(supplier['legal_name'], fallback: '');
    final supplierAddress = _addressFromSupplier(supplier);
    final customerName =
        customer['customer_name']?.toString().trim().isNotEmpty == true
        ? customer['customer_name'].toString().trim()
        : _clean(customer['legal_name'], fallback: 'Customer');

    final quoteDate = _date(
      quote['quote_last_saved_at'] ?? quote['created_at'],
    );
    final requestedDate = _date(quote['requested_fulfilment_date']);
    final deliveryAddress = _customerAddress(customer, delivery: true);
    final billingAddress = _customerAddress(customer, delivery: false);

    final supplierAbn = _clean(
      supplierProfile['abn'] ?? supplier['abn'],
      fallback: '',
    );
    final supplierLicence = _clean(
      supplierProfile['licence_number'],
      fallback: '',
    );
    final supplierPhone = _clean(
      supplierProfile['invoice_phone'] ?? supplier['business_phone'],
      fallback: '',
    );
    final supplierEmail = _clean(
      supplierProfile['invoice_email'] ?? supplier['business_email'],
      fallback: '',
    );

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
                'This document is a quote and not a tax invoice.',
                style: pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 7.5, color: _muted),
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
                    if (supplierPhone.isNotEmpty)
                      pw.Text(
                        'PH: $supplierPhone',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    if (supplierEmail.isNotEmpty)
                      pw.Text(
                        supplierEmail,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Container(
                width: 190,
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
                      'QUOTE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      quoteNumber,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date: $quoteDate',
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                    if (supplierAbn.isNotEmpty)
                      pw.Text(
                        'ABN: $supplierAbn',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    if (supplierLicence.isNotEmpty)
                      pw.Text(
                        'Licence: $supplierLicence',
                        style: const pw.TextStyle(fontSize: 8.5),
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
                  label: 'Quote To',
                  name: customerName,
                  lines: [
                    _clean(customer['legal_name'], fallback: ''),
                    if (_clean(customer['abn'], fallback: '').isNotEmpty)
                      'ABN: ${_clean(customer['abn'], fallback: '')}',
                    _clean(customer['contact_name'], fallback: ''),
                    billingAddress,
                    _clean(customer['phone'], fallback: ''),
                    _clean(customer['email'], fallback: ''),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _partyBox(
                  label: _fulfilmentText(quote) == 'Pickup'
                      ? 'Collection'
                      : 'Deliver To',
                  name: _fulfilmentText(quote) == 'Pickup'
                      ? 'Customer Pickup'
                      : customerName,
                  lines: _fulfilmentText(quote) == 'Pickup'
                      ? [supplierAddress]
                      : [
                          deliveryAddress,
                          _clean(customer['phone'], fallback: ''),
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
                    _clean(quote['customer_reference']),
                  ),
                ),
                pw.Container(width: .6, height: 42, color: _border),
                pw.Expanded(child: _infoCell('Payment', _paymentText(quote))),
                pw.Container(width: .6, height: 42, color: _border),
                pw.Expanded(
                  child: _infoCell('Fulfilment', _fulfilmentText(quote)),
                ),
                pw.Container(width: .6, height: 42, color: _border),
                pw.Expanded(child: _infoCell('Requested', requestedDate)),
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
              0: const pw.FlexColumnWidth(4.6),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.3),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _navy),
                children:
                    [
                          _tableCell('DESCRIPTION', bold: true),
                          _tableCell(
                            'QTY',
                            bold: true,
                            align: pw.TextAlign.center,
                          ),
                          _tableCell(
                            'BASIS',
                            bold: true,
                            align: pw.TextAlign.center,
                          ),
                          _tableCell(
                            'RATE INC GST',
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
                    _tableCell(
                      [
                        [
                          _clean(
                            item['product_name_snapshot'],
                            fallback: 'Product',
                          ),
                          if (_clean(
                                item['grade_code'],
                                fallback: '',
                              ).isNotEmpty ||
                              _clean(
                                item['grade_name'],
                                fallback: '',
                              ).isNotEmpty)
                            [
                              if (_clean(
                                item['grade_code'],
                                fallback: '',
                              ).isNotEmpty)
                                _clean(item['grade_code'], fallback: ''),
                              if (_clean(
                                    item['grade_name'],
                                    fallback: '',
                                  ).isNotEmpty &&
                                  _clean(item['grade_name'], fallback: '') !=
                                      _clean(item['grade_code'], fallback: ''))
                                _clean(item['grade_name'], fallback: ''),
                            ].join(' - '),
                        ].join(' - '),
                        if (_clean(
                          item['sku_snapshot'],
                          fallback: '',
                        ).isNotEmpty)
                          'SKU: ${_clean(item['sku_snapshot'], fallback: '')}',
                        if (_clean(item['notes'], fallback: '').isNotEmpty)
                          _clean(item['notes'], fallback: ''),
                        if (_clean(
                          item['discount_type'],
                          fallback: '',
                        ).isNotEmpty)
                          item['discount_type']?.toString() == 'percent'
                              ? 'Discount: ${_number(item['discount_value']).toStringAsFixed(2)}%${_number(item['discount_amount']) > 0 ? ' (-${_money(item['discount_amount'])})' : ''}'
                              : 'Discount: ${_money(item['discount_value'])}${_number(item['discount_amount']) > 0 ? ' (-${_money(item['discount_amount'])})' : ''}',
                        if (_clean(
                          item['public_comment'],
                          fallback: '',
                        ).isNotEmpty)
                          'Note: ${_clean(item['public_comment'], fallback: '')}',
                      ].join('\n'),
                    ),
                    _tableCell(
                      '${_number(item['quantity']).toStringAsFixed(_number(item['quantity']) % 1 == 0 ? 0 : 2)} ${_clean(item['quantity_unit'], fallback: '')}',
                      align: pw.TextAlign.center,
                    ),
                    _tableCell(
                      _clean(item['price_basis'], fallback: 'unit'),
                      align: pw.TextAlign.center,
                    ),
                    _tableCell(
                      _money(item['unit_price']),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(11),
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Catch-weight products are invoiced using the actual kilograms supplied. The quoted rate is locked per pricing basis; final invoice totals may vary with actual supplied weight.',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                width: 190,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      'COMMERCIAL SUMMARY',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _muted,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Delivery', style: pw.TextStyle(fontSize: 8.5)),
                        pw.Text(
                          _number(quote['delivery_fee']) == 0
                              ? 'Free / N/A'
                              : _money(quote['delivery_fee']),
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Final total confirmed after actual weights are supplied.',
                      style: pw.TextStyle(fontSize: 7.7, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_clean(quote['delivery_notes'], fallback: '').isNotEmpty ||
              _clean(quote['internal_notes'], fallback: '').isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'NOTES',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.SizedBox(height: 5),
            if (_clean(quote['delivery_notes'], fallback: '').isNotEmpty)
              pw.Text(
                'Delivery: ${_clean(quote['delivery_notes'], fallback: '')}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
          ],
        ],
      ),
    );

    return document.save();
  }
}
