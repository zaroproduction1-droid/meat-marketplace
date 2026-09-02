import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierQuotesPage extends StatefulWidget {
  const SupplierQuotesPage({
    super.key,
    this.embedded = false,
    this.onQuoteSelected,
  });

  final bool embedded;
  final ValueChanged<String>? onQuoteSelected;

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
            quote_number,
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
    final number =
        quote['quote_number']?.toString() ??
        quote['order_number']?.toString() ??
        'Quote';
    final revision = (quote['quote_revision'] as num?)?.toInt() ?? 0;
    return revision > 0 ? '$number R$revision' : number;
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

    final onQuoteSelected = widget.onQuoteSelected;
    if (onQuoteSelected != null) {
      onQuoteSelected(id);
      return;
    }

    Navigator.of(context).pop(id);
  }

  Widget _quoteCard(Map<String, dynamic> quote) {
    final items = _nestedList(quote['order_items']);
    final activity = _activityDate(quote);
    final pickup = quote['fulfilment_method']?.toString() == 'pickup';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _openQuote(quote),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E0DD)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EAEA),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: _darkRed,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _quoteNumber(quote),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF777777),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _customerName(quote),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkRed,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${items.length} line${items.length == 1 ? '' : 's'}'
                      ' • ${pickup ? 'Pickup' : 'Delivery'}'
                      '${activity == null ? '' : ' • ${_displayDate(activity.toIso8601String())}'}',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
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

    Widget emptyState(String message) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget queuePanel({
      required String title,
      required String subtitle,
      required List<Map<String, dynamic>> data,
      Widget? search,
      required String emptyMessage,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: Color(0xFF777777),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EAEA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${data.length}',
                      style: const TextStyle(
                        color: _darkRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (search != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: search,
              ),
            ],
            const Divider(height: 1),
            Expanded(
              child: data.isEmpty
                  ? emptyState(emptyMessage)
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: data.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (_, index) => _quoteCard(data[index]),
                    ),
            ),
          ],
        ),
      );
    }

    final searchField = TextField(
      controller: _historySearchController,
      decoration: InputDecoration(
        hintText: 'Search quote, customer, product...',
        prefixIcon: const Icon(Icons.search, size: 19),
        suffixIcon: _historySearchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _historySearchController.clear,
                icon: const Icon(Icons.close, size: 18),
              ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8F8F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quotes',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select any quote to reopen it inside the Sales workspace.',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadQuotes,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 850;

                    final todayPanel = queuePanel(
                      title: 'Today',
                      subtitle: 'Created or revised today',
                      data: today,
                      emptyMessage: 'No quotes created or revised today.',
                    );

                    final historyPanel = queuePanel(
                      title: 'Quote History',
                      subtitle: 'Previous saved quotes',
                      data: old,
                      search: searchField,
                      emptyMessage: _historySearchController.text.trim().isEmpty
                          ? 'No previous quotes yet.'
                          : 'No previous quotes match your search.',
                    );

                    if (narrow) {
                      return ListView(
                        children: [
                          SizedBox(height: 360, child: todayPanel),
                          const SizedBox(height: 12),
                          SizedBox(height: 500, child: historyPanel),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: todayPanel),
                        const SizedBox(width: 12),
                        Expanded(flex: 6, child: historyPanel),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFF7F8FA), child: _buildBody());
    }

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
