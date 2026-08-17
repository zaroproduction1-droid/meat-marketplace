import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_create_order_page.dart';
import 'supplier_invoice_page.dart';
import 'supplier_work_order_page.dart';

class SupplierSalesPage extends StatefulWidget {
  const SupplierSalesPage({super.key});

  @override
  State<SupplierSalesPage> createState() => _SupplierSalesPageState();
}

class _SupplierSalesPageState extends State<SupplierSalesPage>
    with SingleTickerProviderStateMixin {
  static const _darkRed = Color(0xFF741C1C);

  late final TabController _tabController;

  final TextEditingController _stockSearchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _quotes = [];
  List<Map<String, dynamic>> _workOrders = [];
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _stockSearchController.addListener(_refresh);
    _loadSalesDesk();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stockSearchController.removeListener(_refresh);
    _stockSearchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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
      for (final raw in memberships)
        if (raw['business_id'] != null) raw['business_id'].toString(),
    ];

    if (businessIds.isEmpty) {
      throw Exception('No active business membership was found.');
    }

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', businessIds)
        .eq('active', true);

    for (final raw in businesses) {
      if (raw['business_type']?.toString() == 'supplier') {
        final id = raw['id']?.toString();

        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    }

    throw Exception('No active supplier business membership was found.');
  }

  Future<void> _loadSalesDesk() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final supplierBusinessId = await _resolveSupplierBusinessId();

      final results = await Future.wait([
        client
            .from('products')
            .select('''
              id,
              sku,
              product_name,
              available_quantity,
              quantity_unit,
              availability_status,
              active,
              order_unit,
              price_basis,
              weight_type,
              catch_weight,
              product_prices(
                id,
                amount,
                price_basis,
                active,
                price_lists(
                  id,
                  name,
                  visibility,
                  active
                )
              )
            ''')
            .eq('supplier_business_id', supplierBusinessId)
            .eq('active', true)
            .order('product_name'),
        client
            .from('orders')
            .select('''
              id,
              order_number,
              quote_revision,
              quote_last_saved_at,
              status,
              order_source,
              customer_reference,
              delivery_fee,
              fulfilment_method,
              requested_fulfilment_date,
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
            .order('created_at', ascending: false),
        client
            .from('warehouse_work_orders')
            .select('''
              id,
              order_id,
              work_order_number,
              status,
              created_at,
              orders(
                id,
                order_number,
                supplier_customer_accounts(
                  id,
                  customer_name,
                  legal_name
                ),
                order_items(
                  id,
                  fulfilment_status
                )
              )
            ''')
            .eq('supplier_business_id', supplierBusinessId)
            .order('created_at', ascending: false),
        client
            .from('invoices')
            .select('''
              id,
              invoice_number,
              order_id,
              status,
              customer_name_snapshot,
              products_subtotal,
              delivery_fee,
              tax_status,
              total_amount,
              invoice_date,
              due_date,
              created_at
            ''')
            .eq('supplier_business_id', supplierBusinessId)
            .order('created_at', ascending: false),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _products = _maps(results[0]);
        _quotes = _maps(results[1]);
        _workOrders = _maps(results[2]);
        _invoices = _maps(results[3]);
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

  List<Map<String, dynamic>> _maps(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }

    return null;
  }

  List<Map<String, dynamic>> _nestedList(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _stockSearchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _products;
    }

    return _products.where((product) {
      final name = product['product_name']?.toString().toLowerCase() ?? '';
      final sku = product['sku']?.toString().toLowerCase() ?? '';

      return name.contains(query) || sku.contains(query);
    }).toList();
  }

  bool _isCatchWeight(Map<String, dynamic> product) {
    return product['catch_weight'] == true ||
        product['weight_type']?.toString() == 'catch_weight';
  }

  Map<String, dynamic>? _standardPrice(Map<String, dynamic> product) {
    final prices = _nestedList(product['product_prices']);

    for (final price in prices) {
      if (price['active'] != true) {
        continue;
      }

      final list = _nestedMap(price['price_lists']);

      if (list?['active'] == true &&
          list?['visibility']?.toString() == 'public') {
        return price;
      }
    }

    return null;
  }

  String _money(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    if (number == null) {
      return '—';
    }

    final fixed = number.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final decimal = parts.last;

    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '\$${buffer.toString()}.$decimal';
  }

  String _productAvailability(Map<String, dynamic> product) {
    final status = product['availability_status']?.toString();

    return switch (status) {
      'in_stock' => 'In stock',
      'limited' => 'Limited',
      'out_of_stock' => 'Out of stock',
      'made_to_order' => 'Made to order',
      _ => 'Availability not set',
    };
  }

  String _quoteDisplayNumber(Map<String, dynamic> quote) {
    final number = quote['order_number']?.toString() ?? 'Quote';
    final revision = (quote['quote_revision'] as num?)?.toInt() ?? 0;

    if (revision <= 0) {
      return number;
    }

    return '$number #$revision';
  }

  Future<void> _editQuote(Map<String, dynamic> quote) async {
    final orderId = quote['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierCreateOrderPage(quoteOrderId: orderId),
      ),
    );

    if (mounted) {
      await _loadSalesDesk();
    }
  }

  String _customerName(Map<String, dynamic> quote) {
    final account = _nestedMap(quote['supplier_customer_accounts']);

    final customerName = account?['customer_name']?.toString().trim();
    final legalName = account?['legal_name']?.toString().trim();

    if (customerName != null && customerName.isNotEmpty) {
      return customerName;
    }

    if (legalName != null && legalName.isNotEmpty) {
      return legalName;
    }

    return 'Customer';
  }

  Future<void> _openNewSale({String? productId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SupplierCreateOrderPage(initialProductId: productId),
      ),
    );

    if (mounted) {
      await _loadSalesDesk();
    }
  }

  Future<void> _convertQuoteToWorkOrder(Map<String, dynamic> quote) async {
    final quoteId = quote['id']?.toString();

    if (quoteId == null || quoteId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Convert Quote to Work Order?'),
        content: Text(
          'Convert ${quote['order_number'] ?? 'this quote'} for '
          '${_customerName(quote)} into a live warehouse work order?\n\n'
          'The agreed rates remain locked. Catch-weight final totals stay pending until actual supplied weight is entered.',
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

    if (confirmed != true) {
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'convert_supplier_quote_to_sales_order',
        params: {'target_order_id': quoteId},
      );

      await Supabase.instance.client.rpc(
        'create_or_get_warehouse_work_order',
        params: {'target_order_id': quoteId},
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SupplierWorkOrderPage(orderId: quoteId),
        ),
      );

      if (mounted) {
        await _loadSalesDesk();
        _tabController.animateTo(2);
      }
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openWorkOrder(Map<String, dynamic> workOrder) async {
    final orderId = workOrder['order_id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierWorkOrderPage(orderId: orderId),
      ),
    );

    if (mounted) {
      await _loadSalesDesk();
    }
  }

  Future<void> _openInvoice(Map<String, dynamic> invoice) async {
    final orderId = invoice['order_id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierInvoicePage(orderId: orderId),
      ),
    );

    if (mounted) {
      await _loadSalesDesk();
    }
  }

  Widget _newSaleTab() {
    final products = _filteredProducts;

    return RefreshIndicator(
      onRefresh: _loadSalesDesk,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Sale',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Search your own stock while speaking to the customer, then save a quote or create a warehouse work order.',
                      style: TextStyle(color: Color(0xFF666666), height: 1.4),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                onPressed: () => _openNewSale(),
                icon: const Icon(Icons.add),
                label: const Text('Start New Sale'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _stockSearchController,
            decoration: InputDecoration(
              hintText: 'Search product name or SKU',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _stockSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _stockSearchController.clear,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(
                child: Text(
                  'No stock matches your search.',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            ...products.map((product) {
              final standardPrice = _standardPrice(product);
              final catchWeight = _isCatchWeight(product);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['product_name']?.toString() ??
                                  'Unnamed product',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product['sku']?.toString() ?? 'No SKU',
                              style: const TextStyle(color: Color(0xFF666666)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(_productAvailability(product)),
                                ),
                                if (catchWeight)
                                  const Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      'Catch weight • final total after weighing',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Standard Price',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            standardPrice == null
                                ? 'Not set'
                                : '${_money(standardPrice['amount'])} / ${catchWeight ? 'kg' : standardPrice['price_basis'] ?? product['price_basis'] ?? 'unit'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => _openNewSale(
                              productId: product['id']?.toString(),
                            ),
                            icon: const Icon(Icons.point_of_sale_outlined),
                            label: const Text('Use in Sale'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _quotesTab() {
    if (_quotes.isEmpty) {
      return _emptyTab(
        icon: Icons.description_outlined,
        title: 'No saved quotes',
        message:
            'Pricing enquiries saved from the Sales Desk will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSalesDesk,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _quotes.length,
        itemBuilder: (context, index) {
          final quote = _quotes[index];
          final items = _nestedList(quote['order_items']);

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _editQuote(quote),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _quoteDisplayNumber(quote),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _customerName(quote),
                            style: const TextStyle(
                              color: _darkRed,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${items.length} line${items.length == 1 ? '' : 's'}'
                            ' • ${quote['fulfilment_method']?.toString() == 'pickup' ? 'Pickup' : 'Delivery'}'
                            '${quote['requested_fulfilment_date'] == null ? '' : ' • ${quote['requested_fulfilment_date']}'}',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Catch-weight quote totals remain pending until actual supplied weight is recorded.',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _editQuote(quote),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Open / Edit Quote'),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _darkRed,
                          ),
                          onPressed: () => _convertQuoteToWorkOrder(quote),
                          icon: const Icon(Icons.assignment_outlined),
                          label: const Text('Create Work Order'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _workOrdersTab() {
    if (_workOrders.isEmpty) {
      return _emptyTab(
        icon: Icons.assignment_outlined,
        title: 'No work orders',
        message: 'Live warehouse jobs created by Sales will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSalesDesk,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _workOrders.length,
        itemBuilder: (context, index) {
          final workOrder = _workOrders[index];
          final order = _nestedMap(workOrder['orders']);
          final account = _nestedMap(order?['supplier_customer_accounts']);
          final items = _nestedList(order?['order_items']);
          final finalised = items
              .where(
                (item) => item['fulfilment_status']?.toString() == 'finalised',
              )
              .length;

          final customer =
              account?['customer_name']?.toString() ??
              account?['legal_name']?.toString() ??
              'Customer';

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              onTap: () => _openWorkOrder(workOrder),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF4E5E5),
                foregroundColor: _darkRed,
                child: Icon(Icons.assignment_outlined),
              ),
              title: Text(
                workOrder['work_order_number']?.toString() ?? 'Work Order',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '$customer • ${order?['order_number'] ?? ''}\n'
                  '$finalised / ${items.length} lines finalised',
                ),
              ),
              trailing: Chip(
                label: Text(
                  workOrder['status']?.toString().replaceAll('_', ' ') ??
                      'created',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _invoicesTab() {
    if (_invoices.isEmpty) {
      return _emptyTab(
        icon: Icons.request_quote_outlined,
        title: 'No invoices',
        message:
            'Invoices created after warehouse fulfilment will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSalesDesk,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _invoices.length,
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          final total = invoice['total_amount'];

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              onTap: () => _openInvoice(invoice),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF4E5E5),
                foregroundColor: _darkRed,
                child: Icon(Icons.request_quote_outlined),
              ),
              title: Text(
                invoice['invoice_number']?.toString() ?? 'Invoice',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${invoice['customer_name_snapshot'] ?? 'Customer'}'
                  '${invoice['due_date'] == null ? '' : ' • Due ${invoice['due_date']}'}',
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    total == null ? 'Pending' : _money(total),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoice['status']?.toString().replaceAll('_', ' ') ??
                        'draft',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyTab({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return RefreshIndicator(
      onRefresh: _loadSalesDesk,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),
          Icon(icon, size: 64, color: const Color(0xFFAAAAAA)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
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
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadSalesDesk,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [_newSaleTab(), _quotesTab(), _workOrdersTab(), _invoicesTab()],
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
          'Sales',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loadSalesDesk,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _darkRed,
          indicatorColor: _darkRed,
          tabs: [
            const Tab(
              icon: Icon(Icons.point_of_sale_outlined),
              text: 'New Sale',
            ),
            Tab(
              icon: const Icon(Icons.description_outlined),
              text: 'Quotes (${_quotes.length})',
            ),
            Tab(
              icon: const Icon(Icons.assignment_outlined),
              text: 'Work Orders (${_workOrders.length})',
            ),
            Tab(
              icon: const Icon(Icons.request_quote_outlined),
              text: 'Invoices (${_invoices.length})',
            ),
          ],
        ),
      ),
      body: _body(),
    );
  }
}
