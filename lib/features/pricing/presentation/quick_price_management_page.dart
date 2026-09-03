import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/interactive_animal_browser.dart';
import '../../../shared/widgets/interactive_beef_cuts_map.dart';

class _PendingPriceChange {
  _PendingPriceChange({
    required this.product,
    required this.visibility,
    required this.amountText,
    required this.priceBasis,
    required this.minimumQuantity,
    required this.minimumQuantityUnit,
    this.priceListId,
  });

  final Map<String, dynamic> product;
  final String visibility;
  final String amountText;
  final String priceBasis;
  final double? minimumQuantity;
  final dynamic minimumQuantityUnit;
  String? priceListId;
}

class QuickPriceManagementPage extends StatefulWidget {
  const QuickPriceManagementPage({super.key});

  @override
  State<QuickPriceManagementPage> createState() =>
      _QuickPriceManagementPageState();
}

class _QuickPriceManagementPageState extends State<QuickPriceManagementPage> {
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadPage();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    for (final controller in _inlinePriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPage() async {
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

      final productResponse = await client
          .from('products')
          .select('''
            id,
            sku,
            product_name,
            active,
            order_unit,
            quantity_unit,
            price_basis,
            weight_type,
            catch_weight,
            meat_animal_id,
            meat_section_id,
            meat_specification_id,
            meat_grade_id,
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
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('active', true)
          .order('product_name');

      final priceListResponse = await client
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

      final customerResponse = await client
          .from('supplier_customer_relationships')
          .select('''
            butcher_business_id,
            businesses!supplier_customer_relationships_butcher_business_id_fkey(
              legal_name,
              trading_name
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'approved')
          .order('created_at');

      final products = List<Map<String, dynamic>>.from(productResponse);
      final productIds = products
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      List<Map<String, dynamic>> productPrices = [];
      if (productIds.isNotEmpty) {
        final priceResponse = await client
            .from('product_prices')
            .select('''
              id,
              product_id,
              price_list_id,
              amount,
              price_basis,
              minimum_quantity,
              minimum_quantity_unit,
              active
            ''')
            .inFilter('product_id', productIds);

        productPrices = List<Map<String, dynamic>>.from(priceResponse);
      }

      if (!mounted) return;

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _products = products;
        _priceLists = List<Map<String, dynamic>>.from(priceListResponse);
        _approvedCustomers = List<Map<String, dynamic>>.from(customerResponse);
        _productPrices = productPrices;
        if (_pendingChanges.isEmpty) {
          for (final controller in _inlinePriceControllers.values) {
            controller.dispose();
          }
          _inlinePriceControllers.clear();
        }
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

  Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
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
    return _products.where((product) {
      return _productAnimalCode(product) == _selectedAnimalCode;
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedAnimalSections {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      final section = _nestedMap(product['meat_sections']);
      final id = section?['id']?.toString();
      if (section == null || id == null || id.isEmpty) continue;
      byId[id] = section;
    }

    final result = byId.values.toList();
    result.sort((a, b) {
      final ao = int.tryParse(a['display_order']?.toString() ?? '') ?? 9999;
      final bo = int.tryParse(b['display_order']?.toString() ?? '') ?? 9999;
      if (ao != bo) return ao.compareTo(bo);
      return (a['name']?.toString() ?? '').compareTo(
        b['name']?.toString() ?? '',
      );
    });
    return result;
  }

  List<Map<String, dynamic>> get _availableSpecifications {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (_selectedSectionId != null &&
          product['meat_section_id']?.toString() != _selectedSectionId) {
        continue;
      }

      final specification = _nestedMap(product['meat_specifications']);
      final id = specification?['id']?.toString();
      if (specification == null || id == null || id.isEmpty) continue;
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

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();

    final result = _selectedAnimalProducts.where((product) {
      if (_selectedSectionId != null &&
          product['meat_section_id']?.toString() != _selectedSectionId) {
        return false;
      }

      if (_selectedSpecificationId != null &&
          product['meat_specification_id']?.toString() !=
              _selectedSpecificationId) {
        return false;
      }

      if (search.isEmpty) return true;

      final values = [
        product['product_name'],
        product['sku'],
        _sectionName(product),
        _specificationName(product),
        _gradeCode(product),
        _gradeName(product),
      ];

      return values.any(
        (value) =>
            value != null && value.toString().toLowerCase().contains(search),
      );
    }).toList();

    result.sort((a, b) {
      final specCompare = _specificationName(
        a,
      ).toLowerCase().compareTo(_specificationName(b).toLowerCase());
      if (specCompare != 0) return specCompare;
      return _gradeCode(a).compareTo(_gradeCode(b));
    });

    return result;
  }

  Map<String, dynamic>? _sectionByCode(String code) {
    for (final section in _selectedAnimalSections) {
      if (section['code']?.toString() == code) return section;
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

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) return;

    setState(() {
      _selectedAnimalCode = animalCode;
      _selectedAnimalRegionKey = null;
      _selectedSectionId = null;
      _selectedSpecificationId = null;
      _searchController.clear();
    });
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
      _searchController.clear();
    });
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
      _searchController.clear();
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
    if (raw is! List) return [];

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

      if (trading != null && trading.isNotEmpty) return trading;
      if (legal != null && legal.isNotEmpty) return legal;
    }

    return 'Customer';
  }

  String _basisLabel(String? value) => switch (value) {
    'kilogram' => 'kg',
    'carton' => 'carton',
    'unit' => 'unit',
    _ => 'kg',
  };

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) return 'Not set';

    final parts = number.toStringAsFixed(2).split('.');
    final digits = parts.first;
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    return '\$${buffer.toString()}.${parts.last}';
  }

  Future<Map<String, dynamic>> _ensurePriceList({
    required String visibility,
    required String defaultName,
  }) async {
    final existing = _firstPriceListForVisibility(visibility);
    if (existing != null) return existing;

    final supplierId = _supplierBusinessId;
    if (supplierId == null) {
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
        .select('''
          id,
          supplier_business_id,
          name,
          visibility,
          active
        ''')
        .single();

    return Map<String, dynamic>.from(inserted);
  }

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

  void _queueDialogPrice({
    required Map<String, dynamic> product,
    required Map<String, dynamic> priceList,
    required String amountText,
    required String basis,
    required double? minimum,
  }) {
    final productId = product['id'].toString();
    final listId = priceList['id'].toString();
    final key = _changeKey(productId, 'private', listId);
    final catchWeight = _isCatchWeight(product);

    setState(() {
      _pendingChanges[key] = _PendingPriceChange(
        product: product,
        visibility: 'private',
        priceListId: listId,
        amountText: amountText.trim(),
        priceBasis: catchWeight ? 'kilogram' : basis,
        minimumQuantity: minimum,
        minimumQuantityUnit: catchWeight ? 'carton' : product['order_unit'],
      );
    });
  }

  Future<void> _saveAllChanges() async {
    if (_pendingChanges.isEmpty || _isSavingChanges) return;

    final changes = _pendingChanges.values.toList();
    for (final change in changes) {
      final amount = double.tryParse(change.amountText);
      if (amount == null || amount < 0) {
        _message('Enter a valid price for ${change.product['product_name']}.');
        return;
      }
    }

    setState(() => _isSavingChanges = true);

    try {
      for (final change in changes) {
        if (change.priceListId != null) continue;
        final list = await _ensurePriceList(
          visibility: change.visibility,
          defaultName: change.visibility == 'public'
              ? 'Standard Pricing'
              : 'Trade Pricing',
        );
        change.priceListId = list['id']?.toString();
      }

      final now = DateTime.now().toIso8601String();
      await Supabase.instance.client.from('product_prices').upsert(
        [
          for (final change in changes)
            {
              'price_list_id': change.priceListId,
              'product_id': change.product['id'].toString(),
              'amount': double.parse(change.amountText),
              'price_basis': change.priceBasis,
              'minimum_quantity': change.minimumQuantity,
              'minimum_quantity_unit': change.minimumQuantityUnit,
              'active': true,
              'updated_at': now,
            },
        ],
        onConflict: 'price_list_id,product_id',
      );

      if (!mounted) return;
      final count = changes.length;
      setState(() {
        _pendingChanges.clear();
        _isSavingChanges = false;
      });
      await _loadPage();
      _message('$count price change${count == 1 ? '' : 's'} saved.');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _isSavingChanges = false);
      _message(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingChanges = false);
      _message(error.toString());
    }
  }

  Future<void> _openPriceDialog({
    required Map<String, dynamic> product,
    required Map<String, dynamic> priceList,
    required Map<String, dynamic>? existingPrice,
    required String title,
  }) async {
    final productId = product['id']?.toString();
    final priceListId = priceList['id']?.toString();
    if (productId == null || priceListId == null) return;
    final pending =
        _pendingChanges[_changeKey(productId, 'private', priceListId)];

    final catchWeight = _isCatchWeight(product);
    final initialBasis = catchWeight
        ? 'kilogram'
        : pending?.priceBasis ??
              existingPrice?['price_basis']?.toString() ??
              product['price_basis']?.toString() ??
              'unit';

    final amountController = TextEditingController(
      text: pending?.amountText ?? existingPrice?['amount']?.toString() ?? '',
    );
    final minimumController = TextEditingController(
      text: pending?.minimumQuantity?.toString() ??
          existingPrice?['minimum_quantity']?.toString() ??
          '',
    );

    var basis = ['kilogram', 'carton', 'unit'].contains(initialBasis)
        ? initialBasis
        : 'unit';

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final amount = double.tryParse(amountController.text.trim());

              if (amount == null || amount < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid price.')),
                );
                return;
              }

              final minimumText = minimumController.text.trim();
              double? minimum;

              if (minimumText.isNotEmpty) {
                if (catchWeight) {
                  final whole = int.tryParse(minimumText);
                  if (whole == null || whole <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Minimum cartons must be a whole number greater than 0.',
                        ),
                      ),
                    );
                    return;
                  }
                  minimum = whole.toDouble();
                } else {
                  minimum = double.tryParse(minimumText);
                  if (minimum == null || minimum <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Minimum quantity must be greater than 0.',
                        ),
                      ),
                    );
                    return;
                  }
                }
              }

              _queueDialogPrice(
                product: product,
                priceList: priceList,
                amountText: amountController.text,
                basis: basis,
                minimum: minimum,
              );

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            }

            return AlertDialog(
              title: Text('$title • ${product['product_name'] ?? 'Product'}'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        switch (priceList['visibility']?.toString()) {
                          'public' =>
                            'Standard Price: normal marketplace price.',
                          'approved_customers' =>
                            'Trade Price: shown to approved supplier customers.',
                          'private' =>
                            'Customer-Specific Price: only for this selected customer.',
                          _ => '',
                        },
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Price inc GST',
                        prefixText: '\$ ',
                        suffixText:
                            '/ ${catchWeight ? 'kg' : _basisLabel(basis)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!catchWeight)
                      DropdownButtonFormField<String>(
                        initialValue: basis,
                        decoration: const InputDecoration(
                          labelText: 'Price basis',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'kilogram',
                            child: Text('Per kilogram'),
                          ),
                          DropdownMenuItem(
                            value: 'carton',
                            child: Text('Per carton'),
                          ),
                          DropdownMenuItem(
                            value: 'unit',
                            child: Text('Per unit'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => basis = value);
                          }
                        },
                      ),
                    if (!catchWeight) const SizedBox(height: 16),
                    TextField(
                      controller: minimumController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: !catchWeight,
                      ),
                      inputFormatters: catchWeight
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      decoration: InputDecoration(
                        labelText: catchWeight
                            ? 'Minimum order (optional)'
                            : 'Minimum quantity (optional)',
                        suffixText: catchWeight ? 'cartons' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (catchWeight) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Catch-weight products are ordered by whole cartons and charged per kg after the actual weight is known.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  onPressed: save,
                  child: const Text('Add to changes'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    minimumController.dispose();

    if (saved == true && mounted) setState(() {});
  }

  Future<void> _manageCustomerPrices(Map<String, dynamic> product) async {
    if (_approvedCustomers.isEmpty) {
      _message('There are no approved butcher customers yet.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer-Specific Prices',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product['product_name']?.toString() ??
                                      'Product',
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
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
                      child: ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: _approvedCustomers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final customer = _approvedCustomers[index];
                          final customerId = customer['butcher_business_id']
                              ?.toString();

                          final priceList = customerId == null
                              ? null
                              : _privatePriceListForCustomer(customerId);

                          final price = priceList == null
                              ? null
                              : _priceForProductAndList(
                                  product['id'].toString(),
                                  priceList['id'].toString(),
                                );

                          return Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E2DE),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _customerName(customer),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        price == null
                                            ? 'No special price'
                                            : '${_money(price['amount'])} / ${_basisLabel(price['price_basis']?.toString())} inc GST',
                                        style: TextStyle(
                                          color: price == null
                                              ? const Color(0xFF777777)
                                              : _darkRed,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: customerId == null
                                      ? null
                                      : () async {
                                          try {
                                            var list = priceList;

                                            list ??=
                                                await _createPrivatePriceListForCustomer(
                                                  customer,
                                                );

                                            if (!dialogContext.mounted) {
                                              return;
                                            }

                                            Navigator.of(dialogContext).pop();

                                            await _openPriceDialog(
                                              product: product,
                                              priceList: list,
                                              existingPrice: price,
                                              title:
                                                  'Customer-Specific Price • ${_customerName(customer)}',
                                            );

                                            if (!mounted) return;

                                            await _manageCustomerPrices(
                                              product,
                                            );
                                          } catch (error) {
                                            _message(error.toString());
                                          }
                                        },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: Text(
                                    price == null ? 'Set Price' : 'Change',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _createPrivatePriceListForCustomer(
    Map<String, dynamic> customer,
  ) async {
    final supplierId = _supplierBusinessId;
    final customerId = customer['butcher_business_id']?.toString();

    if (supplierId == null || customerId == null || customerId.isEmpty) {
      throw Exception('Customer could not be identified.');
    }

    final existing = _privatePriceListForCustomer(customerId);
    if (existing != null) return existing;

    final inserted = await Supabase.instance.client
        .from('price_lists')
        .insert({
          'supplier_business_id': supplierId,
          'name': '${_customerName(customer)} - Customer Price',
          'visibility': 'private',
          'active': true,
        })
        .select('''
          id,
          supplier_business_id,
          name,
          visibility,
          active
        ''')
        .single();

    final id = inserted['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Customer-specific price list could not be created.');
    }

    await Supabase.instance.client.from('price_list_customers').insert({
      'price_list_id': id,
      'butcher_business_id': customerId,
    });

    await _loadPage();

    final loaded = _privatePriceListForCustomer(customerId);
    if (loaded == null) {
      throw Exception('Customer-specific price list could not be loaded.');
    }

    return loaded;
  }

  int _specialPriceCountForProduct(String productId) {
    final priceListIds = <String>{};

    for (final customer in _approvedCustomers) {
      final customerId = customer['butcher_business_id']?.toString();
      if (customerId == null) continue;

      final list = _privatePriceListForCustomer(customerId);
      if (list == null) continue;

      final price = _priceForProductAndList(productId, list['id'].toString());

      if (price != null) priceListIds.add(list['id'].toString());
    }

    for (final change in _pendingChanges.values) {
      if (change.visibility == 'private' &&
          change.product['id']?.toString() == productId &&
          change.priceListId != null) {
        priceListIds.add(change.priceListId!);
      }
    }

    return priceListIds.length;
  }

  Widget _buildSectionStrip() {
    final sections = _selectedAnimalSections;
    if (sections.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
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
        ],
      ),
    );
  }

  Widget _buildSpecificationStrip() {
    final specifications = _availableSpecifications;
    if (specifications.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
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
                  color:
                      _selectedSpecificationId ==
                          specification['id']?.toString()
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
        ],
      ),
    );
  }

  Widget _buildQuickPriceProductCard(Map<String, dynamic> product) {
    final gradeCode = _gradeCode(product);
    final gradeName = _gradeName(product);
    final specification = _specificationName(product);

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
                Container(
                  width: 72,
                  constraints: const BoxConstraints(minHeight: 62),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E5E5),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFD7B8B8)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        gradeCode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _darkRed,
                          fontSize: gradeCode.length > 3 ? 20 : 25,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (gradeName.isNotEmpty &&
                          gradeName.toLowerCase() !=
                              gradeCode.toLowerCase()) ...[
                        const SizedBox(height: 4),
                        Text(
                          gradeName,
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        specification,
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
            color: changed
                ? const Color(0xFFE6A04B)
                : const Color(0xFFE3E3DF),
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
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Quick Pricing',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPage,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_pendingChanges.isNotEmpty)
            Positioned(
              right: 20,
              top: 20,
              child: SafeArea(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                    onPressed: _isSavingChanges ? null : _saveAllChanges,
                    icon: _isSavingChanges
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSavingChanges
                          ? 'Saving all changes...'
                          : 'Save all (${_pendingChanges.length})',
                    ),
                  ),
                ),
              ),
            ),
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Find a cut and change its price quickly',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose the animal and cut, or search by cut, subcategory, grade or SKU.',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  InteractiveAnimalBrowser(
                    selectedAnimalCode: _selectedAnimalCode,
                    selectedRegionKey: _selectedAnimalRegionKey,
                    onAnimalChanged: _selectAnimal,
                    onRegionSelected: _selectAnimalRegion,
                    maxWidth: 700,
                  ),
                  const SizedBox(height: 14),
                  _buildSectionStrip(),
                  const SizedBox(height: 8),
                  _buildSpecificationStrip(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search quick pricing',
                      hintText: 'Example: Chuck Roll, YG, Rib Eye or SKU',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 850) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 155,
                        child: _priceHeader(
                          title: 'Standard Price',
                          subtitle: 'Normal marketplace price',
                          icon: Icons.public,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 155,
                        child: _priceHeader(
                          title: 'Trade Price',
                          subtitle: 'Approved customers',
                          icon: Icons.handshake_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 190,
                        child: _priceHeader(
                          title: 'Customer Specific',
                          subtitle: 'Private negotiated prices',
                          icon: Icons.person_outline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            if (products.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 42),
                alignment: Alignment.center,
                child: const Text(
                  'No products match this animal, cut or search.',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              for (final product in products) ...[
                _buildQuickPriceProductCard(product),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}
