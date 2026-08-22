import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_product_page.dart';
import 'edit_product_page.dart';
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
            product_prices(
              id,
              amount,
              price_basis,
              active,
              price_lists(id, visibility, active)
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
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

  Future<void> _openAddProductPage({String? sectionId}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddProductPage(
          initialAnimalCode: _selectedAnimalCode,
          initialSectionId: sectionId,
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

  Map<String, dynamic>? _standardPrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List) return null;

    for (final raw in rawPrices) {
      if (raw is! Map) continue;

      final price = Map<String, dynamic>.from(raw);

      if (price['active'] != true) continue;

      final rawList = price['price_lists'];
      if (rawList is! Map) continue;

      final priceList = Map<String, dynamic>.from(rawList);

      if (priceList['active'] == true &&
          priceList['visibility']?.toString() == 'public') {
        return price;
      }
    }

    return null;
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) return 'Not set';

    final parts = number.toStringAsFixed(2).split('.');
    final whole = parts.first;
    final buffer = StringBuffer();

    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(whole[index]);
    }

    return '\$${buffer.toString()}.${parts.last}';
  }

  String _basisLabel(String? value) => switch (value) {
    'kilogram' => 'kg',
    'carton' => 'carton',
    'unit' => 'unit',
    'piece' => 'piece',
    'pack' => 'pack',
    _ => 'kg',
  };

  String _stockLabel(Map<String, dynamic> product) {
    final quantity = product['available_quantity'];
    final unit = product['quantity_unit']?.toString();

    if (quantity == null) {
      return switch (product['availability_status']?.toString()) {
        'in_stock' => 'In stock',
        'limited' => 'Limited stock',
        'out_of_stock' => 'Out of stock',
        'made_to_order' => 'Made to order',
        _ => 'Stock not set',
      };
    }

    final number = quantity is num
        ? quantity.toDouble()
        : double.tryParse(quantity.toString());

    if (number == null) return 'Stock not set';

    final numberText = number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);

    return '$numberText ${unit == 'carton' ? 'cartons' : unit ?? ''}'.trim();
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
                  hintText:
                      'Search cut, specification, category, product name or SKU',
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
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 110),
                  itemCount: _filteredProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1250),
                        child: _buildProductCard(_filteredProducts[index]),
                      ),
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 110),
            sliver: SliverList.separated(
              itemCount: _filteredProducts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1250),
                    child: _buildProductCard(_filteredProducts[index]),
                  ),
                );
              },
            ),
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

  Widget _buildProductCard(Map<String, dynamic> product) {
    final standardPrice = _standardPrice(product);
    final specification = _specificationName(product);
    final category = _gradeName(product);
    final section = _sectionName(product);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E2DE)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openEditProductPage(product),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;

              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['product_name']?.toString() ?? 'Unnamed product',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      section,
                      specification,
                      if (category.isNotEmpty) category,
                    ].join(' • '),
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _smallChip(
                        Icons.qr_code_2_outlined,
                        product['sku']?.toString().trim().isNotEmpty == true
                            ? 'SKU ${product['sku']}'
                            : 'No SKU',
                      ),
                      _smallChip(
                        Icons.inventory_outlined,
                        _stockLabel(product),
                      ),
                      if (product['weight_type']?.toString() ==
                              'catch_weight' ||
                          product['catch_weight'] == true)
                        _smallChip(
                          Icons.monitor_weight_outlined,
                          'Catch weight',
                        ),
                    ],
                  ),
                ],
              );

              final price = Column(
                crossAxisAlignment: narrow
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  const Text(
                    'STANDARD PRICE',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    standardPrice == null
                        ? 'Not set'
                        : '${_money(standardPrice['amount'])} / ${_basisLabel(standardPrice['price_basis']?.toString())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: standardPrice == null
                          ? const Color(0xFF777777)
                          : _darkRed,
                    ),
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const SizedBox(height: 14), price],
                );
              }

              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 18),
                  price,
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _smallChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E1DD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF666666)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF555555),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
