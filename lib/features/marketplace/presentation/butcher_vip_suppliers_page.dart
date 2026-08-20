import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ButcherVipSuppliersPage extends StatefulWidget {
  const ButcherVipSuppliersPage({super.key});

  @override
  State<ButcherVipSuppliersPage> createState() =>
      _ButcherVipSuppliersPageState();
}

class _ButcherVipSuppliersPageState extends State<ButcherVipSuppliersPage> {
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _suppliers = [];
  Duration _reapplyCooldown = const Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cooldownSecondsResponse = await Supabase.instance.client.rpc(
        'cutlink_vip_reapply_cooldown_seconds',
      );

      final cooldownSeconds =
          int.tryParse(cooldownSecondsResponse?.toString() ?? '') ?? 86400;

      final response = await Supabase.instance.client.rpc(
        'list_suppliers_for_butcher_vip',
      );

      if (!mounted) return;

      setState(() {
        _reapplyCooldown = Duration(seconds: cooldownSeconds);
        _suppliers = _maps(response);
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
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

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    final search = _searchController.text.trim().toLowerCase();

    if (search.isEmpty) return _suppliers;

    return _suppliers.where((supplier) {
      final values = [
        supplier['trading_name'],
        supplier['legal_name'],
        supplier['suburb'],
        supplier['state'],
      ];

      return values.any(
        (value) =>
            value != null && value.toString().toLowerCase().contains(search),
      );
    }).toList();
  }

  String _supplierName(Map<String, dynamic> supplier) {
    final trading = supplier['trading_name']?.toString().trim();
    final legal = supplier['legal_name']?.toString().trim();

    if (trading != null && trading.isNotEmpty) return trading;
    if (legal != null && legal.isNotEmpty) return legal;

    return 'Supplier';
  }

  String _location(Map<String, dynamic> supplier) {
    final parts = [
      supplier['suburb']?.toString().trim(),
      supplier['state']?.toString().trim(),
      supplier['postcode']?.toString().trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();

    return parts.isEmpty ? 'Location not listed' : parts.join(' ');
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'pending' => 'Application Pending',
      'approved' => 'VIP Approved',
      'declined' => 'Application Declined',
      'withdrawn' => 'Withdrawn',
      'suspended' => 'VIP Suspended',
      _ => 'Standard Pricing',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'approved' => const Color(0xFF23683A),
      'pending' => const Color(0xFF9A6500),
      'declined' => const Color(0xFF9A3030),
      'suspended' => const Color(0xFF9A3030),
      _ => const Color(0xFF5F5F5F),
    };
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  Duration? _cooldownRemaining(dynamic declinedAt) {
    final declined = _date(declinedAt);
    if (declined == null) return null;

    final remaining = declined.add(_reapplyCooldown).difference(DateTime.now());

    if (remaining.isNegative || remaining.inSeconds <= 0) return null;
    return remaining;
  }

  String _cooldownText(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) return '${hours}h ${minutes}m remaining';
    return '${duration.inMinutes.clamp(1, 59)}m remaining';
  }

  Future<void> _openApplication(Map<String, dynamic> supplier) async {
    final vipStatus = supplier['vip_status']?.toString() ?? 'not_requested';
    final vipEnabled = supplier['vip_pricing_enabled'] == true;
    final creditEnabled = supplier['credit_account_enabled'] == true;
    final creditStatus =
        supplier['credit_application_status']?.toString() ?? 'not_requested';

    if (vipStatus == 'pending') {
      _message(
        'You already have a pending VIP application with this supplier.',
      );
      return;
    }

    if (!vipEnabled && vipStatus == 'declined') {
      final remaining = _cooldownRemaining(supplier['vip_declined_at']);
      if (remaining != null) {
        _message(
          'You can apply again after the cooldown. '
          '${_cooldownText(remaining)}.',
        );
        return;
      }
    }

    if (vipEnabled && creditEnabled) {
      _message('VIP pricing and a credit account are already active.');
      return;
    }

    if (vipEnabled && creditStatus == 'pending') {
      _message('Your credit account application is already pending.');
      return;
    }

    if (vipEnabled && creditStatus == 'declined') {
      final remaining = _cooldownRemaining(supplier['credit_declined_at']);
      if (remaining != null) {
        _message(
          'You can apply for credit again after the cooldown. '
          '${_cooldownText(remaining)}.',
        );
        return;
      }
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ButcherVipApplicationPage(
          supplier: supplier,
          creditUpgradeOnly: vipEnabled && !creditEnabled,
        ),
      ),
    );

    if (changed == true) await _load();
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'VIP Supplier Access',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: _load, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 50),
          children: [
            const Text(
              'Apply for VIP pricing',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your CutLink approval already gives you access to each supplier’s Standard Price. VIP pricing is separate and must be approved by each supplier individually.',
              style: TextStyle(color: Color(0xFF606060), height: 1.45),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD7E3D8)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF35613B)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Every supplier relationship is private and independent. Approval from one supplier does not approve you with another supplier, and suppliers cannot see another supplier’s decision, private review notes or account terms.',
                      style: TextStyle(
                        color: Color(0xFF35523A),
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search suppliers',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0E0DD)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_filteredSuppliers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'No suppliers match your search.',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              for (final supplier in _filteredSuppliers) ...[
                _supplierCard(supplier),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _supplierCard(Map<String, dynamic> supplier) {
    final status = supplier['vip_status']?.toString() ?? 'not_requested';
    final vipEnabled = supplier['vip_pricing_enabled'] == true;
    final creditEnabled = supplier['credit_account_enabled'] == true;
    final creditStatus =
        supplier['credit_application_status']?.toString() ?? 'not_requested';

    final vipCooldown = !vipEnabled && status == 'declined'
        ? _cooldownRemaining(supplier['vip_declined_at'])
        : null;

    final creditCooldown = vipEnabled && creditStatus == 'declined'
        ? _cooldownRemaining(supplier['credit_declined_at'])
        : null;

    String actionLabel;
    bool disabled = false;

    if (vipEnabled && creditEnabled) {
      actionLabel = 'VIP + Credit Active';
      disabled = true;
    } else if (vipEnabled && creditStatus == 'pending') {
      actionLabel = 'Credit Pending';
      disabled = true;
    } else if (vipEnabled && creditCooldown != null) {
      actionLabel = 'Credit cooldown';
      disabled = true;
    } else if (vipEnabled) {
      actionLabel = 'Apply for Credit';
    } else if (status == 'pending') {
      actionLabel = 'VIP Pending';
      disabled = true;
    } else if (vipCooldown != null) {
      actionLabel = 'Cooldown';
      disabled = true;
    } else {
      actionLabel = 'Apply for VIP';
    }

    final statusColour = vipEnabled
        ? const Color(0xFF23683A)
        : _statusColor(status);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E0DD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _darkRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.local_shipping_outlined, color: _darkRed),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _supplierName(supplier),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _location(supplier),
                    style: const TextStyle(color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _smallStatus(
                        vipEnabled ? 'VIP Approved' : _statusLabel(status),
                        statusColour,
                      ),
                      if (vipEnabled)
                        _smallStatus(
                          creditEnabled
                              ? 'Credit Active'
                              : creditStatus == 'pending'
                              ? 'Credit Pending'
                              : 'No Credit Account',
                          const Color(0xFF2F5F8F),
                        ),
                    ],
                  ),
                  if (vipCooldown != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Reapply available in ${_cooldownText(vipCooldown)}.',
                      style: const TextStyle(
                        color: Color(0xFF9A3030),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (creditCooldown != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Credit reapplication available in '
                      '${_cooldownText(creditCooldown)}.',
                      style: const TextStyle(
                        color: Color(0xFF9A3030),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: disabled ? null : () => _openApplication(supplier),
              style: FilledButton.styleFrom(
                backgroundColor: _darkRed,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              icon: Icon(
                vipEnabled
                    ? Icons.account_balance_wallet_outlined
                    : Icons.workspace_premium_outlined,
              ),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStatus(String label, Color colour) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colour,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ButcherVipApplicationPage extends StatefulWidget {
  const ButcherVipApplicationPage({
    super.key,
    required this.supplier,
    this.creditUpgradeOnly = false,
  });

  final Map<String, dynamic> supplier;
  final bool creditUpgradeOnly;

  @override
  State<ButcherVipApplicationPage> createState() =>
      _ButcherVipApplicationPageState();
}

class _ButcherVipApplicationPageState extends State<ButcherVipApplicationPage> {
  static const _darkRed = Color(0xFF741C1C);

  final _formKey = GlobalKey<FormState>();

  final _primaryContact = TextEditingController();
  final _position = TextEditingController();
  final _yearsTrading = TextEditingController();
  final _monthlyPurchases = TextEditingController();
  final _requestedTerms = TextEditingController(text: '14');
  final _requestedCreditLimit = TextEditingController();
  final _messageController = TextEditingController();

  final List<_TradeReferenceControllers> _references = [
    _TradeReferenceControllers(),
    _TradeReferenceControllers(),
  ];

  final List<_PendingDocument> _documents = [];

  String _applicationType = 'vip_pricing_only';

  bool _tradeReferenceConsent = false;
  bool _commercialCreditConsent = false;
  bool _consumerCreditReportConsent = false;
  bool _privacyAccepted = false;
  bool _declarationAccepted = false;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.creditUpgradeOnly) {
      _applicationType = 'vip_pricing_and_credit';
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _primaryContact,
      _position,
      _yearsTrading,
      _monthlyPurchases,
      _requestedTerms,
      _requestedCreditLimit,
      _messageController,
    ]) {
      controller.dispose();
    }

    for (final reference in _references) {
      reference.dispose();
    }

    super.dispose();
  }

  String _supplierName() {
    final trading = widget.supplier['trading_name']?.toString().trim();
    final legal = widget.supplier['legal_name']?.toString().trim();

    if (trading != null && trading.isNotEmpty) return trading;
    if (legal != null && legal.isNotEmpty) return legal;

    return 'Supplier';
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result.isEmpty) return;

    final additions = <_PendingDocument>[];

    for (final file in result) {
      final bytes = await file.readAsBytes();

      if (bytes.length > 10 * 1024 * 1024) {
        _message('${file.name} is larger than the 10 MB limit.');
        continue;
      }

      additions.add(
        _PendingDocument(
          fileName: file.name,
          bytes: bytes,
          extension: file.name.contains('.')
              ? file.name.split('.').last.toLowerCase()
              : null,
        ),
      );
    }

    if (!mounted || additions.isEmpty) return;

    setState(() {
      _documents.addAll(additions);
    });
  }

  String _documentTypeForName(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('credit')) {
      return 'commercial_credit_report';
    }
    if (lower.contains('statement')) {
      return 'supplier_statement';
    }
    if (lower.contains('financial')) {
      return 'financial_statement';
    }
    if (lower.contains('reference')) {
      return 'trade_reference_document';
    }

    return 'other';
  }

  String _mimeType(_PendingDocument document) {
    return switch (document.extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }

  List<Map<String, dynamic>> _referencePayload() {
    final result = <Map<String, dynamic>>[];

    for (final reference in _references) {
      if (reference.businessName.text.trim().isEmpty) {
        continue;
      }

      result.add({
        'business_name': reference.businessName.text.trim(),
        'contact_name': reference.contactName.text.trim(),
        'contact_position': reference.contactPosition.text.trim(),
        'contact_email': reference.email.text.trim(),
        'contact_phone': reference.phone.text.trim(),
        'years_trading_with_reference': reference.yearsTrading.text.trim(),
        'notes': reference.notes.text.trim(),
      });
    }

    return result;
  }

  Future<String> _resolveButcherBusinessId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('You are not signed in.');
    }

    final memberships = await Supabase.instance.client
        .from('business_memberships')
        .select('business_id')
        .eq('user_id', user.id)
        .eq('status', 'active');

    final ids = _maps(memberships)
        .map((row) => row['business_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (ids.isEmpty) {
      throw Exception('No active business membership was found.');
    }

    final businesses = await Supabase.instance.client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', ids);

    for (final business in _maps(businesses)) {
      if (business['business_type']?.toString() == 'butcher' &&
          business['active'] != false) {
        return business['id'].toString();
      }
    }

    throw Exception('No active butcher business was found.');
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_referencePayload().length < 2) {
      _message('Please provide at least two trade references.');
      return;
    }

    if (!_tradeReferenceConsent || !_privacyAccepted || !_declarationAccepted) {
      _message('Please accept the required declarations before submitting.');
      return;
    }

    if (_applicationType == 'vip_pricing_and_credit' &&
        !_commercialCreditConsent) {
      _message(
        'Commercial credit assessment consent is required when requesting a credit account.',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final supplierId = widget.supplier['supplier_business_id']?.toString();

      if (supplierId == null || supplierId.isEmpty) {
        throw Exception('Supplier could not be identified.');
      }

      final response = await Supabase.instance.client.rpc(
        'submit_vip_trade_application',
        params: {
          'p_supplier_business_id': supplierId,
          'p_application_type': _applicationType,
          'p_primary_contact_name': _primaryContact.text.trim(),
          'p_primary_contact_position': _position.text.trim(),
          'p_years_trading': double.tryParse(_yearsTrading.text.trim()),
          'p_estimated_monthly_purchases': double.tryParse(
            _monthlyPurchases.text.trim(),
          ),
          'p_requested_payment_terms_days':
              _applicationType == 'vip_pricing_and_credit'
              ? int.tryParse(_requestedTerms.text.trim())
              : null,
          'p_requested_credit_limit':
              _applicationType == 'vip_pricing_and_credit'
              ? double.tryParse(_requestedCreditLimit.text.trim())
              : null,
          'p_application_message': _messageController.text.trim(),
          'p_trade_reference_contact_consent': _tradeReferenceConsent,
          'p_commercial_credit_assessment_consent': _commercialCreditConsent,
          'p_consumer_credit_report_consent': _consumerCreditReportConsent,
          'p_privacy_notice_accepted': _privacyAccepted,
          'p_applicant_declaration_accepted': _declarationAccepted,
          'p_trade_references': _referencePayload(),
        },
      );

      final applicationId = response?.toString();

      if (applicationId == null || applicationId.isEmpty) {
        throw Exception('VIP application could not be created.');
      }

      if (_documents.isNotEmpty) {
        await _uploadDocuments(
          applicationId: applicationId,
          supplierId: supplierId,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VIP application sent to ${_supplierName()}.')),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _uploadDocuments({
    required String applicationId,
    required String supplierId,
  }) async {
    final butcherId = await _resolveButcherBusinessId();
    final storage = Supabase.instance.client.storage.from(
      'vip-application-documents',
    );

    for (var index = 0; index < _documents.length; index++) {
      final document = _documents[index];

      final safeName = document.fileName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );

      final path =
          '$butcherId/$supplierId/$applicationId/${DateTime.now().microsecondsSinceEpoch}_$index'
          '_$safeName';

      await storage.uploadBinary(
        path,
        document.bytes,
        fileOptions: FileOptions(
          contentType: _mimeType(document),
          upsert: false,
        ),
      );

      await Supabase.instance.client.rpc(
        'register_vip_application_document',
        params: {
          'p_application_id': applicationId,
          'p_document_type': _documentTypeForName(document.fileName),
          'p_file_name': document.fileName,
          'p_storage_path': path,
          'p_mime_type': _mimeType(document),
          'p_file_size_bytes': document.bytes.length,
        },
      );
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final creditRequested = _applicationType == 'vip_pricing_and_credit';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'VIP Application • ${_supplierName()}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 50),
              children: [
                _introCard(),
                const SizedBox(height: 18),
                _section(
                  title: '1. Access requested',
                  subtitle: widget.creditUpgradeOnly
                      ? 'Your VIP pricing is already active. This application only asks this supplier to consider a credit account.'
                      : 'VIP pricing is supplier-specific. Credit terms are optional and remain entirely at the supplier’s discretion.',
                  child: widget.creditUpgradeOnly
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD6E0EA)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Color(0xFF2F5F8F),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Credit account application. Your existing VIP pricing stays active whether this credit application is approved or declined.',
                                  style: TextStyle(
                                    color: Color(0xFF35516D),
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _applicationTypeCard(
                              value: 'vip_pricing_only',
                              icon: Icons.workspace_premium_outlined,
                              title: 'VIP pricing only',
                              description:
                                  'Apply for this supplier’s VIP/Trade pricing. Standard CutLink pricing remains available while your application is reviewed.',
                            ),
                            const SizedBox(height: 12),
                            _applicationTypeCard(
                              value: 'vip_pricing_and_credit',
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'VIP pricing + credit account',
                              description:
                                  'Also ask the supplier to consider payment terms and a credit limit.',
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                _section(
                  title: '2. Applicant details',
                  subtitle:
                      'Your registered CutLink business details are attached automatically. Add the person the supplier should contact about this application.',
                  child: Column(
                    children: [
                      _twoColumns(
                        TextFormField(
                          controller: _primaryContact,
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Primary contact name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              _required(value, 'Primary contact name'),
                        ),
                        TextFormField(
                          controller: _position,
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Position / role',
                            hintText: 'Owner, Director, Purchasing Manager',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => _required(value, 'Position'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _twoColumns(
                        TextFormField(
                          controller: _yearsTrading,
                          enabled: !_submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Years trading',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextFormField(
                          controller: _monthlyPurchases,
                          enabled: !_submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText:
                                'Estimated monthly purchases with this supplier',
                            prefixText: '\$',
                            hintText: 'Optional',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (creditRequested) ...[
                        const SizedBox(height: 16),
                        _twoColumns(
                          TextFormField(
                            controller: _requestedTerms,
                            enabled: !_submitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Requested payment terms',
                              suffixText: 'days',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          TextFormField(
                            controller: _requestedCreditLimit,
                            enabled: !_submitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Requested credit limit',
                              prefixText: '\$',
                              hintText: 'Optional',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        enabled: !_submitting,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Message to supplier (optional)',
                          hintText:
                              'Tell the supplier about your business, expected purchasing or existing relationship.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _section(
                  title: '3. Trade references',
                  subtitle:
                      'Provide at least two businesses the supplier may contact to verify your trading history.',
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < _references.length;
                        index++
                      ) ...[
                        _referenceCard(index),
                        if (index != _references.length - 1)
                          const SizedBox(height: 12),
                      ],
                      if (_references.length < 5) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _submitting
                                ? null
                                : () {
                                    setState(() {
                                      _references.add(
                                        _TradeReferenceControllers(),
                                      );
                                    });
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Add another reference'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _section(
                  title: '4. Supporting documents',
                  subtitle:
                      'Optional documents can help the supplier assess your application. Files are private to you and the supplier you are applying to.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E2DE)),
                        ),
                        child: const Text(
                          'Accepted examples: commercial credit report, recent supplier statements, financial statement or trade-reference documents. PDF/JPG/PNG, maximum 10 MB each.',
                          style: TextStyle(
                            color: Color(0xFF606060),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickDocuments,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Choose Documents'),
                      ),
                      if (_documents.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (var index = 0; index < _documents.length; index++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(_documents[index].fileName),
                            subtitle: Text(
                              '${(_documents[index].bytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
                            ),
                            trailing: IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _documents.removeAt(index);
                                      });
                                    },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _section(
                  title: '5. Permissions & declaration',
                  subtitle:
                      'These permissions apply only to this application and this supplier.',
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _tradeReferenceConsent,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I authorise this supplier to contact the trade references I have provided for the purpose of assessing this VIP/Trade application.',
                        ),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                setState(() {
                                  _tradeReferenceConsent = value ?? false;
                                });
                              },
                      ),
                      if (creditRequested)
                        CheckboxListTile(
                          value: _commercialCreditConsent,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'I authorise this supplier to undertake reasonable commercial credit checks for the purpose of assessing the requested business credit account.',
                          ),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _commercialCreditConsent = value ?? false;
                                  });
                                },
                        ),
                      if (creditRequested)
                        CheckboxListTile(
                          value: _consumerCreditReportConsent,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Optional: where legally permitted and relevant to the commercial credit assessment, I consent to this supplier requesting consumer credit information about me. CutLink does not obtain this report and ticking this box does not require the supplier to perform a check.',
                          ),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _consumerCreditReportConsent =
                                        value ?? false;
                                  });
                                },
                        ),
                      CheckboxListTile(
                        value: _privacyAccepted,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I understand that the application information and uploaded documents are provided to this supplier for assessment and are not shared with other suppliers.',
                        ),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                setState(() {
                                  _privacyAccepted = value ?? false;
                                });
                              },
                      ),
                      CheckboxListTile(
                        value: _declarationAccepted,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I declare that the information I have provided is true and complete to the best of my knowledge, and I understand that VIP pricing or credit approval remains at the supplier’s discretion.',
                        ),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                setState(() {
                                  _declarationAccepted = value ?? false;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _darkRed),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _submitting
                          ? 'Submitting Application...'
                          : 'Submit VIP Application',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Submitting an application does not guarantee VIP pricing, credit approval or particular payment terms. The supplier independently makes the commercial decision.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF707070),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _applicationTypeCard({
    required String value,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = _applicationType == value;

    return Material(
      color: selected
          ? _darkRed.withValues(alpha: 0.055)
          : const Color(0xFFF9F9F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _submitting
            ? null
            : () {
                setState(() {
                  _applicationType = value;
                });
              },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _darkRed : const Color(0xFFE0E0DD),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? _darkRed.withValues(alpha: 0.10)
                      : const Color(0xFFF0F0ED),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: selected ? _darkRed : const Color(0xFF606060),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected ? _darkRed : const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? _darkRed : const Color(0xFFAAAAAA),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _darkRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: _darkRed,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _supplierName(),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Your Standard Price access is unchanged while this application is reviewed.',
                  style: TextStyle(color: Color(0xFF606060), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _referenceCard(int index) {
    final reference = _references[index];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F7),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E2DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trade Reference ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (_references.length > 2)
                IconButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          setState(() {
                            final removed = _references.removeAt(index);
                            removed.dispose();
                          });
                        },
                  tooltip: 'Remove reference',
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _twoColumns(
            TextFormField(
              controller: reference.businessName,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Business / supplier name',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: reference.contactName,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Contact name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _twoColumns(
            TextFormField(
              controller: reference.email,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Contact email',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: reference.phone,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _twoColumns(
            TextFormField(
              controller: reference.contactPosition,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Contact position (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: reference.yearsTrading,
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Years trading with them (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _twoColumns(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _TradeReferenceControllers {
  final businessName = TextEditingController();
  final contactName = TextEditingController();
  final contactPosition = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final yearsTrading = TextEditingController();
  final notes = TextEditingController();

  void dispose() {
    businessName.dispose();
    contactName.dispose();
    contactPosition.dispose();
    email.dispose();
    phone.dispose();
    yearsTrading.dispose();
    notes.dispose();
  }
}

class _PendingDocument {
  const _PendingDocument({
    required this.fileName,
    required this.bytes,
    required this.extension,
  });

  final String fileName;
  final Uint8List bytes;
  final String? extension;
}
