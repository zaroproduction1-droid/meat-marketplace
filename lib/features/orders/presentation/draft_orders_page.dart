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
  String? _selectedOrderId;

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

      final loadedOrders = List<Map<String, dynamic>>.from(response);
      final currentStillExists = loadedOrders.any(
        (order) => order['id']?.toString() == _selectedOrderId,
      );

      setState(() {
        _butcherBusinessId = butcherBusinessId;
        _orders = loadedOrders;
        _selectedOrderId = currentStillExists
            ? _selectedOrderId
            : (loadedOrders.isEmpty
                  ? null
                  : loadedOrders.first['id']?.toString());
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          .update({'quantity': newQuantity})
          .eq('id', item['id']);

      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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

      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _submitOrder(Map<String, dynamic> order) async {
    final items = _items(order);

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one product before submitting the order.',
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
          .update({'status': 'submitted'})
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
          'Cart',
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
                size: 56,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 14),
              const Text(
                'Cart could not be loaded',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
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
                size: 68,
                color: Color(0xFF741C1C),
              ),
              SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 7),
              Text(
                'Products added from Browse Products will appear here, grouped by supplier.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    Map<String, dynamic>? selectedOrder;
    for (final order in _orders) {
      if (order['id']?.toString() == _selectedOrderId) {
        selectedOrder = order;
        break;
      }
    }
    selectedOrder ??= _orders.first;

    Widget supplierQueue() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(13, 12, 13, 9),
              child: Text(
                'Supplier Orders',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: _orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final id = order['id']?.toString();
                  final selected = id == selectedOrder!['id']?.toString();
                  final itemCount = _items(order).length;

                  return Material(
                    color: selected
                        ? const Color(0xFFF5EAEA)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => setState(() => _selectedOrderId = id),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFC79898)
                                : const Color(0xFFE5E5E1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                size: 18,
                                color: Color(0xFF741C1C),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _supplierName(order),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$itemCount item${itemCount == 1 ? '' : 's'} • ${order['order_number'] ?? 'Draft'}',
                                    style: const TextStyle(
                                      color: Color(0xFF777777),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF741C1C),
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    Widget itemRow(Map<String, dynamic> order, Map<String, dynamic> item) {
      final quantity = _formatNumber(item['quantity']);
      final unit = _unitLabel(item['quantity_unit']?.toString());
      final rate = _money(item['unit_price']);
      final basis = _priceBasisLabel(item['price_basis']?.toString());

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE2E2DE)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 17,
                color: Color(0xFF741C1C),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['product_name_snapshot']?.toString() ?? 'Product',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$quantity $unit • $rate${basis.isEmpty ? '' : ' / $basis'}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _editQuantity(order, item),
              tooltip: 'Change quantity',
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              onPressed: () => _removeItem(order, item),
              tooltip: 'Remove',
              color: const Color(0xFF8C3A3A),
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
      );
    }

    Widget orderWorkspace(Map<String, dynamic> order) {
      final items = _items(order);

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _supplierName(order),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order['order_number'] ?? 'Draft order'} • ${items.length} item${items.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EAEA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Draft',
                      style: TextStyle(
                        color: Color(0xFF741C1C),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'No products in this supplier order.',
                        style: TextStyle(color: Color(0xFF777777)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (_, index) => itemRow(order, items[index]),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFBFBF9),
                border: Border(top: BorderSide(color: Color(0xFFE0E0DD))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 620;

                  final totals = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Total',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _money(order['total_amount']),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GST included: ${_money(order['gst_amount'])}',
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  );

                  final submit = FilledButton.icon(
                    onPressed: items.isEmpty ? null : () => _submitOrder(order),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF741C1C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Submit Order'),
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [totals, const SizedBox(height: 10), submit],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: totals),
                      submit,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 850;

              if (narrow) {
                return ListView(
                  children: [
                    SizedBox(height: 260, child: supplierQueue()),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 620,
                      child: orderWorkspace(selectedOrder!),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 310, child: supplierQueue()),
                  const SizedBox(width: 10),
                  Expanded(child: orderWorkspace(selectedOrder!)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
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
        border: Border.all(color: const Color(0xFFE4E4E1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 650;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['product_name_snapshot']?.toString() ?? 'Unnamed product',
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
                  style: const TextStyle(color: Color(0xFF666666)),
                ),
              const SizedBox(height: 8),
              Text(
                '$quantity $quantityUnit × $price${priceBasis.isEmpty ? '' : ' / $priceBasis'}',
                style: const TextStyle(color: Color(0xFF555555)),
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
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Quantity'),
                  ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 12), actions],
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

// ignore: unused_element
class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    // ignore: unused_element_parameter
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
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
