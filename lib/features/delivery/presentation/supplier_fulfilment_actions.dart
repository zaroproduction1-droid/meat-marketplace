import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierFulfilmentActions extends StatefulWidget {
  const SupplierFulfilmentActions({
    super.key,
    required this.orderId,
    required this.supplierId,
    required this.order,
    required this.onChanged,
  });
  final String orderId;
  final String supplierId;
  final Map<String, dynamic> order;
  final Future<void> Function() onChanged;
  @override
  State<SupplierFulfilmentActions> createState() =>
      _SupplierFulfilmentActionsState();
}

class _SupplierFulfilmentActionsState extends State<SupplierFulfilmentActions> {
  bool _busy = false;
  Future<void> _advance(String action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      String? driverId;
      if (action == 'dispatch' &&
          widget.order['assigned_delivery_driver_id'] == null) {
        final drivers = await Supabase.instance.client
            .from('supplier_delivery_drivers')
            .select('id,display_name')
            .eq('supplier_business_id', widget.supplierId)
            .eq('active', true)
            .order('display_name');
        if (!mounted) {
          return;
        }
        if (drivers.isEmpty) {
          throw StateError(
            'No active drivers. Add one in Delivery → Drivers & Vehicles.',
          );
        }
        driverId = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Choose delivery driver'),
            children: [
              for (final driver in drivers)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.pop(context, driver['id'].toString()),
                  child: Text(driver['display_name']?.toString() ?? 'Driver'),
                ),
            ],
          ),
        );
        if (driverId == null) {
          return;
        }
      }
      if (!mounted) {
        return;
      }
      if (action == 'complete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              widget.order['fulfilment_method'] == 'pickup'
                  ? 'Confirm collected?'
                  : 'Confirm delivered?',
            ),
            content: const Text(
              'Confirm the customer has received the goods. This completes the order.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Complete order'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
      }
      await Supabase.instance.client.rpc(
        'advance_supplier_invoiced_order',
        params: {
          'p_order_id': widget.orderId,
          'p_action': action,
          'p_driver_id': driverId,
        },
      );
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update fulfilment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order['status']?.toString() ?? '';
    if (status == 'cancelled') {
      return const SizedBox.shrink();
    }
    final pickup = widget.order['fulfilment_method'] == 'pickup';
    final delivery = widget.order['fulfilment_method'] == 'delivery';
    final complete = status == 'completed';
    final ready = widget.order['ready_for_pickup_at'] != null;
    final dispatched = [
      'dispatched',
      'delivered',
      'completed',
    ].contains(status);
    final canStart = ['accepted', 'processing'].contains(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Fulfilment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Completed'
                : pickup
                ? (ready ? 'Ready for pickup' : 'Preparing for pickup')
                : (dispatched
                      ? 'Out for delivery / delivered'
                      : 'Preparing delivery'),
          ),
          const SizedBox(height: 8),
          if (!complete && canStart && (delivery || (pickup && !ready)))
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _advance(pickup ? 'ready' : 'dispatch'),
              icon: Icon(
                pickup
                    ? Icons.storefront_outlined
                    : Icons.local_shipping_outlined,
              ),
              label: Text(
                _busy
                    ? 'Updating…'
                    : pickup
                    ? 'Ready for pickup'
                    : 'Out for delivery',
              ),
            ),
          if (!complete && ((pickup && ready) || (delivery && dispatched)))
            FilledButton.icon(
              onPressed: _busy ? null : () => _advance('complete'),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                _busy
                    ? 'Updating…'
                    : pickup
                    ? 'Picked up / complete'
                    : 'Delivered / complete',
              ),
            ),
        ],
      ),
    );
  }
}
