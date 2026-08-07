import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'marketplace_product_details_page.dart';

class MarketplaceProductsPage extends StatefulWidget {
  const MarketplaceProductsPage({super.key});

  @override
  State<MarketplaceProductsPage> createState() =>
      _MarketplaceProductsPageState();
}

class _MarketplaceProductsPageState extends State<MarketplaceProductsPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('''
            id,
            sku,
            product_name,
            brand,
            temperature_state,
            available_quantity,
            quantity_unit,
            availability_status,
            supplier_business_id,
            active,
            businesses(
              legal_name,
              trading_name
            ),
            animal_types(name),
            cuts(name),
            product_prices(
              amount,
              price_basis,
              minimum_quantity,
              active,
              price_lists(
                id,
                name,
                visibility,
                active
              )
            )
            ''')
          .eq('active', true)
          .order('product_name');

      if (!mounted) {
        return;
      }

      final products = List<Map<String, dynamic>>.from(response);

      setState(() {
        _products = products;
        _filteredProducts = products;
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

  void _applySearch() {
    final search = _searchController.text.trim().toLowerCase();

    setState(() {
      if (search.isEmpty) {
        _filteredProducts = List<Map<String, dynamic>>.from(_products);
        return;
      }

      _filteredProducts = _products.where((product) {
        final animalType = product['animal_types'] as Map<String, dynamic>?;

        final cut = product['cuts'] as Map<String, dynamic>?;

        final supplier = product['businesses'] as Map<String, dynamic>?;

        final searchableValues = [
          product['product_name'],
          product['sku'],
          product['brand'],
          animalType?['name'],
          cut?['name'],
          supplier?['trading_name'],
          supplier?['legal_name'],
        ];

        return searchableValues.any((value) {
          return value != null &&
              value.toString().toLowerCase().contains(search);
        });
      }).toList();
    });
  }

  Map<String, dynamic>? _findVisiblePrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List || rawPrices.isEmpty) {
      return null;
    }

    for (final rawPrice in rawPrices) {
      if (rawPrice is! Map) {
        continue;
      }

      final price = Map<String, dynamic>.from(rawPrice);

      if (price['active'] == true) {
        return price;
      }
    }

    return null;
  }

  String _formatPriceBasis(String? value) {
    switch (value) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'carton';
      case 'unit':
        return 'unit';
      default:
        return '';
    }
  }

  String _formatAvailability(String? value) {
    switch (value) {
      case 'in_stock':
        return 'In stock';
      case 'limited':
        return 'Limited';
      case 'out_of_stock':
        return 'Out of stock';
      case 'made_to_order':
        return 'Made to order';
      default:
        return 'Unknown';
    }
  }

  String _supplierName(Map<String, dynamic> product) {
    final supplier = product['businesses'] as Map<String, dynamic>?;

    final tradingName = supplier?['trading_name'] as String?;

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName;
    }

    return supplier?['legal_name'] as String? ?? 'Unknown supplier';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Browse Products',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadProducts,
            tooltip: 'Refresh products',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search product, cut, brand or supplier',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
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
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 18),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadProducts,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No matching marketplace products were found.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _filteredProducts.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 14);
          },
          itemBuilder: (context, index) {
            final product = _filteredProducts[index];

            final animalType = product['animal_types'] as Map<String, dynamic>?;

            final cut = product['cuts'] as Map<String, dynamic>?;

            final price = _findVisiblePrice(product);

            final amount = price?['amount'];

            final priceBasis = price?['price_basis'] as String?;

            return Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          MarketplaceProductDetailsPage(product: product),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 680;

                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['product_name'] as String? ??
                                'Unnamed product',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _supplierName(product),
                            style: const TextStyle(
                              color: Color(0xFF741C1C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            '${animalType?['name'] ?? ''} • '
                            '${cut?['name'] ?? ''} • '
                            '${product['temperature_state'] ?? ''}',
                            style: const TextStyle(color: Color(0xFF5E5E5E)),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  _formatAvailability(
                                    product['availability_status'] as String?,
                                  ),
                                ),
                              ),
                              if (product['brand'] != null)
                                Chip(label: Text(product['brand'].toString())),
                            ],
                          ),
                        ],
                      );

                      final pricing = Column(
                        crossAxisAlignment: isNarrow
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.end,
                        children: [
                          if (amount == null)
                            const Text(
                              'Price unavailable',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF666666),
                              ),
                            )
                          else
                            Text(
                              '\$$amount / '
                              '${_formatPriceBasis(priceBasis)}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF741C1C),
                              ),
                            ),
                          if (price?['minimum_quantity'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                'Minimum: '
                                '${price?['minimum_quantity']}',
                              ),
                            ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            details,
                            const SizedBox(height: 18),
                            pricing,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 24),
                          pricing,
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
