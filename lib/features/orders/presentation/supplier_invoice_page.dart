import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierInvoicePage extends StatefulWidget {
  const SupplierInvoicePage({super.key, required this.orderId});

  final String orderId;

  @override
  State<SupplierInvoicePage> createState() => _SupplierInvoicePageState();
}

class _SupplierInvoicePageState extends State<SupplierInvoicePage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];

  final _taxCategoryController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _taxCategoryController.dispose();
    _taxRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      final created = await client.rpc(
        'create_or_get_invoice_from_order',
        params: {'target_order_id': widget.orderId},
      );

      final invoice = Map<String, dynamic>.from(created as Map);

      final response = await client
          .from('invoices')
          .select('''
            id,
            invoice_number,
            order_id,
            supplier_business_id,
            butcher_business_id,
            supplier_customer_account_id,
            status,
            customer_name_snapshot,
            customer_reference_snapshot,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            products_subtotal,
            delivery_fee,
            tax_status,
            tax_category_snapshot,
            tax_rate_snapshot,
            tax_amount,
            total_amount,
            invoice_date,
            due_date,
            notes,
            issued_at,
            paid_at,
            voided_at,
            created_at,
            updated_at,
            invoice_items(
              id,
              order_item_id,
              product_id,
              product_name_snapshot,
              sku_snapshot,
              ordered_quantity,
              ordered_quantity_unit,
              supplied_quantity,
              supplied_quantity_unit,
              catch_weight_snapshot,
              actual_weight,
              actual_weight_unit,
              locked_unit_price,
              price_basis,
              line_amount,
              notes_snapshot
            )
          ''')
          .eq('id', invoice['id'])
          .single();

      if (!mounted) {
        return;
      }

      final loaded = Map<String, dynamic>.from(response);
      final rawItems = loaded['invoice_items'];

      _taxCategoryController.text =
          loaded['tax_category_snapshot']?.toString() ?? '';

      final taxRate = loaded['tax_rate_snapshot'];
      _taxRateController.text = taxRate == null
          ? ''
          : (_asDouble(taxRate) * 100).toStringAsFixed(
              _asDouble(taxRate) * 100 ==
                      (_asDouble(taxRate) * 100).roundToDouble()
                  ? 0
                  : 2,
            );

      _notesController.text = loaded['notes']?.toString() ?? '';

      setState(() {
        _invoice = loaded;
        _items = rawItems is List
            ? rawItems
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  String _money(dynamic value) {
    final number = _asDouble(value);
    return '\$${number.toStringAsFixed(2)}';
  }

  String _formatNumber(dynamic value) {
    final number = _asDouble(value);

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _unitLabel(String? value) {
    return switch (value) {
      'carton' => 'cartons',
      'kilogram' => 'kg',
      'unit' => 'units',
      _ => value ?? '',
    };
  }

  String _basisLabel(String? value) {
    return switch (value) {
      'carton' => 'carton',
      'kilogram' => 'kg',
      'unit' => 'unit',
      _ => value ?? '',
    };
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'draft' => 'Draft',
      'ready' => 'Ready',
      'issued' => 'Issued',
      'part_paid' => 'Part Paid',
      'paid' => 'Paid',
      'void' => 'Void',
      _ => status ?? 'Unknown',
    };
  }

  String _paymentText() {
    final method = _invoice?['payment_method_snapshot']?.toString();

    switch (method) {
      case 'account':
        final days = _invoice?['payment_terms_days_snapshot'];
        return '${_formatNumber(days)} day account';
      case 'prepaid':
        return 'Prepaid';
      case 'cod':
        return 'COD';
      default:
        return 'Not recorded';
    }
  }

  bool get _taxConfigured =>
      _invoice?['tax_status']?.toString() == 'configured';

  bool get _canEditTax {
    final status = _invoice?['status']?.toString();
    return status == 'draft' || status == 'ready';
  }

  bool get _canIssue =>
      _invoice?['status']?.toString() == 'ready' && _taxConfigured;

  Future<void> _saveNotes() async {
    final id = _invoice?['id']?.toString();

    if (id == null || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await Supabase.instance.client
          .from('invoices')
          .update({
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          })
          .eq('id', id)
          .select()
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = Map<String, dynamic>.from(updated);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice notes saved.')));
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _configureTax() async {
    final invoiceId = _invoice?['id']?.toString();

    if (invoiceId == null || !_canEditTax || _isSaving) {
      return;
    }

    final category = _taxCategoryController.text.trim();
    final ratePercent = double.tryParse(_taxRateController.text.trim());

    if (category.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a tax category.')));
      return;
    }

    if (ratePercent == null || ratePercent < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid tax rate percentage.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Configure Invoice Tax?'),
        content: Text(
          'Apply tax category "$category" at '
          '${ratePercent.toStringAsFixed(2)}% to this invoice?\n\n'
          'Only continue if this is the correct tax treatment for this invoice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            child: const Text('Apply Tax'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await Supabase.instance.client.rpc(
        'configure_invoice_tax',
        params: {
          'target_invoice_id': invoiceId,
          'target_tax_category': category,
          'target_tax_rate': ratePercent / 100,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = Map<String, dynamic>.from(updated as Map);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice tax configured.')));

      await _loadPage();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _issueInvoice() async {
    final invoiceId = _invoice?['id']?.toString();

    if (invoiceId == null || !_canIssue || _isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issue Invoice?'),
        content: Text(
          'Issue ${_invoice?['invoice_number'] ?? 'this invoice'} to '
          '${_invoice?['customer_name_snapshot'] ?? 'the customer'}?\n\n'
          'After issuing, the tax and final invoice total are locked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            child: const Text('Issue Invoice'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await Supabase.instance.client.rpc(
        'issue_invoice',
        params: {'target_invoice_id': invoiceId},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = Map<String, dynamic>.from(updated as Map);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice issued.')));

      await _loadPage();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<Uint8List> _buildInvoicePdf() async {
    final document = pw.Document();

    final invoiceNumber = _invoice?['invoice_number']?.toString() ?? 'Invoice';

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
                  'TAX INVOICE',
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
                  invoiceNumber,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Status: ${_statusLabel(_invoice?['status']?.toString())}',
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
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfLabelValue(
                  'Customer',
                  _invoice?['customer_name_snapshot']?.toString() ?? '',
                ),
                if ((_invoice?['customer_reference_snapshot']
                            ?.toString()
                            .trim() ??
                        '')
                    .isNotEmpty)
                  _pdfLabelValue(
                    'Customer reference',
                    _invoice!['customer_reference_snapshot'].toString(),
                  ),
                _pdfLabelValue(
                  'Invoice date',
                  _invoice?['invoice_date']?.toString() ?? '',
                ),
                _pdfLabelValue(
                  'Due date',
                  _invoice?['due_date']?.toString() ?? '',
                ),
                _pdfLabelValue('Payment terms', _paymentText()),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.0),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Product', bold: true),
                  _pdfCell('Supplied', bold: true),
                  _pdfCell('Actual kg', bold: true),
                  _pdfCell('Rate', bold: true),
                  _pdfCell('Amount', bold: true),
                ],
              ),
              for (final item in _items)
                pw.TableRow(
                  children: [
                    _pdfCell(
                      [
                        item['product_name_snapshot']?.toString() ?? 'Product',
                        if ((item['sku_snapshot']?.toString().trim() ?? '')
                            .isNotEmpty)
                          'SKU: ${item['sku_snapshot']}',
                      ].join('\n'),
                    ),
                    _pdfCell(
                      '${_formatNumber(item['supplied_quantity'])} '
                      '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                    ),
                    _pdfCell(
                      item['catch_weight_snapshot'] == true
                          ? _formatNumber(item['actual_weight'])
                          : '',
                    ),
                    _pdfCell(
                      '${_money(item['locked_unit_price'])}'
                      '${_basisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_basisLabel(item['price_basis']?.toString())}'}',
                    ),
                    _pdfCell(_money(item['line_amount'])),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _pdfTotalRow(
                    'Products',
                    _money(_invoice?['products_subtotal']),
                  ),
                  _pdfTotalRow(
                    'Delivery',
                    _asDouble(_invoice?['delivery_fee']) == 0
                        ? 'Free'
                        : _money(_invoice?['delivery_fee']),
                  ),
                  _pdfTotalRow(
                    'Tax',
                    _taxConfigured
                        ? _money(_invoice?['tax_amount'])
                        : 'Pending configuration',
                  ),
                  pw.Divider(),
                  _pdfTotalRow(
                    'Total',
                    _invoice?['total_amount'] == null
                        ? 'Pending'
                        : _money(_invoice?['total_amount']),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          if (_notesController.text.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              _notesController.text.trim(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 105,
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

  pw.Widget _pdfCell(String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 8.2,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfTotalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice() async {
    if (_invoice == null || _isSaving) {
      return;
    }

    try {
      await Printing.layoutPdf(
        name: '${_invoice?['invoice_number'] ?? 'CutLink-Invoice'}.pdf',
        onLayout: (_) => _buildInvoicePdf(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create invoice PDF: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          _invoice?['invoice_number']?.toString() ?? 'Supplier Invoice',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _isLoading || _invoice == null ? null : _printInvoice,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print Invoice'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : _loadPage,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final status = _invoice?['status']?.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _invoice?['invoice_number']?.toString() ?? 'Invoice',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.receipt_long_outlined, size: 17),
                  label: Text(_statusLabel(status)),
                ),
                Chip(
                  avatar: Icon(
                    _taxConfigured
                        ? Icons.verified_outlined
                        : Icons.warning_amber_outlined,
                    size: 17,
                  ),
                  label: Text(
                    _taxConfigured
                        ? 'Tax configured'
                        : 'Tax configuration required',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _invoice?['customer_name_snapshot']?.toString() ?? 'Customer',
              style: const TextStyle(
                color: _darkRed,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 14,
                  children: [
                    _InfoValue(
                      label: 'Invoice date',
                      value: _invoice?['invoice_date']?.toString() ?? '',
                    ),
                    _InfoValue(
                      label: 'Due date',
                      value: _invoice?['due_date']?.toString() ?? '',
                    ),
                    _InfoValue(label: 'Payment', value: _paymentText()),
                    if ((_invoice?['customer_reference_snapshot']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty)
                      _InfoValue(
                        label: 'Customer reference',
                        value: _invoice!['customer_reference_snapshot']
                            .toString(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Invoice Items',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final item in _items) _buildItemCard(item),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _TotalRow(
                          label: 'Products',
                          value: _money(_invoice?['products_subtotal']),
                        ),
                        _TotalRow(
                          label: 'Delivery',
                          value: _asDouble(_invoice?['delivery_fee']) == 0
                              ? 'Free'
                              : _money(_invoice?['delivery_fee']),
                        ),
                        _TotalRow(
                          label: 'Tax',
                          value: _taxConfigured
                              ? _money(_invoice?['tax_amount'])
                              : 'Pending',
                        ),
                        const Divider(),
                        _TotalRow(
                          label: 'Total',
                          value: _invoice?['total_amount'] == null
                              ? 'Pending tax'
                              : _money(_invoice?['total_amount']),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tax Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'CutLink does not guess the tax rate. Enter the correct tax category and percentage before issuing the invoice.',
                      style: TextStyle(color: Color(0xFF666666), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 650;

                        final category = TextField(
                          controller: _taxCategoryController,
                          enabled: _canEditTax && !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Tax category',
                            hintText: 'Example: GST taxable',
                            border: OutlineInputBorder(),
                          ),
                        );

                        final rate = TextField(
                          controller: _taxRateController,
                          enabled: _canEditTax && !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tax rate',
                            suffixText: '%',
                            border: OutlineInputBorder(),
                          ),
                        );

                        if (narrow) {
                          return Column(
                            children: [
                              category,
                              const SizedBox(height: 12),
                              rate,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: category),
                            const SizedBox(width: 12),
                            SizedBox(width: 220, child: rate),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _canEditTax && !_isSaving
                          ? _configureTax
                          : null,
                      style: FilledButton.styleFrom(backgroundColor: _darkRed),
                      icon: const Icon(Icons.calculate_outlined),
                      label: Text(
                        _taxConfigured ? 'Update Tax' : 'Configure Tax',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      enabled: status != 'void' && !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: status != 'void' && !_isSaving
                          ? _saveNotes
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Notes'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _canIssue && !_isSaving ? _issueInvoice : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.send_outlined),
                label: Text(
                  status == 'issued'
                      ? 'Invoice Issued'
                      : _canIssue
                      ? 'Issue Invoice'
                      : 'Configure Tax Before Issuing',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final catchWeight = item['catch_weight_snapshot'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 650;

            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name_snapshot']?.toString() ?? 'Product',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((item['sku_snapshot']?.toString().trim() ?? '').isNotEmpty)
                  Text(
                    'SKU: ${item['sku_snapshot']}',
                    style: const TextStyle(color: Color(0xFF666666)),
                  ),
                const SizedBox(height: 7),
                Text(
                  'Supplied: ${_formatNumber(item['supplied_quantity'])} '
                  '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                ),
                if (catchWeight) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Actual weight: ${_formatNumber(item['actual_weight'])} kg',
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Locked rate: ${_money(item['locked_unit_price'])}'
                  '${_basisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_basisLabel(item['price_basis']?.toString())}'}',
                  style: const TextStyle(color: Color(0xFF555555)),
                ),
              ],
            );

            final right = Text(
              _money(item['line_amount']),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [left, const SizedBox(height: 12), right],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                right,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoValue extends StatelessWidget {
  const _InfoValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          const SizedBox(width: 20),
          Text(value, style: style),
        ],
      ),
    );
  }
}
