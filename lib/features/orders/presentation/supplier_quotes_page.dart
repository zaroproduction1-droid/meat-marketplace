import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_work_order_page.dart';

class SupplierQuotesPage extends StatefulWidget {
  const SupplierQuotesPage({super.key});

  @override
  State<SupplierQuotesPage> createState() => _SupplierQuotesPageState();
}

class _SupplierQuotesPageState extends State<SupplierQuotesPage> {
  static const _darkRed = Color(0xFF741C1C);

  final _historySearchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _quotes = [];

  @override
  void initState() {
    super.initState();
    _historySearchController.addListener(_refresh);
    _loadQuotes();
  }

  @override
  void dispose() {
    _historySearchController.removeListener(_refresh);
    _historySearchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<String> _resolveSupplierBusinessId() async {
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
      for (final row in memberships)
        if (row['business_id'] != null) row['business_id'].toString(),
    ];

    if (businessIds.isEmpty) {
      throw Exception('No active business membership was found.');
    }

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', businessIds)
        .eq('active', true);

    for (final row in businesses) {
      if (row['business_type']?.toString() == 'supplier') {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }

    throw Exception('No active supplier business membership was found.');
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supplierBusinessId = await _resolveSupplierBusinessId();

      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            order_number,
            quote_revision,
            quote_last_saved_at,
            status,
            order_source,
            customer_reference,
            fulfilment_method,
            requested_fulfilment_date,
            requested_fulfilment_time,
            created_at,
            supplier_customer_accounts(
              id,
              customer_name,
              legal_name,
              phone,
              email
            ),
            order_items(
              id,
              product_name_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              catch_weight_snapshot
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'draft')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _quotes = (response as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  List<Map<String, dynamic>> _nestedList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _activityDate(Map<String, dynamic> quote) {
    final raw = quote['quote_last_saved_at'] ?? quote['created_at'];
    return raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
  }

  List<Map<String, dynamic>> get _todaysQuotes {
    final start = _startOfToday();
    final tomorrow = start.add(const Duration(days: 1));

    return _quotes.where((quote) {
      final activity = _activityDate(quote);
      return activity != null &&
          !activity.isBefore(start) &&
          activity.isBefore(tomorrow);
    }).toList();
  }

  List<Map<String, dynamic>> get _oldQuotes {
    final start = _startOfToday();
    final query = _historySearchController.text.trim().toLowerCase();

    return _quotes.where((quote) {
      final activity = _activityDate(quote);
      if (activity == null || !activity.isBefore(start)) return false;
      if (query.isEmpty) return true;

      final account = _nestedMap(quote['supplier_customer_accounts']);
      final items = _nestedList(quote['order_items']);

      final searchable = <String>[
        quote['order_number']?.toString() ?? '',
        _quoteNumber(quote),
        account?['customer_name']?.toString() ?? '',
        account?['legal_name']?.toString() ?? '',
        account?['phone']?.toString() ?? '',
        account?['email']?.toString() ?? '',
        quote['customer_reference']?.toString() ?? '',
        quote['created_at']?.toString() ?? '',
        quote['quote_last_saved_at']?.toString() ?? '',
        for (final item in items)
          item['product_name_snapshot']?.toString() ?? '',
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  String _quoteNumber(Map<String, dynamic> quote) {
    final number = quote['order_number']?.toString() ?? 'Quote';
    final revision = (quote['quote_revision'] as num?)?.toInt() ?? 0;
    return revision > 0 ? '$number #$revision' : number;
  }

  String _customerName(Map<String, dynamic> quote) {
    final account = _nestedMap(quote['supplier_customer_accounts']);
    final customer = account?['customer_name']?.toString().trim();
    final legal = account?['legal_name']?.toString().trim();

    if (customer != null && customer.isNotEmpty) return customer;
    if (legal != null && legal.isNotEmpty) return legal;
    return 'Customer';
  }

  String _displayDate(dynamic value) {
    final parsed = value == null
        ? null
        : DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return '';

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  void _openQuote(Map<String, dynamic> quote) {
    final id = quote['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    Navigator.of(context).pop(id);
  }

  Future<void> _convertToWorkOrder(Map<String, dynamic> quote) async {
    final id = quote['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Work Order?'),
        content: Text(
          'Convert ${_quoteNumber(quote)} for ${_customerName(quote)} '
          'into a live warehouse work order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Create Work Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.rpc(
        'convert_supplier_quote_to_sales_order',
        params: {'target_order_id': id},
      );

      await Supabase.instance.client.rpc(
        'create_or_get_warehouse_work_order',
        params: {'target_order_id': id},
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SupplierWorkOrderPage(orderId: id),
        ),
      );

      if (mounted) await _loadQuotes();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget _quoteCard(Map<String, dynamic> quote) {
    final items = _nestedList(quote['order_items']);
    final activity = _activityDate(quote);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0DD)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _quoteNumber(quote),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _customerName(quote),
                  style: const TextStyle(
                    color: _darkRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${items.length} line${items.length == 1 ? '' : 's'}'
                  '${activity == null ? '' : ' • ${_displayDate(activity.toIso8601String())}'}'
                  ' • ${quote['fulfilment_method']?.toString() == 'pickup' ? 'Pickup' : 'Delivery'}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openQuote(quote),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Open / Edit'),
                ),
                FilledButton.icon(
                  onPressed: () => _convertToWorkOrder(quote),
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('Create Work Order'),
                ),
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [details, const SizedBox(height: 14), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      ),
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
              const Icon(Icons.error_outline, size: 56, color: _darkRed),
              const SizedBox(height: 14),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadQuotes,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final today = _todaysQuotes;
    final old = _oldQuotes;

    return RefreshIndicator(
      onRefresh: _loadQuotes,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
        children: [
          const Text(
            'Today’s Quotes',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Quotes created or revised today.',
            style: TextStyle(color: Color(0xFF666666)),
          ),
          const SizedBox(height: 14),
          if (today.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: const Text(
                'No quotes created or revised today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...today.map(_quoteCard),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Previous Quotes',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Search older quotes by customer, quote number, date, phone or product.',
            style: TextStyle(color: Color(0xFF666666)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _historySearchController,
            decoration: InputDecoration(
              hintText: 'Search old quotes',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _historySearchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _historySearchController.clear,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (old.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Text(
                _historySearchController.text.trim().isEmpty
                    ? 'No previous quotes yet.'
                    : 'No previous quotes match your search.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...old.map(_quoteCard),
        ],
      ),
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
          'Quotes',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _buildBody(),
    );
  }
}
