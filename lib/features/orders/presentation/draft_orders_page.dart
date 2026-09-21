import '../../../shared/widgets/phone_layout.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/cutlink_notice.dart';
import '../../../shared/formatters/order_reference.dart';

class DraftOrdersPage extends StatefulWidget {
  const DraftOrdersPage({super.key});

  @override
  State<DraftOrdersPage> createState() => _DraftOrdersPageState();
}

class _DraftOrdersPageState extends State<DraftOrdersPage> {
  static const _darkRed = Color(0xFF741C1C);
  static const _canvas = Color(0xFFF5F6F8);
  bool _isLoading = true;
  String? _errorMessage;
  String? _butcherBusinessId;

  List<Map<String, dynamic>> _orders = [];
  String? _openOrderId;

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
          params: {'target_order_id': draftId},
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
            delivery_address_label_snapshot,
            delivery_contact_name_snapshot,
            delivery_contact_phone_snapshot,
            delivery_address_line_1_snapshot,
            delivery_address_line_2_snapshot,
            delivery_suburb_snapshot,
            delivery_state_snapshot,
            delivery_address_postcode_snapshot,
            delivery_instructions_snapshot,
            delivery_minimum_order_snapshot,
            delivery_lead_time_days_snapshot,
            delivery_cutoff_time_snapshot,
            pickup_available_snapshot,
            subtotal,
            gst_amount,
            total_amount,
            pricing_status,
            minimum_order_status,
            fulfilment_method,
            requested_fulfilment_date,
            requested_fulfilment_time,
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
              catch_weight_snapshot,
              supplied_quantity,
              supplied_quantity_unit,
              actual_weight,
              actual_weight_unit,
              final_line_amount,
              fulfilment_status,
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
        if (_orders.isEmpty) {
          _openOrderId = null;
        } else if (_openOrderId == null ||
            !_orders.any((order) => order['id']?.toString() == _openOrderId)) {
          _openOrderId = _orders.first['id']?.toString();
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

  bool _isCatchWeightItem(Map<String, dynamic> item) {
    return item['catch_weight_snapshot'] == true &&
        item['price_basis']?.toString() == 'kilogram';
  }

  bool _orderHasCatchWeightItems(Map<String, dynamic> order) {
    return _items(order).any(_isCatchWeightItem);
  }

  String _draftPricingStatusText(Map<String, dynamic> order) {
    if (_orderHasCatchWeightItems(order)) {
      return 'Final product total pending supplier weight';
    }

    return 'Order total known';
  }

  Future<void> _editQuantity(
    Map<String, dynamic> order,
    Map<String, dynamic> item,
  ) async {
    final controller = TextEditingController(
      text: _formatNumber(item['quantity']),
    );

    final quantityUnit = item['quantity_unit']?.toString();
    final requiresWholeNumber =
        quantityUnit == 'carton' || quantityUnit == 'unit';

    final newQuantity = await showDialog<double>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsed = double.tryParse(controller.text.trim());
            final valid =
                parsed != null &&
                parsed > 0 &&
                (!requiresWholeNumber || parsed == parsed.roundToDouble());

            return phoneDialog(
              context,
              AlertDialog(
                title: const Text('Change quantity'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: !requiresWholeNumber,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    suffixText: _unitLabel(quantityUnit),
                    helperText: requiresWholeNumber
                        ? 'Cartons and units must be whole numbers.'
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: !valid
                        ? null
                        : () {
                            Navigator.of(context).pop(parsed);
                          },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
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

      CutLinkNotice.show(
        context,
        title: 'Something went wrong',
        message: error.message,
        error: true,
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
        return phoneDialog(
          context,
          AlertDialog(
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
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
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

      CutLinkNotice.show(
        context,
        title: 'Something went wrong',
        message: error.message,
        error: true,
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
        return phoneDialog(
          context,
          AlertDialog(
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
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
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

      CutLinkNotice.show(
        context,
        title: 'Something went wrong',
        message: error.message,
        error: true,
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
    if (_isPickup(order)) {
      return 0;
    }

    if (_orderHasCatchWeightItems(order)) {
      return 0;
    }

    final minimum = _minimumOrder(order);

    if (minimum == null) {
      return 0;
    }

    final subtotal = _asDouble(order['subtotal']);
    final remaining = minimum - subtotal;

    return remaining > 0 ? remaining : 0;
  }

  bool _meetsMinimumOrder(Map<String, dynamic> order) {
    if (_isPickup(order)) {
      return true;
    }

    if (_orderHasCatchWeightItems(order)) {
      return true;
    }

    return _amountRemainingForMinimum(order) <= 0;
  }

  String _deliveryZoneLabel(Map<String, dynamic> order) {
    final zone = order['delivery_zone_name_snapshot']?.toString().trim();

    if (zone != null && zone.isNotEmpty) {
      return zone;
    }

    final postcode = order['delivery_postcode_snapshot']?.toString().trim();

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

    final days = raw is num ? raw.toInt() : int.tryParse('$raw');

    if (days == null) {
      return 'Not set';
    }

    return '$days day${days == 1 ? '' : 's'}';
  }

  String _cutoffLabel(Map<String, dynamic> order) {
    final raw = order['delivery_cutoff_time_snapshot']?.toString();

    if (raw == null || raw.isEmpty) {
      return 'Not set';
    }

    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  Widget _buildMinimumOrderNotice(Map<String, dynamic> order) {
    if (_isPickup(order)) {
      return const SizedBox.shrink();
    }

    final minimum = _minimumOrder(order);

    if (minimum == null) {
      return const SizedBox.shrink();
    }

    if (_orderHasCatchWeightItems(order)) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE7C27A)),
        ),
        child: Text(
          'Minimum order value for delivery: ${_money(minimum)}. '
          'This order contains catch-weight products, so the final product '
          'value cannot be confirmed until the supplier weighs the cartons. '
          'The minimum will be confirmed by the supplier.',
          style: const TextStyle(
            color: Color(0xFF7A5200),
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      );
    }

    final remaining = _amountRemainingForMinimum(order);
    final met = remaining <= 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: met ? const Color(0xFFF2F7F2) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: met ? const Color(0xFFB7D5B7) : const Color(0xFFE7C27A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.info_outline,
            color: met ? const Color(0xFF2F6D3A) : const Color(0xFF9A6700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              met
                  ? 'Minimum order value for delivery met. Required minimum: ${_money(minimum)}.'
                  : 'Minimum order value for delivery is ${_money(minimum)}. '
                        'Add another ${_money(remaining)} before submitting.',
              style: TextStyle(
                color: met ? const Color(0xFF2F6D3A) : const Color(0xFF7A5200),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySnapshotCard(Map<String, dynamic> order) {
    final hasSnapshot =
        order['delivery_postcode_snapshot'] != null ||
        order['delivery_zone_name_snapshot'] != null ||
        order['delivery_minimum_order_snapshot'] != null ||
        order['delivery_lead_time_days_snapshot'] != null ||
        _deliveryFee(order) > 0;

    if (!hasSnapshot) return const SizedBox.shrink();

    final fee = _deliveryFee(order);
    final address =
        [
              order['delivery_address_label_snapshot'],
              order['delivery_address_line_1_snapshot'],
              order['delivery_address_line_2_snapshot'],
              order['delivery_suburb_snapshot'],
              order['delivery_state_snapshot'],
              order['delivery_address_postcode_snapshot'],
            ]
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .join(', ');

    Widget chip(IconData icon, String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE3E5E8)),
        ),
        child: PhoneRow(
          mode: PhoneRowMode.wrap,
          desktop: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: _darkRed),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery details',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              address,
              style: const TextStyle(
                color: Color(0xFF55585D),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              chip(Icons.map_outlined, _deliveryZoneLabel(order)),
              chip(Icons.timelapse_outlined, _leadTimeLabel(order)),
              chip(Icons.schedule_outlined, 'Cut-off ${_cutoffLabel(order)}'),
              chip(
                Icons.local_shipping_outlined,
                fee == 0 ? 'Free delivery' : _money(fee),
              ),
            ],
          ),
          _buildMinimumOrderNotice(order),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _resolveDefaultDeliveryAddress() async {
    final butcherBusinessId = _butcherBusinessId;

    if (butcherBusinessId == null || butcherBusinessId.isEmpty) {
      return null;
    }

    final rows = await Supabase.instance.client
        .from('butcher_delivery_addresses')
        .select("""
          id,
          label,
          contact_name,
          contact_phone,
          address_line_1,
          address_line_2,
          suburb,
          state,
          postcode,
          delivery_instructions,
          is_default,
          is_active
        """)
        .eq('butcher_business_id', butcherBusinessId)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('label')
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(rows.first);
  }

  bool _isPickup(Map<String, dynamic> order) =>
      order['fulfilment_method']?.toString() == 'pickup';

  Future<void> _setFulfilmentMethod(
    Map<String, dynamic> order,
    String method,
  ) async {
    try {
      if (method == 'pickup') {
        await Supabase.instance.client
            .from('orders')
            .update({'fulfilment_method': 'pickup', 'delivery_fee': 0})
            .eq('id', order['id'])
            .eq('butcher_business_id', _butcherBusinessId!)
            .eq('status', 'draft');

        await Supabase.instance.client.rpc(
          'recalculate_order_totals',
          params: {'target_order_id': order['id']},
        );
      } else {
        await Supabase.instance.client
            .from('orders')
            .update({'fulfilment_method': 'delivery'})
            .eq('id', order['id'])
            .eq('butcher_business_id', _butcherBusinessId!)
            .eq('status', 'draft');

        await Supabase.instance.client.rpc(
          'refresh_draft_order_delivery_terms',
          params: {'target_order_id': order['id']},
        );
      }

      if (!mounted) return;
      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      CutLinkNotice.show(
        context,
        title: 'Fulfilment option not saved',
        message: error.message,
        error: true,
      );
    }
  }

  Widget _buildFulfilmentMethodCard(Map<String, dynamic> order) {
    final pickup = _isPickup(order);

    Widget option({
      required String method,
      required IconData icon,
      required String title,
      required String subtitle,
      required bool enabled,
    }) {
      final selected = pickup ? method == 'pickup' : method == 'delivery';
      return Expanded(
        child: InkWell(
          onTap: enabled ? () => _setFulfilmentMethod(order, method) : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF3F3) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _darkRed : const Color(0xFFE1E3E6),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: selected ? _darkRed : const Color(0xFF5B6168),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: enabled
                              ? const Color(0xFF20242A)
                              : const Color(0xFF9A9EA4),
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: selected ? _darkRed : const Color(0xFFB0B3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF73777D),
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PhoneRow(
      mode: PhoneRowMode.stack,
      desktop: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          option(
            method: 'delivery',
            icon: Icons.local_shipping_outlined,
            title: 'Delivery',
            subtitle: 'Deliver to your saved business address',
            enabled: true,
          ),
          const SizedBox(width: 10),
          option(
            method: 'pickup',
            icon: Icons.store_mall_directory_outlined,
            title: 'Pickup',
            subtitle: 'Collect directly from ${_supplierName(order)}',
            enabled: true,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _deliverySnapshotPayload(
    Map<String, dynamic> order,
    Map<String, dynamic> address,
  ) {
    String? clean(dynamic value) {
      final valueText = value?.toString().trim() ?? '';
      return valueText.isEmpty ? null : valueText;
    }

    final postcode = clean(address['postcode']);

    return {
      'fulfilment_method': 'delivery',
      'delivery_address_label_snapshot': clean(address['label']),
      'delivery_contact_name_snapshot': clean(address['contact_name']),
      'delivery_contact_phone_snapshot': clean(address['contact_phone']),
      'delivery_address_line_1_snapshot': clean(address['address_line_1']),
      'delivery_address_line_2_snapshot': clean(address['address_line_2']),
      'delivery_suburb_snapshot': clean(address['suburb']),
      'delivery_state_snapshot': clean(address['state']),
      'delivery_address_postcode_snapshot': postcode,
      'delivery_postcode_snapshot': postcode,
      'delivery_instructions_snapshot':
          clean(address['delivery_instructions']) ??
          clean(order['delivery_notes']),
    };
  }

  DateTime? _requestedDate(Map<String, dynamic> order) {
    final raw = order['requested_fulfilment_date']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  TimeOfDay? _requestedTime(Map<String, dynamic> order) {
    final raw = order['requested_fulfilment_time']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Choose requested date';
    const months = <String>[
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

  String _timeLabel(BuildContext context, Map<String, dynamic> order) {
    final time = _requestedTime(order);
    if (time == null) return '12:00 PM default';
    return time.format(context);
  }

  Future<void> _pickRequestedDate(Map<String, dynamic> order) async {
    final now = DateTime.now();
    final current = _requestedDate(order);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          current != null &&
              !current.isBefore(DateTime(now.year, now.month, now.day))
          ? current
          : DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;

    final value = picked.toIso8601String().split('T').first;
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'requested_fulfilment_date': value})
          .eq('id', order['id'])
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'draft');
      if (!mounted) return;
      setState(() => order['requested_fulfilment_date'] = value);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      CutLinkNotice.show(
        context,
        title: 'Date not saved',
        message: error.message,
        error: true,
      );
    }
  }

  Future<void> _pickRequestedTime(Map<String, dynamic> order) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _requestedTime(order) ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked == null || !mounted) return;

    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'requested_fulfilment_time': value})
          .eq('id', order['id'])
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'draft');
      if (!mounted) return;
      setState(() => order['requested_fulfilment_time'] = value);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      CutLinkNotice.show(
        context,
        title: 'Time not saved',
        message: error.message,
        error: true,
      );
    }
  }

  Future<void> _resetRequestedTime(Map<String, dynamic> order) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'requested_fulfilment_time': null})
          .eq('id', order['id'])
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'draft');
      if (!mounted) return;
      setState(() => order['requested_fulfilment_time'] = null);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      CutLinkNotice.show(
        context,
        title: 'Time not reset',
        message: error.message,
        error: true,
      );
    }
  }

  Future<void> _cancelSupplierDraft(Map<String, dynamic> order) async {
    final supplier = _supplierName(order);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => phoneDialog(
        context,
        AlertDialog(
          title: const Text('Remove supplier order?'),
          content: Text(
            'Remove the entire draft order for $supplier from your cart? '
            'All products in this supplier order will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Order'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              child: const Text('Remove Order'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('orders')
          .delete()
          .eq('id', order['id'])
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'draft');
      if (!mounted) return;
      CutLinkNotice.show(
        context,
        title: 'Order removed',
        message: '$supplier was removed from your cart.',
      );
      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      CutLinkNotice.show(
        context,
        title: 'Could not remove order',
        message: error.message,
        error: true,
      );
    }
  }

  Widget _buildRequestedScheduleCard(Map<String, dynamic> order) {
    final date = _requestedDate(order);
    final pickup = _isPickup(order);
    final fulfilmentLabel = pickup ? 'pickup' : 'delivery';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final dateButton = OutlinedButton.icon(
            onPressed: () => _pickRequestedDate(order),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(
              date == null
                  ? '${pickup ? 'Pickup' : 'Delivery'} date required'
                  : _dateLabel(date),
            ),
          );
          final timeButton = OutlinedButton.icon(
            onPressed: () => _pickRequestedTime(order),
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: Text(_timeLabel(context, order)),
          );
          final resetTime = _requestedTime(order) == null
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: () => _resetRequestedTime(order),
                  child: const Text('Use 12:00 PM default'),
                );

          final controls = <Widget>[
            if (compact) dateButton else Expanded(child: dateButton),
            const SizedBox(width: 10, height: 10),
            if (compact) timeButton else Expanded(child: timeButton),
            if (_requestedTime(order) != null) ...[
              const SizedBox(width: 6, height: 6),
              resetTime,
            ],
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhoneRow(
                mode: PhoneRowMode.wrap,
                desktop: Row(
                  children: [
                    Icon(
                      pickup
                          ? Icons.store_mall_directory_outlined
                          : Icons.local_shipping_outlined,
                      color: _darkRed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Requested ${pickup ? 'pickup' : 'delivery'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the requested $fulfilmentLabel day. Time is optional and defaults to 12:00 PM if left blank.',
                style: const TextStyle(
                  color: Color(0xFF666A70),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 10),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: controls,
                )
              else
                Row(children: controls),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitOrder(Map<String, dynamic> order) async {
    final items = _items(order);
    final pickup = _isPickup(order);
    final fulfilmentLabel = pickup ? 'pickup' : 'delivery';

    if (items.isEmpty) {
      CutLinkNotice.show(
        context,
        title: 'Cart is empty',
        message: 'Add at least one product before submitting the order.',
        error: true,
      );
      return;
    }

    if (!_meetsMinimumOrder(order)) {
      final remaining = _amountRemainingForMinimum(order);
      final minimum = _minimumOrder(order);

      CutLinkNotice.show(
        context,
        title: 'Minimum order not met',
        message:
            'Minimum order value for delivery is ${_money(minimum)}. '
            'Add another ${_money(remaining)} before submitting.',
        error: true,
      );
      return;
    }

    final requestedDate = _requestedDate(order);
    if (requestedDate == null) {
      CutLinkNotice.show(
        context,
        title: 'Requested date required',
        message:
            'Choose the requested $fulfilmentLabel day before submitting this order.',
        error: true,
      );
      return;
    }

    final requestedTime =
        _requestedTime(order) ?? const TimeOfDay(hour: 12, minute: 0);
    final requestedTimeValue =
        '${requestedTime.hour.toString().padLeft(2, '0')}:'
        '${requestedTime.minute.toString().padLeft(2, '0')}';
    final orderReference = cutLinkOrderReference(order['order_number']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return phoneDialog(
          context,
          AlertDialog(
            title: Text('Submit $orderReference?'),
            content: Text(
              _orderHasCatchWeightItems(order)
                  ? 'Submit $orderReference to ${_supplierName(order)} for $fulfilmentLabel? '
                        'Catch-weight product totals remain pending until the supplier records the actual supplied kilograms.'
                  : 'Submit $orderReference to ${_supplierName(order)} for $fulfilmentLabel? '
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
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Submit Order'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      final payload = <String, dynamic>{
        'fulfilment_method': pickup ? 'pickup' : 'delivery',
        'requested_fulfilment_date': requestedDate
            .toIso8601String()
            .split('T')
            .first,
        'requested_fulfilment_time': requestedTimeValue,
        'status': 'submitted',
      };

      if (pickup) {
        payload['delivery_fee'] = 0;
      } else {
        final deliveryAddress = await _resolveDefaultDeliveryAddress();

        if (deliveryAddress == null) {
          if (!mounted) return;
          CutLinkNotice.show(
            context,
            title: 'Delivery address required',
            message:
                'Add an active delivery address in Settings before submitting this order.',
            error: true,
          );
          return;
        }

        final addressLine1 =
            deliveryAddress['address_line_1']?.toString().trim() ?? '';
        final postcode = deliveryAddress['postcode']?.toString().trim() ?? '';

        if (addressLine1.isEmpty || postcode.isEmpty) {
          if (!mounted) return;
          CutLinkNotice.show(
            context,
            title: 'Delivery address incomplete',
            message:
                'Your delivery address must include an address line and postcode before submitting.',
            error: true,
          );
          return;
        }

        payload.addAll(_deliverySnapshotPayload(order, deliveryAddress));
      }

      await Supabase.instance.client
          .from('orders')
          .update(payload)
          .eq('id', order['id'])
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'draft');

      if (!mounted) return;

      CutLinkNotice.show(
        context,
        title: 'Order submitted',
        message:
            '$orderReference was submitted to ${_supplierName(order)} for $fulfilmentLabel.',
      );

      await _loadDraftOrders();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      CutLinkNotice.show(
        context,
        title: 'Something went wrong',
        message: error.message,
        error: true,
      );
    }
  }

  Widget _buildCartOverview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactDesktop = constraints.maxWidth >= 760;

        final heading = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your cart',
              style: TextStyle(
                fontSize: 19,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${_orders.length} supplier order${_orders.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Color(0xFF6A6E75),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        if (compactDesktop) {
          return Container(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
            ),
            child: Row(
              children: [
                SizedBox(width: 150, child: heading),
                const SizedBox(width: 18),
                Expanded(child: _buildSupplierOrderSelector()),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 7),
              _buildSupplierOrderSelector(),
              const Divider(height: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupplierOrderSelector() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (context, index) {
          final order = _orders[index];
          final orderId = order['id']?.toString();
          final selected = orderId != null && orderId == _openOrderId;
          final itemCount = _items(order).length;

          return InkWell(
            onTap: () {
              setState(() {
                _openOrderId = selected ? null : orderId;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? _darkRed : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _supplierName(order),
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF202020)
                              : const Color(0xFF55585D),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$itemCount product line${itemCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFF777B80),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Remove this supplier order',
                    child: InkWell(
                      onTap: () => _cancelSupplierDraft(order),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: Color(0xFF9B2C2C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    selected ? Icons.expand_less : Icons.expand_more,
                    size: 19,
                    color: selected ? _darkRed : const Color(0xFF777B80),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: phoneAppBar(
        context,
        AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 20,
          title: const Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF741C1C),
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Cart & Draft Orders',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loadDraftOrders,
              tooltip: 'Refresh orders',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 10),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE3E5E8)),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildOrderProductsPane(Map<String, dynamic> order) {
    final items = _items(order);
    final reference = cutLinkOrderReference(order['order_number']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _supplierName(order),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order $reference  •  ${items.length} product line${items.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF666A70),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Remove this supplier order',
                child: IconButton(
                  onPressed: () => _cancelSupplierDraft(order),
                  icon: const Icon(Icons.close_rounded),
                  color: _darkRed,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF3F3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Products',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '${items.length} line${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFF666A70),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'This draft order has no products.',
                style: TextStyle(color: Color(0xFF666666)),
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
          _buildMinimumOrderNotice(order),
          if (_orderHasCatchWeightItems(order)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE7D7AF)),
              ),
              child: Text(
                _draftPricingStatusText(order),
                style: const TextStyle(
                  color: Color(0xFF6D5722),
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutPane(Map<String, dynamic> order) {
    final items = _items(order);
    final pickup = _isPickup(order);
    final reference = cutLinkOrderReference(order['order_number']);

    Widget summary() {
      if (_orderHasCatchWeightItems(order)) {
        return Column(
          children: [
            const _TotalRow(
              label: 'Products',
              value: 'Pending final weight',
              bold: true,
            ),
            _TotalRow(
              label: pickup ? 'Pickup' : 'Delivery',
              value: pickup
                  ? 'Free'
                  : _deliveryFee(order) == 0
                  ? 'Free'
                  : _money(_deliveryFee(order)),
            ),
            const Divider(),
            const _TotalRow(
              label: 'Final order total',
              value: 'Pending supplier weight',
              bold: true,
            ),
          ],
        );
      }

      return Column(
        children: [
          _TotalRow(
            label: 'Products (inc GST)',
            value: _money(order['subtotal']),
          ),
          _TotalRow(
            label: pickup ? 'Pickup' : 'Delivery (inc GST)',
            value: pickup
                ? 'Free'
                : _deliveryFee(order) == 0
                ? 'Free'
                : _money(_deliveryFee(order)),
          ),
          const Divider(),
          _TotalRow(
            label: 'Total inc GST',
            value: _money(order['total_amount']),
            bold: true,
          ),
          const SizedBox(height: 6),
          _TotalRow(label: 'Total ex GST', value: _money(_exGstAmount(order))),
          _TotalRow(label: 'GST included', value: _money(order['gst_amount'])),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E5E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Checkout • $reference',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose how and when you want this order fulfilled.',
            style: TextStyle(
              color: Color(0xFF6A6E75),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _buildFulfilmentMethodCard(order),
          const SizedBox(height: 12),
          _buildRequestedScheduleCard(order),
          const SizedBox(height: 12),
          if (pickup)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E5E8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.store_mall_directory_outlined,
                    size: 20,
                    color: _darkRed,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Pickup from ${_supplierName(order)}. The supplier will receive your requested pickup date and time.',
                      style: const TextStyle(
                        color: Color(0xFF555A60),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildDeliverySnapshotCard(order),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE3E5E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Order details',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _editOrderDetails(order),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                Text(
                  'Reference: ${order['customer_reference'] == null || order['customer_reference'].toString().trim().isEmpty ? 'Not provided' : order['customer_reference']}',
                  style: const TextStyle(
                    color: Color(0xFF60646A),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Notes: ${order['delivery_notes'] == null || order['delivery_notes'].toString().trim().isEmpty ? 'Not provided' : order['delivery_notes']}',
                  style: const TextStyle(
                    color: Color(0xFF60646A),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Order summary',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          summary(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: items.isEmpty || !_meetsMinimumOrder(order)
                ? null
                : () => _submitOrder(order),
            style: FilledButton.styleFrom(
              backgroundColor: _darkRed,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.send_outlined),
            label: Text('Submit $reference'),
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
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 18),
              const Text(
                'Draft orders could not be loaded',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center),
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
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 46),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E5E8)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 58, color: _darkRed),
                SizedBox(height: 18),
                Text(
                  'Your cart is ready when you are',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Products added from the marketplace are grouped into a separate draft for each supplier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF666A70), height: 1.45),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _openOrderId == null
        ? null
        : _orders.cast<Map<String, dynamic>?>().firstWhere(
            (row) => row?['id']?.toString() == _openOrderId,
            orElse: () => null,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1050 && order != null;

        if (desktop) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCartOverview(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _loadDraftOrders,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [_buildOrderProductsPane(order)],
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 390,
                            child: SingleChildScrollView(
                              child: _buildCheckoutPane(order),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadDraftOrders,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                children: [
                  _buildCartOverview(),
                  if (order != null) ...[
                    const SizedBox(height: 16),
                    _buildOrderProductsPane(order),
                    const SizedBox(height: 14),
                    _buildCheckoutPane(order),
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
    final isCatchWeight =
        item['catch_weight_snapshot'] == true &&
        item['price_basis']?.toString() == 'kilogram';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
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
                isCatchWeight
                    ? '$quantity $quantityUnit ordered at '
                          '$price${priceBasis.isEmpty ? '' : ' / $priceBasis'}'
                    : '$quantity $quantityUnit × '
                          '$price${priceBasis.isEmpty ? '' : ' / $priceBasis'}',
                style: const TextStyle(color: Color(0xFF555555)),
              ),
              if (isCatchWeight) ...[
                const SizedBox(height: 5),
                const Text(
                  'Final kilograms and product total pending supplier weight.',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );

          final actions = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                isCatchWeight
                    ? 'Final total pending'
                    : money(item['line_subtotal']),
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
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
