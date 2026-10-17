import '../../../shared/widgets/supplier_photo_terms_notice.dart';
import '../../support/presentation/missing_item_request_button.dart';
import 'vip_customer_prices_dialog.dart';
import '../../../shared/widgets/phone_stock_scaffold.dart';
import '../../../shared/widgets/phone_layout.dart';
import 'dart:async';
import 'dart:convert';

import '../../../shared/widgets/supplier_stock_filters.dart';
import '../../../shared/animal_catalogues/product_variant.dart';
import '../../../shared/animal_catalogues/lamb_product_details.dart';
import '../../products/presentation/edit_product_page.dart';
import '../../products/presentation/add_product_page.dart';
import '../../../shared/widgets/catalogue_product_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/animal_catalogues/animal_catalogue_registry.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';

class _PendingPriceChange {
  _PendingPriceChange({
    required this.product,
    required this.visibility,
    required this.amountText,
    required this.priceBasis,
    required this.minimumQuantity,
    required this.minimumQuantityUnit,
    this.priceListId,
    this.customer,
    this.minimumText,
  });

  final Map<String, dynamic> product;
  final String visibility;
  final String amountText;
  final String priceBasis;
  final double? minimumQuantity;
  final dynamic minimumQuantityUnit;
  String? priceListId;
  final Map<String, dynamic>? customer;
  final String? minimumText;
}

class QuickPriceManagementPage extends StatefulWidget {
  const QuickPriceManagementPage({super.key});

  @override
  State<QuickPriceManagementPage> createState() =>
      _QuickPriceManagementPageState();
}

class _QuickPriceManagementPageState extends State<QuickPriceManagementPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();

  final _skuController = TextEditingController();
  final _cutScroll = ScrollController();
  final _specScroll = ScrollController();
  final Map<String, TextEditingController> _stockControllers = {};
  final Set<String> _savingStock = {};
  final Map<String, String> _stockStatuses = {};
  final Map<String, String> _stockBaselines = {};
  final Map<String, String> _statusBaselines = {};
  final Set<String> _resetStock = {};

  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSectionId;
  String? _selectedSpecificationId;

  bool _isLoading = true;
  String? _errorMessage;
  String? _supplierBusinessId;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _priceLists = [];
  List<Map<String, dynamic>> _approvedCustomers = [];
  List<Map<String, dynamic>> _productPrices = [];
  final Map<String, TextEditingController> _inlinePriceControllers = {};
  final Map<String, _PendingPriceChange> _pendingChanges = {};
  bool _isSavingChanges = false;
  List<Map<String, dynamic>> _stockOptions = [];
  final _stockFilters = SupplierStockFilters()..status = 'active';
  Timer? _stockDebounce;
  String? _scheduledScope;
  String? _loadedScope;
  bool _loadingStock = false;
  String? _stockError;
  int _stockOffset = 0;
  int _stockTotal = 0;
  int _stockVersion = 0;
  int _pageVersion = 0;
  Map<String, Map<String, String>> _filterChoices = {};
  String? _filterChoiceScope;
  int _filterChoiceVersion = 0;
  String? _filterChoiceError;
  bool _loadingFilterChoices = false;

  List<String> get _scopeSpecificationIds =>
      _scopedStockOptions
          .map((p) => p['meat_specification_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();

  Future<void> _loadFilterChoices(List<String> ids) async {
    final scope = '$_supplierBusinessId:${ids.join(',')}';
    if (_filterChoiceScope == scope) return;
    _filterChoiceScope = scope;
    final version = ++_filterChoiceVersion;
    setState(() {
      _filterChoices = {};
      _loadingFilterChoices = true;
      _filterChoiceError = null;
    });
    try {
      final raw = await Supabase.instance.client
          .rpc(
            'supplier_inventory_facets',
            params: {
              'p_supplier_business_id': _supplierBusinessId,
              'p_specification_ids': ids,
            },
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted || version != _filterChoiceVersion) return;
      setState(
        () => _filterChoices = {
          for (final entry in Map<String, dynamic>.from(raw as Map).entries)
            entry.key: Map<String, String>.from(entry.value as Map),
        },
      );
    } catch (_) {
      if (!mounted || version != _filterChoiceVersion) return;
      setState(() {
        _filterChoiceScope = null;
        _filterChoiceError = 'Filter options could not load.';
      });
    } finally {
      if (mounted && version == _filterChoiceVersion) {
        setState(() => _loadingFilterChoices = false);
      }
    }
  }

  String get _selectionSignature => jsonEncode([
    _selectedAnimalCode,
    _selectedAnimalRegionKey,
    _selectedSectionId,
    _selectedSpecificationId,
    _searchController.text.trim(),
    _skuController.text.trim(),
    _stockFilters.signature,
  ]);

  List<Map<String, dynamic>> get _scopedStockOptions => _selectedAnimalProducts
      .where(
        (p) =>
            _matchesSelectedCut(p) &&
            (_selectedSpecificationId == null ||
                p['meat_specification_id']?.toString() ==
                    _selectedSpecificationId),
      )
      .toList();

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
      unawaited(_loadStock());
    });
  }

  Future<void> _loadStock() async {
    if (_supplierBusinessId == null || !mounted) {
      return;
    }
    final version = ++_stockVersion;
    final scope = _selectionSignature;
    _scheduledScope = scope;
    _stockDebounce?.cancel();
    final specificationIds = _scopeSpecificationIds;
    unawaited(_loadFilterChoices(specificationIds));
    setState(() {
      _loadingStock = true;
      _stockError = null;
    });
    try {
      final response = await Supabase.instance.client
          .rpc(
            'supplier_inventory_page_v2',
            params: {
              'p_supplier_business_id': _supplierBusinessId,
              'p_filters': {
                'specifications': specificationIds,
                'values': _stockFilters.values,
              },
              'p_search': _searchController.text.trim(),
              'p_sku': _skuController.text.trim(),
              'p_status': _stockFilters.status,
              'p_sort': _stockFilters.sort,
              'p_offset': _stockOffset,
              'p_limit': 40,
            },
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted ||
          version != _stockVersion ||
          scope != _selectionSignature) {
        return;
      }
      final products = List<Map<String, dynamic>>.from(
        response['products'] as List,
      );
      setState(() {
        for (final product in products) {
          final id = product['id'].toString();
          final reset = _resetStock.remove(id);
          final quantity = product['available_quantity']?.toString() ?? '0';
          final status =
              product['availability_status']?.toString() ?? 'out_of_stock';
          final controller = _stockControllers[id];
          if (controller != null &&
              (reset || controller.text == _stockBaselines[id])) {
            controller.text = quantity;
          }
          if (reset || _stockStatuses[id] == _statusBaselines[id]) {
            _stockStatuses.remove(id);
          }
          _stockBaselines[id] = quantity;
          _statusBaselines[id] = status;
        }
        _products = products;
        _productPrices = [
          for (final p in products)
            ...List<Map<String, dynamic>>.from(
              p['product_prices'] as List? ?? [],
            ),
        ];
        for (final product in products) {
          for (final visibility in ['public', 'approved_customers']) {
            final key = _changeKey(product['id'].toString(), visibility);
            if (_pendingChanges.containsKey(key)) {
              continue;
            }
            final list = _firstPriceListForVisibility(visibility);
            final price = list == null
                ? null
                : _priceForProductAndList(
                    product['id'].toString(),
                    list['id'].toString(),
                  );
            final amount = price?['amount'];
            _inlinePriceControllers[key]?.text = amount == null
                ? ''
                : amount.toString();
          }
        }
        _stockTotal = (response['total'] as num).toInt();
        _loadedScope = scope;
      });
      if (_stockOffset > 0 && _stockOffset >= _stockTotal) {
        _stockOffset = 0;
        await _loadStock();
      }
    } catch (error) {
      if (mounted && version == _stockVersion) {
        setState(() {
          _stockError = 'Unable to load prices. Please retry. $error';
          _products = [];
        });
      }
    } finally {
      if (mounted && version == _stockVersion) {
        setState(() => _loadingStock = false);
      }
    }
  }

  Future<void> _addProduct() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddProductPage(
          initialAnimalCode: _selectedAnimalCode,
          initialSectionId: _selectedSectionId,
          initialSpecificationId: _selectedSpecificationId,
        ),
      ),
    );
    if (!mounted || changed != true) {
      return;
    }
    SupplierStockCatalogue.invalidate(_supplierBusinessId!);
    await _loadPage();
  }

  Future<void> _browseDiagram() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => phoneDialog(
          context,
          AlertDialog(
            title: const Text('Browse animal cuts'),
            content: SizedBox(
              width: 850,
              height: MediaQuery.sizeOf(dialogContext).height * 0.65,
              child: InteractiveAnimalBrowser(
                fitToHeight: true,
                selectedAnimalCode: _selectedAnimalCode,
                selectedRegionKey: _selectedAnimalRegionKey,
                onAnimalChanged: (code) {
                  _selectAnimal(code);
                  update(() {});
                },
                onRegionSelected: (region) {
                  _selectAnimalRegion(region);
                  update(() {});
                },
                maxWidth: 850,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Show products'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrowStrip(ScrollController controller, List<Widget> children) {
    void move(double direction) {
      if (!controller.hasClients) {
        return;
      }
      controller.animateTo(
        (controller.offset + direction * 260)
            .clamp(0.0, controller.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Scroll left',
            onPressed: () => move(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              children: children,
            ),
          ),
          IconButton(
            tooltip: 'Scroll right',
            onPressed: () => move(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _saveStock(Map<String, dynamic> product) async {
    final id = product['id'].toString();
    final quantity = double.tryParse(_stockControllers[id]?.text.trim() ?? '');
    if (quantity == null || !quantity.isFinite || quantity < 0) {
      _message('Enter a valid stock quantity.');
      return;
    }
    setState(() => _savingStock.add(id));
    try {
      await Supabase.instance.client.rpc(
        'update_supplier_product_stock',
        params: {
          'p_product_id': id,
          'p_quantity': quantity,
          'p_availability_status':
              _stockStatuses[id] ?? product['availability_status'],
          'p_reason': 'manual_adjustment',
          'p_notes': 'Supplier inventory workspace',
        },
      );
      if (!mounted) {
        return;
      }
      product['available_quantity'] = quantity;
      product['availability_status'] =
          _stockStatuses[id] ?? product['availability_status'];
      await _loadStock();
      _message('Stock updated.');
    } catch (error) {
      _message('Unable to update stock: $error');
    } finally {
      if (mounted) {
        setState(() => _savingStock.remove(id));
      }
    }
  }

  Widget _stockEditor(Map<String, dynamic> product) {
    final id = product['id'].toString();
    final controller = _stockControllers.putIfAbsent(
      id,
      () => TextEditingController(
        text: product['available_quantity']?.toString() ?? '0',
      ),
    );
    final status =
        _stockStatuses[id] ??
        product['availability_status']?.toString() ??
        'out_of_stock';
    final statuses = <String, String>{
      'in_stock': 'In stock',
      'limited': 'Limited',
      'out_of_stock': 'Out of stock',
      'made_to_order': 'Made to order',
    };
    if (!statuses.containsKey(status)) {
      statuses[status] = status;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 125,
            child: TextField(
              controller: controller,
              enabled: product['active'] == true && !_savingStock.contains(id),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Stock',
                suffixText: product['quantity_unit'] == 'kilogram'
                    ? 'kg'
                    : product['quantity_unit'] == 'unit'
                    ? 'units'
                    : 'ctn',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 156,
            child: DropdownButtonFormField<String>(
              key: ValueKey('$id:$status'),
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Availability',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in statuses.entries)
                  DropdownMenuItem(value: s.key, child: Text(s.value)),
              ],
              onChanged: product['active'] != true || _savingStock.contains(id)
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() => _stockStatuses[id] = v);
                      }
                    },
            ),
          ),
          IconButton(
            tooltip: 'Save stock',
            onPressed: product['active'] != true || _savingStock.contains(id)
                ? null
                : () => _saveStock(product),
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProductPage(product: product)),
    );
    if (!mounted) {
      return;
    }
    _resetStock.add(product['id'].toString());
    if (changed == true) {
      SupplierStockCatalogue.invalidate(_supplierBusinessId!);
    }
    // Pricing can be saved independently on the product page.
    await _loadPage();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _skuController.addListener(_refresh);
    _loadPage();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _cutScroll.dispose();
    _specScroll.dispose();
    for (final controller in _stockControllers.values) {
      controller.dispose();
    }
    _stockDebounce?.cancel();
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    for (final controller in _inlinePriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPage() async {
    final version = ++_pageVersion;
    ++_stockVersion;
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
      for (final row in businesses) {
        if (row['business_type']?.toString() == 'supplier') {
          supplierBusinessId = row['id']?.toString();
          break;
        }
      }

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception('No active supplier business membership was found.');
      }

      _filterChoiceScope = null;
      ++_filterChoiceVersion;
      final catalogueFuture = client.rpc(
        'supplier_inventory_catalogue',
        params: {'p_supplier_business_id': supplierBusinessId},
      );

      final priceListFuture = client
          .from('price_lists')
          .select('''
            id,
            supplier_business_id,
            name,
            visibility,
            active,
            price_list_customers(
              butcher_business_id
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('active', true)
          .order('name');

      final customerFuture = client
          .from('supplier_customer_relationships')
          .select('''
            butcher_business_id,
            businesses!supplier_customer_relationships_butcher_business_id_fkey(
              legal_name,
              trading_name,
              logo_path
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'approved')
          .order('created_at');

      final loaded = await Future.wait<dynamic>([
        catalogueFuture,
        priceListFuture,
        customerFuture,
      ]).timeout(const Duration(seconds: 25));
      final stockOptions = List<Map<String, dynamic>>.from(loaded[0] as List);
      final priceListResponse = loaded[1] as List;
      final customerResponse = loaded[2] as List;

      if (!mounted || version != _pageVersion) {
        return;
      }

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _stockOptions = stockOptions;
        _priceLists = List<Map<String, dynamic>>.from(priceListResponse);
        _approvedCustomers = List<Map<String, dynamic>>.from(customerResponse);

        if (_pendingChanges.isEmpty) {
          for (final controller in _inlinePriceControllers.values) {
            controller.dispose();
          }
          _inlinePriceControllers.clear();
        }
        _isLoading = false;
      });
      await _loadStock();
    } on PostgrestException catch (error) {
      if (!mounted || version != _pageVersion) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _pageVersion) {
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

  String _productAnimalCode(Map<String, dynamic> product) {
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
    final code = _nestedMap(product['meat_grades'])?['code']?.toString().trim();
    return code == null || code.isEmpty ? 'N/A' : code;
  }

  String _gradeName(Map<String, dynamic> product) {
    return _nestedMap(product['meat_grades'])?['name']?.toString().trim() ?? '';
  }

  List<Map<String, dynamic>> get _selectedAnimalProducts {
    return _stockOptions.where((product) {
      return _productAnimalCode(product) == _selectedAnimalCode;
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedAnimalSections {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      final section = _nestedMap(product['meat_sections']);
      final id = section?['id']?.toString();
      if (section == null || id == null || id.isEmpty) {
        continue;
      }
      byId[id] = section;
    }

    final result = byId.values.toList();
    result.sort((a, b) {
      final ao = int.tryParse(a['display_order']?.toString() ?? '') ?? 9999;
      final bo = int.tryParse(b['display_order']?.toString() ?? '') ?? 9999;
      if (ao != bo) {
        return ao.compareTo(bo);
      }
      return (a['name']?.toString() ?? '').compareTo(
        b['name']?.toString() ?? '',
      );
    });
    return result;
  }

  bool _matchesSelectedCut(Map<String, dynamic> product) {
    final regionKey = _selectedAnimalRegionKey;
    if (regionKey != null) {
      final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
      if (catalogue == null) {
        return false;
      }
      return catalogue.productMatchesRegion(product, regionKey);
    }

    final sectionId = _selectedSectionId;
    if (sectionId == null) {
      return true;
    }
    return product['meat_section_id']?.toString() == sectionId;
  }

  List<Map<String, dynamic>> get _availableSpecifications {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (!_matchesSelectedCut(product)) {
        continue;
      }

      final specification = _nestedMap(product['meat_specifications']);
      final id = specification?['id']?.toString();
      if (specification == null || id == null || id.isEmpty) {
        continue;
      }
      byId[id] = specification;
    }

    final result = byId.values.toList();
    result.sort(
      (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
        (b['name']?.toString() ?? '').toLowerCase(),
      ),
    );
    return result;
  }

  List<Map<String, dynamic>> get _filteredProducts => _products;

  Map<String, dynamic>? _sectionByCode(String code) {
    for (final section in _selectedAnimalSections) {
      if (section['code']?.toString() == code) {
        return section;
      }
    }
    return null;
  }

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) {
      return;
    }

    setState(() {
      _selectedAnimalCode = animalCode;
      _stockFilters.values.clear();
      _selectedAnimalRegionKey = null;
      _selectedSectionId = null;
      _selectedSpecificationId = null;
    });
  }

  void _selectAnimalRegion(String regionKey) {
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    if (catalogue == null) {
      return;
    }

    Map<String, dynamic>? section;
    final sectionCode = catalogue.sectionCodeForRegion(regionKey);
    if (sectionCode != null) {
      section = _sectionByCode(sectionCode);
    }

    if (section == null) {
      for (final product in _selectedAnimalProducts) {
        if (!catalogue.productMatchesRegion(product, regionKey)) {
          continue;
        }
        section = _nestedMap(product['meat_sections']);
        if (section != null) {
          break;
        }
      }
    }

    if (section == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This cut is not available in the catalogue yet.'),
        ),
      );
      return;
    }

    final sectionId = section['id']?.toString();
    setState(() {
      _selectedAnimalRegionKey = regionKey;
      _selectedSectionId = sectionId;
      _selectedSpecificationId = null;
    });
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
    });
  }

  bool _isCatchWeight(Map<String, dynamic> product) {
    return product['weight_type']?.toString() == 'catch_weight' ||
        product['catch_weight'] == true;
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

  List<Map<String, dynamic>> _priceListsForVisibility(String visibility) {
    return _priceLists.where((priceList) {
      return priceList['visibility']?.toString() == visibility &&
          priceList['active'] == true;
    }).toList();
  }

  Map<String, dynamic>? _priceForProductAndList(
    String productId,
    String priceListId,
  ) {
    for (final price in _productPrices) {
      if (price['product_id']?.toString() == productId &&
          price['price_list_id']?.toString() == priceListId &&
          price['active'] == true) {
        return price;
      }
    }
    return null;
  }

  List<String> _customerIdsForPriceList(Map<String, dynamic> priceList) {
    final raw = priceList['price_list_customers'];
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => item['butcher_business_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _privatePriceListForCustomer(
    String customerBusinessId,
  ) {
    for (final priceList in _priceListsForVisibility('private')) {
      if (_customerIdsForPriceList(priceList).contains(customerBusinessId)) {
        return priceList;
      }
    }
    return null;
  }

  String _customerName(Map<String, dynamic> customer) {
    final rawBusiness = customer['businesses'];
    if (rawBusiness is Map) {
      final business = Map<String, dynamic>.from(rawBusiness);
      final trading = business['trading_name']?.toString().trim();
      final legal = business['legal_name']?.toString().trim();

      if (trading != null && trading.isNotEmpty) {
        return trading;
      }
      if (legal != null && legal.isNotEmpty) {
        return legal;
      }
    }

    return 'Customer';
  }

  String _basisLabel(String? value) => switch (value) {
    'kilogram' => 'kg',
    'carton' => 'carton',
    'unit' => 'unit',
    _ => 'kg',
  };

  String _changeKey(String productId, String visibility, [String? listId]) =>
      '$productId|$visibility|${listId ?? ''}';

  TextEditingController _inlineController({
    required Map<String, dynamic> product,
    required String visibility,
    required Map<String, dynamic>? price,
  }) {
    final key = _changeKey(product['id'].toString(), visibility);
    return _inlinePriceControllers.putIfAbsent(
      key,
      () => TextEditingController(text: price?['amount']?.toString() ?? ''),
    );
  }

  void _queueInlinePrice({
    required Map<String, dynamic> product,
    required String visibility,
    required Map<String, dynamic>? priceList,
    required Map<String, dynamic>? existingPrice,
    required String amountText,
  }) {
    final productId = product['id'].toString();
    final key = _changeKey(productId, visibility);
    final catchWeight = _isCatchWeight(product);

    setState(() {
      _pendingChanges[key] = _PendingPriceChange(
        product: product,
        visibility: visibility,
        priceListId: priceList?['id']?.toString(),
        amountText: amountText.trim(),
        priceBasis: catchWeight
            ? 'kilogram'
            : existingPrice?['price_basis']?.toString() ??
                  product['price_basis']?.toString() ??
                  'unit',
        minimumQuantity: existingPrice?['minimum_quantity'] is num
            ? (existingPrice!['minimum_quantity'] as num).toDouble()
            : double.tryParse(
                existingPrice?['minimum_quantity']?.toString() ?? '',
              ),
        minimumQuantityUnit: catchWeight
            ? 'carton'
            : existingPrice?['minimum_quantity_unit'] ?? product['order_unit'],
      );
    });
  }

  void _queueVipPrice({
    required Map<String, dynamic> product,
    required Map<String, dynamic> customer,
    required Map<String, dynamic>? priceList,
    required Map<String, dynamic>? existingPrice,
    required VipCustomerPriceDraft? draft,
  }) {
    final id = customer['butcher_business_id'].toString();
    final key = _changeKey(product['id'].toString(), 'private', id);
    setState(() {
      if (draft == null) {
        _pendingChanges.remove(key);
        return;
      }
      _pendingChanges[key] = _PendingPriceChange(
        product: product,
        customer: customer,
        minimumText: draft.minimumText,
        visibility: 'private',
        priceListId: priceList?['id']?.toString(),
        amountText: draft.amountText.trim(),
        priceBasis: _isCatchWeight(product) ? 'kilogram' : draft.priceBasis,
        minimumQuantity: double.tryParse(draft.minimumText.trim()),
        minimumQuantityUnit: _isCatchWeight(product)
            ? 'carton'
            : existingPrice?['minimum_quantity_unit'] ?? product['order_unit'],
      );
    });
  }

  Future<bool> _saveAllChanges() async {
    if (_pendingChanges.isEmpty) {
      return true;
    }
    if (_isSavingChanges) {
      return false;
    }
    final changes = Map<String, _PendingPriceChange>.of(_pendingChanges);
    for (final change in changes.values) {
      final amount = double.tryParse(change.amountText);
      if (amount == null || !amount.isFinite || amount < 0) {
        _message('Enter a valid price for ${change.product['product_name']}.');
        return false;
      }
      if (change.minimumText != null &&
          change.minimumText!.trim().isNotEmpty &&
          double.tryParse(change.minimumText!.trim()) == null) {
        _message(
          'Check the minimum order for ${change.product['product_name']}.',
        );
        return false;
      }
      final minimum = change.minimumQuantity;
      if (minimum != null &&
          (!minimum.isFinite ||
              minimum <= 0 ||
              (_isCatchWeight(change.product) &&
                  minimum != minimum.roundToDouble()))) {
        _message(
          'Check the minimum order for ${change.product['product_name']}.',
        );
        return false;
      }
    }
    setState(() => _isSavingChanges = true);
    try {
      // List creation, customer assignment and every price update share one
      // database transaction. An invalid or unauthorised row rolls it all back.
      await Supabase.instance.client
          .rpc(
            'save_supplier_price_changes',
            params: {
              'p_supplier_business_id': _supplierBusinessId,
              'p_changes': [
                for (final change in changes.values)
                  {
                    'product_id': change.product['id'].toString(),
                    'price_list_id': change.priceListId,
                    'visibility': change.visibility,
                    'butcher_business_id':
                        change.customer?['butcher_business_id'],
                    'amount': double.parse(change.amountText),
                    'price_basis': change.priceBasis,
                    'minimum_quantity': change.minimumQuantity,
                    'minimum_quantity_unit': change.minimumQuantityUnit,
                  },
              ],
            },
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) {
        return true;
      }
      setState(() {
        for (final entry in changes.entries) {
          if (identical(_pendingChanges[entry.key], entry.value)) {
            _pendingChanges.remove(entry.key);
          }
        }
        _isSavingChanges = false;
      });
      await _loadPage();
      _message(
        '${changes.length} price change${changes.length == 1 ? '' : 's'} saved.',
      );
      return true;
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _isSavingChanges = false);
        _message(error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingChanges = false);
        _message(
          'Prices could not be saved. Your changes are kept; try again.',
        );
      }
    }
    return false;
  }

  Future<void> _manageCustomerPrices(Map<String, dynamic> product) async {
    if (_approvedCustomers.isEmpty) {
      _message('There are no approved butcher customers yet.');
      return;
    }
    final customers = <String, Map<String, dynamic>>{
      for (final customer in _approvedCustomers)
        if (customer['butcher_business_id'] != null)
          customer['butcher_business_id'].toString(): customer,
    };
    final entries = <VipCustomerPriceEntry>[];
    final lists = <String, Map<String, dynamic>?>{};
    final prices = <String, Map<String, dynamic>?>{};
    for (final entry in customers.entries) {
      final id = entry.key;
      final list = _privatePriceListForCustomer(id);
      final price = list == null
          ? null
          : _priceForProductAndList(
              product['id'].toString(),
              list['id'].toString(),
            );
      lists[id] = list;
      prices[id] = price;
      final pending =
          _pendingChanges[_changeKey(product['id'].toString(), 'private', id)];
      final catchWeight = _isCatchWeight(product);
      final rawBasis = catchWeight
          ? 'kilogram'
          : price?['price_basis']?.toString() ??
                product['price_basis']?.toString() ??
                'unit';
      final basis = ['kilogram', 'carton', 'unit'].contains(rawBasis)
          ? rawBasis
          : 'unit';
      final saved = VipCustomerPriceDraft(
        amountText: price?['amount']?.toString() ?? '',
        priceBasis: basis,
        minimumText: price?['minimum_quantity']?.toString() ?? '',
      );
      final logo = _nestedMap(
        entry.value['businesses'],
      )?['logo_path']?.toString().trim();
      entries.add(
        VipCustomerPriceEntry(
          customerId: id,
          name: _customerName(entry.value),
          saved: saved,
          initial: pending == null
              ? saved
              : VipCustomerPriceDraft(
                  amountText: pending.amountText,
                  priceBasis: pending.priceBasis,
                  minimumText:
                      pending.minimumText ??
                      pending.minimumQuantity?.toString() ??
                      '',
                ),
          logoUrl: logo == null || logo.isEmpty
              ? null
              : logo.startsWith('https://')
              ? logo
              : Supabase.instance.client.storage
                    .from('business-branding')
                    .getPublicUrl(logo),
        ),
      );
    }
    final standardList = _firstPriceListForVisibility('public');
    final standard = standardList == null
        ? null
        : _priceForProductAndList(
            product['id'].toString(),
            standardList['id'].toString(),
          );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VipCustomerPricesDialog(
        standardPrice: standard == null
            ? null
            : {...standard, 'price_lists': standardList},
        productName: product['product_name']?.toString() ?? 'Product',
        customers: entries,
        catchWeight: _isCatchWeight(product),
        pendingCount: () => _pendingChanges.length,
        onSaveAll: _saveAllChanges,
        onDraftChanged: (id, draft) => _queueVipPrice(
          product: product,
          customer: customers[id]!,
          priceList: lists[id],
          existingPrice: prices[id],
          draft: draft,
        ),
      ),
    );
  }

  int _specialPriceCountForProduct(String productId) {
    final customerIds = <String>{};
    for (final customer in _approvedCustomers) {
      final id = customer['butcher_business_id']?.toString();
      if (id == null) {
        continue;
      }
      final list = _privatePriceListForCustomer(id);
      if (list != null &&
          _priceForProductAndList(productId, list['id'].toString()) != null) {
        customerIds.add(id);
      }
    }
    for (final change in _pendingChanges.values) {
      final id = change.customer?['butcher_business_id']?.toString();
      if (id != null && change.product['id']?.toString() == productId) {
        customerIds.add(id);
      }
    }
    return customerIds.length;
  }

  Widget _buildSectionStrip() {
    final sections = _selectedAnimalSections;
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return _arrowStrip(_cutScroll, [
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          selected: _selectedSectionId == null,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: const Text('All cuts'),
          selectedColor: _darkRed,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: _selectedSectionId == null
                ? Colors.white
                : const Color(0xFF444444),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          onSelected: (_) {
            setState(() {
              _selectedAnimalRegionKey = null;
              _selectedSectionId = null;
              _selectedSpecificationId = null;
            });
          },
        ),
      ),
      for (final section in sections)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            selected: _selectedSectionId == section['id']?.toString(),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(section['name']?.toString() ?? 'Cut'),
            selectedColor: _darkRed,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: _selectedSectionId == section['id']?.toString()
                  ? Colors.white
                  : const Color(0xFF444444),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) => _selectSection(section),
          ),
        ),
    ]);
  }

  Widget _buildSpecificationStrip() {
    final specifications = _availableSpecifications;
    if (specifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return _arrowStrip(_specScroll, [
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          selected: _selectedSpecificationId == null,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: const Text('All subcategories'),
          selectedColor: _darkRed,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: _selectedSpecificationId == null
                ? Colors.white
                : const Color(0xFF555555),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
          onSelected: (_) {
            setState(() => _selectedSpecificationId = null);
          },
        ),
      ),
      for (final specification in specifications)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            selected:
                _selectedSpecificationId == specification['id']?.toString(),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(specification['name']?.toString() ?? 'Subcategory'),
            selectedColor: _darkRed,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: _selectedSpecificationId == specification['id']?.toString()
                  ? Colors.white
                  : const Color(0xFF555555),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) {
              setState(() {
                _selectedSpecificationId = specification['id']?.toString();
              });
            },
          ),
        ),
    ]);
  }

  Widget _buildQuickPriceProductCard(Map<String, dynamic> product) {
    final gradeCode = _gradeCode(product);
    final gradeName = _gradeName(product);
    final specification = _specificationName(product);
    final lambSummary = LambProductDetails.secondaryLine(product);
    final lambTitle = LambProductDetails.title(product, specification);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E2DE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 850;

            final productInfo = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      CatalogueProductImage(product: product, thumbnail: true),
                      if (gradeCode != 'NA' &&
                          gradeCode != 'N/A' &&
                          gradeCode != 'LAMB')
                        Tooltip(
                          message: gradeName,
                          child: Text(
                            gradeCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _darkRed,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lambTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_sectionName(product)}'
                        '${product['sku']?.toString().trim().isNotEmpty == true ? '  •  SKU ${product['sku']}' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF6A6A6A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ([
                        product['brand']?.toString() ?? '',
                        productSizeLabel(product),
                        productProgram(product),
                        product['marbling_score']?.toString() ?? '',
                      ].where((v) => v.isNotEmpty).join(' • ').isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          [
                            product['brand']?.toString() ?? '',
                            productSizeLabel(product),
                            productProgram(product),
                            product['marbling_score']?.toString() ?? '',
                          ].where((v) => v.isNotEmpty).join(' • '),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _darkRed,
                          ),
                        ),
                      ],
                      if (lambSummary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          lambSummary,
                          style: const TextStyle(
                            color: Color(0xFF4E5357),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      TextButton.icon(
                        onPressed:
                            _pendingChanges.values.any(
                              (change) => change.product['id'] == product['id'],
                            )
                            ? null
                            : () => _editProduct(product),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Edit product'),
                      ),
                      _stockEditor(product),
                      if (_isCatchWeight(product)) ...[
                        const SizedBox(height: 5),
                        const Text(
                          r'Carton order • $/kg catch-weight pricing',
                          style: TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  productInfo,
                  const SizedBox(height: 12),
                  const Text(
                    'STANDARD PRICE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _priceCell(product: product, visibility: 'public'),
                  const SizedBox(height: 10),
                  const Text(
                    'TRADE PRICE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _priceCell(
                    product: product,
                    visibility: 'approved_customers',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'CUSTOMER SPECIFIC',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _customerPriceCell(product),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: productInfo),
                const SizedBox(width: 12),
                SizedBox(
                  width: 155,
                  child: _priceCell(product: product, visibility: 'public'),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 155,
                  child: _priceCell(
                    product: product,
                    visibility: 'approved_customers',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 190, child: _customerPriceCell(product)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _priceHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E2DE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _darkRed, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF686868),
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceCell({
    required Map<String, dynamic> product,
    required String visibility,
  }) {
    final productId = product['id'].toString();
    final list = _firstPriceListForVisibility(visibility);
    final price = list == null
        ? null
        : _priceForProductAndList(productId, list['id'].toString());

    final basis = _isCatchWeight(product)
        ? 'kilogram'
        : price?['price_basis']?.toString() ??
              product['price_basis']?.toString() ??
              'unit';
    final controller = _inlineController(
      product: product,
      visibility: visibility,
      price: price,
    );
    final changed = _pendingChanges.containsKey(
      _changeKey(productId, visibility),
    );

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) => _queueInlinePrice(
        product: product,
        visibility: visibility,
        priceList: list,
        existingPrice: price,
        amountText: value,
      ),
      style: TextStyle(
        color: _darkRed,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        hintText: 'Not set',
        prefixText: r'$ ',
        suffixText: '/ ${_basisLabel(basis)}',
        isDense: true,
        filled: changed,
        fillColor: changed ? const Color(0xFFFFF4E5) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: changed ? const Color(0xFFE6A04B) : const Color(0xFFE3E3DF),
          ),
        ),
      ),
    );
  }

  Widget _customerPriceCell(Map<String, dynamic> product) {
    final productId = product['id'].toString();
    final count = _specialPriceCountForProduct(productId);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _manageCustomerPrices(product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E3DF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 0
                    ? 'No special prices'
                    : '$count customer price${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: count == 0 ? const Color(0xFF777777) : _darkRed,
                ),
              ),
            ),
            const Icon(
              Icons.people_alt_outlined,
              size: 18,
              color: Color(0xFF666666),
            ),
          ],
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PhoneStockScaffold(
      ready: !_isLoading && _errorMessage == null,
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: phoneAppBar(
        context,
        AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Inventory & Pricing',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            MissingItemRequestButton(
              businessId: _supplierBusinessId,
              pageName: 'Supplier inventory & pricing',
              catalogueContext: {
                'Animal': _selectedAnimalCode,
                'Cut / region': _selectedAnimalRegionKey,
                'Section ID': _selectedSectionId,
                'Specification ID': _selectedSpecificationId,
                'Search': _searchController.text,
              },
            ),
            IconButton(
              tooltip: 'Browse animal catalogue',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: _isLoading ? null : _browseDiagram,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _isLoading || _isSavingChanges ? null : _addProduct,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add product'),
              ),
            ),
            IconButton(
              onPressed: _isLoading || _isSavingChanges
                  ? null
                  : () {
                      if (_supplierBusinessId != null) {
                        SupplierStockCatalogue.invalidate(_supplierBusinessId!);
                      }
                      _loadPage();
                    },
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _isSavingChanges,
        child: Column(
          children: [
            const SupplierPhotoTermsNotice(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _pendingChanges.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE3E5E8))),
                ),
                child: PhoneRow(
                  mode: PhoneRowMode.wrap,
                  desktop: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_pendingChanges.length} unsaved price changes',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isSavingChanges ? null : _saveAllChanges,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          _isSavingChanges ? 'Saving…' : 'Save prices',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final products = _filteredProducts;
    final header = <Widget>[
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E5E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                Widget search(
                  TextEditingController controller,
                  String label,
                  IconData icon,
                ) => TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: Icon(icon),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: controller.clear,
                            icon: const Icon(Icons.close),
                          ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                final query = search(
                  _searchController,
                  'Search products, brand or specification',
                  Icons.search,
                );
                final sku = search(
                  _skuController,
                  'Search SKU',
                  Icons.qr_code_2,
                );
                if (box.maxWidth < 600) {
                  return Column(
                    children: [query, const SizedBox(height: 10), sku],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: query),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: sku),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            AnimalCatalogueControls(
              selectedCode: _selectedAnimalCode,
              onChanged: _selectAnimal,
              onBrowse: _browseDiagram,
            ),
            const SizedBox(height: 8),
            _buildSectionStrip(),
            if (_selectedSectionId != null ||
                _selectedAnimalRegionKey != null) ...[
              const SizedBox(height: 8),
              _buildSpecificationStrip(),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SupplierStockFilterBar(
          rows: const [],
          options: _filterChoices,
          filters: _stockFilters,
          showGrade: _selectedAnimalCode == CutLinkAnimals.beef,
          onChanged: () => setState(() {}),
        ),
      ),
      if (_loadingFilterChoices) const LinearProgressIndicator(minHeight: 2),
      if (_filterChoiceError != null)
        TextButton.icon(
          onPressed: () => _loadFilterChoices(_scopeSpecificationIds),
          icon: const Icon(Icons.refresh),
          label: Text('$_filterChoiceError Retry'),
        ),
      const SizedBox(height: 6),
      if (_loadingStock) const LinearProgressIndicator(minHeight: 2),
      if (_stockError != null)
        Row(
          children: [
            Expanded(child: Text(_stockError!)),
            TextButton(onPressed: _loadStock, child: const Text('Retry')),
          ],
        ),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 880) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'PRODUCT',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF666A70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 155,
                  child: _priceHeader(
                    title: 'Standard',
                    subtitle: 'Marketplace',
                    icon: Icons.public,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 155,
                  child: _priceHeader(
                    title: 'Trade',
                    subtitle: 'Approved customers',
                    icon: Icons.handshake_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 190,
                  child: _priceHeader(
                    title: 'Customer specific',
                    subtitle: 'Private pricing',
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ];
    final pager = SupplierStockPager(
      offset: _stockOffset,
      total: _stockTotal,
      loading: _loadingStock,
      onPage: (offset) {
        _stockOffset = offset;
        unawaited(_loadStock());
      },
    );
    final waiting =
        _loadingStock ||
        (_stockError == null && _loadedScope != _selectionSignature);
    return PhoneStockScrollView(
      maxContentWidth: 1440,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: header,
            ),
          ),
        ),
        if (waiting || _stockError != null || products.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: waiting
                    ? const CircularProgressIndicator()
                    : Text(
                        _stockError != null
                            ? 'Use Retry to reload your prices.'
                            : 'No products match these filters.',
                      ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  key: ValueKey(products[index]['id']),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildQuickPriceProductCard(products[index]),
                ),
                childCount: products.length,
              ),
            ),
          ),
        SliverToBoxAdapter(child: pager),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }
}
