import '../../../shared/widgets/phone_layout.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_customer_account_page.dart';
import 'supplier_customer_profile_dialog.dart';
import '../services/customer_account_service.dart';
import 'supplier_vip_applications_page.dart';

class SupplierCustomerRequestsPage extends StatefulWidget {
  const SupplierCustomerRequestsPage({super.key});

  @override
  State<SupplierCustomerRequestsPage> createState() =>
      _SupplierCustomerRequestsPageState();
}

class _SupplierCustomerRequestsPageState
    extends State<SupplierCustomerRequestsPage> {
  static const _darkRed = Color(0xFF741C1C);

  bool _isLoading = true;
  String? _errorMessage;
  String? _supplierBusinessId;

  List<Map<String, dynamic>> _relationships = [];
  List<Map<String, dynamic>> _customerAccounts = [];
  List<Map<String, dynamic>> _accountSummaries = [];
  int _pendingVipApplicationCount = 0;

  final TextEditingController _customerSearchController =
      TextEditingController();
  String _appliedCustomerSearch = '';

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final memberships = await client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active');

      final businessIds = <String>[
        for (final raw in memberships)
          if (raw['business_id'] != null) raw['business_id'].toString(),
      ];

      if (businessIds.isEmpty) {
        throw Exception('No active business membership was found.');
      }

      final supplierBusinesses = await client
          .from('businesses')
          .select('id, business_type, active, verification_status')
          .inFilter('id', businessIds)
          .eq('business_type', 'supplier')
          .eq('active', true)
          .eq('verification_status', 'approved');

      if (supplierBusinesses.isEmpty) {
        throw Exception('No active approved supplier business was found.');
      }

      final supplierBusinessId = supplierBusinesses.first['id']?.toString();

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception('Your supplier business could not be identified.');
      }

      final directoryResponse = await client.rpc(
        'list_cutlink_butchers_for_supplier',
      );

      final relationshipRows = <Map<String, dynamic>>[];

      for (final raw in List<Map<String, dynamic>>.from(
        directoryResponse as List,
      )) {
        relationshipRows.add({
          'id': raw['relationship_id'],
          'butcher_business_id': raw['butcher_business_id'],
          'status': raw['relationship_status'],
          'account_reference': raw['account_reference'],
          'credit_terms': raw['credit_terms'],
          'payment_method': raw['payment_method'],
          'payment_terms_days': raw['payment_terms_days'],
          'credit_limit': raw['credit_limit'],
          'issue_reporting_window_hours': raw['issue_reporting_window_hours'],
          'created_at': raw['relationship_created_at'],
          'approved_at': raw['approved_at'],
          'businesses': {
            'id': raw['butcher_business_id'],
            'legal_name': raw['butcher_legal_name'],
            'trading_name': raw['butcher_trading_name'],
            'abn': raw['butcher_abn'],
            'business_email': raw['butcher_email'],
            'business_phone': raw['butcher_phone'],
            'address_line_1': raw['butcher_address_line_1'],
            'address_line_2': raw['butcher_address_line_2'],
            'suburb': raw['butcher_suburb'],
            'state': raw['butcher_state'],
            'postcode': raw['butcher_postcode'],
          },
        });
      }

      final accountResponse = await client
          .from('supplier_customer_accounts')
          .select()
          .eq('supplier_business_id', supplierBusinessId)
          .order('customer_name');

      final pendingVipApplications = await client
          .from('vip_trade_applications')
          .select('id')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'pending');

      final accountSummaryResponse = await client.rpc(
        'list_supplier_account_summaries',
        params: {'due_soon_days': 7},
      );

      final pendingVipCount = pendingVipApplications.length;

      if (!mounted) {
        return;
      }

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _relationships = relationshipRows;
        _customerAccounts = List<Map<String, dynamic>>.from(accountResponse);
        _accountSummaries = List<Map<String, dynamic>>.from(
          accountSummaryResponse as List,
        );
        _pendingVipApplicationCount = pendingVipCount;
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

  Map<String, dynamic>? _accountForRelationship(
    Map<String, dynamic> relationship,
  ) {
    final relationshipId = relationship['id']?.toString();
    final butcherId = relationship['butcher_business_id']?.toString();

    for (final account in _customerAccounts) {
      if (relationshipId != null &&
          account['supplier_customer_relationship_id']?.toString() ==
              relationshipId) {
        return account;
      }

      if (butcherId != null &&
          account['linked_butcher_business_id']?.toString() == butcherId) {
        return account;
      }
    }

    return null;
  }

  String _businessName(Map<String, dynamic> relationship) {
    final business = relationship['businesses'] as Map<String, dynamic>?;

    final tradingName = business?['trading_name']?.toString().trim();
    if (tradingName != null && tradingName.isNotEmpty) {
      return tradingName;
    }

    final legalName = business?['legal_name']?.toString().trim();
    if (legalName != null && legalName.isNotEmpty) {
      return legalName;
    }

    return 'Unknown butcher';
  }

  String _accountName(Map<String, dynamic> account) {
    final name = account['customer_name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final legalName = account['legal_name']?.toString().trim();
    if (legalName != null && legalName.isNotEmpty) {
      return legalName;
    }

    return 'Customer';
  }

  Map<String, dynamic>? _summaryForAccount(Map<String, dynamic> account) {
    final accountId = account['id']?.toString();
    if (accountId == null) {
      return null;
    }

    for (final summary in _accountSummaries) {
      if (summary['supplier_customer_account_id']?.toString() == accountId) {
        return summary;
      }
    }

    return null;
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _asDouble(value);
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _shortDate(dynamic value) {
    if (value == null) {
      return '—';
    }
    final date = DateTime.tryParse(value.toString());
    if (date == null) {
      return '—';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _accountStatusLabel(String? status) {
    switch (status) {
      case 'overdue':
        return 'Overdue';
      case 'due_soon':
        return 'Due Soon';
      case 'open':
        return 'Open';
      case 'credit_available':
        return 'Credit Available';
      case 'clear':
        return 'Clear';
      default:
        return 'Open';
    }
  }

  Color _accountStatusColor(String? status) {
    switch (status) {
      case 'overdue':
        return const Color(0xFFB3261E);
      case 'due_soon':
        return const Color(0xFF9A5B00);
      case 'credit_available':
        return const Color(0xFF315A8C);
      case 'clear':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF666666);
    }
  }

  Future<void> _openCustomerAccount(Map<String, dynamic> account) async {
    final id = account['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SupplierCustomerAccountPage(supplierCustomerAccountId: id),
      ),
    );

    if (mounted) {
      await _loadPage();
    }
  }

  Future<Map<String, dynamic>?> _accountForOpening(
    Map<String, dynamic> relationship,
  ) async {
    final existing = _accountForRelationship(relationship);
    if (existing != null) {
      return existing;
    }

    await _ensureCustomerAccountForRelationship(relationship);

    final supplierBusinessId = _supplierBusinessId;
    final butcherBusinessId = relationship['butcher_business_id']?.toString();
    if (supplierBusinessId == null || butcherBusinessId == null) {
      return null;
    }

    final response = await Supabase.instance.client
        .from('supplier_customer_accounts')
        .select()
        .eq('supplier_business_id', supplierBusinessId)
        .eq('linked_butcher_business_id', butcherBusinessId)
        .maybeSingle();

    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<void> _openRelationshipAccount(
    Map<String, dynamic> relationship,
  ) async {
    try {
      final account = await _accountForOpening(relationship);
      if (account == null) {
        throw Exception('The customer account could not be opened.');
      }
      if (!mounted) {
        return;
      }
      await _openCustomerAccount(account);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _editRelationshipAccount(
    Map<String, dynamic> relationship,
  ) async {
    try {
      final account = await _accountForOpening(relationship);
      if (account == null) {
        throw Exception('The customer account could not be opened.');
      }
      if (!mounted) {
        return;
      }
      await _editCustomerAccount(account);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _updateStatus({
    required Map<String, dynamic> relationship,
    required String status,
  }) async {
    final relationshipId = relationship['id']?.toString();

    if (relationshipId == null || relationshipId.isEmpty) {
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final updates = <String, dynamic>{
        'status': status,
        'updated_at': now,
        'approved_at': status == 'approved' ? now : null,
      };

      await Supabase.instance.client
          .from('supplier_customer_relationships')
          .update(updates)
          .eq('id', relationshipId);

      if (status == 'approved') {
        await _ensureCustomerAccountForRelationship(relationship);
      }

      if (!mounted) {
        return;
      }

      final message = switch (status) {
        'approved' => 'Customer access approved.',
        'declined' => 'Customer access declined.',
        'suspended' => 'Customer access suspended.',
        _ => 'Customer relationship updated.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      await _loadPage();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _ensureCustomerAccountForRelationship(
    Map<String, dynamic> relationship,
  ) async {
    final supplierBusinessId = _supplierBusinessId;
    final relationshipId = relationship['id']?.toString();
    final butcherBusinessId = relationship['butcher_business_id']?.toString();
    final business = relationship['businesses'] as Map<String, dynamic>?;

    if (supplierBusinessId == null ||
        butcherBusinessId == null ||
        business == null) {
      return;
    }

    final payload = <String, dynamic>{
      'supplier_business_id': supplierBusinessId,
      'linked_butcher_business_id': butcherBusinessId,
      'supplier_customer_relationship_id': relationshipId,
      'account_source': 'cutlink',
      'customer_name': _businessName(relationship),
      'legal_name': business['legal_name'],
      'abn': business['abn'],
      'email': business['business_email'],
      'phone': business['business_phone'],
      'billing_address_line_1': business['address_line_1'],
      'billing_address_line_2': business['address_line_2'],
      'billing_suburb': business['suburb'],
      'billing_state': business['state'],
      'billing_postcode': business['postcode'],
      'delivery_address_line_1': business['address_line_1'],
      'delivery_address_line_2': business['address_line_2'],
      'delivery_suburb': business['suburb'],
      'delivery_state': business['state'],
      'delivery_postcode': business['postcode'],
      'account_reference': relationship['account_reference'],
      'payment_method': relationship['payment_method'] ?? 'cod',
      'payment_terms_days': relationship['payment_terms_days'] ?? 0,
      'credit_limit': relationship['credit_limit'],
      'issue_reporting_window_hours':
          relationship['issue_reporting_window_hours'] ?? 24,
      'active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final existing = _accountForRelationship(relationship);

    if (existing == null) {
      await Supabase.instance.client
          .from('supplier_customer_accounts')
          .insert(payload);
      return;
    }

    await Supabase.instance.client
        .from('supplier_customer_accounts')
        .update({
          'supplier_customer_relationship_id': relationshipId,
          'account_reference': relationship['account_reference'],
          'payment_method': relationship['payment_method'] ?? 'cod',
          'payment_terms_days': relationship['payment_terms_days'] ?? 0,
          'credit_limit': relationship['credit_limit'],
          'issue_reporting_window_hours':
              relationship['issue_reporting_window_hours'] ?? 24,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', existing['id']);
  }

  Future<void> _openAddExternalCustomerDialog() async {
    final supplierBusinessId = _supplierBusinessId;

    if (supplierBusinessId == null) {
      return;
    }

    final result = await _showCustomerAccountDialog();

    if (result == null) {
      return;
    }

    try {
      await CustomerAccountService.save(
        supplierBusinessId: supplierBusinessId,
        values: result,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('External customer added.')));

      await _loadPage();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editCustomerAccount(Map<String, dynamic> account) async {
    final result = await _showCustomerAccountDialog(account: account);
    if (result == null) {
      return;
    }
    try {
      await CustomerAccountService.save(
        supplierBusinessId: _supplierBusinessId!,
        account: account,
        values: result,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer account updated.')),
      );
      await _loadPage();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PostgrestException ? error.message : error.toString(),
          ),
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _showCustomerAccountDialog({
    Map<String, dynamic>? account,
  }) => showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SupplierCustomerProfileDialog(
      supplierBusinessId: _supplierBusinessId!,
      account: account,
    ),
  );

  String _formatStatus(String? status) {
    return switch (status) {
      'requested' => 'Pending',
      'approved' => 'Approved',
      'declined' => 'Declined',
      'suspended' => 'Suspended',
      _ => 'CutLink Member',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'approved' => Colors.green,
      'declined' => Colors.red,
      'suspended' => Colors.red,
      'requested' => Colors.orange,
      _ => _darkRed,
    };
  }

  IconData _statusIcon(String? status) {
    return switch (status) {
      'approved' => Icons.check_circle_outline,
      'declined' => Icons.cancel_outlined,
      'suspended' => Icons.block,
      'requested' => Icons.schedule,
      _ => Icons.verified_outlined,
    };
  }

  String _paymentText(Map<String, dynamic> account) {
    final method = account['payment_method']?.toString();

    return switch (method) {
      'account' => '${account['payment_terms_days'] ?? 0} day account',
      'prepaid' => 'Prepaid',
      _ => 'COD',
    };
  }

  void _applyCustomerSearch(String value) {
    final query = value.trim();

    setState(() {
      _appliedCustomerSearch = query;
    });
  }

  void _clearCustomerSearch() {
    _customerSearchController.clear();

    setState(() {
      _appliedCustomerSearch = '';
    });
  }

  bool _matchesCustomerSearch(String value) {
    final query = _appliedCustomerSearch.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    return value.toLowerCase().contains(query);
  }

  List<Map<String, dynamic>> get _filteredRelationships {
    return _relationships
        .where(
          (relationship) => _matchesCustomerSearch(_businessName(relationship)),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredManualAccounts {
    return _manualAccounts
        .where((account) => _matchesCustomerSearch(_accountName(account)))
        .toList();
  }

  List<Map<String, dynamic>> get _manualAccounts {
    return _customerAccounts
        .where((account) => account['account_source']?.toString() == 'manual')
        .toList();
  }

  Future<void> _openVipApplications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SupplierVipApplicationsPage(),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadPage();
  }

  Widget _vipApplicationsPanel() {
    final hasPending = _pendingVipApplicationCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasPending ? const Color(0xFFFFF8EB) : const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPending ? const Color(0xFFE6C98A) : const Color(0xFFE0E0DD),
        ),
      ),
      child: Row(
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
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'VIP Applications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (hasPending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9A6500),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_pendingVipApplicationCount pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  hasPending
                      ? 'You have VIP or credit applications waiting for review.'
                      : 'Review VIP pricing and credit applications from CutLink butchers.',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _openVipApplications,
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            icon: const Icon(Icons.open_in_new),
            label: Text(hasPending ? 'Review Now' : 'Open'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E5E8)),
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
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF4E5E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search, color: _darkRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _customerSearchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _applyCustomerSearch,
              decoration: InputDecoration(
                hintText:
                    'Search CutLink members or external customers, then press Enter',
                filled: true,
                fillColor: const Color(0xFFFAFAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFDADAD6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFDADAD6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _darkRed, width: 1.2),
                ),
                suffixIcon: _appliedCustomerSearch.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearCustomerSearch,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: () =>
                _applyCustomerSearch(_customerSearchController.text),
            style: FilledButton.styleFrom(
              backgroundColor: _darkRed,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: phoneAppBar(
        context,
        AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 20,
          title: const Row(
            children: [
              Icon(Icons.people_alt_outlined, color: _darkRed, size: 22),
              SizedBox(width: 10),
              Text(
                'Customers & Accounts',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _openAddExternalCustomerDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: _darkRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text(
                  'Add External Customer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _loadPage,
              tooltip: 'Refresh customers and accounts',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 10),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE4E6E8)),
          ),
        ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;

        Widget cutLinkList() {
          final rows = _filteredRelationships;

          if (rows.isEmpty) {
            return _emptyCard(
              icon: Icons.people_outline,
              title: _appliedCustomerSearch.isEmpty
                  ? 'No CutLink members'
                  : 'No matching CutLink members',
              description: _appliedCustomerSearch.isEmpty
                  ? 'Registered CutLink butcher members will appear here.'
                  : 'Try another member name.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) => _buildRelationshipCard(rows[index]),
          );
        }

        Widget externalList() {
          final rows = _filteredManualAccounts;

          if (rows.isEmpty) {
            return _emptyCard(
              icon: Icons.person_add_alt_1_outlined,
              title: _appliedCustomerSearch.isEmpty
                  ? 'No external customers'
                  : 'No matching external customers',
              description: _appliedCustomerSearch.isEmpty
                  ? 'Add customers here for phone, email or sales-rep orders.'
                  : 'Try another customer name.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) => _buildAccountCard(rows[index]),
          );
        }

        Widget panel({
          required String title,
          required String subtitle,
          required Widget child,
          Widget? action,
        }) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E5E8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x07000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
                  child: PhoneRow(
                    mode: PhoneRowMode.wrap,
                    desktop: Row(
                      children: [
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
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ?action,
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        final vip = _vipApplicationsPanel();

        if (!desktop) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              vip,
              const SizedBox(height: 12),
              _buildCustomerSearchBar(),
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: panel(
                  title: 'CutLink Members',
                  subtitle:
                      'Registered CutLink butcher members and account terms.',
                  child: cutLinkList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 420,
                child: panel(
                  title: 'External Customers',
                  subtitle:
                      'Supplier-private phone, email and manual customers.',
                  action: FilledButton.icon(
                    onPressed: _openAddExternalCustomerDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Add'),
                  ),
                  child: externalList(),
                ),
              ),
            ],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                children: [
                  vip,
                  const SizedBox(height: 12),
                  _buildCustomerSearchBar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: panel(
                            title: 'CutLink Members',
                            subtitle:
                                'Registered CutLink butcher members and commercial account settings.',
                            child: cutLinkList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: panel(
                            title: 'External Customers',
                            subtitle:
                                'Supplier-private customers for direct sales.',
                            action: FilledButton.icon(
                              onPressed: _openAddExternalCustomerDialog,
                              style: FilledButton.styleFrom(
                                backgroundColor: _darkRed,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.add, size: 17),
                              label: const Text('Add External'),
                            ),
                            child: externalList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 54, color: _darkRed),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipCard(Map<String, dynamic> relationship) {
    final status = relationship['status']?.toString();
    final account = _accountForRelationship(relationship);
    final summary = account == null ? null : _summaryForAccount(account);

    final outstanding = _asDouble(summary?['outstanding_balance']);
    final overdue = _asDouble(summary?['overdue_amount']);
    final nextDue = _asDouble(summary?['next_amount_due']);
    final nextDate = summary?['next_due_date'];
    final accountStatus = summary?['account_status']?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openRelationshipAccount(relationship),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E5E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: _darkRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _businessName(relationship),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            _statusIcon(status),
                            size: 13,
                            color: _statusColor(status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatStatus(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (account != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _paymentText(account),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _darkRed),
                PopupMenuButton<String>(
                  tooltip: 'Member actions',
                  onSelected: (value) {
                    if (value == 'open') {
                      _openRelationshipAccount(relationship);
                    } else if (value == 'edit') {
                      _editRelationshipAccount(relationship);
                    } else if (value == 'suspend') {
                      _updateStatus(
                        relationship: relationship,
                        status: 'suspended',
                      );
                    } else if (value == 'approve') {
                      _updateStatus(
                        relationship: relationship,
                        status: 'approved',
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Text('Open Account'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Account Settings'),
                    ),
                    if (status == 'approved')
                      const PopupMenuItem(
                        value: 'suspend',
                        child: Text('Suspend Access'),
                      ),
                    if (status == 'suspended' || status == 'declined')
                      const PopupMenuItem(
                        value: 'approve',
                        child: Text('Approve Access'),
                      ),
                  ],
                ),
              ],
            ),
            if (summary != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F6),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: PhoneRow(
                  mode: PhoneRowMode.metrics,
                  desktop: Row(
                    children: [
                      Expanded(
                        child: _financialCompact(
                          'Outstanding',
                          _money(outstanding),
                          outstanding > 0 ? _darkRed : null,
                        ),
                      ),
                      Expanded(
                        child: _financialCompact(
                          'Overdue',
                          _money(overdue),
                          overdue > 0 ? const Color(0xFFB3261E) : null,
                        ),
                      ),
                      Expanded(
                        child: _financialCompact(
                          'Next Due',
                          nextDue > 0
                              ? '${_money(nextDue)}\n${_shortDate(nextDate)}'
                              : '—',
                          null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _accountStatusColor(
                              accountStatus,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _accountStatusLabel(accountStatus),
                            style: TextStyle(
                              color: _accountStatusColor(accountStatus),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (status == 'requested') ...[
              const SizedBox(height: 10),
              PhoneRow(
                mode: PhoneRowMode.wrap,
                desktop: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _updateStatus(
                        relationship: relationship,
                        status: 'declined',
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _updateStatus(
                        relationship: relationship,
                        status: 'approved',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _financialCompact(String label, String value, Color? valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF222222),
            fontSize: 11,
            height: 1.15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final active = account['active'] == true;
    final summary = _summaryForAccount(account);

    final outstanding = _asDouble(summary?['outstanding_balance']);
    final overdue = _asDouble(summary?['overdue_amount']);
    final nextDue = _asDouble(summary?['next_amount_due']);
    final nextDate = summary?['next_due_date'];
    final accountStatus = summary?['account_status']?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openCustomerAccount(account),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E5E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: _darkRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _accountName(account),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${active ? 'Active' : 'Inactive'} • ${_paymentText(account)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF777777),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _darkRed),
                PopupMenuButton<String>(
                  tooltip: 'Customer actions',
                  onSelected: (value) {
                    if (value == 'open') {
                      _openCustomerAccount(account);
                    } else if (value == 'edit') {
                      _editCustomerAccount(account);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Open Account')),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Account Settings'),
                    ),
                  ],
                ),
              ],
            ),
            if (summary != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F6),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: PhoneRow(
                  mode: PhoneRowMode.metrics,
                  desktop: Row(
                    children: [
                      Expanded(
                        child: _financialCompact(
                          'Outstanding',
                          _money(outstanding),
                          outstanding > 0 ? _darkRed : null,
                        ),
                      ),
                      Expanded(
                        child: _financialCompact(
                          'Overdue',
                          _money(overdue),
                          overdue > 0 ? const Color(0xFFB3261E) : null,
                        ),
                      ),
                      Expanded(
                        child: _financialCompact(
                          'Next Due',
                          nextDue > 0
                              ? '${_money(nextDue)}\n${_shortDate(nextDate)}'
                              : '—',
                          null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _accountStatusColor(
                            accountStatus,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _accountStatusLabel(accountStatus),
                          style: TextStyle(
                            color: _accountStatusColor(accountStatus),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
