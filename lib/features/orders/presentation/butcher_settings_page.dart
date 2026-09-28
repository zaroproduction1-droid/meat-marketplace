import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../../shared/widgets/phone_layout.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ButcherSettingsPage extends StatelessWidget {
  const ButcherSettingsPage({super.key, this.onBrandingChanged});
  final VoidCallback? onBrandingChanged;
  @override
  Widget build(BuildContext context) {
    final sections = <(IconData, String, String, Widget)>[
      (
        Icons.business_outlined,
        'Business profile',
        'Your business identity, contacts and main address.',
        const ButcherProfileSettingsPage(),
      ),
      (
        Icons.receipt_long_outlined,
        'Billing & accounts',
        'ABN, billing address and accounts contact.',
        const ButcherBillingSettingsPage(),
      ),
      (
        Icons.local_shipping_outlined,
        'Delivery addresses',
        'Manage delivery locations and your default address.',
        const ButcherDeliveryAddressesPage(),
      ),
      (
        Icons.notifications_outlined,
        'Notifications',
        'Choose alerts, categories and muted activity.',
        const ButcherNotificationSettingsPage(),
      ),
      (
        Icons.privacy_tip_outlined,
        'Privacy',
        'Choose how approved suppliers see your business.',
        const ButcherPrivacySettingsPage(),
      ),
    ];
    return CutLinkWorkspaceTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(title: const Text('Business settings')),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: EdgeInsets.all(constraints.maxWidth < 600 ? 14 : 24),
                children: [
                  const Text(
                    'Make CutLink yours',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Manage your business identity, purchasing details and preferences.',
                    style: TextStyle(color: Color(0xFF6D7177)),
                  ),
                  const SizedBox(height: 20),
                  _ButcherBrandingCard(onChanged: onBrandingChanged),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) => Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        for (final section in sections)
                          SizedBox(
                            width: c.maxWidth >= 740
                                ? (c.maxWidth - 16) / 2
                                : c.maxWidth,
                            child: _SettingsTile(
                              icon: section.$1,
                              title: section.$2,
                              subtitle: section.$3,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      CutLinkWorkspaceTheme(child: section.$4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButcherBrandingCard extends StatefulWidget {
  const _ButcherBrandingCard({this.onChanged});
  final VoidCallback? onChanged;
  @override
  State<_ButcherBrandingCard> createState() => _ButcherBrandingCardState();
}

class _ButcherBrandingCardState extends State<_ButcherBrandingCard> {
  String? _businessId, _path, _error;
  Uint8List? _bytes;
  bool _loading = true, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await _ButcherSettingsData.resolveButcherBusinessId();
      final row = await Supabase.instance.client
          .from('businesses')
          .select('logo_path')
          .eq('id', id)
          .single();
      final path = row['logo_path']?.toString();
      Uint8List? bytes;
      if (path != null && path.isNotEmpty) {
        try {
          bytes = await Supabase.instance.client.storage
              .from('business-branding')
              .download(path);
        } catch (_) {
          /* Allow replacing an old logo whose stored file is missing. */
        }
      }
      if (mounted) {
        setState(() {
          _businessId = id;
          _path = path;
          _bytes = bytes;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load company branding.';
        });
      }
    }
  }

  Future<void> _change({bool remove = false}) async {
    final id = _businessId;
    if (_busy || id == null) {
      return;
    }
    setState(() => _busy = true);
    String? uploadedPath;
    bool saved = false;
    try {
      Uint8List? bytes;
      if (!remove) {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['png', 'jpg', 'jpeg'],
        );
        if (files.isEmpty) {
          return;
        }
        bytes = await files.first.readAsBytes();
        final extension = files.first.name.split('.').last.toLowerCase();
        if (!['png', 'jpg', 'jpeg'].contains(extension) ||
            bytes.isEmpty ||
            bytes.length > 5 * 1024 * 1024) {
          throw StateError('Choose a PNG or JPG logo up to 5 MB.');
        }
        uploadedPath =
            '$id/logo-${DateTime.now().microsecondsSinceEpoch}.${extension == 'jpeg' ? 'jpg' : extension}';
        await Supabase.instance.client.storage
            .from('business-branding')
            .uploadBinary(
              uploadedPath,
              bytes,
              fileOptions: FileOptions(
                contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
              ),
            );
      }
      await Supabase.instance.client.rpc(
        'set_my_business_logo',
        params: {'p_business_id': id, 'p_logo_path': uploadedPath},
      );
      saved = true;
      final oldPath = _path;
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await Supabase.instance.client.storage
              .from('business-branding')
              .remove([oldPath]);
        } catch (_) {
          /* Keep the saved logo if old-file cleanup is unavailable. */
        }
      }
      if (mounted) {
        setState(() {
          _path = uploadedPath;
          _bytes = bytes;
          _error = null;
        });
        widget.onChanged?.call();
      }
    } catch (e) {
      if (!saved && uploadedPath != null) {
        try {
          await Supabase.instance.client.storage
              .from('business-branding')
              .remove([uploadedPath]);
        } catch (_) {
          /* Do not hide the original upload error. */
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to update logo: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E5E8)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _bytes == null
                    ? const Icon(
                        Icons.storefront_outlined,
                        size: 34,
                        color: Color(0xFF741C1C),
                      )
                    : Image.memory(_bytes!, fit: BoxFit.contain),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company branding',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add your business logo to your CutLink identity. PNG or JPG, up to 5 MB.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            TextButton(onPressed: _load, child: Text('$_error Retry')),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy || _loading || _businessId == null
                    ? null
                    : () => _change(),
                icon: const Icon(Icons.upload_outlined),
                label: Text(
                  _busy
                      ? 'Saving…'
                      : _path == null
                      ? 'Upload logo'
                      : 'Change logo',
                ),
              ),
              if (_path != null)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _change(remove: true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove logo'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
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
      color: Colors.white,
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
                  color: const Color(0xFF741C1C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF741C1C)),
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
          PhoneRow(
            mode: PhoneRowMode.stack,
            desktop: Row(
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
          PhoneRow(
            mode: PhoneRowMode.stack,
            desktop: Row(
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
        builder: (context, setDialogState) => phoneDialog(
          context,
          AlertDialog(
            title: Text(
              existing == null
                  ? 'Add Delivery Address'
                  : 'Edit Delivery Address',
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
                    PhoneRow(
                      mode: PhoneRowMode.stack,
                      desktop: Row(
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
        appBar: phoneAppBar(
          context,
          AppBar(title: const Text('Delivery Addresses')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(title: const Text('Delivery Addresses')),
        ),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: phoneAppBar(
        context,
        AppBar(
          title: const Text('Delivery Addresses'),
          actions: [
            IconButton(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              tooltip: 'Add address',
            ),
          ],
        ),
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
  final Map<String, bool> _activityPreferences = {
    'notify_platform': true,
    'notify_messages': true,
    'notify_credit_updates': true,
    'notify_delivery_updates': true,
    'notify_support_updates': true,
  };
  bool _muteAll = false;
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
        _muteAll = row['mute_all_notifications'] == true;
        for (final key in _activityPreferences.keys) {
          _activityPreferences[key] = row[key] != false;
        }
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
            ..._activityPreferences,
            'mute_all_notifications': _muteAll,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PostgrestException
                  ? e.message
                  : 'Could not save notification preferences. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsFormScaffold(
      title: 'Notification settings',
      loading: _loading,
      error: _error,
      saving: _saving,
      onRetry: _load,
      onSave: _save,
      child: Column(
        children: [
          const Text(
            'Choose what appears in the dashboard bell and unread alerts. Turn a category off to mute it. All activity remains available in All notifications.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mute all dashboard alerts'),
            subtitle: const Text(
              'Keep notification history without bell alerts.',
            ),
            value: _muteAll,
            onChanged: _saving ? null : (v) => setState(() => _muteAll = v),
          ),
          for (final entry in const {
            'notify_platform': 'CutLink announcements',
            'notify_messages': 'Marketplace messages & issues',
            'notify_credit_updates': 'Credits & refunds',
            'notify_delivery_updates': 'Delivery and pickup updates',
            'notify_support_updates': 'CutLink Support replies',
          }.entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: _activityPreferences[entry.key]!,
              onChanged: (v) =>
                  setState(() => _activityPreferences[entry.key] = v),
            ),
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
        appBar: phoneAppBar(context, AppBar(title: Text(title))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: phoneAppBar(context, AppBar(title: Text(title))),
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

    return CutLinkWorkspaceTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(
            title: Text(title),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(saving ? 'Saving…' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Keep your business details and preferences up to date.',
                  style: TextStyle(color: Color(0xFF6D7177)),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: child,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
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
