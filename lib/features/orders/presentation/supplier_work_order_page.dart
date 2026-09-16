import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_invoice_page.dart';
import 'supplier_sales_page.dart';
import '../../../shared/widgets/zoomable_pdf_preview.dart';

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
  List<Map<String, dynamic>> _deliveryDrivers = [];
  String? _selectedDeliveryDriverId;
  String? _invoiceId;
  late int _workspaceTabIndex;

  String? _selectedLineId;
  String? _lineAction;
  String? _selectedDiscountType;
  Map<String, String> _privateComments = {};
  final _lineEditorController = TextEditingController();

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
    _lineEditorController.dispose();
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
            supplier_business_id,
            assigned_delivery_driver_id,
            status,
            customer_reference,
            customer_contact_name_snapshot,
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
              abn,
              contact_name,
              email,
              phone,
              account_reference,
              delivery_address_line_1,
              delivery_address_line_2,
              delivery_suburb,
              delivery_state,
              delivery_postcode
            ),
            businesses!orders_butcher_business_id_fkey(
              legal_name,
              trading_name,
              abn,
              business_email,
              business_phone,
              address_line_1,
              address_line_2,
              suburb,
              state,
              postcode
            ),
            order_items(
              id,
              product_id,
              product_name_snapshot,
              sku_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              line_subtotal,
              notes,
              supplied_quantity,
              supplied_quantity_unit,
              actual_weight,
              actual_weight_unit,
              final_line_amount,
              fulfilment_status,
              catch_weight_snapshot,
              discount_type,
              discount_value,
              discount_amount,
              public_comment,
              invoice_excluded
            )
          ''')
          .eq('id', widget.orderId)
          .single();

      if (!mounted) {
        return;
      }

      final order = Map<String, dynamic>.from(orderResponse);

      final rawItemsForGrades = order['order_items'];
      if (rawItemsForGrades is List) {
        final productIds = rawItemsForGrades
            .whereType<Map>()
            .map((item) => item['product_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        if (productIds.isNotEmpty) {
          final productRows = await client
              .from('products')
              .select('id, meat_grades(code, name)')
              .inFilter('id', productIds);
          final gradeByProductId = <String, Map<String, dynamic>>{};
          for (final rawProduct in productRows) {
            final product = Map<String, dynamic>.from(rawProduct);
            final id = product['id']?.toString();
            final rawGrade = product['meat_grades'];
            if (id != null && rawGrade is Map) {
              gradeByProductId[id] = Map<String, dynamic>.from(rawGrade);
            }
          }
          for (final rawItem in rawItemsForGrades.whereType<Map>()) {
            final grade = gradeByProductId[rawItem['product_id']?.toString()];
            rawItem['grade_code'] = grade?['code'];
            rawItem['grade_name'] = grade?['name'];
          }
        }
      }

      final privateComments = <String, String>{};
      final workOrderId = workOrder['id']?.toString();
      final rawOrderItems = order['order_items'];
      final lineIds = rawOrderItems is List
          ? rawOrderItems
                .whereType<Map>()
                .where((item) => item['invoice_excluded'] != true)
                .map((item) => item['id']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toList()
          : <String>[];

      if (workOrderId != null && workOrderId.isNotEmpty && lineIds.isNotEmpty) {
        final privateRows = await client
            .from('supplier_document_line_private_notes')
            .select('line_id, private_comment')
            .eq('document_kind', 'work_order')
            .eq('document_id', workOrderId)
            .inFilter('line_id', lineIds);

        for (final rawNote in privateRows) {
          final lineId = rawNote['line_id']?.toString();
          final comment = rawNote['private_comment']?.toString().trim() ?? '';
          if (lineId != null && lineId.isNotEmpty && comment.isNotEmpty) {
            privateComments[lineId] = comment;
          }
        }
      }

      var deliveryDrivers = <Map<String, dynamic>>[];
      final supplierBusinessId = order['supplier_business_id']?.toString();

      if (order['fulfilment_method']?.toString() == 'delivery' &&
          supplierBusinessId != null &&
          supplierBusinessId.isNotEmpty) {
        final driverResponse = await client
            .from('supplier_delivery_drivers')
            .select('id, display_name, phone, active')
            .eq('supplier_business_id', supplierBusinessId)
            .eq('active', true)
            .order('display_name');

        deliveryDrivers = List<Map<String, dynamic>>.from(
          driverResponse as List,
        );
      }

      _instructionsController.text =
          workOrder['warehouse_instructions']?.toString() ?? '';
      _pickedByController.text = workOrder['picked_by']?.toString() ?? '';
      _checkedByController.text = workOrder['checked_by']?.toString() ?? '';

      setState(() {
        _workOrder = workOrder;
        _order = order;
        _deliveryDrivers = deliveryDrivers;
        _selectedDeliveryDriverId = order['assigned_delivery_driver_id']
            ?.toString();
        _privateComments = privateComments;
        if (_selectedLineId != null && !lineIds.contains(_selectedLineId)) {
          _selectedLineId = null;
          _lineAction = null;
        }
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

  Future<void> _reopenForCuts() async {
    if (_invoiceId != null || _isSaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add more cuts?'),
        content: const Text(
          'This opens the same order in Sales with its existing details and products. New products will be added to this work order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reopen Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SupplierSalesPage(initialWorkOrderOrderId: widget.orderId),
      ),
    );
    if (changed == true && mounted) {
      await _loadPage();
    }
  }

  Future<void> _editContactName() async {
    if (_invoiceId != null || _isSaving) return;

    final controller = TextEditingController(
      text: _customerDetail('contact_name'),
    );
    final value = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Contact Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Contact name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (text) => Navigator.pop(dialogContext, text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (value == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.rpc(
        'update_supplier_order_contact_name',
        params: {
          'target_order_id': widget.orderId,
          'contact_name_value': value,
        },
      );
      await _loadPage();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact name updated.')));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Map<String, dynamic>> get _items {
    final raw = _order?['order_items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .where((item) => item['invoice_excluded'] != true)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _lineTitle(Map<String, dynamic> item) {
    final product = item['product_name_snapshot']?.toString().trim();
    final code = item['grade_code']?.toString().trim() ?? '';
    final name = item['grade_name']?.toString().trim() ?? '';
    final grade = [
      if (code.isNotEmpty) code,
      if (name.isNotEmpty && name != code) name,
    ].join(' - ');
    final base = product == null || product.isEmpty ? 'Product' : product;
    return grade.isEmpty ? base : '$base - $grade';
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

  Map<String, dynamic> _customerAccount() {
    final accountRaw = _order?['supplier_customer_accounts'];
    final businessRaw = _order?['businesses'];
    final account = accountRaw is Map
        ? Map<String, dynamic>.from(accountRaw)
        : <String, dynamic>{};
    final business = businessRaw is Map
        ? Map<String, dynamic>.from(businessRaw)
        : <String, dynamic>{};

    String? firstNonEmpty(List<dynamic> values) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    return {
      'customer_name': firstNonEmpty([
        account['customer_name'],
        business['trading_name'],
        business['legal_name'],
      ]),
      'legal_name': firstNonEmpty([
        account['legal_name'],
        business['legal_name'],
      ]),
      'abn': firstNonEmpty([account['abn'], business['abn']]),
      'contact_name': firstNonEmpty([
        _order?['customer_contact_name_snapshot'],
        account['contact_name'],
      ]),
      'email': firstNonEmpty([account['email'], business['business_email']]),
      'phone': firstNonEmpty([account['phone'], business['business_phone']]),
      'delivery_address_line_1': firstNonEmpty([
        account['delivery_address_line_1'],
        business['address_line_1'],
      ]),
      'delivery_address_line_2': firstNonEmpty([
        account['delivery_address_line_2'],
        business['address_line_2'],
      ]),
      'delivery_suburb': firstNonEmpty([
        account['delivery_suburb'],
        business['suburb'],
      ]),
      'delivery_state': firstNonEmpty([
        account['delivery_state'],
        business['state'],
      ]),
      'delivery_postcode': firstNonEmpty([
        account['delivery_postcode'],
        business['postcode'],
      ]),
    };
  }

  String _customerDetail(String key) {
    final value = _customerAccount()[key]?.toString().trim() ?? '';
    return value;
  }

  String _deliveryAddress() {
    final account = _customerAccount();
    final parts = <String>[
      account['delivery_address_line_1']?.toString().trim() ?? '',
      account['delivery_address_line_2']?.toString().trim() ?? '',
      account['delivery_suburb']?.toString().trim() ?? '',
      account['delivery_state']?.toString().trim() ?? '',
      account['delivery_postcode']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    return parts.isEmpty ? 'Not recorded' : parts.join(', ');
  }

  bool _isCatchWeight(Map<String, dynamic> item) {
    return item['catch_weight_snapshot'] == true &&
        item['price_basis']?.toString() == 'kilogram';
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  String _assignedDriverName() {
    for (final driver in _deliveryDrivers) {
      if (driver['id']?.toString() == _selectedDeliveryDriverId) {
        final name = driver['display_name']?.toString().trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    }
    return 'Not assigned';
  }

  Future<void> _assignDeliveryDriver(String? driverId) async {
    if (_isSaving || driverId == null || driverId.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.rpc(
        'assign_order_delivery_driver',
        params: {'target_order_id': widget.orderId, 'p_driver_id': driverId},
      );

      if (!mounted) return;

      setState(() {
        _selectedDeliveryDriverId = driverId;
        if (_order != null) {
          _order!['assigned_delivery_driver_id'] = driverId;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery driver assigned.')),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _killWorkOrder() async {
    if (_isSaving || _invoiceId != null) return;

    final marketplace = _order?['order_source']?.toString() == 'marketplace';
    final reasonController = TextEditingController();
    var reasonMissing = false;

    final reason = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kill Order?'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  marketplace
                      ? 'This marketplace order will be cancelled and the butcher will be notified. Reserved stock will be restored.'
                      : 'This removes the warehouse work order, cancels the underlying order and restores any stock reserved for it. This cannot be undone.',
                ),
                if (marketplace) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Cancellation reason',
                      hintText:
                          'Tell the butcher why this order cannot be fulfilled.',
                      errorText: reasonMissing
                          ? 'A cancellation reason is required.'
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep Order'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade800,
              ),
              onPressed: () {
                final value = reasonController.text.trim();
                if (marketplace && value.isEmpty) {
                  setDialogState(() => reasonMissing = true);
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Kill Order'),
            ),
          ],
        ),
      ),
    );

    reasonController.dispose();
    if (reason == null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.rpc(
        'kill_supplier_work_order',
        params: {
          'target_order_id': widget.orderId,
          'p_reason': reason.trim().isEmpty ? null : reason.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double _lineGrossAmount(Map<String, dynamic> item) {
    final raw = item['final_line_amount'] ?? item['line_subtotal'];
    final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (parsed != null) return parsed;

    final quantityRaw = item['quantity'];
    final priceRaw = item['unit_price'];
    final quantity = quantityRaw is num
        ? quantityRaw.toDouble()
        : double.tryParse('$quantityRaw') ?? 0;
    final price = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse('$priceRaw') ?? 0;
    return quantity * price;
  }

  double _lineDiscountAmount(Map<String, dynamic> item) {
    final gross = _lineGrossAmount(item);
    final type = item['discount_type']?.toString();
    final rawValue = item['discount_value'];
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse('$rawValue') ?? 0;

    if (type == 'percent') {
      return (gross * value.clamp(0, 100) / 100).clamp(0, gross);
    }
    if (type == 'fixed') {
      return value.clamp(0, gross);
    }
    return 0;
  }

  double _lineNetAmount(Map<String, dynamic> item) =>
      (_lineGrossAmount(item) - _lineDiscountAmount(item)).clamp(
        0,
        double.infinity,
      );

  double get _finalInvoiceAmount {
    var productsTotal = 0.0;
    for (final item in _items) {
      productsTotal += _lineNetAmount(item);
    }

    final deliveryRaw = _order?['delivery_fee'];
    final deliveryFee = deliveryRaw is num
        ? deliveryRaw.toDouble()
        : double.tryParse('$deliveryRaw') ?? 0;

    return productsTotal + deliveryFee;
  }

  Map<String, dynamic>? get _selectedLine {
    final id = _selectedLineId;
    if (id == null) return null;
    for (final item in _items) {
      if (item['id']?.toString() == id) return item;
    }
    return null;
  }

  double get _currentDeliveryFee {
    final raw = _order?['delivery_fee'];
    return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
  }

  void _selectLine(Map<String, dynamic> item) {
    if (_isSaving) return;
    setState(() {
      _selectedLineId = item['id']?.toString();
      _lineAction = null;
      _lineEditorController.clear();
    });
  }

  void _openLineAction(String action) {
    final item = _selectedLine;
    if (item == null) return;

    if (action == 'pick') {
      _editLineFulfilment(item);
      return;
    }
    if (action == 'remove') {
      _removeSelectedWorkOrderLine();
      return;
    }

    if (_lineAction == action) {
      setState(() {
        _lineAction = null;
        _selectedDiscountType = null;
        _lineEditorController.clear();
      });
      return;
    }

    setState(() {
      _lineAction = action;
      if (action == 'discount') {
        final type = item['discount_type']?.toString();
        _selectedDiscountType = type == 'percent' || type == 'fixed'
            ? type
            : null;
        final raw = item['discount_value'];
        final value = raw is num
            ? raw.toDouble()
            : double.tryParse('$raw') ?? 0;
        _lineEditorController.text = _selectedDiscountType == null
            ? ''
            : value.toStringAsFixed(2);
      } else if (action == 'delivery') {
        _lineEditorController.text = _currentDeliveryFee.toStringAsFixed(2);
      } else if (action == 'private') {
        _lineEditorController.text =
            _privateComments[item['id']?.toString() ?? ''] ?? '';
      } else if (action == 'public') {
        _lineEditorController.text = item['public_comment']?.toString() ?? '';
      }
    });
  }

  Future<void> _saveSelectedLineAction() async {
    final item = _selectedLine;
    if (item == null || _lineAction == null || _isSaving) return;

    var discountType = item['discount_type']?.toString();
    if (discountType != 'percent' && discountType != 'fixed') {
      discountType = null;
    }
    double? discountValue;
    if (discountType != null) {
      final raw = item['discount_value'];
      discountValue = raw is num
          ? raw.toDouble()
          : double.tryParse('$raw') ?? 0;
    }

    var publicComment = item['public_comment']?.toString() ?? '';
    var privateComment = _privateComments[item['id']?.toString() ?? ''] ?? '';
    var deliveryFee = _currentDeliveryFee;

    if (_lineAction == 'discount') {
      discountType = _selectedDiscountType;
      discountValue = discountType == null
          ? null
          : double.tryParse(_lineEditorController.text.trim());

      if (discountType != null && discountValue == null) {
        _message('Enter a valid discount.');
        return;
      }
      if (discountType == 'percent' &&
          (discountValue! < 0 || discountValue > 100)) {
        _message('Percentage discount must be between 0 and 100%.');
        return;
      }
      if (discountValue != null && discountValue < 0) {
        _message('Discount cannot be negative.');
        return;
      }
    } else if (_lineAction == 'delivery') {
      final parsed = double.tryParse(_lineEditorController.text.trim());
      if (parsed == null || parsed < 0) {
        _message('Enter a valid delivery charge.');
        return;
      }
      deliveryFee = parsed;
    } else if (_lineAction == 'private') {
      privateComment = _lineEditorController.text.trim();
    } else if (_lineAction == 'public') {
      publicComment = _lineEditorController.text.trim();
    }

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.rpc(
        'update_supplier_work_order_line',
        params: {
          'p_order_item_id': item['id'],
          'p_discount_type': discountType,
          'p_discount_value': discountValue,
          'p_public_comment': publicComment,
          'p_private_comment': privateComment,
          'p_delivery_fee': deliveryFee,
          'p_remove': false,
        },
      );
      if (!mounted) return;
      setState(() => _lineAction = null);
      await _loadPage();
    } on PostgrestException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeSelectedWorkOrderLine() async {
    final item = _selectedLine;
    if (item == null || _isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this item?'),
        content: Text(
          '${item['product_name_snapshot'] ?? 'This item'} will be removed from '
          'the Work Order and the reserved stock will be restored. It will not '
          'appear on the invoice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove Item'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.rpc(
        'update_supplier_work_order_line',
        params: {
          'p_order_item_id': item['id'],
          'p_discount_type': item['discount_type'],
          'p_discount_value': item['discount_value'],
          'p_public_comment': item['public_comment'],
          'p_private_comment':
              _privateComments[item['id']?.toString() ?? ''] ?? '',
          'p_delivery_fee': _currentDeliveryFee,
          'p_remove': true,
        },
      );
      if (!mounted) return;
      setState(() {
        _selectedLineId = null;
        _lineAction = null;
      });
      await _loadPage();
      if (mounted) _message('Item removed and reserved stock restored.');
    } on PostgrestException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmCreditLimitBeforeInvoiceCreation() async {
    if (_order?['payment_method_snapshot']?.toString() != 'account') {
      return true;
    }

    final accountId = _order?['supplier_customer_account_id']?.toString();
    if (accountId == null || accountId.isEmpty) {
      return true;
    }

    final raw = await Supabase.instance.client.rpc(
      'check_supplier_customer_credit_limit',
      params: {
        'target_supplier_customer_account_id': accountId,
        'proposed_amount': _finalInvoiceAmount,
      },
    );

    final rows = raw is List ? raw : const [];
    if (rows.isEmpty || rows.first is! Map) return true;

    final check = Map<String, dynamic>.from(rows.first as Map);
    if (check['over_limit'] != true) return true;
    if (!mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Credit Limit Warning'),
        content: Text(
          'Credit limit: ${_money(check['credit_limit'])}\n'
          'Current exposure: ${_money(check['current_credit_exposure'])}\n'
          'This invoice: ${_money(_finalInvoiceAmount)}\n'
          'Projected exposure: ${_money(check['projected_credit_exposure'])}\n'
          'Over limit by: ${_money(check['over_limit_by'])}\n\n'
          'Creating this invoice will make it official immediately. Continue anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Create Anyway'),
          ),
        ],
      ),
    );

    return proceed == true;
  }

  Future<void> _startPickingAndOpenPreview() async {
    await _saveWorkOrderDetails(status: 'picking');
    if (!mounted || _workOrder?['status']?.toString() != 'picking') return;
    setState(() => _workspaceTabIndex = 1);
  }

  Future<void> _createInvoiceFromFinishedWorkOrder() async {
    if (!_allLinesFinalised || _isSaving) {
      return;
    }

    final creditApproved = await _confirmCreditLimitBeforeInvoiceCreation();
    if (!creditApproved || !mounted) return;

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

              final productName = _lineTitle(item);

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
                          const SizedBox(height: 6),
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
                if (_customerDetail('legal_name').isNotEmpty)
                  labelValue('Legal name', _customerDetail('legal_name')),
                if (_customerDetail('abn').isNotEmpty)
                  labelValue('ABN', _customerDetail('abn')),
                if (_customerDetail('contact_name').isNotEmpty)
                  labelValue('Contact', _customerDetail('contact_name')),
                if (_customerDetail('phone').isNotEmpty)
                  labelValue('Phone', _customerDetail('phone')),
                if (_customerDetail('email').isNotEmpty)
                  labelValue('Email', _customerDetail('email')),
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
                        _lineTitle(item),
                        if ((item['sku_snapshot']?.toString().trim() ?? '')
                            .isNotEmpty)
                          'SKU: ${item['sku_snapshot']}',
                        if ((item['notes']?.toString().trim() ?? '').isNotEmpty)
                          'Notes: ${item['notes']}',
                        if ((item['public_comment']?.toString().trim() ?? '')
                            .isNotEmpty)
                          'Public comment: ${item['public_comment']}',
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
          if (_invoiceId == null &&
              _workOrder?['status']?.toString() != 'completed')
            OutlinedButton.icon(
              onPressed: _isLoading || _isSaving ? null : _killWorkOrder,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade800,
                side: BorderSide(color: Colors.red.shade200),
              ),
              icon: const Icon(Icons.delete_forever_outlined, size: 17),
              label: const Text('Kill Order'),
            ),
          if (_invoiceId == null &&
              _workOrder?['status']?.toString() != 'completed')
            const SizedBox(width: 7),
          if (_invoiceId == null)
            TextButton.icon(
              onPressed: _isLoading || _isSaving ? null : _reopenForCuts,
              icon: const Icon(Icons.add_box_outlined, size: 17),
              label: const Text('Add Cuts'),
            ),
          if (_invoiceId == null) const SizedBox(width: 7),
          OutlinedButton.icon(
            onPressed: _isLoading || _isSaving ? null : _downloadPickSlip,
            icon: const Icon(Icons.download_outlined, size: 17),
            label: const Text('Download'),
          ),
          const SizedBox(width: 7),
          FilledButton.icon(
            onPressed: _isLoading || _isSaving ? null : _printPickSlip,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.print_outlined, size: 17),
            label: const Text('Print'),
          ),
          const SizedBox(width: 7),
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
    final workOrderNumber =
        _workOrder?['work_order_number']?.toString() ?? 'CutLink-Work-Order';

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Work Order PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              const Text(
                'Scroll wheel to zoom',
                style: TextStyle(
                  color: Color(0xFF6D7177),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _downloadPickSlip,
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('Download'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ZoomablePdfPreview(
            documentKey: 'work-order-${widget.orderId}-$workOrderNumber',
            buildPdf: _buildPickSlipPdf,
            dpi: 420,
          ),
        ),
      ],
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
        child: LayoutBuilder(
          builder: (context, panelConstraints) {
            final twoColumns = panelConstraints.maxWidth >= 540;
            final gap = twoColumns ? 12.0 : 0.0;
            final columnWidth = twoColumns
                ? (panelConstraints.maxWidth - gap) / 2
                : panelConstraints.maxWidth;

            Widget cell(String label, String value, {bool fullWidth = false}) {
              return SizedBox(
                width: fullWidth ? panelConstraints.maxWidth : columnWidth,
                child: _compactInfoLine(label, value),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.business_outlined,
                      color: _darkRed,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Customer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (_invoiceId == null)
                      IconButton(
                        tooltip: 'Edit contact name',
                        visualDensity: VisualDensity.compact,
                        onPressed: _isSaving ? null : _editContactName,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: gap,
                  runSpacing: 2,
                  children: [
                    cell('Business', _customerName()),
                    if (_customerDetail('contact_name').isNotEmpty)
                      cell('Contact', _customerDetail('contact_name')),
                    if (_customerDetail('phone').isNotEmpty)
                      cell('Phone', _customerDetail('phone')),
                    if (_customerDetail('email').isNotEmpty)
                      cell('Email', _customerDetail('email')),
                    cell('Fulfilment', _fulfilmentMethodLabel()),
                    if (!pickup) cell('Driver', _assignedDriverName()),
                    if ((_order?['customer_reference']?.toString().trim() ?? '')
                        .isNotEmpty)
                      cell(
                        'Reference',
                        _order!['customer_reference'].toString(),
                      ),
                    if (!pickup)
                      cell('Address', _deliveryAddress(), fullWidth: true),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    Widget workOrderSummaryPanel() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
        child: LayoutBuilder(
          builder: (context, panelConstraints) {
            final twoColumns = panelConstraints.maxWidth >= 500;
            final gap = twoColumns ? 12.0 : 0.0;
            final columnWidth = twoColumns
                ? (panelConstraints.maxWidth - gap) / 2
                : panelConstraints.maxWidth;

            Widget cell(String label, String value, {bool fullWidth = false}) {
              return SizedBox(
                width: fullWidth ? panelConstraints.maxWidth : columnWidth,
                child: _compactInfoLine(label, value),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: _darkRed, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Work Order Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: gap,
                  runSpacing: 2,
                  children: [
                    cell(
                      'Work Order',
                      _workOrder?['work_order_number']?.toString() ??
                          'Work Order',
                    ),
                    cell('Status', _workOrderStatusLabel(status)),
                    cell('Requested', _requestedFulfilmentDateLabel()),
                    cell('Confirmed', _confirmedFulfilmentLabel()),
                    cell(
                      'Placed',
                      _orderCreatedDateTimeLabel(),
                      fullWidth: true,
                    ),
                  ],
                ),
              ],
            );
          },
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
            children: [
              _buildCompactWorkOrderHeader(status),
              const SizedBox(height: 8),
              customerPanel(),
              const SizedBox(height: 8),
              workOrderSummaryPanel(),
              const SizedBox(height: 8),
              pickPanel,
              const SizedBox(height: 6),
              warehousePanel,
            ],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _buildCompactWorkOrderHeader(status),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: customerPanel()),
                      const SizedBox(width: 12),
                      Expanded(child: workOrderSummaryPanel()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: pickPanel),
                        const SizedBox(width: 12),
                        SizedBox(width: 300, child: warehousePanel),
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
          _headerMetric(
            _allLinesFinalised ? 'FINAL TOTAL' : 'RUNNING TOTAL',
            _money(_finalInvoiceAmount),
            Icons.payments_outlined,
          ),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      itemCount: _items.length,
      shrinkWrap: !boundedHeight,
      physics: boundedHeight
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 5),
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFE5E7EA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, size: 18, color: _darkRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _allLinesFinalised
                        ? 'Final invoice total before invoice creation'
                        : 'Running total - updates as actual weights are finalised',
                    style: const TextStyle(
                      color: Color(0xFF60646A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _money(_finalInvoiceAmount),
                  style: const TextStyle(
                    color: _darkRed,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (boundedHeight) Expanded(child: list) else list,
          if (_selectedLine != null) ...[
            const Divider(height: 1),
            _buildWorkOrderLineDock(),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkOrderLineDock() {
    final item = _selectedLine;
    if (item == null) return const SizedBox.shrink();

    Widget actionButton({
      required String label,
      required IconData icon,
      required String action,
      bool danger = false,
    }) {
      final active = _lineAction == action;
      return TextButton.icon(
        onPressed: _isSaving ? null : () => _openLineAction(action),
        style: TextButton.styleFrom(
          foregroundColor: danger
              ? Colors.red.shade700
              : active
              ? Colors.white
              : _darkRed,
          backgroundColor: active ? _darkRed : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      );
    }

    return Container(
      color: const Color(0xFFFAFAF8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 17, color: _darkRed),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item['product_name_snapshot']?.toString() ?? 'Selected item',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() {
                        _selectedLineId = null;
                        _lineAction = null;
                      }),
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              actionButton(
                label: _isCatchWeight(item) ? 'Weight' : 'Pick Qty',
                icon: Icons.scale_outlined,
                action: 'pick',
              ),
              actionButton(
                label: 'Discount',
                icon: Icons.percent,
                action: 'discount',
              ),
              actionButton(
                label: 'Delivery',
                icon: Icons.local_shipping_outlined,
                action: 'delivery',
              ),
              actionButton(
                label: 'Private Comment',
                icon: Icons.lock_outline,
                action: 'private',
              ),
              actionButton(
                label: 'Public Comment',
                icon: Icons.chat_bubble_outline,
                action: 'public',
              ),
              actionButton(
                label: 'Remove Item',
                icon: Icons.delete_outline,
                action: 'remove',
                danger: true,
              ),
            ],
          ),
          if (_lineAction != null &&
              _lineAction != 'pick' &&
              _lineAction != 'remove') ...[
            const SizedBox(height: 7),
            _buildWorkOrderLineInlineEditor(item),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkOrderLineInlineEditor(Map<String, dynamic> item) {
    final action = _lineAction;
    if (action == null) return const SizedBox.shrink();

    Widget saveButton() => FilledButton.icon(
      onPressed: _isSaving ? null : _saveSelectedLineAction,
      style: FilledButton.styleFrom(
        backgroundColor: _darkRed,
        visualDensity: VisualDensity.compact,
      ),
      icon: _isSaving
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined, size: 16),
      label: const Text('Save'),
    );

    if (action == 'discount') {
      Widget typeField() => DropdownButtonFormField<String?>(
        initialValue: _selectedDiscountType,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Discount',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('No discount')),
          DropdownMenuItem<String?>(
            value: 'percent',
            child: Text('Percentage (%)'),
          ),
          DropdownMenuItem<String?>(
            value: 'fixed',
            child: Text(r'Fixed amount ($)'),
          ),
        ],
        onChanged: _isSaving
            ? null
            : (value) => setState(() {
                _selectedDiscountType = value;
                if (value == null) _lineEditorController.clear();
              }),
      );

      Widget amountField() => TextField(
        controller: _lineEditorController,
        enabled: !_isSaving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: _selectedDiscountType == 'percent'
              ? 'Percentage'
              : 'Amount',
          suffixText: _selectedDiscountType == 'percent' ? '%' : null,
          prefixText: _selectedDiscountType == 'fixed' ? r'$' : null,
        ),
      );

      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                typeField(),
                if (_selectedDiscountType != null) ...[
                  const SizedBox(height: 8),
                  amountField(),
                ],
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: saveButton()),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 190, child: typeField()),
              if (_selectedDiscountType != null) ...[
                const SizedBox(width: 8),
                Expanded(child: amountField()),
              ] else
                const Spacer(),
              const SizedBox(width: 8),
              saveButton(),
            ],
          );
        },
      );
    }

    if (action == 'delivery') {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _lineEditorController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Delivery charge for this order',
                prefixText: r'$',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          saveButton(),
        ],
      );
    }

    final isPrivate = action == 'private';
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _lineEditorController,
            enabled: !_isSaving,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isPrivate
                  ? 'Private supplier comment'
                  : 'Public comment',
              helperText: isPrivate
                  ? 'Supplier only. Never prints or shows to the customer.'
                  : 'Flows through to the invoice and customer PDF.',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        saveButton(),
      ],
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
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
            const SizedBox(height: 7),
            if (!pickup) ...[
              DropdownButtonFormField<String>(
                initialValue:
                    _deliveryDrivers.any(
                      (driver) =>
                          driver['id']?.toString() == _selectedDeliveryDriverId,
                    )
                    ? _selectedDeliveryDriverId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Delivery driver',
                  helperText: 'Assign the driver responsible for this job.',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final driver in _deliveryDrivers)
                    DropdownMenuItem<String>(
                      value: driver['id']?.toString(),
                      child: Text(
                        driver['display_name']?.toString() ?? 'Driver',
                      ),
                    ),
                ],
                onChanged: _isSaving || _deliveryDrivers.isEmpty
                    ? null
                    : _assignDeliveryDriver,
              ),
              if (_deliveryDrivers.isEmpty) ...[
                const SizedBox(height: 7),
                const Text(
                  'No active drivers. Add one in Delivery → Drivers & Vehicles.',
                  style: TextStyle(
                    color: Color(0xFF9A6700),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 11),
            ],
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
              minLines: 1,
              maxLines: 2,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Warehouse instructions',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
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
            const SizedBox(height: 6),
            if (status == 'created' || status == 'printed')
              FilledButton.icon(
                onPressed: _isSaving ? null : _startPickingAndOpenPreview,
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Picking'),
              ),
            if (status == 'picking') ...[
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
      padding: const EdgeInsets.only(bottom: 4),
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
    final productName = _lineTitle(item);
    final publicComment = item['public_comment']?.toString().trim() ?? '';

    final selected = item['id']?.toString() == _selectedLineId;

    return Material(
      color: selected
          ? const Color(0xFFF7EDED)
          : finalised
          ? const Color(0xFFF7FBF7)
          : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _isSaving ? null : () => _selectLine(item),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? _darkRed
                  : finalised
                  ? const Color(0xFFB8D8BE)
                  : const Color(0xFFE2E2DE),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    finalised
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
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
                          : _money(_lineNetAmount(item)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_lineDiscountAmount(item) > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '-${_money(_lineDiscountAmount(item))}',
                        style: const TextStyle(
                          color: _darkRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Icon(
                    selected ? Icons.check_circle : Icons.more_horiz,
                    size: 19,
                    color: _darkRed,
                  ),
                ],
              ),
              if (publicComment.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F3F3),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: _darkRed,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          publicComment,
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
