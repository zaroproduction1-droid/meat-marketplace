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

  late final TextEditingController _marblingScoreController;
  late final TextEditingController _gradeController;
  late final TextEditingController _breedProgramController;
  late final TextEditingController _pieceWeightMinController;
  late final TextEditingController _pieceWeightMaxController;
  late final TextEditingController _cartonWeightController;
  late final TextEditingController _piecesPerCartonController;
  late final TextEditingController _packagingTypeController;
  late final TextEditingController _trimSpecificationController;
  late final TextEditingController _fatSpecificationController;
  late final TextEditingController _supplierSpecificationController;

  bool _isLoadingPage = true;
  bool _isLoadingCatalogue = false;
  bool _isLoadingVariants = false;
  bool _isSaving = false;

  bool _catchWeight = false;
  bool _active = true;

  bool _usesCanonicalCatalogue = false;
  bool _usesSpecGradeCatalogue = false;

  String? _selectedAnimalId;
  String? _selectedSectionId;
  String? _selectedSpecificationId;
  String? _selectedGradeId;

  bool _isLoadingSections = false;
  bool _isLoadingSpecifications = false;
  bool _isLoadingGrades = false;

  List<Map<String, dynamic>> _animals = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _specifications = [];
  List<Map<String, dynamic>> _grades = [];

  String? _selectedSpeciesId;
  String? _selectedMeatProductId;
  String? _selectedProductVariantId;

  String _temperatureState = 'chilled';
  String _priceBasis = 'kilogram';
  String _quantityUnit = 'kilogram';
  String _availabilityStatus = 'in_stock';

  String _pieceWeightUnit = 'kg';
  String _cartonWeightUnit = 'kg';
  String _halalStatus = 'not_specified';

  List<Map<String, dynamic>> _species = [];
  List<Map<String, dynamic>> _catalogueProducts = [];
  List<Map<String, dynamic>> _productVariants = [];

  bool _isLoadingPricing = true;
  bool _isSavingPrice = false;
  String? _pricingError;
  String? _supplierBusinessId;

  List<Map<String, dynamic>> _priceLists = [];
  List<Map<String, dynamic>> _productPrices = [];
  List<Map<String, dynamic>> _approvedCustomers = [];

  @override
  void initState() {
    super.initState();

    _skuController = TextEditingController();
    _productNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _brandController = TextEditingController();
    _originCountryController = TextEditingController();
    _originStateController = TextEditingController();
    _quantityController = TextEditingController();

    _marblingScoreController = TextEditingController();
    _gradeController = TextEditingController();
    _breedProgramController = TextEditingController();
    _pieceWeightMinController = TextEditingController();
    _pieceWeightMaxController = TextEditingController();
    _cartonWeightController = TextEditingController();
    _piecesPerCartonController = TextEditingController();
    _packagingTypeController = TextEditingController();
    _trimSpecificationController = TextEditingController();
    _fatSpecificationController = TextEditingController();
    _supplierSpecificationController = TextEditingController();

    _applyProductData(widget.product);
    _loadInitialData();
    _loadPricing();
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

    _marblingScoreController.dispose();
    _gradeController.dispose();
    _breedProgramController.dispose();
    _pieceWeightMinController.dispose();
    _pieceWeightMaxController.dispose();
    _cartonWeightController.dispose();
    _piecesPerCartonController.dispose();
    _packagingTypeController.dispose();
    _trimSpecificationController.dispose();
    _fatSpecificationController.dispose();
    _supplierSpecificationController.dispose();

    super.dispose();
  }

  void _applyProductData(Map<String, dynamic> product) {
    _skuController.text = product['sku']?.toString() ?? '';
    _productNameController.text = product['product_name']?.toString() ?? '';
    _descriptionController.text = product['description']?.toString() ?? '';
    _brandController.text = product['brand']?.toString() ?? '';
    _originCountryController.text = product['origin_country']?.toString() ?? '';
    _originStateController.text = product['origin_state']?.toString() ?? '';
    _quantityController.text = product['available_quantity']?.toString() ?? '';

    _marblingScoreController.text = product['marbling_score']?.toString() ?? '';
    _gradeController.text = product['grade']?.toString() ?? '';
    _breedProgramController.text = product['breed_program']?.toString() ?? '';

    _pieceWeightMinController.text =
        product['piece_weight_min']?.toString() ?? '';
    _pieceWeightMaxController.text =
        product['piece_weight_max']?.toString() ?? '';

    _cartonWeightController.text = product['carton_weight']?.toString() ?? '';

    _piecesPerCartonController.text =
        product['pieces_per_carton']?.toString() ?? '';

    _packagingTypeController.text = product['packaging_type']?.toString() ?? '';

    _trimSpecificationController.text =
        product['trim_specification']?.toString() ?? '';

    _fatSpecificationController.text =
        product['fat_specification']?.toString() ?? '';

    _supplierSpecificationController.text =
        product['supplier_specification']?.toString() ?? '';

    final temperature = product['temperature_state']?.toString();

    if (temperature != null &&
        ['fresh', 'chilled', 'frozen'].contains(temperature)) {
      _temperatureState = temperature;
    }

    final priceBasis = product['price_basis']?.toString();

    if (priceBasis != null &&
        ['kilogram', 'carton', 'unit'].contains(priceBasis)) {
      _priceBasis = priceBasis;
    }

    final quantityUnit = product['quantity_unit']?.toString();

    if (quantityUnit != null &&
        ['kilogram', 'carton', 'unit'].contains(quantityUnit)) {
      _quantityUnit = quantityUnit;
    }

    final availability = product['availability_status']?.toString();

    if (availability != null &&
        [
          'in_stock',
          'limited',
          'out_of_stock',
          'made_to_order',
        ].contains(availability)) {
      _availabilityStatus = availability;
    }

    final pieceWeightUnit = product['piece_weight_unit']?.toString();

    if (pieceWeightUnit != null &&
        ['kg', 'g'].contains(pieceWeightUnit.toLowerCase())) {
      _pieceWeightUnit = pieceWeightUnit.toLowerCase();
    }

    final cartonWeightUnit = product['carton_weight_unit']?.toString();

    if (cartonWeightUnit != null &&
        ['kg', 'g'].contains(cartonWeightUnit.toLowerCase())) {
      _cartonWeightUnit = cartonWeightUnit.toLowerCase();
    }

    final halalStatus = product['halal_status']?.toString();

    if (halalStatus != null &&
        ['halal', 'not_halal', 'not_specified'].contains(halalStatus)) {
      _halalStatus = halalStatus;
    } else {
      _halalStatus = 'not_specified';
    }

    _catchWeight = product['catch_weight'] as bool? ?? false;
    _active = product['active'] as bool? ?? true;

    _usesSpecGradeCatalogue = product['meat_specification_id'] != null;

    _selectedAnimalId = product['meat_animal_id']?.toString();
    _selectedSectionId = product['meat_section_id']?.toString();
    _selectedSpecificationId = product['meat_specification_id']?.toString();
    _selectedGradeId = product['meat_grade_id']?.toString();

    _usesCanonicalCatalogue =
        !_usesSpecGradeCatalogue && product['product_variant_id'] != null;

    _selectedProductVariantId = product['product_variant_id']?.toString();
  }

  Future<void> _loadInitialData() async {
    try {
      final productId = widget.product['id']?.toString();

      if (productId == null || productId.isEmpty) {
        throw Exception('The product ID could not be identified.');
      }

      final productResponse = await Supabase.instance.client
          .from('products')
          .select('*')
          .eq('id', productId)
          .single();

      _applyProductData(Map<String, dynamic>.from(productResponse));

      if (_usesSpecGradeCatalogue) {
        await _loadSpecGradeInitialData(productId);
        return;
      }

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

      final variantResponse = await Supabase.instance.client
          .from('product_variants')
          .select('''
            id,
            meat_product_id,
            variant_name,
            temperature_state
          ''')
          .eq('id', _selectedProductVariantId!)
          .single();

      final meatProductId = variantResponse['meat_product_id']?.toString();

      if (meatProductId == null) {
        throw Exception('The linked catalogue product could not be found.');
      }

      final pathResponse = await Supabase.instance.client
          .from('meat_product_catalogue_paths')
          .select('''
            id,
            species_id,
            species_name,
            parent_product_id,
            name,
            slug,
            product_level,
            depth,
            catalogue_path
          ''')
          .eq('id', meatProductId)
          .single();

      final speciesId = pathResponse['species_id']?.toString();

      if (speciesId == null) {
        throw Exception('The catalogue species could not be identified.');
      }

      final catalogueResponse = await Supabase.instance.client
          .from('meat_product_catalogue_paths')
          .select('''
            id,
            species_id,
            species_name,
            parent_product_id,
            name,
            slug,
            product_level,
            depth,
            catalogue_path
          ''')
          .eq('species_id', speciesId)
          .eq('active', true)
          .order('catalogue_path');

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
        _selectedMeatProductId = meatProductId;

        _catalogueProducts = List<Map<String, dynamic>>.from(catalogueResponse);

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

  Future<void> _loadSpecGradeInitialData(String productId) async {
    final animalsResponse = await Supabase.instance.client
        .from('meat_animals')
        .select('id, code, name, display_order')
        .eq('is_active', true)
        .order('display_order');

    final sectionsResponse = await Supabase.instance.client
        .from('meat_sections')
        .select('id, animal_id, code, name, is_miscellaneous, display_order')
        .eq('animal_id', _selectedAnimalId!)
        .eq('is_active', true)
        .order('display_order');

    final specificationsResponse = await Supabase.instance.client
        .from('meat_specifications')
        .select(
          'id, animal_id, section_id, name, ham_code, specification_type, approval_status, display_order',
        )
        .eq('section_id', _selectedSectionId!)
        .eq('is_active', true)
        .order('display_order')
        .order('name');

    final mappingResponse = await Supabase.instance.client
        .from('meat_specification_grades')
        .select('grade_id, display_order')
        .eq('specification_id', _selectedSpecificationId!)
        .eq('is_active', true)
        .order('display_order');

    final gradeIds = List<Map<String, dynamic>>.from(
      mappingResponse,
    ).map((row) => row['grade_id'].toString()).toList();

    List<Map<String, dynamic>> grades = [];
    if (gradeIds.isNotEmpty) {
      final gradeResponse = await Supabase.instance.client
          .from('meat_grades')
          .select('id, code, name, description, display_order')
          .inFilter('id', gradeIds)
          .eq('is_active', true)
          .order('display_order');
      grades = List<Map<String, dynamic>>.from(gradeResponse);
    }

    if (_selectedGradeId != null) {
      for (final grade in grades) {
        if (grade['id']?.toString() == _selectedGradeId) {
          _gradeController.text = '${grade['code']} - ${grade['name']}';
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _animals = List<Map<String, dynamic>>.from(animalsResponse);
      _sections = List<Map<String, dynamic>>.from(sectionsResponse);
      _specifications = List<Map<String, dynamic>>.from(specificationsResponse);
      _grades = grades;
      _isLoadingPage = false;
    });
  }

  Future<void> _selectAnimalNew(String? animalId) async {
    if (animalId == null) return;

    setState(() {
      _selectedAnimalId = animalId;
      _selectedSectionId = null;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
      _sections = [];
      _specifications = [];
      _grades = [];
      _gradeController.clear();
      _isLoadingSections = true;
    });

    try {
      final rows = await Supabase.instance.client
          .from('meat_sections')
          .select('id, animal_id, code, name, is_miscellaneous, display_order')
          .eq('animal_id', animalId)
          .eq('is_active', true)
          .order('display_order');

      if (!mounted) return;
      setState(() {
        _sections = List<Map<String, dynamic>>.from(rows);
        _isLoadingSections = false;
      });
    } catch (error) {
      if (mounted) setState(() => _isLoadingSections = false);
      _showMessage('Unable to load sections: $error');
    }
  }

  Future<void> _selectSectionNew(String? sectionId) async {
    if (sectionId == null) return;

    setState(() {
      _selectedSectionId = sectionId;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
      _specifications = [];
      _grades = [];
      _gradeController.clear();
      _isLoadingSpecifications = true;
    });

    await _loadSpecificationsNew();
  }

  Future<void> _loadSpecificationsNew({String? selectId}) async {
    final sectionId = _selectedSectionId;
    if (sectionId == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('meat_specifications')
          .select(
            'id, animal_id, section_id, name, ham_code, specification_type, approval_status, display_order',
          )
          .eq('section_id', sectionId)
          .eq('is_active', true)
          .order('display_order')
          .order('name');

      if (!mounted) return;
      setState(() {
        _specifications = List<Map<String, dynamic>>.from(rows);
        _selectedSpecificationId = selectId;
        _selectedGradeId = null;
        _grades = [];
        _gradeController.clear();
        _isLoadingSpecifications = false;
      });

      if (selectId != null) {
        await _selectSpecificationNew(selectId);
      }
    } catch (error) {
      if (mounted) setState(() => _isLoadingSpecifications = false);
      _showMessage('Unable to load specifications: $error');
    }
  }

  Future<void> _selectSpecificationNew(String? specificationId) async {
    if (specificationId == null) return;

    final selectedSpecification = _specifications.firstWhere(
      (row) => row['id']?.toString() == specificationId,
    );

    setState(() {
      _selectedSpecificationId = specificationId;
      _selectedGradeId = null;
      _grades = [];
      _gradeController.clear();
      _productNameController.text =
          selectedSpecification['name']?.toString() ?? '';
      _isLoadingGrades = true;
    });

    try {
      final mappings = await Supabase.instance.client
          .from('meat_specification_grades')
          .select('grade_id, display_order')
          .eq('specification_id', specificationId)
          .eq('is_active', true)
          .order('display_order');

      final ids = List<Map<String, dynamic>>.from(
        mappings,
      ).map((row) => row['grade_id'].toString()).toList();

      List<Map<String, dynamic>> grades = [];
      if (ids.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('meat_grades')
            .select('id, code, name, description, display_order')
            .inFilter('id', ids)
            .eq('is_active', true)
            .order('display_order');
        grades = List<Map<String, dynamic>>.from(rows);
      }

      if (!mounted) return;
      setState(() {
        _grades = grades;
        _isLoadingGrades = false;
      });
    } catch (error) {
      if (mounted) setState(() => _isLoadingGrades = false);
      _showMessage('Unable to load categories: $error');
    }
  }

  void _selectGradeNew(String? gradeId) {
    if (gradeId == null) return;

    final grade = _grades.firstWhere((row) => row['id']?.toString() == gradeId);

    setState(() {
      _selectedGradeId = gradeId;
      _gradeController.text = '${grade['code']} - ${grade['name']}';
    });
  }

  String _specificationLabelNew(Map<String, dynamic> row) {
    final custom = row['specification_type'] == 'supplier_custom';
    final base = row['name'].toString();
    return custom ? '$base • Custom' : base;
  }

  String _gradeLabelNew(Map<String, dynamic> row) {
    return '${row['code']} — ${row['name']}';
  }

  Future<void> _addManualSpecificationNew() async {
    final supplierId =
        _supplierBusinessId ??
        widget.product['supplier_business_id']?.toString();

    if (supplierId == null ||
        _selectedAnimalId == null ||
        _selectedSectionId == null) {
      _showMessage('Select the animal and section first.');
      return;
    }

    final nameController = TextEditingController();
    final detailsController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Specification Manually'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Specification name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: detailsController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Specification details (optional)',
                    hintText:
                        'Trim, preparation, trade code or other defining details',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(dialogContext, {
                  'name': name,
                  'details': detailsController.text.trim(),
                });
              },
              child: const Text('Add Specification'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    detailsController.dispose();

    if (result == null) return;

    try {
      setState(() => _isLoadingSpecifications = true);

      final created = await Supabase.instance.client.rpc(
        'create_supplier_custom_specification',
        params: {
          'p_supplier_business_id': supplierId,
          'p_animal_id': _selectedAnimalId,
          'p_section_id': _selectedSectionId,
          'p_name': result['name'],
          'p_description': null,
          'p_specification_notes': result['details']!.isEmpty
              ? null
              : result['details'],
        },
      );

      final row = Map<String, dynamic>.from(created as Map);
      await _loadSpecificationsNew(selectId: row['id'].toString());

      _showMessage('Custom specification added.');
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _isLoadingSpecifications = false);
      _showMessage(error.message);
    }
  }

  Future<void> _loadCatalogueProducts(String speciesId) async {
    setState(() {
      _selectedSpeciesId = speciesId;

      _selectedMeatProductId = null;
      _selectedProductVariantId = null;

      _catalogueProducts = [];
      _productVariants = [];

      _isLoadingCatalogue = true;
      _isLoadingVariants = false;
    });

    try {
      final response = await Supabase.instance.client
          .from('meat_product_catalogue_paths')
          .select('''
            id,
            species_id,
            species_name,
            parent_product_id,
            name,
            slug,
            product_level,
            depth,
            catalogue_path
          ''')
          .eq('species_id', speciesId)
          .eq('active', true)
          .order('catalogue_path');

      if (!mounted) {
        return;
      }

      setState(() {
        _catalogueProducts = List<Map<String, dynamic>>.from(response);

        _isLoadingCatalogue = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCatalogue = false;
      });

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCatalogue = false;
      });

      _showMessage('Unable to load catalogue products: $error');
    }
  }

  Future<void> _loadProductVariants(String meatProductId) async {
    setState(() {
      _selectedMeatProductId = meatProductId;

      _selectedProductVariantId = null;
      _productVariants = [];

      _isLoadingVariants = true;
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

        _isLoadingVariants = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingVariants = false;
      });

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingVariants = false;
      });

      _showMessage('Unable to load product variants: $error');
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

    final trimSpecification = variant['trim_specification']?.toString();

    final fatSpecification = variant['fat_specification']?.toString();

    final grade = variant['grade']?.toString();

    final breed = variant['breed']?.toString();

    final halalStatus = variant['halal_status']?.toString();

    final weightMin = variant['weight_min'];
    final weightMax = variant['weight_max'];

    final weightUnit = variant['weight_unit']?.toString();

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

      if (trimSpecification != null &&
          trimSpecification.trim().isNotEmpty &&
          _trimSpecificationController.text.trim().isEmpty) {
        _trimSpecificationController.text = trimSpecification;
      }

      if (fatSpecification != null &&
          fatSpecification.trim().isNotEmpty &&
          _fatSpecificationController.text.trim().isEmpty) {
        _fatSpecificationController.text = fatSpecification;
      }

      if (grade != null &&
          grade.trim().isNotEmpty &&
          _gradeController.text.trim().isEmpty) {
        _gradeController.text = grade;
      }

      if (breed != null &&
          breed.trim().isNotEmpty &&
          _breedProgramController.text.trim().isEmpty) {
        _breedProgramController.text = breed;
      }

      if (halalStatus != null &&
          ['halal', 'not_halal', 'not_specified'].contains(halalStatus) &&
          _halalStatus == 'not_specified') {
        _halalStatus = halalStatus;
      }

      if (weightMin != null && _pieceWeightMinController.text.trim().isEmpty) {
        _pieceWeightMinController.text = weightMin.toString();
      }

      if (weightMax != null && _pieceWeightMaxController.text.trim().isEmpty) {
        _pieceWeightMaxController.text = weightMax.toString();
      }

      if (weightUnit != null &&
          ['kg', 'g'].contains(weightUnit.toLowerCase())) {
        _pieceWeightUnit = weightUnit.toLowerCase();
      }
    });
  }

  String _catalogueProductLabel(Map<String, dynamic> product) {
    final path = product['catalogue_path']?.toString();

    if (path != null && path.trim().isNotEmpty) {
      return path;
    }

    return product['name']?.toString() ?? 'Unnamed catalogue product';
  }

  String? _selectedCataloguePath() {
    final selectedId = _selectedMeatProductId;

    if (selectedId == null) {
      return null;
    }

    for (final product in _catalogueProducts) {
      if (product['id']?.toString() == selectedId) {
        return _catalogueProductLabel(product);
      }
    }

    return null;
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName.';
    }

    return null;
  }

  String? _validateOptionalNonNegativeNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = double.tryParse(value.trim());

    if (number == null || number < 0) {
      return 'Enter a valid number of 0 or more.';
    }

    return null;
  }

  String? _validateOptionalPositiveInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = int.tryParse(value.trim());

    if (number == null || number <= 0) {
      return 'Enter a whole number greater than 0.';
    }

    return null;
  }

  bool _validatePieceWeightRange() {
    final minText = _pieceWeightMinController.text.trim();

    final maxText = _pieceWeightMaxController.text.trim();

    if (minText.isEmpty || maxText.isEmpty) {
      return true;
    }

    final min = double.tryParse(minText);

    final max = double.tryParse(maxText);

    if (min == null || max == null) {
      return true;
    }

    if (min > max) {
      _showMessage(
        'Minimum piece weight cannot be greater than maximum piece weight.',
      );

      return false;
    }

    return true;
  }

  double? _optionalDouble(TextEditingController controller) {
    final value = controller.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return double.parse(value);
  }

  int? _optionalInt(TextEditingController controller) {
    final value = controller.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return int.parse(value);
  }

  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_validatePieceWeightRange()) {
      return;
    }

    if (_usesSpecGradeCatalogue) {
      if (_selectedAnimalId == null ||
          _selectedSectionId == null ||
          _selectedSpecificationId == null ||
          _selectedGradeId == null) {
        _showMessage(
          'Please select the animal, section, specification and AUS-MEAT category.',
        );
        return;
      }
    }

    if (_usesCanonicalCatalogue) {
      if (_selectedSpeciesId == null) {
        _showMessage('Please select a species.');
        return;
      }

      if (_selectedMeatProductId == null) {
        _showMessage('Please select a catalogue product or cut.');
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

      final pieceWeightMin = _optionalDouble(_pieceWeightMinController);

      final pieceWeightMax = _optionalDouble(_pieceWeightMaxController);

      final cartonWeight = _optionalDouble(_cartonWeightController);

      final piecesPerCarton = _optionalInt(_piecesPerCartonController);

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

        'marbling_score': _emptyToNull(_marblingScoreController.text),

        'grade': _emptyToNull(_gradeController.text),

        'breed_program': _emptyToNull(_breedProgramController.text),

        'piece_weight_min': pieceWeightMin,

        'piece_weight_max': pieceWeightMax,

        'piece_weight_unit': pieceWeightMin == null && pieceWeightMax == null
            ? null
            : _pieceWeightUnit,

        'carton_weight': cartonWeight,

        'carton_weight_unit': cartonWeight == null ? null : _cartonWeightUnit,

        'pieces_per_carton': piecesPerCarton,

        'packaging_type': _emptyToNull(_packagingTypeController.text),

        'trim_specification': _emptyToNull(_trimSpecificationController.text),

        'fat_specification': _emptyToNull(_fatSpecificationController.text),

        'halal_status': _halalStatus,

        'supplier_specification': _emptyToNull(
          _supplierSpecificationController.text,
        ),

        'active': _active,

        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_usesSpecGradeCatalogue) {
        updateData['meat_animal_id'] = _selectedAnimalId;
        updateData['meat_section_id'] = _selectedSectionId;
        updateData['meat_specification_id'] = _selectedSpecificationId;
        updateData['meat_grade_id'] = _selectedGradeId;
        updateData['product_variant_id'] = null;
        updateData['animal_type_id'] = null;
        updateData['cut_id'] = null;

        updateData['price_basis'] = 'kilogram';
        updateData['order_unit'] = 'carton';
        updateData['weight_type'] = 'catch_weight';
        updateData['catch_weight'] = true;
        updateData['quantity_unit'] = 'carton';
      }

      if (_usesCanonicalCatalogue) {
        updateData['product_variant_id'] = _selectedProductVariantId;

        updateData['animal_type_id'] = null;

        updateData['cut_id'] = null;
      }

      await Supabase.instance.client
          .from('products')
          .update(updateData)
          .eq('id', widget.product['id']);

      if (_usesSpecGradeCatalogue) {
        final productId = widget.product['id']?.toString();

        if (productId != null) {
          final existingOffer = await Supabase.instance.client
              .from('supplier_spec_grade_offers')
              .select('id')
              .eq('product_id', productId)
              .maybeSingle();

          if (existingOffer != null) {
            await Supabase.instance.client
                .from('supplier_spec_grade_offers')
                .update({
                  'specification_id': _selectedSpecificationId,
                  'grade_id': _selectedGradeId,
                  'supplier_sku': _skuController.text.trim(),
                  'supplier_product_name': _productNameController.text.trim(),
                  'is_available': _availabilityStatus != 'out_of_stock',
                  'is_active': _active,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('id', existingOffer['id']);
          }
        }
      }

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

  Future<void> _loadPricing() async {
    if (mounted) {
      setState(() {
        _isLoadingPricing = true;
        _pricingError = null;
      });
    }

    try {
      final productId = widget.product['id']?.toString();

      if (productId == null || productId.isEmpty) {
        throw Exception('The product ID could not be identified.');
      }

      final product = await Supabase.instance.client
          .from('products')
          .select('supplier_business_id')
          .eq('id', productId)
          .single();

      final supplierBusinessId = product['supplier_business_id']?.toString();

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception(
          'The supplier business for this product could not be identified.',
        );
      }

      final priceListsResponse = await Supabase.instance.client
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
          .order('name');

      final approvedCustomersResponse = await Supabase.instance.client
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

      final pricesResponse = await Supabase.instance.client
          .from('product_prices')
          .select('''
            id,
            product_id,
            price_list_id,
            amount,
            price_basis,
            minimum_quantity,
            active
          ''')
          .eq('product_id', productId);

      if (!mounted) {
        return;
      }

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _priceLists = List<Map<String, dynamic>>.from(priceListsResponse);
        _productPrices = List<Map<String, dynamic>>.from(pricesResponse);
        _approvedCustomers = List<Map<String, dynamic>>.from(
          approvedCustomersResponse,
        );
        _isLoadingPricing = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pricingError = error.message;
        _isLoadingPricing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pricingError = error.toString();
        _isLoadingPricing = false;
      });
    }
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

  Map<String, dynamic>? _priceForList(String priceListId) {
    for (final price in _productPrices) {
      if (price['price_list_id']?.toString() == priceListId &&
          price['active'] == true) {
        return price;
      }
    }

    return null;
  }

  String _formatMoneyValue(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return 'Not set';
    }

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

  String _pricingBasisLabel(String? basis) {
    switch (basis) {
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

  String _visibilityLabel(String visibility) {
    switch (visibility) {
      case 'public':
        return 'Standard Price';
      case 'approved_customers':
        return 'Trade Price';
      case 'private':
        return 'Customer-Specific Price';
      default:
        return visibility;
    }
  }

  Future<Map<String, dynamic>?> _ensurePriceList({
    required String visibility,
    required String defaultName,
  }) async {
    final existing = _firstPriceListForVisibility(visibility);

    if (existing != null) {
      return existing;
    }

    if (_supplierBusinessId == null) {
      _showMessage('Supplier business could not be identified.');
      return null;
    }

    try {
      final inserted = await Supabase.instance.client
          .from('price_lists')
          .insert({
            'supplier_business_id': _supplierBusinessId,
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

      await _loadPricing();

      return Map<String, dynamic>.from(inserted);
    } on PostgrestException catch (error) {
      _showMessage(error.message);
      return null;
    }
  }

  Future<void> _editProductPrice({
    required Map<String, dynamic> priceList,
  }) async {
    final priceListId = priceList['id']?.toString();

    if (priceListId == null || priceListId.isEmpty) {
      return;
    }

    final existingPrice = _priceForList(priceListId);

    final amountController = TextEditingController(
      text: existingPrice?['amount']?.toString() ?? '',
    );

    final minimumController = TextEditingController(
      text: existingPrice?['minimum_quantity']?.toString() ?? '',
    );

    var basis = _usesSpecGradeCatalogue
        ? 'kilogram'
        : existingPrice?['price_basis']?.toString() ?? _priceBasis;

    if (!['kilogram', 'carton', 'unit'].contains(basis)) {
      basis = 'kilogram';
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                '${_visibilityLabel(priceList['visibility']?.toString() ?? '')} - ${priceList['name'] ?? ''}',
              ),
              content: SizedBox(
                width: 500,
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
                        labelText: 'Price (inc GST)',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: basis,
                      decoration: InputDecoration(
                        labelText: 'Price basis',
                        helperText: _usesSpecGradeCatalogue
                            ? 'Marketplace catch-weight products are priced per kilogram.'
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      items: _usesSpecGradeCatalogue
                          ? const [
                              DropdownMenuItem(
                                value: 'kilogram',
                                child: Text('Per kilogram'),
                              ),
                            ]
                          : const [
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
                      onChanged: _usesSpecGradeCatalogue
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() {
                                  basis = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: minimumController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _usesSpecGradeCatalogue
                            ? 'Minimum order'
                            : 'Minimum quantity',
                        hintText: 'Optional',
                        suffixText: _usesSpecGradeCatalogue ? 'cartons' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (existingPrice != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop({'remove': true});
                    },
                    child: const Text('Remove Price'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (amount == null || amount < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid price.')),
                      );
                      return;
                    }

                    final minimumText = minimumController.text.trim();

                    final minimum = minimumText.isEmpty
                        ? null
                        : double.tryParse(minimumText);

                    if (minimumText.isNotEmpty &&
                        (minimum == null || minimum <= 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Minimum quantity must be greater than 0.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop({
                      'amount': amount,
                      'price_basis': basis,
                      'minimum_quantity': minimum,
                      'remove': false,
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF741C1C),
                  ),
                  child: const Text('Save Price'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    minimumController.dispose();

    if (result == null) {
      return;
    }

    setState(() {
      _isSavingPrice = true;
    });

    try {
      if (result['remove'] == true) {
        if (existingPrice != null) {
          await Supabase.instance.client
              .from('product_prices')
              .update({'active': false})
              .eq('id', existingPrice['id']);
        }
      } else if (existingPrice != null) {
        await Supabase.instance.client
            .from('product_prices')
            .update({
              'amount': result['amount'],
              'price_basis': result['price_basis'],
              'minimum_quantity': result['minimum_quantity'],
              'active': true,
            })
            .eq('id', existingPrice['id']);
      } else {
        await Supabase.instance.client.from('product_prices').insert({
          'product_id': widget.product['id'],
          'price_list_id': priceListId,
          'amount': result['amount'],
          'price_basis': result['price_basis'],
          'minimum_quantity': result['minimum_quantity'],
          'active': true,
        });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product price updated.')));

      await _loadPricing();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPrice = false;
        });
      }
    }
  }

  Future<void> _createAndEditStandardPrice(String visibility) async {
    final defaultName = visibility == 'public'
        ? 'Standard Pricing'
        : 'Trade Pricing';

    final priceList = await _ensurePriceList(
      visibility: visibility,
      defaultName: defaultName,
    );

    if (priceList == null || !mounted) {
      return;
    }

    await _editProductPrice(priceList: priceList);
  }

  Widget _pricingSectionCard({
    required String title,
    required String description,
    required String visibility,
    required IconData icon,
  }) {
    final priceList = _firstPriceListForVisibility(visibility);

    if (priceList == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF741C1C)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _isSavingPrice
                          ? null
                          : () => _createAndEditStandardPrice(visibility),
                      icon: const Icon(Icons.add),
                      label: const Text('Set Price'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF741C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final price = _priceForList(priceList['id'].toString());

    final priceText = price == null
        ? 'Not set'
        : '${_formatMoneyValue(price['amount'])} / ${_pricingBasisLabel(price['price_basis']?.toString())} inc GST';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF741C1C)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        priceText,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: price == null
                              ? const Color(0xFF777777)
                              : const Color(0xFF741C1C),
                        ),
                      ),
                      if (price?['minimum_quantity'] != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Minimum quantity: ${price!['minimum_quantity']}',
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );

            final editButton = OutlinedButton.icon(
              onPressed: _isSavingPrice
                  ? null
                  : () => _editProductPrice(priceList: priceList),
              icon: const Icon(Icons.edit_outlined),
              label: Text(price == null ? 'Set Price' : 'Edit Price'),
            );

            if (constraints.maxWidth < 650) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 16), editButton],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 18),
                editButton,
              ],
            );
          },
        ),
      ),
    );
  }

  String _approvedCustomerName(Map<String, dynamic> customer) {
    final business = customer['businesses'];

    if (business is Map) {
      final tradingName = business['trading_name']?.toString();

      if (tradingName != null && tradingName.trim().isNotEmpty) {
        return tradingName.trim();
      }

      final legalName = business['legal_name']?.toString();

      if (legalName != null && legalName.trim().isNotEmpty) {
        return legalName.trim();
      }
    }

    return 'Unnamed butcher';
  }

  List<String> _customerIdsForPriceList(Map<String, dynamic> priceList) {
    final raw = priceList['price_list_customers'];

    if (raw is! List) {
      return [];
    }

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

  Future<void> _setCustomerSpecificPrice(Map<String, dynamic> customer) async {
    final customerBusinessId = customer['butcher_business_id']?.toString();

    if (customerBusinessId == null ||
        customerBusinessId.isEmpty ||
        _supplierBusinessId == null) {
      return;
    }

    var priceList = _privatePriceListForCustomer(customerBusinessId);

    if (priceList == null) {
      try {
        final customerName = _approvedCustomerName(customer);

        final insertedPriceList = await Supabase.instance.client
            .from('price_lists')
            .insert({
              'supplier_business_id': _supplierBusinessId,
              'name': '$customerName - Customer Price',
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

        final priceListId = insertedPriceList['id']?.toString();

        if (priceListId == null || priceListId.isEmpty) {
          throw Exception(
            'The customer-specific price list could not be created.',
          );
        }

        await Supabase.instance.client.from('price_list_customers').insert({
          'price_list_id': priceListId,
          'butcher_business_id': customerBusinessId,
        });

        await _loadPricing();

        priceList = _privatePriceListForCustomer(customerBusinessId);

        if (priceList == null) {
          throw Exception(
            'The customer-specific price list could not be loaded.',
          );
        }
      } on PostgrestException catch (error) {
        _showMessage(error.message);
        return;
      } catch (error) {
        _showMessage(error.toString());
        return;
      }
    }

    await _editProductPrice(priceList: priceList);
  }

  Future<void> _removeCustomerSpecificPrice(
    Map<String, dynamic> customer,
  ) async {
    final customerBusinessId = customer['butcher_business_id']?.toString();

    if (customerBusinessId == null || customerBusinessId.isEmpty) {
      return;
    }

    final priceList = _privatePriceListForCustomer(customerBusinessId);

    if (priceList == null) {
      return;
    }

    final price = _priceForList(priceList['id'].toString());

    if (price == null) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('product_prices')
          .update({'active': false})
          .eq('id', price['id']);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer-specific price removed for this product.'),
        ),
      );

      await _loadPricing();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    }
  }

  Widget _buildCustomerSpecificPricingSection() {
    if (_approvedCustomers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1DE)),
        ),
        child: const Text(
          'No approved butcher customers are available yet. Approve a butcher under Customers & Accounts before assigning a customer-specific price.',
          style: TextStyle(color: Color(0xFF666666), height: 1.4),
        ),
      );
    }

    return Column(
      children: [
        for (final customer in _approvedCustomers) ...[
          _buildCustomerPriceCard(customer),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildCustomerPriceCard(Map<String, dynamic> customer) {
    final customerBusinessId = customer['butcher_business_id']?.toString();

    final priceList = customerBusinessId == null
        ? null
        : _privatePriceListForCustomer(customerBusinessId);

    final price = priceList == null
        ? null
        : _priceForList(priceList['id'].toString());

    final standardPriceList = _firstPriceListForVisibility('public');

    final standardPrice = standardPriceList == null
        ? null
        : _priceForList(standardPriceList['id'].toString());

    final priceText = price == null
        ? 'No special price'
        : '${_formatMoneyValue(price['amount'])} / ${_pricingBasisLabel(price['price_basis']?.toString())} inc GST';

    String? savingText;

    if (price != null &&
        standardPrice != null &&
        price['price_basis']?.toString() ==
            standardPrice['price_basis']?.toString()) {
      final customerAmount = price['amount'] is num
          ? (price['amount'] as num).toDouble()
          : double.tryParse('${price['amount']}');

      final standardAmount = standardPrice['amount'] is num
          ? (standardPrice['amount'] as num).toDouble()
          : double.tryParse('${standardPrice['amount']}');

      if (customerAmount != null &&
          standardAmount != null &&
          standardAmount > customerAmount &&
          standardAmount > 0) {
        final saving = standardAmount - customerAmount;
        final percentage = (saving / standardAmount) * 100;

        savingText =
            'Saves ${_formatMoneyValue(saving)} / ${_pricingBasisLabel(price['price_basis']?.toString())} (${percentage.toStringAsFixed(1)}%) vs Standard';
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: price == null
              ? const Color(0xFFE0E0E0)
              : const Color(0xFFD9C1C1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFF4E5E5),
                  foregroundColor: Color(0xFF741C1C),
                  child: Icon(Icons.storefront_outlined),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _approvedCustomerName(customer),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        priceText,
                        style: TextStyle(
                          color: price == null
                              ? const Color(0xFF666666)
                              : const Color(0xFF741C1C),
                          fontWeight: price == null
                              ? FontWeight.w500
                              : FontWeight.w800,
                          fontSize: price == null ? 14 : 18,
                        ),
                      ),
                      if (savingText != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          savingText,
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSavingPrice
                      ? null
                      : () => _setCustomerSpecificPrice(customer),
                  icon: Icon(price == null ? Icons.add : Icons.edit_outlined),
                  label: Text(
                    price == null ? 'Set Special Price' : 'Edit Price',
                  ),
                ),
                if (price != null)
                  TextButton.icon(
                    onPressed: _isSavingPrice
                        ? null
                        : () => _removeCustomerSpecificPrice(customer),
                    icon: const Icon(Icons.close),
                    label: const Text('Remove'),
                  ),
              ],
            );

            if (constraints.maxWidth < 680) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 14), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: details),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPricingTab() {
    if (_isLoadingPricing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pricingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Color(0xFF741C1C),
              ),
              const SizedBox(height: 16),
              Text(_pricingError!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadPricing,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Product Pricing',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              const Text(
                'Manage the prices for this product. Standard, Trade and Customer-Specific pricing stays attached to this product while access rules control which price each butcher receives.',
                style: TextStyle(color: Color(0xFF666666), height: 1.5),
              ),
              const SizedBox(height: 26),

              _pricingSectionCard(
                title: 'Standard Price',
                description:
                    'The normal marketplace price shown to all approved butchers.',
                visibility: 'public',
                icon: Icons.public,
              ),

              const SizedBox(height: 14),

              _pricingSectionCard(
                title: 'Trade Price',
                description:
                    'Shown to butchers approved as customers by this supplier. It takes priority over the Standard Price.',
                visibility: 'approved_customers',
                icon: Icons.handshake_outlined,
              ),

              const SizedBox(height: 26),

              const Text(
                'Customer-Specific Pricing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Give selected approved butchers their own negotiated price for this product. This price takes priority over Trade and Standard pricing for that butcher only.',
                style: TextStyle(color: Color(0xFF666666), height: 1.4),
              ),
              const SizedBox(height: 14),

              _buildCustomerSpecificPricingSection(),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F4F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5D6D6)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF741C1C)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Price priority remains: Customer-Specific Price → Trade Price → Standard Price.',
                        style: TextStyle(
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _twoColumnFields(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(children: [left, const SizedBox(height: 18), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 18),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF741C1C);

    final selectedCataloguePath = _selectedCataloguePath();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Edit Product',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: darkRed,
            unselectedLabelColor: Color(0xFF666666),
            indicatorColor: darkRed,
            tabs: [
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Product Details',
              ),
              Tab(icon: Icon(Icons.price_change_outlined), text: 'Pricing'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _isLoadingPage
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
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
                                    'Edit Product',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    _usesSpecGradeCatalogue
                                        ? 'This product uses CutLink specification + grade pricing.'
                                        : _usesCanonicalCatalogue
                                        ? 'This product is linked to the previous recursive marketplace catalogue.'
                                        : 'This is a legacy product. Supplier listing information can still be edited.',
                                    style: const TextStyle(
                                      color: Color(0xFF5E5E5E),
                                      height: 1.4,
                                    ),
                                  ),

                                  if (_usesSpecGradeCatalogue) ...[
                                    const SizedBox(height: 30),

                                    _sectionTitle(
                                      'Product classification',
                                      subtitle:
                                          'Choose the animal, section, cut specification and AUS-MEAT category.',
                                    ),

                                    const SizedBox(height: 20),

                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'new-animal-$_selectedAnimalId',
                                      ),
                                      initialValue: _selectedAnimalId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Animal',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: _animals.map((animal) {
                                        return DropdownMenuItem<String>(
                                          value: animal['id'].toString(),
                                          child: Text(
                                            animal['name'].toString(),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _isSaving
                                          ? null
                                          : _selectAnimalNew,
                                    ),

                                    const SizedBox(height: 18),

                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'new-section-$_selectedAnimalId-$_selectedSectionId',
                                      ),
                                      initialValue: _selectedSectionId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Section',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _isLoadingSections
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      items: _sections.map((section) {
                                        final label =
                                            section['is_miscellaneous'] == true
                                            ? '${section['name']} • Other'
                                            : section['name'].toString();

                                        return DropdownMenuItem<String>(
                                          value: section['id'].toString(),
                                          child: Text(label),
                                        );
                                      }).toList(),
                                      onChanged:
                                          _selectedAnimalId == null ||
                                              _isLoadingSections ||
                                              _isSaving
                                          ? null
                                          : _selectSectionNew,
                                    ),

                                    const SizedBox(height: 18),

                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'new-spec-$_selectedSectionId-$_selectedSpecificationId',
                                      ),
                                      initialValue: _selectedSpecificationId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Cut / Specification',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _isLoadingSpecifications
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      items: _specifications.map((
                                        specification,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: specification['id'].toString(),
                                          child: Text(
                                            _specificationLabelNew(
                                              specification,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged:
                                          _selectedSectionId == null ||
                                              _isLoadingSpecifications ||
                                              _isSaving
                                          ? null
                                          : _selectSpecificationNew,
                                    ),

                                    const SizedBox(height: 10),

                                    OutlinedButton.icon(
                                      onPressed:
                                          _selectedSectionId == null ||
                                              _isSaving
                                          ? null
                                          : _addManualSpecificationNew,
                                      icon: const Icon(Icons.add),
                                      label: const Text(
                                        'Add Specification Manually',
                                      ),
                                    ),

                                    const SizedBox(height: 18),

                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'new-grade-$_selectedSpecificationId-$_selectedGradeId',
                                      ),
                                      initialValue: _selectedGradeId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Grade / AUS-MEAT Category',
                                        helperText:
                                            _grades.isEmpty &&
                                                !_isLoadingGrades &&
                                                _selectedSpecificationId != null
                                            ? 'No categories are mapped to this specification yet.'
                                            : 'The price below belongs to this exact category.',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _isLoadingGrades
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      items: _grades.map((grade) {
                                        return DropdownMenuItem<String>(
                                          value: grade['id'].toString(),
                                          child: Text(_gradeLabelNew(grade)),
                                        );
                                      }).toList(),
                                      onChanged: _grades.isEmpty || _isSaving
                                          ? null
                                          : _selectGradeNew,
                                    ),

                                    const SizedBox(height: 18),

                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F4F4),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5D6D6),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.price_change_outlined,
                                            color: Color(0xFF741C1C),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Prices are managed in the Pricing tab',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  'Standard, Trade and Customer-Specific prices all belong to this exact specification and grade.',
                                                  style: TextStyle(
                                                    color: Color(0xFF666666),
                                                    height: 1.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextButton(
                                                  onPressed: () {
                                                    DefaultTabController.of(
                                                      context,
                                                    ).animateTo(1);
                                                  },
                                                  child: const Text(
                                                    'Open Pricing',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 32),
                                    const Divider(),
                                  ],

                                  if (_usesCanonicalCatalogue) ...[
                                    const SizedBox(height: 30),

                                    _sectionTitle(
                                      'Meat catalogue',
                                      subtitle:
                                          'The complete catalogue path is loaded automatically, regardless of how many parent levels the product has.',
                                    ),

                                    const SizedBox(height: 20),

                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'species-$_selectedSpeciesId',
                                      ),
                                      initialValue: _selectedSpeciesId,
                                      decoration: const InputDecoration(
                                        labelText: 'Species',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: _species.map((species) {
                                        return DropdownMenuItem<String>(
                                          value: species['id'] as String,
                                          child: Text(
                                            species['name'] as String,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          _loadCatalogueProducts(value);
                                        }
                                      },
                                    ),

                                    const SizedBox(height: 18),

                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'catalogue-$_selectedSpeciesId-$_selectedMeatProductId',
                                      ),
                                      initialValue: _selectedMeatProductId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Catalogue product / cut',
                                        hintText: _isLoadingCatalogue
                                            ? 'Loading catalogue...'
                                            : 'Select a product or cut',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _isLoadingCatalogue
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      items: _catalogueProducts.map((product) {
                                        return DropdownMenuItem<String>(
                                          value: product['id'] as String,
                                          child: Text(
                                            _catalogueProductLabel(product),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged:
                                          _selectedSpeciesId == null ||
                                              _isLoadingCatalogue
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                _loadProductVariants(value);
                                              }
                                            },
                                    ),

                                    if (selectedCataloguePath != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F4F4),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5D6D6),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.account_tree_outlined,
                                              size: 20,
                                              color: darkRed,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                selectedCataloguePath,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 18),

                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'variant-$_selectedMeatProductId-$_selectedProductVariantId',
                                      ),
                                      initialValue: _selectedProductVariantId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Product variant / specification',
                                        hintText: _isLoadingVariants
                                            ? 'Loading variants...'
                                            : 'Select a variant',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _isLoadingVariants
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      items: _productVariants.map((variant) {
                                        return DropdownMenuItem<String>(
                                          value: variant['id'] as String,
                                          child: Text(
                                            _variantLabel(variant),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged:
                                          _selectedMeatProductId == null ||
                                              _isLoadingVariants
                                          ? null
                                          : _selectVariant,
                                    ),

                                    if (_selectedMeatProductId != null &&
                                        !_isLoadingVariants &&
                                        _productVariants.isEmpty) ...[
                                      const SizedBox(height: 10),
                                      const Text(
                                        'This catalogue product does not currently have an active variant.',
                                        style: TextStyle(
                                          color: Color(0xFF9A6700),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 32),

                                    const Divider(),
                                  ],

                                  const SizedBox(height: 28),

                                  _sectionTitle(
                                    'Product details',
                                    subtitle:
                                        'Keep the everyday information here. Pricing is managed separately in the Pricing tab.',
                                  ),

                                  const SizedBox(height: 18),

                                  _twoColumnFields(
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
                                    TextFormField(
                                      controller: _productNameController,
                                      readOnly: _usesSpecGradeCatalogue,
                                      decoration: InputDecoration(
                                        labelText: 'Supplier product name',
                                        helperText: _usesSpecGradeCatalogue
                                            ? 'Automatically linked to the selected cut / specification.'
                                            : null,
                                        prefixIcon: _usesSpecGradeCatalogue
                                            ? const Icon(Icons.link_outlined)
                                            : null,
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        return _requiredValidator(
                                          value,
                                          'a product name',
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  _twoColumnFields(
                                    TextFormField(
                                      controller: _quantityController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: _usesSpecGradeCatalogue
                                            ? 'Available cartons'
                                            : 'Available quantity',
                                        suffixText: _usesSpecGradeCatalogue
                                            ? 'cartons'
                                            : null,
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator:
                                          _validateOptionalNonNegativeNumber,
                                    ),
                                    DropdownButtonFormField<String>(
                                      initialValue: _availabilityStatus,
                                      decoration: const InputDecoration(
                                        labelText: 'Availability',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'in_stock',
                                          child: Text('In stock'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'limited',
                                          child: Text('Limited stock'),
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

                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _active,
                                    title: const Text('Product active'),
                                    subtitle: Text(
                                      _active
                                          ? 'Visible and available in your catalogue.'
                                          : 'Hidden from your active catalogue.',
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _active = value;
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 20),

                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding: const EdgeInsets.only(
                                      bottom: 8,
                                    ),
                                    title: const Text(
                                      'More product details',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Optional brand, marbling, trim, origin and supplier notes.',
                                    ),
                                    children: [
                                      const SizedBox(height: 12),

                                      _twoColumnFields(
                                        TextFormField(
                                          controller: _brandController,
                                          decoration: const InputDecoration(
                                            labelText: 'Brand (optional)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        TextFormField(
                                          controller: _marblingScoreController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Marbling / MB score (optional)',
                                            hintText: 'Example: MB4-5',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      _twoColumnFields(
                                        TextFormField(
                                          controller: _breedProgramController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Breed / program (optional)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        DropdownButtonFormField<String>(
                                          initialValue: _halalStatus,
                                          decoration: const InputDecoration(
                                            labelText: 'Halal status',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'not_specified',
                                              child: Text('Not specified'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'halal',
                                              child: Text('Halal'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'not_halal',
                                              child: Text('Not halal'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _halalStatus = value;
                                              });
                                            }
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      _twoColumnFields(
                                        TextFormField(
                                          controller:
                                              _trimSpecificationController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Trim specification (optional)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        TextFormField(
                                          controller:
                                              _fatSpecificationController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Fat specification (optional)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      _twoColumnFields(
                                        TextFormField(
                                          controller: _packagingTypeController,
                                          decoration: const InputDecoration(
                                            labelText: 'Packaging (optional)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        TextFormField(
                                          controller:
                                              _piecesPerCartonController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Pieces per carton (optional)',
                                            border: OutlineInputBorder(),
                                          ),
                                          validator:
                                              _validateOptionalPositiveInteger,
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      _twoColumnFields(
                                        TextFormField(
                                          controller: _originCountryController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Country of origin (optional)',
                                            hintText: 'Australia',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        TextFormField(
                                          controller: _originStateController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'State of origin (optional)',
                                            hintText: 'NSW',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      TextFormField(
                                        controller: _descriptionController,
                                        minLines: 2,
                                        maxLines: 4,
                                        decoration: const InputDecoration(
                                          labelText: 'Description (optional)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      TextFormField(
                                        controller:
                                            _supplierSpecificationController,
                                        minLines: 3,
                                        maxLines: 6,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Supplier specification / notes (optional)',
                                          hintText:
                                              'Extra trade information that does not fit the structured fields above',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
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
            _buildPricingTab(),
          ],
        ),
      ),
    );
  }
}
