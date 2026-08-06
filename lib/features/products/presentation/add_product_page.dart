import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  final _skuController = TextEditingController();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _originCountryController = TextEditingController();
  final _originStateController = TextEditingController();
  final _availableQuantityController = TextEditingController();

  bool _isLoadingPage = true;
  bool _isSaving = false;
  bool _catchWeight = false;

  String? _supplierBusinessId;
  String? _selectedAnimalTypeId;
  String? _selectedCutId;

  String _temperatureState = 'chilled';
  String _priceBasis = 'kilogram';
  String _quantityUnit = 'kilogram';
  String _availabilityStatus = 'in_stock';

  List<Map<String, dynamic>> _animalTypes = [];
  List<Map<String, dynamic>> _cuts = [];

  @override
  void initState() {
    super.initState();
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
    _availableQuantityController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id, businesses(business_type)')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final business = Map<String, dynamic>.from(
        membership['businesses'] as Map,
      );

      if (business['business_type'] != 'supplier') {
        throw Exception('Only approved supplier accounts can create products.');
      }

      final animalTypesResponse = await Supabase.instance.client
          .from('animal_types')
          .select('id, name')
          .eq('active', true)
          .order('sort_order');

      if (!mounted) {
        return;
      }

      setState(() {
        _supplierBusinessId = membership['business_id'] as String;
        _animalTypes = List<Map<String, dynamic>>.from(animalTypesResponse);
        _isLoadingPage = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPage = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPage = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadCuts(String animalTypeId) async {
    setState(() {
      _selectedAnimalTypeId = animalTypeId;
      _selectedCutId = null;
      _cuts = [];
    });

    try {
      final cutsResponse = await Supabase.instance.client
          .from('cuts')
          .select('id, name')
          .eq('animal_type_id', animalTypeId)
          .eq('active', true)
          .order('sort_order');

      if (!mounted) {
        return;
      }

      setState(() {
        _cuts = List<Map<String, dynamic>>.from(cutsResponse);
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName.';
    }

    return null;
  }

  String? _validateQuantity(String? value) {
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

    if (_selectedAnimalTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an animal type.')),
      );

      return;
    }

    if (_selectedCutId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a cut.')));

      return;
    }

    if (_supplierBusinessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The supplier business could not be identified.'),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final quantityText = _availableQuantityController.text.trim();

      await Supabase.instance.client.from('products').insert({
        'supplier_business_id': _supplierBusinessId,
        'animal_type_id': _selectedAnimalTypeId,
        'cut_id': _selectedCutId,
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
        'active': true,
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product created successfully.')),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      String message = error.message;

      if (error.code == '23505') {
        message = 'This SKU already exists for your supplier business.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while creating the product.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
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
          'Add Product',
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
                              'Product information',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Enter the basic details for this product. '
                              'Pricing and photos will be added separately.',
                              style: TextStyle(color: Color(0xFF5E5E5E)),
                            ),
                            const SizedBox(height: 30),
                            TextFormField(
                              controller: _skuController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Supplier SKU',
                                hintText: 'Example: BEEF-RIBEYE-001',
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
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Product name',
                                hintText: 'Example: Chilled Beef Rib Eye',
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
                            DropdownButtonFormField<String>(
                              initialValue: _selectedAnimalTypeId,
                              decoration: const InputDecoration(
                                labelText: 'Animal type',
                                border: OutlineInputBorder(),
                              ),
                              items: _animalTypes.map((animalType) {
                                return DropdownMenuItem<String>(
                                  value: animalType['id'] as String,
                                  child: Text(animalType['name'] as String),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _loadCuts(value);
                                }
                              },
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCutId,
                              decoration: const InputDecoration(
                                labelText: 'Cut',
                                border: OutlineInputBorder(),
                              ),
                              items: _cuts.map((cut) {
                                return DropdownMenuItem<String>(
                                  value: cut['id'] as String,
                                  child: Text(cut['name'] as String),
                                );
                              }).toList(),
                              onChanged: _selectedAnimalTypeId == null
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedCutId = value;
                                      });
                                    },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _brandController,
                              textInputAction: TextInputAction.next,
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
                                'The final supplied weight may differ '
                                'from the ordered estimate.',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _catchWeight = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _availableQuantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Available quantity (optional)',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateQuantity,
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
                              textInputAction: TextInputAction.next,
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
                            const SizedBox(height: 30),
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
                                      'Create Product',
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
