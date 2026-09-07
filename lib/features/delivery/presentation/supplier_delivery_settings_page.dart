import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierDeliverySettingsPage extends StatefulWidget {
  const SupplierDeliverySettingsPage({super.key});

  @override
  State<SupplierDeliverySettingsPage> createState() =>
      _SupplierDeliverySettingsPageState();
}

class _SupplierDeliverySettingsPageState
    extends State<SupplierDeliverySettingsPage> {
  static const Color _darkRed = Color(0xFF741C1C);

  final _minimumOrderController = TextEditingController();
  final _leadTimeController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _pickupAvailable = false;
  bool _settingsActive = true;

  String? _supplierBusinessId;
  String? _errorMessage;
  TimeOfDay? _cutoffTime;

  final Set<int> _selectedDeliveryDays = <int>{};
  List<Map<String, dynamic>> _zones = [];

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _minimumOrderController.dispose();
    _leadTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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

      final supplierBusinessId = membership['business_id']?.toString();

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception('Your supplier business could not be identified.');
      }

      final settingsResponse = await Supabase.instance.client
          .from('supplier_delivery_settings')
          .select('''
            id,
            supplier_business_id,
            minimum_order_amount,
            default_lead_time_days,
            order_cutoff_time,
            pickup_available,
            delivery_notes,
            active
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .limit(1);

      final daysResponse = await Supabase.instance.client
          .from('supplier_delivery_days')
          .select('weekday, active')
          .eq('supplier_business_id', supplierBusinessId)
          .order('weekday');

      final zonesResponse = await Supabase.instance.client
          .from('supplier_delivery_zones')
          .select('''
            id,
            supplier_business_id,
            zone_name,
            minimum_order_amount,
            delivery_fee,
            lead_time_days,
            active,
            notes,
            supplier_delivery_zone_postcodes(
              id,
              postcode
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('zone_name');

      if (!mounted) {
        return;
      }

      Map<String, dynamic>? settings;

      if (settingsResponse.isNotEmpty) {
        settings = Map<String, dynamic>.from(settingsResponse.first);
      }

      final selectedDays = <int>{};

      for (final rawDay in daysResponse) {
        final day = Map<String, dynamic>.from(rawDay);

        if (day['active'] == true) {
          final weekday = day['weekday'];

          if (weekday is int) {
            selectedDays.add(weekday);
          }
        }
      }

      setState(() {
        _supplierBusinessId = supplierBusinessId;

        _minimumOrderController.text = _formatEditableNumber(
          settings?['minimum_order_amount'],
        );

        _leadTimeController.text = _formatEditableNumber(
          settings?['default_lead_time_days'] ?? 1,
        );

        _notesController.text = settings?['delivery_notes']?.toString() ?? '';

        _pickupAvailable = settings?['pickup_available'] == true;
        _settingsActive = settings?['active'] != false;

        _cutoffTime = _parseDatabaseTime(
          settings?['order_cutoff_time']?.toString(),
        );

        _selectedDeliveryDays
          ..clear()
          ..addAll(selectedDays);

        _zones = List<Map<String, dynamic>>.from(zonesResponse);

        _isLoading = false;
      });
      await _loadOperations();
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


  int _workspaceIndex = 0;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _runs = [];
  List<Map<String, dynamic>> _readyOrders = [];

  Future<void> _loadOperations() async {
    final supplierBusinessId = _supplierBusinessId;
    if (supplierBusinessId == null) {
      return;
    }
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client.from('supplier_delivery_drivers').select().eq('supplier_business_id', supplierBusinessId).order('active', ascending: false).order('display_name'),
      client.from('supplier_delivery_vehicles').select().eq('supplier_business_id', supplierBusinessId).order('active', ascending: false).order('display_name'),
      client.from('supplier_delivery_runs').select('''
        id, supplier_business_id, run_number, delivery_date, driver_id, vehicle_id,
        status, notes, loaded_at, started_at, completed_at, cancelled_at, created_at,
        supplier_delivery_run_stops(
          id, order_id, stop_sequence, status, customer_name_snapshot,
          contact_name_snapshot, contact_phone_snapshot, address_line_1_snapshot,
          address_line_2_snapshot, suburb_snapshot, state_snapshot, postcode_snapshot,
          delivery_instructions_snapshot, delivered_at, recipient_name, driver_notes,
          failed_at, failed_reason
        )
      ''').eq('supplier_business_id', supplierBusinessId).order('delivery_date', ascending: false).order('created_at', ascending: false).limit(100),
      client.from('orders').select('''
        id, order_number, status, fulfilment_method, confirmed_fulfilment_date,
        requested_fulfilment_date, delivery_notes,
        businesses!orders_butcher_business_id_fkey(trading_name, legal_name),
        supplier_customer_accounts(customer_name, legal_name),
        invoices(id)
      ''').eq('supplier_business_id', supplierBusinessId).inFilter('status', ['processing', 'dispatched']).eq('fulfilment_method', 'delivery').order('confirmed_fulfilment_date'),
    ]);

    if (!mounted) {
      return;
    }
    final activeOrderIds = <String>{};
    final failedOrderIds = <String>{};

    for (final rawRun in results[2] as List) {
      final run = Map<String, dynamic>.from(rawRun as Map);
      final stops = run['supplier_delivery_run_stops'];
      if (stops is List) {
        for (final rawStop in stops.whereType<Map>()) {
          final status = rawStop['status']?.toString();
          final orderId = rawStop['order_id']?.toString();

          if (status == 'pending' ||
              status == 'loaded' ||
              status == 'out_for_delivery') {
            if (orderId != null) {
              activeOrderIds.add(orderId);
            }
          }

          if (status == 'failed' && orderId != null) {
            failedOrderIds.add(orderId);
          }
        }
      }
    }

    setState(() {
      _drivers = List<Map<String, dynamic>>.from(results[0] as List);
      _vehicles = List<Map<String, dynamic>>.from(results[1] as List);
      _runs = List<Map<String, dynamic>>.from(results[2] as List);
      _readyOrders = List<Map<String, dynamic>>.from(
        results[3] as List,
      ).where((order) {
        final invoices = order['invoices'];
        final orderId = order['id']?.toString();
        final status = order['status']?.toString();

        if (invoices is! List ||
            invoices.isEmpty ||
            orderId == null ||
            activeOrderIds.contains(orderId)) {
          return false;
        }

        if (status == 'processing') {
          return true;
        }

        return status == 'dispatched' && failedOrderIds.contains(orderId);
      }).toList();
    });
  }

  bool _isRedeliveryOrder(Map<String, dynamic> order) {
    return order['status']?.toString() == 'dispatched';
  }

  String _customerName(Map<String, dynamic> order) {
    final business = order['businesses'];
    if (business is Map) {
      final trading = business['trading_name']?.toString().trim();
      final legal = business['legal_name']?.toString().trim();
      if (trading != null && trading.isNotEmpty) {
        return trading;
      }
      if (legal != null && legal.isNotEmpty) {
        return legal;
      }
    }
    final account = order['supplier_customer_accounts'];
    if (account is Map) {
      final name = account['customer_name']?.toString().trim();
      final legal = account['legal_name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
      if (legal != null && legal.isNotEmpty) {
        return legal;
      }
    }
    return 'Customer';
  }

  String _driverName(String? id) {
    for (final d in _drivers) {
      if (d['id']?.toString() == id) {
        return d['display_name']?.toString() ?? 'Driver';
      }
    }
    return 'Unassigned';
  }

  String _vehicleName(String? id) {
    for (final v in _vehicles) {
      if (v['id']?.toString() == id) {
        final name = v['display_name']?.toString() ?? 'Vehicle';
        final rego = v['registration']?.toString().trim() ?? '';
        return rego.isEmpty ? name : '$name • $rego';
      }
    }
    return 'Unassigned';
  }

  String _runStatusLabel(String value) {
    switch (value) {
      case 'ready': return 'Ready';
      case 'loaded': return 'Loaded';
      case 'in_progress': return 'Out for Delivery';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return 'Draft';
    }
  }

  Future<void> _refreshAll() async {
    await _loadPage();
    await _loadOperations();
  }

  Future<void> _showDriverDialog([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['display_name']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    var active = existing?['active'] != false;
    final save = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(existing == null ? 'Add Driver' : 'Edit Driver'),
      content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Driver name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: active, title: const Text('Active'), onChanged: (v) => setDialogState(() => active = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
    )));
    if (save == true && name.text.trim().isNotEmpty) {
      final data = {'supplier_business_id': _supplierBusinessId, 'display_name': name.text.trim(), 'phone': phone.text.trim().isEmpty ? null : phone.text.trim(), 'notes': notes.text.trim().isEmpty ? null : notes.text.trim(), 'active': active};
      if (existing == null) {
        await Supabase.instance.client.from('supplier_delivery_drivers').insert(data);
      } else {
        await Supabase.instance.client.from('supplier_delivery_drivers').update(data).eq('id', existing['id']);
      }
      await _loadOperations();
    }
    name.dispose(); phone.dispose(); notes.dispose();
  }

  Future<void> _showVehicleDialog([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['display_name']?.toString() ?? '');
    final rego = TextEditingController(text: existing?['registration']?.toString() ?? '');
    final type = TextEditingController(text: existing?['vehicle_type']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    var active = existing?['active'] != false;
    final save = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(existing == null ? 'Add Vehicle' : 'Edit Vehicle'),
      content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Vehicle name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: rego, decoration: const InputDecoration(labelText: 'Registration', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: type, decoration: const InputDecoration(labelText: 'Vehicle type', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: active, title: const Text('Active'), onChanged: (v) => setDialogState(() => active = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
    )));
    if (save == true && name.text.trim().isNotEmpty) {
      final data = {'supplier_business_id': _supplierBusinessId, 'display_name': name.text.trim(), 'registration': rego.text.trim().isEmpty ? null : rego.text.trim(), 'vehicle_type': type.text.trim().isEmpty ? null : type.text.trim(), 'active': active, 'notes': notes.text.trim().isEmpty ? null : notes.text.trim()};
      if (existing == null) {
        await Supabase.instance.client.from('supplier_delivery_vehicles').insert(data);
      } else {
        await Supabase.instance.client.from('supplier_delivery_vehicles').update(data).eq('id', existing['id']);
      }
      await _loadOperations();
    }
    name.dispose(); rego.dispose(); type.dispose(); notes.dispose();
  }

  Future<void> _showCreateRunDialog() async {
    if (_readyOrders.isEmpty) { _showMessage('There are no invoiced delivery orders ready for dispatch or redelivery.'); return; }
    DateTime deliveryDate = DateTime.now();
    String? driverId;
    for (final d in _drivers) { if (d['active'] == true && d['id'] != null) { driverId = d['id'].toString(); break; } }
    String? vehicleId;
    for (final v in _vehicles) { if (v['active'] == true && v['id'] != null) { vehicleId = v['id'].toString(); break; } }
    final selected = <String>{};
    final create = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Create Delivery Run'),
      content: SizedBox(width: 720, height: 560, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () async { final picked = await showDatePicker(context: dialogContext, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: deliveryDate); if (picked != null) {
                            setDialogState(() => deliveryDate = picked);
                          } }, icon: const Icon(Icons.calendar_today_outlined), label: Text('${deliveryDate.day}/${deliveryDate.month}/${deliveryDate.year}'))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(initialValue: driverId, decoration: const InputDecoration(labelText: 'Driver', border: OutlineInputBorder()), items: _drivers.where((d) => d['active'] == true).map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['display_name']?.toString() ?? 'Driver'))).toList(), onChanged: (v) => setDialogState(() => driverId = v))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(initialValue: vehicleId, decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()), items: _vehicles.where((v) => v['active'] == true).map((v) => DropdownMenuItem(value: v['id'].toString(), child: Text(v['display_name']?.toString() ?? 'Vehicle'))).toList(), onChanged: (v) => setDialogState(() => vehicleId = v))),
        ]),
        const SizedBox(height: 16),
        const Text('Orders ready for dispatch', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _readyOrders.length,
            itemBuilder: (context, index) {
              final order = _readyOrders[index];
              final id = order['id'].toString();
              final redelivery = _isRedeliveryOrder(order);

              return CheckboxListTile(
                value: selected.contains(id),
                onChanged: (v) => setDialogState(() {
                  if (v == true) {
                    selected.add(id);
                  } else {
                    selected.remove(id);
                  }
                }),
                title: Text(order['order_number']?.toString() ?? 'Order'),
                subtitle: Text(
                  redelivery
                      ? '${_customerName(order)} • Redelivery required'
                      : _customerName(order),
                ),
                secondary: redelivery
                    ? const Icon(
                        Icons.replay_rounded,
                        color: Color(0xFFB85C00),
                      )
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(dialogContext, true), child: const Text('Create Run'))],
    )));
    if (create == true) {
      await Supabase.instance.client.rpc('create_supplier_delivery_run', params: {
        'p_delivery_date': '${deliveryDate.year}-${deliveryDate.month.toString().padLeft(2, '0')}-${deliveryDate.day.toString().padLeft(2, '0')}',
        'p_driver_id': driverId, 'p_vehicle_id': vehicleId, 'p_order_ids': selected.toList(), 'p_notes': null,
      });
      _showMessage('Delivery run created.');
      await _loadOperations();
    }
  }

  Future<void> _runAction(String rpc, String runId, String message) async {
    try { await Supabase.instance.client.rpc(rpc, params: {'p_run_id': runId}); _showMessage(message); await _loadOperations(); }
    on PostgrestException catch (e) { _showMessage(e.message); }
  }

  Future<void> _completeStop(Map<String, dynamic> stop) async {
    final recipient = TextEditingController(); final notes = TextEditingController();
    final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm Delivery'),
      content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: recipient, decoration: const InputDecoration(labelText: 'Received by', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Driver notes', border: OutlineInputBorder())),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delivered'))],
    ));
    if (confirm == true) {
      await Supabase.instance.client.rpc('complete_supplier_delivery_stop', params: {'p_stop_id': stop['id'], 'p_recipient_name': recipient.text.trim().isEmpty ? null : recipient.text.trim(), 'p_driver_notes': notes.text.trim().isEmpty ? null : notes.text.trim(), 'p_proof_reference': null});
      await _loadOperations();
    }
    recipient.dispose(); notes.dispose();
  }

  Future<void> _failStop(Map<String, dynamic> stop) async {
    final reason = TextEditingController();
    final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Failed Delivery'),
      content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save Failed Delivery'))],
    ));
    if (confirm == true && reason.text.trim().isNotEmpty) {
      await Supabase.instance.client.rpc('fail_supplier_delivery_stop', params: {'p_stop_id': stop['id'], 'p_failed_reason': reason.text.trim(), 'p_driver_notes': null});
      await _loadOperations();
    }
    reason.dispose();
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE3E5E8))), child: Row(children: [Icon(icon, color: _darkRed), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFF6D7177), fontSize: 11.5, fontWeight: FontWeight.w700))])])));
  }

  Widget _buildOverview() {
    final inProgress = _runs.where((r) => r['status'] == 'in_progress').length;
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayRuns = _runs.where((r) => r['delivery_date']?.toString() == todayKey).length;
    var delivered = 0;
    for (final r in _runs) {
      final stops = r['supplier_delivery_run_stops'];
      if (stops is List) {
        delivered += stops
            .whereType<Map>()
            .where((s) => s['status'] == 'delivered')
            .length;
      }
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [_metricCard('Ready to Dispatch', '${_readyOrders.length}', Icons.inventory_2_outlined), const SizedBox(width: 12), _metricCard("Today's Runs", '$todayRuns', Icons.route_outlined), const SizedBox(width: 12), _metricCard('Out for Delivery', '$inProgress', Icons.local_shipping_outlined), const SizedBox(width: 12), _metricCard('Delivered', '$delivered', Icons.check_circle_outline)]),
      const SizedBox(height: 18),
      _sectionCard(title: 'Delivery Operations', subtitle: 'Create delivery runs from invoiced orders that are ready to leave the warehouse.', child: Row(children: [FilledButton.icon(onPressed: _showCreateRunDialog, icon: const Icon(Icons.add_road), label: const Text('Create Delivery Run')), const SizedBox(width: 12), OutlinedButton.icon(onPressed: _refreshAll, icon: const Icon(Icons.refresh), label: const Text('Refresh'))])),
      const SizedBox(height: 18),
      _buildRuns(compact: true),
    ]);
  }

  Widget _buildRuns({bool compact = false}) {
    final runs = compact ? _runs.take(8).toList() : _runs;
    if (runs.isEmpty) {
      return _sectionCard(
        title: 'Delivery Runs',
        subtitle: 'No delivery runs have been created yet.',
        child: const Text(
          'Create your first run when orders are ready for dispatch.',
        ),
      );
    }
    return Column(children: runs.map((run) {
      final stopsRaw = run['supplier_delivery_run_stops'];
      final stops = stopsRaw is List ? stopsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      stops.sort((a, b) => ((a['stop_sequence'] as num?)?.toInt() ?? 0).compareTo((b['stop_sequence'] as num?)?.toInt() ?? 0));
      final status = run['status']?.toString() ?? 'draft';
      return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE3E5E8)), borderRadius: BorderRadius.circular(14)), child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Row(children: [Expanded(child: Text(run['run_number']?.toString() ?? 'Delivery Run', style: const TextStyle(fontWeight: FontWeight.w900))), Text(_runStatusLabel(status), style: const TextStyle(fontWeight: FontWeight.w800, color: _darkRed))]),
        subtitle: Text('${run['delivery_date'] ?? ''} • ${_driverName(run['driver_id']?.toString())} • ${_vehicleName(run['vehicle_id']?.toString())} • ${stops.length} stop${stops.length == 1 ? '' : 's'}'),
        children: [
          if (status == 'ready' || status == 'loaded') Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Wrap(spacing: 8, children: [
            if (status == 'ready') FilledButton.icon(onPressed: () => _runAction('mark_supplier_delivery_run_loaded', run['id'].toString(), 'Delivery run marked loaded.'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Mark Loaded')),
            if (status == 'loaded') FilledButton.icon(onPressed: () => _runAction('start_supplier_delivery_run', run['id'].toString(), 'Delivery run started.'), icon: const Icon(Icons.local_shipping_outlined), label: const Text('Start Run')),
            OutlinedButton(onPressed: () => _runAction('cancel_supplier_delivery_run', run['id'].toString(), 'Delivery run cancelled.'), child: const Text('Cancel Run')),
          ])),
          for (final stop in stops) ListTile(
            leading: CircleAvatar(radius: 16, child: Text('${stop['stop_sequence'] ?? ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
            title: Text(stop['customer_name_snapshot']?.toString() ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text([stop['address_line_1_snapshot'], stop['suburb_snapshot'], stop['postcode_snapshot']].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ')),
            trailing: stop['status'] == 'out_for_delivery' ? Wrap(spacing: 6, children: [FilledButton(onPressed: () => _completeStop(stop), child: const Text('Delivered')), OutlinedButton(onPressed: () => _failStop(stop), child: const Text('Failed'))]) : Text(stop['status']?.toString().replaceAll('_', ' ') ?? ''),
          ),
          if (status == 'in_progress' && stops.every((s) => s['status'] == 'delivered' || s['status'] == 'failed' || s['status'] == 'cancelled')) Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _runAction('complete_supplier_delivery_run', run['id'].toString(), 'Delivery run completed.'), icon: const Icon(Icons.check_circle_outline), label: const Text('Complete Run')))),
        ],
      ));
    }).toList());
  }

  Widget _buildDriversVehicles() {
    return ListView(padding: const EdgeInsets.all(20), children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _sectionCard(title: 'Drivers', subtitle: 'Manage your supplier delivery drivers.', child: Column(children: [Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _showDriverDialog(), icon: const Icon(Icons.person_add_alt), label: const Text('Add Driver'))), const SizedBox(height: 10), for (final driver in _drivers) ListTile(leading: const Icon(Icons.badge_outlined, color: _darkRed), title: Text(driver['display_name']?.toString() ?? 'Driver'), subtitle: Text(driver['phone']?.toString() ?? ''), trailing: IconButton(onPressed: () => _showDriverDialog(driver), icon: const Icon(Icons.edit_outlined))) ]))),
      const SizedBox(width: 16),
      Expanded(child: _sectionCard(title: 'Vehicles', subtitle: 'Manage delivery trucks and vehicles.', child: Column(children: [Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _showVehicleDialog(), icon: const Icon(Icons.add), label: const Text('Add Vehicle'))), const SizedBox(height: 10), for (final vehicle in _vehicles) ListTile(leading: const Icon(Icons.local_shipping_outlined, color: _darkRed), title: Text(vehicle['display_name']?.toString() ?? 'Vehicle'), subtitle: Text([vehicle['registration'], vehicle['vehicle_type']].where((e) => e != null && e.toString().trim().isNotEmpty).join(' • ')), trailing: IconButton(onPressed: () => _showVehicleDialog(vehicle), icon: const Icon(Icons.edit_outlined))) ]))),
    ])]);
  }

  Widget _workspaceShell() {
    final pages = <Widget>[
      _buildOverview(),
      ListView(padding: const EdgeInsets.all(20), children: [Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _showCreateRunDialog, icon: const Icon(Icons.add_road), label: const Text('Create Delivery Run'))), const SizedBox(height: 14), _buildRuns()]),
      _buildDriversVehicles(),
      ListView(padding: const EdgeInsets.all(20), children: [
        _sectionCard(title: 'Delivery Days', subtitle: 'Choose the days your business normally delivers.', child: _buildDeliveryDays()),
        const SizedBox(height: 16),
        _sectionCard(title: 'Delivery Zones', subtitle: 'Manage delivery areas, postcodes, minimums, fees and lead times.', child: Column(children: [Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _showZoneDialog(), icon: const Icon(Icons.add), label: const Text('Add Delivery Zone'))), const SizedBox(height: 12), _buildZones()])),
      ]),
      ListView(padding: const EdgeInsets.all(20), children: [
        _sectionCard(title: 'General Delivery Rules', subtitle: 'Manage your delivery minimum, lead time, cutoff, pickup availability and customer-facing notes.', child: Column(children: [
          TextField(controller: _minimumOrderController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Default minimum order value for delivery (inc GST)', prefixText: '\$', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: _leadTimeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default lead time (days)', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          InkWell(onTap: _pickCutoffTime, child: InputDecorator(decoration: const InputDecoration(labelText: 'Order cut-off time', border: OutlineInputBorder(), suffixIcon: Icon(Icons.schedule)), child: Text(_cutoffTime == null ? 'No cut-off time set' : _cutoffTime!.format(context)))),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _pickupAvailable, title: const Text('Pickup available'), onChanged: (v) => setState(() => _pickupAvailable = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _settingsActive, title: const Text('Delivery settings active'), onChanged: (v) => setState(() => _settingsActive = v)),
          TextField(controller: _notesController, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Delivery notes', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _isSaving ? null : _saveSettings, icon: const Icon(Icons.save_outlined), label: Text(_isSaving ? 'Saving...' : 'Save Delivery Settings'))),
        ])),
      ]),
    ];
    const labels = ['Overview', 'Delivery Runs', 'Drivers & Vehicles', 'Areas & Schedule', 'Settings'];
    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Column(children: [
        Row(children: [const Icon(Icons.local_shipping_outlined, color: _darkRed, size: 24), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Delivery Operations', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text('Manage supplier drivers, vehicles, delivery runs, areas and schedules.', style: TextStyle(color: Color(0xFF6D7177), fontSize: 11.5))])), IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh))]),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 4, children: List.generate(labels.length, (i) => ChoiceChip(label: Text(labels[i]), selected: _workspaceIndex == i, onSelected: (_) => setState(() => _workspaceIndex = i))))),
        const SizedBox(height: 10),
      ])),
      const Divider(height: 1),
      Expanded(child: pages[_workspaceIndex]),
    ]);
  }

  String _formatEditableNumber(dynamic value) {
    if (value == null) {
      return '';
    }

    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatMoney(dynamic value) {
    if (value == null) {
      return 'Not set';
    }

    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return '\$${number.toStringAsFixed(2)}';
  }

  TimeOfDay? _parseDatabaseTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parts = value.split(':');

    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _databaseTime(TimeOfDay? value) {
    if (value == null) {
      return null;
    }

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute:00';
  }

  double? _optionalDouble(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return double.tryParse(trimmed);
  }

  int? _optionalInt(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return int.tryParse(trimmed);
  }

  Future<void> _pickCutoffTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _cutoffTime ?? const TimeOfDay(hour: 14, minute: 0),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _cutoffTime = selected;
    });
  }

  Future<void> _saveSettings() async {
    if (_isSaving) {
      return;
    }

    final supplierBusinessId = _supplierBusinessId;

    if (supplierBusinessId == null) {
      _showMessage('Your supplier business could not be identified.');
      return;
    }

    final minimumOrder = _optionalDouble(_minimumOrderController.text);

    if (_minimumOrderController.text.trim().isNotEmpty &&
        minimumOrder == null) {
      _showMessage('Enter a valid minimum order value for delivery.');
      return;
    }

    if (minimumOrder != null && minimumOrder < 0) {
      _showMessage('Minimum order value for delivery cannot be negative.');
      return;
    }

    final leadTime = int.tryParse(_leadTimeController.text.trim());

    if (leadTime == null || leadTime < 0 || leadTime > 60) {
      _showMessage('Default lead time must be between 0 and 60 days.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final client = Supabase.instance.client;

      await client.from('supplier_delivery_settings').upsert({
        'supplier_business_id': supplierBusinessId,
        'minimum_order_amount': minimumOrder,
        'default_lead_time_days': leadTime,
        'order_cutoff_time': _databaseTime(_cutoffTime),
        'pickup_available': _pickupAvailable,
        'delivery_notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'active': _settingsActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'supplier_business_id');

      for (var weekday = 1; weekday <= 7; weekday++) {
        await client.from('supplier_delivery_days').upsert({
          'supplier_business_id': supplierBusinessId,
          'weekday': weekday,
          'active': _selectedDeliveryDays.contains(weekday),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'supplier_business_id,weekday');
      }

      if (!mounted) {
        return;
      }

      _showMessage('Delivery settings saved.');

      await _loadPage();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to save delivery settings: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> _zonePostcodes(Map<String, dynamic> zone) {
    final raw = zone['supplier_delivery_zone_postcodes'];

    if (raw is! List) {
      return [];
    }

    final postcodes = raw
        .whereType<Map>()
        .map((item) => item['postcode']?.toString().trim())
        .whereType<String>()
        .where((postcode) => postcode.isNotEmpty)
        .toSet()
        .toList();

    postcodes.sort();

    return postcodes;
  }

  List<String>? _parsePostcodes(String rawText) {
    final rawParts = rawText
        .split(RegExp(r'[\s,;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final unique = <String>{};

    for (final postcode in rawParts) {
      if (!RegExp(r'^\d{4}$').hasMatch(postcode)) {
        return null;
      }

      unique.add(postcode);
    }

    final result = unique.toList()..sort();

    return result;
  }

  Future<void> _replaceZonePostcodes({
    required String zoneId,
    required List<String> postcodes,
  }) async {
    final client = Supabase.instance.client;

    await client
        .from('supplier_delivery_zone_postcodes')
        .delete()
        .eq('delivery_zone_id', zoneId);

    if (postcodes.isEmpty) {
      return;
    }

    await client
        .from('supplier_delivery_zone_postcodes')
        .insert(
          postcodes
              .map(
                (postcode) => {
                  'delivery_zone_id': zoneId,
                  'postcode': postcode,
                },
              )
              .toList(),
        );
  }

  Future<void> _showZoneDialog({Map<String, dynamic>? zone}) async {
    final nameController = TextEditingController(
      text: zone?['zone_name']?.toString() ?? '',
    );
    final minimumController = TextEditingController(
      text: _formatEditableNumber(zone?['minimum_order_amount']),
    );
    final feeController = TextEditingController(
      text: _formatEditableNumber(zone?['delivery_fee']),
    );
    final leadController = TextEditingController(
      text: _formatEditableNumber(zone?['lead_time_days']),
    );
    final notesController = TextEditingController(
      text: zone?['notes']?.toString() ?? '',
    );
    final postcodeController = TextEditingController(
      text: zone == null ? '' : _zonePostcodes(zone).join(', '),
    );

    var active = zone?['active'] != false;
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveZone() async {
                if (saving) {
                  return;
                }

                final supplierBusinessId = _supplierBusinessId;

                if (supplierBusinessId == null) {
                  return;
                }

                final zoneName = nameController.text.trim();

                if (zoneName.isEmpty) {
                  _showMessage('Enter a delivery zone name.');
                  return;
                }

                final minimum = _optionalDouble(minimumController.text);
                final fee = _optionalDouble(feeController.text);
                final lead = _optionalInt(leadController.text);
                final postcodes = _parsePostcodes(postcodeController.text);

                if (postcodes == null) {
                  _showMessage('Every postcode must contain exactly 4 digits.');
                  return;
                }

                if (minimumController.text.trim().isNotEmpty &&
                    minimum == null) {
                  _showMessage(
                    'Enter a valid minimum order value for this delivery zone.',
                  );
                  return;
                }

                if (feeController.text.trim().isNotEmpty && fee == null) {
                  _showMessage('Enter a valid delivery fee.');
                  return;
                }

                if (leadController.text.trim().isNotEmpty && lead == null) {
                  _showMessage('Enter a valid lead time.');
                  return;
                }

                if (minimum != null && minimum < 0) {
                  _showMessage(
                    'Minimum order value for delivery cannot be negative.',
                  );
                  return;
                }

                if (fee != null && fee < 0) {
                  _showMessage('Delivery fee cannot be negative.');
                  return;
                }

                if (lead != null && (lead < 0 || lead > 60)) {
                  _showMessage('Zone lead time must be between 0 and 60 days.');
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                try {
                  final payload = {
                    'supplier_business_id': supplierBusinessId,
                    'zone_name': zoneName,
                    'minimum_order_amount': minimum,
                    'delivery_fee': fee,
                    'lead_time_days': lead,
                    'active': active,
                    'notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  };

                  late String savedZoneId;

                  if (zone == null) {
                    final insertedZone = await Supabase.instance.client
                        .from('supplier_delivery_zones')
                        .insert(payload)
                        .select('id')
                        .single();

                    savedZoneId = insertedZone['id'].toString();
                  } else {
                    savedZoneId = zone['id'].toString();

                    await Supabase.instance.client
                        .from('supplier_delivery_zones')
                        .update(payload)
                        .eq('id', savedZoneId);
                  }

                  await _replaceZonePostcodes(
                    zoneId: savedZoneId,
                    postcodes: postcodes,
                  );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  await _loadPage();

                  if (mounted) {
                    _showMessage(
                      zone == null
                          ? 'Delivery zone added.'
                          : 'Delivery zone updated.',
                    );
                  }
                } on PostgrestException catch (error) {
                  if (mounted) {
                    _showMessage(error.message);
                  }

                  setDialogState(() {
                    saving = false;
                  });
                }
              }

              return AlertDialog(
                title: Text(
                  zone == null ? 'Add Delivery Zone' : 'Edit Delivery Zone',
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Zone name',
                            hintText: 'Example: Sydney Metro',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: minimumController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText:
                                'Minimum order value for delivery (inc GST)',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: feeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Delivery fee (inc GST)',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: leadController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Lead time in days',
                            hintText:
                                'Leave blank to use the default lead time',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: postcodeController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Postcodes',
                            hintText: 'Example: 2164, 2165, 2166, 2170',
                            helperText:
                                'Separate postcodes with commas, spaces or new lines.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Zone notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          title: const Text('Zone active'),
                          onChanged: saving
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    active = value;
                                  });
                                },
                        ),
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
                  FilledButton(
                    onPressed: saving ? null : saveZone,
                    style: FilledButton.styleFrom(backgroundColor: _darkRed),
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(zone == null ? 'Add Zone' : 'Save Changes'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      minimumController.dispose();
      feeController.dispose();
      leadController.dispose();
      notesController.dispose();
      postcodeController.dispose();
    }
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Delivery Zone?'),
          content: Text('Delete "${zone['zone_name'] ?? 'this zone'}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              child: const Text('Delete'),
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
          .from('supplier_delivery_zones')
          .delete()
          .eq('id', zone['id']);

      if (!mounted) {
        return;
      }

      _showMessage('Delivery zone deleted.');
      await _loadPage();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF666666), height: 1.4),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDays() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(7, (index) {
        final weekday = index + 1;
        final selected = _selectedDeliveryDays.contains(weekday);

        return FilterChip(
          selected: selected,
          label: Text(_weekdayNames[index]),
          selectedColor: const Color(0xFFF4E5E5),
          checkmarkColor: _darkRed,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedDeliveryDays.add(weekday);
              } else {
                _selectedDeliveryDays.remove(weekday);
              }
            });
          },
        );
      }),
    );
  }

  Widget finalPostcodesWidget(Map<String, dynamic> zone) {
    final postcodes = _zonePostcodes(zone);

    if (postcodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Postcodes: None',
          style: TextStyle(
            color: Color(0xFF9A6700),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final preview = postcodes.length <= 8
        ? postcodes.join(', ')
        : '${postcodes.take(8).join(', ')} +${postcodes.length - 8} more';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Postcodes: $preview',
        style: const TextStyle(
          color: Color(0xFF555555),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildZones() {
    if (_zones.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1DE)),
        ),
        child: const Text(
          'No delivery zones have been added yet.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    return Column(
      children: [
        for (final zone in _zones) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  zone['active'] == true
                      ? Icons.local_shipping_outlined
                      : Icons.pause_circle_outline,
                  color: zone['active'] == true
                      ? _darkRed
                      : const Color(0xFF888888),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone['zone_name']?.toString() ?? 'Unnamed zone',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Delivery minimum: ${_formatMoney(zone['minimum_order_amount'])} inc GST',
                          ),
                          Text(
                            'Fee: ${_formatMoney(zone['delivery_fee'])} inc GST',
                          ),
                          Text(
                            zone['lead_time_days'] == null
                                ? 'Lead time: Default'
                                : 'Lead time: ${zone['lead_time_days']} day${zone['lead_time_days'] == 1 ? '' : 's'}',
                          ),
                          Text(zone['active'] == true ? 'Active' : 'Inactive'),
                        ],
                      ),
                      finalPostcodesWidget(zone),
                      if (zone['notes'] != null &&
                          zone['notes'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          zone['notes'].toString(),
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showZoneDialog(zone: zone);
                    } else if (value == 'delete') {
                      _deleteZone(zone);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 56, color: _darkRed),
                        const SizedBox(height: 14),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _refreshAll, child: const Text('Try Again')),
                      ],
                    ),
                  ),
                )
              : _workspaceShell(),
    );
  }

}
