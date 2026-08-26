import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_work_order_page.dart';

class SupplierMarketplaceOrderDetailPage extends StatefulWidget {
  const SupplierMarketplaceOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<SupplierMarketplaceOrderDetailPage> createState() =>
      _SupplierMarketplaceOrderDetailPageState();
}

class _SupplierMarketplaceOrderDetailPageState
    extends State<SupplierMarketplaceOrderDetailPage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final row = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            order_number,
            status,
            order_source,
            butcher_business_id,
            customer_reference,
            delivery_notes,
            fulfilment_method,
            requested_fulfilment_date,
            requested_fulfilment_time,
            confirmed_fulfilment_date,
            confirmed_fulfilment_time,
            fulfilment_schedule_confirmed_at,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            delivery_fee,
            submitted_at,
            businesses!orders_butcher_business_id_fkey(
              id,
              trading_name,
              legal_name,
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
              product_name_snapshot,
              sku_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              catch_weight_snapshot,
              notes
            )
          ''')
          .eq('id', widget.orderId)
          .eq('order_source', 'marketplace')
          .single();

      if (!mounted) return;

      setState(() {
        _order = Map<String, dynamic>.from(row);
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  List<Map<String, dynamic>> _items() {
    final raw = _order?['order_items'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _customerName() {
    final business = _map(_order?['businesses']);
    final trading = business?['trading_name']?.toString().trim();
    final legal = business?['legal_name']?.toString().trim();
    if (trading != null && trading.isNotEmpty) return trading;
    if (legal != null && legal.isNotEmpty) return legal;
    return 'CutLink Butcher';
  }

  String _address() {
    final business = _map(_order?['businesses']);
    if (business == null) return 'Not provided';
    final parts = <String>[
      business['address_line_1']?.toString() ?? '',
      business['address_line_2']?.toString() ?? '',
      business['suburb']?.toString() ?? '',
      business['state']?.toString() ?? '',
      business['postcode']?.toString() ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  String _date(dynamic raw) {
    if (raw == null) return 'Not specified';
    final date = DateTime.tryParse(raw.toString())?.toLocal();
    if (date == null) return raw.toString();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _quantity(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return value?.toString() ?? '0';
    if (number == number.roundToDouble()) return number.toInt().toString();
    return number
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return 'Not set';
    return '\$${number.toStringAsFixed(2)}';
  }

  String _unit(String? value) {
    return switch (value) {
      'carton' => 'cartons',
      'kilogram' => 'kg',
      'unit' => 'units',
      _ => value ?? '',
    };
  }

  String _fulfilmentLabel() {
    return _order?['fulfilment_method']?.toString() == 'pickup'
        ? 'Pickup'
        : 'Delivery';
  }

  DateTime? _parseRequestedDate() {
    final raw = _order?['requested_fulfilment_date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  TimeOfDay? _parseRequestedTime() {
    final raw = _order?['requested_fulfilment_time']?.toString();
    if (raw == null || raw.isEmpty) return null;

    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _dateDbValue(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _timeDbValue(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  String _dateDisplay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _accept() async {
    if (_saving || _order?['status']?.toString() != 'submitted') return;

    DateTime? confirmedDate = _parseRequestedDate();
    TimeOfDay? confirmedTime = _parseRequestedTime();

    final schedule = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final initial =
                  confirmedDate == null || confirmedDate!.isBefore(today)
                  ? today
                  : confirmedDate!;

              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: initial,
                firstDate: today,
                lastDate: DateTime(now.year + 2),
              );

              if (picked != null) {
                setDialogState(() => confirmedDate = picked);
              }
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: dialogContext,
                initialTime: confirmedTime ?? TimeOfDay.now(),
              );

              if (picked != null) {
                setDialogState(() => confirmedTime = picked);
              }
            }

            final pickup = _order?['fulfilment_method']?.toString() == 'pickup';
            final fulfilment = pickup ? 'Pickup' : 'Delivery';
            final requestedDate = _parseRequestedDate();
            final requestedTime = _parseRequestedTime();

            return AlertDialog(
              title: Text(
                'Confirm $fulfilment Schedule',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_customerName()} requested the following $fulfilment schedule.',
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0DC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_outlined, color: _darkRed),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              requestedDate == null || requestedTime == null
                                  ? 'Butcher request is incomplete.'
                                  : 'Requested: ${_dateDisplay(requestedDate)} at '
                                        '${requestedTime.format(dialogContext)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'SUPPLIER CONFIRMED SCHEDULE',
                      style: TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                confirmedDate == null
                                    ? 'Choose date'
                                    : _dateDisplay(confirmedDate!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickTime,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                confirmedTime == null
                                    ? 'Choose time'
                                    : confirmedTime!.format(dialogContext),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Keep the butcher’s requested schedule or change it. '
                      'The confirmed date and time will follow the order into fulfilment.',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Back'),
                ),
                FilledButton.icon(
                  onPressed: confirmedDate == null || confirmedTime == null
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop({
                            'confirmed_date': _dateDbValue(confirmedDate!),
                            'confirmed_time': _timeDbValue(confirmedTime!),
                          });
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _darkRed,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accept & Create Work Order'),
                ),
              ],
            );
          },
        );
      },
    );

    if (schedule == null || !mounted) return;

    setState(() => _saving = true);

    try {
      await Supabase.instance.client.rpc(
        'accept_marketplace_order_and_create_work_order',
        params: {
          'target_order_id': widget.orderId,
          'confirmed_date': schedule['confirmed_date'],
          'confirmed_time': schedule['confirmed_time'],
        },
      );

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SupplierWorkOrderPage(orderId: widget.orderId),
        ),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject() async {
    if (_saving || _order?['status']?.toString() != 'submitted') return;

    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject marketplace order'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Give the butcher a clear reason. They will see it before '
                  'the cancelled order is removed from their Orders page.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Reason for rejection',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.length < 3) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a rejection reason.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8D1B1B),
              ),
              child: const Text('Reject Order'),
            ),
          ],
        ),
      );

      if (reason == null) return;

      setState(() => _saving = true);

      await Supabase.instance.client.rpc(
        'reject_marketplace_order',
        params: {'target_order_id': widget.orderId, 'rejection_reason': reason},
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
      controller.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _info(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _darkRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'New Marketplace Order',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 54, color: _darkRed),
                    const SizedBox(height: 14),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    final business = _map(order['businesses']);
    final items = _items();
    final submitted = order['status']?.toString() == 'submitted';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4E5E5),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: _darkRed,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['order_number']?.toString() ??
                              'Marketplace Order',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _customerName(),
                          style: const TextStyle(
                            color: _darkRed,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: submitted
                          ? const Color(0xFFEAF1FB)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      submitted
                          ? 'NEW'
                          : order['status'].toString().toUpperCase(),
                      style: TextStyle(
                        color: submitted
                            ? const Color(0xFF315A8C)
                            : const Color(0xFF2E7D32),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 245,
                  child: _info(
                    'FULFILMENT',
                    _fulfilmentLabel(),
                    Icons.local_shipping_outlined,
                  ),
                ),
                SizedBox(
                  width: 245,
                  child: _info(
                    'REQUESTED DATE',
                    _date(order['requested_fulfilment_date']),
                    Icons.event_outlined,
                  ),
                ),
                SizedBox(
                  width: 245,
                  child: _info(
                    'REQUESTED TIME',
                    order['requested_fulfilment_time']?.toString() ??
                        'Not specified',
                    Icons.schedule_outlined,
                  ),
                ),
                if (order['confirmed_fulfilment_date'] != null)
                  SizedBox(
                    width: 245,
                    child: _info(
                      'CONFIRMED DATE',
                      _date(order['confirmed_fulfilment_date']),
                      Icons.event_available_outlined,
                    ),
                  ),
                if (order['confirmed_fulfilment_time'] != null)
                  SizedBox(
                    width: 245,
                    child: _info(
                      'CONFIRMED TIME',
                      order['confirmed_fulfilment_time']?.toString() ??
                          'Not specified',
                      Icons.access_time_outlined,
                    ),
                  ),
                SizedBox(
                  width: 245,
                  child: _info(
                    'PAYMENT',
                    order['payment_method_snapshot']
                            ?.toString()
                            .toUpperCase() ??
                        'Not set',
                    Icons.payments_outlined,
                  ),
                ),
                SizedBox(
                  width: 245,
                  child: _info(
                    'CUSTOMER REF',
                    order['customer_reference']?.toString().trim().isNotEmpty ==
                            true
                        ? order['customer_reference'].toString()
                        : 'None',
                    Icons.tag_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0DD)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Butcher Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Trading name: ${business?['trading_name'] ?? 'Not provided'}',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Legal name: ${business?['legal_name'] ?? 'Not provided'}',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Email: ${business?['business_email'] ?? 'Not provided'}',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Phone: ${business?['business_phone'] ?? 'Not provided'}',
                    ),
                    const SizedBox(height: 5),
                    Text('Address: ${_address()}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ordered Products',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E0DD)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name_snapshot']?.toString() ??
                                'Product',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          if (item['sku_snapshot']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 4),
                            Text(
                              'SKU ${item['sku_snapshot']}',
                              style: const TextStyle(color: Color(0xFF777777)),
                            ),
                          ],
                          const SizedBox(height: 7),
                          Text(
                            '${_quantity(item['quantity'])} ${_unit(item['quantity_unit']?.toString())} ordered',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (item['catch_weight_snapshot'] == true) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Catch weight — actual kilograms are entered during warehouse fulfilment.',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_money(item['unit_price'])}/${_unit(item['price_basis']?.toString())}',
                          style: const TextStyle(
                            color: _darkRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (item['catch_weight_snapshot'] == true)
                          const Text(
                            'Final total pending weight',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (order['delivery_notes']?.toString().trim().isNotEmpty ==
                true) ...[
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery / Order Notes',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 7),
                      Text(order['delivery_notes'].toString()),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (submitted)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _reject,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Accept & Open Work Order'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
