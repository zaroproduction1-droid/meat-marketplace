import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'compare_offers_page.dart';
import '../../orders/presentation/draft_orders_page.dart';
import '../../orders/presentation/submitted_orders_page.dart';

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
  final Map<String, Map<String, dynamic>> _deliverySettingsBySupplierId = {};
  final Map<String, Map<String, dynamic>> _deliveryZoneBySupplierId = {};

  String? _butcherPostcode;

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

      final user = Supabase.instance.client.auth.currentUser;
      String? butcherPostcode;

      if (user != null) {
        final memberships = await Supabase.instance.client
            .from('business_memberships')
            .select('business_id')
            .eq('user_id', user.id)
            .eq('status', 'active')
            .limit(1);

        if (memberships.isNotEmpty) {
          final businessId = memberships.first['business_id']?.toString();

          if (businessId != null && businessId.isNotEmpty) {
            final businesses = await Supabase.instance.client
                .from('businesses')
                .select('postcode')
                .eq('id', businessId)
                .limit(1);

            if (businesses.isNotEmpty) {
              final postcode = businesses.first['postcode']?.toString().trim();

              if (postcode != null && postcode.isNotEmpty) {
                butcherPostcode = postcode;
              }
            }
          }
        }
      }

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

      final supplierIds = products
          .map((product) => product['supplier_business_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final deliverySettingsBySupplierId = <String, Map<String, dynamic>>{};
      final deliveryZoneBySupplierId = <String, Map<String, dynamic>>{};

      if (supplierIds.isNotEmpty) {
        final settingsResponse = await Supabase.instance.client
            .from('supplier_delivery_settings')
            .select('''
              supplier_business_id,
              minimum_order_amount,
              default_lead_time_days,
              order_cutoff_time,
              pickup_available,
              delivery_notes,
              active
            ''')
            .inFilter('supplier_business_id', supplierIds.toList());

        for (final rawSetting in settingsResponse) {
          final setting = Map<String, dynamic>.from(rawSetting);
          final supplierId = setting['supplier_business_id']?.toString();

          if (supplierId != null && supplierId.isNotEmpty) {
            deliverySettingsBySupplierId[supplierId] = setting;
          }
        }

        if (butcherPostcode != null) {
          final zonesResponse = await Supabase.instance.client
              .from('supplier_delivery_zones')
              .select('''
                id,
                supplier_business_id,
                zone_name,
                minimum_order_amount,
                delivery_fee,
                lead_time_days,
                active,
                supplier_delivery_zone_postcodes!inner(
                  postcode
                )
              ''')
              .inFilter('supplier_business_id', supplierIds.toList())
              .eq('active', true)
              .eq('supplier_delivery_zone_postcodes.postcode', butcherPostcode);

          for (final rawZone in zonesResponse) {
            final zone = Map<String, dynamic>.from(rawZone);
            final supplierId = zone['supplier_business_id']?.toString();

            if (supplierId != null &&
                supplierId.isNotEmpty &&
                !deliveryZoneBySupplierId.containsKey(supplierId)) {
              deliveryZoneBySupplierId[supplierId] = zone;
            }
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

        _deliverySettingsBySupplierId
          ..clear()
          ..addAll(deliverySettingsBySupplierId);

        _deliveryZoneBySupplierId
          ..clear()
          ..addAll(deliveryZoneBySupplierId);

        _butcherPostcode = butcherPostcode;
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

  Future<void> _openCompareOffers(Map<String, dynamic> product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompareOffersPage(selectedProduct: product),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadProducts();
  }

  Future<void> _openDraftOrdersPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DraftOrdersPage()));

    if (!mounted) {
      return;
    }

    await _loadProducts();
  }

  Future<void> _openMyOrdersPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SubmittedOrdersPage()),
    );

    if (!mounted) {
      return;
    }

    await _loadProducts();
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

  // ignore: unused_element
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

  Map<String, dynamic>? _priceForVisibility(
    Map<String, dynamic> product,
    String visibility,
  ) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List) {
      return null;
    }

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

      if (priceList['visibility']?.toString() == visibility) {
        return price;
      }
    }

    return null;
  }

  String _visiblePriceLabel(Map<String, dynamic>? price) {
    final rawPriceList = price?['price_lists'];

    if (rawPriceList is! Map) {
      return 'Standard Price';
    }

    switch (rawPriceList['visibility']?.toString()) {
      case 'private':
        return 'Your Special Price';
      case 'approved_customers':
        return 'Your Trade Price';
      case 'public':
      default:
        return 'Standard Price';
    }
  }

  // ignore: unused_element
  Widget _buildCustomerPriceDisplay(
    Map<String, dynamic> product, {
    required Map<String, dynamic>? visiblePrice,
    required CrossAxisAlignment alignment,
  }) {
    if (visiblePrice == null || visiblePrice['amount'] == null) {
      return const Text(
        'Price unavailable',
        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF666666)),
      );
    }

    final visibleAmountRaw = visiblePrice['amount'];
    final visibleAmount = visibleAmountRaw is num
        ? visibleAmountRaw.toDouble()
        : double.tryParse('$visibleAmountRaw');

    final visibleBasis = visiblePrice['price_basis']?.toString();

    final standardPrice = _priceForVisibility(product, 'public');

    final standardAmountRaw = standardPrice?['amount'];
    final standardAmount = standardAmountRaw is num
        ? standardAmountRaw.toDouble()
        : double.tryParse('${standardAmountRaw ?? ''}');

    final standardBasis = standardPrice?['price_basis']?.toString();

    final priceLabel = _visiblePriceLabel(visiblePrice);

    final isDiscountedPrice =
        priceLabel != 'Standard Price' &&
        visibleAmount != null &&
        standardAmount != null &&
        standardAmount > visibleAmount &&
        standardBasis == visibleBasis;

    final saving = isDiscountedPrice ? standardAmount - visibleAmount : null;

    final savingPercent = isDiscountedPrice && standardAmount > 0
        ? (saving! / standardAmount) * 100
        : null;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (isDiscountedPrice) ...[
          Text(
            '${_formatMoney(standardAmount)} / ${_formatPriceBasis(standardBasis)} inc GST',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF777777),
              decoration: TextDecoration.lineThrough,
              decorationThickness: 2,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Text(
          '${_formatMoney(visibleAmountRaw)} / ${_formatPriceBasis(visibleBasis)} inc GST',
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF741C1C),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          priceLabel,
          style: TextStyle(
            color: priceLabel == 'Standard Price'
                ? const Color(0xFF666666)
                : const Color(0xFF741C1C),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        if (saving != null && savingPercent != null) ...[
          const SizedBox(height: 4),
          Text(
            'Save ${_formatMoney(saving)} / ${_formatPriceBasis(visibleBasis)} • ${savingPercent.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  String _withThousandsSeparators(String value) {
    final parts = value.split('.');
    final whole = parts.first;
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    final formattedWhole = '${negative ? '-' : ''}${buffer.toString()}';

    if (parts.length == 1) {
      return formattedWhole;
    }

    return '$formattedWhole.${parts.sublist(1).join('.')}';
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
      return _withThousandsSeparators(number.toInt().toString());
    }

    final formatted = number
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return _withThousandsSeparators(formatted);
  }

  String _formatMoney(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return '\$0.00';
    }

    return '\$${_withThousandsSeparators(number.toStringAsFixed(2))}';
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

  // ignore: unused_element
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
      final clean = marbling.trim().replaceFirst(
        RegExp(r'^mb\s*', caseSensitive: false),
        '',
      );
      chips.add(
        _specChip(icon: Icons.auto_awesome_outlined, label: 'MB $clean'),
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

    chips.add(
      _specChip(
        icon: usesCanonicalCatalogue
            ? Icons.account_tree_outlined
            : Icons.history,
        label: usesCanonicalCatalogue
            ? 'Recursive catalogue'
            : 'Legacy listing',
      ),
    );

    return chips;
  }

  Map<String, dynamic>? _deliverySettingsForProduct(
    Map<String, dynamic> product,
  ) {
    final supplierId = product['supplier_business_id']?.toString();

    if (supplierId == null || supplierId.isEmpty) {
      return null;
    }

    return _deliverySettingsBySupplierId[supplierId];
  }

  Map<String, dynamic>? _deliveryZoneForProduct(Map<String, dynamic> product) {
    final supplierId = product['supplier_business_id']?.toString();

    if (supplierId == null || supplierId.isEmpty) {
      return null;
    }

    return _deliveryZoneBySupplierId[supplierId];
  }

  dynamic _effectiveDeliveryMinimum(Map<String, dynamic> product) {
    final zone = _deliveryZoneForProduct(product);

    if (zone != null && zone['minimum_order_amount'] != null) {
      return zone['minimum_order_amount'];
    }

    return _deliverySettingsForProduct(product)?['minimum_order_amount'];
  }

  dynamic _effectiveLeadTime(Map<String, dynamic> product) {
    final zone = _deliveryZoneForProduct(product);

    if (zone != null && zone['lead_time_days'] != null) {
      return zone['lead_time_days'];
    }

    return _deliverySettingsForProduct(product)?['default_lead_time_days'];
  }

  // ignore: unused_element
  Widget _buildDeliverySummary(Map<String, dynamic> product) {
    final settings = _deliverySettingsForProduct(product);
    final zone = _deliveryZoneForProduct(product);

    if (settings == null || settings['active'] != true) {
      return const SizedBox.shrink();
    }

    final rows = <String>[];
    final zoneName = zone?['zone_name']?.toString();
    final leadTime = _effectiveLeadTime(product);
    final minimum = _effectiveDeliveryMinimum(product);
    final deliveryFee = zone?['delivery_fee'];

    if (_butcherPostcode != null) {
      rows.add(
        zoneName != null && zoneName.trim().isNotEmpty
            ? 'Zone: ${zoneName.trim()}'
            : 'No zone match for $_butcherPostcode',
      );
    }

    if (leadTime != null) {
      final days = leadTime is num
          ? leadTime.toInt()
          : int.tryParse('$leadTime');

      if (days != null) {
        rows.add('Lead time: $days day${days == 1 ? '' : 's'}');
      }
    }

    if (minimum != null) {
      rows.add('Minimum: ${_formatMoney(minimum)}');
    }

    if (zone != null) {
      if (deliveryFee == null) {
        rows.add('Delivery fee: Not set');
      } else {
        final fee = deliveryFee is num
            ? deliveryFee.toDouble()
            : double.tryParse('$deliveryFee');

        if (fee != null) {
          rows.add(
            fee == 0
                ? 'Delivery fee: Free'
                : 'Delivery fee: ${_formatMoney(fee)}',
          );
        }
      }
    }

    if (settings['pickup_available'] == true) {
      rows.add('Pickup available');
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E1DE)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: rows
            .map(
              (row) => Text(
                row,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _comparisonKey(Map<String, dynamic> product) {
    final variantId = product['product_variant_id']?.toString();

    if (variantId != null && variantId.trim().isNotEmpty) {
      return 'variant:$variantId';
    }

    final cutId = product['cut_id']?.toString() ?? '';
    final productName =
        product['product_name']?.toString().trim().toLowerCase() ?? '';

    return 'legacy:$cutId:$productName';
  }

  List<List<Map<String, dynamic>>> _groupedBuyingOptions() {
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final product in _filteredProducts) {
      groups
          .putIfAbsent(_comparisonKey(product), () => <Map<String, dynamic>>[])
          .add(product);
    }

    final result = groups.values.toList();

    result.sort((a, b) {
      final aName = a.first['product_name']?.toString().toLowerCase() ?? '';
      final bName = b.first['product_name']?.toString().toLowerCase() ?? '';

      return aName.compareTo(bName);
    });

    return result;
  }

  int _supplierOfferCount(List<Map<String, dynamic>> offers) {
    return offers
        .map((product) => product['supplier_business_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
  }

  // ignore: unused_element
  Map<String, dynamic>? _lowestVisiblePrice(List<Map<String, dynamic>> offers) {
    Map<String, dynamic>? lowest;
    double? lowestAmount;

    for (final product in offers) {
      final price = _findVisiblePrice(product);
      final rawAmount = price?['amount'];

      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse('${rawAmount ?? ''}');

      if (price == null || amount == null) {
        continue;
      }

      if (lowestAmount == null || amount < lowestAmount) {
        lowestAmount = amount;
        lowest = price;
      }
    }

    return lowest;
  }

  // ignore: unused_element
  String _groupAvailabilityText(List<Map<String, dynamic>> offers) {
    var inStock = 0;
    var limited = 0;
    var madeToOrder = 0;

    for (final product in offers) {
      switch (product['availability_status']?.toString()) {
        case 'in_stock':
          inStock++;
          break;
        case 'limited':
          limited++;
          break;
        case 'made_to_order':
          madeToOrder++;
          break;
      }
    }

    if (inStock > 0) {
      return '$inStock offer${inStock == 1 ? '' : 's'} in stock';
    }

    if (limited > 0) {
      return '$limited limited-stock offer${limited == 1 ? '' : 's'}';
    }

    if (madeToOrder > 0) {
      return '$madeToOrder made-to-order offer${madeToOrder == 1 ? '' : 's'}';
    }

    return 'Currently unavailable';
  }

  String _variantDisplayName(Map<String, dynamic> product) {
    final variant = _variant(product);
    final name = variant?['variant_name']?.toString().trim();

    if (name == null || name.isEmpty) {
      return '';
    }

    return name;
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
            onPressed: _openMyOrdersPage,
            tooltip: 'My orders',
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            onPressed: _openDraftOrdersPage,
            tooltip: 'Draft orders',
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
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

    final groups = _groupedBuyingOptions();

    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No matching products were found.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          children: [
            const Text(
              'Choose what you want to buy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the exact cut or product first. Prices and supplier '
              'offers are shown only after you open the buying page.',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            for (final offers in groups) ...[
              Builder(
                builder: (context) {
                  final representative = offers.first;
                  final supplierCount = _supplierOfferCount(offers);
                  final cataloguePath = _cataloguePath(representative);
                  final variantName = _variantDisplayName(representative);

                  return Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      onTap: () => _openCompareOffers(representative),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4E5E5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_outlined,
                                color: Color(0xFF741C1C),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    representative['product_name']
                                            ?.toString() ??
                                        'Unnamed product',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (variantName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      variantName,
                                      style: const TextStyle(
                                        color: Color(0xFF741C1C),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 7),
                                  Text(
                                    cataloguePath,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$supplierCount supplier offer'
                                    '${supplierCount == 1 ? '' : 's'} available',
                                    style: const TextStyle(
                                      color: Color(0xFF555555),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF741C1C),
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
