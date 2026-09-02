import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_invoice_page.dart';

class SupplierWorkOrderPage extends StatefulWidget {
  const SupplierWorkOrderPage({
    super.key,
    required this.orderId,
    this.initialTabIndex = 0,
  });

  final String orderId;
  final int initialTabIndex;

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
  String? _invoiceId;
  late int _workspaceTabIndex;
  final _previewTransformController = TransformationController();
  final _previewViewportKey = GlobalKey();
  double _previewZoom = 1;

  final _instructionsController = TextEditingController();
  final _pickedByController = TextEditingController();
  final _checkedByController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _workspaceTabIndex = widget.initialTabIndex.clamp(0, 2);
    _loadPage();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _pickedByController.dispose();
    _checkedByController.dispose();
    _previewTransformController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      final existingInvoices = await client
          .from('invoices')
          .select('id')
          .eq('order_id', widget.orderId)
          .limit(1);

      if (existingInvoices.isNotEmpty) {
        _invoiceId = existingInvoices.first['id']?.toString();
      }

      final existingWorkOrders = await client
          .from('warehouse_work_orders')
          .select()
          .eq('order_id', widget.orderId)
          .limit(1);

      Map<String, dynamic> workOrder;

      if (existingWorkOrders.isNotEmpty) {
        workOrder = Map<String, dynamic>.from(existingWorkOrders.first);
      } else {
        final workOrderResponse = await client.rpc(
          'create_or_get_warehouse_work_order',
          params: {'target_order_id': widget.orderId},
        );

        workOrder = Map<String, dynamic>.from(workOrderResponse as Map);
      }

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
            fulfilment_method,
            requested_fulfilment_date,
            requested_fulfilment_time,
            confirmed_fulfilment_date,
            confirmed_fulfilment_time,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            delivery_fee,
            order_source,
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
    }

    final businessRaw = _order?['businesses'];

    if (businessRaw is Map) {
      final business = Map<String, dynamic>.from(businessRaw);
      final tradingName = business['trading_name']?.toString().trim();

      if (tradingName != null && tradingName.isNotEmpty) {
        return tradingName;
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
      if ((account['delivery_address_line_1']?.toString().trim() ?? '')
          .isNotEmpty)
        account['delivery_address_line_1'].toString().trim(),
      if ((account['delivery_address_line_2']?.toString().trim() ?? '')
          .isNotEmpty)
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

  String _fulfilmentMethodLabel() {
    return switch (_order?['fulfilment_method']?.toString()) {
      'pickup' => 'Pickup',
      'delivery' => 'Delivery',
      _ => 'Not recorded',
    };
  }

  String _requestedFulfilmentDateLabel() {
    final raw = _order?['requested_fulfilment_date']?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw);

    if (date == null) {
      return 'Not recorded';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _confirmedFulfilmentLabel() {
    final dateRaw = _order?['confirmed_fulfilment_date']?.toString();
    final timeRaw = _order?['confirmed_fulfilment_time']?.toString();

    final date = dateRaw == null ? null : DateTime.tryParse(dateRaw);

    if (date == null) {
      return _requestedFulfilmentDateLabel();
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    String timeLabel = '';
    if (timeRaw != null && timeRaw.isNotEmpty) {
      final parts = timeRaw.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          final hour12 = hour % 12 == 0 ? 12 : hour % 12;
          final period = hour >= 12 ? 'PM' : 'AM';
          timeLabel = ' $hour12:${minute.toString().padLeft(2, '0')} $period';
        }
      }
    }

    return '$day/$month/${date.year}$timeLabel';
  }

  String _orderCreatedDateTimeLabel() {
    final raw = _order?['created_at']?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();

    if (date == null) {
      return 'Not recorded';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} $hour12:$minute $period';
  }

  Future<void> _createInvoiceFromFinishedWorkOrder() async {
    if (!_allLinesFinalised || _isSaving) {
      return;
    }

    final workOrderId = _workOrder?['id']?.toString();

    if (workOrderId == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await Supabase.instance.client
          .from('warehouse_work_orders')
          .update({
            'status': 'picked',
            'picked_at': now,
            'warehouse_instructions': _nullIfEmpty(
              _instructionsController.text,
            ),
            'picked_by': _nullIfEmpty(_pickedByController.text),
            'checked_by': _nullIfEmpty(_checkedByController.text),
          })
          .eq('id', workOrderId);

      final createdInvoice = await Supabase.instance.client.rpc(
        'create_or_get_invoice_from_order',
        params: {'target_order_id': widget.orderId},
      );

      final invoiceMap = Map<String, dynamic>.from(createdInvoice as Map);
      final invoiceId = invoiceMap['id']?.toString();

      if (invoiceId == null || invoiceId.isEmpty) {
        throw Exception('Invoice was created but no invoice ID was returned.');
      }

      await Supabase.instance.client
          .from('warehouse_work_orders')
          .update({'status': 'completed', 'completed_at': now})
          .eq('id', workOrderId);

      if (!mounted) {
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SupplierInvoicePage(invoiceId: invoiceId),
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

  Future<void> _saveWorkOrderDetails({String? status}) async {
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

      if (status == 'picking') {
        await Supabase.instance.client
            .from('orders')
            .update({'status': 'processing', 'updated_at': now})
            .eq('id', widget.orderId)
            .inFilter('status', ['accepted', 'processing']);
      }

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
    final workOrderStatus = _workOrder?['status']?.toString();

    if (itemId == null || itemId.isEmpty) {
      return;
    }

    if (workOrderStatus != 'picking' &&
        workOrderStatus != 'picked' &&
        workOrderStatus != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Start Picking first, then enter the supplied quantity and actual kilograms.',
          ),
        ),
      );
      return;
    }

    final catchWeight = _isCatchWeight(item);
    final orderedQuantity = item['quantity'];
    final quantityUnit = item['quantity_unit']?.toString() ?? 'unit';

    final suppliedController = TextEditingController(
      text:
          item['supplied_quantity']?.toString() ??
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
              final supplied = double.tryParse(suppliedController.text.trim());
              final actualWeight = double.tryParse(
                weightController.text.trim(),
              );

              final wholeQuantityRequired =
                  quantityUnit == 'carton' || quantityUnit == 'unit';

              final suppliedValid =
                  supplied != null &&
                  supplied >= 0 &&
                  (!wholeQuantityRequired ||
                      supplied == supplied.roundToDouble());

              final weightValid =
                  !catchWeight || (actualWeight != null && actualWeight > 0);

              Future<void> save() async {
                if (saving || !suppliedValid || !weightValid) {
                  return;
                }

                setDialogState(() => saving = true);

                try {
                  final updates = <String, dynamic>{
                    'supplied_quantity': supplied,
                    'supplied_quantity_unit': quantityUnit,
                    'fulfilment_status': 'finalised',
                    'finalised_at': DateTime.now().toUtc().toIso8601String(),
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
                    SnackBar(
                      content: Text(
                        catchWeight
                            ? 'Actual weight saved and line finalised.'
                            : 'Supplied quantity saved and line finalised.',
                      ),
                    ),
                  );

                  await _loadPage();
                } on PostgrestException catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                    setDialogState(() => saving = false);
                  }
                }
              }

              final productName =
                  item['product_name_snapshot']?.toString() ?? 'Product';

              return Dialog(
                insetPadding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5EAEA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                catchWeight
                                    ? Icons.scale_outlined
                                    : Icons.inventory_2_outlined,
                                color: _darkRed,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    catchWeight
                                        ? 'Enter Actual Weight'
                                        : 'Confirm Supplied Quantity',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE4E4E0)),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Ordered',
                                style: TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_formatNumber(item['quantity'])} '
                                '${_unitLabel(quantityUnit)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: suppliedController,
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: wholeQuantityRequired
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : null,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Quantity supplied',
                            suffixText: _unitLabel(quantityUnit),
                            helperText: wholeQuantityRequired
                                ? 'Enter whole ${_unitLabel(quantityUnit).toLowerCase()} only.'
                                : null,
                            errorText:
                                suppliedController.text.trim().isEmpty ||
                                    suppliedValid
                                ? null
                                : 'Enter a valid supplied quantity.',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (catchWeight) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: weightController,
                            enabled: !saving,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Actual total kilograms',
                              hintText: 'e.g. 24.65',
                              suffixText: 'kg',
                              errorText:
                                  weightController.text.trim().isEmpty ||
                                      weightValid
                                  ? null
                                  : 'Enter a weight greater than 0 kg.',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 17,
                                  color: Color(0xFF666666),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Enter the total scale weight for the supplied cartons. '
                                    'The invoice amount is calculated from actual kg × the locked \$/kg rate.',
                                    style: TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    saving || !suppliedValid || !weightValid
                                    ? null
                                    : save,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _darkRed,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                                    : const Icon(Icons.check),
                                label: Text(
                                  saving
                                      ? 'Saving...'
                                      : catchWeight
                                      ? 'Save Weight'
                                      : 'Finalise Line',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
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
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
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
                labelValue('Fulfilment', _fulfilmentMethodLabel()),
                labelValue('Requested date', _requestedFulfilmentDateLabel()),
                labelValue('Order placed', _orderCreatedDateTimeLabel()),
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
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(22),
              1: pw.FlexColumnWidth(3.0),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
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
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
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
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfCell(String value, {bool bold = false, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
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
        name: '${_workOrder?['work_order_number'] ?? 'CutLink-Work-Order'}.pdf',
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
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(Icons.assignment_outlined, color: _darkRed, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _workOrder?['work_order_number']?.toString() ??
                    'Warehouse Work Order',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPage,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: _workspaceTabs(),
        ),
      ),
      body: switch (_workspaceTabIndex) {
        0 => _buildBody(),
        1 => _buildPreviewTab(),
        _ => _buildHistoryTab(),
      },
    );
  }

  Widget _workspaceTabs() {
    return Container(
      height: 49,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F1F2))),
      ),
      child: Row(
        children: [
          _workspaceTab(0, Icons.assignment_outlined, 'Working Order'),
          _workspaceTab(1, Icons.picture_as_pdf_outlined, 'Preview'),
          _workspaceTab(2, Icons.history, 'Order History'),
        ],
      ),
    );
  }

  Widget _workspaceTab(int index, IconData icon, String label) {
    final selected = _workspaceTabIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: () => setState(() => _workspaceTabIndex = index),
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : const Color(0xFF5E6369),
          backgroundColor: selected ? _darkRed : const Color(0xFFF4F5F6),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(
              color: selected ? _darkRed : const Color(0xFFE1E3E6),
            ),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildPreviewTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null || _workOrder == null || _order == null) {
      return _buildBody();
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Picking Slip / Work Order',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _zoomControls(),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _downloadPickSlip,
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('Download'),
              ),
              const SizedBox(width: 7),
              FilledButton.icon(
                onPressed: _isSaving ? null : _printPickSlip,
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                icon: const Icon(Icons.print_outlined, size: 17),
                label: const Text('Print'),
              ),
              if (_invoiceId != null) ...[
                const SizedBox(width: 7),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => SupplierInvoicePage(
                        invoiceId: _invoiceId,
                        initialTabIndex: 1,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 17),
                  label: const Text('View Invoice PDF'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight > 24
                  ? constraints.maxHeight - 24
                  : constraints.maxHeight;
              final availableWidth = constraints.maxWidth > 24
                  ? constraints.maxWidth - 24
                  : constraints.maxWidth;
              final fitWidth =
                  availableHeight *
                  PdfPageFormat.a4.width /
                  PdfPageFormat.a4.height;
              final maxWidth = fitWidth < availableWidth
                  ? fitWidth
                  : availableWidth;
              return ClipRect(
                key: _previewViewportKey,
                child: Listener(
                  onPointerSignal: _handlePreviewPointerSignal,
                  child: InteractiveViewer(
                    transformationController: _previewTransformController,
                    minScale: 0.75,
                    maxScale: 4,
                    panEnabled: _previewZoom > 1,
                    child: PdfPreview(
                      build: (_) => _buildPickSlipPdf(),
                      pdfFileName:
                          '${_workOrder?['work_order_number'] ?? 'CutLink-Work-Order'}.pdf',
                      maxPageWidth: maxWidth,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      allowPrinting: false,
                      allowSharing: false,
                      useActions: false,
                      initialPageFormat: PdfPageFormat.a4,
                      dpi: 220,
                      padding: const EdgeInsets.all(12),
                      scrollViewDecoration: const BoxDecoration(
                        color: Color(0xFFE9EBEE),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _zoomControls() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F6),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE0E2E5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _previewZoom <= 0.75
                ? null
                : () => _setPreviewZoom(_previewZoom - 0.25),
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Tooltip(
            message: 'Reset and centre preview',
            child: TextButton.icon(
              onPressed: _resetPreviewZoom,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4F555B),
                minimumSize: const Size(72, 34),
                padding: const EdgeInsets.symmetric(horizontal: 7),
              ),
              icon: const Icon(Icons.center_focus_strong_outlined, size: 15),
              label: Text(
                '${(_previewZoom * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _previewZoom >= 4
                ? null
                : () => _setPreviewZoom(_previewZoom + 0.25),
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _handlePreviewPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _setPreviewZoom(
      _previewZoom + (event.scrollDelta.dy < 0 ? 0.15 : -0.15),
      focalPoint: event.localPosition,
    );
  }

  void _setPreviewZoom(double value, {Offset? focalPoint}) {
    final zoom = value.clamp(0.75, 4.0);
    if (zoom == _previewZoom) return;

    final focal = focalPoint ?? _previewCentre();
    final factor = zoom / _previewZoom;
    final adjustment = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(_previewTransformController.value);
    _previewTransformController.value = adjustment;
    setState(() => _previewZoom = zoom);
  }

  Offset _previewCentre() {
    final renderObject = _previewViewportKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.size.center(Offset.zero);
    }
    return Offset.zero;
  }

  void _resetPreviewZoom() {
    _previewTransformController.value = Matrix4.identity();
    setState(() => _previewZoom = 1);
  }

  Future<void> _downloadPickSlip() async {
    try {
      await Printing.sharePdf(
        bytes: await _buildPickSlipPdf(),
        filename:
            '${_workOrder?['work_order_number'] ?? 'CutLink-Work-Order'}.pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download pick slip: $error')),
        );
      }
    }
  }

  Widget _buildHistoryTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return _buildBody();
    final events = <({String title, dynamic value, IconData icon})>[
      (
        title: 'Order created',
        value: _order?['created_at'],
        icon: Icons.add_circle_outline,
      ),
      (
        title: 'Order accepted',
        value: _order?['accepted_at'],
        icon: Icons.check_circle_outline,
      ),
      (
        title: 'Work order created',
        value: _workOrder?['created_at'],
        icon: Icons.assignment_outlined,
      ),
      (
        title: 'Picking slip printed',
        value: _workOrder?['printed_at'],
        icon: Icons.print_outlined,
      ),
      (
        title: 'Picking started',
        value: _workOrder?['picking_started_at'],
        icon: Icons.play_circle_outline,
      ),
      (
        title: 'Picking completed',
        value: _workOrder?['picked_at'],
        icon: Icons.inventory_2_outlined,
      ),
      (
        title: 'Work order completed',
        value: _workOrder?['completed_at'],
        icon: Icons.task_alt,
      ),
    ].where((event) => event.value != null).toList();

    return _historyPanel(
      title: 'Order History',
      subtitle: 'Recorded milestones for this order and warehouse workflow.',
      events: events,
    );
  }

  Widget _historyPanel({
    required String title,
    required String subtitle,
    required List<({String title, dynamic value, IconData icon})> events,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E5E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF73777D), fontSize: 12),
              ),
              const SizedBox(height: 18),
              if (events.isEmpty)
                const Text('No recorded milestones yet.')
              else
                for (var index = 0; index < events.length; index++)
                  _historyEvent(
                    events[index],
                    last: index == events.length - 1,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyEvent(
    ({String title, dynamic value, IconData icon}) event, {
    required bool last,
  }) {
    final parsed = DateTime.tryParse(event.value.toString())?.toLocal();
    final date = parsed == null
        ? event.value.toString()
        : '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}  ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EAEA),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, size: 16, color: _darkRed),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1, color: const Color(0xFFE0E2E5)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(
                      color: Color(0xFF71767C),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

    final status = _workOrder?['status']?.toString();
    final pickup = _order?['fulfilment_method']?.toString() == 'pickup';

    Widget customerPanel() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE3E5E8)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.business_outlined, color: _darkRed, size: 19),
                SizedBox(width: 8),
                Text(
                  'Customer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 11),
            _compactInfoLine('Business', _customerName()),
            _compactInfoLine('Fulfilment', _fulfilmentMethodLabel()),
            if (!pickup) _compactInfoLine('Address', _deliveryAddress()),
            if ((_order?['customer_reference']?.toString().trim() ?? '')
                .isNotEmpty)
              _compactInfoLine(
                'Reference',
                _order!['customer_reference'].toString(),
              ),
          ],
        ),
      );
    }

    Widget workOrderSummaryPanel() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE3E5E8)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_outlined, color: _darkRed, size: 19),
                SizedBox(width: 8),
                Text(
                  'Work Order Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 11),
            _compactInfoLine(
              'Work Order',
              _workOrder?['work_order_number']?.toString() ?? 'Work Order',
            ),
            _compactInfoLine('Status', _workOrderStatusLabel(status)),
            _compactInfoLine('Requested', _requestedFulfilmentDateLabel()),
            _compactInfoLine('Confirmed', _confirmedFulfilmentLabel()),
            _compactInfoLine('Placed', _orderCreatedDateTimeLabel()),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final pickPanel = _buildPickWorkspace(boundedHeight: desktop);
        final warehousePanel = _buildWarehouseControlPanel(status);

        if (!desktop) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
            children: [
              _buildCompactWorkOrderHeader(status),
              const SizedBox(height: 14),
              customerPanel(),
              const SizedBox(height: 12),
              workOrderSummaryPanel(),
              const SizedBox(height: 12),
              pickPanel,
              const SizedBox(height: 10),
              warehousePanel,
            ],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                children: [
                  _buildCompactWorkOrderHeader(status),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: customerPanel()),
                      const SizedBox(width: 12),
                      Expanded(child: workOrderSummaryPanel()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: pickPanel),
                        const SizedBox(width: 12),
                        SizedBox(width: 350, child: warehousePanel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactWorkOrderHeader(String? status) {
    final pickup = _order?['fulfilment_method']?.toString() == 'pickup';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E5E8)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _workOrder?['work_order_number']?.toString() ??
                            'Work Order',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4E5E5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _workOrderStatusLabel(status),
                        style: const TextStyle(
                          color: _darkRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_customerName()} • ${_order?['order_number'] ?? 'Order'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _headerMetric(
            pickup ? 'PICKUP' : 'DELIVERY',
            pickup ? 'Collection' : _requestedFulfilmentDateLabel(),
            pickup
                ? Icons.shopping_bag_outlined
                : Icons.local_shipping_outlined,
          ),
          _headerMetric(
            'LINES',
            '${_items.where((item) => item['fulfilment_status']?.toString() == 'finalised').length}/${_items.length}',
            Icons.checklist_outlined,
          ),
          if (_order?['pricing_status']?.toString() == 'pending_weight')
            _headerMetric('TOTAL', 'Pending weight', Icons.scale_outlined),
        ],
      ),
    );
  }

  Widget _headerMetric(String label, String value, IconData icon) {
    return SizedBox(
      width: 155,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFE5E5E2))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF666A70)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickWorkspace({required bool boundedHeight}) {
    final list = ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _items.length,
      shrinkWrap: !boundedHeight,
      physics: boundedHeight
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (_, index) => _buildItemCard(_items[index]),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E5E8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: boundedHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 19,
                  color: _darkRed,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pick & Weigh',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${_items.length} line${_items.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (boundedHeight) Expanded(child: list) else list,
        ],
      ),
    );
  }

  Widget _buildWarehouseControlPanel(String? status) {
    final pickup = _order?['fulfilment_method']?.toString() == 'pickup';
    final canEnterWeights =
        status == 'picking' || status == 'picked' || status == 'completed';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E5E8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.warehouse_outlined, size: 19, color: _darkRed),
                SizedBox(width: 8),
                Text(
                  'Warehouse',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 11),
            if (!canEnterWeights)
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFE5C37A)),
                ),
                child: const Text(
                  'Start Picking to unlock supplied quantities and actual kilogram entry.',
                  style: TextStyle(
                    color: Color(0xFF75551A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            if (!canEnterWeights) const SizedBox(height: 10),
            TextField(
              controller: _instructionsController,
              minLines: 2,
              maxLines: 3,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Warehouse instructions',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pickedByController,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Picked by',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: _checkedByController,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Checked by',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _saveWorkOrderDetails(),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Details'),
            ),
            const SizedBox(height: 9),
            if (status == 'created' || status == 'printed')
              FilledButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _saveWorkOrderDetails(status: 'picking'),
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Picking'),
              ),
            if (status == 'picking') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.scale_outlined, size: 18, color: _darkRed),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Click a line in Pick & Weigh to enter the total actual kilograms from the scale.',
                        style: TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: !_allLinesFinalised || _isSaving
                    ? null
                    : _createInvoiceFromFinishedWorkOrder,
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.request_quote_outlined),
                label: Text(
                  !_allLinesFinalised
                      ? 'Finalise All Lines First'
                      : 'Create Invoice',
                ),
              ),
            ],
            if (status == 'picked')
              FilledButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) =>
                                SupplierInvoicePage(orderId: widget.orderId),
                          ),
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Open Invoice'),
              ),
            if ((_order?['delivery_notes']?.toString().trim() ?? '')
                .isNotEmpty) ...[
              const Divider(height: 22),
              const Text(
                'Delivery Notes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                _order!['delivery_notes'].toString(),
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              pickup ? 'Pickup order' : 'Delivery order',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactInfoLine(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final catchWeight = _isCatchWeight(item);
    final finalised = item['fulfilment_status']?.toString() == 'finalised';
    final productName = item['product_name_snapshot']?.toString() ?? 'Product';

    return Material(
      color: finalised ? const Color(0xFFF7FBF7) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap:
            _isSaving ||
                (_workOrder?['status']?.toString() != 'picking' &&
                    _workOrder?['status']?.toString() != 'picked' &&
                    _workOrder?['status']?.toString() != 'completed')
            ? null
            : () => _editLineFulfilment(item),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: finalised
                  ? const Color(0xFFB8D8BE)
                  : const Color(0xFFE2E2DE),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                finalised ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: finalised
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF999999),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((item['sku_snapshot']?.toString().trim() ?? '')
                        .isNotEmpty)
                      Text(
                        'SKU ${item['sku_snapshot']}',
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _lineMetric(
                  'ORDERED',
                  '${_formatNumber(item['quantity'])} '
                      '${_unitLabel(item['quantity_unit']?.toString())}',
                ),
              ),
              Expanded(
                flex: 2,
                child: _lineMetric(
                  'SUPPLIED',
                  item['supplied_quantity'] == null
                      ? 'Pending'
                      : '${_formatNumber(item['supplied_quantity'])} '
                            '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                ),
              ),
              if (catchWeight)
                Expanded(
                  flex: 2,
                  child: _lineMetric(
                    'ACTUAL KG',
                    item['actual_weight'] == null
                        ? 'Pending'
                        : '${_formatNumber(item['actual_weight'])} kg',
                  ),
                ),
              Expanded(
                flex: 2,
                child: _lineMetric(
                  'FINAL',
                  item['final_line_amount'] == null
                      ? (catchWeight ? 'Pending' : '—')
                      : _money(item['final_line_amount']),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                finalised
                    ? Icons.edit_outlined
                    : (_workOrder?['status']?.toString() == 'picking'
                          ? Icons.scale_outlined
                          : Icons.lock_outline),
                size: 19,
                color: _darkRed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
