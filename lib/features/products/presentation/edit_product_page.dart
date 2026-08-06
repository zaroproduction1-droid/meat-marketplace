import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProductPage extends StatefulWidget {
  const EditProductPage({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _skuController;
  late final TextEditingController _productNameController;
  late final TextEditingController _brandController;
  late final TextEditingController _quantityController;

  late String _temperatureState;
  late String _availabilityStatus;
  late bool _active;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _skuController = TextEditingController(
      text: widget.product['sku'] as String? ?? '',
    );

    _productNameController = TextEditingController(
      text: widget.product['product_name'] as String? ?? '',
    );

    _brandController = TextEditingController(
      text: widget.product['brand'] as String? ?? '',
    );

    _quantityController = TextEditingController(
      text: widget.product['available_quantity']?.toString() ?? '',
    );

    _temperatureState =
        widget.product['temperature_state'] as String? ?? 'chilled';

    _availabilityStatus =
        widget.product['availability_status'] as String? ?? 'in_stock';

    _active = widget.product['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _productNameController.dispose();
    _brandController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName.';
    }

    return null;
  }

  String? _quantityValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final quantity = double.tryParse(value.trim());

    if (quantity == null || quantity < 0) {
      return 'Please enter a valid quantity.';
    }

    return null;
  }

  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final quantityText = _quantityController.text.trim();

      await Supabase.instance.client
          .from('products')
          .update({
            'sku': _skuController.text.trim(),
            'product_name': _productNameController.text.trim(),
            'brand': _brandController.text.trim().isEmpty
                ? null
                : _brandController.text.trim(),
            'temperature_state': _temperatureState,
            'availability_status': _availabilityStatus,
            'available_quantity': quantityText.isEmpty
                ? null
                : double.parse(quantityText),
            'active': _active,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.product['id']);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully.')),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF741C1C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Edit Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Update product',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _skuController,
                        decoration: const InputDecoration(
                          labelText: 'Supplier SKU',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          return _requiredValidator(value, 'a supplier SKU');
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _productNameController,
                        decoration: const InputDecoration(
                          labelText: 'Product name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          return _requiredValidator(value, 'a product name');
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Brand',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _temperatureState,
                        decoration: const InputDecoration(
                          labelText: 'Storage condition',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'chilled',
                            child: Text('Chilled'),
                          ),
                          DropdownMenuItem(
                            value: 'frozen',
                            child: Text('Frozen'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _temperatureState = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Available quantity',
                          border: OutlineInputBorder(),
                        ),
                        validator: _quantityValidator,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _availabilityStatus,
                        decoration: const InputDecoration(
                          labelText: 'Availability status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'in_stock',
                            child: Text('In stock'),
                          ),
                          DropdownMenuItem(
                            value: 'limited',
                            child: Text('Limited'),
                          ),
                          DropdownMenuItem(
                            value: 'out_of_stock',
                            child: Text('Out of stock'),
                          ),
                          DropdownMenuItem(
                            value: 'made_to_order',
                            child: Text('Made to order'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _availabilityStatus = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _active,
                        title: const Text('Product active'),
                        subtitle: Text(
                          _active
                              ? 'The product is available in your catalogue.'
                              : 'The product is deactivated.',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _active = value;
                          });
                        },
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _isSaving ? null : _saveProduct,
                        style: FilledButton.styleFrom(
                          backgroundColor: darkRed,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
