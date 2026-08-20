import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierVipApplicationsPage extends StatefulWidget {
  const SupplierVipApplicationsPage({super.key});

  @override
  State<SupplierVipApplicationsPage> createState() =>
      _SupplierVipApplicationsPageState();
}

class _SupplierVipApplicationsPageState
    extends State<SupplierVipApplicationsPage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _loading = true;
  String? _error;

  String _filter = 'pending';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _applications = [];

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

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<String> _resolveSupplierBusinessId() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You are not signed in.');
    }

    final memberships = await client
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

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', ids);

    for (final business in _maps(businesses)) {
      if (business['business_type']?.toString() == 'supplier' &&
          business['active'] != false) {
        return business['id'].toString();
      }
    }

    throw Exception('No active supplier business was found.');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supplierId = await _resolveSupplierBusinessId();

      final response = await Supabase.instance.client
          .from('vip_trade_applications')
          .select('''
            id,
            supplier_business_id,
            butcher_business_id,
            status,
            application_type,
            application_purpose,
            butcher_trading_name_snapshot,
            butcher_legal_name_snapshot,
            butcher_abn_snapshot,
            butcher_email_snapshot,
            butcher_phone_snapshot,
            butcher_address_snapshot,
            primary_contact_name,
            primary_contact_position,
            years_trading,
            estimated_monthly_purchases,
            requested_payment_terms_days,
            requested_credit_limit,
            application_message,
            trade_reference_contact_consent,
            commercial_credit_assessment_consent,
            consumer_credit_report_consent,
            privacy_notice_accepted,
            applicant_declaration_accepted,
            submitted_at,
            decided_at,
            created_at,
            vip_trade_application_references(
              id,
              reference_order,
              business_name,
              contact_name,
              contact_position,
              contact_email,
              contact_phone,
              years_trading_with_reference,
              notes
            ),
            vip_trade_application_documents(
              id,
              document_type,
              file_name,
              storage_path,
              mime_type,
              file_size_bytes,
              created_at
            )
          ''')
          .eq('supplier_business_id', supplierId)
          .order('submitted_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _applications = _maps(response);
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

  List<Map<String, dynamic>> get _filteredApplications {
    final search = _searchController.text.trim().toLowerCase();

    return _applications.where((application) {
      if (_filter != 'all' && application['status']?.toString() != _filter) {
        return false;
      }

      if (search.isEmpty) return true;

      final values = [
        application['butcher_trading_name_snapshot'],
        application['butcher_legal_name_snapshot'],
        application['butcher_abn_snapshot'],
        application['butcher_email_snapshot'],
        application['butcher_phone_snapshot'],
        application['primary_contact_name'],
      ];

      return values.any(
        (value) =>
            value != null && value.toString().toLowerCase().contains(search),
      );
    }).toList();
  }

  int _statusCount(String status) {
    return _applications
        .where((row) => row['status']?.toString() == status)
        .length;
  }

  String _butcherName(Map<String, dynamic> application) {
    final trading = application['butcher_trading_name_snapshot']
        ?.toString()
        .trim();
    final legal = application['butcher_legal_name_snapshot']?.toString().trim();

    if (trading != null && trading.isNotEmpty) return trading;
    if (legal != null && legal.isNotEmpty) return legal;

    return 'CutLink Butcher';
  }

  String _statusLabel(Map<String, dynamic> application) {
    final value = application['status']?.toString();
    final purpose = application['application_purpose']?.toString();

    return switch (value) {
      'pending' => 'Pending Review',
      'approved' =>
        purpose == 'credit_upgrade' ? 'Credit Approved' : 'VIP Approved',
      'declined' =>
        purpose == 'credit_upgrade' ? 'Credit Declined' : 'Declined',
      'withdrawn' => 'Withdrawn',
      'superseded' => 'Superseded',
      _ => value ?? 'Unknown',
    };
  }

  Color _statusColor(String? value) {
    return switch (value) {
      'pending' => const Color(0xFF9A6500),
      'approved' => const Color(0xFF23683A),
      'declined' => const Color(0xFF9A3030),
      'withdrawn' => const Color(0xFF686868),
      _ => const Color(0xFF686868),
    };
  }

  String _money(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    if (number == null) return '—';

    final parts = number.toStringAsFixed(2).split('.');
    final reversed = parts.first.split('').reversed.toList();
    final grouped = <String>[];

    for (var i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) grouped.add(',');
      grouped.add(reversed[i]);
    }

    return '\$${grouped.reversed.join()}.${parts[1]}';
  }

  String _dateTime(dynamic value) {
    if (value == null) return '—';

    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  String _applicationTypeLabel(Map<String, dynamic> application) {
    if (application['application_purpose']?.toString() == 'credit_upgrade') {
      return 'Credit Account Application';
    }

    return application['application_type']?.toString() ==
            'vip_pricing_and_credit'
        ? 'VIP Pricing + Credit'
        : 'VIP Pricing Only';
  }

  Future<void> _openApplication(Map<String, dynamic> application) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SupplierVipApplicationDetailPage(application: application),
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'VIP Applications',
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
        constraints: const BoxConstraints(maxWidth: 1150),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 50),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Butcher VIP applications',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Review applications made directly to your supplier business. Your decisions, internal notes, credit settings and customer relationship remain private to your business.',
                        style: TextStyle(
                          color: Color(0xFF606060),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                _countBadge(
                  'Pending',
                  _statusCount('pending'),
                  const Color(0xFF9A6500),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search butcher, ABN, email or contact',
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('Pending', 'pending'),
                _filterChip('Approved', 'approved'),
                _filterChip('Declined', 'declined'),
                _filterChip('All', 'all'),
              ],
            ),
            const SizedBox(height: 18),
            if (_filteredApplications.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 60,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0DD)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.workspace_premium_outlined,
                      size: 56,
                      color: Color(0xFF8A8A8A),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No VIP applications here',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final application in _filteredApplications) ...[
                _applicationCard(application),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;

    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) {
        setState(() => _filter = value);
      },
      selectedColor: _darkRed.withValues(alpha: 0.10),
      side: BorderSide(color: selected ? _darkRed : const Color(0xFFDADAD7)),
      labelStyle: TextStyle(
        color: selected ? _darkRed : const Color(0xFF555555),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _countBadge(String label, int count, Color colour) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: colour,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: colour,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _applicationCard(Map<String, dynamic> application) {
    final status = application['status']?.toString();
    final statusColour = _statusColor(status);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E0DD)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openApplication(application),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _darkRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.storefront_outlined, color: _darkRed),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _butcherName(application),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _applicationTypeLabel(application),
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submitted ${_dateTime(application['submitted_at'])}',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 13,
                      ),
                    ),
                    if (application['estimated_monthly_purchases'] != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Estimated monthly purchases: '
                        '${_money(application['estimated_monthly_purchases'])}',
                        style: const TextStyle(color: Color(0xFF555555)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColour.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(application),
                      style: TextStyle(
                        color: statusColour,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open Application',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right),
                    ],
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

class SupplierVipApplicationDetailPage extends StatefulWidget {
  const SupplierVipApplicationDetailPage({
    super.key,
    required this.application,
  });

  final Map<String, dynamic> application;

  @override
  State<SupplierVipApplicationDetailPage> createState() =>
      _SupplierVipApplicationDetailPageState();
}

class _SupplierVipApplicationDetailPageState
    extends State<SupplierVipApplicationDetailPage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _processing = false;

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _name() {
    final trading = widget.application['butcher_trading_name_snapshot']
        ?.toString()
        .trim();
    final legal = widget.application['butcher_legal_name_snapshot']
        ?.toString()
        .trim();

    if (trading != null && trading.isNotEmpty) return trading;
    if (legal != null && legal.isNotEmpty) return legal;

    return 'CutLink Butcher';
  }

  bool get _isCreditUpgrade =>
      widget.application['application_purpose']?.toString() == 'credit_upgrade';

  bool get _creditRequested =>
      _isCreditUpgrade ||
      widget.application['application_type']?.toString() ==
          'vip_pricing_and_credit';

  String get _approvalActionLabel {
    if (_isCreditUpgrade) return 'Approve Credit Account';
    if (_creditRequested) return 'Approve VIP + Credit';
    return 'Approve VIP Pricing';
  }

  String get _approvalDialogTitle {
    if (_isCreditUpgrade) return 'Approve Credit Account';
    if (_creditRequested) return 'Approve VIP + Credit Application';
    return 'Approve VIP Application';
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _money(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    if (number == null) return '—';
    return '\$${number.toStringAsFixed(2)}';
  }

  String _date(dynamic value) {
    if (value == null) return '—';

    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final path = document['storage_path']?.toString();

    if (path == null || path.isEmpty) {
      _message('Document path is missing.');
      return;
    }

    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('vip-application-documents')
          .createSignedUrl(path, 300);

      final uri = Uri.tryParse(signedUrl);
      if (uri == null) {
        throw Exception('The secure document link could not be created.');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );

      if (!launched) {
        throw Exception('The document could not be opened.');
      }
    } on StorageException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _approve() async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _VipApprovalDialog(
        title: _approvalDialogTitle,
        creditRequested: _creditRequested,
        creditUpgradeOnly: _isCreditUpgrade,
        requestedTermsDays:
            (widget.application['requested_payment_terms_days'] as num?)
                ?.toInt(),
        requestedCreditLimit:
            (widget.application['requested_credit_limit'] as num?)?.toDouble(),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    if (_creditRequested) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              _isCreditUpgrade
                  ? 'Confirm credit approval'
                  : 'Confirm VIP and credit approval',
            ),
            content: Text(
              _isCreditUpgrade
                  ? 'This will activate a credit account for ${_name()} using the approved payment terms and credit limit you entered.'
                  : 'This will activate VIP pricing for ${_name()} and also approve the requested credit account using the terms you entered.',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Go Back'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirm Approval'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    }

    setState(() => _processing = true);

    try {
      await Supabase.instance.client.rpc(
        'approve_vip_trade_application',
        params: {
          'p_application_id': widget.application['id'],
          'p_internal_notes': result['internal_notes'],
          'p_risk_rating': result['risk_rating'],
          'p_approved_payment_method': result['payment_method'],
          'p_approved_payment_terms_days': result['payment_terms_days'],
          'p_approved_credit_limit': result['credit_limit'],
        },
      );

      if (!mounted) return;

      final message = _isCreditUpgrade
          ? '${_name()} approved for a credit account.'
          : _creditRequested
          ? '${_name()} approved for VIP pricing and credit.'
          : '${_name()} approved for VIP pricing.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _decline() async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _isCreditUpgrade
                ? 'Decline credit application for ${_name()}?'
                : 'Decline ${_name()}?',
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isCreditUpgrade
                      ? 'This declines only the credit application. ${_name()} will keep any existing VIP pricing already approved by your supplier business.'
                      : 'This only declines the VIP application made to your supplier business. It does not affect the butcher’s CutLink account or their relationship with another supplier.',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Internal decline notes (optional)',
                    hintText: 'Private to your supplier business',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9A3030),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                _isCreditUpgrade ? 'Decline Credit' : 'Decline Application',
              ),
            ),
          ],
        );
      },
    );

    final notes = notesController.text.trim();
    notesController.dispose();

    if (confirmed != true) return;

    setState(() => _processing = true);

    try {
      await Supabase.instance.client.rpc(
        'decline_vip_trade_application',
        params: {
          'p_application_id': widget.application['id'],
          'p_internal_notes': notes,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isCreditUpgrade
                ? 'Credit application declined. Existing VIP pricing remains unchanged.'
                : 'VIP application declined.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final references =
        _maps(widget.application['vip_trade_application_references'])..sort(
          (a, b) => ((a['reference_order'] as num?)?.toInt() ?? 0).compareTo(
            (b['reference_order'] as num?)?.toInt() ?? 0,
          ),
        );

    final documents = _maps(
      widget.application['vip_trade_application_documents'],
    );

    final pending = widget.application['status']?.toString() == 'pending';
    final creditRequested = _creditRequested;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Review Application • ${_name()}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 80),
            children: [
              _section(
                title: 'Application',
                child: Column(
                  children: [
                    _detailRow(
                      'Request',
                      _isCreditUpgrade
                          ? 'Credit Account Upgrade'
                          : creditRequested
                          ? 'VIP Pricing + Credit Account'
                          : 'VIP Pricing Only',
                    ),
                    _detailRow(
                      'Submitted',
                      _date(widget.application['submitted_at']),
                    ),
                    _detailRow(
                      'Primary contact',
                      _value(widget.application['primary_contact_name']),
                    ),
                    _detailRow(
                      'Position',
                      _value(widget.application['primary_contact_position']),
                    ),
                    _detailRow(
                      'Years trading',
                      _value(widget.application['years_trading']),
                    ),
                    _detailRow(
                      'Estimated monthly purchases',
                      _money(widget.application['estimated_monthly_purchases']),
                    ),
                    if (creditRequested) ...[
                      _detailRow(
                        'Requested terms',
                        widget.application['requested_payment_terms_days'] ==
                                null
                            ? '—'
                            : '${widget.application['requested_payment_terms_days']} days',
                      ),
                      _detailRow(
                        'Requested credit limit',
                        _money(widget.application['requested_credit_limit']),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section(
                title: 'Registered CutLink business',
                child: Column(
                  children: [
                    _detailRow(
                      'Trading name',
                      _value(
                        widget.application['butcher_trading_name_snapshot'],
                      ),
                    ),
                    _detailRow(
                      'Legal name',
                      _value(widget.application['butcher_legal_name_snapshot']),
                    ),
                    _detailRow(
                      'ABN',
                      _value(widget.application['butcher_abn_snapshot']),
                    ),
                    _detailRow(
                      'Email',
                      _value(widget.application['butcher_email_snapshot']),
                    ),
                    _detailRow(
                      'Phone',
                      _value(widget.application['butcher_phone_snapshot']),
                    ),
                    _detailRow(
                      'Address',
                      _value(widget.application['butcher_address_snapshot']),
                    ),
                  ],
                ),
              ),
              if (_value(widget.application['application_message']) != '—') ...[
                const SizedBox(height: 16),
                _section(
                  title: 'Message from butcher',
                  child: Text(
                    _value(widget.application['application_message']),
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _section(
                title: 'Trade references',
                child: references.isEmpty
                    ? const Text('No trade references supplied.')
                    : Column(
                        children: [
                          for (
                            var index = 0;
                            index < references.length;
                            index++
                          ) ...[
                            _referenceCard(references[index], index + 1),
                            if (index != references.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _section(
                title: 'Supporting documents',
                child: documents.isEmpty
                    ? const Text('No supporting documents supplied.')
                    : Column(
                        children: [
                          for (final document in documents)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.description_outlined),
                              title: Text(
                                document['file_name']?.toString() ?? 'Document',
                              ),
                              subtitle: Text(
                                document['document_type']
                                        ?.toString()
                                        .replaceAll('_', ' ') ??
                                    '',
                              ),
                              trailing: OutlinedButton.icon(
                                onPressed: () => _openDocument(document),
                                icon: const Icon(Icons.lock_open_outlined),
                                label: const Text('Open'),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _section(
                title: 'Permissions supplied',
                child: Column(
                  children: [
                    _permissionRow(
                      'Trade references may be contacted',
                      widget.application['trade_reference_contact_consent'] ==
                          true,
                    ),
                    if (creditRequested)
                      _permissionRow(
                        'Commercial credit assessment consent',
                        widget.application['commercial_credit_assessment_consent'] ==
                            true,
                      ),
                    if (creditRequested)
                      _permissionRow(
                        'Consumer credit report consent',
                        widget.application['consumer_credit_report_consent'] ==
                            true,
                        optional: true,
                      ),
                    _permissionRow(
                      'Privacy notice accepted',
                      widget.application['privacy_notice_accepted'] == true,
                    ),
                    _permissionRow(
                      'Applicant declaration accepted',
                      widget.application['applicant_declaration_accepted'] ==
                          true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD6E0D7)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, color: Color(0xFF35613B)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This application belongs only to your supplier business. Your decision, risk assessment, internal notes, payment terms and credit limit are not shared with another supplier.',
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
              if (pending) ...[
                const SizedBox(height: 22),
                _section(
                  title: 'Supplier decision',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Review the full application above before making your decision.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _processing ? null : _decline,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF9A3030),
                                minimumSize: const Size.fromHeight(50),
                              ),
                              icon: const Icon(Icons.close),
                              label: Text(
                                _isCreditUpgrade
                                    ? 'Decline Credit'
                                    : 'Decline Application',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _processing ? null : _approve,
                              style: FilledButton.styleFrom(
                                backgroundColor: _darkRed,
                                minimumSize: const Size.fromHeight(50),
                              ),
                              icon: _processing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(_approvalActionLabel),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 210,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceCard(Map<String, dynamic> reference, int number) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E2DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reference $number • ${_value(reference['business_name'])}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Contact: ${_value(reference['contact_name'])}'),
          Text('Email: ${_value(reference['contact_email'])}'),
          Text('Phone: ${_value(reference['contact_phone'])}'),
          if (reference['years_trading_with_reference'] != null)
            Text(
              'Trading relationship: '
              '${reference['years_trading_with_reference']} years',
            ),
        ],
      ),
    );
  }

  Widget _permissionRow(String label, bool accepted, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.check_circle : Icons.remove_circle_outline,
            color: accepted ? const Color(0xFF23683A) : const Color(0xFF777777),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              optional ? '$label (optional)' : label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipApprovalDialog extends StatefulWidget {
  const _VipApprovalDialog({
    required this.title,
    required this.creditRequested,
    required this.creditUpgradeOnly,
    this.requestedTermsDays,
    this.requestedCreditLimit,
  });

  final String title;
  final bool creditRequested;
  final bool creditUpgradeOnly;
  final int? requestedTermsDays;
  final double? requestedCreditLimit;

  @override
  State<_VipApprovalDialog> createState() => _VipApprovalDialogState();
}

class _VipApprovalDialogState extends State<_VipApprovalDialog> {
  String _riskRating = 'manual_review';
  late String _paymentMethod;

  late final TextEditingController _termsController;
  late final TextEditingController _creditLimitController;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _paymentMethod = widget.creditRequested ? 'account' : 'cod';

    _termsController = TextEditingController(
      text: '${widget.requestedTermsDays ?? 14}',
    );

    _creditLimitController = TextEditingController(
      text: widget.requestedCreditLimit == null
          ? ''
          : widget.requestedCreditLimit!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _termsController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _paymentMethod == 'account';

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.creditUpgradeOnly
                    ? 'Existing VIP pricing remains active. This decision only controls the butcher’s credit account with your supplier business.'
                    : widget.creditRequested
                    ? 'VIP pricing and the credit account will apply only to this butcher with your supplier business.'
                    : 'VIP pricing will be enabled only for this butcher with your supplier business.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _riskRating,
                decoration: const InputDecoration(
                  labelText: 'Internal risk assessment',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'manual_review',
                    child: Text('Manual review / not rated'),
                  ),
                  DropdownMenuItem(value: 'low', child: Text('Low risk')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium risk')),
                  DropdownMenuItem(value: 'high', child: Text('High risk')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _riskRating = value);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Approved payment method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cod', child: Text('COD')),
                  DropdownMenuItem(value: 'prepaid', child: Text('Prepaid')),
                  DropdownMenuItem(
                    value: 'account',
                    child: Text('Credit account'),
                  ),
                ],
                onChanged: widget.creditRequested
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _paymentMethod = value);
                      },
              ),
              if (widget.creditRequested) ...[
                const SizedBox(height: 8),
                const Text(
                  'This application requests credit, so approval requires a credit account payment method.',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
              if (account) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _termsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Payment terms',
                          suffixText: 'days',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _creditLimitController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Credit limit',
                          prefixText: '\$',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Internal review notes',
                  hintText:
                      'Private to your supplier business. Not visible to the butcher or another supplier.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          onPressed: () {
            final terms = int.tryParse(_termsController.text.trim());
            final creditText = _creditLimitController.text.trim();
            final creditLimit = creditText.isEmpty
                ? null
                : double.tryParse(creditText);

            if (account && (terms == null || terms <= 0)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Enter valid payment terms for a credit account.',
                  ),
                ),
              );
              return;
            }

            if (creditText.isNotEmpty &&
                (creditLimit == null || creditLimit < 0)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid credit limit.')),
              );
              return;
            }

            Navigator.of(context).pop({
              'risk_rating': _riskRating,
              'payment_method': _paymentMethod,
              'payment_terms_days': account ? terms : 0,
              'credit_limit': account ? creditLimit : null,
              'internal_notes': _notesController.text.trim(),
            });
          },
          child: Text(widget.title),
        ),
      ],
    );
  }
}
