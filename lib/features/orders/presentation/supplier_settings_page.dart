import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierSettingsPage extends StatelessWidget {
  const SupplierSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Supplier Settings',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage your business profile, invoices, privacy and notifications.',
            style: TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 20),
          _SettingsTile(
            icon: Icons.business_outlined,
            title: 'Business Profile',
            subtitle:
                'Trading name, legal name, contact details and business address.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupplierProfileSettingsPage(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.receipt_long_outlined,
            title: 'Invoice Configuration',
            subtitle:
                'ABN, licence number, invoice contact details, invoice address and banking details.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupplierInvoiceConfigurationPage(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle:
                'Control marketplace profile visibility and customer access to contact details.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupplierPrivacySettingsPage(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle:
                'Choose which order, quote, payment and invoice activity should notify you.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupplierNotificationSettingsPage(),
                ),
              );
            },
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
                child: const SizedBox(),
              ),
              Transform.translate(
                offset: const Offset(-35, 0),
                child: Icon(icon, color: const Color(0xFF8B1E1E)),
              ),
              const SizedBox(width: 0),
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
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierSettingsData {
  static List<Map<String, dynamic>> maps(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<String> resolveSupplierBusinessId() async {
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

    final businessIds = <String>[
      for (final row in maps(memberships))
        if (row['business_id'] != null) row['business_id'].toString(),
    ];

    if (businessIds.isEmpty) {
      throw Exception('No active business membership was found.');
    }

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', businessIds);

    for (final business in maps(businesses)) {
      if (business['business_type']?.toString() == 'supplier' &&
          business['active'] != false) {
        final id = business['id']?.toString();
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    }

    throw Exception('No active supplier business was found.');
  }
}

class SupplierProfileSettingsPage extends StatefulWidget {
  const SupplierProfileSettingsPage({super.key});

  @override
  State<SupplierProfileSettingsPage> createState() =>
      _SupplierProfileSettingsPageState();
}

class _SupplierProfileSettingsPageState
    extends State<SupplierProfileSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;

  final _loginEmailController = TextEditingController();
  final _tradingName = TextEditingController();
  final _legalName = TextEditingController();
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
      final id = await _SupplierSettingsData.resolveSupplierBusinessId();
      _loginEmailController.text =
          Supabase.instance.client.auth.currentUser?.email ?? '';
      final business = await Supabase.instance.client
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

      _tradingName.text = business['trading_name']?.toString() ?? '';
      _legalName.text = business['legal_name']?.toString() ?? '';
      _email.text = business['business_email']?.toString() ?? '';
      _phone.text = business['business_phone']?.toString() ?? '';
      _address1.text = business['address_line_1']?.toString() ?? '';
      _address2.text = business['address_line_2']?.toString() ?? '';
      _suburb.text = business['suburb']?.toString() ?? '';
      _state.text = business['state']?.toString() ?? '';
      _postcode.text = business['postcode']?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        _businessId = id;
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
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
        ],
      ),
    );
  }
}

class SupplierInvoiceConfigurationPage extends StatefulWidget {
  const SupplierInvoiceConfigurationPage({super.key});

  @override
  State<SupplierInvoiceConfigurationPage> createState() =>
      _SupplierInvoiceConfigurationPageState();
}

class _SupplierInvoiceConfigurationPageState
    extends State<SupplierInvoiceConfigurationPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;

  final _abn = TextEditingController();
  final _licence = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _suburb = TextEditingController();
  final _state = TextEditingController();
  final _postcode = TextEditingController();
  final _bankName = TextEditingController();
  final _accountName = TextEditingController();
  final _bsb = TextEditingController();
  final _accountNumber = TextEditingController();
  final _instructions = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _abn,
      _licence,
      _email,
      _phone,
      _address1,
      _address2,
      _suburb,
      _state,
      _postcode,
      _bankName,
      _accountName,
      _bsb,
      _accountNumber,
      _instructions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final id = await _SupplierSettingsData.resolveSupplierBusinessId();
      final profile = await Supabase.instance.client
          .from('supplier_invoice_profiles')
          .select()
          .eq('supplier_business_id', id)
          .maybeSingle();

      if (profile != null) {
        _abn.text = profile['abn']?.toString() ?? '';
        _licence.text = profile['licence_number']?.toString() ?? '';
        _email.text = profile['invoice_email']?.toString() ?? '';
        _phone.text = profile['invoice_phone']?.toString() ?? '';
        _address1.text = profile['address_line_1']?.toString() ?? '';
        _address2.text = profile['address_line_2']?.toString() ?? '';
        _suburb.text = profile['suburb']?.toString() ?? '';
        _state.text = profile['state']?.toString() ?? '';
        _postcode.text = profile['postcode']?.toString() ?? '';
        _bankName.text = profile['bank_name']?.toString() ?? '';
        _accountName.text = profile['bank_account_name']?.toString() ?? '';
        _bsb.text = profile['bank_bsb']?.toString() ?? '';
        _accountNumber.text = profile['bank_account_number']?.toString() ?? '';
        _instructions.text = profile['payment_instructions']?.toString() ?? '';
      }

      if (!mounted) return;
      setState(() {
        _businessId = id;
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

  Future<void> _save() async {
    if (_businessId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final saved = await Supabase.instance.client
          .from('supplier_invoice_profiles')
          .upsert({
            'supplier_business_id': _businessId,
            'abn': _abn.text.trim(),
            'licence_number': _licence.text.trim(),
            'invoice_email': _email.text.trim(),
            'invoice_phone': _phone.text.trim(),
            'address_line_1': _address1.text.trim(),
            'address_line_2': _address2.text.trim(),
            'suburb': _suburb.text.trim(),
            'state': _state.text.trim(),
            'postcode': _postcode.text.trim(),
            'bank_name': _bankName.text.trim(),
            'bank_account_name': _accountName.text.trim(),
            'bank_bsb': _bsb.text.trim(),
            'bank_account_number': _accountNumber.text.trim(),
            'payment_instructions': _instructions.text.trim(),
          })
          .select()
          .single();

      if (saved['supplier_business_id']?.toString() != _businessId) {
        throw Exception('The invoice configuration was not saved.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice configuration saved.')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'Invoice Configuration',
      loading: _loading,
      error: _error,
      saving: _saving,
      onRetry: _load,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Supplier Invoice Details'),
          _field(_abn, 'ABN'),
          _field(_licence, 'Licence Number'),
          _field(
            _email,
            'Invoice Email',
            keyboardType: TextInputType.emailAddress,
          ),
          _field(_phone, 'Invoice Phone', keyboardType: TextInputType.phone),
          const Divider(height: 30),
          const _SectionHeading('Invoice Address'),
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
          const _SectionHeading('Banking Details'),
          _field(_bankName, 'Bank Name'),
          _field(_accountName, 'Account Name'),
          _field(_bsb, 'BSB', keyboardType: TextInputType.number),
          _field(
            _accountNumber,
            'Account Number',
            keyboardType: TextInputType.number,
          ),
          _field(_instructions, 'Payment Instructions', maxLines: 3),
        ],
      ),
    );
  }
}

class SupplierPrivacySettingsPage extends StatefulWidget {
  const SupplierPrivacySettingsPage({super.key});

  @override
  State<SupplierPrivacySettingsPage> createState() =>
      _SupplierPrivacySettingsPageState();
}

class _SupplierPrivacySettingsPageState
    extends State<SupplierPrivacySettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;
  bool _marketplaceVisible = true;
  bool _shareContact = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await _SupplierSettingsData.resolveSupplierBusinessId();
      final settings = await Supabase.instance.client
          .from('business_app_settings')
          .select()
          .eq('business_id', id)
          .maybeSingle();

      if (settings != null) {
        _marketplaceVisible = settings['marketplace_profile_visible'] != false;
        _shareContact =
            settings['share_contact_with_approved_customers'] != false;
      }

      if (!mounted) return;
      setState(() {
        _businessId = id;
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

  Future<void> _save() async {
    if (_businessId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final saved = await Supabase.instance.client
          .from('business_app_settings')
          .upsert({
            'business_id': _businessId,
            'marketplace_profile_visible': _marketplaceVisible,
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
            title: const Text('Show supplier profile in marketplace'),
            subtitle: const Text(
              'Allows CutLink users to see your supplier profile where applicable.',
            ),
            value: _marketplaceVisible,
            onChanged: (value) {
              setState(() => _marketplaceVisible = value);
            },
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share contact details with approved customers'),
            subtitle: const Text(
              'Approved customers can see your business contact details.',
            ),
            value: _shareContact,
            onChanged: (value) {
              setState(() => _shareContact = value);
            },
          ),
        ],
      ),
    );
  }
}

class SupplierNotificationSettingsPage extends StatefulWidget {
  const SupplierNotificationSettingsPage({super.key});

  @override
  State<SupplierNotificationSettingsPage> createState() =>
      _SupplierNotificationSettingsPageState();
}

class _SupplierNotificationSettingsPageState
    extends State<SupplierNotificationSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _businessId;

  bool _newOrders = true;
  bool _quoteActivity = true;
  bool _paymentClaims = true;
  bool _invoiceUpdates = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await _SupplierSettingsData.resolveSupplierBusinessId();
      final settings = await Supabase.instance.client
          .from('business_app_settings')
          .select()
          .eq('business_id', id)
          .maybeSingle();

      if (settings != null) {
        _newOrders = settings['notify_new_orders'] != false;
        _quoteActivity = settings['notify_quote_activity'] != false;
        _paymentClaims = settings['notify_payment_claims'] != false;
        _invoiceUpdates = settings['notify_invoice_updates'] != false;
      }

      if (!mounted) return;
      setState(() {
        _businessId = id;
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

  Future<void> _save() async {
    if (_businessId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final saved = await Supabase.instance.client
          .from('business_app_settings')
          .upsert({
            'business_id': _businessId,
            'notify_new_orders': _newOrders,
            'notify_quote_activity': _quoteActivity,
            'notify_payment_claims': _paymentClaims,
            'notify_invoice_updates': _invoiceUpdates,
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
            title: const Text('New marketplace orders'),
            value: _newOrders,
            onChanged: (value) {
              setState(() => _newOrders = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quote activity'),
            value: _quoteActivity,
            onChanged: (value) {
              setState(() => _quoteActivity = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Customer payment claims'),
            value: _paymentClaims,
            onChanged: (value) {
              setState(() => _paymentClaims = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invoice updates'),
            value: _invoiceUpdates,
            onChanged: (value) {
              setState(() => _invoiceUpdates = value);
            },
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
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8B1E1E)),
                ),
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
