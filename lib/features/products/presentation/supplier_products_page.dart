import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_product_page.dart';
import 'edit_product_page.dart';

class SupplierProductsPage extends StatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  State<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends State<SupplierProductsPage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];

  final Map<String, Map<String, dynamic>> _cataloguePathsByProductId = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final businessId = membership['business_id'] as String;

      final response = await Supabase.instance.client
          .from('products')
          .select('''
                id,
                supplier_business_id,
                product_variant_id,
                animal_type_id,
                cut_id,
                sku,
                product_name,
                description,
                brand,
                origin_country,
                origin_state,
                temperature_state,
                price_basis,
                catch_weight,
                available_quantity,
                quantity_unit,
                availability_status,
                active,
                created_at,

                animal_types(name),
                cuts(name),

                product_variants(
                  id,
                  meat_product_id,
                  variant_name,
                  temperature_state,
                  bone_state
                )
                ''')
          .eq('supplier_business_id', businessId)
          .order('created_at', ascending: false);

      final products = List<Map<String, dynamic>>.from(response);

      final meatProductIds = <String>{};

      for (final product in products) {
        final variant = _variant(product);

        final meatProductId = variant?['meat_product_id']?.toString();

        if (meatProductId != null && meatProductId.isNotEmpty) {
          meatProductIds.add(meatProductId);
        }
      }

      final cataloguePathsByProductId = <String, Map<String, dynamic>>{};

      if (meatProductIds.isNotEmpty) {
        final pathResponse = await Supabase.instance.client
            .from('meat_product_catalogue_paths')
            .select('''
                  id,
                  species_id,
                  species_name,
                  parent_product_id,
                  name,
                  slug,
                  product_level,
                  depth,
                  catalogue_path
                  ''')
            .inFilter('id', meatProductIds.toList());

        for (final rawPath in pathResponse) {
          final path = Map<String, dynamic>.from(rawPath);

          final id = path['id']?.toString();

          if (id != null) {
            cataloguePathsByProductId[id] = path;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;

        _cataloguePathsByProductId
          ..clear()
          ..addAll(cataloguePathsByProductId);

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

  Future<void> _openAddProductPage() async {
    final productCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddProductPage()),
    );

    if (productCreated == true) {
      await _loadProducts();
    }
  }

  Map<String, dynamic>? _variant(Map<String, dynamic> product) {
    final raw = product['product_variants'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return null;
  }

  Map<String, dynamic>? _cataloguePathRecord(Map<String, dynamic> product) {
    final variant = _variant(product);

    final meatProductId = variant?['meat_product_id']?.toString();

    if (meatProductId == null || meatProductId.isEmpty) {
      return null;
    }

    return _cataloguePathsByProductId[meatProductId];
  }

  String _cataloguePath(Map<String, dynamic> product) {
    final variant = _variant(product);

    final pathRecord = _cataloguePathRecord(product);

    if (variant != null && pathRecord != null) {
      final parts = <String>[];

      final speciesName = pathRecord['species_name']?.toString();

      final cataloguePath = pathRecord['catalogue_path']?.toString();

      final variantName = variant['variant_name']?.toString();

      if (speciesName != null && speciesName.trim().isNotEmpty) {
        parts.add(speciesName);
      }

      if (cataloguePath != null && cataloguePath.trim().isNotEmpty) {
        parts.add(cataloguePath);
      }

      if (variantName != null && variantName.trim().isNotEmpty) {
        parts.add(variantName);
      }

      if (parts.isNotEmpty) {
        return parts.join(' → ');
      }
    }

    //
    // Legacy catalogue fallback.
    //
    final rawAnimalType = product['animal_types'];

    final rawCut = product['cuts'];

    String? animalName;
    String? cutName;

    if (rawAnimalType is Map) {
      animalName = rawAnimalType['name']?.toString();
    }

    if (rawCut is Map) {
      cutName = rawCut['name']?.toString();
    }

    final legacyParts = <String>[
      if (animalName != null && animalName.trim().isNotEmpty) animalName,
      if (cutName != null && cutName.trim().isNotEmpty) cutName,
    ];

    if (legacyParts.isNotEmpty) {
      return legacyParts.join(' → ');
    }

    return 'Catalogue not linked';
  }

  bool _usesNewCatalogue(Map<String, dynamic> product) {
    return product['product_variant_id'] != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Products',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProductPage,
        backgroundColor: const Color(0xFF741C1C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
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
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 18),
              const Text(
                'Products could not be loaded',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
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

    if (_products.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 80,
                  color: Color(0xFF741C1C),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No products yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Create your first product to begin building your supplier catalogue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    color: Color(0xFF5E5E5E),
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _openAddProductPage,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF741C1C),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 17,
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Product'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        itemCount: _products.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 14);
        },
        itemBuilder: (context, index) {
          final product = _products[index];

          final cataloguePath = _cataloguePath(product);

          final usesNewCatalogue = _usesNewCatalogue(product);

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              onTap: () async {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => EditProductPage(product: product),
                  ),
                );

                if (updated == true) {
                  await _loadProducts();
                }
              },
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4E5E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF741C1C),
                ),
              ),
              title: Text(
                product['product_name'] as String? ?? 'Unnamed product',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['sku']?.toString() ?? 'No SKU'),

                    const SizedBox(height: 5),

                    Text(
                      cataloguePath,
                      style: const TextStyle(
                        color: Color(0xFF5E5E5E),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          usesNewCatalogue
                              ? Icons.account_tree_outlined
                              : Icons.history,
                          size: 16,
                          color: usesNewCatalogue
                              ? const Color(0xFF741C1C)
                              : const Color(0xFF777777),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          usesNewCatalogue
                              ? 'Recursive catalogue'
                              : 'Legacy catalogue',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: usesNewCatalogue
                                ? const Color(0xFF741C1C)
                                : const Color(0xFF777777),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Chip(
                label: Text(
                  _formatStatus(product['availability_status'] as String?),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatStatus(String? value) {
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
}
