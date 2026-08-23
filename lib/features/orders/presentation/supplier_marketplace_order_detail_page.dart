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

  Future<void> _accept() async {
    if (_saving || _order?['status']?.toString() != 'submitted') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept this marketplace order?'),
        content: Text(
          'Accept ${_order?['order_number'] ?? 'this order'} from '
          '${_customerName()}?\n\n'
          'CutLink will reserve the ordered stock and create the marketplace '
          'Work Order immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Accept & Open Work Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      await Supabase.instance.client.rpc(
        'accept_marketplace_order_and_create_work_order',
        params: {'target_order_id': widget.orderId},
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

    Widget productList() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
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
                    'Ordered Products',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} line${items.length == 1 ? '' : 's'}',
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
            for (var index = 0; index < items.length; index++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[index]['product_name_snapshot']?.toString() ??
                                'Product',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          if (items[index]['sku_snapshot']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 2),
                            Text(
                              'SKU ${items[index]['sku_snapshot']}',
                              style: const TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 105,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ORDERED',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_quantity(items[index]['quantity'])} '
                            '${_unit(items[index]['quantity_unit']?.toString())}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 125,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'LOCKED RATE',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_money(items[index]['unit_price'])}/'
                            '${_unit(items[index]['price_basis']?.toString())}',
                            style: const TextStyle(
                              color: _darkRed,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (items[index]['catch_weight_snapshot'] == true)
                            const Text(
                              'Pending weight',
                              style: TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index != items.length - 1)
                const Divider(height: 1, indent: 14, endIndent: 14),
            ],
          ],
        ),
      );
    }

    Widget summaryPanel() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 11),
            _info(
              'FULFILMENT',
              _fulfilmentLabel(),
              Icons.local_shipping_outlined,
            ),
            const SizedBox(height: 8),
            _info(
              'REQUESTED DATE',
              _date(order['requested_fulfilment_date']),
              Icons.event_outlined,
            ),
            const SizedBox(height: 8),
            _info(
              'PAYMENT',
              order['payment_method_snapshot']?.toString().toUpperCase() ??
                  'Not set',
              Icons.payments_outlined,
            ),
            const SizedBox(height: 8),
            _info(
              'CUSTOMER REF',
              order['customer_reference']?.toString().trim().isNotEmpty == true
                  ? order['customer_reference'].toString()
                  : 'None',
              Icons.tag_outlined,
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Butcher',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              business?['trading_name']?.toString() ??
                  business?['legal_name']?.toString() ??
                  _customerName(),
              style: const TextStyle(
                color: _darkRed,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              business?['business_email']?.toString() ?? 'No email provided',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 3),
            Text(
              business?['business_phone']?.toString() ?? 'No phone provided',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 3),
            Text(
              _address(),
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF666666),
                height: 1.35,
              ),
            ),
            if (order['delivery_notes']?.toString().trim().isNotEmpty ==
                true) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Text(
                'Order Notes',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                order['delivery_notes'].toString(),
                style: const TextStyle(fontSize: 12.5, height: 1.35),
              ),
            ],
            if (submitted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _accept,
                  style: FilledButton.styleFrom(
                    backgroundColor: _darkRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Accept & Open Work Order'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _reject,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject Order'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 940;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0DD)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF1FB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Color(0xFF315A8C),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['order_number']?.toString() ??
                                    'Marketplace Order',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _customerName(),
                                style: const TextStyle(
                                  color: _darkRed,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (desktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: productList()),
                        const SizedBox(width: 12),
                        SizedBox(width: 340, child: summaryPanel()),
                      ],
                    )
                  else ...[
                    productList(),
                    const SizedBox(height: 12),
                    summaryPanel(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
