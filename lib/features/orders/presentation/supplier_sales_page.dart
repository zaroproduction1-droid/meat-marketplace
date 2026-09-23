import '../../../shared/widgets/phone_stock_scaffold.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../../../shared/widgets/sales_loading_progress.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/animal_catalogues/product_variant.dart';
import '../../../shared/animal_catalogues/lamb_product_details.dart';
import '../../../shared/widgets/cutlink_picker.dart';
import '../../../shared/widgets/catalogue_product_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/animal_catalogues/animal_catalogue_registry.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';
import 'supplier_create_order_page.dart';
import 'supplier_orders_page.dart';
import 'supplier_quotes_page.dart';
import 'supplier_work_order_page.dart';

class SupplierSalesPage extends StatefulWidget {
  const SupplierSalesPage({
    super.key,
    this.embedded = false,
    this.initialQuoteOrderId,
    this.initialWorkOrderOrderId,
  });

  final bool embedded;
  final String? initialQuoteOrderId;
  final String? initialWorkOrderOrderId;

  @override
  State<SupplierSalesPage> createState() => _SupplierSalesPageState();
}

class _SupplierSalesPageState extends State<SupplierSalesPage> {
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _skuSearchController = TextEditingController();
  Timer? _searchDebounce;
  final ScrollController _cutScrollController = ScrollController();
  final ScrollController _subcategoryScrollController = ScrollController();
  final ScrollController _finalSpecificationScrollController =
      ScrollController();

  String _sizeFilter = '';
  String _programFilter = '';
  String _marblingFilter = '';
  String _brandFilter = '';
  String _boneFilter = '';
  String _fatClassFilter = '';
  String _temperatureFilter = '';
  String _stockSort = 'name';
  bool _halalFilter = false;
  bool _availableFilter = false;

  void _resetStockFilters() {
    _sizeFilter = '';
    _programFilter = '';
    _marblingFilter = '';
    _brandFilter = '';
    _boneFilter = '';
    _fatClassFilter = '';
    _temperatureFilter = '';
    _halalFilter = false;
    _availableFilter = false;
    _extraFilters.clear();
  }

  final Map<String, String> _extraFilters = {};
  Map<String, dynamic> _facetValues = {};
  List<Map<String, dynamic>> _facetGrades = [];
  List<Map<String, dynamic>> _facetSpecifications = [];
  String? _facetScope;
  int _facetRequest = 0;
  bool _facetsLoading = false;
  String? _facetError;
  String? _supplierBusinessId;
  static const _stockPageSize = 40;
  int _stockOffset = 0;
  int _stockTotal = 0;
  int _pageRequest = 0;
  bool _pageLoading = false;
  String? _pageError;
  final Map<String, Map<String, dynamic>> _saleProducts = {};
  final GlobalKey _stockHeaderKey = GlobalKey();
  final ValueNotifier<int> _facetRevision = ValueNotifier(0);

  List<String> _facetChoices(String field) =>
      (_facetValues[field] as List? ?? const []).map((v) => '$v').toList();

  void _changeStockFilters(VoidCallback change) {
    setState(change);
    _queueStockSearch();
  }

  void _queueStockSearch() {
    _searchDebounce?.cancel();
    ++_pageRequest; // Immediately invalidate any previous search response.
    if (_supplierBusinessId == null || !mounted) return;
    setState(() {
      _stockOffset = 0;
      _pageLoading = true;
      _pageError = null;
      _products = [];
    });
    unawaited(_loadStockFacets());
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) unawaited(_loadStockPage());
    });
  }

  String get _salesAnimalId =>
      _catalogueAnimals
          .firstWhere(
            (a) => a['code'] == _selectedAnimalCode,
            orElse: () => const {},
          )['id']
          ?.toString() ??
      '00000000-0000-0000-0000-000000000000';

  String? get _salesSectionId => _selectedAnimalRegionKey == null
      ? null
      : _selectedCatalogueSectionId ?? '00000000-0000-0000-0000-000000000000';

  Map<String, dynamic> get _stockQuery => {
    'animal': _salesAnimalId,
    'meat_section_id': _salesSectionId,
    'meat_specification_id': _selectedSpecificationId,
    'meat_grade_id': _selectedGradeId,
    'search': _searchController.text.trim(),
    'sku': _skuSearchController.text.trim(),
    'size': _sizeFilter,
    'program': _programFilter,
    'marbling_score': _marblingFilter,
    'brand': _brandFilter,
    'bone_state': _boneFilter,
    'fat_class': _fatClassFilter,
    'temperature_state': _temperatureFilter,
    'halal': _halalFilter,
    'available': _availableFilter,
    'sort': _stockSort,
    ..._extraFilters,
  };

  Future<void> _loadStockFacets({bool force = false}) async {
    if (_supplierBusinessId == null) return;
    final scope =
        '$_supplierBusinessId|$_salesAnimalId|$_salesSectionId|$_selectedSpecificationId';
    if (!force && _facetScope == scope) return;
    final request = ++_facetRequest;
    setState(() {
      _facetScope = scope;
      _facetsLoading = true;
      _facetError = null;
      _facetValues = {};
      _facetGrades = [];
      _facetSpecifications = [];
    });
    try {
      final raw = await Supabase.instance.client
          .rpc(
            'supplier_sales_stock_facets',
            params: {
              'p_supplier_business_id': _supplierBusinessId,
              'p_animal_id': _salesAnimalId,
              'p_section_id': _salesSectionId,
              'p_specification_id': _selectedSpecificationId,
            },
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted || request != _facetRequest) return;
      final data = _nestedMap(raw) ?? {};
      setState(() {
        _facetValues = _nestedMap(data['values']) ?? {};
        _facetGrades = _rows(data['grades']);
        _facetSpecifications = _rows(data['specifications']);
      });
    } catch (_) {
      if (!mounted || request != _facetRequest) return;
      setState(() {
        _facetScope = null;
        _facetError =
            'Filter options could not load. Your stock search is still available.';
      });
    } finally {
      if (mounted && request == _facetRequest) {
        setState(() => _facetsLoading = false);
        _facetRevision.value++;
      }
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  Future<void> _loadStockPage({int offset = 0}) async {
    if (_supplierBusinessId == null) return;
    _searchDebounce?.cancel();
    final request = ++_pageRequest;
    final query = _stockQuery;
    setState(() {
      _pageLoading = true;
      _pageError = null;
      _products = [];
    });
    try {
      final raw = await Supabase.instance.client
          .rpc(
            'supplier_sales_stock_page',
            params: {
              'p_supplier_business_id': _supplierBusinessId,
              'p_filters': query,
              'p_offset': offset,
              'p_limit': _stockPageSize,
            },
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted || request != _pageRequest) return;
      final data = _nestedMap(raw) ?? {};
      final total = (data['total'] as num?)?.toInt() ?? 0;
      if (offset > 0 && offset >= total) {
        await _loadStockPage(
          offset: total == 0
              ? 0
              : ((total - 1) ~/ _stockPageSize) * _stockPageSize,
        );
        return;
      }
      setState(() {
        _products = _rows(data['products']);
        _stockTotal = total;
        _stockOffset = offset;
      });
      if (offset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _stockHeaderKey.currentContext;
          if (mounted && request == _pageRequest && target != null) {
            Scrollable.ensureVisible(
              target,
              duration: const Duration(milliseconds: 180),
            );
          }
        });
      }
    } catch (error) {
      if (!mounted || request != _pageRequest) return;
      setState(
        () => _pageError = error is TimeoutException
            ? 'Stock search took too long. Narrow your cut or search, or try again.'
            : error is PostgrestException
            ? error.message
            : 'Could not load stock. Please try again.',
      );
    } finally {
      if (mounted && request == _pageRequest) {
        setState(() => _pageLoading = false);
      }
    }
  }

  Widget _salesStockFilters() {
    Widget picker(
      String label,
      String field,
      String value,
      ValueChanged<String> change,
    ) {
      final choices =
          {..._facetChoices(field), if (value.isNotEmpty) value}.toList()..sort(
            field == 'size'
                ? compareProductSizeLabels
                : (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
          );
      return SizedBox(
        width: 195,
        child: CutLinkPickerField<String>(
          label: label,
          value: value,
          dense: true,
          showLabelWhenDense: true,
          options: [
            CutLinkPickerOption(value: '', label: 'Any ${label.toLowerCase()}'),
            for (final v in choices)
              CutLinkPickerOption(
                value: v,
                label: field == 'size'
                    ? v
                    : productSpecificationLabel(field, v),
              ),
          ],
          onChanged: (v) {
            if (v != null) _changeStockFilters(() => change(v));
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_facetsLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Loading filter choices…',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (_facetError != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_facetError!),
              TextButton(
                onPressed: () => _loadStockFacets(force: true),
                child: const Text('Retry filters'),
              ),
            ],
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            picker('Size', 'size', _sizeFilter, (v) => _sizeFilter = v),
            if (_facetChoices('program').isNotEmpty ||
                _programFilter.isNotEmpty)
              picker(
                'Program',
                'program',
                _programFilter,
                (v) => _programFilter = v,
              ),
            if (_facetChoices('marbling_score').isNotEmpty ||
                _marblingFilter.isNotEmpty)
              picker(
                _programFilter == 'Wagyu' ? 'Wagyu MB' : 'Marbling',
                'marbling_score',
                _marblingFilter,
                (v) => _marblingFilter = v,
              ),
            picker('Brand', 'brand', _brandFilter, (v) => _brandFilter = v),
            if (_facetChoices('bone_state').isNotEmpty ||
                _boneFilter.isNotEmpty)
              picker('Bone', 'bone_state', _boneFilter, (v) => _boneFilter = v),
            if (_facetChoices('fat_class').isNotEmpty ||
                _fatClassFilter.isNotEmpty)
              picker(
                'Fat Class',
                'fat_class',
                _fatClassFilter,
                (v) => _fatClassFilter = v,
              ),
            picker(
              'Temperature',
              'temperature_state',
              _temperatureFilter,
              (v) => _temperatureFilter = v,
            ),
            for (final entry in const {
              'packaging_type': 'Packaging',
              'chicken_skin': 'Skin',
              'chicken_bone': 'Chicken bone',
              'chicken_production_type': 'Production',
              'chicken_preparation': 'Preparation',
              'chicken_carton_size': 'Carton configuration',
            }.entries)
              if (_facetChoices(
                    entry.key,
                  ).any((v) => v != 'not_applicable' && v != 'not_specified') ||
                  (_extraFilters[entry.key] ?? '').isNotEmpty)
                picker(
                  entry.value,
                  entry.key,
                  _extraFilters[entry.key] ?? '',
                  (v) => _extraFilters[entry.key] = v,
                ),
            SizedBox(
              width: 195,
              child: CutLinkPickerField<String>(
                label: 'Sort stock',
                value: _stockSort,
                dense: true,
                showLabelWhenDense: true,
                enableSearch: false,
                options: const [
                  CutLinkPickerOption(value: 'name', label: 'Product: A–Z'),
                  CutLinkPickerOption(
                    value: 'price_low',
                    label: 'Standard price: low to high',
                  ),
                  CutLinkPickerOption(
                    value: 'price_high',
                    label: 'Standard price: high to low',
                  ),
                  CutLinkPickerOption(
                    value: 'stock',
                    label: 'Stock: most available',
                  ),
                ],
                onChanged: (v) {
                  if (v != null) _changeStockFilters(() => _stockSort = v);
                },
              ),
            ),
            FilterChip(
              label: const Text('Halal only'),
              selected: _halalFilter,
              onSelected: (v) => _changeStockFilters(() => _halalFilter = v),
            ),
            FilterChip(
              label: const Text('Available only'),
              selected: _availableFilter,
              onSelected: (v) =>
                  _changeStockFilters(() => _availableFilter = v),
            ),
            TextButton(
              onPressed: () => _changeStockFilters(_resetStockFilters),
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stockPagination() => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      TextButton.icon(
        onPressed: _pageLoading || _stockOffset == 0
            ? null
            : () => _loadStockPage(offset: _stockOffset - _stockPageSize),
        icon: const Icon(Icons.chevron_left),
        label: const Text('Previous'),
      ),
      Text(
        _pageLoading
            ? 'Searching…'
            : _stockTotal == 0
            ? '0 results'
            : '${_stockOffset + 1}–${_stockOffset + _products.length} of $_stockTotal',
      ),
      TextButton.icon(
        onPressed: _pageLoading || _stockOffset + _stockPageSize >= _stockTotal
            ? null
            : () => _loadStockPage(offset: _stockOffset + _stockPageSize),
        icon: const Icon(Icons.chevron_right),
        label: const Text('Next'),
      ),
    ],
  );

  bool _isLoading = true;
  int _loadStage = 0;
  int _loadedStockCount = 0;
  int? _totalStockCount;
  int _stockLoadRequest = 0;
  String? _errorMessage;
  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSpecificationId;
  String? _selectedGradeId;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _catalogueAnimals = [];
  List<Map<String, dynamic>> _catalogueSections = [];
  int _newMarketplaceItemCount = 0;

  Map<String, dynamic>? _activeSale;
  final List<Map<String, dynamic>> _activeSaleLines = [];
  bool _activeSaleMinimized = false;

  // Other open sale sessions are parked here while the salesperson works
  // on the currently active sale. There is no fixed limit.
  final List<Map<String, dynamic>> _parkedSales = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _skuSearchController.addListener(_refresh);
    _initialiseSalesWorkspace();
  }

  Future<void> _initialiseSalesWorkspace() async {
    await _loadStock();

    if (!mounted) {
      return;
    }

    final quoteOrderId = widget.initialQuoteOrderId?.trim();

    if (quoteOrderId != null && quoteOrderId.isNotEmpty) {
      await _loadQuoteIntoWorkspace(quoteOrderId);
      return;
    }

    final workOrderOrderId = widget.initialWorkOrderOrderId?.trim();

    if (workOrderOrderId != null && workOrderOrderId.isNotEmpty) {
      await _loadWorkOrderAdditionsIntoWorkspace(workOrderOrderId);
    }
  }

  Future<void> _loadWorkOrderAdditionsIntoWorkspace(String orderId) async {
    try {
      final raw = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            order_number,
            customer_contact_name_snapshot,
            supplier_customer_account_id,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            fulfilment_method,
            requested_fulfilment_date,
            requested_fulfilment_time,
            delivery_notes,
            internal_notes,
            source_reference,
            customer_reference,
            delivery_fee,
            order_source,
            supplier_customer_accounts(*),
            order_items(
              id,
              product_id,
              product_name_snapshot,
              sku_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              catch_weight_snapshot,
              notes,
              invoice_excluded
            )
          ''')
          .eq('id', orderId)
          .single();

      if (!mounted) {
        return;
      }

      final order = Map<String, dynamic>.from(raw);
      final account = _nestedMap(order['supplier_customer_accounts']);
      final existingItems = _nestedList(
        order['order_items'],
      ).where((item) => item['invoice_excluded'] != true).toList();
      if (account == null) {
        throw Exception('The work order customer could not be loaded.');
      }

      setState(() {
        _parkCurrentSale();
        _activeSale = {
          'work_order_order_id': order['id'],
          'order_number': order['order_number'],
          'supplier_customer_account_id':
              order['supplier_customer_account_id'] ?? account['id'],
          'customer': account,
          'customer_contact_name_snapshot':
              order['customer_contact_name_snapshot'],
          'customer_name':
              account['customer_name']?.toString().trim().isNotEmpty == true
              ? account['customer_name'].toString().trim()
              : 'Customer',
          'payment_method':
              order['payment_method_snapshot']?.toString() ?? 'cod',
          'payment_terms_days':
              (order['payment_terms_days_snapshot'] as num?)?.toInt() ?? 0,
          'fulfilment_method':
              order['fulfilment_method']?.toString() ?? 'pickup',
          'requested_fulfilment_date': order['requested_fulfilment_date']
              ?.toString(),
          'requested_fulfilment_time': order['requested_fulfilment_time']
              ?.toString(),
          'delivery_notes': order['delivery_notes']?.toString() ?? '',
          'internal_notes': order['internal_notes']?.toString() ?? '',
          'source_reference': order['source_reference']?.toString(),
          'customer_reference': order['customer_reference']?.toString(),
          'delivery_fee': (order['delivery_fee'] as num?)?.toDouble() ?? 0,
          'order_source': order['order_source']?.toString() ?? 'manual',
        };
        _activeSaleLines
          ..clear()
          ..addAll(
            existingItems.map(
              (item) => {
                'existing_order_item_id': item['id'],
                'product_id': item['product_id'],
                'product_name':
                    item['product_name_snapshot']?.toString() ?? 'Product',
                'sku': item['sku_snapshot']?.toString(),
                'quantity': item['quantity'],
                'quantity_unit': item['quantity_unit']?.toString() ?? 'unit',
                'unit_price': item['unit_price'],
                'price_basis': item['price_basis']?.toString() ?? 'unit',
                'catch_weight_snapshot': item['catch_weight_snapshot'] == true,
                'notes': item['notes']?.toString() ?? '',
              },
            ),
          );
        _activeSaleMinimized = false;
        _selectedAnimalRegionKey = null;
        _searchController.clear();
      });
      _queueStockSearch();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add products to ${order['order_number'] ?? 'this work order'}.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  void dispose() {
    ++_pageRequest;
    ++_facetRequest;
    ++_stockLoadRequest;
    _searchDebounce?.cancel();
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    _skuSearchController.removeListener(_refresh);
    _skuSearchController.dispose();
    _facetRevision.dispose();
    _cutScrollController.dispose();
    _subcategoryScrollController.dispose();
    _finalSpecificationScrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) _queueStockSearch();
  }

  Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }

    return null;
  }

  List<Map<String, dynamic>> _nestedList(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<String> _resolveSupplierBusinessId() async {
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
      for (final raw in memberships)
        if (raw['business_id'] != null) raw['business_id'].toString(),
    ];

    if (businessIds.isEmpty) {
      throw Exception('No active business membership was found.');
    }

    final businesses = await client
        .from('businesses')
        .select('id, business_type, active')
        .inFilter('id', businessIds)
        .eq('active', true);

    for (final raw in businesses) {
      if (raw['business_type']?.toString() == 'supplier') {
        final id = raw['id']?.toString();

        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    }

    throw Exception('No active supplier business membership was found.');
  }

  Future<void> _loadStock() async {
    final request = ++_stockLoadRequest;
    ++_pageRequest;
    ++_facetRequest;
    _searchDebounce?.cancel();
    setState(() {
      _isLoading = true;
      _loadStage = 0;
      _loadedStockCount = 0;
      _totalStockCount = null;
      _errorMessage = null;
      _facetScope = null;
    });
    try {
      final client = Supabase.instance.client;
      final supplier = await _resolveSupplierBusinessId().timeout(
        const Duration(seconds: 30),
      );
      if (!mounted || request != _stockLoadRequest) return;
      setState(() {
        _supplierBusinessId = supplier;
        _loadStage = 1;
      });
      final responses = await Future.wait<dynamic>([
        client
            .from('meat_animals')
            .select('id, code, name')
            .eq('is_active', true),
        client
            .from('meat_sections')
            .select(
              'id, animal_id, code, name, slug, hotspot_key, display_order',
            )
            .eq('is_active', true)
            .order('display_order'),
        client
            .from('orders')
            .select('id, order_items(id)')
            .eq('supplier_business_id', supplier)
            .eq('order_source', 'marketplace')
            .eq('status', 'submitted'),
      ]).timeout(const Duration(seconds: 30));
      if (!mounted || request != _stockLoadRequest) return;
      setState(() {
        _catalogueAnimals = _rows(responses[0]);
        _catalogueSections = _rows(responses[1]);
        _newMarketplaceItemCount = _rows(responses[2]).fold<int>(
          0,
          (sum, row) => sum + (row['order_items'] as List? ?? const []).length,
        );
        _loadStage = 4;
        _isLoading = false;
      });
      await Future.wait<void>([
        _loadStockPage(),
        _loadStockFacets(force: true),
      ]);
    } catch (error) {
      if (!mounted || request != _stockLoadRequest) return;
      setState(() {
        _errorMessage = error is TimeoutException
            ? 'Loading took too long. Please try again.'
            : error is PostgrestException
            ? error.message
            : error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadQuoteIntoWorkspace(String quoteOrderId) async {
    try {
      final client = Supabase.instance.client;
      final supplierBusinessId = await _resolveSupplierBusinessId();

      final raw = await client
          .from('orders')
          .select('''
            id,
            order_number,
            quote_number,
            quote_revision,
            status,
            order_source,
            source_reference,
            customer_reference,
            delivery_notes,
            internal_notes,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            fulfilment_method,
            requested_fulfilment_date,
            requested_fulfilment_time,
            delivery_fee,
            supplier_customer_account_id,
            supplier_customer_accounts(
              id,
              customer_name,
              legal_name,
              payment_method,
              payment_terms_days,
              delivery_address_line_1,
              delivery_address_line_2,
              delivery_suburb,
              delivery_state,
              delivery_postcode
            ),
            order_items(
              id,
              product_id,
              product_name_snapshot,
              sku_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              catch_weight_snapshot,
              notes
            )
          ''')
          .eq('id', quoteOrderId)
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'draft')
          .single();

      if (!mounted) {
        return;
      }

      final quote = Map<String, dynamic>.from(raw);
      final account = _nestedMap(quote['supplier_customer_accounts']);
      final items = _nestedList(quote['order_items']);

      if (account == null) {
        throw Exception('The quote customer account could not be loaded.');
      }

      final addressParts = <String>[
        account['delivery_address_line_1']?.toString().trim() ?? '',
        account['delivery_address_line_2']?.toString().trim() ?? '',
        account['delivery_suburb']?.toString().trim() ?? '',
        account['delivery_state']?.toString().trim() ?? '',
        account['delivery_postcode']?.toString().trim() ?? '',
      ].where((part) => part.isNotEmpty).toList();

      setState(() {
        _parkCurrentSale();

        _activeSale = {
          'quote_order_id': quote['id'],
          'quote_number': quote['quote_number'] ?? quote['order_number'],
          'quote_revision': quote['quote_revision'],
          'supplier_customer_account_id':
              quote['supplier_customer_account_id'] ?? account['id'],
          'customer': account,
          'customer_name':
              account['customer_name']?.toString().trim().isNotEmpty == true
              ? account['customer_name'].toString().trim()
              : 'Customer',
          'payment_method':
              quote['payment_method_snapshot']?.toString() ?? 'cod',
          'payment_terms_days':
              (quote['payment_terms_days_snapshot'] as num?)?.toInt() ?? 0,
          'fulfilment_method':
              quote['fulfilment_method']?.toString() ?? 'pickup',
          'requested_fulfilment_date': quote['requested_fulfilment_date']
              ?.toString(),
          'requested_fulfilment_time': quote['requested_fulfilment_time']
              ?.toString(),
          'delivery_address': addressParts.isEmpty
              ? null
              : addressParts.join(', '),
          'delivery_notes': quote['delivery_notes']?.toString() ?? '',
          'internal_notes': quote['internal_notes']?.toString() ?? '',
          'source_reference': quote['source_reference']?.toString(),
          'customer_reference': quote['customer_reference']?.toString(),
          'delivery_fee': (quote['delivery_fee'] as num?)?.toDouble() ?? 0,
          'order_source': quote['order_source']?.toString() ?? 'manual',
        };

        _activeSaleLines
          ..clear()
          ..addAll(
            items.map(
              (item) => {
                'product_id': item['product_id'],
                'product_name':
                    item['product_name_snapshot']?.toString() ?? 'Product',
                'sku': item['sku_snapshot']?.toString(),
                'quantity': item['quantity'],
                'quantity_unit': item['quantity_unit']?.toString() ?? 'unit',
                'unit_price': item['unit_price'],
                'price_basis': item['price_basis']?.toString() ?? 'unit',
                'catch_weight_snapshot': item['catch_weight_snapshot'] == true,
                'notes': item['notes']?.toString() ?? '',
              },
            ),
          );

        _activeSaleMinimized = false;
        _selectedAnimalRegionKey = null;
        _searchController.clear();
      });
      _queueStockSearch();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quote ${quote['order_number'] ?? ''} reopened in Sales.',
          ),
        ),
      );
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
    }
  }

  String? _productAnimalCode(Map<String, dynamic> product) {
    final rawAnimal = product['meat_animals'];

    if (rawAnimal is Map) {
      final animal = Map<String, dynamic>.from(rawAnimal);
      final code = animal['code']?.toString().trim().toUpperCase();

      if (code != null && code.isNotEmpty) {
        return code;
      }
    }

    // Existing Beef stock created before meat_animal_id was populated may
    // still have a valid beef meat_section_id. Keep those visible under Beef.
    if (product['meat_section_id'] != null) {
      return CutLinkAnimals.beef;
    }

    return null;
  }

  String _selectedCutLabel(String regionKey) {
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    return catalogue?.regionLabel(regionKey) ?? regionKey;
  }

  String _specificationName(Map<String, dynamic> product) {
    final specification = _nestedMap(product['meat_specifications']);
    return specification?['name']?.toString().trim().isNotEmpty == true
        ? specification!['name'].toString().trim()
        : product['product_name']?.toString().trim().isNotEmpty == true
        ? product['product_name'].toString().trim()
        : 'Unspecified cut';
  }

  String _gradeCode(Map<String, dynamic> product) {
    final grade = _nestedMap(product['meat_grades']);
    final code = grade?['code']?.toString().trim();
    return code == null || code.isEmpty ? 'N/A' : code;
  }

  String _gradeName(Map<String, dynamic> product) {
    final grade = _nestedMap(product['meat_grades']);
    final name = grade?['name']?.toString().trim();
    return name == null || name.isEmpty ? '' : name;
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

    return values.isEmpty ? 'Standard Chicken' : values.join(' • ');
  }

  String _normaliseCatalogueKey(dynamic value) {
    return (value?.toString() ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String? get _selectedCatalogueSectionId {
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

  List<Map<String, String>> get _availableSpecifications => [
    for (final row in _facetSpecifications)
      {'id': '${row['id']}', 'name': '${row['name']}'},
  ];

  List<Map<String, String>> get _availableGrades => [
    for (final row in _facetGrades)
      {
        'id': '${row['id']}',
        'code': '${row['code']}',
        'name': '${row['name']}',
      },
  ];

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) {
      return;
    }

    final catalogue = AnimalCatalogueRegistry.forCode(animalCode);

    _changeStockFilters(() {
      _resetStockFilters();
      _selectedAnimalCode = animalCode;
      _selectedAnimalRegionKey = catalogue?.defaultRegionKey;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });
  }

  void _selectAnimalRegion(String regionKey) {
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    if (catalogue == null || !catalogue.regionKeys.contains(regionKey)) {
      return;
    }

    _changeStockFilters(() {
      _resetStockFilters();
      _selectedAnimalRegionKey = regionKey;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_subcategoryScrollController.hasClients) {
        _subcategoryScrollController.jumpTo(0);
      }
    });
  }

  void _clearAnimalRegion() {
    if (_selectedAnimalRegionKey == null) {
      return;
    }

    _changeStockFilters(() {
      _resetStockFilters();
      _selectedAnimalRegionKey = null;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });
  }

  bool _isCatchWeight(Map<String, dynamic> product) {
    return product['weight_type']?.toString() == 'catch_weight' ||
        product['catch_weight'] == true;
  }

  Map<String, dynamic>? _standardPrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List) {
      return null;
    }

    for (final raw in rawPrices) {
      if (raw is! Map) {
        continue;
      }

      final price = Map<String, dynamic>.from(raw);

      if (price['active'] != true) {
        continue;
      }

      final rawList = price['price_lists'];

      if (rawList is! Map) {
        continue;
      }

      final list = Map<String, dynamic>.from(rawList);

      if (list['active'] == true &&
          list['visibility']?.toString() == 'public') {
        return price;
      }
    }

    return null;
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return 'No standard price';
    }

    final fixed = number.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final decimal = parts.last;

    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '\$${buffer.toString()}.$decimal';
  }

  String _basisLabel(Map<String, dynamic> product) {
    if (_isCatchWeight(product)) {
      return 'kg';
    }

    final basis = product['price_basis']?.toString();

    switch (basis) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'carton';
      case 'unit':
        return 'unit';
      default:
        return basis ?? 'unit';
    }
  }

  String _quantityLabel(Map<String, dynamic> product) {
    final quantity = product['available_quantity'];
    final unit = product['quantity_unit']?.toString();

    if (quantity == null) {
      return 'Availability not entered';
    }

    final number = quantity is num
        ? quantity.toDouble()
        : double.tryParse(quantity.toString());

    final quantityText = number == null
        ? quantity.toString()
        : number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);

    final unitText = switch (unit) {
      'carton' => 'cartons',
      'kilogram' => 'kg',
      'unit' => 'units',
      _ => unit ?? '',
    };

    return '$quantityText${unitText.isEmpty ? '' : ' $unitText'}';
  }

  String _availabilityLabel(String? value) {
    return switch (value) {
      'in_stock' => 'In stock',
      'limited' => 'Limited',
      'out_of_stock' => 'Out of stock',
      'made_to_order' => 'Made to order',
      _ => 'Unknown',
    };
  }

  Future<void> _openNewSale({Map<String, dynamic>? pendingProduct}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const SupplierCreateOrderPage()),
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      setState(() {
        _parkCurrentSale();
        _activeSale = Map<String, dynamic>.from(result);
        _activeSaleLines.clear();
        _activeSaleMinimized = false;
      });

      if (pendingProduct != null) {
        await _addProductToActiveSale(pendingProduct);
      }
    }

    if (mounted) {
      await _loadStock();
    }
  }

  int get _openSaleCount => (_activeSale == null ? 0 : 1) + _parkedSales.length;

  void _parkCurrentSale() {
    final sale = _activeSale;
    if (sale == null) {
      return;
    }

    _parkedSales.add({
      'sale': Map<String, dynamic>.from(sale),
      'lines': [
        for (final line in _activeSaleLines) Map<String, dynamic>.from(line),
      ],
      'minimized': _activeSaleMinimized,
    });
  }

  void _switchToParkedSale(int index) {
    if (index < 0 || index >= _parkedSales.length) {
      return;
    }

    setState(() {
      final selected = _parkedSales.removeAt(index);

      if (_activeSale != null) {
        _parkCurrentSale();
      }

      _activeSale = Map<String, dynamic>.from(selected['sale'] as Map);
      _activeSaleLines
        ..clear()
        ..addAll(
          (selected['lines'] as List).whereType<Map>().map(
            (line) => Map<String, dynamic>.from(line),
          ),
        );
      _activeSaleMinimized = selected['minimized'] == true;
    });
  }

  String _parkedSaleCustomerName(Map<String, dynamic> parked) {
    final sale = parked['sale'];
    if (sale is! Map) {
      return 'Customer';
    }

    return sale['customer_name']?.toString() ?? 'Customer';
  }

  int _parkedSaleLineCount(Map<String, dynamic> parked) {
    final lines = parked['lines'];
    return lines is List ? lines.length : 0;
  }

  String get _activeSaleCustomerName =>
      _activeSale?['customer_name']?.toString() ?? 'Customer';

  String _saleUnitLabel(String value) {
    return switch (value) {
      'carton' => 'cartons',
      'kilogram' => 'kg',
      'unit' => 'units',
      _ => value,
    };
  }

  String _saleBasisLabel(String value) {
    return switch (value) {
      'carton' => 'carton',
      'kilogram' => 'kg',
      'unit' => 'unit',
      _ => value,
    };
  }

  String _orderUnit(Map<String, dynamic> product) {
    if (_isCatchWeight(product)) {
      return 'carton';
    }

    final configured = product['order_unit']?.toString();
    if (configured == 'carton' ||
        configured == 'kilogram' ||
        configured == 'unit') {
      return configured!;
    }

    final stockUnit = product['quantity_unit']?.toString();
    if (stockUnit == 'carton' ||
        stockUnit == 'kilogram' ||
        stockUnit == 'unit') {
      return stockUnit!;
    }

    return 'unit';
  }

  String _salePriceBasis(Map<String, dynamic> product) {
    if (_isCatchWeight(product)) {
      return 'kilogram';
    }

    final configured = product['price_basis']?.toString();
    if (configured == 'carton' ||
        configured == 'kilogram' ||
        configured == 'unit') {
      return configured!;
    }

    return 'unit';
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _saleEstimatedTotal() {
    var total = 0.0;

    for (final line in _activeSaleLines) {
      final quantity = line['quantity'] is num
          ? (line['quantity'] as num).toDouble()
          : double.tryParse('${line['quantity']}') ?? 0;
      final rate = line['unit_price'] is num
          ? (line['unit_price'] as num).toDouble()
          : double.tryParse('${line['unit_price']}') ?? 0;

      if (line['catch_weight_snapshot'] == true &&
          line['price_basis']?.toString() == 'kilogram') {
        continue;
      }

      total += quantity * rate;
    }

    return total;
  }

  int _activeSaleLineIndex(String productId) {
    return _activeSaleLines.indexWhere(
      (line) =>
          line['product_id']?.toString() == productId &&
          (_activeSale?['work_order_order_id'] == null ||
              line['existing_order_item_id'] == null),
    );
  }

  Future<void> _editSaleProduct(String productId) async {
    try {
      var product = _saleProducts[productId];
      if (product == null) {
        final supplier =
            _supplierBusinessId ?? await _resolveSupplierBusinessId();
        final raw = await Supabase.instance.client
            .from('products')
            .select(
              '*, meat_animals(*), meat_sections(*), meat_specifications(*), meat_grades(*), product_prices(*, price_lists(*))',
            )
            .eq('supplier_business_id', supplier)
            .eq('id', productId)
            .maybeSingle()
            .timeout(const Duration(seconds: 30));
        product = _nestedMap(raw);
      }
      if (!mounted) return;
      if (product == null) {
        throw StateError('This product is no longer available.');
      }
      await _addProductToActiveSale(product);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load this sale item. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _addProductToActiveSale(Map<String, dynamic> product) async {
    final cacheId = product['id']?.toString();
    if (cacheId != null) {
      _saleProducts[cacheId] = Map<String, dynamic>.from(product);
    }
    if (_activeSale == null) {
      await _openNewSale(pendingProduct: product);
      return;
    }

    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) {
      return;
    }

    final existingIndex = _activeSaleLineIndex(productId);
    final existing = existingIndex >= 0
        ? _activeSaleLines[existingIndex]
        : null;

    final catchWeight = _isCatchWeight(product);
    final quantityUnit = _orderUnit(product);
    final priceBasis = _salePriceBasis(product);
    final standardPrice = _standardPrice(product);
    final quantityController = TextEditingController(
      text: existing?['quantity']?.toString() ?? '1',
    );
    final rateController = TextEditingController(
      text:
          existing?['unit_price']?.toString() ??
          standardPrice?['amount']?.toString() ??
          '',
    );
    final notesController = TextEditingController(
      text: existing?['notes']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quantity = double.tryParse(quantityController.text.trim());
            final rate = double.tryParse(rateController.text.trim());
            final whole = quantityUnit == 'carton' || quantityUnit == 'unit';
            final validQuantity =
                quantity != null &&
                quantity > 0 &&
                (!whole || quantity == quantity.roundToDouble());
            final validRate = rate != null && rate >= 0;

            return phoneDialog(
              context,
              AlertDialog(
                title: Text(
                  '${existing == null ? 'Add' : 'Update'} '
                  '${product['product_name']?.toString() ?? 'Product'}',
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sale: $_activeSaleCustomerName',
                          style: const TextStyle(
                            color: _darkRed,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (catchWeight) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Catch-weight product: enter cartons ordered and '
                              'the agreed \$/kg rate. Final kilograms and total '
                              'will be confirmed during warehouse weighing.',
                              style: TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                        TextField(
                          controller: quantityController,
                          autofocus: true,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: !whole,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            suffixText: _saleUnitLabel(quantityUnit),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Agreed rate',
                            prefixText: r'$ ',
                            suffixText: '/ ${_saleBasisLabel(priceBasis)}',
                            helperText: standardPrice == null
                                ? 'Enter the agreed customer rate.'
                                : 'Standard price: '
                                      '${_money(standardPrice['amount'])} / '
                                      '${_saleBasisLabel(priceBasis)}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Line notes (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: validQuantity && validRate
                        ? () => Navigator.of(dialogContext).pop({
                            'product_id': productId,
                            'product_name':
                                product['product_name']?.toString() ??
                                'Unnamed product',
                            'sku': product['sku']?.toString(),
                            'quantity': quantity,
                            'quantity_unit': quantityUnit,
                            'unit_price': rate,
                            'price_basis': priceBasis,
                            'catch_weight_snapshot': catchWeight,
                            'notes': notesController.text.trim(),
                          })
                        : null,
                    style: FilledButton.styleFrom(backgroundColor: _darkRed),
                    icon: Icon(
                      existing == null ? Icons.add : Icons.save_outlined,
                    ),
                    label: Text(existing == null ? 'Add to Sale' : 'Update'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    quantityController.dispose();
    rateController.dispose();
    notesController.dispose();

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (existingIndex >= 0) {
        _activeSaleLines[existingIndex] = result;
      } else {
        _activeSaleLines.add(result);
      }

      _activeSaleMinimized = false;
    });
  }

  Future<void> _handleAddToSale(Map<String, dynamic> product) async {
    if (_openSaleCount == 0) {
      await _openNewSale(pendingProduct: product);
      return;
    }

    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add to Sale',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choose one of your $_openSaleCount open sales or start another.',
                    style: const TextStyle(color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (_activeSale != null)
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF4E5E5),
                              child: Icon(
                                Icons.shopping_cart_checkout_outlined,
                                color: _darkRed,
                              ),
                            ),
                            title: Text(
                              _activeSaleCustomerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${_activeSaleLines.length} item'
                              '${_activeSaleLines.length == 1 ? '' : 's'} • Currently open',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(
                              sheetContext,
                            ).pop({'type': 'active'}),
                          ),
                        for (var i = 0; i < _parkedSales.length; i++)
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.receipt_long_outlined),
                            ),
                            title: Text(
                              _parkedSaleCustomerName(_parkedSales[i]),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${_parkedSaleLineCount(_parkedSales[i])} item'
                              '${_parkedSaleLineCount(_parkedSales[i]) == 1 ? '' : 's'} • Open sale',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(
                              sheetContext,
                            ).pop({'type': 'parked', 'index': i}),
                          ),
                        const Divider(),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF4E5E5),
                            child: Icon(
                              Icons.add_business_outlined,
                              color: _darkRed,
                            ),
                          ),
                          title: const Text(
                            'Start New Sale',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text(
                            'Your existing open sales will stay saved in this workspace.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.of(sheetContext).pop({'type': 'new'}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) {
      return;
    }

    final type = choice['type']?.toString();

    if (type == 'active') {
      await _addProductToActiveSale(product);
      return;
    }

    if (type == 'parked') {
      final index = choice['index'];
      if (index is int) {
        _switchToParkedSale(index);
        if (mounted) {
          await _addProductToActiveSale(product);
        }
      }
      return;
    }

    if (type == 'new') {
      await _openNewSale(pendingProduct: product);
    }
  }

  Future<void> _startAnotherSale({Map<String, dynamic>? pendingProduct}) async {
    await _openNewSale(pendingProduct: pendingProduct);
  }

  void _removeSaleLine(int index) {
    setState(() {
      _activeSaleLines.removeAt(index);
    });
  }

  void _closeActiveSale() {
    setState(() {
      _activeSale = null;
      _activeSaleLines.clear();
      _activeSaleMinimized = false;

      if (_parkedSales.isNotEmpty) {
        final next = _parkedSales.removeLast();
        _activeSale = Map<String, dynamic>.from(next['sale'] as Map);
        _activeSaleLines.addAll(
          (next['lines'] as List).whereType<Map>().map(
            (line) => Map<String, dynamic>.from(line),
          ),
        );
        _activeSaleMinimized = next['minimized'] == true;
      }
    });
  }

  Widget _openSalesSwitcher() {
    if (_openSaleCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dynamic_feed_outlined, color: _darkRed),
          const SizedBox(width: 10),
          Text(
            'Open Sales ($_openSaleCount)',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_activeSale != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: true,
                        label: Text(_activeSaleCustomerName),
                        onSelected: (_) {},
                      ),
                    ),
                  for (var i = 0; i < _parkedSales.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(
                          Icons.receipt_long_outlined,
                          size: 17,
                        ),
                        label: Text(_parkedSaleCustomerName(_parkedSales[i])),
                        onPressed: () => _switchToParkedSale(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _startAnotherSale(),
            icon: const Icon(Icons.add),
            label: const Text('New Sale'),
          ),
        ],
      ),
    );
  }

  Widget _activeSalePanel() {
    final sale = _activeSale;
    if (sale == null) {
      return const SizedBox.shrink();
    }

    final fulfilment = sale['fulfilment_method']?.toString() == 'delivery'
        ? 'Delivery'
        : 'Pickup';
    final payment = switch (sale['payment_method']?.toString()) {
      'account' => 'Account • ${sale['payment_terms_days'] ?? 0} days',
      'prepaid' => 'Prepaid',
      _ => 'COD',
    };
    final date =
        sale['requested_fulfilment_date']?.toString() ?? 'Date not set';
    final time =
        sale['requested_fulfilment_time']?.toString() ?? 'Time not set';
    final estimate = _saleEstimatedTotal();
    final hasCatchWeight = _activeSaleLines.any(
      (line) => line['catch_weight_snapshot'] == true,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _darkRed.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 3),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _activeSaleMinimized = !_activeSaleMinimized;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4E5E5),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_checkout_outlined,
                      color: _darkRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Open Sale • $_activeSaleCustomerName',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_activeSaleLines.length} item'
                          '${_activeSaleLines.length == 1 ? '' : 's'}'
                          ' • $payment • $fulfilment'
                          ' • $date $time',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _activeSaleMinimized
                        ? 'Expand sale'
                        : 'Minimise sale',
                    onPressed: () {
                      setState(() {
                        _activeSaleMinimized = !_activeSaleMinimized;
                      });
                    },
                    icon: Icon(
                      _activeSaleMinimized
                          ? Icons.expand_more
                          : Icons.expand_less,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_activeSaleMinimized) ...[
            const Divider(height: 1),
            if (_activeSaleLines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No products added yet. Use Add to Sale from the '
                  'inventory on the right.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              for (var index = 0; index < _activeSaleLines.length; index++)
                ListTile(
                  dense: true,
                  leading:
                      _activeSaleLines[index]['existing_order_item_id'] != null
                      ? const Tooltip(
                          message: 'Already on this work order',
                          child: Icon(Icons.check_circle, color: Colors.green),
                        )
                      : const Tooltip(
                          message: 'New product',
                          child: Icon(Icons.add_circle, color: _darkRed),
                        ),
                  title: Text(
                    _activeSaleLines[index]['product_name']?.toString() ??
                        'Product',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_activeSaleLines[index]['quantity']} '
                    '${_saleUnitLabel(_activeSaleLines[index]['quantity_unit']?.toString() ?? 'unit')}'
                    ' • ${_money(_activeSaleLines[index]['unit_price'])}'
                    ' / ${_saleBasisLabel(_activeSaleLines[index]['price_basis']?.toString() ?? 'unit')}',
                  ),
                  trailing:
                      _activeSaleLines[index]['existing_order_item_id'] != null
                      ? const Chip(label: Text('Existing'))
                      : Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Edit line',
                              onPressed: () {
                                final productId =
                                    _activeSaleLines[index]['product_id']
                                        ?.toString();

                                if (productId == null) {
                                  return;
                                }

                                unawaited(_editSaleProduct(productId));
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Remove line',
                              onPressed: () => _removeSaleLine(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PhoneRow(
                mode: PhoneRowMode.wrap,
                desktop: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasCatchWeight
                            ? 'Estimated fixed-price lines: '
                                  '${_money(estimate)} • Catch-weight totals '
                                  'pending weighing'
                            : 'Estimated total: ${_money(estimate)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _closeActiveSale,
                      icon: const Icon(Icons.close),
                      label: const Text('Close Sale'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed:
                          _activeSale?['work_order_order_id'] != null &&
                              _activeSaleRpcItems().isEmpty
                          ? null
                          : _reviewActiveSale,
                      style: FilledButton.styleFrom(backgroundColor: _darkRed),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(
                        _activeSale?['work_order_order_id'] != null
                            ? 'Review Work Order'
                            : 'Review Sale',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _activeSaleRpcItems() {
    return _activeSaleLines
        .where(
          (line) =>
              _activeSale?['work_order_order_id'] == null ||
              line['existing_order_item_id'] == null,
        )
        .map(
          (line) => {
            'product_id': line['product_id'],
            'quantity': line['quantity'],
            'quantity_unit': line['quantity_unit'],
            'unit_price': line['unit_price'],
            'price_basis': line['price_basis'],
            'catch_weight_snapshot': line['catch_weight_snapshot'] == true,
            'notes': line['notes'],
          },
        )
        .toList();
  }

  Future<void> _saveActiveSaleAsQuote() async {
    final sale = _activeSale;

    if (sale == null || _activeSaleLines.isEmpty) {
      return;
    }

    final customerAccountId = sale['supplier_customer_account_id']?.toString();

    if (customerAccountId == null || customerAccountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This sale does not have a valid customer account.'),
        ),
      );
      return;
    }

    final creditApproved = await _confirmCreditLimitForActiveSale();

    if (!creditApproved || !mounted) {
      return;
    }

    try {
      final existingQuoteId = sale['quote_order_id']?.toString();

      if (existingQuoteId != null && existingQuoteId.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'update_supplier_sales_desk_quote',
          params: {
            'target_order_id': existingQuoteId,
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': sale['order_source']?.toString() ?? 'manual',
            'p_source_reference': sale['source_reference'],
            'p_customer_reference': sale['customer_reference'],
            'p_delivery_notes':
                (sale['delivery_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['delivery_notes']?.toString().trim(),
            'p_internal_notes':
                (sale['internal_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['internal_notes']?.toString().trim(),
            'p_payment_method': sale['payment_method']?.toString(),
            'p_payment_terms_days':
                (sale['payment_terms_days'] as num?)?.toInt() ?? 0,
            'p_fulfilment_method': sale['fulfilment_method']?.toString(),
            'p_requested_fulfilment_date': sale['requested_fulfilment_date']
                ?.toString(),
            'p_delivery_fee': (sale['delivery_fee'] as num?)?.toDouble() ?? 0,
            'p_items': _activeSaleRpcItems(),
          },
        );
      } else {
        await Supabase.instance.client.rpc(
          'create_supplier_sales_desk_quote',
          params: {
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': 'manual',
            'p_source_reference': null,
            'p_customer_reference': null,
            'p_delivery_notes':
                (sale['delivery_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['delivery_notes']?.toString().trim(),
            'p_internal_notes':
                (sale['internal_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['internal_notes']?.toString().trim(),
            'p_payment_method': sale['payment_method']?.toString(),
            'p_payment_terms_days':
                (sale['payment_terms_days'] as num?)?.toInt() ?? 0,
            'p_fulfilment_method': sale['fulfilment_method']?.toString(),
            'p_requested_fulfilment_date': sale['requested_fulfilment_date']
                ?.toString(),
            'p_requested_fulfilment_time': sale['requested_fulfilment_time']
                ?.toString(),
            'p_delivery_fee': 0,
            'p_items': _activeSaleRpcItems(),
          },
        );
      }

      if (!mounted) {
        return;
      }

      final customerName = _activeSaleCustomerName;
      final wasExisting = sale['quote_order_id']?.toString().isNotEmpty == true;

      _closeActiveSale();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasExisting
                ? 'Quote updated for $customerName.'
                : 'Quote saved for $customerName.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<bool> _confirmCreditLimitForActiveSale() async {
    final sale = _activeSale;
    if (sale == null) {
      return true;
    }

    final accountId = sale['supplier_customer_account_id']?.toString();

    if (accountId == null || accountId.isEmpty) {
      return true;
    }

    final paymentMethod = sale['payment_method']?.toString();

    // Credit-limit warnings apply to account sales.
    if (paymentMethod != 'account') {
      return true;
    }

    final deliveryFee = sale['delivery_fee'] is num
        ? (sale['delivery_fee'] as num).toDouble()
        : double.tryParse('${sale['delivery_fee']}') ?? 0;

    final proposedKnownAmount = _saleEstimatedTotal() + deliveryFee;

    try {
      final raw = await Supabase.instance.client.rpc(
        'check_supplier_customer_credit_limit',
        params: {
          'target_supplier_customer_account_id': accountId,
          'proposed_amount': proposedKnownAmount,
        },
      );

      final rows = raw is List ? raw : const [];
      if (rows.isEmpty || rows.first is! Map) {
        return true;
      }

      final check = Map<String, dynamic>.from(rows.first as Map);

      if (check['over_limit'] != true) {
        return true;
      }

      final creditLimit = _asDouble(check['credit_limit']);
      final currentExposure = _asDouble(check['current_credit_exposure']);
      final projected = _asDouble(check['projected_credit_exposure']);
      final overBy = _asDouble(check['over_limit_by']);

      if (!mounted) {
        return false;
      }

      final hasCatchWeight = _activeSaleLines.any(
        (line) => line['catch_weight_snapshot'] == true,
      );

      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
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
                            color: const Color(0xFFFFF1E3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFB85C00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Credit Limit Warning',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'This sale would take the customer '
                                'over their approved account limit.',
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 12,
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
                      ),
                      child: Column(
                        children: [
                          _creditLimitRow('Customer', _activeSaleCustomerName),
                          const SizedBox(height: 8),
                          _creditLimitRow('Credit limit', _money(creditLimit)),
                          const SizedBox(height: 8),
                          _creditLimitRow(
                            'Current exposure',
                            _money(currentExposure),
                          ),
                          const SizedBox(height: 8),
                          _creditLimitRow(
                            'This sale',
                            _money(proposedKnownAmount),
                          ),
                          const Divider(height: 20),
                          _creditLimitRow(
                            'Projected exposure',
                            _money(projected),
                            strong: true,
                          ),
                          const SizedBox(height: 8),
                          _creditLimitRow(
                            'Over limit by',
                            _money(overBy),
                            strong: true,
                            warning: true,
                          ),
                        ],
                      ),
                    ),
                    if (hasCatchWeight) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'This order contains catch-weight items. '
                        'The final invoice value may be higher after '
                        'actual weights are entered, so the credit '
                        'limit will be checked again when the invoice '
                        'is issued.',
                        style: TextStyle(
                          color: Color(0xFF8A5600),
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Go Back'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _darkRed,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Continue Anyway'),
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

      return proceed == true;
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  Widget _creditLimitRow(
    String label,
    String value, {
    bool strong = false,
    bool warning = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF666666),
              fontSize: 11.5,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: warning ? const Color(0xFFB3261E) : const Color(0xFF222222),
            fontSize: strong ? 13 : 12,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void> _createWorkOrderFromActiveSale() async {
    final sale = _activeSale;

    if (sale == null || _activeSaleRpcItems().isEmpty) {
      return;
    }

    final customerAccountId = sale['supplier_customer_account_id']?.toString();

    if (customerAccountId == null || customerAccountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This sale does not have a valid customer account.'),
        ),
      );
      return;
    }

    try {
      final existingWorkOrderOrderId = sale['work_order_order_id']?.toString();
      if (existingWorkOrderOrderId != null &&
          existingWorkOrderOrderId.isNotEmpty) {
        final newItems = _activeSaleRpcItems();
        final addedRaw = await Supabase.instance.client.rpc(
          'add_supplier_work_order_items',
          params: {
            'target_order_id': existingWorkOrderOrderId,
            'p_items': newItems,
          },
        );

        if (!mounted) {
          return;
        }

        final added = (addedRaw as num?)?.toInt() ?? newItems.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$added product${added == 1 ? '' : 's'} added to the work order.',
            ),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }

      final existingQuoteId = sale['quote_order_id']?.toString();
      late String orderId;

      if (existingQuoteId != null && existingQuoteId.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'update_supplier_sales_desk_quote',
          params: {
            'target_order_id': existingQuoteId,
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': sale['order_source']?.toString() ?? 'manual',
            'p_source_reference': sale['source_reference'],
            'p_customer_reference': sale['customer_reference'],
            'p_delivery_notes':
                (sale['delivery_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['delivery_notes']?.toString().trim(),
            'p_internal_notes':
                (sale['internal_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['internal_notes']?.toString().trim(),
            'p_payment_method': sale['payment_method']?.toString(),
            'p_payment_terms_days':
                (sale['payment_terms_days'] as num?)?.toInt() ?? 0,
            'p_fulfilment_method': sale['fulfilment_method']?.toString(),
            'p_requested_fulfilment_date': sale['requested_fulfilment_date']
                ?.toString(),
            'p_delivery_fee': (sale['delivery_fee'] as num?)?.toDouble() ?? 0,
            'p_items': _activeSaleRpcItems(),
          },
        );

        await Supabase.instance.client.rpc(
          'convert_supplier_quote_to_sales_order',
          params: {'target_order_id': existingQuoteId},
        );

        orderId = existingQuoteId;
      } else {
        final orderIdRaw = await Supabase.instance.client.rpc(
          'create_supplier_sales_desk_order',
          params: {
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': 'manual',
            'p_source_reference': null,
            'p_customer_reference': null,
            'p_delivery_notes':
                (sale['delivery_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['delivery_notes']?.toString().trim(),
            'p_internal_notes':
                (sale['internal_notes']?.toString().trim().isEmpty ?? true)
                ? null
                : sale['internal_notes']?.toString().trim(),
            'p_payment_method': sale['payment_method']?.toString(),
            'p_payment_terms_days':
                (sale['payment_terms_days'] as num?)?.toInt() ?? 0,
            'p_fulfilment_method': sale['fulfilment_method']?.toString(),
            'p_requested_fulfilment_date': sale['requested_fulfilment_date']
                ?.toString(),
            'p_requested_fulfilment_time': sale['requested_fulfilment_time']
                ?.toString(),
            'p_delivery_fee': 0,
            'p_items': _activeSaleRpcItems(),
          },
        );

        orderId = orderIdRaw.toString();
      }

      await Supabase.instance.client.rpc(
        'create_or_get_warehouse_work_order',
        params: {'target_order_id': orderId},
      );

      if (!mounted) {
        return;
      }

      final customerName = _activeSaleCustomerName;

      _closeActiveSale();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Work order created for $customerName.')),
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SupplierWorkOrderPage(orderId: orderId),
        ),
      );

      if (mounted) {
        await _loadStock();
      }
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _reviewActiveSale() async {
    final sale = _activeSale;

    if (sale == null || _activeSaleLines.isEmpty) {
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final payment = switch (sale['payment_method']?.toString()) {
          'account' => 'Account • ${sale['payment_terms_days'] ?? 0} days',
          'prepaid' => 'Prepaid',
          _ => 'COD',
        };

        final fulfilment = sale['fulfilment_method']?.toString() == 'delivery'
            ? 'Delivery'
            : 'Pickup';

        final date = sale['requested_fulfilment_date']?.toString() ?? 'Not set';
        final time = sale['requested_fulfilment_time']?.toString() ?? 'Not set';

        final isQuote = sale['quote_order_id'] != null;
        final isWorkOrderAddition = sale['work_order_order_id'] != null;
        final quoteNumber = sale['quote_number']?.toString();
        final revision = (sale['quote_revision'] as num?)?.toInt() ?? 0;
        final documentLabel = isQuote
            ? [
                if (quoteNumber != null && quoteNumber.isNotEmpty) quoteNumber,
                if (revision > 0) 'R$revision',
              ].join(' ')
            : 'New Sale';

        final customer = sale['customer'];
        final customerMap = customer is Map
            ? Map<String, dynamic>.from(customer)
            : <String, dynamic>{};

        final customerPhone = customerMap['phone']?.toString().trim() ?? '';
        final customerEmail = customerMap['email']?.toString().trim() ?? '';
        final deliveryAddress =
            sale['delivery_address']?.toString().trim() ?? '';

        Widget panel({
          required String title,
          required IconData icon,
          required List<Widget> children,
        }) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: _darkRed),
                    const SizedBox(width: 7),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          );
        }

        Widget customerPanel() {
          return panel(
            title: 'Customer',
            icon: Icons.business_outlined,
            children: [
              _reviewInfo('Business', _activeSaleCustomerName),
              if (customerPhone.isNotEmpty) _reviewInfo('Phone', customerPhone),
              if (customerEmail.isNotEmpty) _reviewInfo('Email', customerEmail),
              if (deliveryAddress.isNotEmpty)
                _reviewInfo('Delivery address', deliveryAddress),
            ],
          );
        }

        Widget summaryPanel() {
          return panel(
            title: isQuote
                ? 'Quote Summary'
                : isWorkOrderAddition
                ? 'Work Order Addition'
                : 'Sale Summary',
            icon: isQuote
                ? Icons.description_outlined
                : Icons.point_of_sale_outlined,
            children: [
              _reviewInfo(
                isQuote
                    ? 'Quote'
                    : isWorkOrderAddition
                    ? 'Work order'
                    : 'Document',
                isWorkOrderAddition
                    ? sale['order_number']?.toString() ?? 'Work order'
                    : documentLabel,
              ),
              _reviewInfo('Payment', payment),
              _reviewInfo('Fulfilment', fulfilment),
              _reviewInfo('Requested date', date),
              _reviewInfo('Requested time', time),
            ],
          );
        }

        Widget itemsPanel() {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _activeSaleLines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final line = _activeSaleLines[index];
                      final catchWeight = line['catch_weight_snapshot'] == true;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE6E6E2)),
                        ),
                        child: PhoneRow(
                          mode: PhoneRowMode.wrap,
                          desktop: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  line['product_name']?.toString() ?? 'Product',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${line['quantity']} '
                                  '${_saleUnitLabel(line['quantity_unit']?.toString() ?? 'unit')}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${_money(line['unit_price'])}'
                                  ' / ${_saleBasisLabel(line['price_basis']?.toString() ?? 'unit')}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (catchWeight) ...[
                                const SizedBox(width: 10),
                                const Tooltip(
                                  message:
                                      'Final total pending warehouse weight',
                                  child: Icon(
                                    Icons.scale_outlined,
                                    size: 17,
                                    color: _darkRed,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        Widget totalsActionsPanel() {
          final hasCatchWeight = _activeSaleLines.any(
            (line) => line['catch_weight_snapshot'] == true,
          );

          final quoteButton = OutlinedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop('quote'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.description_outlined),
            label: Text(isQuote ? 'Save Quote Revision' : 'Save as Quote'),
          );

          final workOrderButton = FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop('work_order'),
            style: FilledButton.styleFrom(
              backgroundColor: _darkRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.assignment_outlined),
            label: Text(
              isWorkOrderAddition ? 'Add to Work Order' : 'Create Work Order',
            ),
          );

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Totals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  hasCatchWeight
                      ? _money(_saleEstimatedTotal())
                      : _money(_saleEstimatedTotal()),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _darkRed,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hasCatchWeight
                      ? 'Fixed-price items only. Catch-weight totals are finalised after weighing.'
                      : 'Estimated total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                if (!isWorkOrderAddition) ...[
                  quoteButton,
                  const SizedBox(height: 9),
                ],
                workOrderButton,
              ],
            ),
          );
        }

        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F5),
            appBar: phoneAppBar(
              context,
              AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                leading: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
                title: Text(
                  isQuote
                      ? 'Quote • $documentLabel'
                      : isWorkOrderAddition
                      ? 'Add to Work Order • ${sale['order_number'] ?? ''}'
                      : 'Review Sale • $_activeSaleCustomerName',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 900;

                if (!desktop) {
                  return ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      customerPanel(),
                      const SizedBox(height: 10),
                      summaryPanel(),
                      const SizedBox(height: 10),
                      SizedBox(height: 420, child: itemsPanel()),
                      const SizedBox(height: 10),
                      SizedBox(height: 270, child: totalsActionsPanel()),
                    ],
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: customerPanel()),
                              const SizedBox(width: 12),
                              Expanded(child: summaryPanel()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: itemsPanel()),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 350,
                                  child: totalsActionsPanel(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    if (choice == 'quote') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => phoneDialog(
          context,
          AlertDialog(
            title: const Text('Save Quote?'),
            content: Text(
              'Save this sale as a quote for $_activeSaleCustomerName? '
              'It will remain editable as a quote and will not enter the warehouse.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                child: const Text('Save Quote'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && mounted) {
        await _saveActiveSaleAsQuote();
      }

      return;
    }

    if (choice == 'work_order') {
      final addingToWorkOrder = sale['work_order_order_id'] != null;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => phoneDialog(
          context,
          AlertDialog(
            title: Text(
              addingToWorkOrder ? 'Add Products?' : 'Create Work Order?',
            ),
            content: Text(
              addingToWorkOrder
                  ? 'Add the new products to ${sale['order_number'] ?? 'this work order'}? Existing products and order details will remain unchanged.'
                  : 'Confirm this sale for $_activeSaleCustomerName and send it to the warehouse for picking and weighing? Agreed rates will be locked.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: _darkRed),
                child: Text(
                  addingToWorkOrder ? 'Add Products' : 'Create Work Order',
                ),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && mounted) {
        await _createWorkOrderFromActiveSale();
      }
    }
  }

  Widget _reviewInfo(String label, String value) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.3),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuotes() async {
    final quoteOrderId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const SupplierQuotesPage()),
    );

    if (!mounted) {
      return;
    }

    await _loadStock();

    if (quoteOrderId != null && quoteOrderId.isNotEmpty && mounted) {
      await _loadQuoteIntoWorkspace(quoteOrderId);
    }
  }

  Future<void> _openOrders({String? initialTabKey}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierOrdersPage(initialTabKey: initialTabKey),
      ),
    );

    if (mounted) {
      await _loadStock();
    }
  }

  Widget _ordersButton() {
    return OutlinedButton(
      onPressed: () => _openOrders(initialTabKey: 'new'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: Color(0xFFD8D8D4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 18),
          const SizedBox(width: 8),
          const Text('Orders', style: TextStyle(fontWeight: FontWeight.w800)),
          if (_newMarketplaceItemCount > 0) ...[
            const SizedBox(width: 8),
            TweenAnimationBuilder<double>(
              key: ValueKey(_newMarketplaceItemCount),
              tween: Tween<double>(begin: 0.72, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFB3261E),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _newMarketplaceItemCount > 99
                      ? '99+'
                      : _newMarketplaceItemCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compactTopButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: Color(0xFFD8D8D4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
              color: selected ? _darkRed : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _darkRed : const Color(0xFFD9D9D5),
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

  Widget _buildAnimalCutStrip() {
    final catalogue = AnimalCatalogueRegistry.forCode(_selectedAnimalCode);
    if (catalogue == null) {
      return const SizedBox.shrink();
    }

    final regions = catalogue.regionKeys.toList();
    return _arrowScrollStrip(
      controller: _cutScrollController,
      height: 38,
      children: [
        _thinChoice(
          label: 'All cuts',
          selected: _selectedAnimalRegionKey == null,
          onTap: _clearAnimalRegion,
        ),
        for (final region in regions)
          _thinChoice(
            label: catalogue.regionLabel(region),
            selected: _selectedAnimalRegionKey == region,
            onTap: () => _selectAnimalRegion(region),
          ),
      ],
    );
  }

  Widget _buildAnimalSubcutStrip() {
    final specifications = _availableSpecifications;
    if (specifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return _arrowScrollStrip(
      controller: _subcategoryScrollController,
      height: 38,
      children: [
        _thinChoice(
          label: 'All sub-cuts',
          selected: _selectedSpecificationId == null,
          onTap: () {
            _changeStockFilters(() {
              _resetStockFilters();
              _selectedSpecificationId = null;
              _selectedGradeId = null;
            });
          },
        ),
        for (final specification in specifications)
          _thinChoice(
            label: specification['name'] ?? 'Sub-cut',
            selected: _selectedSpecificationId == specification['id'],
            onTap: () {
              _changeStockFilters(() {
                _resetStockFilters();
                _selectedSpecificationId = specification['id'];
                _selectedGradeId = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildFinalSpecificationStrip() {
    final usesGradeStage =
        AnimalCatalogueRegistry.forCode(_selectedAnimalCode)?.usesGradeStage ??
        true;

    if (usesGradeStage) {
      final grades = _availableGrades;
      if (grades.isEmpty) {
        return const SizedBox.shrink();
      }

      return _arrowScrollStrip(
        controller: _finalSpecificationScrollController,
        height: 45,
        children: [
          _thinChoice(
            label: 'All grades',
            selected: _selectedGradeId == null,
            onTap: () {
              _changeStockFilters(() {
                _selectedGradeId = null;
              });
            },
          ),
          for (final grade in grades)
            _thinChoice(
              label: (grade['code'] ?? grade['name'] ?? 'Grade').toString(),
              selected: _selectedGradeId == grade['id'],
              onTap: () {
                _changeStockFilters(() {
                  _selectedGradeId = grade['id'];
                });
              },
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String _salesProductSummary(Map<String, dynamic> product) => [
    productSizeLabel(product),
    product['brand']?.toString() ?? '',
    product['breed_program']?.toString() ?? '',
    productMarblingLabel(product['marbling_score']),
    product['production_claim']?.toString().replaceAll('_', ' ') ?? '',
    if (product['feeding_days'] != null) '${product['feeding_days']}D',
    if (product['rib_count'] != null) '${product['rib_count']}R',
    if (product['hgp_free'] == true) 'HGP Free',
    if (_isChickenProduct(product)) _chickenVariationLabel(product),
    product['bone_state']?.toString().replaceAll('_', ' ') ?? '',
    product['packaging_type']?.toString().replaceAll('_', ' ') ?? '',
    LambProductDetails.fatClass(product),
    LambProductDetails.commercialDescription(product),
  ].where((value) => value.trim().isNotEmpty).toSet().join(' • ');

  Future<void> _openSalesProductInfo(Map<String, dynamic> product) async {
    final fields = <String, String>{
      'Animal': _productAnimalCode(product) ?? 'Not specified',
      'Main cut':
          _nestedMap(product['meat_sections'])?['name']?.toString() ?? '',
      'Sub-cut': _specificationName(product),
      'Grade / category': <String>{
        _gradeCode(product),
        _gradeName(product),
      }.join(' • '),
      'SKU': product['sku']?.toString() ?? '',
      'Brand': product['brand']?.toString() ?? '',
      'Size per piece': productSizeLabel(product),
      'Program': productProgram(product),
      'Commercial description': LambProductDetails.commercialDescription(
        product,
      ),
      'Fat Class': LambProductDetails.fatClass(product),
      'Marbling': product['marbling_score']?.toString() ?? '',
      'Feeding / production':
          product['production_claim']?.toString().replaceAll('_', ' ') ?? '',
      'Feeding days': product['feeding_days']?.toString() ?? '',
      'Rib count': product['rib_count']?.toString() ?? '',
      'HGP free': product['hgp_free'] == true ? 'Yes • Supplier declared' : '',
      'Temperature': product['temperature_state']?.toString() ?? '',
      'Halal': product['halal_status'] == 'halal'
          ? 'Halal • Supplier declared'
          : product['halal_status'] == 'not_halal'
          ? 'Not Halal'
          : 'Not specified',
      'Stock': _quantityLabel(product),
      'Availability': _availabilityLabel(
        product['availability_status']?.toString(),
      ),
      'Ordering unit': product['order_unit']?.toString() ?? '',
      'Weight': _isCatchWeight(product)
          ? 'Catch weight • Final actual weight applies'
          : 'Fixed weight / quantity',
      for (final entry in const {
        'bone_state': 'Bone',
        'packaging_type': 'Packaging',
        'pieces_per_carton': 'Pieces per carton',
        'chicken_skin': 'Skin',
        'chicken_bone': 'Chicken bone',
        'chicken_production_type': 'Production',
        'chicken_preparation': 'Preparation',
        'chicken_carton_size': 'Chicken carton size',
      }.entries)
        entry.value: product[entry.key]?.toString().replaceAll('_', ' ') ?? '',
      'Carton weight': product['carton_weight'] == null
          ? ''
          : '${product['carton_weight']} ${product['carton_weight_unit'] ?? 'kg'}',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LambProductDetails.title(
                          product,
                          _specificationName(product),
                        ),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close information',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CatalogueProductImage(
                          product: product,
                          imageHeight: 230,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final entry in fields.entries.where(
                                (e) => e.value.trim().isNotEmpty,
                              ))
                                SizedBox(
                                  width: constraints.maxWidth < 480
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 24) / 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6D7177),
                                        ),
                                      ),
                                      SelectableText(
                                        entry.value,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if ((product['supplier_specification']
                                    ?.toString()
                                    .trim() ??
                                '')
                            .isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Supplier specification',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          SelectableText(
                            product['supplier_specification'].toString(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Use Add to Sale to choose quantity and confirm the customer rate.',
                          style: TextStyle(color: Color(0xFF6D7177)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final price = _standardPrice(product)?['amount'];
    final available =
        product['availability_status']?.toString() != 'out_of_stock';
    final summary = _salesProductSummary(product);
    final grade = [_gradeCode(product), _gradeName(product)]
        .where((value) => value.isNotEmpty && value != '—' && value != 'LAMB')
        .toSet()
        .join(' • ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      color: available ? Colors.white : const Color(0xFFFAFAF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3E5E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 650;
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatalogueProductImage(
                  product: product,
                  thumbnail: true,
                  imageWidth: narrow ? 96 : 136,
                  imageHeight: narrow ? 96 : 136,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            LambProductDetails.title(
                              product,
                              _specificationName(product),
                            ),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (grade.isNotEmpty)
                            _salesInfoPill(
                              icon: Icons.verified_outlined,
                              label: grade,
                              emphasized: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'SKU ${product['sku'] ?? 'Not set'} • ${product['temperature_state'] ?? 'Not specified'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6D7177),
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _salesInfoPill(
                            icon: Icons.inventory_2_outlined,
                            label: _quantityLabel(product),
                            emphasized: available,
                          ),
                          _salesInfoPill(
                            icon: Icons.check_circle_outline,
                            label: _availabilityLabel(
                              product['availability_status']?.toString(),
                            ),
                          ),
                          if (_isCatchWeight(product))
                            _salesInfoPill(
                              icon: Icons.scale_outlined,
                              label: 'Catch weight',
                            ),
                          if (product['halal_status'] == 'halal')
                            _salesInfoPill(
                              icon: Icons.verified_outlined,
                              label: 'Halal • Supplier declared',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Column(
              crossAxisAlignment: narrow
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                const Text(
                  'STANDARD PRICE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF777777),
                  ),
                ),
                Text(
                  price == null
                      ? 'Price not set'
                      : '${_money(price)} / ${_basisLabel(product)}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openSalesProductInfo(product),
                      icon: const Icon(Icons.info_outline, size: 17),
                      label: const Text('Info'),
                    ),
                    FilledButton.icon(
                      onPressed: available
                          ? () => _handleAddToSale(product)
                          : null,
                      style: FilledButton.styleFrom(backgroundColor: _darkRed),
                      icon: const Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 17,
                      ),
                      label: const Text('Add to Sale'),
                    ),
                  ],
                ),
              ],
            );
            return narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [identity, const SizedBox(height: 10), actions],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 14),
                      SizedBox(width: 210, child: actions),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _salesInfoPill({
    required IconData icon,
    required String label,
    bool emphasized = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xFFF4E5E5) : const Color(0xFFF4F4F1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: emphasized ? _darkRed : const Color(0xFF666666),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized ? _darkRed : const Color(0xFF5F5F5F),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSalesCatalogue() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ValueListenableBuilder<int>(
        valueListenable: _facetRevision,
        builder: (context, revision, child) => StatefulBuilder(
          builder: (context, updateDialog) => Dialog(
            insetPadding: const EdgeInsets.all(14),
            child: SizedBox(
              width: 1220,
              height: MediaQuery.sizeOf(context).height * .86,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Browse animal catalogue',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
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
                      builder: (context, constraints) {
                        final diagram = InteractiveAnimalBrowser(
                          selectedAnimalCode: _selectedAnimalCode,
                          selectedRegionKey: _selectedAnimalRegionKey,
                          onAnimalChanged: (animal) {
                            _selectAnimal(animal);
                            updateDialog(() {});
                          },
                          onRegionSelected: (region) {
                            _selectAnimalRegion(region);
                            updateDialog(() {});
                          },
                          maxWidth: 850,
                        );
                        final choices = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _selectedAnimalRegionKey == null
                                  ? 'Choose a main cut on the animal'
                                  : _selectedCutLabel(
                                      _selectedAnimalRegionKey!,
                                    ),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final specification
                                in _availableSpecifications)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: OutlinedButton(
                                  onPressed: () {
                                    _changeStockFilters(() {
                                      _resetStockFilters();
                                      _selectedSpecificationId =
                                          specification['id'];
                                      _selectedGradeId = null;
                                    });
                                    Navigator.pop(dialogContext);
                                  },
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        specification['name'] ?? 'Sub-cut',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_availableSpecifications.isEmpty)
                              Text(
                                _facetsLoading
                                    ? 'Loading sub-cuts…'
                                    : _facetError ??
                                          'No sub-cuts available in this section.',
                              ),
                          ],
                        );
                        if (constraints.maxWidth < 800) {
                          return ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              diagram,
                              const SizedBox(height: 12),
                              choices,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: diagram,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 4,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(14),
                                child: choices,
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
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return SalesLoadingProgress(
        key: ValueKey(_stockLoadRequest),
        stage: _loadStage,
        loaded: _loadedStockCount,
        total: _totalStockCount,
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            FilledButton(onPressed: _loadStock, child: const Text('Try again')),
          ],
        ),
      );
    }
    final products = _products;
    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E5E8)),
      ),
      child: child,
    );
    return RefreshIndicator(
      onRefresh: _loadStock,
      child: PhoneStockScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  panel(
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Sales workspace',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _openNewSale(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _darkRed,
                          ),
                          icon: const Icon(
                            Icons.add_shopping_cart_outlined,
                            size: 18,
                          ),
                          label: const Text('New Sale'),
                        ),
                        _compactTopButton(
                          icon: Icons.description_outlined,
                          label: 'Quotes',
                          onTap: _openQuotes,
                        ),
                        _ordersButton(),
                      ],
                    ),
                  ),
                  if (_openSaleCount > 0) _openSalesSwitcher(),
                  if (_activeSale != null) _activeSalePanel(),
                  panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimalCatalogueControls(
                          selectedCode: _selectedAnimalCode,
                          onChanged: _selectAnimal,
                          onBrowse: _openSalesCatalogue,
                        ),
                        const SizedBox(height: 6),
                        _buildAnimalCutStrip(),
                        if (_selectedAnimalRegionKey != null)
                          _buildAnimalSubcutStrip(),
                        if (_selectedSpecificationId != null)
                          _buildFinalSpecificationStrip(),
                      ],
                    ),
                  ),
                  panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              key: _stockHeaderKey,
                              child: const Text(
                                'Your stock',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              _pageLoading
                                  ? 'Searching…'
                                  : '$_stockTotal results',
                              style: const TextStyle(
                                color: _darkRed,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            Widget search(
                              TextEditingController controller,
                              String hint,
                            ) => TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: hint,
                                prefixIcon: const Icon(Icons.search, size: 19),
                                suffixIcon: controller.text.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: controller.clear,
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close, size: 17),
                                      ),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF7F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE3E5E8),
                                  ),
                                ),
                              ),
                            );
                            return constraints.maxWidth < 600
                                ? Column(
                                    children: [
                                      search(
                                        _searchController,
                                        'Search products, brands or specifications…',
                                      ),
                                      const SizedBox(height: 8),
                                      search(
                                        _skuSearchController,
                                        'Search SKU…',
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: search(
                                          _searchController,
                                          'Search products, brands or specifications…',
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 230,
                                        child: search(
                                          _skuSearchController,
                                          'Search SKU…',
                                        ),
                                      ),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 10),
                        _salesStockFilters(),
                        const SizedBox(height: 8),
                        _stockPagination(),
                        if (_pageLoading)
                          const LinearProgressIndicator(minHeight: 3),
                        if (_pageError != null)
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(_pageError!),
                              TextButton(
                                onPressed: () =>
                                    _loadStockPage(offset: _stockOffset),
                                child: const Text('Retry search'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_pageLoading && _pageError == null && products.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    'No matching stock. Adjust your cut, filters or search.',
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCard(products[index]),
                childCount: products.length,
              ),
            ),
          ),
          if (products.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _stockPagination(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _workspaceHeader() {
    return Container(
      height: isPhoneLayout(context) ? null : 62,
      padding: EdgeInsets.symmetric(
        vertical: isPhoneLayout(context) ? 10 : 0,
        horizontal: 22,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EAEA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.point_of_sale_outlined,
              color: _darkRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 1),
                Text(
                  'Direct sales, quotes and active sales workspace',
                  style: TextStyle(
                    color: Color(0xFF74787E),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadStock,
            tooltip: 'Refresh sales workspace',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return PhoneStockScaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        phoneHeader: _workspaceHeader(),
        ready: !_isLoading && _errorMessage == null,
        body: _buildBody(),
      );
    }
    return PhoneStockScaffold(
      ready: !_isLoading && _errorMessage == null,
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: phoneAppBar(
        context,
        AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Sales',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE4E6E8)),
          ),
          actions: [
            IconButton(
              onPressed: _loadStock,
              tooltip: 'Refresh sales workspace',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
