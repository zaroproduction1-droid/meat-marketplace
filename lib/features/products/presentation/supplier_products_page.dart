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
  final ScrollController _sectionScrollController = ScrollController();

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
  String? _selectedVisualLabel;

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
    _sectionScrollController.dispose();
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
            chicken_skin,
            chicken_bone,
            chicken_production_type,
            chicken_preparation,
            chicken_size_weight,
            chicken_carton_size,
            available_quantity,
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

  String get _selectedAnimalName {
    return CutLinkAnimals.all
        .firstWhere(
          (animal) => animal.code == _selectedAnimalCode,
          orElse: () => CutLinkAnimals.all.first,
        )
        .name;
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

  int _sectionProductCount(String sectionId) {
    return _products.where((product) {
      return _productAnimalCode(product) == _selectedAnimalCode &&
          product['meat_section_id']?.toString() == sectionId;
    }).length;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();

    return _products.where((product) {
      if (_productAnimalCode(product) != _selectedAnimalCode) {
        return false;
      }

      if (_selectedSectionId != null &&
          product['meat_section_id']?.toString() != _selectedSectionId) {
        return false;
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
      CutLinkBeefCutKeys.cheek => 'MISC',
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
      CutLinkBeefCutKeys.oxTail => 'MISC',
      CutLinkBeefCutKeys.miscOffalOther => 'MISC',
      _ => null,
    };
  }

  String _beefRegionLabel(String regionKey) {
    return switch (regionKey) {
      CutLinkBeefCutKeys.cheek => 'Cheek',
      CutLinkBeefCutKeys.neck => 'Neck',
      CutLinkBeefCutKeys.shoulder => 'Shoulder',
      CutLinkBeefCutKeys.chuck => 'Chuck',
      CutLinkBeefCutKeys.blade => 'Blade',
      CutLinkBeefCutKeys.brisket => 'Brisket',
      CutLinkBeefCutKeys.shinShank => 'Shin / Shank',
      CutLinkBeefCutKeys.ribs => 'Ribs',
      CutLinkBeefCutKeys.ribEye => 'Rib Eye',
      CutLinkBeefCutKeys.plate => 'Plate',
      CutLinkBeefCutKeys.skirt => 'Skirt',
      CutLinkBeefCutKeys.loin => 'Loin',
      CutLinkBeefCutKeys.flank => 'Flank',
      CutLinkBeefCutKeys.rump => 'Rump',
      CutLinkBeefCutKeys.round => 'Round',
      CutLinkBeefCutKeys.silversideOutside => 'Silverside / Outside',
      CutLinkBeefCutKeys.oxTail => 'Ox Tail',
      CutLinkBeefCutKeys.miscOffalOther => 'Miscellaneous / Offal',
      _ => regionKey,
    };
  }

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) return;

    setState(() {
      _selectedAnimalCode = animalCode;
      _selectedAnimalRegionKey = null;
      _selectedSectionId = null;
      _selectedVisualLabel = null;
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
      _selectedVisualLabel = _beefRegionLabel(regionKey);
      _searchController.clear();
    });
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = section['id'].toString();
      _selectedVisualLabel = section['name']?.toString();
      _searchController.clear();
    });
  }

  void _clearSectionSelection() {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = null;
      _selectedVisualLabel = null;
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

  bool get _searching => _searchController.text.trim().isNotEmpty;

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

    return Column(
      children: [
        _buildSearchHeader(),
        Expanded(
          child: _searching
              ? _buildImmediateResults(
                  title: 'Search Results',
                  showBackToCow: false,
                )
              : _selectedSectionId != null
              ? _buildImmediateResults(
                  title:
                      '${_selectedVisualLabel ?? _selectedSectionName ?? 'Selected'} Stock',
                  showBackToCow: true,
                )
              : _buildBrowseView(),
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1250),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: (_) => _refresh(),
                decoration: InputDecoration(
                  hintText: _selectedAnimalCode == CutLinkAnimals.chicken
                      ? 'Search cut, sub-cut, skin, bone, state, brand or SKU'
                      : 'Search cut, specification, category, product name or SKU',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF8F8F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E2DE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E2DE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _darkRed, width: 1.5),
                  ),
                ),
              ),
              if (_searching) ...[
                const SizedBox(height: 10),
                Text(
                  '${_filteredProducts.length} search result${_filteredProducts.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImmediateResults({
    required String title,
    required bool showBackToCow,
  }) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${_filteredProducts.length} product${_filteredProducts.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showBackToCow) ...[
                    const SizedBox(width: 14),
                    OutlinedButton.icon(
                      onPressed: _clearSectionSelection,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to animal'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    showBackToCow
                        ? 'No stock has been added for this section yet.'
                        : 'No stock matches your search.',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final groups = _groupedFilteredProducts.entries.toList();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 110),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1250),
                            child: _buildGradeMatrixCard(
                              group.key,
                              group.value,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBrowseView() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Browse $_selectedAnimalName Stock',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Use the arrows to switch animals. Select a cut '
                                'region or section to filter your stock.',
                                style: TextStyle(color: Color(0xFF666666)),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedSectionId != null)
                          TextButton.icon(
                            onPressed: _clearSectionSelection,
                            icon: const Icon(Icons.close),
                            label: const Text('Show all stock'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InteractiveAnimalBrowser(
                      selectedAnimalCode: _selectedAnimalCode,
                      selectedRegionKey: _selectedAnimalRegionKey,
                      onAnimalChanged: _selectAnimal,
                      onRegionSelected: _selectAnimalRegion,
                      maxWidth: 760,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionStrip(),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedSectionName == null
                            ? 'All $_selectedAnimalName Stock'
                            : '${_selectedSectionName!} Stock',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${_filteredProducts.length} product${_filteredProducts.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_filteredProducts.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 55, 24, 100),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 52,
                      color: Color(0xFF999999),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedSectionName == null
                          ? 'No $_selectedAnimalName stock has been added yet.'
                          : 'No ${_selectedSectionName!} stock has been added yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_selectedSectionId != null) ...[
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () =>
                            _openAddProductPage(sectionId: _selectedSectionId),
                        style: FilledButton.styleFrom(
                          backgroundColor: _darkRed,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Add Product to ${_selectedSectionName ?? 'Section'}',
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$_selectedAnimalName and '
                        '${_selectedSectionName ?? 'this section'} '
                        'will be selected automatically.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
              final groups = _groupedFilteredProducts.entries.toList();
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 110),
                sliver: SliverList.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1250),
                        child: _buildGradeMatrixCard(group.key, group.value),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _scrollSectionStrip(double direction) async {
    if (!_sectionScrollController.hasClients) {
      return;
    }

    final position = _sectionScrollController.position;
    final target = (_sectionScrollController.offset + (320 * direction))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    await _sectionScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _buildSectionStrip() {
    final sections = _selectedAnimalSections;

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        IconButton(
          tooltip: 'Previous cut sections',
          onPressed: () => _scrollSectionStrip(-1),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _sectionScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final section in sections) ...[
                  _sectionChip(section),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next cut sections',
          onPressed: () => _scrollSectionStrip(1),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _sectionChip(Map<String, dynamic> section) {
    final id = section['id'].toString();
    final selected = _selectedSectionId == id;
    final count = _sectionProductCount(id);

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => _selectSection(section),
      selectedColor: const Color(0xFFF3E8E8),
      side: BorderSide(color: selected ? _darkRed : const Color(0xFFD9D9D5)),
      label: Text(
        '${section['name']} ($count)',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? _darkRed : const Color(0xFF4D4D4D),
        ),
      ),
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
                      const SizedBox(width: 38),
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

        final stockField = TextField(
          controller: stockController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            isDense: true,
            suffixText: 'ctn',
            border: OutlineInputBorder(),
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

        final editButton = IconButton(
          tooltip: 'Open full product editor',
          onPressed: () => _openEditProductPage(product),
          icon: const Icon(Icons.open_in_new, size: 18),
          visualDensity: VisualDensity.compact,
        );

        if (narrow) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [gradeBadge, const Spacer(), editButton]),
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
              SizedBox(width: 38, child: editButton),
            ],
          ),
        );
      },
    );
  }
}
