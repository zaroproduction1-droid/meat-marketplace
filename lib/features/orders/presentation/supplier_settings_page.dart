import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierSettingsPage extends StatelessWidget {
  const SupplierSettingsPage({super.key});

  static const _darkRed = Color(0xFF741C1C);
  static const _canvas = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE3E5E8);
  static const _muted = Color(0xFF666A70);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: _darkRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _border),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 50),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x07000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFFF8EEEE),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Icon(
                        Icons.tune_outlined,
                        color: _darkRed,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supplier Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your business profile, invoice configuration, privacy and notification preferences.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 760;

                  final cards = [
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
                            builder: (_) =>
                                const SupplierInvoiceConfigurationPage(),
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
                            builder: (_) =>
                                const SupplierNotificationSettingsPage(),
                          ),
                        );
                      },
                    ),
                  ];

                  if (!twoColumns) {
                    return Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          cards[i],
                          if (i != cards.length - 1) const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 14),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 14),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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

  static const _darkRed = Color(0xFF741C1C);
  static const _border = Color(0xFFE3E5E8);
  static const _muted = Color(0xFF666A70);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 142),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x07000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8EEEE),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _darkRed, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2329),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 9),
                child: Icon(
                  Icons.chevron_right,
                  color: Color(0xFF8A8F96),
                  size: 20,
                ),
              ),
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

  static const _darkRed = Color(0xFF741C1C);
  static const _canvas = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE3E5E8);
  static const _muted = Color(0xFF666A70);

  IconData get _pageIcon {
    switch (title) {
      case 'Business Profile':
        return Icons.business_outlined;
      case 'Invoice Configuration':
        return Icons.receipt_long_outlined;
      case 'Privacy':
        return Icons.privacy_tip_outlined;
      case 'Notifications':
        return Icons.notifications_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  String get _pageDescription {
    switch (title) {
      case 'Business Profile':
        return 'Maintain the supplier details used throughout CutLink.';
      case 'Invoice Configuration':
        return 'Manage the supplier information and payment details shown on invoices.';
      case 'Privacy':
        return 'Control how your supplier profile and contact information are shared.';
      case 'Notifications':
        return 'Choose which supplier activity should generate notifications.';
      default:
        return 'Manage this supplier setting.';
    }
  }

  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 8,
      title: Row(
        children: [
          Icon(_pageIcon, color: _darkRed, size: 21),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: _border),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: _canvas,
        appBar: _appBar(),
        body: const Center(child: CircularProgressIndicator(color: _darkRed)),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: _canvas,
        appBar: _appBar(),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x07000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: _darkRed, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4B4F55),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _canvas,
      appBar: _appBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 50),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x07000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_pageIcon, color: _darkRed, size: 23),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _pageDescription,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x07000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: child,
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _darkRed.withValues(alpha: 0.45),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 19),
                    label: Text(
                      saving ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF741C1C),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2329),
            ),
          ),
        ],
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
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      readOnly: true,
      enableInteractiveSelection: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_outline),
        filled: true,
        fillColor: const Color(0xFFF5F6F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD9DDE1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD9DDE1)),
        ),
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
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD9DDE1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD9DDE1)),
        ),
      ),
    ),
  );
}
