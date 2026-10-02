import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/customer_account_rules.dart';

class SupplierCustomerProfileDialog extends StatefulWidget {
  const SupplierCustomerProfileDialog({
    super.key,
    required this.supplierBusinessId,
    this.account,
  });
  final String supplierBusinessId;
  final Map<String, dynamic>? account;

  @override
  State<SupplierCustomerProfileDialog> createState() =>
      _SupplierCustomerProfileDialogState();
}

class _SupplierCustomerProfileDialogState
    extends State<SupplierCustomerProfileDialog> {
  static const _red = Color(0xFF741C1C);
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _locations = <_ProfileLocation>[];
  int _defaultLocation = 0;
  int _tab = 0;
  late String _payment;
  late bool _hold;
  late bool _requirePo;
  bool _loading = false;
  String? _contextError;
  Map<String, dynamic>? _credit;
  Map<String, double>? _ageing;
  List<Map<String, dynamic>> _history = [];

  static const _names = {
    'customer_name': 'Business name',
    'legal_name': 'Legal name',
    'abn': 'ABN',
    'licence_number': 'Licence number',
    'contact_name': 'Contact name',
    'email': 'Order / invoice email',
    'statement_email': 'Statement email',
    'phone': 'Phone',
    'website': 'Website',
    'account_reference': 'Account reference',
    'payment_terms_days': 'Account terms (days)',
    'credit_limit': 'Credit limit (AUD)',
    'issue_reporting_window_hours': 'Issue reporting window (hours)',
    'billing_address_line_1': 'Address line 1',
    'billing_address_line_2': 'Address line 2',
    'billing_suburb': 'Suburb',
    'billing_state': 'State',
    'billing_postcode': 'Postcode',
    'internal_account_notes': 'Supplier-only account notes',
  };

  @override
  void initState() {
    super.initState();
    final a = widget.account ?? {};
    for (final key in _names.keys) {
      final fallback = key == 'payment_terms_days'
          ? '0'
          : key == 'issue_reporting_window_hours'
          ? '24'
          : key == 'billing_state'
          ? 'NSW'
          : '';
      _fields[key] = TextEditingController(
        text: a[key]?.toString() ?? fallback,
      );
    }
    _payment = a['payment_method']?.toString() ?? 'cod';
    _hold = a['account_hold'] == true;
    _requirePo = a['require_purchase_order'] == true;
    final saved = a['delivery_locations'];
    if (saved is List && saved.isNotEmpty) {
      for (final item in saved) {
        final row = Map<String, dynamic>.from(item as Map);
        if (row['is_default'] == true) {
          _defaultLocation = _locations.length;
        }
        _locations.add(_ProfileLocation(row));
      }
    } else {
      _locations.add(
        _ProfileLocation({
          'label': 'Main delivery address',
          'contact_name': a['delivery_contact_name'] ?? a['contact_name'],
          'phone': a['delivery_contact_phone'] ?? a['phone'],
          'address_line_1': a['delivery_address_line_1'],
          'address_line_2': a['delivery_address_line_2'],
          'suburb': a['delivery_suburb'],
          'state': a['delivery_state'] ?? 'NSW',
          'postcode': a['delivery_postcode'],
          'instructions': a['delivery_instructions'],
        }),
      );
    }
    if (a['id'] != null) {
      _loadContext();
    }
  }

  Future<void> _loadContext() async {
    setState(() {
      _loading = true;
      _contextError = null;
    });
    try {
      final client = Supabase.instance.client;
      final id = widget.account!['id'];
      final data = await Future.wait<dynamic>([
        client.rpc(
          'check_supplier_customer_credit_limit',
          params: {
            'target_supplier_customer_account_id': id,
            'proposed_amount': 0,
          },
        ),
        client
            .from('supplier_customer_account_events')
            .select()
            .eq('supplier_business_id', widget.supplierBusinessId)
            .eq('account_id', id)
            .order('created_at', ascending: false)
            .limit(100),
      ]);
      var query = client
          .from('invoices')
          .select('status,outstanding_amount,due_date')
          .eq('supplier_business_id', widget.supplierBusinessId);
      final butcher = widget.account!['linked_butcher_business_id'];
      query = butcher == null
          ? query.eq('supplier_customer_account_id', id)
          : query.or(
              'supplier_customer_account_id.eq.$id,butcher_business_id.eq.$butcher',
            );
      final invoices = await query.inFilter('status', ['issued', 'part_paid']);
      if (!mounted) {
        return;
      }
      setState(() {
        final credit = data[0] as List;
        _credit = credit.isEmpty
            ? null
            : Map<String, dynamic>.from(credit.first as Map);
        _history = List<Map<String, dynamic>>.from(data[1] as List);
        _ageing = CustomerAccountRules.ageing(
          List<Map<String, dynamic>>.from(invoices),
          DateTime.now(),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _contextError = 'Account summary or history could not load. $error';
      });
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    for (final location in _locations) {
      location.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, {int lines = 1}) => TextFormField(
    controller: _fields[key],
    maxLines: lines,
    keyboardType: key.contains('email')
        ? TextInputType.emailAddress
        : [
            'credit_limit',
            'payment_terms_days',
            'issue_reporting_window_hours',
            'billing_postcode',
          ].contains(key)
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: _names[key],
      isDense: true,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      if (key == 'customer_name' && (value?.trim().isEmpty ?? true)) {
        return 'Business name is required.';
      }
      if (key.contains('email')) {
        return CustomerAccountRules.emailError(value);
      }
      if (key == 'billing_postcode') {
        return CustomerAccountRules.postcodeError(value);
      }
      if (key == 'credit_limit') {
        return CustomerAccountRules.numberError(value, optional: true);
      }
      if ([
        'payment_terms_days',
        'issue_reporting_window_hours',
      ].contains(key)) {
        return CustomerAccountRules.numberError(value, integer: true);
      }
      return null;
    },
  );

  Widget _grid(List<Widget> fields) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth < 600 ? 1 : 2;
      return Wrap(
        spacing: 14,
        runSpacing: 16,
        children: [
          for (final field in fields)
            SizedBox(
              width: (box.maxWidth - (columns - 1) * 14) / columns,
              child: field,
            ),
        ],
      );
    },
  );

  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16, top: 8),
    child: Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
    ),
  );

  String _money(dynamic value) =>
      '\$${(double.tryParse('$value') ?? 0).toStringAsFixed(2)}';

  Widget _contextStatus() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_loading) const LinearProgressIndicator(color: _red),
      if (_contextError != null) ...[
        Text(_contextError!, style: const TextStyle(color: _red)),
        TextButton(
          onPressed: _loadContext,
          child: const Text('Retry summary and history'),
        ),
      ],
    ],
  );

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Business and contacts'),
      _grid([
        for (final key in [
          'customer_name',
          'legal_name',
          'abn',
          'licence_number',
          'contact_name',
          'phone',
          'email',
          'statement_email',
          'website',
        ])
          _field(key),
      ]),
      const SizedBox(height: 12),
      const Text(
        'Statement email defaults to the order / invoice email when left blank.',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
      _heading('Billing address'),
      _grid([
        for (final key in [
          'billing_address_line_1',
          'billing_address_line_2',
          'billing_suburb',
          'billing_state',
          'billing_postcode',
        ])
          _field(key),
      ]),
    ],
  );

  Widget _account() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Commercial terms'),
      _grid([
        DropdownButtonFormField<String>(
          initialValue: _payment,
          decoration: const InputDecoration(
            labelText: 'Payment type',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'cod', child: Text('COD')),
            DropdownMenuItem(value: 'prepaid', child: Text('Prepaid')),
            DropdownMenuItem(value: 'account', child: Text('Account')),
          ],
          onChanged: (value) => setState(() => _payment = value ?? 'cod'),
        ),
        _field('account_reference'),
        if (_payment == 'account') ...[
          _field('payment_terms_days'),
          _field('credit_limit'),
        ],
        _field('issue_reporting_window_hours'),
      ]),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        activeTrackColor: _red,
        title: const Text('Account on hold'),
        subtitle: const Text('Stops new orders and new invoice creation.'),
        value: _hold,
        onChanged: (value) => setState(() => _hold = value),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        activeTrackColor: _red,
        title: const Text('Require customer PO number'),
        value: _requirePo,
        onChanged: (value) => setState(() => _requirePo = value),
      ),
      if (widget.account != null) ...[
        _heading('Live account position'),
        _contextStatus(),
        if (_credit != null)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat('Invoice balance', _money(_credit!['invoice_outstanding'])),
              _stat(
                'Unallocated payments',
                _money(_credit!['unallocated_payments']),
              ),
              _stat('Unapplied credits', _money(_credit!['unapplied_credits'])),
              _stat(
                'Credit exposure',
                _money(_credit!['current_credit_exposure']),
              ),
            ],
          ),
        if (_ageing != null) ...[
          _heading('Outstanding invoices by days overdue'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in _ageing!.entries)
                _stat(entry.key, _money(entry.value)),
            ],
          ),
        ],
      ],
    ],
  );

  Widget _stat(String label, String value) => Container(
    width: 160,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _delivery() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'The default location is used for new orders. Existing document snapshots stay unchanged.',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
      const SizedBox(height: 16),
      for (var index = 0; index < _locations.length; index++)
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: _defaultLocation == index ? _red : const Color(0xFFE0E0E0),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _defaultLocation == index
                          ? 'Default delivery location'
                          : 'Delivery location ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_defaultLocation != index)
                    TextButton(
                      onPressed: () => setState(() => _defaultLocation = index),
                      child: const Text('Make default'),
                    ),
                  if (_locations.length > 1)
                    IconButton(
                      tooltip: 'Remove location',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        final removed = _locations.removeAt(index);
                        removed.dispose();
                        if (_defaultLocation == index) {
                          _defaultLocation = 0;
                        } else if (_defaultLocation > index) {
                          _defaultLocation--;
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _grid([
                for (final entry in _ProfileLocation.names.entries)
                  TextFormField(
                    controller: _locations[index].fields[entry.key],
                    decoration: InputDecoration(
                      labelText: entry.value,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: entry.key == 'postcode'
                        ? CustomerAccountRules.postcodeError
                        : null,
                  ),
              ]),
            ],
          ),
        ),
      OutlinedButton.icon(
        onPressed: _locations.length >= 20
            ? null
            : () => setState(
                () => _locations.add(
                  _ProfileLocation({
                    'label': 'Delivery location ${_locations.length + 1}',
                    'state': 'NSW',
                  }),
                ),
              ),
        icon: const Icon(Icons.add),
        label: const Text('Add delivery location'),
      ),
    ],
  );

  Widget _historyTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _contextStatus(),
      if (widget.account == null)
        const Text('History starts when the account is created.'),
      if (!_loading &&
          _contextError == null &&
          widget.account != null &&
          _history.isEmpty)
        const Text('No changes recorded since this upgrade.'),
      for (final row in _history)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(
              row['event_type'] == 'created'
                  ? 'Account created'
                  : 'Account updated',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${DateTime.tryParse('${row['created_at']}')?.toLocal().toString().split('.').first ?? ''} · ${row['actor_name'] ?? 'Supplier team'}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in Map<String, dynamic>.from(
                      row['changes'] as Map? ?? {},
                    ).entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${_names[entry.key] ?? entry.key.replaceAll('_', ' ')}: ${_changeText(entry.value)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );

  String _changeText(dynamic value) {
    final change = Map<String, dynamic>.from(value as Map);
    String show(dynamic v) => v == null || v == ''
        ? '—'
        : v is List
        ? '${v.length} saved location(s)'
        : '$v';
    return '${show(change['old'])} → ${show(change['new'])}';
  }

  void _save() {
    // Keep every tab mounted so validation covers fields on hidden tabs too.
    if (!_form.currentState!.validate()) {
      var invalidTab = 0;
      if ((_payment == 'account' &&
              (CustomerAccountRules.numberError(
                        _fields['payment_terms_days']!.text,
                        integer: true,
                      ) !=
                      null ||
                  CustomerAccountRules.numberError(
                        _fields['credit_limit']!.text,
                        optional: true,
                      ) !=
                      null)) ||
          CustomerAccountRules.numberError(
                _fields['issue_reporting_window_hours']!.text,
                integer: true,
              ) !=
              null) {
        invalidTab = 1;
      } else if (_locations.any(
        (location) =>
            CustomerAccountRules.postcodeError(
              location.fields['postcode']!.text,
            ) !=
            null,
      )) {
        invalidTab = 2;
      }
      setState(() => _tab = invalidTab);
      return;
    }
    String? nullable(String key) {
      final value = _fields[key]!.text.trim();
      return value.isEmpty ? null : value;
    }

    final locations = [
      for (var i = 0; i < _locations.length; i++)
        {..._locations[i].values, 'is_default': i == _defaultLocation},
    ];
    final address = locations[_defaultLocation];
    final values = <String, dynamic>{
      for (final key in _names.keys)
        if (![
          'payment_terms_days',
          'credit_limit',
          'issue_reporting_window_hours',
        ].contains(key))
          key: nullable(key),
      'payment_method': _payment,
      'payment_terms_days': _payment == 'account'
          ? int.parse(_fields['payment_terms_days']!.text.trim())
          : 0,
      'credit_limit': _payment == 'account' && nullable('credit_limit') != null
          ? double.parse(nullable('credit_limit')!)
          : null,
      'issue_reporting_window_hours': int.parse(
        _fields['issue_reporting_window_hours']!.text.trim(),
      ),
      'account_hold': _hold,
      'require_purchase_order': _requirePo,
      'delivery_locations': locations,
      'delivery_contact_name': address['contact_name'],
      'delivery_contact_phone': address['phone'],
      'delivery_instructions': address['instructions'],
      for (final key in [
        'address_line_1',
        'address_line_2',
        'suburb',
        'state',
        'postcode',
      ])
        'delivery_$key': address[key],
    };
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 1100,
        height: (size.height * .88).clamp(250.0, 820.0),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.manage_accounts_outlined, color: _red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.account == null
                          ? 'New customer account'
                          : 'Customer account',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            [
                              'Details',
                              'Account',
                              'Delivery',
                              'Notes',
                              'History',
                            ][i],
                          ),
                          selected: _tab == i,
                          onSelected: (_) => setState(() => _tab = i),
                          selectedColor: const Color(0xFFF4E5E5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _form,
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      for (final tab in [
                        _details(),
                        _account(),
                        _delivery(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _heading('Supplier-only notes'),
                            _field('internal_account_notes', lines: 7),
                            const SizedBox(height: 12),
                            const Text(
                              'These notes stay within this supplier account. They are not printed on customer documents.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        _historyTab(),
                      ])
                        SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            child: tab,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(backgroundColor: _red),
                    child: const Text('Save changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLocation {
  _ProfileLocation(Map<String, dynamic> row) {
    for (final key in names.keys) {
      fields[key] = TextEditingController(text: row[key]?.toString() ?? '');
    }
  }
  static const names = {
    'label': 'Location name',
    'contact_name': 'Delivery contact',
    'phone': 'Delivery phone',
    'address_line_1': 'Address line 1',
    'address_line_2': 'Address line 2',
    'suburb': 'Suburb',
    'state': 'State',
    'postcode': 'Postcode',
    'instructions': 'Delivery instructions',
  };
  final fields = <String, TextEditingController>{};
  Map<String, dynamic> get values => {
    for (final entry in fields.entries)
      entry.key: entry.value.text.trim().isEmpty
          ? null
          : entry.value.text.trim(),
  };
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}
