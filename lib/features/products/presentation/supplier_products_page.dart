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

      final memberships = await Supabase.instance.client
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

      final businesses = await Supabase.instance.client
          .from('businesses')
          .select('id, business_type, active')
          .inFilter('id', businessIds)
          .eq('active', true);

      String? businessId;

      for (final raw in businesses) {
        if (raw['business_type']?.toString() == 'supplier') {
          businessId = raw['id']?.toString();
          break;
        }
      }

      if (businessId == null || businessId.isEmpty) {
        throw Exception('No active supplier business membership was found.');
      }

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

            marbling_score,
            grade,
            breed_program,
            piece_weight_min,
            piece_weight_max,
            piece_weight_unit,
            carton_weight,
            carton_weight_unit,
            pieces_per_carton,
            packaging_type,
            trim_specification,
            fat_specification,
            halal_status,
            supplier_specification,

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

  String _formatNumber(dynamic value) {
    if (value == null) {
      return '';
    }

    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return value.toString();
    }

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _weightRange(Map<String, dynamic> product) {
    final min = product['piece_weight_min'];
    final max = product['piece_weight_max'];
    final unit = product['piece_weight_unit']?.toString();

    if (min == null && max == null) {
      return '';
    }

    final suffix = unit == null || unit.trim().isEmpty ? '' : ' $unit';

    if (min != null && max != null) {
      return '${_formatNumber(min)}–${_formatNumber(max)}$suffix';
    }

    if (min != null) {
      return '${_formatNumber(min)}+$suffix';
    }

    return 'Up to ${_formatNumber(max)}$suffix';
  }

  String _cartonDetails(Map<String, dynamic> product) {
    final cartonWeight = product['carton_weight'];
    final cartonUnit = product['carton_weight_unit']?.toString();
    final piecesPerCarton = product['pieces_per_carton'];

    final parts = <String>[];

    if (cartonWeight != null) {
      final suffix = cartonUnit == null || cartonUnit.trim().isEmpty
          ? ''
          : ' $cartonUnit';
      parts.add('${_formatNumber(cartonWeight)}$suffix');
    }

    if (piecesPerCarton != null) {
      parts.add('${_formatNumber(piecesPerCarton)} pcs');
    }

    return parts.join(' • ');
  }

  String _availableQuantityText(Map<String, dynamic> product) {
    final quantity = product['available_quantity'];
    final unit = product['quantity_unit']?.toString();

    if (quantity == null) {
      return '';
    }

    final label = switch (unit) {
      'kilogram' => 'kg',
      'carton' => 'cartons',
      'unit' => 'units',
      _ => unit ?? '',
    };

    return '${_formatNumber(quantity)}${label.isEmpty ? '' : ' $label'}';
  }

  String _halalLabel(String? value) {
    switch (value) {
      case 'halal':
        return 'Halal';
      case 'not_halal':
        return 'Not halal';
      default:
        return '';
    }
  }

  Widget _specChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE1E1DE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF5A5A5A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4E4E4E),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSpecificationChips(Map<String, dynamic> product) {
    final chips = <Widget>[];

    final brand = product['brand']?.toString();
    final marbling = product['marbling_score']?.toString();
    final grade = product['grade']?.toString();
    final breedProgram = product['breed_program']?.toString();
    final pieceWeight = _weightRange(product);
    final carton = _cartonDetails(product);
    final packaging = product['packaging_type']?.toString();
    final trim = product['trim_specification']?.toString();
    final fat = product['fat_specification']?.toString();
    final halal = _halalLabel(product['halal_status']?.toString());
    final originCountry = product['origin_country']?.toString();
    final originState = product['origin_state']?.toString();
    final available = _availableQuantityText(product);

    if (brand != null && brand.trim().isNotEmpty) {
      chips.add(_specChip(icon: Icons.sell_outlined, label: brand.trim()));
    }

    if (marbling != null && marbling.trim().isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.auto_awesome_outlined,
          label:
              'MB ${marbling.trim().replaceFirst(RegExp(r'^mb\s*', caseSensitive: false), '')}',
        ),
      );
    }

    if (grade != null && grade.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.workspace_premium_outlined, label: grade.trim()),
      );
    }

    if (breedProgram != null && breedProgram.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.badge_outlined, label: breedProgram.trim()),
      );
    }

    if (pieceWeight.isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.scale_outlined, label: 'Piece $pieceWeight'),
      );
    }

    if (carton.isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.inventory_2_outlined, label: 'Carton $carton'),
      );
    }

    if (packaging != null && packaging.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.all_inbox_outlined, label: packaging.trim()),
      );
    }

    if (trim != null && trim.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.content_cut_outlined, label: trim.trim()),
      );
    }

    if (fat != null && fat.trim().isNotEmpty) {
      chips.add(_specChip(icon: Icons.straighten_outlined, label: fat.trim()));
    }

    if (halal.isNotEmpty) {
      chips.add(_specChip(icon: Icons.verified_outlined, label: halal));
    }

    final originParts = <String>[
      if (originState != null && originState.trim().isNotEmpty)
        originState.trim(),
      if (originCountry != null && originCountry.trim().isNotEmpty)
        originCountry.trim(),
    ];

    if (originParts.isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.public_outlined, label: originParts.join(', ')),
      );
    }

    if (available.isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.inventory_outlined,
          label: 'Available $available',
        ),
      );
    }

    if (product['catch_weight'] == true) {
      chips.add(
        _specChip(icon: Icons.monitor_weight_outlined, label: 'Catch weight'),
      );
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'My Stock',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadProducts,
            tooltip: 'Refresh stock',
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
                'Stock could not be loaded',
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
                  'No stock yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Add your first product to begin building your supplier stock list.',
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
          final specificationChips = _buildSpecificationChips(product);

          final supplierSpecification = product['supplier_specification']
              ?.toString();

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
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
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              Text(
                                product['product_name'] as String? ??
                                    'Unnamed product',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  _formatStatus(
                                    product['availability_status'] as String?,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (product['active'] == false)
                                const Chip(
                                  label: Text('Inactive'),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text(
                            product['sku']?.toString() ?? 'No SKU',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4E4E4E),
                            ),
                          ),

                          const SizedBox(height: 7),

                          Text(
                            cataloguePath,
                            style: const TextStyle(
                              color: Color(0xFF5E5E5E),
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 8),

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

                          if (specificationChips.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: specificationChips,
                            ),
                          ],

                          if (supplierSpecification != null &&
                              supplierSpecification.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              supplierSpecification.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Color(0xFF777777)),
                  ],
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
