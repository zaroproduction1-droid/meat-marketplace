import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DraftOrdersPage extends StatefulWidget {
  const DraftOrdersPage({super.key});

  @override
  State<DraftOrdersPage> createState() => _DraftOrdersPageState();
}

class _DraftOrdersPageState extends State<DraftOrdersPage> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _butcherBusinessId;

  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadDraftOrders();
  }

  Future<void> _loadDraftOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final butcherBusinessId = membership['business_id'] as String;

      final draftIds = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('butcher_business_id', butcherBusinessId)
          .eq('status', 'draft');

      for (final rawDraft in draftIds) {
        final draftId = rawDraft['id']?.toString();

        if (draftId == null || draftId.isEmpty) {
          continue;
        }

        await Supabase.instance.client.rpc(
          'refresh_draft_order_delivery_terms',
          params: {
            'target_order_id': draftId,
          },
        );
      }

      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            order_number,
            butcher_business_id,
            supplier_business_id,
            status,
            customer_reference,
            delivery_notes,
            delivery_fee,
            delivery_zone_id,
            delivery_zone_name_snapshot,
            delivery_postcode_snapshot,
            delivery_minimum_order_snapshot,
            delivery_lead_time_days_snapshot,
            delivery_cutoff_time_snapshot,
            pickup_available_snapshot,
            subtotal,
            gst_amount,
            total_amount,
            created_at,
            updated_at,

            businesses!orders_supplier_business_id_fkey(
              legal_name,
              trading_name
            ),

            order_items(
              id,
              order_id,
              product_id,
              product_name_snapshot,
              sku_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              line_subtotal,
              notes,
              created_at
            )
          ''')
          .eq('butcher_business_id', butcherBusinessId)
          .eq('status', 'draft')
          .order('updated_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _butcherBusinessId = butcherBusinessId;
        _orders = List<Map<String, dynamic>>.from(response);
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

  String _supplierName(Map<String, dynamic> order) {
    final raw = order['businesses'];

    if (raw is! Map) {
      return 'Unknown supplier';
    }

    final supplier = Map<String, dynamic>.from(raw);

    final tradingName = supplier['trading_name']?.toString();

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName.trim();
    }

    return supplier['legal_name']?.toString() ?? 'Unknown supplier';
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> order) {
    final raw = order['order_items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort((a, b) {
        final left = a['created_at']?.toString() ?? '';
        final right = b['created_at']?.toString() ?? '';
        return left.compareTo(right);
      });
  }


  String _withThousandsSeparators(String value) {
    final parts = value.split('.');
    final whole = parts.first;
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    final formattedWhole = '${negative ? '-' : ''}${buffer.toString()}';

    if (parts.length == 1) {
      return formattedWhole;
    }

    return '$formattedWhole.${parts.sublist(1).join('.')}';
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
      return _withThousandsSeparators(number.toInt().toString());
    }

    final formatted = number
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return _withThousandsSeparators(formatted);
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return '\$0.00';
    }

    return '\$${_withThousandsSeparators(number.toStringAsFixed(2))}';
  }

  String _unitLabel(String? value) {
    switch (value) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'cartons';
      case 'unit':
        return 'units';
      default:
        return value ?? '';
    }
  }

  String _priceBasisLabel(String? value) {
    switch (value) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'carton';
      case 'unit':
        return 'unit';
      default:
        return value ?? '';
    }
  }

  Future<void> _editQuantity(
    Map<String, dynamic> order,
    Map<String, dynamic> item,
  ) async {
    final controller = TextEditingController(
      text: _formatNumber(item['quantity']),
    );

    final newQuantity = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change quantity'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: _unitLabel(item['quantity_unit']?.toString()),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());

                if (value == null || value <= 0) {
                  return;
                }

                Navigator.of(context).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newQuantity == null) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('order_items')
          .update({
            'quantity': newQuantity,
          })
          .eq('id', item['id']);

      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _removeItem(
    Map<String, dynamic> order,
    Map<String, dynamic> item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove product?'),
          content: Text(
            'Remove ${item['product_name_snapshot'] ?? 'this product'} from the draft order?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('order_items')
          .delete()
          .eq('id', item['id']);

      final remainingItems = await Supabase.instance.client
          .from('order_items')
          .select('id')
          .eq('order_id', order['id'])
          .limit(1);

      if (remainingItems.isEmpty) {
        await Supabase.instance.client
            .from('orders')
            .delete()
            .eq('id', order['id'])
            .eq('butcher_business_id', _butcherBusinessId!)
            .eq('status', 'draft');
      }

      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _editOrderDetails(Map<String, dynamic> order) async {
    final referenceController = TextEditingController(
      text: order['customer_reference']?.toString() ?? '',
    );

    final deliveryController = TextEditingController(
      text: order['delivery_notes']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Order details'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Customer reference',
                    hintText: 'Example: PO-1048 or shop reference',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: deliveryController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Delivery notes',
                    hintText: 'Example: Deliver Friday before 10am',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'customer_reference': referenceController.text.trim(),
                  'delivery_notes': deliveryController.text.trim(),
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    referenceController.dispose();
    deliveryController.dispose();

    if (result == null) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('orders')
          .update({
            'customer_reference': result['customer_reference']!.isEmpty
                ? null
                : result['customer_reference'],
            'delivery_notes': result['delivery_notes']!.isEmpty
                ? null
                : result['delivery_notes'],
          })
          .eq('id', order['id'])
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'draft');

      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  double _exGstAmount(Map<String, dynamic> order) {
    final total = _asDouble(order['total_amount']);
    return total / 1.10;
  }

  double _deliveryFee(Map<String, dynamic> order) {
    return _asDouble(order['delivery_fee']);
  }

  double? _minimumOrder(Map<String, dynamic> order) {
    final value = order['delivery_minimum_order_snapshot'];

    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value');
  }

  double _amountRemainingForMinimum(Map<String, dynamic> order) {
    final minimum = _minimumOrder(order);

    if (minimum == null) {
      return 0;
    }

    final subtotal = _asDouble(order['subtotal']);
    final remaining = minimum - subtotal;

    return remaining > 0 ? remaining : 0;
  }

  bool _meetsMinimumOrder(Map<String, dynamic> order) {
    return _amountRemainingForMinimum(order) <= 0;
  }

  String _deliveryZoneLabel(Map<String, dynamic> order) {
    final zone =
        order['delivery_zone_name_snapshot']?.toString().trim();

    if (zone != null && zone.isNotEmpty) {
      return zone;
    }

    final postcode =
        order['delivery_postcode_snapshot']?.toString().trim();

    if (postcode != null && postcode.isNotEmpty) {
      return 'No matched delivery zone for $postcode';
    }

    return 'No delivery zone matched';
  }

  String _leadTimeLabel(Map<String, dynamic> order) {
    final raw = order['delivery_lead_time_days_snapshot'];

    if (raw == null) {
      return 'Not set';
    }

    final days = raw is num
        ? raw.toInt()
        : int.tryParse('$raw');

    if (days == null) {
      return 'Not set';
    }

    return '$days day${days == 1 ? '' : 's'}';
  }

  String _cutoffLabel(Map<String, dynamic> order) {
    final raw =
        order['delivery_cutoff_time_snapshot']?.toString();

    if (raw == null || raw.isEmpty) {
      return 'Not set';
    }

    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  Widget _buildMinimumOrderNotice(
    Map<String, dynamic> order,
  ) {
    final minimum = _minimumOrder(order);

    if (minimum == null) {
      return const SizedBox.shrink();
    }

    final remaining = _amountRemainingForMinimum(order);
    final met = remaining <= 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: met
            ? const Color(0xFFF2F7F2)
            : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: met
              ? const Color(0xFFB7D5B7)
              : const Color(0xFFE7C27A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            met
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: met
                ? const Color(0xFF2F6D3A)
                : const Color(0xFF9A6700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              met
                  ? 'Minimum order met. Required minimum: ${_money(minimum)}.'
                  : 'Minimum order is ${_money(minimum)}. Add another ${_money(remaining)} before submitting.',
              style: TextStyle(
                color: met
                    ? const Color(0xFF2F6D3A)
                    : const Color(0xFF7A5200),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySnapshotCard(
    Map<String, dynamic> order,
  ) {
    final hasSnapshot =
        order['delivery_postcode_snapshot'] != null ||
        order['delivery_zone_name_snapshot'] != null ||
        order['delivery_minimum_order_snapshot'] != null ||
        order['delivery_lead_time_days_snapshot'] != null ||
        _deliveryFee(order) > 0;

    if (!hasSnapshot) {
      return const SizedBox.shrink();
    }

    final fee = _deliveryFee(order);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE1E1DE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Zone: ${_deliveryZoneLabel(order)}',
            style: const TextStyle(
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lead time: ${_leadTimeLabel(order)}',
            style: const TextStyle(
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cut-off: ${_cutoffLabel(order)}',
            style: const TextStyle(
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pickup: ${order['pickup_available_snapshot'] == true ? 'Available' : 'Not available'}',
            style: const TextStyle(
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fee == 0
                ? 'Delivery fee: Free'
                : 'Delivery fee: ${_money(fee)}',
            style: const TextStyle(
              color: Color(0xFF555555),
              fontWeight: FontWeight.w700,
            ),
          ),
          _buildMinimumOrderNotice(order),
        ],
      ),
    );
  }

  Future<void> _submitOrder(Map<String, dynamic> order) async {
    final items = _items(order);

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one product before submitting the order.'),
        ),
      );
      return;
    }

    if (!_meetsMinimumOrder(order)) {
      final remaining = _amountRemainingForMinimum(order);
      final minimum = _minimumOrder(order);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum order is ${_money(minimum)}. Add another ${_money(remaining)} before submitting.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submit order?'),
          content: Text(
            'Submit ${order['order_number'] ?? 'this order'} to ${_supplierName(order)}? '
            'Once submitted, the order items can no longer be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              child: const Text('Submit Order'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('orders')
          .update({
            'status': 'submitted',
          })
          .eq('id', order['id'])
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'draft');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${order['order_number'] ?? 'Order'} was submitted to ${_supplierName(order)}.',
          ),
        ),
      );

      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Draft Orders',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadDraftOrders,
            tooltip: 'Refresh orders',
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
      return const Center(
        child: CircularProgressIndicator(),
      );
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
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 18),
              const Text(
                'Draft orders could not be loaded',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadDraftOrders,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 76,
                color: Color(0xFF741C1C),
              ),
              SizedBox(height: 20),
              Text(
                'No draft orders',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Products added from the marketplace will appear here before you submit them to a supplier.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDraftOrders,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _orders.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 18);
            },
            itemBuilder: (context, index) {
              final order = _orders[index];
              final items = _items(order);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    color: Color(0xFFE0E0E0),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 650;

                          final header = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['order_number']?.toString() ??
                                    'Draft order',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _supplierName(order),
                                style: const TextStyle(
                                  color: Color(0xFF741C1C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          );

                          final status = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4E5E5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Draft',
                              style: TextStyle(
                                color: Color(0xFF741C1C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );

                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                header,
                                const SizedBox(height: 12),
                                status,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: header),
                              status,
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),

                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'This draft order has no products.',
                            style: TextStyle(
                              color: Color(0xFF666666),
                            ),
                          ),
                        )
                      else
                        for (final item in items)
                          _OrderItemCard(
                            item: item,
                            formatNumber: _formatNumber,
                            money: _money,
                            unitLabel: _unitLabel,
                            priceBasisLabel: _priceBasisLabel,
                            onEdit: () => _editQuantity(order, item),
                            onRemove: () => _removeItem(order, item),
                          ),

                      const SizedBox(height: 8),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE1E1DE),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 650;

                            final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  'Reference: ${order['customer_reference'] == null || order['customer_reference'].toString().trim().isEmpty ? 'Not provided' : order['customer_reference']}',
                                  style: const TextStyle(
                                    color: Color(0xFF555555),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  'Delivery notes: ${order['delivery_notes'] == null || order['delivery_notes'].toString().trim().isEmpty ? 'Not provided' : order['delivery_notes']}',
                                  style: const TextStyle(
                                    color: Color(0xFF555555),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            );

                            final button = OutlinedButton.icon(
                              onPressed: () => _editOrderDetails(order),
                              icon: const Icon(Icons.edit_note_outlined),
                              label: const Text('Edit Details'),
                            );

                            if (narrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  details,
                                  const SizedBox(height: 14),
                                  button,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: details),
                                const SizedBox(width: 18),
                                button,
                              ],
                            );
                          },
                        ),
                      ),

                      _buildDeliverySnapshotCard(order),

                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Column(
                            children: [
                              _TotalRow(
                                label: 'Products (inc GST)',
                                value: _money(order['subtotal']),
                              ),
                              _TotalRow(
                                label: 'Delivery (inc GST)',
                                value: _deliveryFee(order) == 0
                                    ? 'Free'
                                    : _money(_deliveryFee(order)),
                              ),
                              const Divider(),
                              _TotalRow(
                                label: 'Total inc GST',
                                value: _money(order['total_amount']),
                                bold: true,
                              ),
                              const SizedBox(height: 8),
                              _TotalRow(
                                label: 'Total ex GST',
                                value: _money(_exGstAmount(order)),
                              ),
                              _TotalRow(
                                label: 'GST included',
                                value: _money(order['gst_amount']),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed:
                              items.isEmpty || !_meetsMinimumOrder(order)
                                  ? null
                                  : () => _submitOrder(order),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF741C1C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 16,
                            ),
                          ),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Submit Order'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  const _OrderItemCard({
    required this.item,
    required this.formatNumber,
    required this.money,
    required this.unitLabel,
    required this.priceBasisLabel,
    required this.onEdit,
    required this.onRemove,
  });

  final Map<String, dynamic> item;

  final String Function(dynamic value) formatNumber;
  final String Function(dynamic value) money;
  final String Function(String? value) unitLabel;
  final String Function(String? value) priceBasisLabel;

  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final quantity = formatNumber(item['quantity']);
    final quantityUnit = unitLabel(item['quantity_unit']?.toString());

    final price = money(item['unit_price']);
    final priceBasis = priceBasisLabel(item['price_basis']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE4E4E1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 650;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['product_name_snapshot']?.toString() ??
                    'Unnamed product',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              if (item['sku_snapshot'] != null &&
                  item['sku_snapshot'].toString().trim().isNotEmpty)
                Text(
                  'SKU: ${item['sku_snapshot']}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '$quantity $quantityUnit × $price${priceBasis.isEmpty ? '' : ' / $priceBasis'}',
                style: const TextStyle(
                  color: Color(0xFF555555),
                ),
              ),
            ],
          );

          final actions = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                money(item['line_subtotal']),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    label: const Text('Quantity'),
                  ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                    ),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 20),
              actions,
            ],
          );
        },
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
      fontSize: bold ? 17 : 15,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style,
            ),
          ),
          Text(
            value,
            style: style,
          ),
        ],
      ),
    );
  }
}
