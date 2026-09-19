import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/animal_catalogues/product_variant.dart';
import '../../../shared/widgets/cutlink_picker.dart';
import 'marketplace_product_details_page.dart';
import '../../orders/presentation/draft_orders_page.dart';
import '../../../shared/animal_catalogues/animal_catalogue_registry.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';
import '../../../shared/widgets/cutlink_notice.dart';
import '../../../shared/widgets/catalogue_product_image.dart';
import '../../../shared/animal_catalogues/catalogue_search.dart';

class MarketplaceProductsPage extends StatefulWidget {
  const MarketplaceProductsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MarketplaceProductsPage> createState() =>
      _MarketplaceProductsPageState();
}

class _MarketplaceProductsPageState extends State<MarketplaceProductsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _supplierSearchController =
      TextEditingController();

  final ScrollController _cutScrollController = ScrollController();
  final ScrollController _subcategoryScrollController = ScrollController();
  final ScrollController _gradeScrollController = ScrollController();
  final ScrollController _finalSpecificationScrollController =
      ScrollController();

  bool _isLoading = true;
  bool _loadingStock = false;
  String? _stockError;
  String? _stockScope;
  int _stockLoadVersion = 0;
  int _catalogueLoadVersion = 0;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _facetProducts = [];
  String? _facetScope;
  DateTime? _facetsLoadedAt;
  static const _stockPageSize = 60;
  int _stockPageOffset = 0;
  int _stockTotal = 0;
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _catalogueAnimals = [];
  List<Map<String, dynamic>> _catalogueSections = [];
  List<Map<String, dynamic>> _catalogueSpecifications = [];

  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSectionId;
  String? _selectedSpecificationId;
  String? _selectedGradeId;
  String? _selectedCommercialSpecificationKey;
  String? _selectedPieceSize;
  String _selectedProgram = '';
  String _selectedMarbling = '';
  String _selectedBrand = '';
  bool _stockViewActive = false;
  bool _filtersExpanded = false;

  void _resetVariants() {
    _stockViewActive = false;
    _selectedPieceSize = null;
    _selectedProgram = '';
    _selectedMarbling = '';
    _selectedBrand = '';
  }

  bool _matchesVariants(
    Map<String, dynamic> p, {
    bool grade = false,
    bool brand = true,
    bool marbling = true,
  }) {
    return (_selectedPieceSize == null ||
            _selectedPieceSize!.isEmpty ||
            productSizeLabel(p) == _selectedPieceSize) &&
        (_selectedProgram.isEmpty || productProgram(p) == _selectedProgram) &&
        (!marbling ||
            _selectedMarbling.isEmpty ||
            (p['marbling_score']?.toString().trim() ?? '') ==
                _selectedMarbling) &&
        (!brand ||
            _selectedBrand.isEmpty ||
            (p['brand']?.toString().trim() ?? '') == _selectedBrand) &&
        (!grade ||
            _selectedGradeId == null ||
            _matchesGrade(p, _selectedGradeId!));
  }

  List<Map<String, dynamic>> get _variantScope => _facetProducts.where((p) {
    final hasCut =
        _selectedSectionId != null || _selectedAnimalRegionKey != null;
    if (hasCut &&
        (_animalCode(p) != _selectedAnimalCode || !_matchesSelectedCut(p))) {
      return false;
    }
    if (_selectedSpecificationId != null &&
        !_matchesSpecification(p, _selectedSpecificationId!)) {
      return false;
    }
    if (_halalOnly && p['halal_status'] != 'halal') {
      return false;
    }
    if (_availableOnly && p['availability_status'] == 'out_of_stock') {
      return false;
    }
    return true;
  }).toList();

  List<String> get _pieceSizes =>
      _variantScope.map(productSizeLabel).toSet().toList()..sort();

  Widget _variantFilters() {
    final scope = _variantScope;
    final sizes = _pieceSizes;
    final sized = scope
        .where(
          (p) =>
              _selectedPieceSize == null ||
              _selectedPieceSize!.isEmpty ||
              productSizeLabel(p) == _selectedPieceSize,
        )
        .toList();
    final programs =
        sized.map(productProgram).where((v) => v.isNotEmpty).toSet().toList()
          ..sort();
    final marbling =
        sized
            .where(
              (p) =>
                  _selectedProgram.isEmpty ||
                  productProgram(p) == _selectedProgram,
            )
            .map((p) => p['marbling_score']?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final brands =
        scope
            .where((p) => _matchesVariants(p, grade: true, brand: false))
            .map((p) => p['brand']?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    Widget picker(
      String label,
      String selected,
      List<String> values,
      ValueChanged<String> change,
    ) => SizedBox(
      width: 210,
      child: CutLinkPickerField<String>(
        label: label,
        value: selected,
        dense: true,
        options: [
          CutLinkPickerOption(value: '', label: 'Any ${label.toLowerCase()}'),
          for (final v in {...values, if (selected.isNotEmpty) selected})
            CutLinkPickerOption(value: v, label: v),
        ],
        onChanged: (v) {
          if (v == null) {
            return;
          }
          setState(() => change(v));
          _applySearch();
        },
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (sizes.length > 1 || _selectedPieceSize?.isNotEmpty == true)
            picker(
              'Size',
              _selectedPieceSize ?? '',
              sizes.where((v) => v.isNotEmpty).toList(),
              (v) {
                _selectedPieceSize = v;
                _selectedCommercialSpecificationKey = null;
              },
            ),
          if (programs.isNotEmpty || _selectedProgram.isNotEmpty)
            picker('Program', _selectedProgram, programs, (v) {
              _selectedProgram = v;
              _selectedCommercialSpecificationKey = null;
            }),
          if (marbling.isNotEmpty || _selectedMarbling.isNotEmpty)
            picker(
              _selectedProgram == 'Wagyu' ? 'Wagyu MB' : 'Marbling',
              _selectedMarbling,
              marbling,
              (v) {
                _selectedMarbling = v;
                _selectedCommercialSpecificationKey = null;
              },
            ),
          if (brands.isNotEmpty || _selectedBrand.isNotEmpty)
            picker('Brand', _selectedBrand, brands, (v) {
              _selectedBrand = v;
              _selectedCommercialSpecificationKey = null;
            }),
        ],
      ),
    );
  }

  String _sortMode = 'recommended';
  bool _availableOnly = false;
  bool _halalOnly = false;
  Timer? _searchDebounce;
  final Map<String, String> _chickenAttributeFilters = <String, String>{};
  final Map<String, String> _goatAttributeFilters = <String, String>{};
  String? _butcherBusinessId;
  String? _addingProductId;
  final Map<String, int> _cartQuantities = <String, int>{};
  late final AnimationController _cartBounceController;
  late final Animation<double> _cartBounceScale;
  Timer? _cartBounceTimer;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _cartBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _cartBounceScale = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _cartBounceController, curve: Curves.easeInOut),
    );
    _searchController.addListener(_onSearchChanged);
    _supplierSearchController.addListener(_onSearchChanged);
    _loadButcherBusinessId();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _supplierSearchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _supplierSearchController.dispose();
    _cutScrollController.dispose();
    _subcategoryScrollController.dispose();
    _gradeScrollController.dispose();
    _finalSpecificationScrollController.dispose();
    _cartBounceTimer?.cancel();
    _searchDebounce?.cancel();
    _cartBounceController.dispose();
    super.dispose();
  }

  Future<void> _loadButcherBusinessId() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return;
      }

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _butcherBusinessId = membership['business_id']?.toString();
      });

      await _loadCartItemCount();
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

    if (minimum == null || minimum <= 1) {
      return 1;
    }
    return minimum.ceil();
  }

  int _cartQuantity(Map<String, dynamic> product) {
    final id = product['id']?.toString();
    if (id == null) {
      return _minimumCartQuantity(product);
    }

    return _cartQuantities[id] ?? _minimumCartQuantity(product);
  }

  void _changeCartQuantity(Map<String, dynamic> product, int delta) {
    final id = product['id']?.toString();
    if (id == null) {
      return;
    }

    final minimum = _minimumCartQuantity(product);
    final current = _cartQuantity(product);
    final next = current + delta;

    setState(() {
      _cartQuantities[id] = next < minimum ? minimum : next;
    });
  }

  Future<void> _loadCartItemCount() async {
    final butcherBusinessId = _butcherBusinessId;
    if (butcherBusinessId == null || butcherBusinessId.isEmpty) {
      return;
    }

    try {
      final drafts = await Supabase.instance.client
          .from('orders')
          .select('id, order_items(id)')
          .eq('butcher_business_id', butcherBusinessId)
          .eq('status', 'draft');

      var count = 0;
      for (final raw in drafts) {
        final items = raw['order_items'];
        if (items is List) {
          count += items.length;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() => _cartItemCount = count);
      _syncCartBounce();
    } on PostgrestException {
      // Cart badge is supplementary; product browsing must still work if it fails.
    }
  }

  void _syncCartBounce() {
    _cartBounceTimer?.cancel();
    _cartBounceController.stop();
    _cartBounceController.value = 0;

    if (_cartItemCount <= 0) {
      return;
    }

    Future<void> bounce() async {
      if (!mounted ||
          _cartItemCount <= 0 ||
          _cartBounceController.isAnimating) {
        return;
      }
      await _cartBounceController.forward(from: 0);
      if (!mounted) {
        return;
      }
      await _cartBounceController.reverse();
    }

    bounce();
    _cartBounceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      bounce();
    });
  }

  Future<void> _openCart() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DraftOrdersPage()));
    if (mounted) {
      await _loadCartItemCount();
    }
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
      CutLinkNotice.show(
        context,
        message: 'Your butcher business could not be identified.',
        title: 'Cart unavailable',
        error: true,
      );
      return;
    }

    final visiblePrice = _findVisiblePrice(product);
    final rawPrice = visiblePrice?['amount'];
    final unitPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');

    if (visiblePrice == null || unitPrice == null) {
      CutLinkNotice.show(
        context,
        message: 'This supplier offer does not have a visible price.',
        title: 'Price unavailable',
        error: true,
      );
      return;
    }

    if (product['availability_status']?.toString() == 'out_of_stock') {
      CutLinkNotice.show(
        context,
        message: 'This item is currently out of stock.',
        title: 'Out of stock',
        error: true,
      );
      return;
    }

    final supplierBusinessId = product['supplier_business_id']?.toString();
    if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
      CutLinkNotice.show(
        context,
        message: 'Supplier information is missing.',
        title: 'Supplier unavailable',
        error: true,
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

      if (!mounted) {
        return;
      }

      CutLinkNotice.show(
        context,
        title: 'Added to cart',
        message: orderNumber == null || orderNumber.trim().isEmpty
            ? '${_specificationName(product)} added to cart.'
            : '${_specificationName(product)} added to $orderNumber.',
      );
      await _loadCartItemCount();
    } on PostgrestException catch (error) {
      if (mounted) {
        CutLinkNotice.show(
          context,
          message: error.message,
          title: 'Could not update cart',
          error: true,
        );
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

  Future<void> _loadStock({bool force = false, int offset = 0}) async {
    if (_isLoading || !mounted) {
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final cutSelected =
        _selectedSectionId != null || _selectedAnimalRegionKey != null;
    final directSearch = _searchController.text.trim().isNotEmpty || _halalOnly;
    final globalSearch = directSearch && !cutSelected;
    final animal = _catalogueAnimals.where(
      (row) => row['code'] == _selectedAnimalCode,
    );
    final animalId = globalSearch || animal.isEmpty
        ? null
        : animal.first['id']?.toString();
    // Non-beef diagrams can group several sections. Their lightweight index
    // retains the existing region matcher before requesting a result page.
    final sectionId = globalSearch || _selectedAnimalCode != CutLinkAnimals.beef
        ? null
        : _selectedCatalogueSectionId;
    final facetScope = jsonEncode([userId, animalId, sectionId]);
    final scope = jsonEncode([
      facetScope,
      _selectedAnimalRegionKey,
      _selectedSpecificationId,
      _selectedGradeId,
      _selectedCommercialSpecificationKey,
      _selectedPieceSize,
      _selectedProgram,
      _selectedMarbling,
      _selectedBrand,
      _halalOnly,
      _availableOnly,
      _chickenAttributeFilters,
      _goatAttributeFilters,
      _searchController.text.trim(),
      _supplierSearchController.text.trim(),
      _sortMode,
      offset,
    ]);
    if (!force && _stockScope == scope) {
      return;
    }
    _stockScope = scope;
    final version = ++_stockLoadVersion;
    setState(() {
      _products = [];
      _filteredProducts = [];
      _stockTotal = 0;
      _stockPageOffset = offset;
      _stockError = null;
      _loadingStock = cutSelected || directSearch;
      if (_facetScope != facetScope || force) {
        _facetProducts = [];
      }
    });
    if (!cutSelected && !directSearch) {
      return;
    }
    try {
      if (userId == null) {
        throw StateError('Your session has ended. Please sign in again.');
      }
      if (!globalSearch && animalId == null) {
        throw StateError('Select an animal first.');
      }
      if (!globalSearch &&
          _selectedAnimalCode == CutLinkAnimals.beef &&
          sectionId == null) {
        throw StateError(
          'This cut could not be matched. Please refresh the catalogue.',
        );
      }
      final refreshIndex =
          force ||
          _facetScope != facetScope ||
          _facetsLoadedAt == null ||
          DateTime.now().difference(_facetsLoadedAt!) >
              const Duration(minutes: 1);
      if (refreshIndex) {
        final raw = await Supabase.instance.client
            .rpc(
              'marketplace_catalogue_index',
              params: {'p_animal_id': animalId, 'p_section_id': sectionId},
            )
            .timeout(const Duration(seconds: 20));
        if (!mounted ||
            version != _stockLoadVersion ||
            Supabase.instance.client.auth.currentUser?.id != userId) {
          return;
        }
        final result = Map<String, dynamic>.from(raw as Map);
        final animals = {
          for (final row in _catalogueAnimals) row['id'].toString(): row,
        };
        final sections = {
          for (final row in _catalogueSections) row['id'].toString(): row,
        };
        final specifications = {
          for (final row in _catalogueSpecifications) row['id'].toString(): row,
        };
        final grades = {
          for (final rawGrade in result['grades'] as List)
            (rawGrade as Map)['id'].toString(): Map<String, dynamic>.from(
              rawGrade,
            ),
        };
        _facetProducts =
            [
                  for (final rawVariant in result['variants'] as List)
                    Map<String, dynamic>.from(rawVariant as Map),
                ]
                .map(
                  (row) => <String, dynamic>{
                    ...row,
                    'meat_animals': animals[row['meat_animal_id']],
                    'meat_sections': sections[row['meat_section_id']],
                    'meat_specifications':
                        specifications[row['meat_specification_id']],
                    'meat_grades': grades[row['meat_grade_id']],
                  },
                )
                .toList();
        _facetScope = facetScope;
        _facetsLoadedAt = DateTime.now();
      }
      final sizeReady = _selectedPieceSize != null || _pieceSizes.length <= 1;
      final specificationReady = _usesGradeStage
          ? _selectedGradeId != null || _availableGrades.length == 1
          : _selectedCommercialSpecificationKey != null ||
                _availableCommercialSpecifications.length == 1;
      // Browsing choices needs no prices, supplier joins or full product rows.
      if (!_stockViewActive &&
          !directSearch &&
          !(_selectedSpecificationId != null &&
              sizeReady &&
              specificationReady)) {
        return;
      }
      _stockViewActive = true;
      final keys = _facetProducts
          .where((product) {
            if (!globalSearch &&
                (_animalCode(product) != _selectedAnimalCode ||
                    !_matchesSelectedCut(product))) {
              return false;
            }
            if (_selectedSpecificationId != null &&
                !_matchesSpecification(product, _selectedSpecificationId!)) {
              return false;
            }
            if (_usesGradeStage &&
                _selectedGradeId != null &&
                !_matchesGrade(product, _selectedGradeId!)) {
              return false;
            }
            if (_halalOnly && product['halal_status'] != 'halal') {
              return false;
            }
            if (_availableOnly &&
                product['availability_status'] == 'out_of_stock') {
              return false;
            }
            return _matchesVariants(product) &&
                _matchesCommercialSpecification(product) &&
                _matchesChickenAttributeFilters(product) &&
                _matchesGoatAttributeFilters(product);
          })
          .map((p) => p['_variant_key'].toString())
          .toList();
      if (keys.isEmpty) {
        return;
      }
      final raw = await Supabase.instance.client
          .rpc(
            'marketplace_stock_page',
            params: {
              'p_animal_id': animalId,
              'p_section_id': sectionId,
              'p_variant_keys': keys,
              'p_search': _searchController.text.trim(),
              'p_supplier_search': _supplierSearchController.text.trim(),
              'p_sort': _sortMode,
              'p_offset': offset,
              'p_limit': _stockPageSize,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted ||
          version != _stockLoadVersion ||
          Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      final result = Map<String, dynamic>.from(raw as Map);
      setState(() {
        _products = List<Map<String, dynamic>>.from(result['products'] as List);
        _filteredProducts = _products;
        _stockTotal = (result['total'] as num).toInt();
      });
    } catch (error) {
      if (!mounted || version != _stockLoadVersion) {
        return;
      }
      setState(() {
        _stockScope = null;
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
          const Text('Loading matching products…'),
        ],
      ),
    );
  }

  Future<void> _loadProducts() async {
    final catalogueVersion = ++_catalogueLoadVersion;
    ++_stockLoadVersion;
    _stockScope = null;
    _facetScope = null;
    _facetsLoadedAt = null;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalogueAnimalResponse = await Supabase.instance.client
          .from('meat_animals')
          .select('id, code, name')
          .eq('is_active', true)
          .timeout(const Duration(seconds: 20));

      final catalogueSectionResponse = await Supabase.instance.client
          .from('meat_sections')
          .select('id, animal_id, code, name, slug, hotspot_key, display_order')
          .eq('is_active', true)
          .order('display_order')
          .timeout(const Duration(seconds: 20));

      final catalogueSpecificationResponse = await Supabase.instance.client
          .from('meat_specifications')
          .select(
            'id, animal_id, section_id, name, slug, display_order, '
            'specification_type, approval_status, alternate_names',
          )
          .eq('is_active', true)
          .order('display_order')
          .timeout(const Duration(seconds: 20));

      if (!mounted || catalogueVersion != _catalogueLoadVersion) {
        return;
      }

      setState(() {
        _products = [];
        _catalogueAnimals = List<Map<String, dynamic>>.from(
          catalogueAnimalResponse,
        );
        _catalogueSections = List<Map<String, dynamic>>.from(
          catalogueSectionResponse,
        );
        _catalogueSpecifications = List<Map<String, dynamic>>.from(
          catalogueSpecificationResponse,
        );
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

  Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
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

  bool _marketplaceCatalogueVisible(Map<String, dynamic> product) {
    final specificationId = product['meat_specification_id']?.toString();
    if (specificationId == null || specificationId.isEmpty) {
      return true;
    }

    return _nestedMap(product['meat_specifications']) != null;
  }

  List<Map<String, dynamic>> get _selectedAnimalProducts {
    return _facetProducts.where((product) {
      if (!_marketplaceCatalogueVisible(product)) {
        return false;
      }

      final animalCode = _animalCode(product);

      if (animalCode.isEmpty) {
        return false;
      }

      return animalCode == _selectedAnimalCode;
    }).toList();
  }

  String? get _selectedSectionName {
    final regionKey = _selectedAnimalRegionKey;
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);

    if (regionKey != null && catalogue != null) {
      return catalogue.regionLabel(regionKey);
    }

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

    final animalIds = _catalogueAnimals
        .where((animal) => animal['code'] == _selectedAnimalCode)
        .map((animal) => animal['id']?.toString())
        .whereType<String>()
        .toSet();
    for (final section in _catalogueSections) {
      final id = section['id']?.toString();
      if (id != null && animalIds.contains(section['animal_id']?.toString())) {
        byId[id] = section;
      }
    }

    for (final product in _selectedAnimalProducts) {
      final section = _nestedMap(product['meat_sections']);
      final id = section?['id']?.toString();
      if (section == null || id == null || id.isEmpty) {
        continue;
      }
      byId[id] = section;
    }

    final rows = byId.values.toList();
    rows.sort((a, b) {
      final aOrder = int.tryParse(a['display_order']?.toString() ?? '') ?? 9999;
      final bOrder = int.tryParse(b['display_order']?.toString() ?? '') ?? 9999;
      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }
      return (a['name']?.toString() ?? '').compareTo(
        b['name']?.toString() ?? '',
      );
    });
    return rows;
  }

  bool _matchesSelectedCut(Map<String, dynamic> product) {
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    final region = _selectedAnimalRegionKey;
    if (catalogue == null || region == null) {
      return _selectedSectionId == null ||
          _productSectionId(product) == _selectedSectionId;
    }
    final section = _nestedMap(product['meat_sections']);
    final code = section?['code']?.toString().toUpperCase() ?? '';
    final expected = catalogue.sectionCodeForRegion(region);
    final spec = _nestedMap(product['meat_specifications']);
    final name = (spec?['name'] ?? product['product_name'] ?? '')
        .toString()
        .toLowerCase();
    if (_selectedAnimalCode == CutLinkAnimals.chicken) {
      // Neck/tail share a storage section with other parts, not a buying choice.
      if (region == 'wing') {
        return code == 'WING' || code == 'WINGS';
      }
      if (region == 'neck') {
        return name.contains('neck');
      }
      if (region == 'tail') {
        return name.contains('tail');
      }
      if (code.isNotEmpty) {
        if (region == 'back-frame') {
          return code == 'BONES_FRAMES_SKIN' && !name.contains('neck');
        }
        if (region == 'misc-offal-other') {
          return code == 'OFFAL_OTHER' ||
              (code == 'OTHER' &&
                  RegExp(
                    r'offal|liver|heart|gizzard|giblet|feet',
                  ).hasMatch(name));
        }
        return code == expected;
      }
    }
    final aliases = <String, Set<String>>{
      'RACK_RIB': {'RACK'},
      'CHUMP_RUMP': {'CHUMP', 'RUMP'},
      'SHOULDER_BLADE': {'SHOULDER'},
      'BRISKET_BREAST': {'BREAST'},
      'LEG_ROUND': {'LEG'},
      'SHIN_SHANK': {'SHANK'},
    };
    if (code == expected || (aliases[expected]?.contains(code) ?? false)) {
      return true;
    }
    return catalogue.productMatchesRegion(product, region);
  }

  bool get _usesGradeStage =>
      AnimalCatalogueRegistry.forCode(_selectedAnimalCode)?.usesGradeStage ??
      true;

  String get _gradeStageLabel =>
      AnimalCatalogueRegistry.forCode(_selectedAnimalCode)?.gradeStageLabel ??
      'Grade';

  String _normaliseCatalogueKey(dynamic value) {
    return (value?.toString() ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String? get _selectedCatalogueSectionId {
    final directSectionId = _selectedSectionId;
    if (directSectionId != null && directSectionId.isNotEmpty) {
      return directSectionId;
    }

    final regionKey = _selectedAnimalRegionKey;
    if (regionKey == null) {
      return null;
    }

    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    final expectedCode = catalogue?.sectionCodeForRegion(regionKey);
    final expectedLabel = catalogue?.regionLabel(regionKey) ?? regionKey;

    String? animalId;
    for (final animal in _catalogueAnimals) {
      if (animal['code']?.toString().toUpperCase() == _selectedAnimalCode) {
        animalId = animal['id']?.toString();
        break;
      }
    }
    if (animalId == null) {
      return null;
    }

    final targetCode = _normaliseCatalogueKey(expectedCode);
    final targetRegion = _normaliseCatalogueKey(regionKey);
    final targetLabel = _normaliseCatalogueKey(expectedLabel);

    for (final section in _catalogueSections) {
      if (section['animal_id']?.toString() != animalId) {
        continue;
      }

      final code = _normaliseCatalogueKey(section['code']);
      final name = _normaliseCatalogueKey(section['name']);
      final slug = _normaliseCatalogueKey(section['slug']);
      final hotspot = _normaliseCatalogueKey(section['hotspot_key']);

      if ((targetCode.isNotEmpty && code == targetCode) ||
          hotspot == targetRegion ||
          slug == targetRegion ||
          name == targetLabel) {
        return section['id']?.toString();
      }
    }

    return null;
  }

  List<Map<String, dynamic>> get _availableSpecifications {
    final sectionId = _selectedCatalogueSectionId;
    if (sectionId == null) {
      return const [];
    }

    final rows = _catalogueSpecifications
        .where((specification) {
          final sections = _catalogueSections.where(
            (section) => section['id'] == specification['section_id'],
          );
          if (sections.isEmpty) {
            return false;
          }
          final section = sections.first;
          final animals = _catalogueAnimals.where(
            (animal) => animal['id'] == section['animal_id'],
          );
          if (animals.isEmpty || animals.first['code'] != _selectedAnimalCode) {
            return false;
          }
          return _matchesSelectedCut({
            'meat_section_id': section['id'],
            'meat_sections': section,
            'meat_specifications': specification,
            'product_name': specification['name'],
          });
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    rows.sort((a, b) {
      final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
      final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
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
      if (_selectedSectionId != null && !_matchesSelectedCut(product)) {
        continue;
      }

      if (_selectedSpecificationId != null &&
          !_matchesSpecification(product, _selectedSpecificationId!)) {
        continue;
      }

      if (!_matchesVariants(product)) {
        continue;
      }
      final grade = _nestedMap(product['meat_grades']);
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

  Map<String, dynamic>? _sectionForRegion(String animalCode, String regionKey) {
    final catalogue = AnimalCatalogueRegistry.forCode(animalCode);
    if (catalogue == null) {
      return null;
    }
    final animalIds = _catalogueAnimals
        .where((animal) => animal['code'] == animalCode)
        .map((animal) => animal['id']?.toString())
        .whereType<String>()
        .toSet();
    final sections = _catalogueSections.where(
      (section) => animalIds.contains(section['animal_id']?.toString()),
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

  bool get _isChickenSelection => _selectedAnimalCode == CutLinkAnimals.chicken;

  String _prettyChickenValue(dynamic raw) {
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

  bool get _isGoatSelection => _selectedAnimalCode == CutLinkAnimals.goat;

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

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) {
      return;
    }

    final catalogue = AnimalCatalogueRegistry.forCode(animalCode);
    final defaultRegionKey = catalogue?.defaultRegionKey;

    setState(() {
      _selectedAnimalCode = animalCode;
      _selectedAnimalRegionKey = defaultRegionKey;
      _selectedSectionId = null;
      _selectedSpecificationId = null;
      _resetVariants();
      _selectedGradeId = null;
      _selectedCommercialSpecificationKey = null;
      _chickenAttributeFilters.clear();
      _goatAttributeFilters.clear();
    });

    if (defaultRegionKey != null) {
      final section = _sectionForRegion(animalCode, defaultRegionKey);
      if (section != null && mounted) {
        setState(() {
          _selectedSectionId = section['id']?.toString();
        });
      }
    }

    _applySearch();
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
      _resetVariants();
      _selectedGradeId = null;
      _selectedCommercialSpecificationKey = null;
      _chickenAttributeFilters.clear();
      _goatAttributeFilters.clear();
    });

    _applySearch();
  }

  String? _regionForSection(Map<String, dynamic> section) {
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    if (catalogue == null) {
      return null;
    }

    final sectionCode = _normaliseCatalogueKey(section['code']);
    final sectionName = _normaliseCatalogueKey(section['name']);
    final sectionSlug = _normaliseCatalogueKey(section['slug']);
    final sectionHotspot = _normaliseCatalogueKey(section['hotspot_key']);

    for (final regionKey in catalogue.regionKeys) {
      final regionCode = _normaliseCatalogueKey(
        catalogue.sectionCodeForRegion(regionKey),
      );
      final regionName = _normaliseCatalogueKey(
        catalogue.regionLabel(regionKey),
      );
      final region = _normaliseCatalogueKey(regionKey);

      if ((sectionCode.isNotEmpty && regionCode == sectionCode) ||
          sectionHotspot == region ||
          sectionSlug == region ||
          sectionName == regionName) {
        return regionKey;
      }
    }

    return null;
  }

  void _selectSection(Map<String, dynamic> section) {
    final regionKey = _regionForSection(section);

    setState(() {
      _selectedAnimalRegionKey = regionKey;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
      _resetVariants();
      _selectedGradeId = null;
      _selectedCommercialSpecificationKey = null;
      _chickenAttributeFilters.clear();
      _goatAttributeFilters.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_subcategoryScrollController.hasClients) {
        _subcategoryScrollController.jumpTo(0);
      }
    });

    _applySearch();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _applySearch();
      }
    });
  }

  void _applySearch({bool loadStock = true}) {
    if (!mounted) {
      return;
    }
    if (loadStock) {
      unawaited(_loadStock());
    } else {
      setState(() => _filteredProducts = _products);
    }
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

  String _pieceWeightText(Map<String, dynamic> product) =>
      productSizeLabel(product);

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

  String _commercialSpecificationLabel(Map<String, dynamic> product) {
    if (_animalCode(product) == CutLinkAnimals.chicken) {
      final chickenValues = <String>[
        _prettyChickenValue(product['chicken_production_type']),
        _prettyChickenValue(product['chicken_skin']),
        _prettyChickenValue(product['chicken_bone']),
        _prettyChickenValue(product['chicken_preparation']),
        _prettyChickenValue(product['temperature_state']),
        _prettyChickenValue(product['halal_status']),
        productSizeLabel(product),
        _prettyChickenValue(product['chicken_carton_size']),
        _prettyChickenValue(product['packaging_type']),
        product['brand']?.toString().trim() ?? '',
      ].where((value) => value.isNotEmpty).toList();

      final pieces = product['pieces_per_carton']?.toString().trim() ?? '';
      if (pieces.isNotEmpty) {
        chickenValues.add('$pieces pcs/carton');
      }

      return chickenValues.isEmpty
          ? 'Standard specification'
          : chickenValues.join(' • ');
    }

    final values = <String>[
      _prettyChickenValue(product['bone_state']),
      _prettyChickenValue(product['temperature_state']),
      _prettyChickenValue(product['halal_status']),
      _prettyChickenValue(product['packaging_type']),
      product['brand']?.toString().trim() ?? '',
      _prettyChickenValue(product['supplier_specification']),
    ].where((value) => value.isNotEmpty).toList();

    final size = productSizeLabel(product);
    if (size.isNotEmpty) {
      values.add(size);
    }

    final carton = product['carton_weight']?.toString().trim() ?? '';
    if (carton.isNotEmpty) {
      final unit =
          product['carton_weight_unit']?.toString().trim().isNotEmpty == true
          ? product['carton_weight_unit'].toString().trim()
          : 'kg';
      values.add('$carton $unit carton');
    }

    final pieces = product['pieces_per_carton']?.toString().trim() ?? '';
    if (pieces.isNotEmpty) {
      values.add('$pieces pcs/carton');
    }

    return values.isEmpty ? 'Standard specification' : values.join(' • ');
  }

  String _commercialSpecificationKey(Map<String, dynamic> product) {
    return _commercialSpecificationLabel(product).trim().toLowerCase();
  }

  List<Map<String, String>> get _availableCommercialSpecifications {
    if (_selectedSpecificationId == null) {
      return const [];
    }

    final byKey = <String, String>{};

    for (final product in _variantScope) {
      if ((_selectedSectionId != null || _selectedAnimalRegionKey != null) &&
          !_matchesSelectedCut(product)) {
        continue;
      }
      if (!_matchesSpecification(product, _selectedSpecificationId!)) {
        continue;
      }

      if (!_matchesVariants(product)) {
        continue;
      }
      final key = _commercialSpecificationKey(product);
      if (key.isEmpty) {
        continue;
      }
      byKey[key] = _commercialSpecificationLabel(product);
    }

    final rows =
        [
          for (final entry in byKey.entries)
            {'key': entry.key, 'label': entry.value},
        ]..sort(
          (a, b) => (a['label'] ?? '').toLowerCase().compareTo(
            (b['label'] ?? '').toLowerCase(),
          ),
        );

    return rows;
  }

  bool _matchesCommercialSpecification(Map<String, dynamic> product) {
    if (_usesGradeStage || _selectedCommercialSpecificationKey == null) {
      return true;
    }
    return _commercialSpecificationKey(product) ==
        _selectedCommercialSpecificationKey;
  }

  Widget _buildCommercialSpecificationStrip() {
    final specifications = _availableCommercialSpecifications;
    if (specifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return _arrowScrollStrip(
      controller: _finalSpecificationScrollController,
      height: 38,
      children: [
        _thinChoice(
          label: 'All specifications',
          selected: _selectedCommercialSpecificationKey == null,
          onTap: () {
            setState(() {
              _selectedCommercialSpecificationKey = null;
            });
            _applySearch();
          },
        ),
        for (final specification in specifications)
          _thinChoice(
            label: specification['label'] ?? 'Specification',
            selected:
                _selectedCommercialSpecificationKey == specification['key'],
            onTap: () {
              setState(() {
                _selectedCommercialSpecificationKey = specification['key'];
              });
              _applySearch();
            },
          ),
      ],
    );
  }

  Widget _thinChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF741C1C) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF741C1C)
                    : const Color(0xFFD9D9D5),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF444444),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
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
            child: Icon(icon, size: 19, color: const Color(0xFF741C1C)),
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
              _resetVariants();
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
              _resetVariants();
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
            onTap: () => _chooseCatalogueSubcut(specification),
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
        automaticallyImplyLeading: widget.onBack == null,
        leading: widget.onBack == null
            ? null
            : IconButton(
                onPressed: widget.onBack,
                tooltip: 'Back to dashboard',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
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
          ScaleTransition(
            scale: _cartBounceScale,
            child: FilledButton(
              onPressed: _openCart,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 19),
                      if (_cartItemCount > 0)
                        Positioned(
                          right: -9,
                          top: -9,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF741C1C),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _cartItemCount > 99 ? '99+' : '$_cartItemCount',
                              style: const TextStyle(
                                color: Color(0xFF741C1C),
                                fontSize: 9.5,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Cart',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
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

    final pieceSize = productSizeLabel(product);
    if (pieceSize.isNotEmpty) {
      parts.add(pieceSize);
    }
    final brand = product['brand']?.toString().trim() ?? '';
    if (brand.isNotEmpty) {
      parts.add(brand);
    }

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

  Widget _supplierIdentity(Map<String, dynamic> product) {
    final business = _nestedMap(product['businesses']);
    final path = business?['logo_path']?.toString().trim() ?? '';
    final name = _supplierName(product);
    final fallback = Center(
      child: Text(
        name.isEmpty ? 'S' : name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF741C1C),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE3E5E8)),
          ),
          child: path.isEmpty
              ? fallback
              : Image.network(
                  Supabase.instance.client.storage
                      .from('business-branding')
                      .getPublicUrl(path),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  semanticLabel: '$name logo',
                  errorBuilder: (_, error, stackTrace) => fallback,
                ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF741C1C),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
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
              CatalogueProductImage(product: product, thumbnail: true),
              const SizedBox(width: 9),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _supplierIdentity(product),
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
                    if (product['halal_status'] == 'halal') ...[
                      const SizedBox(height: 4),
                      const Text(
                        'HALAL • Supplier declared',
                        style: TextStyle(
                          color: Color(0xFF246342),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (commercialSummary.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        commercialSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF3F444A),
                          fontSize: 13,
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

  void _chooseCatalogueSubcut(Map<String, dynamic> specification) {
    setState(() {
      _selectedSpecificationId = specification['id']?.toString();
      _resetVariants();
      _selectedGradeId = null;
      _selectedCommercialSpecificationKey = null;
      _chickenAttributeFilters.clear();
      _goatAttributeFilters.clear();
      _stockViewActive = true;
      _stockScope = null;
    });
    _applySearch();
  }

  Future<void> _openAnimalCatalogue() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          final specifications = _availableSpecifications;
          Widget diagram() => InteractiveAnimalBrowser(
            selectedAnimalCode: _selectedAnimalCode,
            selectedRegionKey: _selectedAnimalRegionKey,
            maxWidth: 900,
            onAnimalChanged: (code) {
              _selectAnimal(code);
              update(() {});
            },
            onRegionSelected: (region) {
              _selectAnimalRegion(region);
              update(() {});
            },
          );
          Widget choices() => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. Choose a cut',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final section in _selectedAnimalSections)
                    ChoiceChip(
                      label: Text(section['name']?.toString() ?? 'Cut'),
                      selected: _selectedSectionId == section['id']?.toString(),
                      onSelected: (_) {
                        _selectSection(section);
                        update(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '2. Choose a sub-cut',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a sub-cut to view supplier offers. Refine grade, size and brand on the results page.',
                style: TextStyle(fontSize: 12, color: Color(0xFF666A70)),
              ),
              const SizedBox(height: 10),
              if (specifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Select a cut on the diagram or above to see its sub-cuts.',
                  ),
                ),
              for (final specification in specifications)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () {
                      _chooseCatalogueSubcut(specification);
                      Navigator.pop(dialogContext);
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            specification['name']?.toString() ?? 'Sub-cut',
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
            ],
          );
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 1240,
              height: MediaQuery.sizeOf(dialogContext).height * 0.88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Browse animal catalogue',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close catalogue',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        if (box.maxWidth < 850) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              diagram(),
                              const SizedBox(height: 20),
                              choices(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 7,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: diagram(),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 4,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(18),
                                child: choices(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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

    final cutSelected =
        _selectedSectionId != null || _selectedAnimalRegionKey != null;
    final subcategorySelected = _selectedSpecificationId != null;
    final finalSpecificationSelected = _usesGradeStage
        ? _selectedGradeId != null ||
              (!_loadingStock && _availableGrades.length == 1)
        : _selectedCommercialSpecificationKey != null ||
              (!_loadingStock &&
                  _availableCommercialSpecifications.length == 1);
    final sizeSelected = _selectedPieceSize != null || _pieceSizes.length <= 1;
    final exactSelection =
        _stockViewActive ||
        (subcategorySelected && sizeSelected && finalSpecificationSelected);

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
            hintText: exactSelection
                ? 'Search matching products...'
                : !cutSelected
                ? 'Search all products — e.g. Scotch Fillet, Brisket...'
                : !subcategorySelected
                ? 'Search subcategories within ${_selectedSectionName ?? 'this cut'}...'
                : !finalSpecificationSelected
                ? (_usesGradeStage
                      ? 'Search grades for this subcategory...'
                      : 'Search specifications for this sub-cut...')
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

                final supplierField = SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Filter supplier'),
                        content: SizedBox(
                          width: 400,
                          height: 56,
                          child: TextField(
                            controller: _supplierSearchController,
                            autofocus: true,
                            maxLines: 1,
                            decoration: const InputDecoration(
                              hintText: 'Supplier name',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) =>
                                Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => _supplierSearchController.clear(),
                            child: const Text('Clear'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text(
                      _supplierSearchController.text.isEmpty
                          ? 'Filter supplier'
                          : _supplierSearchController.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );

                final sortField = CutLinkPickerField<String>(
                  label: 'Sort results',
                  value: _sortMode,
                  dense: true,
                  enableSearch: false,
                  options: const [
                    CutLinkPickerOption(
                      value: 'recommended',
                      label: 'Recommended',
                      icon: Icons.auto_awesome_outlined,
                    ),
                    CutLinkPickerOption(
                      value: 'price_low',
                      label: 'Price: low to high',
                      icon: Icons.arrow_downward,
                    ),
                    CutLinkPickerOption(
                      value: 'price_high',
                      label: 'Price: high to low',
                      icon: Icons.arrow_upward,
                    ),
                    CutLinkPickerOption(
                      value: 'supplier',
                      label: 'Supplier: A–Z',
                      icon: Icons.storefront_outlined,
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _sortMode = value);
                    _applySearch();
                  },
                );

                final fieldWidth = narrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: fieldWidth, child: supplierField),
                    SizedBox(width: fieldWidth, child: sortField),
                  ],
                );
              },
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                availableToggle(),
                TextButton(
                  onPressed: () {
                    _supplierSearchController.clear();
                    setState(() {
                      final wasViewingStock = _stockViewActive;
                      _resetVariants();
                      _stockViewActive = wasViewingStock;
                      _selectedCommercialSpecificationKey = null;
                      _selectedPieceSize = '';
                      _sortMode = 'recommended';
                      _availableOnly = false;
                      _halalOnly = false;
                      _chickenAttributeFilters.clear();
                      _goatAttributeFilters.clear();
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
        if (query.isEmpty) {
          return true;
        }
        return matchesCatalogueSearch(query, [
          specification['name'],
          ...(specification['alternate_names'] as List? ?? const []),
        ]);
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
            subtitle: _usesGradeStage
                ? 'Choose this subcategory to view its $_gradeStageLabel.'
                : 'Choose this subcategory to view matching supplier offers.',
            onTap: () {
              setState(() {
                _selectedSpecificationId = specification['id']?.toString();
                _resetVariants();
                _selectedGradeId = null;
                _selectedCommercialSpecificationKey = null;
              });
              _applySearch();
            },
          );
        },
      );
    }

    Widget sizeStage() {
      if (_loadingStock) {
        return const Center(child: CircularProgressIndicator());
      }
      final sizes = _pieceSizes;
      return ListView(
        padding: const EdgeInsets.all(10),
        children: [
          rightChoiceCard(
            icon: Icons.straighten,
            title: 'Any size',
            subtitle: 'Compare all piece sizes for this sub-cut.',
            onTap: () {
              setState(() => _selectedPieceSize = '');
              _applySearch();
            },
          ),
          for (final size in sizes.where((v) => v.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: rightChoiceCard(
                icon: Icons.straighten,
                title: size,
                subtitle: 'Size of each piece inside the carton.',
                onTap: () {
                  setState(() {
                    _selectedPieceSize = size;
                    _selectedGradeId = null;
                    _selectedCommercialSpecificationKey = null;
                  });
                  _applySearch();
                },
              ),
            ),
        ],
      );
    }

    Widget gradeStage() {
      final query = _searchController.text.trim().toLowerCase();
      final grades = _availableGrades.where((grade) {
        if (query.isEmpty) {
          return true;
        }
        final code = grade['code']?.toString() ?? '';
        final name = grade['name']?.toString() ?? '';
        return matchesCatalogueSearch(query, [code, name]);
      }).toList();

      if (grades.isEmpty && _loadingStock) {
        return const Center(child: CircularProgressIndicator());
      }
      if (grades.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Text(
              query.isEmpty
                  ? 'No stocked products are available for this subcategory yet.'
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
              _applySearch();
            },
          );
        },
      );
    }

    Widget commercialSpecificationStage() {
      final query = _searchController.text.trim().toLowerCase();
      final specifications = _availableCommercialSpecifications
          .where((row) => (row['label'] ?? '').toLowerCase().contains(query))
          .toList();

      if (specifications.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(26),
            child: Text(
              'No product specifications are available for this sub-cut.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
          return rightChoiceCard(
            icon: Icons.tune_outlined,
            title: specification['label'] ?? 'Product specification',
            subtitle:
                'Choose this specification to compare matching suppliers and pricing.',
            onTap: () {
              setState(() {
                _selectedCommercialSpecificationKey = specification['key'];
              });
              _applySearch();
            },
          );
        },
      );
    }

    Widget supplierStockStage() {
      if (_loadingStock) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_filteredProducts.isEmpty && _stockPageOffset > 0) {
        return Center(
          child: TextButton(
            onPressed: () => _loadStock(force: true),
            child: const Text('Return to first page'),
          ),
        );
      }
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
                  'No active supplier product matches these cut and specification choices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF777777), height: 1.35),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          Expanded(
            child: ListView.separated(
              key: ValueKey('$_stockScope:$_stockPageOffset'),
              padding: const EdgeInsets.all(10),
              itemCount: _filteredProducts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (_, index) =>
                  _buildMarketplaceProductCard(_filteredProducts[index]),
            ),
          ),
          if (_stockTotal > _stockPageSize || _stockPageOffset > 0)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _stockPageOffset == 0
                        ? null
                        : () => _loadStock(
                            offset: _stockPageOffset - _stockPageSize,
                          ),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  Text(
                    '${_stockPageOffset + 1}–${_stockPageOffset + _filteredProducts.length} of $_stockTotal',
                  ),
                  TextButton.icon(
                    onPressed:
                        _stockPageOffset + _filteredProducts.length >=
                            _stockTotal
                        ? null
                        : () => _loadStock(
                            offset: _stockPageOffset + _stockPageSize,
                          ),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    Widget resultsPanel() {
      final directSearch =
          _searchController.text.trim().isNotEmpty || _halalOnly;
      final globalSearch = directSearch && !cutSelected;

      final showingStock = directSearch || exactSelection;
      final title = showingStock
          ? (globalSearch
                ? (_halalOnly ? 'Halal Products' : 'Search Results')
                : 'Supplier Stock')
          : globalSearch
          ? (_halalOnly ? 'Halal Products' : 'Search Results')
          : !cutSelected
          ? 'Choose a Cut'
          : !subcategorySelected
          ? 'Subcategories'
          : !sizeSelected
          ? 'Choose Piece Size'
          : !finalSpecificationSelected
          ? (_usesGradeStage ? 'Choose Grade' : 'Choose Specification')
          : 'Supplier Stock';

      final subtitle = showingStock
          ? 'Compare matching supplier offers and pricing.'
          : globalSearch
          ? (_halalOnly
                ? 'Products marked Halal by their supplier.'
                : 'Matching products from all suppliers.')
          : !cutSelected
          ? 'Open the animal catalogue or choose a cut above.'
          : !subcategorySelected
          ? 'Choose the exact subcategory for this cut.'
          : !sizeSelected
          ? 'Select the weight of each cut inside the carton.'
          : !finalSpecificationSelected
          ? (_usesGradeStage
                ? 'Choose the commercial grade/category.'
                : 'Choose the product specification for this sub-cut.')
          : 'Compare matching supplier offers and pricing.';

      Widget filters() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('All products'),
                  selected: !_halalOnly,
                  onSelected: (_) {
                    setState(() => _halalOnly = false);
                    _applySearch();
                  },
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Halal only'),
                  selected: _halalOnly,
                  onSelected: (selected) {
                    setState(() => _halalOnly = selected);
                    _applySearch();
                  },
                ),
              ],
            ),
          ),
          if (subcategorySelected || globalSearch) _variantFilters(),
          if (showingStock) resultsToolbar(),
        ],
      );
      Widget content() => showingStock
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
          : !sizeSelected
          ? sizeStage()
          : !finalSpecificationSelected
          ? (_usesGradeStage ? gradeStage() : commercialSpecificationStage())
          : supplierStockStage();
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E5E8)),
        ),
        child: LayoutBuilder(
          builder: (context, panel) {
            final sideFilters = panel.maxWidth >= 780;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
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
                                  '$_stockTotal result${_stockTotal == 1 ? '' : 's'}',
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
                      if (!sideFilters) ...[
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _filtersExpanded = !_filtersExpanded,
                          ),
                          icon: Icon(
                            _filtersExpanded ? Icons.expand_less : Icons.tune,
                          ),
                          label: Text(
                            _filtersExpanded
                                ? 'Hide filters & sorting'
                                : 'Filters & sorting',
                          ),
                        ),
                        if (_filtersExpanded)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: panel.maxHeight * 0.38,
                            ),
                            child: SingleChildScrollView(
                              child: SizedBox(
                                width: panel.maxWidth,
                                child: filters(),
                              ),
                            ),
                          ),
                      ],
                      _stockLoadingStatus(),
                      Expanded(child: content()),
                    ],
                  ),
                ),
                if (sideFilters) ...[
                  const VerticalDivider(width: 1, color: Color(0xFFE3E5E8)),
                  SizedBox(
                    width: 234,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 14, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 0, 12, 14),
                            child: Text(
                              'Filters & sorting',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          filters(),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1740),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3E5E8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _openAnimalCatalogue,
                          icon: const Icon(Icons.menu_book_outlined, size: 20),
                          label: const Text('Browse animal catalogue'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF741C1C),
                          ),
                        ),
                        for (final animal in const [
                          'BEEF',
                          'VEAL',
                          'LAMB',
                          'MUTTON',
                          'GOAT',
                          'CHICKEN',
                        ])
                          ChoiceChip(
                            label: Text(animal),
                            selected: _selectedAnimalCode == animal,
                            onSelected: (_) => _selectAnimal(animal),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSectionStrip(),
                    if (cutSelected) ...[
                      const SizedBox(height: 4),
                      _buildSpecificationStrip(),
                    ],
                    if (subcategorySelected) ...[
                      const SizedBox(height: 4),
                      _usesGradeStage
                          ? _buildGradeStrip()
                          : _buildCommercialSpecificationStrip(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: resultsPanel()),
            ],
          ),
        ),
      ),
    );
  }
}
