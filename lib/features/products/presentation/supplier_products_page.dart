import '../../../shared/widgets/phone_layout.dart';
import 'dart:async';
import 'dart:convert';

import '../../../shared/widgets/supplier_stock_filters.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/animal_catalogues/product_variant.dart';
import '../../../shared/animal_catalogues/animal_catalogue_registry.dart';
import 'add_product_page.dart';
import 'edit_product_page.dart';
import '../../../shared/widgets/cutlink_picker.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';

class SupplierProductsPage extends StatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  State<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends State<SupplierProductsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
  bool _loadingStock = false;
  String? _stockError;
  String? _stockScope;
  String? _scheduledScope;
  Timer? _stockDebounce;
  int _stockOffset = 0;
  int _stockTotal = 0;
  List<Map<String, dynamic>> _stockOptions = [];
  final _stockFilters = SupplierStockFilters();
  bool _showAllStock = true;
  bool _browseCompact = false;
  final Set<String> _resetProductEditors = {};
  final Map<String, String> _matrixBaselines = {};
  final Map<String, String> _availabilityBaselines = {};

  void _syncMatrixEditors(Map<String, dynamic> product) {
    final id = product['id'].toString();
    final reset = _resetProductEditors.remove(id);
    for (final entry in [
      (_matrixStockControllers, _matrixNumber(product['available_quantity'])),
      (_matrixStandardControllers, _matrixStandardInitial(product)),
      (_matrixTradeControllers, _matrixTradeInitial(product)),
    ]) {
      final key = '${identityHashCode(entry.$1)}:$id';
      final controller = entry.$1[id];
      if (controller != null &&
          (reset || controller.text == _matrixBaselines[key])) {
        controller.text = entry.$2;
      }
      _matrixBaselines[key] = entry.$2;
    }
    final status = product['availability_status']?.toString() ?? 'out_of_stock';
    if (reset ||
        !_matrixAvailability.containsKey(id) ||
        _matrixAvailability[id] == _availabilityBaselines[id]) {
      _matrixAvailability[id] = status;
    }
    _availabilityBaselines[id] = status;
  }

  String get _selectionSignature => jsonEncode([
    _selectedAnimalCode,
    _selectedAnimalRegionKey,
    _selectedSectionId,
    _selectedSpecificationId,
    _selectedGradeId,
    _searchController.text.trim(),
    _chickenAttributeFilters,
    _goatAttributeFilters,
    _stockFilters.signature,
  ]);

  void _scheduleStock() {
    if (_isLoading || _scheduledScope == _selectionSignature) {
      return;
    }
    _scheduledScope = _selectionSignature;
    _stockDebounce?.cancel();
    _stockDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }
      _stockOffset = 0;
      unawaited(_loadStock(force: true));
    });
  }

  List<Map<String, dynamic>> get _scopedStockOptions =>
      _stockOptions.where((p) {
        final globalSearch =
            _searchController.text.trim().isNotEmpty &&
            _selectedSectionId == null &&
            _selectedAnimalRegionKey == null;
        return (globalSearch || _productAnimalCode(p) == _selectedAnimalCode) &&
            (_selectedSectionId == null && _selectedAnimalRegionKey == null ||
                _matchesSelectedCut(p)) &&
            (_selectedSpecificationId == null ||
                p['meat_specification_id']?.toString() ==
                    _selectedSpecificationId) &&
            (_selectedGradeId == null ||
                p['meat_grade_id']?.toString() == _selectedGradeId) &&
            _matchesChickenAttributeFilters(p) &&
            _matchesGoatAttributeFilters(p);
      }).toList();

  Future<void> _openStockFilters() async {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => phoneDialog(
          context,
          AlertDialog(
            title: const Text('Filter inventory'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: SupplierStockFilterBar(
                  rows: _scopedStockOptions,
                  filters: _stockFilters,
                  showGrade: _selectedAnimalCode == CutLinkAnimals.beef,
                  onChanged: () => update(() {}),
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Show products'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() => _showAllStock = true);
    }
  }

  int _stockLoadVersion = 0;
  int _catalogueLoadVersion = 0;
  String? _errorMessage;
  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSectionId;
  String? _selectedSpecificationId;
  String? _selectedGradeId;
  final Map<String, String> _chickenAttributeFilters = <String, String>{};
  final Map<String, String> _goatAttributeFilters = <String, String>{};

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _catalogueSpecifications = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadProducts();
  }

  @override
  void dispose() {
    _stockDebounce?.cancel();
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

  Future<void> _loadStock({bool force = false}) async {
    if (_isLoading || !mounted || _supplierBusinessId == null) {
      return;
    }
    final scope = '$_selectionSignature:$_stockOffset';
    if (!force && _stockScope == scope) {
      return;
    }
    _stockScope = scope;
    _scheduledScope = _selectionSignature;
    _stockDebounce?.cancel();
    final version = ++_stockLoadVersion;
    final keys = _scopedStockOptions
        .where(_stockFilters.matches)
        .map((p) => p['_variant_key'].toString())
        .toSet()
        .toList();
    setState(() {
      _loadingStock = true;
      _stockError = null;
    });
    try {
      final response = await Supabase.instance.client
          .rpc(
            'supplier_stock_page',
            params: {
              'p_supplier_business_id': _supplierBusinessId,
              'p_variant_keys': keys,
              'p_search': _searchController.text.trim(),
              'p_status': _stockFilters.status,
              'p_sort': _stockFilters.sort,
              'p_offset': _stockOffset,
              'p_limit': 40,
            },
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted ||
          version != _stockLoadVersion ||
          scope != '$_selectionSignature:$_stockOffset') {
        return;
      }
      setState(() {
        _products = List<Map<String, dynamic>>.from(
          response['products'] as List,
        );
        _stockTotal = (response['total'] as num).toInt();
        for (final product in _products) {
          _syncMatrixEditors(product);
        }
      });
      if (_stockOffset > 0 && _stockOffset >= _stockTotal) {
        _stockOffset = 0;
        await _loadStock(force: true);
      }
    } catch (error) {
      if (!mounted || version != _stockLoadVersion) {
        return;
      }
      setState(() {
        _products = [];
        _stockError = error is TimeoutException
            ? 'Loading took too long. Please retry.'
            : 'Unable to load products: $error';
      });
    } finally {
      if (mounted && version == _stockLoadVersion) {
        setState(() => _loadingStock = false);
      }
    }
  }

  Widget _stockLoadingStatus() {
    if (_stockError != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(child: Text(_stockError!)),
            TextButton(
              onPressed: () => _loadStock(force: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (!_loadingStock) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text('Loading products… ${_products.length} loaded'),
        ],
      ),
    );
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    final catalogueVersion = ++_catalogueLoadVersion;
    ++_stockLoadVersion;
    _stockScope = null;
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
          .eq('status', 'active')
          .timeout(const Duration(seconds: 20));

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
          .eq('active', true)
          .timeout(const Duration(seconds: 20));

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
          .order('name')
          .timeout(const Duration(seconds: 20));

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
          .order('display_order')
          .timeout(const Duration(seconds: 20));

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
            .order('display_order')
            .timeout(const Duration(seconds: 20));

        sections = [
          for (final raw in sectionResponse)
            {
              ...Map<String, dynamic>.from(raw),
              'animal_code': animalCodeById[raw['animal_id']?.toString()] ?? '',
            },
        ];
      }

      List<Map<String, dynamic>> catalogueSpecifications = [];

      if (sections.isNotEmpty) {
        final sectionIds = sections
            .map((section) => section['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();

        if (sectionIds.isNotEmpty) {
          final specificationResponse = await client
              .from('meat_specifications')
              .select(
                'id, animal_id, section_id, name, slug, display_order, '
                'specification_type, approval_status',
              )
              .inFilter('section_id', sectionIds)
              .eq('is_active', true)
              .order('display_order')
              .order('name')
              .timeout(const Duration(seconds: 20));

          catalogueSpecifications = List<Map<String, dynamic>>.from(
            specificationResponse,
          );
        }
      }

      if (refresh) {
        SupplierStockCatalogue.invalidate(supplierBusinessId);
      }
      final stockOptions = await SupplierStockCatalogue.load(
        supplierBusinessId,
      );
      if (!mounted || catalogueVersion != _catalogueLoadVersion) {
        return;
      }

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _stockOptions = stockOptions;
        _priceLists = List<Map<String, dynamic>>.from(priceListResponse);
        _products = [];
        _sections = sections;
        _catalogueSpecifications = catalogueSpecifications;
        _isLoading = false;
      });
      await _loadStock(force: true);
    } on PostgrestException catch (error) {
      if (!mounted || catalogueVersion != _catalogueLoadVersion) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || catalogueVersion != _catalogueLoadVersion) {
        return;
      }

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
      await _loadProducts(refresh: true);
    }
  }

  Future<void> _openEditProductPage(Map<String, dynamic> product) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProductPage(product: product)),
    );
    if (!mounted) {
      return;
    }
    _resetProductEditors.add(product['id'].toString());
    if (changed == true) {
      await _loadProducts(refresh: true);
    } else {
      await _loadStock(force: true);
    }
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String _sectionName(Map<String, dynamic> product) {
    return _map(product['meat_sections'])?['name']?.toString() ??
        'Unclassified';
  }

  String _specificationName(Map<String, dynamic> product) {
    return _map(product['meat_specifications'])?['name']?.toString() ??
        product['product_name']?.toString() ??
        'Unspecified';
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
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
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
    if (rawPrices is! List) {
      return null;
    }

    for (final raw in rawPrices) {
      if (raw is! Map || raw['active'] != true) {
        continue;
      }
      final price = Map<String, dynamic>.from(raw);
      final rawList = price['price_lists'];
      if (rawList is! Map) {
        continue;
      }
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
    if (number == null) {
      return '';
    }
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
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

    if (size.isNotEmpty) {
      values.add(size);
    }
    if (carton.isNotEmpty) {
      values.add(carton);
    }

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
    if (existing != null) {
      return existing;
    }

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

  bool _matrixHasChanges(Map<String, dynamic> product) {
    final id = product['id'].toString();
    bool changed(
      Map<String, TextEditingController> controllers,
      String initial,
    ) {
      final controller = controllers[id];
      if (controller == null) {
        return false;
      }
      final value = controller.text.trim();
      if (value == initial) {
        return false;
      }
      final number = double.tryParse(value);
      return number == null || number != double.tryParse(initial);
    }

    return changed(
          _matrixStockControllers,
          _matrixNumber(product['available_quantity']),
        ) ||
        changed(_matrixStandardControllers, _matrixStandardInitial(product)) ||
        changed(_matrixTradeControllers, _matrixTradeInitial(product)) ||
        (_matrixAvailability.containsKey(id) &&
            _matrixAvailability[id] !=
                product['availability_status']?.toString());
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

    if (stock == null || !stock.isFinite || stock < 0) {
      throw Exception(
        '${_specificationName(product)} • ${_gradeCode(product)}: enter valid stock.',
      );
    }
    final standardChanged =
        standardController.text.trim() != _matrixStandardInitial(product) &&
        (standard == null ||
            standard != double.tryParse(_matrixStandardInitial(product)));
    final tradeChanged =
        tradeText != _matrixTradeInitial(product) &&
        (trade == null ||
            trade != double.tryParse(_matrixTradeInitial(product)));
    if (standardChanged &&
        (standard == null || !standard.isFinite || standard < 0)) {
      throw Exception(
        '${_specificationName(product)} • ${_gradeCode(product)}: enter a valid Standard price.',
      );
    }
    if (tradeText.isNotEmpty &&
        (trade == null || !trade.isFinite || trade < 0)) {
      throw Exception(
        '${_specificationName(product)} • ${_gradeCode(product)}: enter a valid Trade price.',
      );
    }

    if (tradeChanged && trade == null) {
      throw Exception(
        'Use the product Pricing tab to remove an existing Trade price.',
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

    for (final change in [
      (standardChanged, 'public', standard),
      (tradeChanged, 'approved_customers', trade),
    ]) {
      if (!change.$1 || change.$3 == null) {
        continue;
      }
      final existing = _priceForVisibility(product, change.$2);
      final list = await _ensurePriceList(
        visibility: change.$2,
        defaultName: change.$2 == 'public'
            ? 'Standard Pricing'
            : 'Trade Pricing',
      );
      final catchWeight =
          product['catch_weight'] == true ||
          product['weight_type'] == 'catch_weight';
      await client.from('product_prices').upsert({
        'price_list_id': list['id'],
        'product_id': productId,
        'amount': change.$3,
        'price_basis':
            existing?['price_basis'] ??
            (catchWeight ? 'kilogram' : product['price_basis'] ?? 'kilogram'),
        'minimum_quantity': existing == null ? 1 : existing['minimum_quantity'],
        'minimum_quantity_unit':
            existing?['minimum_quantity_unit'] ??
            (catchWeight
                ? 'carton'
                : product['order_unit'] ??
                      product['quantity_unit'] ??
                      'carton'),
        'active': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'price_list_id,product_id');
    }

    final offer = _offer(product);
    if (offer != null && offer['id'] != null) {
      await client
          .from('supplier_spec_grade_offers')
          .update({
            if (standardChanged && standard != null)
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
    if (_savingSpecificationIds.contains(specificationId)) {
      return;
    }

    final changedProducts = products.where(_matrixHasChanges).toList();
    if (changedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save on this page.')),
      );
      return;
    }
    setState(() => _savingSpecificationIds.add(specificationId));

    try {
      for (final product in changedProducts) {
        await _saveMatrixProduct(product);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${changedProducts.length} product changes saved.'),
        ),
      );
      await _loadStock(force: true);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    return _stockOptions
        .where((product) => _productAnimalCode(product) == _selectedAnimalCode)
        .toList();
  }

  bool _matchesSelectedCut(Map<String, dynamic> product) {
    final regionKey = _selectedAnimalRegionKey;
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);

    if (regionKey != null && catalogue != null) {
      return catalogue.productMatchesRegion(product, regionKey);
    }

    return _selectedSectionId == null ||
        product['meat_section_id']?.toString() == _selectedSectionId;
  }

  bool get _usesGradeStage =>
      AnimalCatalogueRegistry.forCode(_selectedAnimalCode)?.usesGradeStage ??
      true;

  String get _gradeStageLabel =>
      AnimalCatalogueRegistry.forCode(_selectedAnimalCode)?.gradeStageLabel ??
      'Grade';

  List<Map<String, dynamic>> get _availableSpecifications {
    final byId = <String, Map<String, dynamic>>{};
    final selectedSectionId = _selectedSectionId;

    if (selectedSectionId != null) {
      for (final specification in _catalogueSpecifications) {
        if (specification['section_id']?.toString() != selectedSectionId) {
          continue;
        }

        // Supplier-custom rows are supplier-owned. Keep the shared browse list
        // canonical; the supplier's own custom rows are added below from stock.
        if (specification['specification_type']?.toString() ==
            'supplier_custom') {
          continue;
        }

        final id = specification['id']?.toString();
        if (id == null || id.isEmpty) {
          continue;
        }
        byId[id] = specification;
      }
    }

    // Include the supplier's own stocked specifications as well, including
    // supplier-custom specifications that may not belong in the shared list.
    for (final product in _selectedAnimalProducts) {
      if (!_matchesSelectedCut(product)) {
        continue;
      }

      final specification = _map(product['meat_specifications']);
      final id = specification?['id']?.toString();

      if (specification == null || id == null || id.isEmpty) {
        continue;
      }
      byId[id] = specification;
    }

    final rows = byId.values.toList();
    rows.sort((a, b) {
      final aOrder = int.tryParse(a['display_order']?.toString() ?? '') ?? 9999;
      final bOrder = int.tryParse(b['display_order']?.toString() ?? '') ?? 9999;
      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }

      return (a['name']?.toString() ?? '').toLowerCase().compareTo(
        (b['name']?.toString() ?? '').toLowerCase(),
      );
    });
    return rows;
  }

  List<Map<String, dynamic>> get _availableGrades {
    if (!_usesGradeStage) {
      return const [];
    }

    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (!_matchesSelectedCut(product)) {
        continue;
      }

      if (_selectedSpecificationId != null &&
          product['meat_specification_id']?.toString() !=
              _selectedSpecificationId) {
        continue;
      }

      final grade = _map(product['meat_grades']);
      final id = grade?['id']?.toString();

      if (grade == null || id == null || id.isEmpty) {
        continue;
      }
      byId[id] = grade;
    }

    final rows = byId.values.toList();
    rows.sort(
      (a, b) =>
          (a['code']?.toString() ?? '').compareTo(b['code']?.toString() ?? ''),
    );
    return rows;
  }

  bool get _isChickenSelection => _selectedAnimalCode == CutLinkAnimals.chicken;

  List<String> _availableChickenAttributeValues(String field) {
    final values = <String>{};

    for (final product in _selectedAnimalProducts) {
      if ((_selectedSectionId != null || _selectedAnimalRegionKey != null) &&
          !_matchesSelectedCut(product)) {
        continue;
      }

      if (_selectedSpecificationId != null &&
          product['meat_specification_id']?.toString() !=
              _selectedSpecificationId) {
        continue;
      }

      final raw = product[field]?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        values.add(raw);
      }
    }

    final rows = values.toList()
      ..sort(
        (a, b) => _prettyChickenValue(
          a,
        ).toLowerCase().compareTo(_prettyChickenValue(b).toLowerCase()),
      );

    return rows;
  }

  bool _matchesChickenAttributeFilters(Map<String, dynamic> product) {
    if (!_isChickenSelection || _chickenAttributeFilters.isEmpty) {
      return true;
    }

    for (final entry in _chickenAttributeFilters.entries) {
      if (product[entry.key]?.toString() != entry.value) {
        return false;
      }
    }

    return true;
  }

  Widget _buildChickenAttributeStrip() {
    const fields = <MapEntry<String, String>>[
      MapEntry('chicken_production_type', 'Production Type'),
      MapEntry('chicken_skin', 'Skin'),
      MapEntry('chicken_bone', 'Bone'),
      MapEntry('chicken_preparation', 'Preparation'),
      MapEntry('temperature_state', 'Product State'),
      MapEntry('halal_status', 'Halal'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields)
          if (_availableChickenAttributeValues(field.key).isNotEmpty) ...[
            Text(
              field.value.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _thinChoice(
                    label: 'Any',
                    selected: !_chickenAttributeFilters.containsKey(field.key),
                    onTap: () {
                      setState(() {
                        _chickenAttributeFilters.remove(field.key);
                      });
                    },
                  ),
                  for (final value in _availableChickenAttributeValues(
                    field.key,
                  ))
                    _thinChoice(
                      label: _prettyChickenValue(value),
                      selected: _chickenAttributeFilters[field.key] == value,
                      onTap: () {
                        setState(() {
                          _chickenAttributeFilters[field.key] = value;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
          ],
      ],
    );
  }

  bool get _isGoatSelection => _selectedAnimalCode == CutLinkAnimals.goat;

  String _prettyGoatValue(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  List<String> _availableGoatAttributeValues(String field) {
    final values = <String>{};

    for (final product in _selectedAnimalProducts) {
      if ((_selectedSectionId != null || _selectedAnimalRegionKey != null) &&
          !_matchesSelectedCut(product)) {
        continue;
      }

      if (_selectedSpecificationId != null &&
          product['meat_specification_id']?.toString() !=
              _selectedSpecificationId) {
        continue;
      }

      final raw = product[field]?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        values.add(raw);
      }
    }

    final rows = values.toList()
      ..sort(
        (a, b) => _prettyGoatValue(
          a,
        ).toLowerCase().compareTo(_prettyGoatValue(b).toLowerCase()),
      );

    return rows;
  }

  bool _matchesGoatAttributeFilters(Map<String, dynamic> product) {
    if (!_isGoatSelection || _goatAttributeFilters.isEmpty) {
      return true;
    }

    for (final entry in _goatAttributeFilters.entries) {
      if (product[entry.key]?.toString() != entry.value) {
        return false;
      }
    }

    return true;
  }

  Widget _buildGoatAttributeStrip() {
    const fields = <MapEntry<String, String>>[
      MapEntry('bone_state', 'Bone'),
      MapEntry('temperature_state', 'Product State'),
      MapEntry('halal_status', 'Halal'),
      MapEntry('packaging_type', 'Packaging'),
      MapEntry('brand', 'Brand'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields)
          if (_availableGoatAttributeValues(field.key).isNotEmpty) ...[
            Text(
              field.value.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _thinChoice(
                    label: 'Any',
                    selected: !_goatAttributeFilters.containsKey(field.key),
                    onTap: () {
                      setState(() {
                        _goatAttributeFilters.remove(field.key);
                      });
                    },
                  ),
                  for (final value in _availableGoatAttributeValues(field.key))
                    _thinChoice(
                      label: _prettyGoatValue(value),
                      selected: _goatAttributeFilters[field.key] == value,
                      onTap: () {
                        setState(() {
                          _goatAttributeFilters[field.key] = value;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
          ],
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredProducts => _products;

  Map<String, dynamic>? _sectionForRegion(String animalCode, String regionKey) {
    final catalogue = AnimalCatalogueRegistry.forCode(animalCode);
    if (catalogue == null) {
      return null;
    }
    final sections = _sections.where(
      (section) => section['animal_code'] == animalCode,
    );
    final sectionCode = catalogue.sectionCodeForRegion(regionKey);
    if (sectionCode != null) {
      for (final section in sections) {
        if (section['code']?.toString().trim().toUpperCase() ==
            sectionCode.trim().toUpperCase()) {
          return section;
        }
      }
    }
    // Resolve diagram aliases (for example Chicken neck/tail) from the
    // catalogue too. Navigation must never depend on downloaded stock.
    for (final section in sections) {
      for (final specification in _catalogueSpecifications) {
        if (specification['section_id'] != section['id']) {
          continue;
        }
        if (catalogue.productMatchesRegion({
          'meat_sections': section,
          'meat_specifications': specification,
          'product_name': specification['name'],
        }, regionKey)) {
          return section;
        }
      }
    }
    return null;
  }

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) {
      return;
    }

    final catalogue = AnimalCatalogueRegistry.forCode(animalCode);
    final defaultRegionKey = catalogue?.defaultRegionKey;
    final defaultSection = defaultRegionKey == null
        ? null
        : _sectionForRegion(animalCode, defaultRegionKey);

    setState(() {
      _selectedAnimalCode = animalCode;
      _stockFilters.values.clear();
      _selectedAnimalRegionKey = defaultRegionKey;
      _selectedSectionId = defaultSection?['id']?.toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });
    unawaited(_loadStock());
  }

  void _selectAnimalRegion(String regionKey) {
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    if (catalogue == null || !catalogue.regionKeys.contains(regionKey)) {
      return;
    }

    final section = _sectionForRegion(_selectedAnimalCode, regionKey);

    setState(() {
      _selectedAnimalRegionKey = regionKey;
      _selectedSectionId = section?['id']?.toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });
    unawaited(_loadStock());
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = section['id'].toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });
    unawaited(_loadStock());
  }

  String? get _selectedSectionName {
    final selected = _selectedSectionId;
    if (selected == null) {
      return null;
    }

    for (final section in _selectedAnimalSections) {
      if (section['id']?.toString() == selected) {
        return section['name']?.toString();
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: phoneAppBar(
        context,
        AppBar(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _isLoading ? null : () => _loadProducts(refresh: true),
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _savingSpecificationIds.isNotEmpty,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    _scheduleStock();
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

    final cutSelected =
        _selectedSectionId != null || _selectedAnimalRegionKey != null;
    final subcategorySelected = _selectedSpecificationId != null;
    final gradeSelected = !_usesGradeStage || _selectedGradeId != null;
    final directSearch =
        _showAllStock || _searchController.text.trim().isNotEmpty;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 7),
              child: Text(
                _usesGradeStage
                    ? 'Choose the animal, cut, subcategory and $_gradeStageLabel.'
                    : 'Choose the animal, cut and subcategory.',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10.5,
                ),
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
                      Text(
                        'SUBCATEGORY',
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildSpecificationStrip(),
                      if (_isChickenSelection) ...[
                        const SizedBox(height: 10),
                        _buildChickenAttributeStrip(),
                      ],
                      if (_isGoatSelection) ...[
                        const SizedBox(height: 10),
                        _buildGoatAttributeStrip(),
                      ],
                    ],
                    if (subcategorySelected && _usesGradeStage) ...[
                      const SizedBox(height: 8),
                      Text(
                        _gradeStageLabel.toUpperCase(),
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
        key: ValueKey(_stockScope),
        padding: const EdgeInsets.all(10),
        itemCount: specifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 7),
        itemBuilder: (_, index) {
          final specification = specifications[index];
          final name = specification['name']?.toString() ?? 'Subcategory';

          return rightChoiceCard(
            icon: Icons.category_outlined,
            title: name,
            subtitle: _usesGradeStage
                ? 'Choose this subcategory to view its $_gradeStageLabel.'
                : 'Choose this subcategory to view matching stock.',
            onTap: () {
              setState(() {
                _selectedSpecificationId = specification['id']?.toString();
                _selectedGradeId = null;
                _chickenAttributeFilters.clear();
                _goatAttributeFilters.clear();
              });
            },
          );
        },
      );
    }

    Widget gradeStage() {
      final grades = _availableGrades;

      if (grades.isEmpty && _loadingStock) {
        return const Center(child: CircularProgressIndicator());
      }
      if (grades.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No stocked products are available for this subcategory yet.',
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
      if (_loadingStock ||
          _stockScope != '$_selectionSignature:$_stockOffset') {
        return const Center(child: CircularProgressIndicator());
      }
      if (_stockError != null) {
        return const Center(
          child: Text('Unable to load this page. Use Retry above.'),
        );
      }
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
          ? (_searchController.text.trim().isEmpty
                ? 'My Stock'
                : 'Search Results')
          : !cutSelected
          ? 'Choose a Cut'
          : !subcategorySelected
          ? 'Subcategories'
          : _usesGradeStage && !gradeSelected
          ? 'Choose $_gradeStageLabel'
          : 'My Stock';

      final subtitle = directSearch
          ? 'Matching products in your supplier inventory.'
          : !cutSelected
          ? 'Select a cut from the animal diagram or cut row.'
          : !subcategorySelected
          ? 'Choose the exact subcategory for this cut.'
          : _usesGradeStage && !gradeSelected
          ? 'Choose the applicable $_gradeStageLabel.'
          : 'Update stock, pricing and availability for this selection.';

      final showingStock =
          directSearch || (subcategorySelected && gradeSelected);

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
                        '$_stockTotal products',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openStockFilters,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Filters & sort'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllStock = !_showAllStock),
                    child: Text(
                      _showAllStock ? 'Browse cuts' : 'Show all matching stock',
                    ),
                  ),
                ],
              ),
            ),
            _stockLoadingStatus(),
            if (showingStock)
              SupplierStockPager(
                offset: _stockOffset,
                total: _stockTotal,
                loading: _loadingStock,
                onPage: (offset) {
                  _stockOffset = offset;
                  unawaited(_loadStock(force: true));
                },
              ),
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
                  : _usesGradeStage && !gradeSelected
                  ? gradeStage()
                  : stockStage(),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 1200;

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _browseCompact = !_browseCompact),
                        icon: Icon(
                          _browseCompact
                              ? Icons.inventory_2_outlined
                              : Icons.grid_view_outlined,
                        ),
                        label: Text(
                          _browseCompact
                              ? 'Back to products'
                              : 'Choose animal / cut',
                        ),
                      ),
                    ),
                    Expanded(
                      child: _browseCompact ? animalPanel() : resultsPanel(),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 300, child: animalPanel()),
                  const SizedBox(width: 14),
                  Expanded(child: resultsPanel()),
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
      if (!controller.hasClients) {
        return;
      }

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

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

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
              _chickenAttributeFilters.clear();
              _goatAttributeFilters.clear();
            });
            unawaited(_loadStock());
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

    if (specifications.isEmpty) {
      return const SizedBox.shrink();
    }

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

    if (grades.isEmpty) {
      return const SizedBox.shrink();
    }

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
    final chicken = _isChickenProduct(first);
    final specification = _specificationName(first);
    final section = _sectionName(first);
    final saving = _savingSpecificationIds.contains(specificationId);
    const itemWord = 'product on this page';
    const itemWordPlural = 'products on this page';

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
                      label: const Text('Add Variation'),
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
                      label: Text(saving ? 'Saving' : 'Save these products'),
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
                          'STANDARD PRICE',
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
                          'TRADE PRICE',
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

    final variant = <String>[
      product['sku']?.toString() ?? '',
      product['brand']?.toString() ?? '',
      productSizeLabel(product),
      product['breed_program']?.toString() ?? '',
      product['marbling_score']?.toString() ?? '',
      'Price per ${product['price_basis'] ?? 'kilogram'}',
    ].where((v) => v.trim().isNotEmpty).join(' • ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (variant.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 5),
            child: Text(
              variant,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        LayoutBuilder(
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: product['quantity_unit'] == 'kilogram'
                    ? 'kg'
                    : product['quantity_unit'] == 'unit'
                    ? 'units'
                    : 'ctn',
                border: OutlineInputBorder(),
              ),
            );

            final standardField = TextField(
              controller: standardController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                isDense: true,
                prefixText: r'$ ',
                border: OutlineInputBorder(),
              ),
            );

            final tradeField = TextField(
              controller: tradeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                CutLinkPickerOption(
                  value: 'out_of_stock',
                  label: 'Out of stock',
                ),
                CutLinkPickerOption(
                  value: 'made_to_order',
                  label: 'Made to order',
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
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
        ),
      ],
    );
  }
}
