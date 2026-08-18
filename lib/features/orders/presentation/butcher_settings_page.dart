import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ButcherSettingsPage extends StatelessWidget {
  const ButcherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Butcher Settings',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage your business profile, billing, delivery addresses, privacy and notifications.',
            style: TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 20),
          _SettingsTile(
            icon: Icons.business_outlined,
            title: 'Business Profile',
            subtitle:
                'Trading name, legal name, business contact details and main address.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ButcherProfileSettingsPage(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.receipt_long_outlined,
            title: 'Billing & Accounts',
            subtitle:
                'ABN, billing address and the accounts contact suppliers should use.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ButcherBillingSettingsPage(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery Addresses',
            subtitle:
                'Save multiple delivery locations and choose a default address.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ButcherDeliveryAddressesPage(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle:
                'Control profile visibility and what approved suppliers can see.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ButcherPrivacySettingsPage(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle:
                'Choose which order, invoice and account activity should notify you.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ButcherNotificationSettingsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B1E1E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF8B1E1E)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButcherSettingsData {
  static List<Map<String, dynamic>> maps(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<String> resolveButcherBusinessId() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('You are not signed in.');
    }

    final memberships = await client
        .from('business_memberships')
        .select('business_id')
        .eq('user_id', userId)
        .eq('status', 'active');

    final ids = <String>[
      for (final row in maps(memberships))
        if (row['business_id'] != null) row['business_id'].toString(),
    ];

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', ids);

    for (final business in maps(businesses)) {
      if (business['business_type']?.toString() == 'butcher' &&
          business['active'] != false) {
        return business['id'].toString();
      }
    }

    throw Exception('No active butcher business was found.');
  }
}

class ButcherProfileSettingsPage extends StatefulWidget {
  const ButcherProfileSettingsPage({super.key});

  @override
  State<ButcherProfileSettingsPage> createState() =>
      _ButcherProfileSettingsPageState();
}

class _ButcherProfileSettingsPageState
    extends State<ButcherProfileSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;

  final _tradingName = TextEditingController();
  final _legalName = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _suburb = TextEditingController();
  final _state = TextEditingController();
  final _postcode = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _loginEmailController,
      _tradingName,
      _legalName,
      _email,
      _phone,
      _address1,
      _address2,
      _suburb,
      _state,
      _postcode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final id = await _ButcherSettingsData.resolveButcherBusinessId();
      _loginEmailController.text =
          Supabase.instance.client.auth.currentUser?.email ?? '';
      final row = await Supabase.instance.client
          .from('businesses')
          .select('''
            trading_name,
            legal_name,
            business_email,
            business_phone,
            address_line_1,
            address_line_2,
            suburb,
            state,
            postcode
          ''')
          .eq('id', id)
          .single();

      _tradingName.text = row['trading_name']?.toString() ?? '';
      _legalName.text = row['legal_name']?.toString() ?? '';
      _email.text = row['business_email']?.toString() ?? '';
      _phone.text = row['business_phone']?.toString() ?? '';
      _address1.text = row['address_line_1']?.toString() ?? '';
      _address2.text = row['address_line_2']?.toString() ?? '';
      _suburb.text = row['suburb']?.toString() ?? '';
      _state.text = row['state']?.toString() ?? '';
      _postcode.text = row['postcode']?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        _businessId = id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final businessId = _businessId;
    if (businessId == null || _saving) return;

    setState(() => _saving = true);

    try {
      final result = await Supabase.instance.client.rpc(
        'update_my_business_profile',
        params: {
          'target_business_id': businessId,
          'p_trading_name': _tradingName.text.trim(),
          'p_legal_name': _legalName.text.trim(),
          'p_business_email': _email.text.trim(),
          'p_business_phone': _phone.text.trim(),
          'p_address_line_1': _address1.text.trim(),
          'p_address_line_2': _address2.text.trim(),
          'p_suburb': _suburb.text.trim(),
          'p_state': _state.text.trim(),
          'p_postcode': _postcode.text.trim(),
        },
      );

      if (result is! Map) {
        throw Exception('The business profile was not saved.');
      }

      final saved = Map<String, dynamic>.from(result);

      _tradingName.text = saved['trading_name']?.toString() ?? '';
      _legalName.text = saved['legal_name']?.toString() ?? '';
      _email.text = saved['business_email']?.toString() ?? '';
      _phone.text = saved['business_phone']?.toString() ?? '';
      _address1.text = saved['address_line_1']?.toString() ?? '';
      _address2.text = saved['address_line_2']?.toString() ?? '';
      _suburb.text = saved['suburb']?.toString() ?? '';
      _state.text = saved['state']?.toString() ?? '';
      _postcode.text = saved['postcode']?.toString() ?? '';

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business profile saved successfully.')),
      );
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'Business Profile',
      loading: _loading,
      error: _error,
      saving: _saving,
      onRetry: _load,
      onSave: _save,
      child: Column(
        children: [
          _field(_tradingName, 'Trading Name'),
          _field(_legalName, 'Legal Name'),
          _lockedEmailField(
            _loginEmailController,
            'Login Email',
            'This email is used to sign in and cannot be changed here.',
          ),
          _field(
            _email,
            'Business Contact Email',
            keyboardType: TextInputType.emailAddress,
          ),
          _field(_phone, 'Business Phone', keyboardType: TextInputType.phone),
          _field(_address1, 'Main Address Line 1'),
          _field(_address2, 'Main Address Line 2'),
          _field(_suburb, 'Suburb'),
          Row(
            children: [
              Expanded(child: _field(_state, 'State')),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  _postcode,
                  'Postcode',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ButcherBillingSettingsPage extends StatefulWidget {
  const ButcherBillingSettingsPage({super.key});

  @override
  State<ButcherBillingSettingsPage> createState() =>
      _ButcherBillingSettingsPageState();
}

class _ButcherBillingSettingsPageState
    extends State<ButcherBillingSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;

  final _abn = TextEditingController();
  final _billingEmail = TextEditingController();
  final _billingPhone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _suburb = TextEditingController();
  final _state = TextEditingController();
  final _postcode = TextEditingController();
  final _accountsName = TextEditingController();
  final _accountsEmail = TextEditingController();
  final _accountsPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _abn,
      _billingEmail,
      _billingPhone,
      _address1,
      _address2,
      _suburb,
      _state,
      _postcode,
      _accountsName,
      _accountsEmail,
      _accountsPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final id = await _ButcherSettingsData.resolveButcherBusinessId();
      final row = await Supabase.instance.client
          .from('butcher_billing_profiles')
          .select()
          .eq('butcher_business_id', id)
          .maybeSingle();

      if (row != null) {
        _abn.text = row['abn']?.toString() ?? '';
        _billingEmail.text = row['billing_email']?.toString() ?? '';
        _billingPhone.text = row['billing_phone']?.toString() ?? '';
        _address1.text = row['billing_address_line_1']?.toString() ?? '';
        _address2.text = row['billing_address_line_2']?.toString() ?? '';
        _suburb.text = row['billing_suburb']?.toString() ?? '';
        _state.text = row['billing_state']?.toString() ?? '';
        _postcode.text = row['billing_postcode']?.toString() ?? '';
        _accountsName.text = row['accounts_contact_name']?.toString() ?? '';
        _accountsEmail.text = row['accounts_contact_email']?.toString() ?? '';
        _accountsPhone.text = row['accounts_contact_phone']?.toString() ?? '';
      }

      if (!mounted) return;
      setState(() {
        _businessId = id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_businessId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final saved = await Supabase.instance.client
          .from('butcher_billing_profiles')
          .upsert({
            'butcher_business_id': _businessId,
            'abn': _abn.text.trim(),
            'billing_email': _billingEmail.text.trim(),
            'billing_phone': _billingPhone.text.trim(),
            'billing_address_line_1': _address1.text.trim(),
            'billing_address_line_2': _address2.text.trim(),
            'billing_suburb': _suburb.text.trim(),
            'billing_state': _state.text.trim(),
            'billing_postcode': _postcode.text.trim(),
            'accounts_contact_name': _accountsName.text.trim(),
            'accounts_contact_email': _accountsEmail.text.trim(),
            'accounts_contact_phone': _accountsPhone.text.trim(),
          })
          .select()
          .single();

      if (saved['butcher_business_id']?.toString() != _businessId) {
        throw Exception('The billing settings were not saved.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Billing settings saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'Billing & Accounts',
      loading: _loading,
      error: _error,
      saving: _saving,
      onRetry: _load,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Billing Details'),
          _field(_abn, 'ABN'),
          _field(
            _billingEmail,
            'Billing Email',
            keyboardType: TextInputType.emailAddress,
          ),
          _field(
            _billingPhone,
            'Billing Phone',
            keyboardType: TextInputType.phone,
          ),
          const Divider(height: 30),
          const _SectionHeading('Billing Address'),
          _field(_address1, 'Address Line 1'),
          _field(_address2, 'Address Line 2'),
          _field(_suburb, 'Suburb'),
          Row(
            children: [
              Expanded(child: _field(_state, 'State')),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  _postcode,
                  'Postcode',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          const _SectionHeading('Accounts Contact'),
          _field(_accountsName, 'Accounts Contact Name'),
          _field(
            _accountsEmail,
            'Accounts Contact Email',
            keyboardType: TextInputType.emailAddress,
          ),
          _field(
            _accountsPhone,
            'Accounts Contact Phone',
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }
}

class ButcherDeliveryAddressesPage extends StatefulWidget {
  const ButcherDeliveryAddressesPage({super.key});

  @override
  State<ButcherDeliveryAddressesPage> createState() =>
      _ButcherDeliveryAddressesPageState();
}

class _ButcherDeliveryAddressesPageState
    extends State<ButcherDeliveryAddressesPage> {
  bool _loading = true;
  String? _error;
  String? _businessId;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await _ButcherSettingsData.resolveButcherBusinessId();
      final rows = await Supabase.instance.client
          .from('butcher_delivery_addresses')
          .select()
          .eq('butcher_business_id', id)
          .eq('is_active', true)
          .order('is_default', ascending: false)
          .order('label');

      if (!mounted) return;
      setState(() {
        _businessId = id;
        _addresses = _ButcherSettingsData.maps(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final businessId = _businessId;
    if (businessId == null) return;

    final label = TextEditingController(
      text: existing?['label']?.toString() ?? '',
    );
    final contactName = TextEditingController(
      text: existing?['contact_name']?.toString() ?? '',
    );
    final contactPhone = TextEditingController(
      text: existing?['contact_phone']?.toString() ?? '',
    );
    final address1 = TextEditingController(
      text: existing?['address_line_1']?.toString() ?? '',
    );
    final address2 = TextEditingController(
      text: existing?['address_line_2']?.toString() ?? '',
    );
    final suburb = TextEditingController(
      text: existing?['suburb']?.toString() ?? '',
    );
    final state = TextEditingController(
      text: existing?['state']?.toString() ?? 'NSW',
    );
    final postcode = TextEditingController(
      text: existing?['postcode']?.toString() ?? '',
    );
    final instructions = TextEditingController(
      text: existing?['delivery_instructions']?.toString() ?? '',
    );
    var isDefault = existing?['is_default'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Add Delivery Address' : 'Edit Delivery Address',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(label, 'Address Label'),
                  _field(contactName, 'Contact Name'),
                  _field(
                    contactPhone,
                    'Contact Phone',
                    keyboardType: TextInputType.phone,
                  ),
                  _field(address1, 'Address Line 1'),
                  _field(address2, 'Address Line 2'),
                  _field(suburb, 'Suburb'),
                  Row(
                    children: [
                      Expanded(child: _field(state, 'State')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          postcode,
                          'Postcode',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _field(instructions, 'Delivery Instructions', maxLines: 3),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Default delivery address'),
                    value: isDefault,
                    onChanged: (value) {
                      setDialogState(() => isDefault = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      final client = Supabase.instance.client;

      if (isDefault) {
        await client
            .from('butcher_delivery_addresses')
            .update({'is_default': false})
            .eq('butcher_business_id', businessId)
            .eq('is_default', true);
      }

      final data = {
        'butcher_business_id': businessId,
        'label': label.text.trim().isEmpty
            ? 'Delivery Address'
            : label.text.trim(),
        'contact_name': contactName.text.trim(),
        'contact_phone': contactPhone.text.trim(),
        'address_line_1': address1.text.trim(),
        'address_line_2': address2.text.trim(),
        'suburb': suburb.text.trim(),
        'state': state.text.trim(),
        'postcode': postcode.text.trim(),
        'delivery_instructions': instructions.text.trim(),
        'is_default': isDefault,
        'is_active': true,
      };

      if (existing == null) {
        await client.from('butcher_delivery_addresses').insert(data);
      } else {
        await client
            .from('butcher_delivery_addresses')
            .update(data)
            .eq('id', existing['id']);
      }

      await _load();
    }

    for (final c in [
      label,
      contactName,
      contactPhone,
      address1,
      address2,
      suburb,
      state,
      postcode,
      instructions,
    ]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Addresses')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Addresses')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Delivery Addresses'),
        actions: [
          IconButton(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            tooltip: 'Add address',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _addresses.isEmpty
                ? const Center(
                    child: Text(
                      'No delivery addresses saved yet.',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final address = _addresses[index];

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF8B1E1E),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  address['label']?.toString() ??
                                      'Delivery Address',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (address['is_default'] == true)
                                const Chip(label: Text('Default')),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              [
                                    address['address_line_1'],
                                    address['address_line_2'],
                                    address['suburb'],
                                    address['state'],
                                    address['postcode'],
                                  ]
                                  .map((e) => e?.toString().trim() ?? '')
                                  .where((e) => e.isNotEmpty)
                                  .join(', '),
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: () => _edit(address),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text(
                    'Add Delivery Address',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ButcherPrivacySettingsPage extends StatefulWidget {
  const ButcherPrivacySettingsPage({super.key});

  @override
  State<ButcherPrivacySettingsPage> createState() =>
      _ButcherPrivacySettingsPageState();
}

class _ButcherPrivacySettingsPageState
    extends State<ButcherPrivacySettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;

  bool _profileVisible = true;
  bool _shareContact = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await _ButcherSettingsData.resolveButcherBusinessId();
      final row = await Supabase.instance.client
          .from('business_app_settings')
          .select()
          .eq('business_id', id)
          .maybeSingle();

      if (row != null) {
        _profileVisible = row['marketplace_profile_visible'] != false;
        _shareContact = row['share_contact_with_approved_customers'] != false;
      }

      if (!mounted) return;
      setState(() {
        _businessId = id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_businessId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final saved = await Supabase.instance.client
          .from('business_app_settings')
          .upsert({
            'business_id': _businessId,
            'marketplace_profile_visible': _profileVisible,
            'share_contact_with_approved_customers': _shareContact,
          })
          .select()
          .single();

      if (saved['business_id']?.toString() != _businessId) {
        throw Exception('The privacy settings were not saved.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'Privacy',
      loading: _loading,
      error: _error,
      saving: _saving,
      onRetry: _load,
      onSave: _save,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show butcher profile where applicable'),
            subtitle: const Text(
              'Controls whether your business profile is visible in relevant CutLink areas.',
            ),
            value: _profileVisible,
            onChanged: (value) => setState(() => _profileVisible = value),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share contact details with approved suppliers'),
            subtitle: const Text(
              'Approved suppliers can see your business contact details.',
            ),
            value: _shareContact,
            onChanged: (value) => setState(() => _shareContact = value),
          ),
        ],
      ),
    );
  }
}

class ButcherNotificationSettingsPage extends StatefulWidget {
  const ButcherNotificationSettingsPage({super.key});

  @override
  State<ButcherNotificationSettingsPage> createState() =>
      _ButcherNotificationSettingsPageState();
}

class _ButcherNotificationSettingsPageState
    extends State<ButcherNotificationSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;

  bool _orders = true;
  bool _quotes = true;
  bool _payments = true;
  bool _invoices = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await _ButcherSettingsData.resolveButcherBusinessId();
      final row = await Supabase.instance.client
          .from('business_app_settings')
          .select()
          .eq('business_id', id)
          .maybeSingle();

      if (row != null) {
        _orders = row['notify_new_orders'] != false;
        _quotes = row['notify_quote_activity'] != false;
        _payments = row['notify_payment_claims'] != false;
        _invoices = row['notify_invoice_updates'] != false;
      }

      if (!mounted) return;
      setState(() {
        _businessId = id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_businessId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final saved = await Supabase.instance.client
          .from('business_app_settings')
          .upsert({
            'business_id': _businessId,
            'notify_new_orders': _orders,
            'notify_quote_activity': _quotes,
            'notify_payment_claims': _payments,
            'notify_invoice_updates': _invoices,
          })
          .select()
          .single();

      if (saved['business_id']?.toString() != _businessId) {
        throw Exception('The notification settings were not saved.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'Notifications',
      loading: _loading,
      error: _error,
      saving: _saving,
      onRetry: _load,
      onSave: _save,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Order status updates'),
            value: _orders,
            onChanged: (value) => setState(() => _orders = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quote activity'),
            value: _quotes,
            onChanged: (value) => setState(() => _quotes = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Payment and account updates'),
            value: _payments,
            onChanged: (value) => setState(() => _payments = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invoice updates'),
            value: _invoices,
            onChanged: (value) => setState(() => _invoices = value),
          ),
        ],
      ),
    );
  }
}

class _SettingsFormScaffold extends StatelessWidget {
  const _SettingsFormScaffold({
    required this.title,
    required this.loading,
    required this.error,
    required this.saving,
    required this.onRetry,
    required this.onSave,
    required this.child,
  });

  final String title;
  final bool loading;
  final String? error;
  final bool saving;
  final VoidCallback onRetry;
  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(padding: const EdgeInsets.all(18), child: child),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                saving ? 'Saving...' : 'Save Changes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    );
  }
}

Widget _lockedEmailField(
  TextEditingController controller,
  String label,
  String helperText,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      readOnly: true,
      enableInteractiveSelection: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: const Icon(Icons.lock_outline),
        filled: true,
        fillColor: const Color(0xFFF1F1F1),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
