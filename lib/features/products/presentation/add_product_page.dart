import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({
    super.key,
    this.initialAnimalCode,
    this.initialSectionId,
    this.initialSpecificationId,
  });

  final String? initialAnimalCode;
  final String? initialSectionId;
  final String? initialSpecificationId;

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  static const _darkRed = Color(0xFF741C1C);

  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _productName = TextEditingController();
  final _standardPrice = TextEditingController();
  final _availableCartons = TextEditingController();
  final _minimumCartons = TextEditingController(text: '1');
  final _brand = TextEditingController();
  final _description = TextEditingController();
  final _originCountry = TextEditingController(text: 'Australia');
  final _originState = TextEditingController();
  final _marbling = TextEditingController();
  final _breed = TextEditingController();
  final _trim = TextEditingController();
  final _fat = TextEditingController();
  final _packaging = TextEditingController();
  final _piecesPerCarton = TextEditingController();
  final _supplierNotes = TextEditingController();

  String? _supplierBusinessId;
  String? _animalId;
  String? _sectionId;
  String? _specificationId;
  String? _gradeId;

  String _temperature = 'chilled';
  String _availability = 'in_stock';
  String _halal = 'not_specified';

  bool _loading = true;
  bool _saving = false;
  bool _loadingSections = false;
  bool _loadingSpecifications = false;
  bool _loadingGrades = false;

  List<Map<String, dynamic>> _animals = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _specifications = [];
  List<Map<String, dynamic>> _grades = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    for (final controller in [
      _sku,
      _productName,
      _standardPrice,
      _availableCartons,
      _minimumCartons,
      _brand,
      _description,
      _originCountry,
      _originState,
      _marbling,
      _breed,
      _trim,
      _fat,
      _packaging,
      _piecesPerCarton,
      _supplierNotes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No signed-in user was found.');

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id, businesses(business_type, verification_status)')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final business = Map<String, dynamic>.from(
        membership['businesses'] as Map,
      );
      if (business['business_type'] != 'supplier') {
        throw Exception('Only supplier accounts can create products.');
      }
      if (business['verification_status'] != 'approved') {
        throw Exception('Your supplier business must be approved first.');
      }

      final animals = await Supabase.instance.client
          .from('meat_animals')
          .select('id, code, name, display_order')
          .eq('is_active', true)
          .order('display_order');

      if (!mounted) return;
      setState(() {
        _supplierBusinessId = membership['business_id'].toString();
        _animals = List<Map<String, dynamic>>.from(animals);
        _loading = false;
      });

      final initialAnimalCode = widget.initialAnimalCode?.trim().toUpperCase();

      if (initialAnimalCode != null && initialAnimalCode.isNotEmpty) {
        Map<String, dynamic>? initialAnimal;

        for (final animal in _animals) {
          if (animal['code']?.toString().trim().toUpperCase() ==
              initialAnimalCode) {
            initialAnimal = animal;
            break;
          }
        }

        final initialAnimalId = initialAnimal?['id']?.toString();

        if (initialAnimalId != null && initialAnimalId.isNotEmpty) {
          await _selectAnimal(initialAnimalId);

          if (!mounted) return;

          final requestedSectionId = widget.initialSectionId;

          if (requestedSectionId != null &&
              requestedSectionId.isNotEmpty &&
              _sections.any(
                (section) => section['id']?.toString() == requestedSectionId,
              )) {
            await _selectSection(requestedSectionId);

            if (!mounted) return;

            final requestedSpecificationId = widget.initialSpecificationId;
            if (requestedSpecificationId != null &&
                requestedSpecificationId.isNotEmpty &&
                _specifications.any(
                  (specification) =>
                      specification['id']?.toString() ==
                      requestedSpecificationId,
                )) {
              await _selectSpecification(requestedSpecificationId);
            }
          }
        }
      }
    } on PostgrestException catch (e) {
      _finishWithError(e.message);
    } catch (e) {
      _finishWithError(e.toString());
    }
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    setState(() => _loading = false);
    _message(message);
  }

  Future<void> _selectAnimal(String? id) async {
    if (id == null) return;
    setState(() {
      _animalId = id;
      _sectionId = null;
      _specificationId = null;
      _gradeId = null;
      _sections = [];
      _specifications = [];
      _grades = [];
      _loadingSections = true;
    });

    try {
      final rows = await Supabase.instance.client
          .from('meat_sections')
          .select('id, code, name, is_miscellaneous, display_order')
          .eq('animal_id', id)
          .eq('is_active', true)
          .order('display_order');

      if (!mounted) return;
      setState(() {
        _sections = List<Map<String, dynamic>>.from(rows);
        _loadingSections = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingSections = false);
      _message('Unable to load sections: $e');
    }
  }

  Future<void> _selectSection(String? id) async {
    if (id == null) return;
    setState(() {
      _sectionId = id;
      _specificationId = null;
      _gradeId = null;
      _specifications = [];
      _grades = [];
      _loadingSpecifications = true;
    });
    await _loadSpecifications();
  }

  Future<void> _loadSpecifications({String? selectId}) async {
    final sectionId = _sectionId;
    if (sectionId == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('meat_specifications')
          .select('id, name, ham_code, specification_type, approval_status')
          .eq('section_id', sectionId)
          .eq('is_active', true)
          .order('display_order')
          .order('name');

      if (!mounted) return;
      setState(() {
        _specifications = List<Map<String, dynamic>>.from(rows);
        _specificationId = selectId;
        _gradeId = null;
        _grades = [];
        _loadingSpecifications = false;
      });
      if (selectId != null) await _selectSpecification(selectId);
    } catch (e) {
      if (mounted) setState(() => _loadingSpecifications = false);
      _message('Unable to load specifications: $e');
    }
  }

  Future<void> _selectSpecification(String? id) async {
    if (id == null) return;

    final selectedSpecification = _specifications.firstWhere(
      (row) => row['id']?.toString() == id,
    );

    setState(() {
      _specificationId = id;
      _gradeId = null;
      _grades = [];
      _loadingGrades = true;
      _productName.text = selectedSpecification['name']?.toString() ?? '';
    });

    try {
      final mappings = await Supabase.instance.client
          .from('meat_specification_grades')
          .select('grade_id, display_order')
          .eq('specification_id', id)
          .eq('is_active', true)
          .order('display_order');

      final ids = List<Map<String, dynamic>>.from(
        mappings,
      ).map((e) => e['grade_id'].toString()).toList();

      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() => _loadingGrades = false);
        return;
      }

      final grades = await Supabase.instance.client
          .from('meat_grades')
          .select('id, code, name, description, display_order')
          .inFilter('id', ids)
          .eq('is_active', true)
          .order('display_order');

      if (!mounted) return;
      setState(() {
        _grades = List<Map<String, dynamic>>.from(grades);
        _loadingGrades = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingGrades = false);
      _message('Unable to load categories: $e');
    }
  }

  Future<void> _addManualSpecification() async {
    if (_supplierBusinessId == null ||
        _animalId == null ||
        _sectionId == null) {
      _message('Select the animal and section first.');
      return;
    }

    final name = TextEditingController();
    final details = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Specification Manually'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Specification name',
                  hintText: 'Enter the missing trade specification',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: details,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Specification details (optional)',
                  hintText: 'Trim, preparation, code or other defining details',
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
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, {
                'name': name.text.trim(),
                'details': details.text.trim(),
              });
            },
            child: const Text('Add Specification'),
          ),
        ],
      ),
    );

    name.dispose();
    details.dispose();
    if (result == null) return;

    try {
      setState(() => _loadingSpecifications = true);
      final created = await Supabase.instance.client.rpc(
        'create_supplier_custom_specification',
        params: {
          'p_supplier_business_id': _supplierBusinessId,
          'p_animal_id': _animalId,
          'p_section_id': _sectionId,
          'p_name': result['name'],
          'p_description': null,
          'p_specification_notes': result['details']!.isEmpty
              ? null
              : result['details'],
        },
      );

      final row = Map<String, dynamic>.from(created as Map);
      await _loadSpecifications(selectId: row['id'].toString());
      _message('Custom specification added.');
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _loadingSpecifications = false);
      _message(e.message);
    }
  }

  String _specLabel(Map<String, dynamic> row) {
    final custom = row['specification_type'] == 'supplier_custom';
    final base = row['name'].toString();
    return custom ? '$base • Custom' : base;
  }

  String _gradeLabel(Map<String, dynamic> row) {
    return '${row['code']} — ${row['name']}';
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _moneyValidator(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return 'Enter a valid price.';
    return null;
  }

  String? _optionalPositive(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    if (number == null || number < 0) return 'Enter a valid number.';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_animalId == null ||
        _sectionId == null ||
        _specificationId == null ||
        _gradeId == null) {
      _message('Select animal, section, specification and category.');
      return;
    }
    if (_supplierBusinessId == null) return;

    final minimum = double.tryParse(_minimumCartons.text.trim());
    if (minimum == null || minimum < 1) {
      _message('Minimum order must be at least 1 carton.');
      return;
    }

    setState(() => _saving = true);

    try {
      await Supabase.instance.client.rpc(
        'create_supplier_spec_grade_product',
        params: {
          'p_supplier_business_id': _supplierBusinessId,
          'p_animal_id': _animalId,
          'p_section_id': _sectionId,
          'p_specification_id': _specificationId,
          'p_grade_id': _gradeId,
          'p_sku': _sku.text.trim(),
          'p_product_name': _productName.text.trim(),
          'p_standard_price_inc_gst': double.parse(_standardPrice.text.trim()),
          'p_available_cartons': _availableCartons.text.trim().isEmpty
              ? null
              : double.parse(_availableCartons.text.trim()),
          'p_minimum_cartons': minimum,
          'p_temperature_state': _temperature,
          'p_availability_status': _availability,
          'p_description': _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          'p_brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
          'p_origin_country': _originCountry.text.trim().isEmpty
              ? null
              : _originCountry.text.trim(),
          'p_origin_state': _originState.text.trim().isEmpty
              ? null
              : _originState.text.trim(),
          'p_marbling_score': _marbling.text.trim().isEmpty
              ? null
              : _marbling.text.trim(),
          'p_breed_program': _breed.text.trim().isEmpty
              ? null
              : _breed.text.trim(),
          'p_trim_specification': _trim.text.trim().isEmpty
              ? null
              : _trim.text.trim(),
          'p_fat_specification': _fat.text.trim().isEmpty
              ? null
              : _fat.text.trim(),
          'p_halal_status': _halal,
          'p_packaging_type': _packaging.text.trim().isEmpty
              ? null
              : _packaging.text.trim(),
          'p_pieces_per_carton': _piecesPerCarton.text.trim().isEmpty
              ? null
              : int.parse(_piecesPerCarton.text.trim()),
          'p_supplier_specification': _supplierNotes.text.trim().isEmpty
              ? null
              : _supplierNotes.text.trim(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product and category price created.')),
      );
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _message(
        e.code == '23505'
            ? 'That SKU already exists for this supplier.'
            : e.message,
      );
    } catch (e) {
      _message('Unable to create product: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _heading(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E6E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF666666),
              height: 1.4,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: const Text(
          'Add Product',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE4E4E1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(
                        'Product classification',
                        'Choose the animal, section, cut specification and AUS-MEAT category.',
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _animalId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Animal',
                          border: OutlineInputBorder(),
                        ),
                        items: _animals
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e['id'].toString(),
                                child: Text(e['name'].toString()),
                              ),
                            )
                            .toList(),
                        onChanged: _saving ? null : _selectAnimal,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _sectionId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Section',
                          border: const OutlineInputBorder(),
                          suffixIcon: _loadingSections
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        items: _sections
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e['id'].toString(),
                                child: Text(
                                  e['is_miscellaneous'] == true
                                      ? '${e['name']} • Other'
                                      : e['name'].toString(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _animalId == null || _loadingSections
                            ? null
                            : _selectSection,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _specificationId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Cut / Specification',
                          border: const OutlineInputBorder(),
                          suffixIcon: _loadingSpecifications
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        items: _specifications
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e['id'].toString(),
                                child: Text(
                                  _specLabel(e),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _sectionId == null || _loadingSpecifications
                            ? null
                            : _selectSpecification,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _sectionId == null || _saving
                            ? null
                            : _addManualSpecification,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Specification Manually'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _gradeId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Grade / AUS-MEAT Category',
                          helperText: _specificationId == null
                              ? 'Choose a specification first.'
                              : _grades.isEmpty && !_loadingGrades
                              ? 'No categories are mapped to this specification yet.'
                              : 'The supplier price below is specific to this category.',
                          border: const OutlineInputBorder(),
                          suffixIcon: _loadingGrades
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        items: _grades
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e['id'].toString(),
                                child: Text(_gradeLabel(e)),
                              ),
                            )
                            .toList(),
                        onChanged: _grades.isEmpty
                            ? null
                            : (value) => setState(() => _gradeId = value),
                      ),
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 24),
                      _heading(
                        'Supplier listing & category price',
                        'This listing represents one exact specification + grade combination. Marketplace catch-weight products are ordered by carton and charged by actual kilograms.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _sku,
                        decoration: const InputDecoration(
                          labelText: 'Supplier SKU',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => _required(v, 'Supplier SKU'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _productName,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Supplier product name',
                          helperText:
                              'Automatically linked to the selected cut / specification.',
                          prefixIcon: Icon(Icons.link_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => _required(v, 'Product name'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _standardPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Standard Price inc GST',
                          prefixText: '\$',
                          suffixText: '/ kg',
                          helperText:
                              'This price applies to the selected specification + category.',
                          border: OutlineInputBorder(),
                        ),
                        validator: _moneyValidator,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 650;
                          final available = TextFormField(
                            controller: _availableCartons,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Available cartons (optional)',
                              suffixText: 'cartons',
                              border: OutlineInputBorder(),
                            ),
                            validator: _optionalPositive,
                          );
                          final minimum = TextFormField(
                            controller: _minimumCartons,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minimum order',
                              suffixText: 'cartons',
                              border: OutlineInputBorder(),
                            ),
                            validator: _optionalPositive,
                          );
                          if (narrow) {
                            return Column(
                              children: [
                                available,
                                const SizedBox(height: 16),
                                minimum,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: available),
                              const SizedBox(width: 16),
                              Expanded(child: minimum),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _availability,
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
                        onChanged: (v) => setState(() => _availability = v!),
                      ),
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 24),
                      _heading(
                        'Additional product details',
                        'These details are secondary attributes. They do not replace the selected AUS-MEAT category.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _brand,
                        decoration: const InputDecoration(
                          labelText: 'Brand (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _temperature,
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
                        onChanged: (v) => setState(() => _temperature = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _marbling,
                        decoration: const InputDecoration(
                          labelText: 'Marbling / MB score (optional)',
                          hintText: 'Example: MB4-5',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _breed,
                        decoration: const InputDecoration(
                          labelText: 'Breed / program (optional)',
                          hintText: 'Example: Angus program',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _halal,
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
                        onChanged: (v) => setState(() => _halal = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _trim,
                        decoration: const InputDecoration(
                          labelText: 'Trim specification (optional)',
                          hintText: 'Example: cap off, chain off',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fat,
                        decoration: const InputDecoration(
                          labelText: 'Fat specification (optional)',
                          hintText: 'Example: 10 mm fat',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _packaging,
                        decoration: const InputDecoration(
                          labelText: 'Packaging (optional)',
                          hintText: 'Example: vacuum packed',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _piecesPerCarton,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pieces per carton (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 650;
                          final country = TextFormField(
                            controller: _originCountry,
                            decoration: const InputDecoration(
                              labelText: 'Country of origin',
                              border: OutlineInputBorder(),
                            ),
                          );
                          final state = TextFormField(
                            controller: _originState,
                            decoration: const InputDecoration(
                              labelText: 'State of origin (optional)',
                              border: OutlineInputBorder(),
                            ),
                          );
                          if (narrow) {
                            return Column(
                              children: [
                                country,
                                const SizedBox(height: 16),
                                state,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: country),
                              const SizedBox(width: 16),
                              Expanded(child: state),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _supplierNotes,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText:
                              'Supplier specification / notes (optional)',
                          hintText:
                              'Any extra trade details that do not fit the structured fields above',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _darkRed,
                          ),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_business_outlined),
                          label: Text(
                            _saving
                                ? 'Creating...'
                                : 'Create Product & Grade Price',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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
