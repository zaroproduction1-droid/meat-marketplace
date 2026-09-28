import 'dart:async';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../../shared/widgets/phone_layout.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PriceListProductsPage extends StatefulWidget {
  const PriceListProductsPage({
    super.key,
    required this.priceListId,
    required this.priceListName,
  });

  final String priceListId;
  final String priceListName;

  @override
  State<PriceListProductsPage> createState() => _PriceListProductsPageState();
}

class _PriceListProductsPageState extends State<PriceListProductsPage> {
  Timer? _searchTimer;
  String _search = '';
  int _page = 0, _request = 0;
  bool _hasMore = false;
  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];
  Map<String, Map<String, dynamic>> _pricesByProductId = {};

  @override
  void initState() {
    super.initState();
    _loadProductsAndPrices();
  }

  Future<void> _loadProductsAndPrices() async {
    final request = ++_request;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final businessId = membership['business_id'] as String;

      var productQuery = Supabase.instance.client
          .from('products')
          .select('''
            id,
            sku,
            product_name,
            price_basis,
            active,
            animal_types(name),
            cuts(name)
            ''')
          .eq('supplier_business_id', businessId)
          .eq('active', true);
      final term = _search.replaceAll(RegExp(r'[^a-zA-Z0-9 ._/-]'), ' ').trim();
      if (term.isNotEmpty) {
        productQuery = productQuery.or(
          'product_name.ilike.%$term%,sku.ilike.%$term%',
        );
      }
      final productsResponse = await productQuery
          .order('product_name')
          .order('id')
          .range(_page * 50, _page * 50 + 50);
      final visibleProducts = productsResponse.take(50).toList();

      final pricesResponse = visibleProducts.isEmpty
          ? <Map<String, dynamic>>[]
          : await Supabase.instance.client
                .from('product_prices')
                .select('''
            id,
            product_id,
            amount,
            price_basis,
            minimum_quantity,
            active
            ''')
                .eq('price_list_id', widget.priceListId)
                .eq('active', true)
                .inFilter(
                  'product_id',
                  visibleProducts.map((p) => p['id'].toString()).toList(),
                );

      final pricesMap = <String, Map<String, dynamic>>{};

      for (final price in pricesResponse) {
        final priceMap = Map<String, dynamic>.from(price);
        final productId = priceMap['product_id'] as String;

        pricesMap[productId] = priceMap;
      }

      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        _hasMore = productsResponse.length > 50;
        _products = List<Map<String, dynamic>>.from(visibleProducts);

        _pricesByProductId = pricesMap;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load products and prices.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openPriceDialog(Map<String, dynamic> product) async {
    final productId = product['id'] as String;
    final existingPrice = _pricesByProductId[productId];

    final amountController = TextEditingController(
      text: existingPrice?['amount']?.toString() ?? '',
    );

    final minimumQuantityController = TextEditingController(
      text: existingPrice?['minimum_quantity']?.toString() ?? '',
    );

    String priceBasis =
        existingPrice?['price_basis'] as String? ??
        product['price_basis'] as String? ??
        'kilogram';

    bool isActive = existingPrice?['active'] as bool? ?? true;

    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> savePrice() async {
              final amount = double.tryParse(amountController.text.trim());

              if (amount == null || amount < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid price.')),
                );

                return;
              }

              final minimumQuantityText = minimumQuantityController.text.trim();

              final minimumQuantity = minimumQuantityText.isEmpty
                  ? null
                  : double.tryParse(minimumQuantityText);

              if (minimumQuantityText.isNotEmpty &&
                  (minimumQuantity == null || minimumQuantity < 0)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid minimum quantity.'),
                  ),
                );

                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await Supabase.instance.client.from('product_prices').upsert({
                  'price_list_id': widget.priceListId,
                  'product_id': productId,
                  'amount': amount,
                  'price_basis': priceBasis,
                  'minimum_quantity': minimumQuantity,
                  'active': isActive,
                  'updated_at': DateTime.now().toIso8601String(),
                }, onConflict: 'price_list_id,product_id');

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop(true);
              } on PostgrestException catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(error.message)));
              }
            }

            return phoneDialog(
              context,
              AlertDialog(
                title: Text(
                  product['product_name'] as String? ?? 'Set product price',
                ),
                content: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: r'$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        isExpanded: isPhoneLayout(context),
                        initialValue: priceBasis,
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
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    priceBasis = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: minimumQuantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Minimum quantity (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        title: const Text('Price active'),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isActive = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop(false);
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving ? null : savePrice,
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Price'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    minimumQuantityController.dispose();

    if (saved == true) {
      await _loadProductsAndPrices();
    }
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

  @override
  Widget build(BuildContext context) {
    return CutLinkWorkspaceTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: phoneAppBar(
          context,
          AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(widget.priceListName),
            actions: [
              IconButton(
                onPressed: _loadProductsAndPrices,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search product name or SKU',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      _search = v;
                      _page = 0;
                      _request++;
                      _searchTimer?.cancel();
                      _searchTimer = Timer(
                        const Duration(milliseconds: 350),
                        _loadProductsAndPrices,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _isLoading || _page == 0
                            ? null
                            : () {
                                _page--;
                                _loadProductsAndPrices();
                              },
                        child: const Text('Previous'),
                      ),
                      Text('Page ${_page + 1} · up to 50 products'),
                      TextButton(
                        onPressed: _isLoading || !_hasMore
                            ? null
                            : () {
                                _page++;
                                _loadProductsAndPrices();
                              },
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
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
                onPressed: _loadProductsAndPrices,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No matching active products. Try another name or SKU.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _products.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 14);
      },
      itemBuilder: (context, index) {
        final product = _products[index];
        final productId = product['id'] as String;
        final price = _pricesByProductId[productId];

        final animalType = product['animal_types'] as Map<String, dynamic>?;

        final cut = product['cuts'] as Map<String, dynamic>?;

        final amount = price?['amount'];
        final priceBasis = price?['price_basis'] as String?;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF4E5E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF741C1C),
              ),
            ),
            title: Text(
              product['product_name'] as String? ?? 'Unnamed product',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${product['sku']} • '
                '${animalType?['name'] ?? ''} • '
                '${cut?['name'] ?? ''}',
              ),
            ),
            trailing: amount == null
                ? const Chip(label: Text('No price'))
                : Text(
                    '\$$amount / ${_formatPriceBasis(priceBasis)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF741C1C),
                    ),
                  ),
            onTap: () {
              _openPriceDialog(product);
            },
          ),
        );
      },
    );
  }
}
