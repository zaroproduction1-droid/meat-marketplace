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
            notes
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
      _showMessage('Enter a valid minimum order amount.');
      return;
    }

    if (minimumOrder != null && minimumOrder < 0) {
      _showMessage('Minimum order cannot be negative.');
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

                if (minimumController.text.trim().isNotEmpty &&
                    minimum == null) {
                  _showMessage('Enter a valid zone minimum order.');
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
                  _showMessage('Minimum order cannot be negative.');
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

                  if (zone == null) {
                    await Supabase.instance.client
                        .from('supplier_delivery_zones')
                        .insert(payload);
                  } else {
                    await Supabase.instance.client
                        .from('supplier_delivery_zones')
                        .update(payload)
                        .eq('id', zone['id']);
                  }

                  if (!dialogContext.mounted) {
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
                            labelText: 'Minimum order for this zone',
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
                            labelText: 'Delivery fee',
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
                            'Minimum: ${_formatMoney(zone['minimum_order_amount'])}',
                          ),
                          Text('Fee: ${_formatMoney(zone['delivery_fee'])}'),
                          Text(
                            zone['lead_time_days'] == null
                                ? 'Lead time: Default'
                                : 'Lead time: ${zone['lead_time_days']} day${zone['lead_time_days'] == 1 ? '' : 's'}',
                          ),
                          Text(zone['active'] == true ? 'Active' : 'Inactive'),
                        ],
                      ),
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
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Delivery Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPage,
            tooltip: 'Refresh',
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
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 18),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    Widget generalPanel() {
      return _sectionCard(
        title: 'General Delivery Rules',
        subtitle:
            'Minimum order, lead time, cut-off time, pickup and delivery availability.',
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minimumOrderController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Default minimum order',
                      prefixText: r'$',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _leadTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Lead time (days)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _pickCutoffTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Order cut-off time',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.schedule),
                  isDense: true,
                ),
                child: Text(
                  _cutoffTime == null
                      ? 'No cut-off time set'
                      : _cutoffTime!.format(context),
                ),
              ),
            ),
            if (_cutoffTime != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _cutoffTime = null),
                  child: const Text('Clear cut-off'),
                ),
              ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _pickupAvailable,
              title: const Text('Pickup available'),
              onChanged: (value) => setState(() => _pickupAvailable = value),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _settingsActive,
              title: const Text('Delivery settings active'),
              onChanged: (value) => setState(() => _settingsActive = value),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Delivery notes',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      );
    }

    Widget daysPanel() {
      return _sectionCard(
        title: 'Delivery Days',
        subtitle: 'Choose the normal delivery days for your business.',
        child: _buildDeliveryDays(),
      );
    }

    Widget zonesPanel() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 10, 9),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Zones',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Minimum order, fee and lead time by area.',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showZoneDialog(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Add Zone'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: _buildZones(),
              ),
            ),
          ],
        ),
      );
    }

    final saveButton = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveSettings,
        style: FilledButton.styleFrom(
          backgroundColor: _darkRed,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(_isSaving ? 'Saving...' : 'Save Delivery Settings'),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;

        if (!desktop) {
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              generalPanel(),
              const SizedBox(height: 10),
              daysPanel(),
              const SizedBox(height: 10),
              SizedBox(height: 430, child: zonesPanel()),
              const SizedBox(height: 10),
              saveButton,
            ],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                generalPanel(),
                                const SizedBox(height: 10),
                                daysPanel(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: zonesPanel()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  saveButton,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
