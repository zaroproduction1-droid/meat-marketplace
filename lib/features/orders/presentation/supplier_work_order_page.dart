import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierWorkOrderPage extends StatefulWidget {
  const SupplierWorkOrderPage({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<SupplierWorkOrderPage> createState() => _SupplierWorkOrderPageState();
}

class _SupplierWorkOrderPageState extends State<SupplierWorkOrderPage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Map<String, dynamic>? _workOrder;
  Map<String, dynamic>? _order;

  final _instructionsController = TextEditingController();
  final _pickedByController = TextEditingController();
  final _checkedByController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _pickedByController.dispose();
    _checkedByController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      final workOrderResponse = await client.rpc(
        'create_or_get_warehouse_work_order',
        params: {'target_order_id': widget.orderId},
      );

      final workOrder = Map<String, dynamic>.from(workOrderResponse as Map);

      final orderResponse = await client
          .from('orders')
          .select('''
            id,
            order_number,
            status,
            customer_reference,
            delivery_notes,
            internal_notes,
            supplier_customer_account_id,
            pricing_status,
            created_at,
            accepted_at,
            supplier_customer_accounts(
              id,
              customer_name,
              legal_name,
              account_reference,
              delivery_address_line_1,
              delivery_address_line_2,
              delivery_suburb,
              delivery_state,
              delivery_postcode
            ),
            businesses!orders_butcher_business_id_fkey(
              legal_name,
              trading_name
            ),
            order_items(
              id,
              product_name_snapshot,
              sku_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              notes,
              supplied_quantity,
              supplied_quantity_unit,
              actual_weight,
              actual_weight_unit,
              final_line_amount,
              fulfilment_status,
              catch_weight_snapshot
            )
          ''')
          .eq('id', widget.orderId)
          .single();

      if (!mounted) {
        return;
      }

      final order = Map<String, dynamic>.from(orderResponse);

      _instructionsController.text =
          workOrder['warehouse_instructions']?.toString() ?? '';
      _pickedByController.text = workOrder['picked_by']?.toString() ?? '';
      _checkedByController.text = workOrder['checked_by']?.toString() ?? '';

      setState(() {
        _workOrder = workOrder;
        _order = order;
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

  List<Map<String, dynamic>> get _items {
    final raw = _order?['order_items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _customerName() {
    final accountRaw = _order?['supplier_customer_accounts'];

    if (accountRaw is Map) {
      final account = Map<String, dynamic>.from(accountRaw);
      final customerName = account['customer_name']?.toString().trim();

      if (customerName != null && customerName.isNotEmpty) {
        return customerName;
      }

      final legalName = account['legal_name']?.toString().trim();

      if (legalName != null && legalName.isNotEmpty) {
        return legalName;
      }
    }

    final businessRaw = _order?['businesses'];

    if (businessRaw is Map) {
      final business = Map<String, dynamic>.from(businessRaw);
      final tradingName = business['trading_name']?.toString().trim();

      if (tradingName != null && tradingName.isNotEmpty) {
        return tradingName;
      }

      final legalName = business['legal_name']?.toString().trim();

      if (legalName != null && legalName.isNotEmpty) {
        return legalName;
      }
    }

    return 'Customer';
  }

  String _deliveryAddress() {
    final raw = _order?['supplier_customer_accounts'];

    if (raw is! Map) {
      return 'Not recorded';
    }

    final account = Map<String, dynamic>.from(raw);

    final parts = <String>[
      if ((account['delivery_address_line_1']?.toString().trim() ?? '').isNotEmpty)
        account['delivery_address_line_1'].toString().trim(),
      if ((account['delivery_address_line_2']?.toString().trim() ?? '').isNotEmpty)
        account['delivery_address_line_2'].toString().trim(),
      if ((account['delivery_suburb']?.toString().trim() ?? '').isNotEmpty)
        account['delivery_suburb'].toString().trim(),
      if ((account['delivery_state']?.toString().trim() ?? '').isNotEmpty)
        account['delivery_state'].toString().trim(),
      if ((account['delivery_postcode']?.toString().trim() ?? '').isNotEmpty)
        account['delivery_postcode'].toString().trim(),
    ];

    return parts.isEmpty ? 'Not recorded' : parts.join(', ');
  }

  bool _isCatchWeight(Map<String, dynamic> item) {
    return item['catch_weight_snapshot'] == true &&
        item['price_basis']?.toString() == 'kilogram';
  }

  String _formatNumber(dynamic value) {
    if (value == null) {
      return '0';
    }

    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return value.toString();
    }

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return '\$0.00';
    }

    return '\$${number.toStringAsFixed(2)}';
  }

  String _unitLabel(String? value) {
    return switch (value) {
      'carton' => 'cartons',
      'kilogram' => 'kg',
      'unit' => 'units',
      _ => value ?? '',
    };
  }

  String _workOrderStatusLabel(String? status) {
    return switch (status) {
      'created' => 'Created',
      'printed' => 'Printed',
      'picking' => 'Picking',
      'picked' => 'Picked',
      'completed' => 'Completed',
      _ => status ?? 'Unknown',
    };
  }

  Future<void> _saveWorkOrderDetails({
    String? status,
  }) async {
    final workOrderId = _workOrder?['id']?.toString();

    if (workOrderId == null || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final updates = <String, dynamic>{
        'warehouse_instructions': _nullIfEmpty(_instructionsController.text),
        'picked_by': _nullIfEmpty(_pickedByController.text),
        'checked_by': _nullIfEmpty(_checkedByController.text),
      };

      if (status != null) {
        updates['status'] = status;

        if (status == 'picking') {
          updates['picking_started_at'] = now;
        }

        if (status == 'picked') {
          updates['picked_at'] = now;
        }

        if (status == 'completed') {
          updates['completed_at'] = now;
        }
      }

      final updated = await Supabase.instance.client
          .from('warehouse_work_orders')
          .update(updates)
          .eq('id', workOrderId)
          .select()
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _workOrder = Map<String, dynamic>.from(updated);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == null
                ? 'Work order details saved.'
                : 'Work order marked ${_workOrderStatusLabel(status).toLowerCase()}.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _editLineFulfilment(Map<String, dynamic> item) async {
    final itemId = item['id']?.toString();

    if (itemId == null) {
      return;
    }

    final catchWeight = _isCatchWeight(item);
    final orderedQuantity = item['quantity'];

    final suppliedController = TextEditingController(
      text: item['supplied_quantity']?.toString() ??
          _formatNumber(orderedQuantity),
    );

    final weightController = TextEditingController(
      text: item['actual_weight']?.toString() ?? '',
    );

    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> save() async {
                if (saving) {
                  return;
                }

                final supplied =
                    double.tryParse(suppliedController.text.trim());
                final actualWeight =
                    double.tryParse(weightController.text.trim());

                if (supplied == null || supplied < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid supplied quantity.'),
                    ),
                  );
                  return;
                }

                final quantityUnit = item['quantity_unit']?.toString() ?? 'unit';

                if ((quantityUnit == 'carton' || quantityUnit == 'unit') &&
                    supplied != supplied.roundToDouble()) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Supplied cartons and units must be whole numbers.',
                      ),
                    ),
                  );
                  return;
                }

                if (catchWeight &&
                    (actualWeight == null || actualWeight <= 0)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter the actual supplied kilograms.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                try {
                  final updates = <String, dynamic>{
                    'supplied_quantity': supplied,
                    'supplied_quantity_unit': quantityUnit,
                    'fulfilment_status': 'finalised',
                    'finalised_at':
                        DateTime.now().toUtc().toIso8601String(),
                  };

                  if (catchWeight) {
                    updates['actual_weight'] = actualWeight;
                    updates['actual_weight_unit'] = 'kilogram';
                  }

                  await Supabase.instance.client
                      .from('order_items')
                      .update(updates)
                      .eq('id', itemId)
                      .eq('order_id', widget.orderId);

                  await Supabase.instance.client.rpc(
                    'refresh_order_pricing_status',
                    params: {'target_order_id': widget.orderId},
                  );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Warehouse fulfilment saved.'),
                    ),
                  );

                  await _loadPage();
                } on PostgrestException catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );

                    setDialogState(() {
                      saving = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(
                  item['product_name_snapshot']?.toString() ?? 'Product',
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ordered: ${_formatNumber(item['quantity'])} '
                          '${_unitLabel(item['quantity_unit']?.toString())}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: suppliedController,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          inputFormatters:
                              item['quantity_unit']?.toString() == 'carton' ||
                                      item['quantity_unit']?.toString() == 'unit'
                                  ? [FilteringTextInputFormatter.digitsOnly]
                                  : null,
                          decoration: InputDecoration(
                            labelText: 'Quantity supplied',
                            suffixText:
                                _unitLabel(item['quantity_unit']?.toString()),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (catchWeight) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: weightController,
                            enabled: !saving,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Actual total weight',
                              suffixText: 'kg',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Final line amount is calculated from actual kg × the locked order-time \$/kg rate.',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving...' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      suppliedController.dispose();
      weightController.dispose();
    }
  }

  bool get _allLinesFinalised {
    if (_items.isEmpty) {
      return false;
    }

    return _items.every(
      (item) => item['fulfilment_status']?.toString() == 'finalised',
    );
  }


  Future<Uint8List> _buildPickSlipPdf() async {
    final document = pw.Document();

    pw.Widget labelValue(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      );
    }

    final workOrderNumber =
        _workOrder?['work_order_number']?.toString() ?? 'Work Order';
    final salesOrderNumber =
        _order?['order_number']?.toString() ?? widget.orderId;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
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
                      'WAREHOUSE WORK ORDER / PICK SLIP',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      workOrderNumber,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Sales Order: $salesOrderNumber',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CutLink warehouse document',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                labelValue('Customer', _customerName()),
                labelValue('Delivery address', _deliveryAddress()),
                if ((_order?['customer_reference']?.toString().trim() ?? '')
                    .isNotEmpty)
                  labelValue(
                    'Customer reference',
                    _order!['customer_reference'].toString(),
                  ),
                if ((_order?['delivery_notes']?.toString().trim() ?? '')
                    .isNotEmpty)
                  labelValue(
                    'Delivery notes',
                    _order!['delivery_notes'].toString(),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'PICK LIST',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.6,
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(22),
              1: pw.FlexColumnWidth(3.0),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                children: [
                  _pdfCell(''),
                  _pdfCell('Product / SKU', bold: true),
                  _pdfCell('Ordered', bold: true),
                  _pdfCell('Supplied', bold: true),
                  _pdfCell('Actual kg', bold: true),
                ],
              ),
              for (final item in _items)
                pw.TableRow(
                  children: [
                    _pdfCell(
                      item['fulfilment_status']?.toString() == 'finalised'
                          ? 'X'
                          : '',
                      center: true,
                    ),
                    _pdfCell(
                      [
                        item['product_name_snapshot']?.toString() ?? 'Product',
                        if ((item['sku_snapshot']?.toString().trim() ?? '')
                            .isNotEmpty)
                          'SKU: ${item['sku_snapshot']}',
                        if ((item['notes']?.toString().trim() ?? '').isNotEmpty)
                          'Notes: ${item['notes']}',
                      ].join('\n'),
                    ),
                    _pdfCell(
                      '${_formatNumber(item['quantity'])} '
                      '${_unitLabel(item['quantity_unit']?.toString())}',
                    ),
                    _pdfCell(
                      item['supplied_quantity'] == null
                          ? ''
                          : '${_formatNumber(item['supplied_quantity'])} '
                              '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                    ),
                    _pdfCell(
                      _isCatchWeight(item) && item['actual_weight'] != null
                          ? _formatNumber(item['actual_weight'])
                          : '',
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Text(
              'Catch-weight lines are ordered by carton and priced per kilogram. '
              'Actual kilograms must come from the warehouse scale. '
              'No estimated carton weights or estimated catch-weight totals are used.',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
          if (_instructionsController.text.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'WAREHOUSE INSTRUCTIONS',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Text(
                _instructionsController.text.trim(),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              pw.Expanded(
                child: _pdfSignatureBox(
                  'Picked by',
                  _pickedByController.text.trim(),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _pdfSignatureBox(
                  'Checked by',
                  _checkedByController.text.trim(),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'This is an internal warehouse document and is not an invoice.',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfCell(
    String value, {
    bool bold = false,
    bool center = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 7,
      ),
      child: pw.Text(
        value,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfSignatureBox(String label, String value) {
    return pw.Container(
      height: 66,
      padding: const pw.EdgeInsets.all(9),
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
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            value.isEmpty ? '____________________________' : value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  Future<void> _printPickSlip() async {
    if (_workOrder == null || _order == null || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final printed = await Printing.layoutPdf(
        name:
            '${_workOrder?['work_order_number'] ?? 'CutLink-Work-Order'}.pdf',
        onLayout: (_) => _buildPickSlipPdf(),
      );

      if (!printed || !mounted) {
        return;
      }

      final workOrderId = _workOrder?['id']?.toString();
      final currentStatus = _workOrder?['status']?.toString();

      if (workOrderId != null) {
        final updates = <String, dynamic>{
          'printed_at': DateTime.now().toUtc().toIso8601String(),
        };

        if (currentStatus == 'created') {
          updates['status'] = 'printed';
        }

        final updated = await Supabase.instance.client
            .from('warehouse_work_orders')
            .update(updates)
            .eq('id', workOrderId)
            .select()
            .single();

        if (mounted) {
          setState(() {
            _workOrder = Map<String, dynamic>.from(updated);
          });
        }
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create pick slip: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
          _workOrder?['work_order_number']?.toString() ??
              'Warehouse Work Order',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _isLoading || _isSaving ? null : _printPickSlip,
            style: FilledButton.styleFrom(
              backgroundColor: _darkRed,
            ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print Pick Slip'),
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
              const Icon(
                Icons.error_outline,
                size: 60,
                color: _darkRed,
              ),
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

    final status = _workOrder?['status']?.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _order?['order_number']?.toString() ?? 'Order',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 17),
                  label: Text(_workOrderStatusLabel(status)),
                ),
                if (_order?['pricing_status']?.toString() == 'pending_weight')
                  const Chip(
                    avatar: Icon(Icons.scale_outlined, size: 17),
                    label: Text('Weight pending'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _customerName(),
              style: const TextStyle(
                color: _darkRed,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            _InfoCard(
              title: 'Customer / Delivery',
              rows: [
                _InfoRowData('Customer', _customerName()),
                _InfoRowData('Delivery address', _deliveryAddress()),
                if ((_order?['customer_reference']?.toString().trim() ?? '')
                    .isNotEmpty)
                  _InfoRowData(
                    'Customer reference',
                    _order!['customer_reference'].toString(),
                  ),
                if ((_order?['delivery_notes']?.toString().trim() ?? '')
                    .isNotEmpty)
                  _InfoRowData(
                    'Delivery notes',
                    _order!['delivery_notes'].toString(),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Pick List',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in _items) _buildItemCard(item),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Warehouse Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _instructionsController,
                      minLines: 3,
                      maxLines: 6,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Warehouse instructions',
                        hintText:
                            'Picking notes, special handling, route or pallet instructions.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 650;

                        final picked = TextField(
                          controller: _pickedByController,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Picked by',
                            border: OutlineInputBorder(),
                          ),
                        );

                        final checked = TextField(
                          controller: _checkedByController,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Checked by',
                            border: OutlineInputBorder(),
                          ),
                        );

                        if (narrow) {
                          return Column(
                            children: [
                              picked,
                              const SizedBox(height: 14),
                              checked,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: picked),
                            const SizedBox(width: 14),
                            Expanded(child: checked),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _saveWorkOrderDetails(),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save Details'),
                        ),
                        if (status == 'created' || status == 'printed')
                          FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _saveWorkOrderDetails(
                                      status: 'picking',
                                    ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _darkRed,
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Picking'),
                          ),
                        if (status == 'picking')
                          FilledButton.icon(
                            onPressed: !_allLinesFinalised || _isSaving
                                ? null
                                : () => _saveWorkOrderDetails(
                                      status: 'picked',
                                    ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _darkRed,
                            ),
                            icon: const Icon(Icons.task_alt),
                            label: Text(
                              _allLinesFinalised
                                  ? 'Mark Picked'
                                  : 'Finalise All Lines First',
                            ),
                          ),
                        if (status == 'picked')
                          FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _saveWorkOrderDetails(
                                      status: 'completed',
                                    ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _darkRed,
                            ),
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Complete Work Order'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final catchWeight = _isCatchWeight(item);
    final finalised = item['fulfilment_status']?.toString() == 'finalised';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: finalised
              ? const Color(0xFFB8D8BE)
              : const Color(0xFFE0E0E0),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              finalised
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: finalised ? Colors.green : const Color(0xFF777777),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['product_name_snapshot']?.toString() ?? 'Product',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((item['sku_snapshot']?.toString().trim() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${item['sku_snapshot']}',
                      style: const TextStyle(color: Color(0xFF666666)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Ordered: ${_formatNumber(item['quantity'])} '
                    '${_unitLabel(item['quantity_unit']?.toString())}',
                  ),
                  if (item['supplied_quantity'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Supplied: ${_formatNumber(item['supplied_quantity'])} '
                      '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                    ),
                  ],
                  if (catchWeight) ...[
                    const SizedBox(height: 4),
                    Text(
                      item['actual_weight'] == null
                          ? 'Actual weight: pending'
                          : 'Actual weight: ${_formatNumber(item['actual_weight'])} kg',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['final_line_amount'] == null
                          ? 'Final amount: pending weight'
                          : 'Final amount: ${_money(item['final_line_amount'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  if ((item['notes']?.toString().trim() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Notes: ${item['notes']}',
                      style: const TextStyle(color: Color(0xFF666666)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _editLineFulfilment(item),
              icon: const Icon(Icons.scale_outlined),
              label: Text(finalised ? 'Edit' : 'Enter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.label, this.value);

  final String label;
  final String value;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              Text(
                row.label,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(row.value),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
