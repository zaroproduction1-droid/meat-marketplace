import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_product_page.dart';
import 'edit_product_page.dart';
import '../../../shared/widgets/cutlink_picker.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';
import '../../../shared/widgets/interactive_beef_cuts_map.dart';

class SupplierProductsPage extends StatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  State<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends State<SupplierProductsPage> {
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _cutScrollController = ScrollController();
  final ScrollController _subcategoryScrollController = ScrollController();
  final ScrollController _gradeScrollController = ScrollController();

  final Map<String, TextEditingController> _matrixStockControllers = {};
  final Map<String, TextEditingController> _matrixStandardControllers = {};
  final Map<String, TextEditingController> _matrixTradeControllers = {};
  final Map<String, String> _matrixAvailability = {};
  final Set<String> _savingSpecificationIds = {};

  String? _supplierBusinessId;
  List<Map<String, dynamic>> _priceLists = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSectionId;
  String? _selectedSpecificationId;
  String? _selectedGradeId;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _sections = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    _cutScrollController.dispose();
    _subcategoryScrollController.dispose();
    _gradeScrollController.dispose();
    for (final controller in [
      ..._matrixStockControllers.values,
      ..._matrixStandardControllers.values,
      ..._matrixTradeControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
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

      String? supplierBusinessId;

      for (final business in businesses) {
        if (business['business_type']?.toString() == 'supplier') {
          supplierBusinessId = business['id']?.toString();
          break;
        }
      }

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception('No active supplier business membership was found.');
      }

      final priceListResponse = await client
          .from('price_lists')
          .select('id, supplier_business_id, name, visibility, active')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('active', true)
          .order('name');

      final animalResponse = await client
          .from('meat_animals')
          .select('id, code, name, display_order')
          .eq('is_active', true)
          .inFilter('code', const [
            'BEEF',
            'VEAL',
            'LAMB',
            'MUTTON',
            'GOAT',
            'CHICKEN',
          ])
          .order('display_order');

      final animals = List<Map<String, dynamic>>.from(animalResponse);
      final animalCodeById = <String, String>{
        for (final animal in animals)
          if (animal['id'] != null && animal['code'] != null)
            animal['id'].toString(): animal['code'].toString(),
      };

      List<Map<String, dynamic>> sections = [];

      if (animalCodeById.isNotEmpty) {
        final sectionResponse = await client
            .from('meat_sections')
            .select(
              'id, animal_id, code, name, is_miscellaneous, display_order',
            )
            .inFilter('animal_id', animalCodeById.keys.toList())
            .eq('is_active', true)
            .order('display_order');

        sections = [
          for (final raw in sectionResponse)
            {
              ...Map<String, dynamic>.from(raw),
              'animal_code': animalCodeById[raw['animal_id']?.toString()] ?? '',
            },
        ];
      }

      final productResponse = await client
          .from('products')
          .select('''
            id,
            supplier_business_id,
            sku,
            product_name,
            description,
            brand,
            temperature_state,
            halal_status,
            feeding_days,
            bone_state,
            rib_count,
            production_claim,
            hgp_free,
            chicken_skin,
            chicken_bone,
            chicken_production_type,
            chicken_preparation,
            chicken_size_weight,
            chicken_carton_size,
            available_quantity,
            available_weight_kg,
            quantity_unit,
            availability_status,
            active,
            created_at,
            meat_animal_id,
            meat_section_id,
            meat_specification_id,
            meat_grade_id,
            catch_weight,
            weight_type,
            price_basis,
            order_unit,
            meat_animals(id, code, name),
            meat_sections(id, code, name, is_miscellaneous),
            meat_specifications(id, name, specification_type),
            meat_grades(id, code, name),
            supplier_spec_grade_offers(
              id,
              specification_id,
              grade_id,
              standard_price_inc_gst,
              minimum_order_quantity,
              is_available,
              is_active
            ),
            product_prices(
              id,
              price_list_id,
              amount,
              price_basis,
              active,
              price_lists(id, visibility, active)
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      _resetMatrixEditors();

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _priceLists = List<Map<String, dynamic>>.from(priceListResponse);
        _products = List<Map<String, dynamic>>.from(productResponse);
        _sections = sections;
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

  Future<void> _openAddProductPage({
    String? sectionId,
    String? specificationId,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddProductPage(
          initialAnimalCode: _selectedAnimalCode,
          initialSectionId: sectionId,
          initialSpecificationId: specificationId,
        ),
      ),
    );

    if (changed == true) {
      await _loadProducts();
    }
  }

  Future<void> _openEditProductPage(Map<String, dynamic> product) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProductPage(product: product)),
    );

    if (changed == true) {
      await _loadProducts();
    }
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _sectionName(Map<String, dynamic> product) {
    return _map(product['meat_sections'])?['name']?.toString() ??
        'Unclassified';
  }

  String _sectionCode(Map<String, dynamic> product) {
    return _map(product['meat_sections'])?['code']?.toString() ?? '';
  }

  String _specificationName(Map<String, dynamic> product) {
    return _map(product['meat_specifications'])?['name']?.toString() ??
        product['product_name']?.toString() ??
        'Unspecified';
  }

  String _gradeName(Map<String, dynamic> product) {
    final grade = _map(product['meat_grades']);
    if (grade == null) return '';

    final code = grade['code']?.toString().trim() ?? '';
    final name = grade['name']?.toString().trim() ?? '';

    if (code == 'NA') return 'Not applicable';
    if (code.isEmpty) return name;
    if (name.isEmpty) return code;

    return '$code • $name';
  }

  void _resetMatrixEditors() {
    for (final controller in [
      ..._matrixStockControllers.values,
      ..._matrixStandardControllers.values,
      ..._matrixTradeControllers.values,
    ]) {
      controller.dispose();
    }
    _matrixStockControllers.clear();
    _matrixStandardControllers.clear();
    _matrixTradeControllers.clear();
    _matrixAvailability.clear();
  }

  TextEditingController _matrixController(
    Map<String, TextEditingController> store,
    String key,
    String initialValue,
  ) {
    return store.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  Map<String, dynamic>? _offer(Map<String, dynamic> product) {
    final raw = product['supplier_spec_grade_offers'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['is_active'] == true) {
          return Map<String, dynamic>.from(item);
        }
      }
      if (raw.isNotEmpty && raw.first is Map) {
        return Map<String, dynamic>.from(raw.first as Map);
      }
    }
    return null;
  }

  Map<String, dynamic>? _priceForVisibility(
    Map<String, dynamic> product,
    String visibility,
  ) {
    final rawPrices = product['product_prices'];
    if (rawPrices is! List) return null;

    for (final raw in rawPrices) {
      if (raw is! Map || raw['active'] != true) continue;
      final price = Map<String, dynamic>.from(raw);
      final rawList = price['price_lists'];
      if (rawList is! Map) continue;
      final priceList = Map<String, dynamic>.from(rawList);
      if (priceList['active'] == true &&
          priceList['visibility']?.toString() == visibility) {
        return price;
      }
    }
    return null;
  }

  String _matrixNumber(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (number == null) return '';
    if (number == number.roundToDouble()) return number.toInt().toString();
    return number.toStringAsFixed(2);
  }

  String _matrixStandardInitial(Map<String, dynamic> product) {
    final publicPrice = _priceForVisibility(product, 'public');
    if (publicPrice != null) {
      return _matrixNumber(publicPrice['amount']);
    }
    return _matrixNumber(_offer(product)?['standard_price_inc_gst']);
  }

  String _matrixTradeInitial(Map<String, dynamic> product) {
    return _matrixNumber(
      _priceForVisibility(product, 'approved_customers')?['amount'],
    );
  }

  String _gradeCode(Map<String, dynamic> product) {
    return _map(product['meat_grades'])?['code']?.toString().trim() ?? 'N/A';
  }

  bool _isChickenProduct(Map<String, dynamic> product) {
    return _productAnimalCode(product) == CutLinkAnimals.chicken;
  }

  String _prettyChickenValue(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'not_applicable' || raw == 'not_specified') {
      return '';
    }

    return switch (raw) {
      'skin_on' => 'Skin On',
      'skin_off' => 'Skin Off',
      'bone_in' => 'Bone In',
      'boneless' => 'Boneless',
      'fresh' => 'Fresh',
      'frozen' => 'Frozen',
      'conventional' => 'Conventional',
      'free_range' => 'Free Range',
      'organic' => 'Organic',
      'whole' => 'Whole',
      'fillet' => 'Fillet',
      'diced' => 'Diced',
      'strips' => 'Strips',
      'sliced' => 'Sliced',
      'minced' => 'Minced',
      'butterflied' => 'Butterflied',
      'schnitzel' => 'Schnitzel',
      'portion_controlled' => 'Portion Controlled',
      'halal' => 'Halal',
      'not_halal' => 'Not Halal',
      'other' => 'Other',
      _ =>
        raw
            .split('_')
            .where((part) => part.isNotEmpty)
            .map(
              (part) =>
                  '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
            )
            .join(' '),
    };
  }

  String _chickenVariationLabel(Map<String, dynamic> product) {
    final values = <String>[
      _prettyChickenValue(product['chicken_skin']),
      _prettyChickenValue(product['chicken_bone']),
      _prettyChickenValue(product['temperature_state']),
      _prettyChickenValue(product['chicken_production_type']),
      _prettyChickenValue(product['halal_status']),
      _prettyChickenValue(product['chicken_preparation']),
    ].where((value) => value.isNotEmpty).toList();

    final size = product['chicken_size_weight']?.toString().trim() ?? '';
    final carton = product['chicken_carton_size']?.toString().trim() ?? '';

    if (size.isNotEmpty) values.add(size);
    if (carton.isNotEmpty) values.add(carton);

    return values.isEmpty ? 'Standard' : values.join(' • ');
  }

  Map<String, List<Map<String, dynamic>>> get _groupedFilteredProducts {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final product in _filteredProducts) {
      final specificationId = product['meat_specification_id']
          ?.toString()
          .trim();
      final key = specificationId == null || specificationId.isEmpty
          ? 'product:${product['id']}'
          : specificationId;
      grouped.putIfAbsent(key, () => []).add(product);
    }

    for (final products in grouped.values) {
      products.sort((a, b) => _gradeCode(a).compareTo(_gradeCode(b)));
    }

    return grouped;
  }

  Map<String, dynamic>? _firstPriceListForVisibility(String visibility) {
    for (final priceList in _priceLists) {
      if (priceList['visibility']?.toString() == visibility &&
          priceList['active'] == true) {
        return priceList;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _ensurePriceList({
    required String visibility,
    required String defaultName,
  }) async {
    final existing = _firstPriceListForVisibility(visibility);
    if (existing != null) return existing;

    final supplierId = _supplierBusinessId;
    if (supplierId == null || supplierId.isEmpty) {
      throw Exception('Supplier business could not be identified.');
    }

    final inserted = await Supabase.instance.client
        .from('price_lists')
        .insert({
          'supplier_business_id': supplierId,
          'name': defaultName,
          'visibility': visibility,
          'active': true,
        })
        .select('id, supplier_business_id, name, visibility, active')
        .single();

    final row = Map<String, dynamic>.from(inserted);
    _priceLists.add(row);
    return row;
  }

  Future<void> _saveMatrixProduct(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) {
      throw Exception('Product could not be identified.');
    }

    final stockController = _matrixController(
      _matrixStockControllers,
      productId,
      _matrixNumber(product['available_quantity']),
    );
    final standardController = _matrixController(
      _matrixStandardControllers,
      productId,
      _matrixStandardInitial(product),
    );
    final tradeController = _matrixController(
      _matrixTradeControllers,
      productId,
      _matrixTradeInitial(product),
    );

    final stock = double.tryParse(stockController.text.trim());
    final standard = double.tryParse(standardController.text.trim());
    final tradeText = tradeController.text.trim();
    final trade = tradeText.isEmpty ? null : double.tryParse(tradeText);
    final availability =
        _matrixAvailability[productId] ??
        product['availability_status']?.toString() ??
        'out_of_stock';

    if (stock == null || stock < 0) {
      throw Exception(
        '${_specificationName(product)} • ${_gradeCode(product)}: enter valid stock.',
      );
    }
    if (standard == null || standard < 0) {
      throw Exception(
        '${_specificationName(product)} • ${_gradeCode(product)}: enter a valid Standard price.',
      );
    }
    if (tradeText.isNotEmpty && (trade == null || trade < 0)) {
      throw Exception(
        '${_specificationName(product)} • ${_gradeCode(product)}: enter a valid Trade price.',
      );
    }

    final client = Supabase.instance.client;

    final currentStockRaw = product['available_quantity'];
    final currentStock = currentStockRaw is num
        ? currentStockRaw.toDouble()
        : double.tryParse(currentStockRaw?.toString() ?? '') ?? 0;

    if (stock != currentStock ||
        availability != product['availability_status']?.toString()) {
      await client.rpc(
        'update_supplier_product_stock',
        params: {
          'p_product_id': productId,
          'p_quantity': stock,
          'p_availability_status': availability,
          'p_reason': 'manual_adjustment',
          'p_notes':
              '${_specificationName(product)} • ${_gradeCode(product)} inventory matrix update',
        },
      );
    }

    final standardList = await _ensurePriceList(
      visibility: 'public',
      defaultName: 'Standard Pricing',
    );
    final standardListId = standardList['id']?.toString();
    if (standardListId == null || standardListId.isEmpty) {
      throw Exception('Standard price list could not be identified.');
    }

    await client.from('product_prices').upsert({
      'price_list_id': standardListId,
      'product_id': productId,
      'amount': standard,
      'price_basis': 'kilogram',
      'minimum_quantity': 1,
      'minimum_quantity_unit': 'carton',
      'active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'price_list_id,product_id');

    if (trade != null) {
      final tradeList = await _ensurePriceList(
        visibility: 'approved_customers',
        defaultName: 'Trade Pricing',
      );
      final tradeListId = tradeList['id']?.toString();
      if (tradeListId == null || tradeListId.isEmpty) {
        throw Exception('Trade price list could not be identified.');
      }

      await client.from('product_prices').upsert({
        'price_list_id': tradeListId,
        'product_id': productId,
        'amount': trade,
        'price_basis': 'kilogram',
        'minimum_quantity': 1,
        'minimum_quantity_unit': 'carton',
        'active': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'price_list_id,product_id');
    }

    final offer = _offer(product);
    if (offer != null && offer['id'] != null) {
      await client
          .from('supplier_spec_grade_offers')
          .update({
            'standard_price_inc_gst': standard,
            'is_available': availability != 'out_of_stock',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', offer['id']);
    }
  }

  Future<void> _saveSpecificationGrades(
    String specificationId,
    List<Map<String, dynamic>> products,
  ) async {
    if (_savingSpecificationIds.contains(specificationId)) return;

    setState(() => _savingSpecificationIds.add(specificationId));

    try {
      for (final product in products) {
        await _saveMatrixProduct(product);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_specificationName(products.first)} grades updated.',
          ),
        ),
      );
      await _loadProducts();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _savingSpecificationIds.remove(specificationId));
      }
    }
  }

  String? _productAnimalCode(Map<String, dynamic> product) {
    final animal = _map(product['meat_animals']);
    final code = animal?['code']?.toString().trim().toUpperCase();

    if (code != null && code.isNotEmpty) {
      return code;
    }

    final sectionId = product['meat_section_id']?.toString();
    if (sectionId != null && sectionId.isNotEmpty) {
      for (final section in _sections) {
        if (section['id']?.toString() == sectionId) {
          final fallbackCode = section['animal_code']
              ?.toString()
              .trim()
              .toUpperCase();
          if (fallbackCode != null && fallbackCode.isNotEmpty) {
            return fallbackCode;
          }
        }
      }
    }

    return null;
  }

  List<Map<String, dynamic>> get _selectedAnimalSections {
    return _sections
        .where(
          (section) =>
              section['animal_code']?.toString() == _selectedAnimalCode,
        )
        .toList()
      ..sort(
        (a, b) => ((a['display_order'] as num?)?.toInt() ?? 999).compareTo(
          (b['display_order'] as num?)?.toInt() ?? 999,
        ),
      );
  }

  List<Map<String, dynamic>> get _selectedAnimalProducts {
    return _products
        .where((product) => _productAnimalCode(product) == _selectedAnimalCode)
        .toList();
  }

  List<Map<String, dynamic>> get _availableSpecifications {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (_selectedSectionId != null &&
          product['meat_section_id']?.toString() != _selectedSectionId) {
        continue;
      }

      final specification = _map(product['meat_specifications']);
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
          product['meat_section_id']?.toString() != _selectedSectionId) {
        continue;
      }

      if (_selectedSpecificationId != null &&
          product['meat_specification_id']?.toString() !=
              _selectedSpecificationId) {
        continue;
      }

      final grade = _map(product['meat_grades']);
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

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();
    final directSearch = search.isNotEmpty;
    final cutScopedSearch = directSearch && _selectedSectionId != null;

    return _products.where((product) {
      if (directSearch) {
        if (cutScopedSearch) {
          if (_productAnimalCode(product) != _selectedAnimalCode) {
            return false;
          }

          if (product['meat_section_id']?.toString() != _selectedSectionId) {
            return false;
          }
        }
      } else {
        if (_productAnimalCode(product) != _selectedAnimalCode) {
          return false;
        }

        if (_selectedSectionId != null &&
            product['meat_section_id']?.toString() != _selectedSectionId) {
          return false;
        }

        if (_selectedSpecificationId != null &&
            product['meat_specification_id']?.toString() !=
                _selectedSpecificationId) {
          return false;
        }

        if (_selectedGradeId != null &&
            product['meat_grade_id']?.toString() != _selectedGradeId) {
          return false;
        }
      }

      if (search.isEmpty) return true;

      final values = [
        product['product_name'],
        product['sku'],
        _sectionName(product),
        _sectionCode(product),
        _specificationName(product),
        _gradeName(product),
        product['brand'],
        product['temperature_state'],
        product['halal_status'],
        product['feeding_days'],
        product['bone_state'],
        product['rib_count'],
        product['production_claim'],
        product['hgp_free'],
        product['chicken_skin'],
        product['chicken_bone'],
        product['chicken_production_type'],
        product['chicken_preparation'],
        product['chicken_size_weight'],
        product['chicken_carton_size'],
        if (_isChickenProduct(product)) _chickenVariationLabel(product),
      ];

      return values.any(
        (value) =>
            value != null && value.toString().toLowerCase().contains(search),
      );
    }).toList();
  }

  Map<String, dynamic>? _sectionByCode(String code) {
    for (final section in _selectedAnimalSections) {
      if (section['code']?.toString() == code) {
        return section;
      }
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
      _searchController.clear();
    });
  }

  void _selectAnimalRegion(String regionKey) {
    if (_selectedAnimalCode != CutLinkAnimals.beef) {
      return;
    }

    final sectionCode = _beefSectionCodeForRegion(regionKey);
    if (sectionCode == null) return;

    final section = _sectionByCode(sectionCode);
    if (section == null) return;

    setState(() {
      _selectedAnimalRegionKey = regionKey;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
      _searchController.clear();
    });
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = section['id'].toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
      _searchController.clear();
    });
  }

  String? get _selectedSectionName {
    final selected = _selectedSectionId;
    if (selected == null) return null;

    for (final section in _selectedAnimalSections) {
      if (section['id']?.toString() == selected) {
        return section['name']?.toString();
      }
    }

    return null;
  }

  double _stockNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _stockFormat(dynamic value, {int decimals = 2}) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (number == null) return '0';
    if (number == number.roundToDouble()) return number.toInt().toString();
    return number.toStringAsFixed(decimals);
  }

  String _stockUnitLabel(String? unit, {bool plural = false}) {
    return switch (unit) {
      'carton' => plural ? 'cartons' : 'carton',
      'kilogram' => 'kg',
      'unit' => plural ? 'units' : 'unit',
      _ => unit ?? 'unit',
    };
  }

  bool _tracksSeparateWeight(Map<String, dynamic> product) {
    return product['catch_weight'] == true ||
        product['weight_type']?.toString() == 'catch_weight' ||
        product['available_weight_kg'] != null;
  }

  String _movementDateTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'Unknown time';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour12 = parsed.hour == 0
        ? 12
        : parsed.hour > 12
        ? parsed.hour - 12
        : parsed.hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';

    return '${parsed.day.toString().padLeft(2, '0')} '
        '${months[parsed.month - 1]} ${parsed.year}, '
        '$hour12:$minute $period';
  }

  String _movementLabel(Map<String, dynamic> row) {
    final reason = row['reason']?.toString() ?? '';
    final source = row['source']?.toString() ?? '';

    if (source == 'supplier_inventory_receive_stock' || reason == 'restock') {
      return 'RECEIVED';
    }

    if (reason == 'order_fulfilment' || reason == 'sale') {
      return 'FULFILLED';
    }

    return switch (reason) {
      'initial_stock' => 'OPENING BALANCE',
      'return' => 'RETURN',
      'damaged' => 'DAMAGED',
      'wastage' => 'WASTAGE',
      'supplier_return' => 'SUPPLIER RETURN',
      'correction' => 'ADJUSTMENT',
      'manual_adjustment' => 'ADJUSTMENT',
      'system_adjustment' => 'ADJUSTMENT',
      'cancellation' => 'CANCELLATION',
      _ => 'ADJUSTMENT',
    };
  }

  Color _movementColour(String label) {
    return switch (label) {
      'RECEIVED' => const Color(0xFF197A45),
      'RETURN' => const Color(0xFF197A45),
      'FULFILLED' => const Color(0xFF355C9A),
      'DAMAGED' => const Color(0xFFB15C00),
      'WASTAGE' => const Color(0xFFB3261E),
      'SUPPLIER RETURN' => const Color(0xFFB3261E),
      _ => _darkRed,
    };
  }

  String _signedQuantity(dynamic value) {
    final number = _stockNumber(value);
    if (number > 0) return '+${_stockFormat(number)}';
    return _stockFormat(number);
  }

  Widget _stockSummaryMetric(
    String label,
    String value, {
    bool strong = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: strong ? _darkRed : const Color(0xFF222222),
            fontSize: strong ? 17 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Future<void> _receiveStock(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) return;

    final quantityUnit = product['quantity_unit']?.toString() ?? 'carton';
    final separateWeight = _tracksSeparateWeight(product);
    final currentQuantity = _stockNumber(product['available_quantity']);
    final currentWeight = product['available_weight_kg'] == null
        ? null
        : _stockNumber(product['available_weight_kg']);

    final quantityController = TextEditingController();
    final weightController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    var receivedDate = DateTime.now();
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quantity = double.tryParse(quantityController.text.trim());
            final weight = double.tryParse(weightController.text.trim());
            final wholeQuantity =
                quantityUnit == 'carton' || quantityUnit == 'unit';

            final validQuantity =
                quantityController.text.trim().isEmpty ||
                (quantity != null &&
                    quantity >= 0 &&
                    (!wholeQuantity || quantity == quantity.roundToDouble()));
            final validWeight =
                !separateWeight ||
                weightController.text.trim().isEmpty ||
                (weight != null && weight >= 0);

            final quantityDelta = quantity ?? 0;
            final weightDelta = weight ?? 0;
            final hasMovement =
                quantityDelta > 0 || (separateWeight && weightDelta > 0);

            final newQuantity = currentQuantity + quantityDelta;
            final newWeight = separateWeight
                ? (currentWeight ?? 0) + weightDelta
                : null;

            Future<void> chooseDate() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: receivedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) {
                final now = DateTime.now();
                setDialogState(() {
                  receivedDate = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    now.hour,
                    now.minute,
                  );
                });
              }
            }

            Future<void> submit() async {
              if (saving || !validQuantity || !validWeight || !hasMovement) {
                return;
              }

              setDialogState(() => saving = true);

              try {
                await Supabase.instance.client.rpc(
                  'receive_supplier_stock',
                  params: {
                    'p_product_id': productId,
                    'p_quantity_delta': quantityController.text.trim().isEmpty
                        ? null
                        : quantity,
                    'p_weight_delta_kg':
                        !separateWeight || weightController.text.trim().isEmpty
                        ? null
                        : weight,
                    'p_reference_number':
                        referenceController.text.trim().isEmpty
                        ? null
                        : referenceController.text.trim(),
                    'p_notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    'p_effective_at': receivedDate.toUtc().toIso8601String(),
                  },
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on PostgrestException catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                  setDialogState(() => saving = false);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                  setDialogState(() => saving = false);
                }
              }
            }

            final productName = product['product_name']?.toString().trim();
            final title = productName == null || productName.isEmpty
                ? '${_specificationName(product)} • ${_gradeCode(product)}'
                : productName;

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4E5E5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.move_to_inbox_outlined,
                              color: _darkRed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Receive Stock',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3E3DF)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _stockSummaryMetric(
                                'CURRENT STOCK',
                                '${_stockFormat(currentQuantity)} '
                                    '${_stockUnitLabel(quantityUnit, plural: true)}',
                              ),
                            ),
                            if (separateWeight) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: _stockSummaryMetric(
                                  'CURRENT WEIGHT',
                                  currentWeight == null
                                      ? 'Not yet tracked'
                                      : '${_stockFormat(currentWeight)} kg',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: quantityController,
                        autofocus: true,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: !wholeQuantity,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: quantityUnit == 'kilogram'
                              ? 'Weight Received'
                              : quantityUnit == 'carton'
                              ? 'Cartons Received'
                              : 'Units Received',
                          suffixText: _stockUnitLabel(
                            quantityUnit,
                            plural: true,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (separateWeight) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Physical Weight Received',
                            suffixText: 'kg',
                            helperText:
                                'Physical kg are tracked independently from cartons.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: saving ? null : chooseDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          'Received Date: '
                          '${receivedDate.day.toString().padLeft(2, '0')}/'
                          '${receivedDate.month.toString().padLeft(2, '0')}/'
                          '${receivedDate.year}',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Reference / Docket (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EAEA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD9BDBD)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _stockSummaryMetric(
                                'NEW STOCK',
                                '${_stockFormat(newQuantity)} '
                                    '${_stockUnitLabel(quantityUnit, plural: true)}',
                                strong: true,
                              ),
                            ),
                            if (separateWeight) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: _stockSummaryMetric(
                                  'NEW WEIGHT',
                                  '${_stockFormat(newWeight ?? 0)} kg',
                                  strong: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed:
                                saving ||
                                    !validQuantity ||
                                    !validWeight ||
                                    !hasMovement
                                ? null
                                : submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _darkRed,
                            ),
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(
                              saving ? 'Receiving...' : 'Receive Stock',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    quantityController.dispose();
    weightController.dispose();
    referenceController.dispose();
    notesController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock received successfully.')),
      );
      await _loadProducts();
    }
  }

  Future<void> _adjustStock(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) return;

    final quantityUnit = product['quantity_unit']?.toString() ?? 'carton';
    final separateWeight = _tracksSeparateWeight(product);
    final currentQuantity = _stockNumber(product['available_quantity']);
    final currentWeight = product['available_weight_kg'] == null
        ? null
        : _stockNumber(product['available_weight_kg']);

    final quantityController = TextEditingController(
      text: _stockFormat(currentQuantity),
    );
    final weightController = TextEditingController(
      text: currentWeight == null ? '' : _stockFormat(currentWeight),
    );
    final notesController = TextEditingController();

    var reason = 'correction';
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quantity = double.tryParse(quantityController.text.trim());
            final weight = double.tryParse(weightController.text.trim());
            final wholeQuantity =
                quantityUnit == 'carton' || quantityUnit == 'unit';
            final quantityValid =
                quantity != null &&
                quantity >= 0 &&
                (!wholeQuantity || quantity == quantity.roundToDouble());
            final weightValid =
                !separateWeight ||
                weightController.text.trim().isEmpty ||
                (weight != null && weight >= 0);
            final otherNeedsNote =
                reason == 'manual_adjustment' &&
                notesController.text.trim().isEmpty;

            Future<void> submit() async {
              if (saving || !quantityValid || !weightValid || otherNeedsNote) {
                return;
              }

              setDialogState(() => saving = true);

              try {
                await Supabase.instance.client.rpc(
                  'adjust_supplier_stock',
                  params: {
                    'p_product_id': productId,
                    'p_actual_quantity': quantity,
                    'p_actual_weight_kg':
                        !separateWeight || weightController.text.trim().isEmpty
                        ? null
                        : weight,
                    'p_reason': reason,
                    'p_notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    'p_effective_at': DateTime.now().toUtc().toIso8601String(),
                  },
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on PostgrestException catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                  setDialogState(() => saving = false);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                  setDialogState(() => saving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text(
                'Adjust Stock',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_specificationName(product)} • ${_gradeCode(product)}',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Enter the actual physical stock. CutLink will record the difference in Stock History.',
                        style: TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: quantityController,
                        autofocus: true,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: !wholeQuantity,
                        ),
                        decoration: InputDecoration(
                          labelText: quantityUnit == 'kilogram'
                              ? 'Actual Weight'
                              : quantityUnit == 'carton'
                              ? 'Actual Cartons'
                              : 'Actual Units',
                          suffixText: _stockUnitLabel(
                            quantityUnit,
                            plural: true,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (separateWeight) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Actual Physical Weight',
                            suffixText: 'kg',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      CutLinkPickerField<String>(
                        label: 'Reason',
                        value: reason,
                        enableSearch: false,
                        options: const [
                          CutLinkPickerOption(
                            value: 'correction',
                            label: 'Stock Count / Data Entry Correction',
                          ),
                          CutLinkPickerOption(
                            value: 'damaged',
                            label: 'Damaged',
                          ),
                          CutLinkPickerOption(
                            value: 'wastage',
                            label: 'Wastage',
                          ),
                          CutLinkPickerOption(
                            value: 'manual_adjustment',
                            label: 'Other',
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => reason = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: reason == 'manual_adjustment'
                              ? 'Reason note (required)'
                              : 'Notes (optional)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed:
                      saving || !quantityValid || !weightValid || otherNeedsNote
                      ? null
                      : submit,
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.tune),
                  label: Text(saving ? 'Saving...' : 'Adjust Stock'),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
    weightController.dispose();
    notesController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock adjustment recorded.')),
      );
      await _loadProducts();
    }
  }

  Future<void> _showStockHistory(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    final supplierId = _supplierBusinessId;

    if (productId == null ||
        productId.isEmpty ||
        supplierId == null ||
        supplierId.isEmpty) {
      return;
    }

    var loading = true;
    String? error;
    List<Map<String, dynamic>> movements = [];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var started = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> load() async {
              try {
                final response = await Supabase.instance.client
                    .from('supplier_inventory_stock_ledger')
                    .select(
                      'id, changed_at, effective_at, quantity_before, '
                      'quantity_delta, quantity_after, quantity_unit, '
                      'weight_before_kg, weight_delta_kg, weight_after_kg, '
                      'reason, actor_user_id, source, reference_type, '
                      'reference_id, reference_number, notes',
                    )
                    .eq('supplier_business_id', supplierId)
                    .eq('product_id', productId)
                    .order('effective_at', ascending: false)
                    .limit(200);

                if (!dialogContext.mounted) return;

                setDialogState(() {
                  movements = List<Map<String, dynamic>>.from(response);
                  loading = false;
                  error = null;
                });
              } on PostgrestException catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  error = e.message;
                  loading = false;
                });
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  error = e.toString();
                  loading = false;
                });
              }
            }

            if (!started) {
              started = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => load());
            }

            final currentUserId = Supabase.instance.client.auth.currentUser?.id;

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 820,
                  maxHeight: 760,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4E5E5),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.history, color: _darkRed),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Stock History',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${_specificationName(product)} • ${_gradeCode(product)}',
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : movements.isEmpty
                          ? const Center(
                              child: Text(
                                'No stock movements have been recorded yet.',
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: movements.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final movement = movements[index];
                                final label = _movementLabel(movement);
                                final colour = _movementColour(label);
                                final quantityUnit = movement['quantity_unit']
                                    ?.toString();
                                final actor = movement['actor_user_id']
                                    ?.toString();
                                final reference = movement['reference_number']
                                    ?.toString()
                                    .trim();
                                final notes = movement['notes']
                                    ?.toString()
                                    .trim();

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE3E3DF),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colour.withValues(
                                                alpha: 0.09,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                color: colour,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _movementDateTime(
                                              movement['effective_at'] ??
                                                  movement['changed_at'],
                                            ),
                                            style: const TextStyle(
                                              color: Color(0xFF666666),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 14,
                                        runSpacing: 6,
                                        children: [
                                          Text(
                                            '${_signedQuantity(movement['quantity_delta'])} '
                                            '${_stockUnitLabel(quantityUnit, plural: true)}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          if (movement['weight_delta_kg'] !=
                                              null)
                                            Text(
                                              '${_signedQuantity(movement['weight_delta_kg'])} kg',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Stock: ${_stockFormat(movement['quantity_before'])} '
                                        '→ ${_stockFormat(movement['quantity_after'])} '
                                        '${_stockUnitLabel(quantityUnit, plural: true)}',
                                        style: const TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (movement['weight_after_kg'] != null)
                                        Text(
                                          'Weight: ${_stockFormat(movement['weight_before_kg'])} '
                                          '→ ${_stockFormat(movement['weight_after_kg'])} kg',
                                          style: const TextStyle(
                                            color: Color(0xFF666666),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      if (reference != null &&
                                          reference.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Ref: $reference',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                      if (notes != null &&
                                          notes.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          notes,
                                          style: const TextStyle(
                                            color: Color(0xFF555555),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        actor == null || actor.isEmpty
                                            ? 'Entered by: System'
                                            : actor == currentUserId
                                            ? 'Entered by: You'
                                            : 'Entered by: Staff member',
                                        style: const TextStyle(
                                          color: Color(0xFF777777),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          'My Stock',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : () => _openAddProductPage(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
            style: TextButton.styleFrom(
              foregroundColor: _darkRed,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _isLoading ? null : _loadProducts,
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
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
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              const Text(
                'My Stock could not be loaded',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
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

    final cutSelected = _selectedSectionId != null;
    final subcategorySelected = _selectedSpecificationId != null;
    final gradeSelected = _selectedGradeId != null;
    final directSearch = _searchController.text.trim().isNotEmpty;

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
                  child: Icon(icon, size: 18, color: _darkRed),
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
                  const Icon(Icons.chevron_right, size: 19, color: _darkRed),
              ],
            ),
          ),
        ),
      );
    }

    Widget subcategoryStage() {
      final specifications = _availableSpecifications;

      if (specifications.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No subcategories are linked to this cut yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF777777),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _selectedSectionId == null
                      ? null
                      : () =>
                            _openAddProductPage(sectionId: _selectedSectionId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _darkRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
            },
          );
        },
      );
    }

    Widget gradeStage() {
      final grades = _availableGrades;

      if (grades.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No grades are linked to this subcategory yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF777777),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _selectedSectionId == null
                      ? null
                      : () => _openAddProductPage(
                          sectionId: _selectedSectionId,
                          specificationId: _selectedSpecificationId,
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _darkRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
            },
          );
        },
      );
    }

    Widget stockStage() {
      if (_filteredProducts.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 46,
                  color: Color(0xFFAAAAAA),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No stock matches this selection',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add a product for this cut, subcategory or grade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF777777), height: 1.35),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _openAddProductPage(
                    sectionId: _selectedSectionId,
                    specificationId: _selectedSpecificationId,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _darkRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final groups = _groupedFilteredProducts.entries.toList();

      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final group = groups[index];
          return _buildGradeMatrixCard(group.key, group.value);
        },
      );
    }

    Widget searchBar() {
      return Container(
        padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: _selectedSectionId == null
                ? 'Search all stock — cut, subcategory, SKU, brand...'
                : 'Search within ${_selectedSectionName ?? 'this cut'}...',
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

    Widget resultsPanel() {
      final title = directSearch
          ? 'Search Results'
          : !cutSelected
          ? 'Choose a Cut'
          : !subcategorySelected
          ? 'Subcategories'
          : !gradeSelected
          ? 'Choose Grade'
          : 'My Stock';

      final subtitle = directSearch
          ? 'Matching products in your supplier inventory.'
          : !cutSelected
          ? 'Select a cut from the animal diagram or cut row.'
          : !subcategorySelected
          ? 'Choose the exact subcategory for this cut.'
          : !gradeSelected
          ? 'Choose the commercial grade/category.'
          : 'Update stock, pricing and availability for this selection.';

      final showingStock = directSearch || gradeSelected;

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
                        '${_filteredProducts.length} product${_filteredProducts.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: _darkRed,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            searchBar(),
            Expanded(
              child: directSearch
                  ? stockStage()
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
                  : stockStage(),
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
        selectedColor: _darkRed,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? _darkRed : const Color(0xFFD9D9D5)),
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
            child: Icon(icon, size: 19, color: _darkRed),
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
              selectedColor: _darkRed,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _selectedGradeId == grade['id']?.toString()
                    ? _darkRed
                    : const Color(0xFFD9D9D5),
              ),
              labelStyle: TextStyle(
                color: _selectedGradeId == grade['id']?.toString()
                    ? Colors.white
                    : const Color(0xFF444444),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
              label: Text(
                grade['code']?.toString().trim().isNotEmpty == true
                    ? grade['code'].toString()
                    : grade['name']?.toString() ?? 'Grade',
              ),
              onSelected: (_) {
                setState(() {
                  _selectedGradeId = grade['id']?.toString();
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGradeMatrixCard(
    String specificationId,
    List<Map<String, dynamic>> products,
  ) {
    final first = products.first;
    final specification = _specificationName(first);
    final section = _sectionName(first);
    final saving = _savingSpecificationIds.contains(specificationId);
    final chicken = _isChickenProduct(first);
    final itemWord = chicken ? 'variation' : 'grade';
    final itemWordPlural = chicken ? 'variations' : 'grades';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0DC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      specification,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$section • ${products.length} '
                      '${products.length == 1 ? itemWord : itemWordPlural}',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => _openAddProductPage(
                              sectionId: first['meat_section_id']?.toString(),
                              specificationId: first['meat_specification_id']
                                  ?.toString(),
                            ),
                      icon: const Icon(Icons.add, size: 17),
                      label: Text(chicken ? 'Add Variation' : 'Add Grade'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () => _saveSpecificationGrades(
                              specificationId,
                              products,
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _darkRed,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: saving
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 17),
                      label: Text(
                        saving
                            ? 'Saving'
                            : chicken
                            ? 'Save Products'
                            : 'Save Grades',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return const SizedBox.shrink();
                }

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: chicken ? 245 : 78,
                        child: Text(
                          chicken ? 'VARIATION' : 'GRADE',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'STOCK',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          r'STANDARD $/KG',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          r'TRADE $/KG',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 138),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < products.length; index++) ...[
              _buildGradeMatrixRow(products[index]),
              if (index != products.length - 1)
                const Divider(height: 12, color: Color(0xFFE9E9E5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradeMatrixRow(Map<String, dynamic> product) {
    final productId = product['id'].toString();
    final standardController = _matrixController(
      _matrixStandardControllers,
      productId,
      _matrixStandardInitial(product),
    );
    final tradeController = _matrixController(
      _matrixTradeControllers,
      productId,
      _matrixTradeInitial(product),
    );
    final availability = _matrixAvailability.putIfAbsent(
      productId,
      () => product['availability_status']?.toString() ?? 'out_of_stock',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;

        final chicken = _isChickenProduct(product);
        final gradeBadge = Container(
          width: narrow
              ? null
              : chicken
              ? 235
              : 68,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8E8),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFD8BEBE)),
          ),
          child: Text(
            chicken ? _chickenVariationLabel(product) : _gradeCode(product),
            textAlign: chicken ? TextAlign.left : TextAlign.center,
            maxLines: chicken ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _darkRed,
              fontSize: chicken ? 12.5 : 17,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

        final quantityUnit = product['quantity_unit']?.toString() ?? 'carton';
        final separateWeight = _tracksSeparateWeight(product);
        final weight = product['available_weight_kg'];

        final stockField = Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDADAD6)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_matrixNumber(product['available_quantity']).isEmpty ? '0' : _matrixNumber(product['available_quantity'])} '
                '${_stockUnitLabel(quantityUnit, plural: true)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              if (separateWeight)
                Text(
                  weight == null
                      ? 'kg not yet tracked'
                      : '${_stockFormat(weight)} kg',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );

        final standardField = TextField(
          controller: standardController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            isDense: true,
            prefixText: r'$ ',
            border: OutlineInputBorder(),
          ),
        );

        final tradeField = TextField(
          controller: tradeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            isDense: true,
            prefixText: r'$ ',
            hintText: 'Optional',
            border: OutlineInputBorder(),
          ),
        );

        final statusField = CutLinkPickerField<String>(
          label: 'Status',
          value: availability,
          dense: true,
          enableSearch: false,
          options: const [
            CutLinkPickerOption(value: 'in_stock', label: 'In stock'),
            CutLinkPickerOption(value: 'low_stock', label: 'Low stock'),
            CutLinkPickerOption(value: 'out_of_stock', label: 'Out of stock'),
            CutLinkPickerOption(value: 'made_to_order', label: 'Made to order'),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _matrixAvailability[productId] = value);
          },
        );

        final receiveButton = FilledButton.icon(
          onPressed: () => _receiveStock(product),
          style: FilledButton.styleFrom(
            backgroundColor: _darkRed,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          icon: const Icon(Icons.add_box_outlined, size: 16),
          label: const Text(
            'Receive',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
        );

        final moreButton = PopupMenuButton<String>(
          tooltip: 'More stock actions',
          onSelected: (value) {
            switch (value) {
              case 'adjust':
                _adjustStock(product);
                break;
              case 'history':
                _showStockHistory(product);
                break;
              case 'edit':
                _openEditProductPage(product);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'adjust',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.tune),
                title: Text('Adjust Stock'),
              ),
            ),
            PopupMenuItem(
              value: 'history',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history),
                title: Text('Stock History'),
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.open_in_new),
                title: Text('Open Product Editor'),
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert, size: 19),
        );

        if (narrow) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    gradeBadge,
                    const Spacer(),
                    receiveButton,
                    moreButton,
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: stockField),
                    const SizedBox(width: 8),
                    Expanded(child: standardField),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: tradeField),
                    const SizedBox(width: 8),
                    Expanded(child: statusField),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: chicken ? 245 : 78,
                child: Align(child: gradeBadge),
              ),
              Expanded(flex: 2, child: stockField),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: standardField),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: tradeField),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: statusField),
              const SizedBox(width: 8),
              receiveButton,
              SizedBox(width: 38, child: moreButton),
            ],
          ),
        );
      },
    );
  }
}
