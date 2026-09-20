import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'marketplace_products_page.dart';
import 'marketplace_product_details_page.dart';
import '../services/butcher_favourites_store.dart';
import '../../../shared/widgets/catalogue_product_image.dart';
import '../../../shared/animal_catalogues/product_variant.dart';

class ButcherFavouritesPage extends StatefulWidget {
  const ButcherFavouritesPage({
    super.key,
    required this.businessId,
    this.initialProducts = false,
    this.initialDashboard = false,
  });
  final String businessId;
  final bool initialProducts;
  final bool initialDashboard;

  @override
  State<ButcherFavouritesPage> createState() => _ButcherFavouritesPageState();
}

class _ButcherFavouritesPageState extends State<ButcherFavouritesPage> {
  static const _brand = Color(0xFF741C1C);
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _busyId;
  late final ButcherFavouritesStore _favourites;
  List<Map<String, dynamic>> _productRows = [];
  String _kind = 'search';
  String _animal = '';
  String _supplier = '';
  String _sort = 'recent';
  bool _halal = false;
  bool _available = false;
  static const _productSelect =
      '*, meat_animals(id,code,name), meat_sections(id,name), '
      'meat_specifications(id,name), meat_grades(id,code,name), '
      'businesses(id,trading_name,legal_name,logo_path), '
      'product_prices(*,price_lists(*))';

  @override
  void initState() {
    super.initState();
    _kind = widget.initialDashboard
        ? 'dashboard'
        : widget.initialProducts
        ? 'product'
        : 'search';
    _favourites = ButcherFavouritesStore(businessId: widget.businessId);
    _load();
  }

  @override
  void dispose() {
    _favourites.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _favourites.load();
      if (!_favourites.ready) {
        throw StateError('Favourites unavailable');
      }
      final saved = _favourites.products;
      final ids = saved
          .map((row) => row['product_id'])
          .whereType<String>()
          .toList();
      final current = <String, Map<String, dynamic>>{};
      for (var start = 0; start < ids.length; start += 80) {
        final batch = await Supabase.instance.client
            .from('products')
            .select(_productSelect)
            .inFilter('id', ids.skip(start).take(80).toList());
        for (final product in batch) {
          current[product['id'].toString()] = Map<String, dynamic>.from(
            product,
          );
        }
      }
      if (mounted) {
        setState(() {
          _rows = _favourites.searches;
          _productRows = [
            for (final row in saved)
              {...row, 'product': current[row['product_id']]},
          ];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load favourites. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _animalFor(Map<String, dynamic> row) => _kind == 'search'
      ? favouriteMap(row['filters'])['animal']?.toString() ?? ''
      : favouriteMap(
              favouriteMap(row['product'])['meat_animals'],
            )['code']?.toString() ??
            row['animal_code']?.toString() ??
            '';

  int get _dashboardCount =>
      _productRows.where((row) => row['dashboard_slot'] != null).length;

  Future<void> _toggleDashboard(Map<String, dynamic> row) async {
    if (_busyId != null) {
      return;
    }
    final selected = row['dashboard_slot'] != null;
    setState(() => _busyId = row['id'].toString());
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in required');
      }
      final current = await client
          .from('butcher_favourite_products')
          .select('id,dashboard_slot')
          .eq('business_id', widget.businessId)
          .eq('user_id', user.id)
          .gte('dashboard_slot', 1)
          .lte('dashboard_slot', 4);
      final used = current.map((item) => item['dashboard_slot']).toSet();
      final free = [
        for (var slot = 1; slot <= 4; slot++)
          if (!used.contains(slot)) slot,
      ];
      if (!selected && free.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your dashboard has four products. Remove a dashboard selection first.',
              ),
            ),
          );
          await _load();
        }
        return;
      }
      final updated = await client
          .from('butcher_favourite_products')
          .update({'dashboard_slot': selected ? null : free.first})
          .eq('business_id', widget.businessId)
          .eq('user_id', user.id)
          .eq('id', row['id'])
          .select('id,dashboard_slot')
          .single();
      if (mounted) {
        final slots = {
          for (final item in current) item['id']: item['dashboard_slot'],
        };
        slots[updated['id']] = updated['dashboard_slot'];
        setState(() {
          _productRows = [
            for (final item in _productRows)
              {...item, 'dashboard_slot': slots[item['id']]},
          ];
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your dashboard selection. Please try again.',
            ),
          ),
        );
        await _load();
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  String _supplierFor(Map<String, dynamic> row) {
    if (_kind == 'search') {
      return favouriteMap(row['filters'])['supplier_query']?.toString() ?? '';
    }
    final business = favouriteMap(favouriteMap(row['product'])['businesses']);
    return (business['trading_name'] ??
            business['legal_name'] ??
            row['supplier_name'] ??
            '')
        .toString();
  }

  String _title(Map<String, dynamic> row) => _kind == 'search'
      ? row['name'].toString()
      : (favouriteMap(
                  favouriteMap(row['product'])['meat_specifications'],
                )['name'] ??
                row['product_name'] ??
                'Unavailable product')
            .toString();
  String _productSummary(Map<String, dynamic> product) => [
    product['sku']?.toString() ?? '',
    productSizeLabel(product),
    product['brand']?.toString() ?? '',
    product['breed_program']?.toString() ?? '',
    favouriteMap(product['meat_grades'])['code']?.toString() ?? '',
    favouriteMap(product['meat_grades'])['name']?.toString() ?? '',
    product['marbling_score']?.toString() ?? '',
  ].where((part) => part.isNotEmpty).join(' • ');
  String _price(Map<String, dynamic> product) {
    Map<String, dynamic>? best;
    var priority = 0;
    for (final raw
        in product['product_prices'] is List
            ? product['product_prices'] as List
            : const []) {
      final price = favouriteMap(raw),
          list = favouriteMap(favouriteMap(raw)['price_lists']);
      final rank = switch (list['visibility']) {
        'private' => 3,
        'approved_customers' => 2,
        'public' => 1,
        _ => 0,
      };
      if (price['active'] == true &&
          list['active'] == true &&
          rank > priority) {
        best = price;
        priority = rank;
      }
    }
    final amount = num.tryParse('${best?['amount']}');
    if (amount == null) {
      return 'Contact supplier';
    }
    final basis = switch (best?['price_basis']) {
      'per_kg' || 'kilogram' => 'kg',
      'per_carton' => 'carton',
      'per_unit' => 'unit',
      _ => best?['price_basis']?.toString() ?? '',
    };
    return '\$${amount.toStringAsFixed(2)}${basis.isEmpty ? '' : ' / $basis'}';
  }

  Future<void> _openProduct(Map<String, dynamic> row) async {
    if (row['product_id'] == null || _busyId != null) {
      return;
    }
    setState(() => _busyId = row['id'].toString());
    try {
      final product = await Supabase.instance.client
          .from('products')
          .select(_productSelect)
          .eq('id', row['product_id'])
          .eq('active', true)
          .maybeSingle();
      if (!mounted) {
        return;
      }
      if (product == null) {
        throw StateError('Unavailable product');
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MarketplaceProductDetailsPage(
            product: Map<String, dynamic>.from(product),
            favourites: _favourites,
          ),
        ),
      );
      if (mounted) {
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This product is unavailable or could not be loaded. Please refresh.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _removeProduct(Map<String, dynamic> row) async {
    if (_busyId != null) {
      return;
    }
    setState(() => _busyId = row['id'].toString());
    try {
      await _favourites.removeProductRow(row['id'].toString());
      if (mounted) {
        setState(
          () => _productRows.removeWhere((item) => item['id'] == row['id']),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not remove product favourite. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final filters = row['filters'];
    if (filters is! Map || filters['version'] != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save this search again from Browse Products.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceProductsPage(
          initialSearch: Map<String, dynamic>.from(filters),
          butcherBusinessId: widget.businessId,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _change(Map<String, dynamic> row, {bool remove = false}) async {
    final id = row['id'].toString();
    if (_busyId != null) {
      return;
    }
    String? name;
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove favourite?'),
          content: Text('Remove “${row['name']}” from your saved searches?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    } else {
      var draft = row['name'].toString();
      name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename favourite'),
          content: TextFormField(
            initialValue: draft,
            autofocus: true,
            maxLength: 100,
            onChanged: (value) => draft = value,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (draft.trim().isNotEmpty) {
                  Navigator.pop(ctx, draft.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name == null) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _busyId = id);
    try {
      final table = Supabase.instance.client.from('butcher_saved_searches');
      final result = remove
          ? await table
                .delete()
                .eq('id', id)
                .eq('business_id', widget.businessId)
                .select('id')
                .single()
          : await table
                .update({'name': name})
                .eq('id', id)
                .eq('business_id', widget.businessId)
                .select('id')
                .single();
      if (mounted && result['id'] == id) {
        setState(() {
          if (remove) {
            _rows.removeWhere((item) => item['id'] == id);
          } else {
            row['name'] = name;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update favourite. Use a unique name or try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _kind == 'search' ? _rows : _productRows;
    final suppliers =
        source
            .map(_supplierFor)
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final rows = source.where((row) {
      final product = favouriteMap(row['product']);
      final filters = favouriteMap(row['filters']);
      final text =
          '${_title(row)} ${row['summary'] ?? ''} ${_supplierFor(row)} ${_productSummary(product)}'
              .toLowerCase();
      return _query.toLowerCase().split(RegExp(r'\s+')).every(text.contains) &&
          (_animal.isEmpty || _animalFor(row) == _animal) &&
          (_supplier.isEmpty || _supplierFor(row) == _supplier) &&
          (!_halal ||
              (_kind == 'search'
                  ? filters['halal'] == true
                  : product['halal_status'] == 'halal')) &&
          (!_available ||
              _kind == 'search' ||
              (product['active'] == true &&
                  product['availability_status'] != 'out_of_stock' &&
                  (num.tryParse('${product['available_quantity']}') ?? 0) > 0));
    }).toList();
    rows.sort(
      (a, b) => _sort == 'name'
          ? _title(a).compareTo(_title(b))
          : (b['created_at']?.toString() ?? '').compareTo(
              a['created_at']?.toString() ?? '',
            ),
    );
    Widget picker(
      String label,
      String selected,
      Map<String, String> choices,
      ValueChanged<String> changed,
    ) => SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        key: ValueKey('$label-$selected-${choices.keys.join()}'),
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final entry in choices.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => changed(value));
          }
        },
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Favourites'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh favourites',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .42,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text('Saved searches (${_rows.length})'),
                          selected: _kind == 'search',
                          onSelected: (_) => setState(() {
                            _kind = 'search';
                            _supplier = '';
                          }),
                        ),
                        ChoiceChip(
                          label: Text('Products (${_productRows.length})'),
                          selected: _kind == 'product',
                          onSelected: (_) => setState(() {
                            _kind = 'product';
                            _supplier = '';
                          }),
                        ),
                        ChoiceChip(
                          label: Text('Dashboard ($_dashboardCount/4)'),
                          selected: _kind == 'dashboard',
                          onSelected: (_) => setState(() {
                            _kind = 'dashboard';
                            _supplier = '';
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_kind == 'dashboard') ...[
                      const Text(
                        'Choose up to four favourite products for your dashboard. Removing a selection keeps it in Favourites.',
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText:
                            'Search favourites, cuts, brands or suppliers…',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        picker('Animal', _animal, {
                          '': 'All animals',
                          for (final animal in const [
                            'BEEF',
                            'VEAL',
                            'LAMB',
                            'MUTTON',
                            'GOAT',
                            'CHICKEN',
                          ])
                            animal: animal,
                        }, (value) => _animal = value),
                        picker('Supplier', _supplier, {
                          '': 'All suppliers',
                          for (final name in {
                            ...suppliers,
                            if (_supplier.isNotEmpty) _supplier,
                          })
                            name: name,
                        }, (value) => _supplier = value),
                        picker('Sort', _sort, {
                          'recent': 'Recently saved',
                          'name': 'Name A–Z',
                        }, (value) => _sort = value),
                        FilterChip(
                          label: Text(
                            _kind == 'search'
                                ? 'Saved with Halal only'
                                : 'Halal only',
                          ),
                          selected: _halal,
                          onSelected: (value) => setState(() => _halal = value),
                        ),
                        if (_kind != 'search')
                          FilterChip(
                            label: const Text('Available only'),
                            selected: _available,
                            onSelected: (value) =>
                                setState(() => _available = value),
                          ),
                        TextButton(
                          onPressed: () => setState(() {
                            _animal = '';
                            _supplier = '';
                            _halal = false;
                            _available = false;
                            _sort = 'recent';
                          }),
                          child: const Text('Clear filters'),
                        ),
                        Text('${rows.length} results'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 40,
                            color: _brand,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            source.isEmpty
                                ? 'Use the search or product heart in Browse Products to save a favourite.'
                                : 'No favourites match these filters.',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MarketplaceProductsPage(
                                    butcherBusinessId: widget.businessId,
                                  ),
                                ),
                              );
                              if (mounted) {
                                await _load();
                              }
                            },
                            child: const Text('Browse products'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final product = favouriteMap(row['product']);
                        final isProduct = _kind != 'search';
                        final available = product['active'] == true;
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE3E5E8)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isProduct) ...[
                                  CatalogueProductImage(
                                    product: product,
                                    thumbnail: true,
                                    imageWidth: 92,
                                    imageHeight: 92,
                                    fit: BoxFit.cover,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _title(row),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        isProduct
                                            ? _supplierFor(row)
                                            : row['summary'].toString(),
                                        style: const TextStyle(
                                          color: Color(0xFF646A70),
                                        ),
                                      ),
                                      if (isProduct) ...[
                                        Text(_productSummary(product)),
                                        Text(
                                          !available
                                              ? 'No longer available'
                                              : '${_price(product)}${product['availability_status'] == 'out_of_stock' ? ' • Out of stock' : ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 5,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (isProduct && _kind == 'dashboard')
                                            FilterChip(
                                              selected:
                                                  row['dashboard_slot'] != null,
                                              label: Text(
                                                row['dashboard_slot'] != null
                                                    ? 'On dashboard • ${row['dashboard_slot']}'
                                                    : 'Add to dashboard',
                                              ),
                                              onSelected:
                                                  _busyId != null ||
                                                      _loading ||
                                                      (!available &&
                                                          row['dashboard_slot'] ==
                                                              null)
                                                  ? null
                                                  : (_) =>
                                                        _toggleDashboard(row),
                                            ),
                                          FilledButton.icon(
                                            onPressed:
                                                _busyId != null ||
                                                    (isProduct && !available)
                                                ? null
                                                : () => isProduct
                                                      ? _openProduct(row)
                                                      : _open(row),
                                            icon: Icon(
                                              isProduct
                                                  ? Icons.shopping_cart_outlined
                                                  : Icons.search,
                                              size: 17,
                                            ),
                                            label: Text(
                                              isProduct
                                                  ? 'View / order'
                                                  : 'Open search',
                                            ),
                                          ),
                                          if (!isProduct)
                                            TextButton(
                                              onPressed: _busyId != null
                                                  ? null
                                                  : () => _change(row),
                                              child: const Text('Rename'),
                                            ),
                                          IconButton(
                                            tooltip: isProduct
                                                ? 'Remove product favourite'
                                                : 'Remove saved search',
                                            onPressed: _busyId != null
                                                ? null
                                                : () => isProduct
                                                      ? _removeProduct(row)
                                                      : _change(
                                                          row,
                                                          remove: true,
                                                        ),
                                            icon: const Icon(
                                              Icons.favorite,
                                              color: Color(0xFFB32632),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
