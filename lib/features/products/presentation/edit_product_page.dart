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
  late final TextEditingController _descriptionController;
  late final TextEditingController _brandController;
  late final TextEditingController _originCountryController;
  late final TextEditingController _originStateController;
  late final TextEditingController _quantityController;

  bool _isLoadingPage = true;
  bool _isSaving = false;
  bool _catchWeight = false;
  bool _active = true;

  late bool _usesCanonicalCatalogue;

  String? _selectedSpeciesId;
  String? _selectedParentProductId;
  String? _selectedMeatProductId;
  String? _selectedProductVariantId;

  String _temperatureState = 'chilled';
  String _priceBasis = 'kilogram';
  String _quantityUnit = 'kilogram';
  String _availabilityStatus = 'in_stock';

  List<Map<String, dynamic>> _species = [];
  List<Map<String, dynamic>> _parentProducts = [];
  List<Map<String, dynamic>> _meatProducts = [];
  List<Map<String, dynamic>> _productVariants = [];

  @override
  void initState() {
    super.initState();

    _skuController = TextEditingController(
      text: widget.product['sku']?.toString() ?? '',
    );

    _productNameController = TextEditingController(
      text: widget.product['product_name']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.product['description']?.toString() ?? '',
    );

    _brandController = TextEditingController(
      text: widget.product['brand']?.toString() ?? '',
    );

    _originCountryController = TextEditingController(
      text: widget.product['origin_country']?.toString() ?? '',
    );

    _originStateController = TextEditingController(
      text: widget.product['origin_state']?.toString() ?? '',
    );

    _quantityController = TextEditingController(
      text: widget.product['available_quantity']?.toString() ?? '',
    );

    _temperatureState =
        widget.product['temperature_state']?.toString() ?? 'chilled';

    _priceBasis = widget.product['price_basis']?.toString() ?? 'kilogram';

    _quantityUnit = widget.product['quantity_unit']?.toString() ?? 'kilogram';

    _availabilityStatus =
        widget.product['availability_status']?.toString() ?? 'in_stock';

    _catchWeight = widget.product['catch_weight'] as bool? ?? false;

    _active = widget.product['active'] as bool? ?? true;

    _usesCanonicalCatalogue = widget.product['product_variant_id'] != null;

    _selectedProductVariantId = widget.product['product_variant_id']
        ?.toString();

    _loadInitialData();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _productNameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _originCountryController.dispose();
    _originStateController.dispose();
    _quantityController.dispose();

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final speciesResponse = await Supabase.instance.client
          .from('species')
          .select('''
                id,
                name,
                slug,
                display_order
                ''')
          .eq('active', true)
          .order('display_order')
          .order('name');

      final species = List<Map<String, dynamic>>.from(speciesResponse);

      if (!_usesCanonicalCatalogue || _selectedProductVariantId == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _species = species;
          _isLoadingPage = false;
        });

        return;
      }

      //
      // Find the catalogue product currently
      // connected to this supplier listing.
      //
      final variantResponse = await Supabase.instance.client
          .from('product_variants')
          .select('''
                id,
                meat_product_id,
                variant_name,
                temperature_state,

                meat_products(
                  id,
                  species_id,
                  parent_product_id
                )
                ''')
          .eq('id', _selectedProductVariantId!)
          .single();

      final rawMeatProduct = variantResponse['meat_products'];

      if (rawMeatProduct is! Map) {
        throw Exception('The linked meat product could not be found.');
      }

      final meatProduct = Map<String, dynamic>.from(rawMeatProduct);

      final speciesId = meatProduct['species_id']?.toString();

      final parentProductId = meatProduct['parent_product_id']?.toString();

      final meatProductId = meatProduct['id']?.toString();

      if (speciesId == null ||
          parentProductId == null ||
          meatProductId == null) {
        throw Exception('The product catalogue relationship is incomplete.');
      }

      final parentResponse = await Supabase.instance.client
          .from('meat_products')
          .select('''
                id,
                name,
                slug,
                product_level,
                display_order
                ''')
          .eq('species_id', speciesId)
          .isFilter('parent_product_id', null)
          .eq('active', true)
          .order('display_order')
          .order('name');

      final childResponse = await Supabase.instance.client
          .from('meat_products')
          .select('''
                id,
                name,
                slug,
                product_level,
                display_order
                ''')
          .eq('parent_product_id', parentProductId)
          .eq('active', true)
          .order('display_order')
          .order('name');

      final variantsResponse = await Supabase.instance.client
          .from('product_variants')
          .select('''
                id,
                variant_name,
                temperature_state,
                bone_state,
                trim_specification,
                fat_specification,
                weight_min,
                weight_max,
                weight_unit,
                pack_size,
                pack_unit,
                grade,
                breed,
                halal_status,
                country_of_origin,
                specification_notes
                ''')
          .eq('meat_product_id', meatProductId)
          .eq('active', true)
          .order('variant_name');

      if (!mounted) {
        return;
      }

      setState(() {
        _species = species;

        _selectedSpeciesId = speciesId;

        _selectedParentProductId = parentProductId;

        _selectedMeatProductId = meatProductId;

        _parentProducts = List<Map<String, dynamic>>.from(parentResponse);

        _meatProducts = List<Map<String, dynamic>>.from(childResponse);

        _productVariants = List<Map<String, dynamic>>.from(variantsResponse);

        _isLoadingPage = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPage = false;
      });

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPage = false;
      });

      _showMessage(error.toString());
    }
  }

  Future<void> _loadParentProducts(String speciesId) async {
    setState(() {
      _selectedSpeciesId = speciesId;

      _selectedParentProductId = null;
      _selectedMeatProductId = null;
      _selectedProductVariantId = null;

      _parentProducts = [];
      _meatProducts = [];
      _productVariants = [];
    });

    try {
      final response = await Supabase.instance.client
          .from('meat_products')
          .select('''
                id,
                name,
                slug,
                product_level,
                display_order
                ''')
          .eq('species_id', speciesId)
          .isFilter('parent_product_id', null)
          .eq('active', true)
          .order('display_order')
          .order('name');

      if (!mounted) {
        return;
      }

      setState(() {
        _parentProducts = List<Map<String, dynamic>>.from(response);
      });
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _loadChildProducts(String parentProductId) async {
    setState(() {
      _selectedParentProductId = parentProductId;

      _selectedMeatProductId = null;
      _selectedProductVariantId = null;

      _meatProducts = [];
      _productVariants = [];
    });

    try {
      final response = await Supabase.instance.client
          .from('meat_products')
          .select('''
                id,
                name,
                slug,
                product_level,
                display_order
                ''')
          .eq('parent_product_id', parentProductId)
          .eq('active', true)
          .order('display_order')
          .order('name');

      if (!mounted) {
        return;
      }

      setState(() {
        _meatProducts = List<Map<String, dynamic>>.from(response);
      });
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _loadProductVariants(String meatProductId) async {
    setState(() {
      _selectedMeatProductId = meatProductId;

      _selectedProductVariantId = null;
      _productVariants = [];
    });

    try {
      final response = await Supabase.instance.client
          .from('product_variants')
          .select('''
                id,
                variant_name,
                temperature_state,
                bone_state,
                trim_specification,
                fat_specification,
                weight_min,
                weight_max,
                weight_unit,
                pack_size,
                pack_unit,
                grade,
                breed,
                halal_status,
                country_of_origin,
                specification_notes
                ''')
          .eq('meat_product_id', meatProductId)
          .eq('active', true)
          .order('variant_name');

      if (!mounted) {
        return;
      }

      setState(() {
        _productVariants = List<Map<String, dynamic>>.from(response);
      });
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    }
  }

  void _selectVariant(String? variantId) {
    if (variantId == null) {
      return;
    }

    final variant = _productVariants.firstWhere(
      (item) => item['id']?.toString() == variantId,
    );

    final variantName = variant['variant_name']?.toString();

    final temperature = variant['temperature_state']?.toString();

    final origin = variant['country_of_origin']?.toString();

    setState(() {
      _selectedProductVariantId = variantId;

      if (variantName != null && variantName.trim().isNotEmpty) {
        _productNameController.text = variantName;
      }

      if (temperature != null &&
          ['fresh', 'chilled', 'frozen'].contains(temperature)) {
        _temperatureState = temperature;
      }

      if (origin != null &&
          origin.trim().isNotEmpty &&
          _originCountryController.text.trim().isEmpty) {
        _originCountryController.text = origin;
      }
    });
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

    if (_usesCanonicalCatalogue) {
      if (_selectedSpeciesId == null) {
        _showMessage('Please select a species.');
        return;
      }

      if (_selectedParentProductId == null) {
        _showMessage('Please select a product family.');
        return;
      }

      if (_selectedMeatProductId == null) {
        _showMessage('Please select a meat product or cut.');
        return;
      }

      if (_selectedProductVariantId == null) {
        _showMessage('Please select a product variant.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final quantityText = _quantityController.text.trim();

      final updateData = <String, dynamic>{
        'sku': _skuController.text.trim(),

        'product_name': _productNameController.text.trim(),

        'description': _emptyToNull(_descriptionController.text),

        'brand': _emptyToNull(_brandController.text),

        'origin_country': _emptyToNull(_originCountryController.text),

        'origin_state': _emptyToNull(_originStateController.text),

        'temperature_state': _temperatureState,

        'price_basis': _priceBasis,

        'catch_weight': _catchWeight,

        'available_quantity': quantityText.isEmpty
            ? null
            : double.parse(quantityText),

        'quantity_unit': _quantityUnit,

        'availability_status': _availabilityStatus,

        'active': _active,

        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_usesCanonicalCatalogue) {
        updateData['product_variant_id'] = _selectedProductVariantId;

        updateData['animal_type_id'] = null;

        updateData['cut_id'] = null;
      }

      await Supabase.instance.client
          .from('products')
          .update(updateData)
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

      var message = error.message;

      if (error.code == '23505') {
        message = 'This SKU already exists for your supplier business.';
      }

      _showMessage(message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Something went wrong while updating the product: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  String _variantLabel(Map<String, dynamic> variant) {
    final variantName = variant['variant_name']?.toString();

    if (variantName != null && variantName.trim().isNotEmpty) {
      return variantName;
    }

    final parts = <String>[];

    final temperature = variant['temperature_state']?.toString();

    final boneState = variant['bone_state']?.toString();

    if (temperature != null && temperature.isNotEmpty) {
      parts.add(temperature[0].toUpperCase() + temperature.substring(1));
    }

    if (boneState == 'bone_in') {
      parts.add('Bone-in');
    }

    if (boneState == 'boneless') {
      parts.add('Boneless');
    }

    if (parts.isEmpty) {
      return 'Unnamed variant';
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF741C1C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Edit Product',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoadingPage
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(18),
                    ),
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

                            const SizedBox(height: 10),

                            Text(
                              _usesCanonicalCatalogue
                                  ? 'This product is linked to the marketplace catalogue.'
                                  : 'This is a legacy product. Supplier listing information can still be edited.',
                              style: const TextStyle(
                                color: Color(0xFF5E5E5E),
                                height: 1.4,
                              ),
                            ),

                            if (_usesCanonicalCatalogue) ...[
                              const SizedBox(height: 30),

                              const Text(
                                'Meat catalogue',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 18),

                              DropdownButtonFormField<String>(
                                key: ValueKey('species-$_selectedSpeciesId'),
                                initialValue: _selectedSpeciesId,
                                decoration: const InputDecoration(
                                  labelText: 'Species',
                                  border: OutlineInputBorder(),
                                ),
                                items: _species.map((species) {
                                  return DropdownMenuItem<String>(
                                    value: species['id'] as String,
                                    child: Text(species['name'] as String),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    _loadParentProducts(value);
                                  }
                                },
                              ),

                              const SizedBox(height: 18),

                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'parent-$_selectedSpeciesId-$_selectedParentProductId',
                                ),
                                initialValue: _selectedParentProductId,
                                decoration: const InputDecoration(
                                  labelText: 'Product family / parent cut',
                                  hintText: 'Example: Blade',
                                  border: OutlineInputBorder(),
                                ),
                                items: _parentProducts.map((product) {
                                  return DropdownMenuItem<String>(
                                    value: product['id'] as String,
                                    child: Text(product['name'] as String),
                                  );
                                }).toList(),
                                onChanged: _selectedSpeciesId == null
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          _loadChildProducts(value);
                                        }
                                      },
                              ),

                              const SizedBox(height: 18),

                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'meat-product-$_selectedParentProductId-$_selectedMeatProductId',
                                ),
                                initialValue: _selectedMeatProductId,
                                decoration: const InputDecoration(
                                  labelText: 'Meat product / cut',
                                  hintText: 'Example: Oyster Blade',
                                  border: OutlineInputBorder(),
                                ),
                                items: _meatProducts.map((product) {
                                  return DropdownMenuItem<String>(
                                    value: product['id'] as String,
                                    child: Text(product['name'] as String),
                                  );
                                }).toList(),
                                onChanged: _selectedParentProductId == null
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          _loadProductVariants(value);
                                        }
                                      },
                              ),

                              const SizedBox(height: 18),

                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'variant-$_selectedMeatProductId-$_selectedProductVariantId',
                                ),
                                initialValue: _selectedProductVariantId,
                                decoration: const InputDecoration(
                                  labelText: 'Product variant / specification',
                                  border: OutlineInputBorder(),
                                ),
                                items: _productVariants.map((variant) {
                                  return DropdownMenuItem<String>(
                                    value: variant['id'] as String,
                                    child: Text(_variantLabel(variant)),
                                  );
                                }).toList(),
                                onChanged: _selectedMeatProductId == null
                                    ? null
                                    : _selectVariant,
                              ),

                              const SizedBox(height: 32),

                              const Divider(),
                            ],

                            const SizedBox(height: 28),

                            const Text(
                              'Supplier listing',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _skuController,
                              decoration: const InputDecoration(
                                labelText: 'Supplier SKU',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                return _requiredValidator(
                                  value,
                                  'a supplier SKU',
                                );
                              },
                            ),

                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _productNameController,
                              decoration: const InputDecoration(
                                labelText: 'Supplier product name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                return _requiredValidator(
                                  value,
                                  'a product name',
                                );
                              },
                            ),

                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _brandController,
                              decoration: const InputDecoration(
                                labelText: 'Brand (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _descriptionController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
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
                                  value: 'fresh',
                                  child: Text('Fresh'),
                                ),
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

                            DropdownButtonFormField<String>(
                              initialValue: _priceBasis,
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
                                  setState(() {
                                    _priceBasis = value;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 18),

                            SwitchListTile(
                              value: _catchWeight,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Catch-weight product'),
                              subtitle: const Text(
                                'The final supplied weight may differ from the ordered estimate.',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _catchWeight = value;
                                });
                              },
                            ),

                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              initialValue: _quantityUnit,
                              decoration: const InputDecoration(
                                labelText: 'Quantity unit',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'kilogram',
                                  child: Text('Kilograms'),
                                ),
                                DropdownMenuItem(
                                  value: 'carton',
                                  child: Text('Cartons'),
                                ),
                                DropdownMenuItem(
                                  value: 'unit',
                                  child: Text('Units'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _quantityUnit = value;
                                  });
                                }
                              },
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

                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _originCountryController,
                              decoration: const InputDecoration(
                                labelText: 'Country of origin (optional)',
                                hintText: 'Australia',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _originStateController,
                              decoration: const InputDecoration(
                                labelText: 'State of origin (optional)',
                                hintText: 'NSW',
                                border: OutlineInputBorder(),
                              ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
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
