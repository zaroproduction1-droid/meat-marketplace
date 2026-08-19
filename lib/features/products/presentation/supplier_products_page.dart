import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_product_page.dart';
import 'edit_product_page.dart';

class SupplierProductsPage extends StatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  State<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends State<SupplierProductsPage> {
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedSectionId;
  String? _selectedVisualLabel;
  String? _hoveredSectionCode;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _beefSections = [];

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

      final beefAnimal = await client
          .from('meat_animals')
          .select('id')
          .eq('code', 'BEEF')
          .eq('is_active', true)
          .maybeSingle();

      List<Map<String, dynamic>> beefSections = [];

      if (beefAnimal != null) {
        final sectionResponse = await client
            .from('meat_sections')
            .select('id, code, name, is_miscellaneous, display_order')
            .eq('animal_id', beefAnimal['id'])
            .eq('is_active', true)
            .order('display_order');

        beefSections = List<Map<String, dynamic>>.from(sectionResponse);
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
        _beefSections = beefSections;
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

  Future<void> _openAddProductPage() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddProductPage()));

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

  int _sectionProductCount(String sectionId) {
    return _products.where((product) {
      return product['meat_section_id']?.toString() == sectionId;
    }).length;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();

    return _products.where((product) {
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
    for (final section in _beefSections) {
      if (section['code']?.toString() == code) {
        return section;
      }
    }
    return null;
  }

  void _selectSectionCode(String code, {String? visualLabel}) {
    final section = _sectionByCode(code);
    if (section == null) return;

    setState(() {
      final id = section['id'].toString();
      _selectedSectionId = id;
      _selectedVisualLabel = visualLabel ?? section['name']?.toString();
      _searchController.clear();
    });
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedSectionId = section['id'].toString();
      _selectedVisualLabel = section['name']?.toString();
      _searchController.clear();
    });
  }

  void _clearSectionSelection() {
    setState(() {
      _selectedSectionId = null;
      _selectedVisualLabel = null;
      _hoveredSectionCode = null;
    });
  }

  String? get _selectedSectionName {
    final selected = _selectedSectionId;
    if (selected == null) return null;

    for (final section in _beefSections) {
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
          IconButton(
            onPressed: _isLoading ? null : _loadProducts,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProductPage,
        backgroundColor: _darkRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
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
                onChanged: (value) {
                  if (value.trim().isNotEmpty && _selectedSectionId != null) {
                    setState(() {
                      _selectedSectionId = null;
                      _selectedVisualLabel = null;
                    });
                  }
                },
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Browse Beef Stock',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Click anywhere inside a cut section to filter your stock.',
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
                    _buildCowImageBrowser(),
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
                            ? 'All Stock'
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
                child: Text(
                  _selectedSectionName == null
                      ? 'No stock has been added yet.'
                      : 'No ${_selectedSectionName!} stock has been added yet.',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w800,
                  ),
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

  Widget _buildCowImageBrowser() {
    final hotspots = <_CowHotspot>[
      _CowHotspot(
        code: 'NECK',
        label: 'Neck',
        points: const [
          Offset(0.2093, 0.1768),
          Offset(0.2707, 0.1796),
          Offset(0.2645, 0.2302),
          Offset(0.2576, 0.2947),
          Offset(0.2528, 0.3591),
          Offset(0.2279, 0.3913),
          Offset(0.2017, 0.4052),
          Offset(0.1727, 0.3361),
          Offset(0.1865, 0.2947),
          Offset(0.1975, 0.2348),
        ],
      ),
      _CowHotspot(
        code: 'CHUCK',
        label: 'Chuck',
        points: const [
          Offset(0.2707, 0.1796),
          Offset(0.4033, 0.1860),
          Offset(0.4068, 0.2762),
          Offset(0.4075, 0.3683),
          Offset(0.4047, 0.4365),
          Offset(0.3522, 0.4374),
          Offset(0.3039, 0.4190),
          Offset(0.2521, 0.3794),
          Offset(0.2624, 0.2947),
        ],
      ),
      _CowHotspot(
        code: 'BLADE',
        label: 'Blade',
        points: const [
          Offset(0.2521, 0.3794),
          Offset(0.3039, 0.4190),
          Offset(0.3522, 0.4374),
          Offset(0.4047, 0.4365),
          Offset(0.4068, 0.4788),
          Offset(0.3660, 0.4972),
          Offset(0.3142, 0.5110),
          Offset(0.2555, 0.5129),
          Offset(0.2348, 0.4880),
          Offset(0.2175, 0.4098),
        ],
      ),
      _CowHotspot(
        code: 'BRISKET',
        label: 'Brisket',
        points: const [
          Offset(0.2555, 0.5129),
          Offset(0.3142, 0.5110),
          Offset(0.3660, 0.4972),
          Offset(0.4068, 0.4788),
          Offset(0.4006, 0.5525),
          Offset(0.3923, 0.5875),
          Offset(0.3453, 0.5893),
          Offset(0.3073, 0.5801),
          Offset(0.2693, 0.5617),
        ],
      ),
      _CowHotspot(
        code: 'SHANK',
        label: 'Shank',
        points: const [
          Offset(0.3073, 0.5801),
          Offset(0.3453, 0.5893),
          Offset(0.3923, 0.5875),
          Offset(0.3854, 0.6538),
          Offset(0.3785, 0.7274),
          Offset(0.3702, 0.8103),
          Offset(0.3384, 0.8103),
          Offset(0.3315, 0.7182),
          Offset(0.3246, 0.6446),
        ],
      ),
      _CowHotspot(
        code: 'RIB',
        label: 'Rib',
        points: const [
          Offset(0.4033, 0.1860),
          Offset(0.5684, 0.1980),
          Offset(0.5753, 0.2670),
          Offset(0.5780, 0.3500),
          Offset(0.5753, 0.4383),
          Offset(0.5041, 0.4420),
          Offset(0.4351, 0.4466),
          Offset(0.4047, 0.4365),
        ],
      ),
      _CowHotspot(
        code: 'PLATE',
        label: 'Short Plate',
        points: const [
          Offset(0.4047, 0.4365),
          Offset(0.5041, 0.4420),
          Offset(0.5753, 0.4383),
          Offset(0.5732, 0.5157),
          Offset(0.5698, 0.5783),
          Offset(0.4834, 0.5801),
          Offset(0.4040, 0.5847),
          Offset(0.4006, 0.5525),
        ],
      ),
      _CowHotspot(
        code: 'LOIN',
        label: 'Loin',
        points: const [
          Offset(0.5684, 0.1980),
          Offset(0.7280, 0.1860),
          Offset(0.7320, 0.2578),
          Offset(0.7341, 0.3223),
          Offset(0.7355, 0.3591),
          Offset(0.6975, 0.3517),
          Offset(0.6423, 0.3536),
          Offset(0.5780, 0.3591),
          Offset(0.5753, 0.2670),
        ],
      ),
      _CowHotspot(
        code: 'LOIN',
        label: 'Tenderloin',
        points: const [
          Offset(0.5780, 0.3591),
          Offset(0.6423, 0.3536),
          Offset(0.6975, 0.3517),
          Offset(0.7355, 0.3591),
          Offset(0.7459, 0.3729),
          Offset(0.7389, 0.3959),
          Offset(0.6906, 0.4033),
          Offset(0.6354, 0.4033),
          Offset(0.5801, 0.3978),
        ],
      ),
      _CowHotspot(
        code: 'FLANK',
        label: 'Flank',
        points: const [
          Offset(0.5801, 0.3978),
          Offset(0.6354, 0.4033),
          Offset(0.6837, 0.4052),
          Offset(0.6851, 0.4604),
          Offset(0.6872, 0.5295),
          Offset(0.6423, 0.5470),
          Offset(0.5732, 0.5820),
          Offset(0.5698, 0.5157),
        ],
      ),
      _CowHotspot(
        code: 'HIND',
        label: 'Thick Flank',
        points: const [
          Offset(0.6837, 0.4052),
          Offset(0.7389, 0.3959),
          Offset(0.7597, 0.4190),
          Offset(0.7838, 0.4696),
          Offset(0.8080, 0.5433),
          Offset(0.7690, 0.5525),
          Offset(0.7251, 0.5341),
          Offset(0.6872, 0.5295),
        ],
      ),
      _CowHotspot(
        code: 'RUMP',
        label: 'Rump',
        points: const [
          Offset(0.7280, 0.1860),
          Offset(0.8564, 0.1750),
          Offset(0.8840, 0.1842),
          Offset(0.9047, 0.2026),
          Offset(0.9081, 0.2670),
          Offset(0.9047, 0.3131),
          Offset(0.8425, 0.3361),
          Offset(0.7804, 0.3591),
          Offset(0.7459, 0.3729),
          Offset(0.7355, 0.3591),
        ],
      ),
      _CowHotspot(
        code: 'HIND',
        label: 'Topside',
        points: const [
          Offset(0.7459, 0.3729),
          Offset(0.7804, 0.3591),
          Offset(0.8425, 0.3361),
          Offset(0.9047, 0.3131),
          Offset(0.9012, 0.3683),
          Offset(0.8964, 0.4328),
          Offset(0.8425, 0.4420),
          Offset(0.7873, 0.4512),
          Offset(0.7597, 0.4190),
        ],
      ),
      _CowHotspot(
        code: 'SILVERSIDE',
        label: 'Silverside',
        points: const [
          Offset(0.7873, 0.4512),
          Offset(0.8425, 0.4420),
          Offset(0.8964, 0.4328),
          Offset(0.8943, 0.4788),
          Offset(0.8909, 0.5295),
          Offset(0.8564, 0.5387),
          Offset(0.8080, 0.5525),
        ],
      ),
      _CowHotspot(
        code: 'HIND',
        label: 'Knuckle',
        points: const [
          Offset(0.8080, 0.5525),
          Offset(0.8564, 0.5387),
          Offset(0.8909, 0.5295),
          Offset(0.8943, 0.5801),
          Offset(0.8874, 0.5985),
          Offset(0.8494, 0.6262),
          Offset(0.8287, 0.5985),
        ],
      ),
      _CowHotspot(
        code: 'SHANK',
        label: 'Hind Shank',
        points: const [
          Offset(0.8494, 0.6262),
          Offset(0.8874, 0.5985),
          Offset(0.8978, 0.6262),
          Offset(0.8978, 0.7182),
          Offset(0.8943, 0.8103),
          Offset(0.8598, 0.8103),
          Offset(0.8564, 0.7366),
          Offset(0.8529, 0.6621),
        ],
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E2DE)),
          ),
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                void updateHover(Offset localPosition) {
                  final normalized = Offset(
                    localPosition.dx / size.width,
                    localPosition.dy / size.height,
                  );

                  String? hoveredCode;
                  for (final hotspot in hotspots.reversed) {
                    if (_pointInPolygon(normalized, hotspot.points)) {
                      hoveredCode = hotspot.code;
                      break;
                    }
                  }

                  if (hoveredCode != _hoveredSectionCode) {
                    setState(() {
                      _hoveredSectionCode = hoveredCode;
                    });
                  }
                }

                void handleTap(Offset localPosition) {
                  final normalized = Offset(
                    localPosition.dx / size.width,
                    localPosition.dy / size.height,
                  );

                  for (final hotspot in hotspots.reversed) {
                    if (_pointInPolygon(normalized, hotspot.points)) {
                      _selectSectionCode(
                        hotspot.code,
                        visualLabel: hotspot.label,
                      );
                      return;
                    }
                  }
                }

                return MouseRegion(
                  cursor: _hoveredSectionCode == null
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  onHover: (event) => updateHover(event.localPosition),
                  onExit: (_) {
                    if (_hoveredSectionCode != null) {
                      setState(() {
                        _hoveredSectionCode = null;
                      });
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => handleTap(details.localPosition),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/cutlink_beef_map.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _CowHotspotPainter(
                              hotspots: hotspots,
                              selectedSectionId: _selectedSectionId,
                              hoveredSectionCode: _hoveredSectionCode,
                              sectionIdForCode: (code) =>
                                  _sectionByCode(code)?['id']?.toString(),
                              accent: _darkRed,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: _buildMiscButton(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    var inside = false;

    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx;
      final yi = polygon[i].dy;
      final xj = polygon[j].dx;
      final yj = polygon[j].dy;

      final intersects =
          ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx <
              (xj - xi) *
                      (point.dy - yi) /
                      ((yj - yi).abs() < 0.000001 ? 0.000001 : (yj - yi)) +
                  xi);

      if (intersects) {
        inside = !inside;
      }
    }

    return inside;
  }

  Widget _buildMiscButton() {
    Map<String, dynamic>? misc;

    for (final section in _beefSections) {
      if (section['is_miscellaneous'] == true) {
        misc = section;
        break;
      }
    }

    final miscSection = misc;
    if (miscSection == null) return const SizedBox.shrink();

    final id = miscSection['id'].toString();
    final selected = _selectedSectionId == id;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFF3E8E8) : Colors.white,
        foregroundColor: selected ? _darkRed : const Color(0xFF444444),
        side: BorderSide(color: selected ? _darkRed : const Color(0xFFD8D8D4)),
      ),
      onPressed: () {
        _selectSection(miscSection);
      },
      icon: const Icon(Icons.medical_information_outlined),
      label: Text(
        'Misc / Offal (${_sectionProductCount(id)})',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildSectionStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final section in _beefSections) ...[
            _sectionChip(section),
            const SizedBox(width: 8),
          ],
        ],
      ),
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

class _CowHotspot {
  const _CowHotspot({
    required this.code,
    required this.label,
    required this.points,
  });

  final String code;
  final String label;
  final List<Offset> points;
}

class _CowHotspotPainter extends CustomPainter {
  const _CowHotspotPainter({
    required this.hotspots,
    required this.selectedSectionId,
    required this.hoveredSectionCode,
    required this.sectionIdForCode,
    required this.accent,
  });

  final List<_CowHotspot> hotspots;
  final String? selectedSectionId;
  final String? hoveredSectionCode;
  final String? Function(String code) sectionIdForCode;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    for (final hotspot in hotspots) {
      final sectionId = sectionIdForCode(hotspot.code);
      final selected = sectionId != null && sectionId == selectedSectionId;
      final hovered = hotspot.code == hoveredSectionCode;

      if (!selected && !hovered) {
        continue;
      }

      final path = Path();
      final first = hotspot.points.first;

      path.moveTo(first.dx * size.width, first.dy * size.height);

      for (final point in hotspot.points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }

      path.close();

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = selected
            ? accent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.22);

      canvas.drawPath(path, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _CowHotspotPainter oldDelegate) {
    return oldDelegate.selectedSectionId != selectedSectionId ||
        oldDelegate.hoveredSectionCode != hoveredSectionCode ||
        oldDelegate.accent != accent;
  }
}
