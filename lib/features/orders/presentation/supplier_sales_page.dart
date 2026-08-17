import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_create_order_page.dart';
import 'supplier_invoices_page.dart';
import 'supplier_orders_page.dart';
import 'supplier_work_orders_page.dart';

class SupplierSalesPage extends StatefulWidget {
  const SupplierSalesPage({super.key});

  @override
  State<SupplierSalesPage> createState() => _SupplierSalesPageState();
}

class _SupplierSalesPageState extends State<SupplierSalesPage> {
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadStock();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
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

  Future<void> _loadStock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final supplierBusinessId = await _resolveSupplierBusinessId();

      final response = await client
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
          .order('product_name');

      if (!mounted) {
        return;
      }

      setState(() {
        _products = (response as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
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

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();

    if (search.isEmpty) {
      return _products;
    }

    return _products.where((product) {
      final name = product['product_name']?.toString().toLowerCase() ?? '';
      final sku = product['sku']?.toString().toLowerCase() ?? '';

      return name.contains(search) || sku.contains(search);
    }).toList();
  }

  bool _isCatchWeight(Map<String, dynamic> product) {
    return product['weight_type']?.toString() == 'catch_weight' ||
        product['catch_weight'] == true;
  }

  Map<String, dynamic>? _standardPrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List) {
      return null;
    }

    for (final raw in rawPrices) {
      if (raw is! Map) {
        continue;
      }

      final price = Map<String, dynamic>.from(raw);

      if (price['active'] != true) {
        continue;
      }

      final rawList = price['price_lists'];

      if (rawList is! Map) {
        continue;
      }

      final list = Map<String, dynamic>.from(rawList);

      if (list['active'] == true &&
          list['visibility']?.toString() == 'public') {
        return price;
      }
    }

    return null;
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return 'No standard price';
    }

    final fixed = number.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final decimal = parts.last;

    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '\$${buffer.toString()}.$decimal';
  }

  String _basisLabel(Map<String, dynamic> product) {
    if (_isCatchWeight(product)) {
      return 'kg';
    }

    final basis = product['price_basis']?.toString();

    switch (basis) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'carton';
      case 'unit':
        return 'unit';
      default:
        return basis ?? 'unit';
    }
  }

  String _quantityLabel(Map<String, dynamic> product) {
    final quantity = product['available_quantity'];
    final unit = product['quantity_unit']?.toString();

    if (quantity == null) {
      return 'Availability not entered';
    }

    final number = quantity is num
        ? quantity.toDouble()
        : double.tryParse(quantity.toString());

    final quantityText = number == null
        ? quantity.toString()
        : number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);

    final unitText = switch (unit) {
      'carton' => 'cartons',
      'kilogram' => 'kg',
      'unit' => 'units',
      _ => unit ?? '',
    };

    return '$quantityText${unitText.isEmpty ? '' : ' $unitText'}';
  }

  String _availabilityLabel(String? value) {
    return switch (value) {
      'in_stock' => 'In stock',
      'limited' => 'Limited',
      'out_of_stock' => 'Out of stock',
      'made_to_order' => 'Made to order',
      _ => 'Unknown',
    };
  }

  Future<void> _openNewSale({String? initialProductId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SupplierCreateOrderPage(initialProductId: initialProductId),
      ),
    );

    if (mounted) {
      await _loadStock();
    }
  }

  Future<void> _openOrders() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SupplierOrdersPage()));

    if (mounted) {
      await _loadStock();
    }
  }

  Future<void> _openWorkOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SupplierWorkOrdersPage()),
    );

    if (mounted) {
      await _loadStock();
    }
  }

  Future<void> _openInvoices() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SupplierInvoicesPage()),
    );

    if (mounted) {
      await _loadStock();
    }
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 245,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E5E5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: _darkRed),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final standardPrice = _standardPrice(product);
    final price = standardPrice?['amount'];
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['product_name']?.toString() ?? 'Unnamed product',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product['sku']?.toString() ?? 'No SKU',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        _availabilityLabel(
                          product['availability_status']?.toString(),
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(_quantityLabel(product)),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (catchWeight)
                      const Chip(
                        label: Text('Catch weight • order by carton'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            );

            final priceColumn = Column(
              crossAxisAlignment: narrow
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
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
                  price == null
                      ? 'Not set'
                      : '${_money(price)} / ${_basisLabel(product)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openNewSale(initialProductId: product['id']?.toString()),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('Add to Sale'),
                ),
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 16), priceColumn],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 24),
                priceColumn,
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
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadStock,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredProducts;

    return RefreshIndicator(
      onRefresh: _loadStock,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
        children: [
          const Text(
            'Sales',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Search your own stock and manage the sale from order through warehouse fulfilment and invoicing.',
            style: TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _actionCard(
                icon: Icons.point_of_sale_outlined,
                title: 'New Sale',
                description:
                    'Select a customer and create a phone, email, sales rep or manual order.',
                onTap: () => _openNewSale(),
              ),
              _actionCard(
                icon: Icons.receipt_long_outlined,
                title: 'Sales Orders',
                description:
                    'Review submitted, accepted and processing customer orders.',
                onTap: _openOrders,
              ),
              _actionCard(
                icon: Icons.assignment_outlined,
                title: 'Work Orders',
                description:
                    'Send accepted sales to the warehouse for picking and weighing.',
                onTap: _openWorkOrders,
              ),
              _actionCard(
                icon: Icons.request_quote_outlined,
                title: 'Invoices',
                description:
                    'Open finalised sales invoices and track invoice status.',
                onTap: _openInvoices,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Search Inventory',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'This search only shows stock belonging to your supplier business.',
            style: TextStyle(color: Color(0xFF666666)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search product name or SKU',
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No stock matches your search.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            )
          else
            ...filtered.map(_buildProductCard),
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
          'Supplier Sales',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadStock,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }
}
