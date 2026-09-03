import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'marketplace_product_details_page.dart';
import '../../orders/presentation/draft_orders_page.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';
import '../../../shared/widgets/interactive_beef_cuts_map.dart';

class MarketplaceProductsPage extends StatefulWidget {
  const MarketplaceProductsPage({super.key});

  @override
  State<MarketplaceProductsPage> createState() =>
      _MarketplaceProductsPageState();
}

class _MarketplaceProductsPageState extends State<MarketplaceProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _supplierSearchController =
      TextEditingController();

  final ScrollController _cutScrollController = ScrollController();
  final ScrollController _subcategoryScrollController = ScrollController();
  final ScrollController _gradeScrollController = ScrollController();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSectionId;
  String? _selectedSpecificationId;
  String? _selectedGradeId;
  String _sortMode = 'recommended';
  bool _availableOnly = false;
  String? _butcherBusinessId;
  String? _addingProductId;
  final Map<String, int> _cartQuantities = <String, int>{};

  final Map<String, Map<String, dynamic>> _cataloguePathsByProductId = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _supplierSearchController.addListener(_applySearch);
    _loadButcherBusinessId();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _supplierSearchController.removeListener(_applySearch);
    _searchController.dispose();
    _supplierSearchController.dispose();
    _cutScrollController.dispose();
    _subcategoryScrollController.dispose();
    _gradeScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadButcherBusinessId() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      if (!mounted) return;

      setState(() {
        _butcherBusinessId = membership['business_id']?.toString();
      });
    } catch (_) {
      // The add-to-cart action will show a clear message if this is unavailable.
    }
  }

  String _orderQuantityUnitFor(
    Map<String, dynamic> product,
    Map<String, dynamic>? visiblePrice,
  ) {
    final configured = product['order_unit']?.toString();
    if (configured == 'kilogram' ||
        configured == 'carton' ||
        configured == 'unit') {
      return configured!;
    }

    final productUnit = product['quantity_unit']?.toString();
    if (productUnit == 'kilogram' ||
        productUnit == 'carton' ||
        productUnit == 'unit') {
      return productUnit!;
    }

    final basis = visiblePrice?['price_basis']?.toString();
    if (basis == 'kilogram' || basis == 'carton' || basis == 'unit') {
      return basis!;
    }

    return 'unit';
  }

  bool _isCatchWeightProduct(Map<String, dynamic> product) {
    return product['weight_type']?.toString() == 'catch_weight' ||
        product['catch_weight'] == true;
  }

  String _orderLineName(Map<String, dynamic> product) {
    final specification = _specificationName(product);
    final grade = _gradeCode(product);

    return grade.trim().isEmpty || grade == 'N/A'
        ? specification
        : '$specification • $grade';
  }

  double _defaultCartQuantity(Map<String, dynamic>? visiblePrice) {
    final raw = visiblePrice?['minimum_quantity'];
    final minimum = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '');

    if (minimum != null && minimum > 1) {
      return minimum.ceilToDouble();
    }

    return 1;
  }

  int _minimumCartQuantity(Map<String, dynamic> product) {
    final price = _findVisiblePrice(product);
    final raw = price?['minimum_quantity'];
    final minimum = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '');

    if (minimum == null || minimum <= 1) return 1;
    return minimum.ceil();
  }

  int _cartQuantity(Map<String, dynamic> product) {
    final id = product['id']?.toString();
    if (id == null) return _minimumCartQuantity(product);

    return _cartQuantities[id] ?? _minimumCartQuantity(product);
  }

  void _changeCartQuantity(Map<String, dynamic> product, int delta) {
    final id = product['id']?.toString();
    if (id == null) return;

    final minimum = _minimumCartQuantity(product);
    final current = _cartQuantity(product);
    final next = current + delta;

    setState(() {
      _cartQuantities[id] = next < minimum ? minimum : next;
    });
  }

  Future<void> _openCart() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DraftOrdersPage()));
  }

  Future<void> _addProductToCart(
    Map<String, dynamic> product, {
    int? requestedQuantity,
  }) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty || _addingProductId != null) {
      return;
    }

    final butcherBusinessId = _butcherBusinessId;
    if (butcherBusinessId == null || butcherBusinessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your butcher business could not be identified.'),
        ),
      );
      return;
    }

    final visiblePrice = _findVisiblePrice(product);
    final rawPrice = visiblePrice?['amount'];
    final unitPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');

    if (visiblePrice == null || unitPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This supplier offer does not have a visible price.'),
        ),
      );
      return;
    }

    if (product['availability_status']?.toString() == 'out_of_stock') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is currently out of stock.')),
      );
      return;
    }

    final supplierBusinessId = product['supplier_business_id']?.toString();
    if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier information is missing.')),
      );
      return;
    }

    final quantity =
        requestedQuantity?.toDouble() ?? _defaultCartQuantity(visiblePrice);
    final quantityUnit = _orderQuantityUnitFor(product, visiblePrice);
    final catchWeight = _isCatchWeightProduct(product);
    final priceBasis = catchWeight
        ? 'kilogram'
        : visiblePrice['price_basis']?.toString();

    setState(() => _addingProductId = productId);

    try {
      final client = Supabase.instance.client;

      final drafts = await client
          .from('orders')
          .select('id, order_number')
          .eq('butcher_business_id', butcherBusinessId)
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'draft')
          .order('created_at', ascending: false)
          .limit(1);

      late String orderId;
      String? orderNumber;

      if (drafts.isNotEmpty) {
        orderId = drafts.first['id'].toString();
        orderNumber = drafts.first['order_number']?.toString();
      } else {
        final created = await client
            .from('orders')
            .insert({
              'butcher_business_id': butcherBusinessId,
              'supplier_business_id': supplierBusinessId,
            })
            .select('id, order_number')
            .single();

        orderId = created['id'].toString();
        orderNumber = created['order_number']?.toString();
      }

      final existing = await client
          .from('order_items')
          .select('id, quantity')
          .eq('order_id', orderId)
          .eq('product_id', productId)
          .limit(1);

      final snapshot = {
        'product_name_snapshot': _orderLineName(product),
        'sku_snapshot': product['sku']?.toString(),
        'quantity_unit': quantityUnit,
        'unit_price': unitPrice,
        'price_basis': priceBasis,
        'catch_weight_snapshot': catchWeight,
      };

      if (existing.isNotEmpty) {
        final rawExisting = existing.first['quantity'];
        final existingQuantity = rawExisting is num
            ? rawExisting.toDouble()
            : double.tryParse(rawExisting?.toString() ?? '') ?? 0;

        await client
            .from('order_items')
            .update({...snapshot, 'quantity': existingQuantity + quantity})
            .eq('id', existing.first['id']);
      } else {
        await client.from('order_items').insert({
          'order_id': orderId,
          'product_id': productId,
          ...snapshot,
          'quantity': quantity,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderNumber == null || orderNumber.trim().isEmpty
                ? '${_specificationName(product)} added to cart.'
                : '${_specificationName(product)} added to $orderNumber.',
          ),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _addingProductId = null);
      }
    }
  }

  Future<void> _openProductInfo(Map<String, dynamic> product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MarketplaceProductDetailsPage(product: product),
      ),
    );
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
            meat_animal_id,
            meat_section_id,
            meat_specification_id,
            meat_grade_id,
            active,
            catch_weight,

            marbling_score,
            grade,
            breed_program,
            feeding_days,
            bone_state,
            rib_count,
            production_claim,
            hgp_free,
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

            meat_animals(
              id,
              code,
              name
            ),
            meat_sections(
              id,
              code,
              name,
              is_miscellaneous,
              display_order
            ),
            meat_specifications(
              id,
              name,
              specification_type
            ),
            meat_grades(
              id,
              code,
              name
            ),

            supplier_spec_grade_offers(
              id,
              product_id,
              specification_id,
              grade_id,
              standard_price_inc_gst,
              minimum_order_quantity,
              is_available,
              is_active
            ),

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

  Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  String _animalCode(Map<String, dynamic> product) {
    return _nestedMap(
          product['meat_animals'],
        )?['code']?.toString().trim().toUpperCase() ??
        '';
  }

  String _sectionName(Map<String, dynamic> product) {
    return _nestedMap(product['meat_sections'])?['name']?.toString() ??
        'Unclassified';
  }

  String _specificationName(Map<String, dynamic> product) {
    return _nestedMap(product['meat_specifications'])?['name']?.toString() ??
        product['product_name']?.toString() ??
        'Unspecified cut';
  }

  String _gradeCode(Map<String, dynamic> product) {
    final value = _nestedMap(
      product['meat_grades'],
    )?['code']?.toString().trim();
    return value == null || value.isEmpty ? 'N/A' : value;
  }

  String _gradeName(Map<String, dynamic> product) {
    return _nestedMap(product['meat_grades'])?['name']?.toString().trim() ?? '';
  }

  List<Map<String, dynamic>> _activeSpecGradeOffers(
    Map<String, dynamic> product,
  ) {
    final raw = product['supplier_spec_grade_offers'];

    if (raw is Map) {
      final offer = Map<String, dynamic>.from(raw);
      return offer['is_active'] == true
          ? <Map<String, dynamic>>[offer]
          : <Map<String, dynamic>>[];
    }

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((offer) => offer['is_active'] == true)
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  String? _directProductSpecificationId(Map<String, dynamic> product) {
    final direct = product['meat_specification_id']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final nested = _nestedMap(
      product['meat_specifications'],
    )?['id']?.toString();
    return nested == null || nested.isEmpty ? null : nested;
  }

  String? _directProductGradeId(Map<String, dynamic> product) {
    final direct = product['meat_grade_id']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final nested = _nestedMap(product['meat_grades'])?['id']?.toString();
    return nested == null || nested.isEmpty ? null : nested;
  }

  String? _productSectionId(Map<String, dynamic> product) {
    final direct = product['meat_section_id']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final nested = _nestedMap(product['meat_sections'])?['id']?.toString();
    return nested == null || nested.isEmpty ? null : nested;
  }

  bool _matchesSpecification(
    Map<String, dynamic> product,
    String specificationId,
  ) {
    if (_directProductSpecificationId(product) == specificationId) {
      return true;
    }

    return _activeSpecGradeOffers(
      product,
    ).any((offer) => offer['specification_id']?.toString() == specificationId);
  }

  bool _matchesGrade(Map<String, dynamic> product, String gradeId) {
    if (_directProductGradeId(product) == gradeId) {
      return true;
    }

    return _activeSpecGradeOffers(
      product,
    ).any((offer) => offer['grade_id']?.toString() == gradeId);
  }

  bool _matchesExactSpecGrade(
    Map<String, dynamic> product, {
    required String specificationId,
    required String gradeId,
  }) {
    final directSpec = _directProductSpecificationId(product);
    final directGrade = _directProductGradeId(product);

    if (directSpec == specificationId && directGrade == gradeId) {
      return true;
    }

    return _activeSpecGradeOffers(product).any((offer) {
      return offer['specification_id']?.toString() == specificationId &&
          offer['grade_id']?.toString() == gradeId;
    });
  }

  List<Map<String, dynamic>> get _selectedAnimalProducts {
    return _products.where((product) {
      final animalCode = _animalCode(product);

      if (animalCode.isEmpty) {
        return false;
      }

      return animalCode == _selectedAnimalCode;
    }).toList();
  }

  String? get _selectedSectionName {
    if (_selectedSectionId == null) {
      return null;
    }

    for (final section in _selectedAnimalSections) {
      if (section['id']?.toString() == _selectedSectionId) {
        return section['name']?.toString();
      }
    }

    return null;
  }

  List<Map<String, dynamic>> get _selectedAnimalSections {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      final section = _nestedMap(product['meat_sections']);
      final id = section?['id']?.toString();

      if (section == null || id == null || id.isEmpty) continue;
      byId[id] = section;
    }

    final rows = byId.values.toList();

    rows.sort((a, b) {
      final aOrder = int.tryParse(a['display_order']?.toString() ?? '') ?? 9999;
      final bOrder = int.tryParse(b['display_order']?.toString() ?? '') ?? 9999;

      if (aOrder != bOrder) return aOrder.compareTo(bOrder);

      return (a['name']?.toString() ?? '').compareTo(
        b['name']?.toString() ?? '',
      );
    });

    return rows;
  }

  List<Map<String, dynamic>> get _availableSpecifications {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (_selectedSectionId != null &&
          _productSectionId(product) != _selectedSectionId) {
        continue;
      }

      final specification = _nestedMap(product['meat_specifications']);
      final id = specification?['id']?.toString();

      if (specification == null || id == null || id.isEmpty) continue;
      byId[id] = specification;
    }

    final rows = byId.values.toList();

    rows.sort(
      (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
        (b['name']?.toString() ?? '').toLowerCase(),
      ),
    );

    return rows;
  }

  List<Map<String, dynamic>> get _availableGrades {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (_selectedSectionId != null &&
          _productSectionId(product) != _selectedSectionId) {
        continue;
      }

      if (_selectedSpecificationId != null &&
          !_matchesSpecification(product, _selectedSpecificationId!)) {
        continue;
      }

      final grade = _nestedMap(product['meat_grades']);
      final id = grade?['id']?.toString();

      if (grade == null || id == null || id.isEmpty) continue;
      byId[id] = grade;
    }

    final rows = byId.values.toList();

    rows.sort(
      (a, b) =>
          (a['code']?.toString() ?? '').compareTo(b['code']?.toString() ?? ''),
    );

    return rows;
  }

  Map<String, dynamic>? _sectionByCode(String code) {
    for (final section in _selectedAnimalSections) {
      if (section['code']?.toString() == code) return section;
    }
    return null;
  }

  String? _beefSectionCodeForRegion(String regionKey) {
    return switch (regionKey) {
      CutLinkBeefCutKeys.cheek => 'CHEEK',
      CutLinkBeefCutKeys.neck => 'NECK',
      CutLinkBeefCutKeys.shoulder => 'SHOULDER',
      CutLinkBeefCutKeys.chuck => 'CHUCK',
      CutLinkBeefCutKeys.blade => 'BLADE',
      CutLinkBeefCutKeys.brisket => 'BRISKET',
      CutLinkBeefCutKeys.shinShank => 'SHANK',
      CutLinkBeefCutKeys.ribs => 'RIB',
      CutLinkBeefCutKeys.ribEye => 'RIBEYE',
      CutLinkBeefCutKeys.plate => 'PLATE',
      CutLinkBeefCutKeys.skirt => 'SKIRT',
      CutLinkBeefCutKeys.loin => 'LOIN',
      CutLinkBeefCutKeys.flank => 'FLANK',
      CutLinkBeefCutKeys.rump => 'RUMP',
      CutLinkBeefCutKeys.round => 'HIND',
      CutLinkBeefCutKeys.silversideOutside => 'SILVERSIDE',
      CutLinkBeefCutKeys.oxTail => 'TAIL',
      CutLinkBeefCutKeys.miscOffalOther => 'MISC',
      _ => null,
    };
  }

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) return;

    setState(() {
      _selectedAnimalCode = animalCode;
      _selectedAnimalRegionKey = null;
      _selectedSectionId = null;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });

    _applySearch();
  }

  void _selectAnimalRegion(String regionKey) {
    if (_selectedAnimalCode != CutLinkAnimals.beef) return;

    final sectionCode = _beefSectionCodeForRegion(regionKey);
    if (sectionCode == null) return;

    final section = _sectionByCode(sectionCode);
    if (section == null) return;

    setState(() {
      _selectedAnimalRegionKey = regionKey;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });

    _applySearch();
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });

    _applySearch();
  }

  void _applySearch() {
    if (!mounted) return;

    final search = _searchController.text.trim().toLowerCase();
    final supplierSearch = _supplierSearchController.text.trim().toLowerCase();
    final directSearch = search.isNotEmpty;
    final cutScopedSearch = directSearch && _selectedSectionId != null;

    double? visibleAmount(Map<String, dynamic> product) {
      final price = _findVisiblePrice(product);
      final raw = price?['amount'];

      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    setState(() {
      _filteredProducts = _products.where((product) {
        if (directSearch) {
          if (cutScopedSearch) {
            if (_animalCode(product) != _selectedAnimalCode) {
              return false;
            }

            if (_productSectionId(product) != _selectedSectionId) {
              return false;
            }

            if (_selectedSpecificationId != null &&
                !_matchesSpecification(product, _selectedSpecificationId!)) {
              return false;
            }

            if (_selectedGradeId != null &&
                !_matchesGrade(product, _selectedGradeId!)) {
              return false;
            }
          }
        } else {
          if (_animalCode(product) != _selectedAnimalCode) {
            return false;
          }

          if (_selectedSectionId != null &&
              _productSectionId(product) != _selectedSectionId) {
            return false;
          }

          if (_selectedSpecificationId != null && _selectedGradeId != null) {
            if (!_matchesExactSpecGrade(
              product,
              specificationId: _selectedSpecificationId!,
              gradeId: _selectedGradeId!,
            )) {
              return false;
            }
          } else {
            if (_selectedSpecificationId != null &&
                !_matchesSpecification(product, _selectedSpecificationId!)) {
              return false;
            }

            if (_selectedGradeId != null &&
                !_matchesGrade(product, _selectedGradeId!)) {
              return false;
            }
          }
        }

        if (_availableOnly) {
          final status = product['availability_status']?.toString();
          final rawQuantity = product['available_quantity'];
          final quantity = rawQuantity is num
              ? rawQuantity.toDouble()
              : double.tryParse(rawQuantity?.toString() ?? '');

          final offerAvailable = _activeSpecGradeOffers(
            product,
          ).any((offer) => offer['is_available'] == true);

          final productAvailable =
              status != 'out_of_stock' && (quantity == null || quantity > 0);

          if (!productAvailable && !offerAvailable) {
            return false;
          }
        }

        final supplierName = _supplierName(product);
        if (supplierSearch.isNotEmpty &&
            !supplierName.toLowerCase().contains(supplierSearch)) {
          return false;
        }

        if (search.isEmpty) return true;

        final specification = _specificationName(product).toLowerCase();
        final productName =
            product['product_name']?.toString().toLowerCase() ?? '';
        final supplierSpecification =
            product['supplier_specification']?.toString().toLowerCase() ?? '';

        if (cutScopedSearch) {
          return specification.contains(search) ||
              productName.contains(search) ||
              supplierSpecification.contains(search) ||
              _gradeCode(product).toLowerCase().contains(search) ||
              _gradeName(product).toLowerCase().contains(search);
        }

        final catalogueNames = _canonicalCatalogueNames(product);
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
          product['feeding_days'],
          product['bone_state'],
          product['rib_count'],
          product['production_claim'],
          product['hgp_free'],
          product['packaging_type'],
          product['trim_specification'],
          product['fat_specification'],
          product['halal_status'],
          product['supplier_specification'],
          _cataloguePath(product),
          _sectionName(product),
          _specificationName(product),
          _gradeCode(product),
          _gradeName(product),
          _supplierName(product),
          ...catalogueNames,
        ];

        return searchableValues.any(
          (value) =>
              value != null && value.toString().toLowerCase().contains(search),
        );
      }).toList();

      switch (_sortMode) {
        case 'price_low':
          _filteredProducts.sort((a, b) {
            final aPrice = visibleAmount(a);
            final bPrice = visibleAmount(b);
            if (aPrice == null && bPrice == null) return 0;
            if (aPrice == null) return 1;
            if (bPrice == null) return -1;
            return aPrice.compareTo(bPrice);
          });
          break;
        case 'price_high':
          _filteredProducts.sort((a, b) {
            final aPrice = visibleAmount(a);
            final bPrice = visibleAmount(b);
            if (aPrice == null && bPrice == null) return 0;
            if (aPrice == null) return 1;
            if (bPrice == null) return -1;
            return bPrice.compareTo(aPrice);
          });
          break;
        case 'supplier':
          _filteredProducts.sort(
            (a, b) => _supplierName(
              a,
            ).toLowerCase().compareTo(_supplierName(b).toLowerCase()),
          );
          break;
        case 'grade':
          _filteredProducts.sort((a, b) {
            final gradeCompare = _gradeCode(a).compareTo(_gradeCode(b));
            if (gradeCompare != 0) return gradeCompare;
            return _supplierName(
              a,
            ).toLowerCase().compareTo(_supplierName(b).toLowerCase());
          });
          break;
        default:
          _filteredProducts.sort((a, b) {
            final specCompare = _specificationName(
              a,
            ).toLowerCase().compareTo(_specificationName(b).toLowerCase());
            if (specCompare != 0) return specCompare;

            final gradeCompare = _gradeCode(a).compareTo(_gradeCode(b));
            if (gradeCompare != 0) return gradeCompare;

            final aPrice = visibleAmount(a);
            final bPrice = visibleAmount(b);
            if (aPrice != null && bPrice != null) {
              final priceCompare = aPrice.compareTo(bPrice);
              if (priceCompare != 0) return priceCompare;
            }

            return _supplierName(
              a,
            ).toLowerCase().compareTo(_supplierName(b).toLowerCase());
          });
      }
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

    final productionClaim = product['production_claim']?.toString();
    if (productionClaim == 'grass_fed') {
      chips.add(_specChip(icon: Icons.grass_outlined, label: 'Grass Fed'));
    } else if (productionClaim == 'grain_fed') {
      chips.add(
        _specChip(icon: Icons.agriculture_outlined, label: 'Grain Fed'),
      );
    } else if (productionClaim == 'mixed') {
      chips.add(_specChip(icon: Icons.tune_outlined, label: 'Mixed Feed'));
    }

    final feedingDays = product['feeding_days'];
    if (feedingDays != null) {
      chips.add(
        _specChip(
          icon: Icons.calendar_month_outlined,
          label: '${feedingDays}D',
        ),
      );
    }

    final boneState = product['bone_state']?.toString();
    if (boneState == 'bone_in') {
      chips.add(_specChip(icon: Icons.straighten_outlined, label: 'Bone In'));
    } else if (boneState == 'boneless') {
      chips.add(_specChip(icon: Icons.straighten_outlined, label: 'Boneless'));
    }

    final ribCount = product['rib_count'];
    if (ribCount != null) {
      chips.add(
        _specChip(icon: Icons.view_week_outlined, label: '${ribCount}R'),
      );
    }

    if (product['hgp_free'] == true) {
      chips.add(_specChip(icon: Icons.verified_outlined, label: 'HGP Free'));
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

  Widget _thinChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
        selectedColor: const Color(0xFF741C1C),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFF741C1C) : const Color(0xFFD9D9D5),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF444444),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _arrowScrollStrip({
    required ScrollController controller,
    required double height,
    required List<Widget> children,
  }) {
    Future<void> move(double direction) async {
      if (!controller.hasClients) return;

      final position = controller.position;
      final target = (controller.offset + (direction * 240))
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      await controller.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          _stripArrow(
            icon: Icons.chevron_left,
            tooltip: 'Scroll left',
            onTap: () => move(-1),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ListView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: children,
            ),
          ),
          const SizedBox(width: 5),
          _stripArrow(
            icon: Icons.chevron_right,
            tooltip: 'Scroll right',
            onTap: () => move(1),
          ),
        ],
      ),
    );
  }

  Widget _stripArrow({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3E5E8)),
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF741C1C)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionStrip() {
    final sections = _selectedAnimalSections;

    if (sections.isEmpty) return const SizedBox.shrink();

    return _arrowScrollStrip(
      controller: _cutScrollController,
      height: 38,
      children: [
        _thinChoice(
          label: 'All cuts',
          selected: _selectedSectionId == null,
          onTap: () {
            setState(() {
              _selectedAnimalRegionKey = null;
              _selectedSectionId = null;
              _selectedSpecificationId = null;
              _selectedGradeId = null;
            });
            _applySearch();
          },
        ),
        for (final section in sections)
          _thinChoice(
            label: section['name']?.toString() ?? 'Cut',
            selected: _selectedSectionId == section['id']?.toString(),
            onTap: () => _selectSection(section),
          ),
      ],
    );
  }

  Widget _buildSpecificationStrip() {
    final specifications = _availableSpecifications;

    if (specifications.isEmpty) return const SizedBox.shrink();

    return _arrowScrollStrip(
      controller: _subcategoryScrollController,
      height: 38,
      children: [
        _thinChoice(
          label: 'All subcategories',
          selected: _selectedSpecificationId == null,
          onTap: () {
            setState(() {
              _selectedSpecificationId = null;
              _selectedGradeId = null;
            });
            _applySearch();
          },
        ),
        for (final specification in specifications)
          _thinChoice(
            label: specification['name']?.toString() ?? 'Subcategory',
            selected:
                _selectedSpecificationId == specification['id']?.toString(),
            onTap: () {
              setState(() {
                _selectedSpecificationId = specification['id']?.toString();
                _selectedGradeId = null;
              });
              _applySearch();
            },
          ),
      ],
    );
  }

  Widget _buildGradeStrip() {
    final grades = _availableGrades;

    if (grades.isEmpty) return const SizedBox.shrink();

    return _arrowScrollStrip(
      controller: _gradeScrollController,
      height: 45,
      children: [
        _thinChoice(
          label: 'All grades',
          selected: _selectedGradeId == null,
          onTap: () {
            setState(() => _selectedGradeId = null);
            _applySearch();
          },
        ),
        for (final grade in grades)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              selected: _selectedGradeId == grade['id']?.toString(),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selectedColor: const Color(0xFF741C1C),
              backgroundColor: const Color(0xFFF4E5E5),
              side: const BorderSide(color: Color(0xFFD7B8B8)),
              label: Text(
                grade['code']?.toString() ?? 'N/A',
                style: TextStyle(
                  color: _selectedGradeId == grade['id']?.toString()
                      ? Colors.white
                      : const Color(0xFF741C1C),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              onSelected: (_) {
                setState(() {
                  _selectedGradeId = grade['id']?.toString();
                });
                _applySearch();
              },
            ),
          ),
      ],
    );
  }

  Widget _gradeBadge(Map<String, dynamic> product) {
    final code = _gradeCode(product);
    final name = _gradeName(product);

    return Container(
      width: 82,
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E5E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7B8B8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF741C1C),
              fontSize: code.length > 3 ? 22 : 28,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (name.isNotEmpty && name.toLowerCase() != code.toLowerCase()) ...[
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 9,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.storefront_outlined, color: Color(0xFF741C1C), size: 22),
            SizedBox(width: 10),
            Text(
              'Browse Products',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: _openCart,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF741C1C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: const Text(
              'Cart',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _loadProducts,
            tooltip: 'Refresh products',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE3E5E8)),
        ),
      ),
      body: Column(children: [Expanded(child: _buildBody())]),
    );
  }

  String _mainCommercialSummary(Map<String, dynamic> product) {
    final parts = <String>[];

    final breedProgram = product['breed_program']?.toString().trim() ?? '';
    final marbling = product['marbling_score']?.toString().trim() ?? '';
    final productionClaim = product['production_claim']?.toString();
    final feedingDays = product['feeding_days'];
    final boneState = product['bone_state']?.toString();
    final ribCount = product['rib_count'];

    if (breedProgram.isNotEmpty) {
      parts.add(breedProgram);
    }

    if (marbling.isNotEmpty) {
      final clean = marbling.replaceFirst(
        RegExp(r'^mb\s*', caseSensitive: false),
        '',
      );
      parts.add('MB $clean');
    }

    if (productionClaim == 'grass_fed') {
      parts.add('Grass Fed');
    } else if (productionClaim == 'grain_fed') {
      parts.add('Grain Fed');
    } else if (productionClaim == 'mixed') {
      parts.add('Mixed Feed');
    }

    if (feedingDays != null) {
      parts.add('${feedingDays}D');
    }

    if (boneState == 'bone_in') {
      parts.add('Bone In');
    } else if (boneState == 'boneless') {
      parts.add('Boneless');
    }

    if (ribCount != null) {
      parts.add('${ribCount}R');
    }

    if (product['hgp_free'] == true) {
      parts.add('HGP Free');
    }

    return parts.join(' • ');
  }

  Widget _buildMarketplaceProductCard(Map<String, dynamic> product) {
    final price = _findVisiblePrice(product);
    final amount = price?['amount'];
    final priceBasis = price?['price_basis'] as String?;
    final productId = product['id']?.toString();
    final adding = productId != null && _addingProductId == productId;
    final supplierSpecification = product['supplier_specification']?.toString();
    final commercialSummary = _mainCommercialSummary(product);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 680;

          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _gradeBadge(product),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _specificationName(product),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _supplierName(product),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF741C1C),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_sectionName(product)} • ${_formatTemperature(product['temperature_state'] as String?)}'
                      '${_availableText(product).isEmpty ? '' : ' • ${_availableText(product)}'}',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (commercialSummary.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        commercialSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF3F444A),
                          fontSize: 10.8,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (supplierSpecification != null &&
                        supplierSpecification.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        supplierSpecification.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final actions = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.end,
            children: [
              const Text(
                'YOUR PRICE',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                amount == null
                    ? 'Contact supplier'
                    : '\$${_formatNumber(amount)}'
                          '${_formatPriceBasis(priceBasis).isEmpty ? '' : ' / ${_formatPriceBasis(priceBasis)}'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openProductInfo(product),
                    icon: const Icon(Icons.info_outline, size: 17),
                    label: const Text('Info'),
                  ),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE3E5E8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _changeCartQuantity(product, -1),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.remove, size: 16),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${_cartQuantity(product)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeCartQuantity(product, 1),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: adding
                        ? null
                        : () => _addProductToCart(
                            product,
                            requestedQuantity: _cartQuantity(product),
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF741C1C),
                    ),
                    icon: adding
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_shopping_cart, size: 17),
                    label: Text(adding ? 'Adding' : 'Add to Cart'),
                  ),
                ],
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [identity, const SizedBox(height: 10), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 14),
              SizedBox(width: 190, child: actions),
            ],
          );
        },
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

    final cutSelected = _selectedSectionId != null;
    final subcategorySelected = _selectedSpecificationId != null;
    final gradeSelected = _selectedGradeId != null;
    final exactSelection = subcategorySelected && gradeSelected;

    // ignore: unused_element
    Widget filterLabel(String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    Widget animalPanel() {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 11, 14, 0),
              child: Text(
                'Browse by Animal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 2, 14, 7),
              child: Text(
                'Choose the animal, cut, subcategory and grade.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 10.5),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InteractiveAnimalBrowser(
                      selectedAnimalCode: _selectedAnimalCode,
                      selectedRegionKey: _selectedAnimalRegionKey,
                      onAnimalChanged: _selectAnimal,
                      onRegionSelected: _selectAnimalRegion,
                      maxWidth: 650,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'CUT',
                      style: TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildSectionStrip(),
                    if (cutSelected) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'SUBCATEGORY',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildSpecificationStrip(),
                    ],
                    if (subcategorySelected) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'GRADE',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildGradeStrip(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget availableToggle() {
      return InkWell(
        onTap: () {
          setState(() => _availableOnly = !_availableOnly);
          _applySearch();
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _availableOnly ? const Color(0xFFF5EAEA) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _availableOnly
                  ? const Color(0xFFB98585)
                  : const Color(0xFFDADAD6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _availableOnly ? Icons.inventory_2 : Icons.inventory_2_outlined,
                size: 16,
                color: _availableOnly
                    ? const Color(0xFF741C1C)
                    : const Color(0xFF666A70),
              ),
              const SizedBox(width: 6),
              Text(
                'Available only',
                style: TextStyle(
                  color: _availableOnly
                      ? const Color(0xFF741C1C)
                      : const Color(0xFF555555),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget universalSearchBar() {
      return Container(
        padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: !cutSelected
                ? 'Search all products — e.g. Scotch Fillet, Brisket...'
                : !subcategorySelected
                ? 'Search subcategories within ${_selectedSectionName ?? 'this cut'}...'
                : !gradeSelected
                ? 'Search grades for this subcategory...'
                : 'Search this selected stock...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close, size: 18),
                  ),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFFBFBF9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFDADAD6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFDADAD6)),
            ),
          ),
        ),
      );
    }

    Widget resultsToolbar() {
      return Container(
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
        decoration: const BoxDecoration(
          color: Color(0xFFFBFBF9),
          border: Border(
            top: BorderSide(color: Color(0xFFE0E0DD)),
            bottom: BorderSide(color: Color(0xFFE0E0DD)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;

                final supplierField = TextField(
                  controller: _supplierSearchController,
                  decoration: InputDecoration(
                    hintText: 'Filter supplier',
                    prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                    suffixIcon: _supplierSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _supplierSearchController.clear,
                            icon: const Icon(Icons.close, size: 17),
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDADAD6)),
                    ),
                  ),
                );

                String sortLabel(String value) => switch (value) {
                  'price_low' => 'Cheapest',
                  'price_high' => 'Highest',
                  'grade' => 'Grade',
                  'supplier' => 'Supplier A–Z',
                  _ => 'Recommended',
                };

                IconData sortIcon(String value) => switch (value) {
                  'price_low' => Icons.south_east,
                  'price_high' => Icons.north_east,
                  'grade' => Icons.workspace_premium_outlined,
                  'supplier' => Icons.storefront_outlined,
                  _ => Icons.auto_awesome_outlined,
                };

                final sortField = PopupMenuButton<String>(
                  initialValue: _sortMode,
                  onSelected: (value) {
                    setState(() => _sortMode = value);
                    _applySearch();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'recommended',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.auto_awesome_outlined),
                        title: Text('Recommended'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'price_low',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.south_east),
                        title: Text('Cheapest price'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'price_high',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.north_east),
                        title: Text('Highest price'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'grade',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.workspace_premium_outlined),
                        title: Text('Grade'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'supplier',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.storefront_outlined),
                        title: Text('Supplier A–Z'),
                      ),
                    ),
                  ],
                  child: Container(
                    height: 47,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDADAD6)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sortIcon(_sortMode),
                          size: 17,
                          color: const Color(0xFF741C1C),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            sortLabel(_sortMode),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                );

                if (narrow) {
                  return Column(
                    children: [
                      supplierField,
                      const SizedBox(height: 7),
                      sortField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 6, child: supplierField),
                    const SizedBox(width: 7),
                    Expanded(flex: 4, child: sortField),
                  ],
                );
              },
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                availableToggle(),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _supplierSearchController.clear();
                    setState(() {
                      _sortMode = 'recommended';
                      _availableOnly = false;
                    });
                    _applySearch();
                  },
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget rightChoiceCard({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
      Widget? trailing,
    }) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE3E5E8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EAEA),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF741C1C)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ] else
                  const Icon(
                    Icons.chevron_right,
                    size: 19,
                    color: Color(0xFF741C1C),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Widget subcategoryStage() {
      final query = _searchController.text.trim().toLowerCase();
      final specifications = _availableSpecifications.where((specification) {
        if (query.isEmpty) return true;
        return (specification['name']?.toString() ?? '')
            .toLowerCase()
            .contains(query);
      }).toList();

      if (specifications.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Text(
              query.isEmpty
                  ? 'No subcategories are linked to this cut yet.'
                  : 'No subcategories match “${_searchController.text.trim()}”.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: specifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 7),
        itemBuilder: (_, index) {
          final specification = specifications[index];
          final name = specification['name']?.toString() ?? 'Subcategory';

          return rightChoiceCard(
            icon: Icons.category_outlined,
            title: name,
            subtitle: 'Choose this subcategory to view its grades.',
            onTap: () {
              setState(() {
                _selectedSpecificationId = specification['id']?.toString();
                _selectedGradeId = null;
              });
              _searchController.clear();
              _applySearch();
            },
          );
        },
      );
    }

    Widget gradeStage() {
      final query = _searchController.text.trim().toLowerCase();
      final grades = _availableGrades.where((grade) {
        if (query.isEmpty) return true;
        final code = grade['code']?.toString() ?? '';
        final name = grade['name']?.toString() ?? '';
        return code.toLowerCase().contains(query) ||
            name.toLowerCase().contains(query);
      }).toList();

      if (grades.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Text(
              query.isEmpty
                  ? 'No grades are linked to this subcategory yet.'
                  : 'No grades match “${_searchController.text.trim()}”.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: grades.length,
        separatorBuilder: (_, _) => const SizedBox(height: 7),
        itemBuilder: (_, index) {
          final grade = grades[index];
          final code = grade['code']?.toString() ?? 'N/A';
          final name = grade['name']?.toString() ?? '';

          return rightChoiceCard(
            icon: Icons.workspace_premium_outlined,
            title: code,
            subtitle: name,
            onTap: () {
              setState(() {
                _selectedGradeId = grade['id']?.toString();
              });
              _searchController.clear();
              _applySearch();
            },
          );
        },
      );
    }

    Widget supplierStockStage() {
      if (_filteredProducts.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_outlined,
                  size: 46,
                  color: Color(0xFFAAAAAA),
                ),
                SizedBox(height: 10),
                Text(
                  'No supplier offers match this selection',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'No active supplier product is linked to this exact subcategory and grade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF777777), height: 1.35),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: _filteredProducts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 7),
        itemBuilder: (_, index) =>
            _buildMarketplaceProductCard(_filteredProducts[index]),
      );
    }

    Widget resultsPanel() {
      final directSearch = _searchController.text.trim().isNotEmpty;
      final globalSearch = directSearch && !cutSelected;

      final title = globalSearch
          ? 'Search Results'
          : !cutSelected
          ? 'Choose a Cut'
          : !subcategorySelected
          ? 'Subcategories'
          : !gradeSelected
          ? 'Choose Grade'
          : 'Supplier Stock';

      final subtitle = globalSearch
          ? 'Matching products from all suppliers.'
          : !cutSelected
          ? 'Select a cut from the animal diagram or cut row.'
          : !subcategorySelected
          ? 'Choose the exact subcategory for this cut.'
          : !gradeSelected
          ? 'Choose the commercial grade/category.'
          : 'Compare matching supplier offers and pricing.';

      final showingStock = globalSearch || exactSelection;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 7),
              child: Row(
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
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showingStock)
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
                        '${_filteredProducts.length} result${_filteredProducts.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFF741C1C),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            universalSearchBar(),
            if (showingStock) resultsToolbar(),
            Expanded(
              child: globalSearch
                  ? supplierStockStage()
                  : !cutSelected
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 48,
                              color: Color(0xFFAAAAAA),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Select a cut or search above',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : !subcategorySelected
                  ? subcategoryStage()
                  : !gradeSelected
                  ? gradeStage()
                  : supplierStockStage(),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 930;

              if (narrow) {
                return ListView(
                  children: [
                    SizedBox(height: 640, child: animalPanel()),
                    const SizedBox(height: 14),
                    SizedBox(height: 720, child: resultsPanel()),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: animalPanel()),
                  const SizedBox(width: 14),
                  Expanded(flex: 5, child: resultsPanel()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
