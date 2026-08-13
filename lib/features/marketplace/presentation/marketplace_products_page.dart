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

  final Map<String, Map<String, dynamic>> _cataloguePathsByProductId = {};

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
            description,
            brand,
            origin_country,
            origin_state,
            temperature_state,
            available_quantity,
            quantity_unit,
            availability_status,
            supplier_business_id,
            product_variant_id,
            animal_type_id,
            cut_id,
            active,
            catch_weight,

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

            businesses(
              legal_name,
              trading_name
            ),

            animal_types(name),
            cuts(name),

            product_variants(
              id,
              meat_product_id,
              variant_name,
              temperature_state,
              bone_state
            ),

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

      final products = List<Map<String, dynamic>>.from(response);

      final meatProductIds = <String>{};

      for (final product in products) {
        final variant = _variant(product);
        final meatProductId = variant?['meat_product_id']?.toString();

        if (meatProductId != null && meatProductId.trim().isNotEmpty) {
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
              path_names,
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

      _applySearch();
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

    if (meatProductId == null || meatProductId.trim().isEmpty) {
      return null;
    }

    return _cataloguePathsByProductId[meatProductId];
  }

  List<String> _canonicalCatalogueNames(Map<String, dynamic> product) {
    final names = <String>[];

    final variant = _variant(product);
    final pathRecord = _cataloguePathRecord(product);

    if (variant == null || pathRecord == null) {
      return names;
    }

    final speciesName = pathRecord['species_name']?.toString();

    if (speciesName != null && speciesName.trim().isNotEmpty) {
      names.add(speciesName);
    }

    final rawPathNames = pathRecord['path_names'];

    if (rawPathNames is List) {
      for (final value in rawPathNames) {
        final name = value?.toString();

        if (name != null && name.trim().isNotEmpty) {
          names.add(name);
        }
      }
    } else {
      final cataloguePath = pathRecord['catalogue_path']?.toString();

      if (cataloguePath != null && cataloguePath.trim().isNotEmpty) {
        final pathParts = cataloguePath.split('→');

        for (final rawPart in pathParts) {
          final part = rawPart.trim();

          if (part.isNotEmpty) {
            names.add(part);
          }
        }
      }
    }

    final variantName = variant['variant_name']?.toString();

    if (variantName != null && variantName.trim().isNotEmpty) {
      names.add(variantName);
    }

    return names;
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

    final legacyNames = <String>[
      if (animalName != null && animalName.trim().isNotEmpty) animalName,
      if (cutName != null && cutName.trim().isNotEmpty) cutName,
    ];

    if (legacyNames.isNotEmpty) {
      return legacyNames.join(' → ');
    }

    return 'Catalogue not linked';
  }

  void _applySearch() {
    if (!mounted) {
      return;
    }

    final search = _searchController.text.trim().toLowerCase();

    setState(() {
      if (search.isEmpty) {
        _filteredProducts = List<Map<String, dynamic>>.from(_products);
        return;
      }

      _filteredProducts = _products.where((product) {
        final supplier = product['businesses'];

        String? tradingName;
        String? legalName;

        if (supplier is Map) {
          tradingName = supplier['trading_name']?.toString();
          legalName = supplier['legal_name']?.toString();
        }

        final catalogueNames = _canonicalCatalogueNames(product);
        final fullCataloguePath = _cataloguePath(product);

        final animalType = product['animal_types'];
        final cut = product['cuts'];

        String? legacyAnimal;
        String? legacyCut;

        if (animalType is Map) {
          legacyAnimal = animalType['name']?.toString();
        }

        if (cut is Map) {
          legacyCut = cut['name']?.toString();
        }

        final searchableValues = <dynamic>[
          product['product_name'],
          product['sku'],
          product['brand'],
          product['description'],
          product['origin_country'],
          product['origin_state'],
          product['temperature_state'],
          product['marbling_score'],
          product['grade'],
          product['breed_program'],
          product['packaging_type'],
          product['trim_specification'],
          product['fat_specification'],
          product['halal_status'],
          product['supplier_specification'],
          tradingName,
          legalName,
          fullCataloguePath,
          ...catalogueNames,
          legacyAnimal,
          legacyCut,
        ];

        return searchableValues.any((value) {
          return value != null &&
              value.toString().toLowerCase().contains(search);
        });
      }).toList();
    });
  }

  bool _usesCanonicalCatalogue(Map<String, dynamic> product) {
    return product['product_variant_id'] != null;
  }

  Map<String, dynamic>? _findVisiblePrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List || rawPrices.isEmpty) {
      return null;
    }

    Map<String, dynamic>? bestPrice;
    var bestPriority = 0;

    for (final rawPrice in rawPrices) {
      if (rawPrice is! Map) {
        continue;
      }

      final price = Map<String, dynamic>.from(rawPrice);

      if (price['active'] != true) {
        continue;
      }

      final rawPriceList = price['price_lists'];

      if (rawPriceList is! Map) {
        continue;
      }

      final priceList = Map<String, dynamic>.from(rawPriceList);

      if (priceList['active'] != true) {
        continue;
      }

      final visibility = priceList['visibility'] as String?;

      int priority;

      switch (visibility) {
        case 'private':
          priority = 3;
          break;
        case 'approved_customers':
          priority = 2;
          break;
        case 'public':
          priority = 1;
          break;
        default:
          priority = 0;
      }

      if (priority > bestPriority) {
        bestPriority = priority;
        bestPrice = price;
      }
    }

    return bestPrice;
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

  String _formatTemperature(String? value) {
    switch (value) {
      case 'fresh':
        return 'Fresh';
      case 'chilled':
        return 'Chilled';
      case 'frozen':
        return 'Frozen';
      default:
        return value ?? 'Not specified';
    }
  }

  String _supplierName(Map<String, dynamic> product) {
    final raw = product['businesses'];

    if (raw is! Map) {
      return 'Unknown supplier';
    }

    final supplier = Map<String, dynamic>.from(raw);

    final tradingName = supplier['trading_name']?.toString();

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName;
    }

    return supplier['legal_name']?.toString() ?? 'Unknown supplier';
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

  String _pieceWeightText(Map<String, dynamic> product) {
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

  String _cartonText(Map<String, dynamic> product) {
    final cartonWeight = product['carton_weight'];
    final cartonUnit = product['carton_weight_unit']?.toString();
    final piecesPerCarton = product['pieces_per_carton'];

    final parts = <String>[];

    if (cartonWeight != null) {
      final suffix =
          cartonUnit == null || cartonUnit.trim().isEmpty ? '' : ' $cartonUnit';
      parts.add('${_formatNumber(cartonWeight)}$suffix');
    }

    if (piecesPerCarton != null) {
      parts.add('${_formatNumber(piecesPerCarton)} pcs');
    }

    return parts.join(' • ');
  }

  String _availableText(Map<String, dynamic> product) {
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

  Widget _specChip({
    required IconData icon,
    required String label,
  }) {
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

  List<Widget> _marketplaceChips(
    Map<String, dynamic> product, {
    required bool usesCanonicalCatalogue,
  }) {
    final chips = <Widget>[];

    chips.add(
      _specChip(
        icon: Icons.inventory_2_outlined,
        label: _formatAvailability(product['availability_status'] as String?),
      ),
    );

    final brand = product['brand']?.toString();
    final marbling = product['marbling_score']?.toString();
    final grade = product['grade']?.toString();
    final breedProgram = product['breed_program']?.toString();
    final pieceWeight = _pieceWeightText(product);
    final carton = _cartonText(product);
    final packaging = product['packaging_type']?.toString();
    final trim = product['trim_specification']?.toString();
    final fat = product['fat_specification']?.toString();
    final halal = _halalLabel(product['halal_status']?.toString());
    final originCountry = product['origin_country']?.toString();
    final originState = product['origin_state']?.toString();
    final available = _availableText(product);

    if (brand != null && brand.trim().isNotEmpty) {
      chips.add(_specChip(icon: Icons.sell_outlined, label: brand.trim()));
    }

    if (marbling != null && marbling.trim().isNotEmpty) {
      final clean = marbling
          .trim()
          .replaceFirst(RegExp(r'^mb\s*', caseSensitive: false), '');
      chips.add(
        _specChip(
          icon: Icons.auto_awesome_outlined,
          label: 'MB $clean',
        ),
      );
    }

    if (grade != null && grade.trim().isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.workspace_premium_outlined,
          label: grade.trim(),
        ),
      );
    }

    if (breedProgram != null && breedProgram.trim().isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.badge_outlined,
          label: breedProgram.trim(),
        ),
      );
    }

    if (pieceWeight.isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.scale_outlined,
          label: 'Piece $pieceWeight',
        ),
      );
    }

    if (carton.isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.inventory_2_outlined,
          label: 'Carton $carton',
        ),
      );
    }

    if (packaging != null && packaging.trim().isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.all_inbox_outlined,
          label: packaging.trim(),
        ),
      );
    }

    if (trim != null && trim.trim().isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.content_cut_outlined,
          label: trim.trim(),
        ),
      );
    }

    if (fat != null && fat.trim().isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.straighten_outlined,
          label: fat.trim(),
        ),
      );
    }

    if (halal.isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.verified_outlined,
          label: halal,
        ),
      );
    }

    final originParts = <String>[
      if (originState != null && originState.trim().isNotEmpty)
        originState.trim(),
      if (originCountry != null && originCountry.trim().isNotEmpty)
        originCountry.trim(),
    ];

    if (originParts.isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.public_outlined,
          label: originParts.join(', '),
        ),
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
        _specChip(
          icon: Icons.monitor_weight_outlined,
          label: 'Catch weight',
        ),
      );
    }

    chips.add(
      _specChip(
        icon: usesCanonicalCatalogue
            ? Icons.account_tree_outlined
            : Icons.history,
        label:
            usesCanonicalCatalogue ? 'Recursive catalogue' : 'Legacy listing',
      ),
    );

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
                    hintText:
                        'Search species, cut, variant, supplier, brand, MB, grade, origin or specification',
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

            final price = _findVisiblePrice(product);
            final amount = price?['amount'];
            final priceBasis = price?['price_basis'] as String?;

            final cataloguePath = _cataloguePath(product);
            final usesCanonicalCatalogue = _usesCanonicalCatalogue(product);

            final chips = _marketplaceChips(
              product,
              usesCanonicalCatalogue: usesCanonicalCatalogue,
            );

            final supplierSpecification =
                product['supplier_specification']?.toString();

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

                          const SizedBox(height: 10),

                          Text(
                            cataloguePath,
                            style: const TextStyle(
                              color: Color(0xFF5E5E5E),
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Storage: ${_formatTemperature(product['temperature_state'] as String?)}',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                            ),
                          ),

                          if (supplierSpecification != null &&
                              supplierSpecification.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              supplierSpecification.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                height: 1.4,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: chips,
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
                              '\$$amount / ${_formatPriceBasis(priceBasis)}',
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
                                'Minimum: ${price?['minimum_quantity']}',
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
