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
  static const _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String? _supplierBusinessId;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _priceLists = [];
  List<Map<String, dynamic>> _approvedCustomers = [];
  List<Map<String, dynamic>> _productPrices = [];

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
            meat_specification_id,
            meat_grade_id
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

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return _products;

    return _products.where((product) {
      final values = [product['product_name'], product['sku']];

      return values.any((value) {
        return value != null && value.toString().toLowerCase().contains(search);
      });
    }).toList();
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

  Future<void> _editMainPrice({
    required Map<String, dynamic> product,
    required String visibility,
  }) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) return;

    try {
      final list = await _ensurePriceList(
        visibility: visibility,
        defaultName: visibility == 'public'
            ? 'Standard Pricing'
            : 'Trade Pricing',
      );

      final priceListId = list['id']?.toString();
      if (priceListId == null || priceListId.isEmpty) return;

      final existing = _priceForProductAndList(productId, priceListId);
      await _openPriceDialog(
        product: product,
        priceList: list,
        existingPrice: existing,
        title: visibility == 'public' ? 'Standard Price' : 'Trade Price',
      );
    } catch (error) {
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

    final catchWeight = _isCatchWeight(product);
    final initialBasis = catchWeight
        ? 'kilogram'
        : existingPrice?['price_basis']?.toString() ??
              product['price_basis']?.toString() ??
              'unit';

    final amountController = TextEditingController(
      text: existingPrice?['amount']?.toString() ?? '',
    );
    final minimumController = TextEditingController(
      text: existingPrice?['minimum_quantity']?.toString() ?? '',
    );

    var basis = ['kilogram', 'carton', 'unit'].contains(initialBasis)
        ? initialBasis
        : 'unit';

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool saving = false;

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

              setDialogState(() => saving = true);

              try {
                await Supabase.instance.client.from('product_prices').upsert({
                  'price_list_id': priceListId,
                  'product_id': productId,
                  'amount': amount,
                  'price_basis': catchWeight ? 'kilogram' : basis,
                  'minimum_quantity': minimum,
                  'minimum_quantity_unit': catchWeight
                      ? 'carton'
                      : product['order_unit'],
                  'active': true,
                  'updated_at': DateTime.now().toIso8601String(),
                }, onConflict: 'price_list_id,product_id');

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on PostgrestException catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() => saving = false);
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(error.message)));
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
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Price'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    minimumController.dispose();

    if (saved == true) {
      await _loadPage();
    }
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
    var count = 0;

    for (final customer in _approvedCustomers) {
      final customerId = customer['butcher_business_id']?.toString();
      if (customerId == null) continue;

      final list = _privatePriceListForCustomer(customerId);
      if (list == null) continue;

      final price = _priceForProductAndList(productId, list['id'].toString());

      if (price != null) count++;
    }

    return count;
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

    final amount = price?['amount'];
    final basis = _isCatchWeight(product)
        ? 'kilogram'
        : price?['price_basis']?.toString() ??
              product['price_basis']?.toString() ??
              'unit';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _editMainPrice(product: product, visibility: visibility),
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
                amount == null
                    ? 'Not set'
                    : '${_money(amount)} / ${_basisLabel(basis)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: amount == null ? const Color(0xFF777777) : _darkRed,
                ),
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF666666)),
          ],
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search products',
                      hintText: 'Search product name or SKU',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => _searchController.clear(),
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 850) {
                        return Column(
                          children: [
                            _priceHeader(
                              title: 'Standard Price',
                              subtitle: 'Normal marketplace price',
                              icon: Icons.public,
                            ),
                            const SizedBox(height: 8),
                            _priceHeader(
                              title: 'Trade Price',
                              subtitle: 'For approved supplier customers',
                              icon: Icons.handshake_outlined,
                            ),
                            const SizedBox(height: 8),
                            _priceHeader(
                              title: 'Customer-Specific Price',
                              subtitle: 'Private negotiated customer prices',
                              icon: Icons.person_outline,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Expanded(flex: 4, child: SizedBox()),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _priceHeader(
                              title: 'Standard Price',
                              subtitle: 'Normal marketplace price',
                              icon: Icons.public,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _priceHeader(
                              title: 'Trade Price',
                              subtitle: 'Approved customers',
                              icon: Icons.handshake_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _priceHeader(
                              title: 'Customer-Specific',
                              subtitle: 'Private negotiated prices',
                              icon: Icons.person_outline,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'No products match your search.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Color(0xFFE2E2DE)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final narrow = constraints.maxWidth < 850;

                                final productInfo = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['product_name']?.toString() ??
                                          'Unnamed product',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product['sku']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true
                                          ? 'SKU: ${product['sku']}'
                                          : 'No SKU',
                                      style: const TextStyle(
                                        color: Color(0xFF6A6A6A),
                                      ),
                                    ),
                                    if (_isCatchWeight(product)) ...[
                                      const SizedBox(height: 5),
                                      const Text(
                                        'Carton order • \$/kg catch-weight pricing',
                                        style: TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                );

                                if (narrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      productInfo,
                                      const SizedBox(height: 14),
                                      const Text(
                                        'STANDARD PRICE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF777777),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      _priceCell(
                                        product: product,
                                        visibility: 'public',
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'TRADE PRICE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF777777),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      _priceCell(
                                        product: product,
                                        visibility: 'approved_customers',
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'CUSTOMER-SPECIFIC PRICE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF777777),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      _customerPriceCell(product),
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(flex: 4, child: productInfo),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _priceCell(
                                        product: product,
                                        visibility: 'public',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: _priceCell(
                                        product: product,
                                        visibility: 'approved_customers',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: _customerPriceCell(product),
                                    ),
                                  ],
                                );
                              },
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
