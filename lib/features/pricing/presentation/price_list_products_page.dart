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

      final productsResponse = await Supabase.instance.client
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
          .eq('active', true)
          .order('product_name');

      final pricesResponse = await Supabase.instance.client
          .from('product_prices')
          .select('''
            id,
            product_id,
            amount,
            price_basis,
            minimum_quantity,
            active
            ''')
          .eq('price_list_id', widget.priceListId);

      final pricesMap = <String, Map<String, dynamic>>{};

      for (final price in pricesResponse) {
        final priceMap = Map<String, dynamic>.from(price);
        final productId = priceMap['product_id'] as String;

        pricesMap[productId] = priceMap;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _products = List<Map<String, dynamic>>.from(productsResponse);

        _pricesByProductId = pricesMap;
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
    } catch (_) {
      if (!mounted) {
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

            return AlertDialog(
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
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
            'Create at least one active product before adding prices.',
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
