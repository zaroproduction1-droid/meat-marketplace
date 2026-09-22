import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/phone_layout.dart';

/// Order-only attribution. Never changes the customer's business profile.
class OrderSalesContact extends StatefulWidget {
  const OrderSalesContact({
    super.key,
    required this.orderId,
    this.locked = false,
  });
  final String orderId;
  final bool locked;
  @override
  State<OrderSalesContact> createState() => _OrderSalesContactState();
}

class _OrderSalesContactState extends State<OrderSalesContact> {
  String _name = '';
  String _phone = '';
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrderSalesContact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.orderId;
    try {
      final db = Supabase.instance.client;
      final order = await db
          .from('orders')
          .select('salesperson_name,salesperson_phone,supplier_business_id')
          .eq('id', id)
          .single();
      final profile = await db
          .from('supplier_invoice_profiles')
          .select('default_salesperson_name,default_salesperson_phone')
          .eq('supplier_business_id', order['supplier_business_id'])
          .maybeSingle();
      if (!mounted || widget.orderId != id) {
        return;
      }
      setState(() {
        _name =
            (order['salesperson_name'] ??
                    profile?['default_salesperson_name'] ??
                    '')
                .toString();
        _phone =
            (order['salesperson_name'] != null
                    ? order['salesperson_phone']
                    : profile?['default_salesperson_phone'])
                ?.toString() ??
            '';
        _error = null;
        _busy = false;
      });
    } catch (_) {
      if (mounted && widget.orderId == id) {
        setState(() {
          _error = 'Could not load sales contact';
          _busy = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    final name = TextEditingController(text: _name);
    final phone = TextEditingController(text: _phone);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => phoneDialog(
        context,
        AlertDialog(
          title: const Text('Sales contact for this order'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Printed on the invoice. Locked when the invoice is created. Leave blank to use your supplier default.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Salesperson name',
                  ),
                ),
                TextField(
                  controller: phone,
                  maxLength: 50,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Salesperson phone',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, [
                name.text.trim(),
                phone.text.trim(),
              ]),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // Dialog controllers are disposed after the closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    phone.dispose();
    if (result == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'set_order_sales_contact',
        params: {
          'target_order_id': widget.orderId,
          'contact_name': result[0],
          'contact_phone': result[1],
        },
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PostgrestException
                  ? error.message
                  : 'Could not save sales contact.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(
          _error ??
              'Salesperson: ${_name.isEmpty ? 'Not set' : _name}${_phone.isEmpty ? '' : ' • $_phone'}',
        ),
        if (!widget.locked)
          TextButton.icon(
            onPressed: _busy
                ? null
                : _error != null
                ? _load
                : _edit,
            icon: const Icon(Icons.badge_outlined, size: 17),
            label: Text(_error != null ? 'Retry' : 'Edit sales contact'),
          ),
      ],
    ),
  );
}
