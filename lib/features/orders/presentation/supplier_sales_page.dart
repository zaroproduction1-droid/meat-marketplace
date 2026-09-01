import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/cutlink_picker.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';
import '../../../shared/widgets/interactive_beef_cuts_map.dart';
import 'supplier_create_order_page.dart';
import 'supplier_orders_page.dart';
import 'supplier_quotes_page.dart';
import 'supplier_work_order_page.dart';

class SupplierSalesPage extends StatefulWidget {
  const SupplierSalesPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SupplierSalesPage> createState() => _SupplierSalesPageState();
}

class _SupplierSalesPageState extends State<SupplierSalesPage> {
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSpecificationId;
  String? _selectedGradeId;

  final ScrollController _specificationScrollController = ScrollController();

  List<Map<String, dynamic>> _products = [];
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
    _loadStock();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    _specificationScrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final supplierBusinessId = await _resolveSupplierBusinessId();

      final productResponse = await client
          .from('products')
          .select('''
            id,
            sku,
            product_name,
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
            order_unit,
            price_basis,
            weight_type,
            catch_weight,
            meat_animal_id,
            meat_animals(
              id,
              code,
              name
            ),
            meat_section_id,
            meat_sections(
              id,
              code,
              name,
              is_miscellaneous
            ),
            meat_specification_id,
            meat_specifications(
              id,
              name,
              specification_type
            ),
            meat_grade_id,
            meat_grades(
              id,
              code,
              name
            ),
            product_prices(
              id,
              amount,
              price_basis,
              active,
              price_lists(
                id,
                name,
                visibility,
                active
              )
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('active', true)
          .order('product_name');

      final marketplaceResponse = await client
          .from('orders')
          .select('''
            id,
            order_items(id)
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('order_source', 'marketplace')
          .eq('status', 'submitted');

      var marketplaceItemCount = 0;

      for (final raw in marketplaceResponse) {
        final items = raw['order_items'];
        if (items is List) {
          marketplaceItemCount += items.length;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _products = (productResponse as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _newMarketplaceItemCount = marketplaceItemCount;
        _isLoading = false;
      });
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

  List<Map<String, dynamic>> get _animalRegionProducts {
    return _products.where((product) {
      if (_productAnimalCode(product) != _selectedAnimalCode) {
        return false;
      }

      if (_selectedAnimalCode == CutLinkAnimals.beef &&
          _selectedAnimalRegionKey != null &&
          !_productMatchesBeefCut(product, _selectedAnimalRegionKey!)) {
        return false;
      }

      return true;
    }).toList();
  }

  String _specificationId(Map<String, dynamic> product) {
    return product['meat_specification_id']?.toString() ?? '';
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

    if (size.isNotEmpty) values.add(size);
    if (carton.isNotEmpty) values.add(carton);

    return values.isEmpty ? 'Standard Chicken' : values.join(' • ');
  }

  List<Map<String, String>> get _availableSpecifications {
    final byId = <String, String>{};

    for (final product in _animalRegionProducts) {
      if (_selectedGradeId != null &&
          product['meat_grade_id']?.toString() != _selectedGradeId) {
        continue;
      }

      final id = _specificationId(product);
      if (id.isEmpty) continue;
      byId[id] = _specificationName(product);
    }

    final rows = [
      for (final entry in byId.entries) {'id': entry.key, 'name': entry.value},
    ];

    rows.sort(
      (a, b) => (a['name'] ?? '').toLowerCase().compareTo(
        (b['name'] ?? '').toLowerCase(),
      ),
    );

    return rows;
  }

  List<Map<String, String>> get _availableGrades {
    final byId = <String, Map<String, String>>{};

    for (final product in _animalRegionProducts) {
      final gradeId = product['meat_grade_id']?.toString();
      if (gradeId == null || gradeId.isEmpty) continue;

      final code = _gradeCode(product);
      final name = _gradeName(product);

      byId[gradeId] = {'id': gradeId, 'code': code, 'name': name};
    }

    final rows = byId.values.toList();

    rows.sort((a, b) => (a['code'] ?? '').compareTo(b['code'] ?? ''));

    return rows;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();

    final results = _animalRegionProducts.where((product) {
      if (_selectedAnimalCode != CutLinkAnimals.chicken &&
          _selectedGradeId != null &&
          product['meat_grade_id']?.toString() != _selectedGradeId) {
        return false;
      }

      if (_selectedSpecificationId != null &&
          _specificationId(product) != _selectedSpecificationId) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final name = product['product_name']?.toString().toLowerCase() ?? '';
      final sku = product['sku']?.toString().toLowerCase() ?? '';
      final specification = _specificationName(product).toLowerCase();
      final gradeCode = _gradeCode(product).toLowerCase();
      final gradeName = _gradeName(product).toLowerCase();
      final chickenVariation = _isChickenProduct(product)
          ? _chickenVariationLabel(product).toLowerCase()
          : '';
      final brand = product['brand']?.toString().toLowerCase() ?? '';

      return name.contains(search) ||
          sku.contains(search) ||
          specification.contains(search) ||
          brand.contains(search) ||
          chickenVariation.contains(search) ||
          (_selectedAnimalCode != CutLinkAnimals.chicken &&
              (gradeCode.contains(search) || gradeName.contains(search)));
    }).toList();

    results.sort((a, b) {
      final specificationCompare = _specificationName(
        a,
      ).toLowerCase().compareTo(_specificationName(b).toLowerCase());
      if (specificationCompare != 0) return specificationCompare;
      if (_selectedAnimalCode == CutLinkAnimals.chicken) {
        return _chickenVariationLabel(
          a,
        ).toLowerCase().compareTo(_chickenVariationLabel(b).toLowerCase());
      }
      return _gradeCode(a).compareTo(_gradeCode(b));
    });

    return results;
  }

  bool _productMatchesBeefCut(Map<String, dynamic> product, String cutKey) {
    final rawSection = product['meat_sections'];

    if (rawSection is! Map) {
      return false;
    }

    final section = Map<String, dynamic>.from(rawSection);
    final code = section['code']?.toString().trim().toLowerCase() ?? '';
    final name = section['name']?.toString().trim().toLowerCase() ?? '';
    final miscellaneous = section['is_miscellaneous'] == true;

    final aliases = _sectionAliasesForCut(cutKey);

    if (miscellaneous && cutKey == CutLinkBeefCutKeys.miscOffalOther) {
      return true;
    }

    return aliases.contains(code) || aliases.contains(name);
  }

  Set<String> _sectionAliasesForCut(String cutKey) {
    return switch (cutKey) {
      CutLinkBeefCutKeys.cheek => {'cheek', 'misc', 'miscellaneous / offal'},
      CutLinkBeefCutKeys.neck => {'neck'},
      CutLinkBeefCutKeys.shoulder => {'shoulder'},
      CutLinkBeefCutKeys.chuck => {'chuck'},
      CutLinkBeefCutKeys.blade => {'blade', 'chuck'},
      CutLinkBeefCutKeys.brisket => {'brisket'},
      CutLinkBeefCutKeys.shinShank => {
        'shin / shank',
        'shin/shank',
        'shin-shank',
        'shin',
        'shank',
      },
      CutLinkBeefCutKeys.ribs => {'ribs', 'rib'},
      CutLinkBeefCutKeys.ribEye => {'rib eye', 'ribeye', 'rib-eye'},
      CutLinkBeefCutKeys.plate => {'plate', 'short plate'},
      CutLinkBeefCutKeys.skirt => {'skirt'},
      CutLinkBeefCutKeys.loin => {'loin'},
      CutLinkBeefCutKeys.flank => {'flank'},
      CutLinkBeefCutKeys.rump => {'rump'},
      CutLinkBeefCutKeys.round => {
        'round',
        'hind',
        'topside / thick flank / knuckle',
        'topside',
        'thick flank',
        'knuckle',
      },
      CutLinkBeefCutKeys.silversideOutside => {
        'silverside / outside',
        'silverside/outside',
        'silverside-outside',
        'silverside',
        'outside',
      },
      CutLinkBeefCutKeys.oxTail => {
        'ox tail',
        'oxtail',
        'ox-tail',
        'misc',
        'miscellaneous / offal',
      },
      CutLinkBeefCutKeys.miscOffalOther => {
        'misc',
        'miscellaneous / offal',
        'miscellaneous / offal · other',
        'miscellaneous/offal',
        'misc / offal',
        'offal',
      },
      _ => {cutKey.toLowerCase()},
    };
  }

  String _beefCutLabel(String cutKey) {
    return switch (cutKey) {
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
      _ => cutKey,
    };
  }

  String get _selectedAnimalName {
    return CutLinkAnimals.all
        .firstWhere(
          (animal) => animal.code == _selectedAnimalCode,
          orElse: () => CutLinkAnimals.all.first,
        )
        .name;
  }

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) {
      return;
    }

    setState(() {
      _selectedAnimalCode = animalCode;
      _selectedAnimalRegionKey = null;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
      _searchController.clear();
    });
  }

  void _selectAnimalRegion(String regionKey) {
    setState(() {
      _selectedAnimalRegionKey = regionKey;
      _selectedSpecificationId = null;
    });
  }

  void _clearAnimalRegion() {
    if (_selectedAnimalRegionKey == null) {
      return;
    }

    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSpecificationId = null;
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
      (line) => line['product_id']?.toString() == productId,
    );
  }

  Future<void> _addProductToActiveSale(Map<String, dynamic> product) async {
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

            return AlertDialog(
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
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Edit line',
                        onPressed: () {
                          final productId =
                              _activeSaleLines[index]['product_id']?.toString();

                          if (productId == null) return;

                          final product = _products
                              .where(
                                (row) => row['id']?.toString() == productId,
                              )
                              .cast<Map<String, dynamic>?>()
                              .firstWhere(
                                (row) => row != null,
                                orElse: () => null,
                              );

                          if (product != null) {
                            _addProductToActiveSale(product);
                          }
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
              child: Row(
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
                    onPressed: _activeSaleLines.isEmpty
                        ? null
                        : _reviewActiveSale,
                    style: FilledButton.styleFrom(backgroundColor: _darkRed),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Review Sale'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _activeSaleRpcItems() {
    return _activeSaleLines
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
    if (sale == null) return true;

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

      if (!mounted) return false;

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

    try {
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
            title: isQuote ? 'Quote Summary' : 'Sale Summary',
            icon: isQuote
                ? Icons.description_outlined
                : Icons.point_of_sale_outlined,
            children: [
              _reviewInfo(isQuote ? 'Quote' : 'Document', documentLabel),
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
                        child: Row(
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
                                message: 'Final total pending warehouse weight',
                                child: Icon(
                                  Icons.scale_outlined,
                                  size: 17,
                                  color: _darkRed,
                                ),
                              ),
                            ],
                          ],
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
            label: const Text('Create Work Order'),
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
                quoteButton,
                const SizedBox(height: 9),
                workOrderButton,
              ],
            ),
          );
        }

        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F5),
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              leading: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
              title: Text(
                isQuote
                    ? 'Quote • $documentLabel'
                    : 'Review Sale • $_activeSaleCustomerName',
                style: const TextStyle(fontWeight: FontWeight.w900),
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
        builder: (dialogContext) => AlertDialog(
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
      );

      if (confirmed == true && mounted) {
        await _saveActiveSaleAsQuote();
      }

      return;
    }

    if (choice == 'work_order') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Create Work Order?'),
          content: Text(
            'Confirm this sale for $_activeSaleCustomerName and send it to '
            'the warehouse for picking and weighing? Agreed rates will be locked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _darkRed),
              child: const Text('Create Work Order'),
            ),
          ],
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

  Future<void> _scrollSpecifications(double direction) async {
    if (!_specificationScrollController.hasClients) return;

    final position = _specificationScrollController.position;
    final target = (position.pixels + (direction * 280)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _specificationScrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openGradeDropdown(BuildContext buttonContext) async {
    final selected = await showCutLinkPickerDialog<String>(
      context: buttonContext,
      title: 'Grade',
      currentValue: _selectedGradeId,
      searchHint: 'Search grade code or name',
      options: [
        const CutLinkPickerOption<String>(
          value: '__all__',
          label: 'All Grades',
          subtitle: 'Show every grade',
          icon: Icons.layers_outlined,
        ),
        ..._availableGrades.map(
          (grade) => CutLinkPickerOption<String>(
            value: grade['id']?.toString() ?? '',
            label: grade['code']?.toString() ?? 'N/A',
            subtitle: grade['name']?.toString(),
            icon: Icons.workspace_premium_outlined,
          ),
        ),
      ],
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedGradeId = selected == '__all__' ? null : selected;
    });
  }

  String get _selectedGradeLabel {
    final selectedId = _selectedGradeId;
    if (selectedId == null) return 'All Grades';

    for (final grade in _availableGrades) {
      if (grade['id']?.toString() == selectedId) {
        final code = grade['code']?.toString().trim() ?? '';
        final name = grade['name']?.toString().trim() ?? '';
        if (code.isNotEmpty && name.isNotEmpty) return '$code • $name';
        if (code.isNotEmpty) return code;
        if (name.isNotEmpty) return name;
      }
    }

    return 'Selected Grade';
  }

  Widget _buildGradeFilterStrip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Builder(
        builder: (buttonContext) {
          return InkWell(
            onTap: () => _openGradeDropdown(buttonContext),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              constraints: const BoxConstraints(minWidth: 145, maxWidth: 250),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _selectedGradeId == null
                      ? const Color(0xFFD7D7D3)
                      : _darkRed,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 16, color: _darkRed),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      _selectedGradeId == null
                          ? 'All Grades'
                          : _selectedGradeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Color(0xFF555555),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecificationStrip() {
    final specifications = _availableSpecifications;

    if (specifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        IconButton(
          onPressed: () => _scrollSpecifications(-1),
          tooltip: 'Previous cuts',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: SizedBox(
            height: 38,
            child: ListView(
              controller: _specificationScrollController,
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: _selectedSpecificationId == null,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 0,
                    ),
                    side: BorderSide(
                      color: _selectedSpecificationId == null
                          ? _darkRed
                          : const Color(0xFFD9D9D5),
                    ),
                    selectedColor: _darkRed,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: _selectedSpecificationId == null
                          ? Colors.white
                          : const Color(0xFF3E3E3E),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    label: const Text('All'),
                    onSelected: (_) {
                      setState(() => _selectedSpecificationId = null);
                    },
                  ),
                ),
                for (final specification in specifications)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: _selectedSpecificationId == specification['id'],
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 0,
                      ),
                      side: BorderSide(
                        color: _selectedSpecificationId == specification['id']
                            ? _darkRed
                            : const Color(0xFFD9D9D5),
                      ),
                      selectedColor: _darkRed,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _selectedSpecificationId == specification['id']
                            ? Colors.white
                            : const Color(0xFF3E3E3E),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      label: Text(specification['name'] ?? 'Cut'),
                      onSelected: (_) {
                        setState(() {
                          _selectedSpecificationId = specification['id'];
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => _scrollSpecifications(1),
          tooltip: 'Next cuts',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final standardPrice = _standardPrice(product);
    final price = standardPrice?['amount'];
    final catchWeight = _isCatchWeight(product);
    final chicken = _isChickenProduct(product);
    final gradeCode = _gradeCode(product);
    final gradeName = _gradeName(product);
    final specification = _specificationName(product);
    final chickenVariation = chicken ? _chickenVariationLabel(product) : '';
    final availability = _availabilityLabel(
      product['availability_status']?.toString(),
    );
    final available =
        product['availability_status']?.toString() != 'out_of_stock';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: available ? Colors.white : const Color(0xFFFAFAF8),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: available ? const Color(0xFFDEDEDA) : const Color(0xFFE8E8E4),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: available ? () => _handleAddToSale(product) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 620;

              final gradeBadge = Container(
                width: narrow ? (chicken ? 150 : 82) : (chicken ? 190 : 92),
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: available
                      ? const Color(0xFFF4E5E5)
                      : const Color(0xFFF0F0ED),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: available
                        ? const Color(0xFFD7B8B8)
                        : const Color(0xFFD9D9D5),
                  ),
                ),
                child: chicken
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHICKEN',
                            style: TextStyle(
                              color: _darkRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            chickenVariation,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: available
                                  ? _darkRed
                                  : const Color(0xFF777777),
                              fontSize: 11.5,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            gradeCode,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: available
                                  ? _darkRed
                                  : const Color(0xFF777777),
                              fontSize: gradeCode.length > 3 ? 24 : 30,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (gradeName.isNotEmpty &&
                              gradeName.toLowerCase() !=
                                  gradeCode.toLowerCase()) ...[
                            const SizedBox(height: 5),
                            Text(
                              gradeName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 9.5,
                                height: 1.05,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
              );

              final productDetails = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specification,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product['sku']?.toString().trim().isNotEmpty == true
                        ? 'SKU ${product['sku']}'
                        : 'No SKU',
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      _salesInfoPill(
                        icon: Icons.inventory_2_outlined,
                        label: _quantityLabel(product),
                        emphasized: available,
                      ),
                      _salesInfoPill(
                        icon: available
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        label: availability,
                      ),
                      if (catchWeight)
                        _salesInfoPill(
                          icon: Icons.scale_outlined,
                          label: 'Catch weight',
                        ),
                    ],
                  ),
                ],
              );

              final pricing = Column(
                crossAxisAlignment: narrow
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  const Text(
                    'STANDARD',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 9.5,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price == null
                        ? 'Price not set'
                        : '${_money(price)} / ${_basisLabel(product)}',
                    style: TextStyle(
                      color: price == null
                          ? const Color(0xFF777777)
                          : const Color(0xFF202020),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  FilledButton.icon(
                    onPressed: available
                        ? () => _handleAddToSale(product)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkRed,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_shopping_cart_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      'Add to Sale',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        gradeBadge,
                        const SizedBox(width: 11),
                        Expanded(child: productDetails),
                      ],
                    ),
                    const SizedBox(height: 10),
                    pricing,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  gradeBadge,
                  const SizedBox(width: 12),
                  Expanded(child: productDetails),
                  const SizedBox(width: 16),
                  pricing,
                ],
              );
            },
          ),
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
          Text(
            label,
            style: TextStyle(
              color: emphasized ? _darkRed : const Color(0xFF5F5F5F),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
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
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loadStock,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredProducts;

    return RefreshIndicator(
      onRefresh: _loadStock,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE3E5E8)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 760;

                        final titleBlock = Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8EDEE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.point_of_sale_outlined,
                                color: _darkRed,
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sales',
                                    style: TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Create direct sales, manage open sales and quotes, then move live orders into fulfilment.',
                                    style: TextStyle(
                                      color: Color(0xFF666A70),
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final actions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _openNewSale(),
                              style: FilledButton.styleFrom(
                                backgroundColor: _darkRed,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_shopping_cart_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'New Sale',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            _compactTopButton(
                              icon: Icons.description_outlined,
                              label: 'Quotes',
                              onTap: _openQuotes,
                            ),
                            _ordersButton(),
                          ],
                        );

                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titleBlock,
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: actions,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: titleBlock),
                            const SizedBox(width: 18),
                            actions,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_openSaleCount > 0) _openSalesSwitcher(),
                  if (_activeSale != null) _activeSalePanel(),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 940;

                      final cowPanel = Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Browse Stock by Animal',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Choose an animal, then select its cut region to narrow '
                              'the stock shown to the salesperson.',
                              style: TextStyle(color: Color(0xFF666666)),
                            ),
                            const SizedBox(height: 14),
                            InteractiveAnimalBrowser(
                              selectedAnimalCode: _selectedAnimalCode,
                              selectedRegionKey: _selectedAnimalRegionKey,
                              onAnimalChanged: _selectAnimal,
                              onRegionSelected: _selectAnimalRegion,
                              maxWidth: 700,
                            ),
                            if (_selectedAnimalRegionKey != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Selected: ${_beefCutLabel(_selectedAnimalRegionKey!)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: _darkRed,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _clearAnimalRegion,
                                    icon: const Icon(Icons.close),
                                    label: const Text('Show All'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );

                      final inventoryPanel = Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                            const Text(
                              'Search Inventory',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _selectedAnimalCode == CutLinkAnimals.chicken
                                  ? 'Find the Chicken cut, variation or SKU the customer is asking for.'
                                  : 'Find the cut, grade or SKU the customer is asking for.',
                              style: TextStyle(color: Color(0xFF666666)),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    _selectedAnimalCode ==
                                        CutLinkAnimals.chicken
                                    ? 'Search cut, skin, bone, state, brand or SKU'
                                    : 'Search cut, grade or SKU',
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedAnimalCode !=
                                CutLinkAnimals.chicken) ...[
                              _buildGradeFilterStrip(),
                              const SizedBox(height: 10),
                            ],
                            _buildSpecificationStrip(),
                            const SizedBox(height: 12),
                            if (_selectedAnimalRegionKey != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4E5E5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.filter_alt_outlined,
                                      size: 18,
                                      color: _darkRed,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Showing ${_beefCutLabel(_selectedAnimalRegionKey!)}',
                                        style: const TextStyle(
                                          color: _darkRed,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: narrow ? 240 : 430,
                                maxHeight: narrow ? 500 : 560,
                              ),
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 40,
                                        ),
                                        child: Text(
                                          _selectedAnimalRegionKey == null
                                              ? 'No $_selectedAnimalName stock matches your search.'
                                              : 'No stock is currently listed in this region.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Scrollbar(
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        primary: false,
                                        padding: EdgeInsets.zero,
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          return _buildProductCard(
                                            filtered[index],
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            cowPanel,
                            const SizedBox(height: 16),
                            inventoryPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: cowPanel),
                          const SizedBox(width: 18),
                          Expanded(flex: 9, child: inventoryPanel),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceHeader() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 22),
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
      return ColoredBox(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            _workspaceHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
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
      body: _buildBody(),
    );
  }
}
