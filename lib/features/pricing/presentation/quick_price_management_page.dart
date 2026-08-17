import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuickPriceManagementPage extends StatefulWidget {
  const QuickPriceManagementPage({super.key});

  @override
  State<QuickPriceManagementPage> createState() =>
      _QuickPriceManagementPageState();
}

class _QuickPriceManagementPageState extends State<QuickPriceManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isApplyingBulkChange = false;
  String? _errorMessage;
  String? _selectedPriceListId;

  List<Map<String, dynamic>> _priceLists = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, Map<String, dynamic>> _pricesByProductId = {};

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
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('No signed-in user was found.');

      final membership = await client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final businessId = membership['business_id'] as String;

      final priceListResponse = await client
          .from('price_lists')
          .select('id, name, visibility, active')
          .eq('supplier_business_id', businessId)
          .eq('active', true)
          .order('name');

      final productResponse = await client
          .from('products')
          .select('''
            id,
            sku,
            product_name,
            active,
            order_unit,
            price_basis,
            weight_type,
            catch_weight
          ''')
          .eq('supplier_business_id', businessId)
          .eq('active', true)
          .order('product_name');

      final priceLists = List<Map<String, dynamic>>.from(priceListResponse);
      final products = List<Map<String, dynamic>>.from(productResponse);
      final selected = _selectedPriceListId ??
          (priceLists.isEmpty ? null : priceLists.first['id']?.toString());

      if (!mounted) {

        return;

      }
      setState(() {
        _priceLists = priceLists;
        _products = products;
        _selectedPriceListId = selected;
      });

      await _loadPrices();
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

  Future<void> _loadPrices() async {
    final priceListId = _selectedPriceListId;
    if (priceListId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pricesByProductId = {};
        _isLoading = false;
      });
      return;
    }

    final response = await Supabase.instance.client
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
        .eq('price_list_id', priceListId);

    final prices = <String, Map<String, dynamic>>{};
    for (final raw in response) {
      final row = Map<String, dynamic>.from(raw);
      final productId = row['product_id']?.toString();
      if (productId != null && productId.isNotEmpty) prices[productId] = row;
    }

    if (!mounted) {

      return;

    }
    setState(() {
      _pricesByProductId = prices;
      _isLoading = false;
    });
  }

  bool _isCatchWeight(Map<String, dynamic> product) {
    return product['weight_type']?.toString() == 'catch_weight' ||
        product['catch_weight'] == true;
  }

  String _effectivePriceBasis(Map<String, dynamic> product, Map<String, dynamic>? price) {
    if (_isCatchWeight(product)) return 'kilogram';
    final fromPrice = price?['price_basis']?.toString();
    if (fromPrice == 'kilogram' || fromPrice == 'carton' || fromPrice == 'unit') {
      return fromPrice!;
    }
    final fromProduct = product['price_basis']?.toString();
    if (fromProduct == 'kilogram' || fromProduct == 'carton' || fromProduct == 'unit') {
      return fromProduct!;
    }
    return 'unit';
  }

  String _effectiveMinimumUnit(Map<String, dynamic> product, Map<String, dynamic>? price) {
    if (_isCatchWeight(product)) return 'carton';
    final configured = price?['minimum_quantity_unit']?.toString();
    if (configured == 'kilogram' || configured == 'carton' || configured == 'unit') {
      return configured!;
    }
    final orderUnit = product['order_unit']?.toString();
    if (orderUnit == 'kilogram' || orderUnit == 'carton' || orderUnit == 'unit') {
      return orderUnit!;
    }
    return 'unit';
  }

  String _basisLabel(String value) => switch (value) {
        'kilogram' => 'kg',
        'carton' => 'carton',
        'unit' => 'unit',
        _ => value,
      };

  String _minimumUnitLabel(String value) => switch (value) {
        'kilogram' => 'kg',
        'carton' => 'cartons',
        'unit' => 'units',
        _ => value,
      };

  String _visibilityLabel(String? value) => switch (value) {
        'public' => 'Standard',
        'approved_customers' => 'Trade',
        'private' => 'Customer-Specific',
        _ => 'Price List',
      };

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return _products;
    return _products.where((product) {
      return [product['product_name'], product['sku']].any((value) =>
          value != null && value.toString().toLowerCase().contains(search));
    }).toList();
  }

  Future<void> _editPrice(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) {
      return;
    }
    final existing = _pricesByProductId[productId];
    final isCatchWeight = _isCatchWeight(product);
    final priceBasis = _effectivePriceBasis(product, existing);
    final minimumUnit = _effectiveMinimumUnit(product, existing);

    final amountController = TextEditingController(text: existing?['amount']?.toString() ?? '');
    final minimumController = TextEditingController(text: existing?['minimum_quantity']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount < 0) {
                return;
              }
              final minimumText = minimumController.text.trim();
              double? minimumQuantity;
              if (minimumText.isNotEmpty) {
                if (isCatchWeight) {
                  final whole = int.tryParse(minimumText);
                  if (whole == null || whole <= 0) {
                    return;
                  }
                  minimumQuantity = whole.toDouble();
                } else {
                  minimumQuantity = double.tryParse(minimumText);
                  if (minimumQuantity == null || minimumQuantity <= 0) {
                    return;
                  }
                }
              }

              setDialogState(() => isSaving = true);
              try {
                await Supabase.instance.client.from('product_prices').upsert({
                  'price_list_id': _selectedPriceListId,
                  'product_id': productId,
                  'amount': amount,
                  'price_basis': isCatchWeight ? 'kilogram' : priceBasis,
                  'minimum_quantity': minimumQuantity,
                  'minimum_quantity_unit': isCatchWeight ? 'carton' : minimumUnit,
                  'active': true,
                  'updated_at': DateTime.now().toIso8601String(),
                }, onConflict: 'price_list_id,product_id');

                if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
              } on PostgrestException catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() => isSaving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(error.message)),
                );
              }
            }

            return AlertDialog(
              title: Text(product['product_name']?.toString() ?? 'Edit price'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price per ${_basisLabel(priceBasis)}',
                        prefixText: r'$ ',
                        suffixText: '/ ${_basisLabel(priceBasis)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: minimumController,
                      keyboardType: TextInputType.numberWithOptions(decimal: !isCatchWeight),
                      inputFormatters: isCatchWeight ? [FilteringTextInputFormatter.digitsOnly] : null,
                      decoration: InputDecoration(
                        labelText: 'Minimum ${_minimumUnitLabel(minimumUnit)} per order (optional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (isCatchWeight) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Catch-weight products are ordered by whole cartons and charged per kg after actual weight is known.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    minimumController.dispose();
    if (saved == true) await _loadPrices();
  }

  Future<void> _showBulkAdjustDialog() async {
    if (_selectedPriceListId == null || _pricesByProductId.isEmpty) {
      return;
    }
    final controller = TextEditingController();
    String adjustmentType = 'percent';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Bulk price adjustment'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: adjustmentType,
                      decoration: const InputDecoration(
                        labelText: 'Adjustment type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'percent', child: Text('Percentage')),
                        DropdownMenuItem(value: 'dollar', child: Text('Dollar amount')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => adjustmentType = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      decoration: InputDecoration(
                        labelText: adjustmentType == 'percent' ? 'Change percentage' : 'Change amount',
                        hintText: adjustmentType == 'percent' ? 'Example: 5 or -5' : 'Example: 1.50 or -1.50',
                        prefixText: adjustmentType == 'dollar' ? r'$ ' : null,
                        suffixText: adjustmentType == 'percent' ? '%' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    if (value == null || value == 0) {
                      return;
                    }
                    Navigator.of(dialogContext).pop({'type': adjustmentType, 'value': value});
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (result == null) {
      return;
    }
    setState(() => _isApplyingBulkChange = true);
    try {
      final client = Supabase.instance.client;
      final type = result['type'] as String;
      final value = result['value'] as double;

      for (final row in _pricesByProductId.values) {
        final raw = row['amount'];
        final current = raw is num ? raw.toDouble() : double.tryParse('$raw');
        if (current == null) continue;
        final next = type == 'percent' ? current * (1 + value / 100) : current + value;
        if (next < 0) continue;
        await client.from('product_prices').update({
          'amount': double.parse(next.toStringAsFixed(4)),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', row['id']);
      }

      await _loadPrices();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isApplyingBulkChange = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Quick Pricing', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _isLoading ? null : _loadPage, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Color(0xFF741C1C)),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: _loadPage, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_priceLists.isEmpty) {
      return const Center(child: Text('Create a price list before using Quick Pricing.'));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPriceListId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Price list', border: OutlineInputBorder()),
                      items: _priceLists.map((priceList) {
                        final id = priceList['id']?.toString() ?? '';
                        final name = priceList['name']?.toString() ?? 'Price List';
                        final visibility = _visibilityLabel(priceList['visibility']?.toString());
                        return DropdownMenuItem(value: id, child: Text('$visibility • $name'));
                      }).toList(),
                      onChanged: (value) async {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedPriceListId = value;
                          _isLoading = true;
                        });
                        await _loadPrices();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(labelText: 'Search products', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isApplyingBulkChange ? null : _showBulkAdjustDialog,
                    icon: const Icon(Icons.percent),
                    label: const Text('Bulk Change'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                itemCount: _filteredProducts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  final productId = product['id']?.toString() ?? '';
                  final price = _pricesByProductId[productId];
                  final amount = price?['amount'];
                  final basis = _effectivePriceBasis(product, price);
                  final minimum = price?['minimum_quantity'];
                  final minimumUnit = _effectiveMinimumUnit(product, price);

                  return Card(
                    elevation: 0,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      title: Text(product['product_name']?.toString() ?? 'Unnamed product', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text([
                        if (product['sku'] != null && product['sku'].toString().trim().isNotEmpty) 'SKU: ${product['sku']}',
                        if (_isCatchWeight(product)) 'Order cartons • priced / kg',
                        if (minimum != null) 'Minimum: ${minimum.toString()} ${_minimumUnitLabel(minimumUnit)}',
                      ].join('  •  ')),
                      trailing: SizedBox(
                        width: 210,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                amount == null ? 'Not set' : '\$${double.parse(amount.toString()).toStringAsFixed(2)} / ${_basisLabel(basis)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: amount == null ? const Color(0xFF777777) : const Color(0xFF741C1C),
                                ),
                              ),
                            ),
                            IconButton(onPressed: () => _editPrice(product), icon: const Icon(Icons.edit_outlined)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
