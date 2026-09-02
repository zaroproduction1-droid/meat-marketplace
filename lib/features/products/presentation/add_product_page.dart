import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/cutlink_picker.dart';

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
  final _feedingDays = TextEditingController();
  final _ribCount = TextEditingController();
  final _chickenSizeWeight = TextEditingController();
  final _chickenCartonSize = TextEditingController();

  String? _supplierBusinessId;
  String? _animalId;
  String? _sectionId;
  String? _specificationId;
  String? _gradeId;

  String _temperature = 'chilled';
  String _availability = 'in_stock';
  String _halal = 'not_specified';
  String _boneState = 'not_specified';
  String _productionClaim = 'not_specified';
  bool _hgpFree = false;

  String _chickenSkin = 'not_applicable';
  String _chickenBone = 'not_applicable';
  String _chickenProductionType = 'conventional';
  String _chickenPreparation = 'not_applicable';

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
      _feedingDays,
      _ribCount,
      _chickenSizeWeight,
      _chickenCartonSize,
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

  Map<String, dynamic>? get _selectedAnimal {
    if (_animalId == null) return null;
    for (final animal in _animals) {
      if (animal['id']?.toString() == _animalId) return animal;
    }
    return null;
  }

  bool get _isChicken => _selectedAnimal?['code']?.toString() == 'CHICKEN';

  Future<void> _selectAnimal(String? id) async {
    if (id == null) return;
    final selected = _animals.firstWhere(
      (animal) => animal['id']?.toString() == id,
    );
    final chicken = selected['code']?.toString() == 'CHICKEN';

    setState(() {
      _animalId = id;
      _sectionId = null;
      _specificationId = null;
      _gradeId = null;
      _sections = [];
      _specifications = [];
      _grades = [];
      _loadingSections = true;
      _temperature = chicken ? 'fresh' : 'chilled';
      if (chicken) {
        _chickenSkin = 'not_applicable';
        _chickenBone = 'not_applicable';
        _chickenProductionType = 'conventional';
        _chickenPreparation = 'not_applicable';
      }
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
      _loadingGrades = !_isChicken;
      _productName.text = selectedSpecification['name']?.toString() ?? '';
    });

    if (_isChicken) {
      return;
    }

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

    if (_animalId == null || _sectionId == null || _specificationId == null) {
      _message('Select animal, main cut and sub-cut.');
      return;
    }

    if (!_isChicken && _gradeId == null) {
      _message('Select the product category / grade.');
      return;
    }

    if (_supplierBusinessId == null) return;

    final minimum = double.tryParse(_minimumCartons.text.trim());
    if (minimum == null || minimum < 1) {
      _message('Minimum order must be at least 1 carton.');
      return;
    }

    final piecesText = _piecesPerCarton.text.trim();
    final pieces = piecesText.isEmpty ? null : int.tryParse(piecesText);
    if (piecesText.isNotEmpty && (pieces == null || pieces < 0)) {
      _message('Enter a valid pieces per carton value.');
      return;
    }

    setState(() => _saving = true);

    try {
      if (_isChicken) {
        await Supabase.instance.client.rpc(
          'create_supplier_chicken_product',
          params: {
            'p_supplier_business_id': _supplierBusinessId,
            'p_animal_id': _animalId,
            'p_section_id': _sectionId,
            'p_specification_id': _specificationId,
            'p_sku': _sku.text.trim(),
            'p_product_name': _productName.text.trim(),
            'p_standard_price_inc_gst': double.parse(
              _standardPrice.text.trim(),
            ),
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
            'p_halal_status': _halal,
            'p_chicken_skin': _chickenSkin,
            'p_chicken_bone': _chickenBone,
            'p_chicken_production_type': _chickenProductionType,
            'p_chicken_preparation': _chickenPreparation,
            'p_chicken_size_weight': _chickenSizeWeight.text.trim().isEmpty
                ? null
                : _chickenSizeWeight.text.trim(),
            'p_chicken_carton_size': _chickenCartonSize.text.trim().isEmpty
                ? null
                : _chickenCartonSize.text.trim(),
            'p_packaging_type': _packaging.text.trim().isEmpty
                ? null
                : _packaging.text.trim(),
            'p_pieces_per_carton': pieces,
            'p_supplier_specification': _supplierNotes.text.trim().isEmpty
                ? null
                : _supplierNotes.text.trim(),
          },
        );
      } else {
        final createdProductId = await Supabase.instance.client.rpc(
          'create_supplier_spec_grade_product',
          params: {
            'p_supplier_business_id': _supplierBusinessId,
            'p_animal_id': _animalId,
            'p_section_id': _sectionId,
            'p_specification_id': _specificationId,
            'p_grade_id': _gradeId,
            'p_sku': _sku.text.trim(),
            'p_product_name': _productName.text.trim(),
            'p_standard_price_inc_gst': double.parse(
              _standardPrice.text.trim(),
            ),
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
            'p_pieces_per_carton': pieces,
            'p_supplier_specification': _supplierNotes.text.trim().isEmpty
                ? null
                : _supplierNotes.text.trim(),
          },
        );

        final productId = createdProductId?.toString();
        if (productId != null && productId.isNotEmpty) {
          await Supabase.instance.client
              .from('products')
              .update({
                'feeding_days': int.tryParse(_feedingDays.text.trim()),
                'bone_state': _boneState,
                'rib_count': int.tryParse(_ribCount.text.trim()),
                'production_claim': _productionClaim,
                'hgp_free': _hgpFree,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', productId);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isChicken
                ? 'Chicken product created.'
                : 'Product and category price created.',
          ),
        ),
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

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    IconData icon = Icons.inventory_2_outlined,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EAEA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _darkRed, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2A2A2A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Future<String?> _showCutLinkPicker({
    required String title,
    required List<Map<String, String>> options,
    String? currentValue,
  }) {
    return showCutLinkPickerDialog<String>(
      context: context,
      title: title,
      currentValue: currentValue,
      options: options
          .map(
            (option) => CutLinkPickerOption<String>(
              value: option['value']!,
              label: option['label'] ?? '',
              subtitle: option['subtitle'],
            ),
          )
          .toList(),
    );
  }

  Widget _cutLinkPickerField({
    required String label,
    required String? value,
    required List<Map<String, String>> options,
    required Future<void> Function(String?) onSelected,
    String hint = 'Select',
    bool enabled = true,
    bool loading = false,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    final selected = options.cast<Map<String, String>?>().firstWhere(
      (option) => option?['value'] == value,
      orElse: () => null,
    );

    return FormField<String>(
      key: ValueKey('$label-$value-${options.length}-$loading'),
      initialValue: value,
      validator: validator,
      builder: (field) {
        final hasValue = selected != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: !enabled || loading
                  ? null
                  : () async {
                      final picked = await _showCutLinkPicker(
                        title: label,
                        options: options,
                        currentValue: value,
                      );
                      if (picked == null) return;
                      field.didChange(picked);
                      await onSelected(picked);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: enabled ? Colors.white : const Color(0xFFF3F3F1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: field.hasError
                        ? Colors.red.shade700
                        : hasValue
                        ? const Color(0xFFC9B1B1)
                        : const Color(0xFFD8D8D4),
                    width: hasValue ? 1.2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: hasValue
                            ? const Color(0xFFF4E8E8)
                            : const Color(0xFFF1F1EE),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              hasValue
                                  ? Icons.check_circle_outline
                                  : Icons.touch_app_outlined,
                              size: 18,
                              color: hasValue
                                  ? _darkRed
                                  : const Color(0xFF777777),
                            ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF777777),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasValue
                                ? selected['label'] ?? hint
                                : loading
                                ? 'Loading...'
                                : hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: hasValue
                                  ? const Color(0xFF262626)
                                  : const Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF666666),
                    ),
                  ],
                ),
              ),
            ),
            if (helperText != null && helperText.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  helperText,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
            ],
            if (field.hasError) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _twoFields(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _chickenSpecifications() {
    CutLinkPickerField<String> picker({
      required String label,
      required String value,
      required List<CutLinkPickerOption<String>> options,
      required ValueChanged<String> onChanged,
    }) {
      return CutLinkPickerField<String>(
        label: label,
        value: value,
        options: options,
        enabled: !_saving,
        onChanged: (picked) {
          if (picked != null) onChanged(picked);
        },
      );
    }

    return Column(
      children: [
        _twoFields(
          picker(
            label: 'Skin',
            value: _chickenSkin,
            options: const [
              CutLinkPickerOption(value: 'skin_on', label: 'Skin On'),
              CutLinkPickerOption(value: 'skin_off', label: 'Skin Off'),
              CutLinkPickerOption(
                value: 'not_applicable',
                label: 'Not Applicable',
              ),
            ],
            onChanged: (value) => setState(() => _chickenSkin = value),
          ),
          picker(
            label: 'Bone',
            value: _chickenBone,
            options: const [
              CutLinkPickerOption(value: 'bone_in', label: 'Bone In'),
              CutLinkPickerOption(value: 'boneless', label: 'Boneless'),
              CutLinkPickerOption(
                value: 'not_applicable',
                label: 'Not Applicable',
              ),
            ],
            onChanged: (value) => setState(() => _chickenBone = value),
          ),
        ),
        const SizedBox(height: 14),
        _twoFields(
          picker(
            label: 'Product State',
            value: _temperature,
            options: const [
              CutLinkPickerOption(value: 'fresh', label: 'Fresh'),
              CutLinkPickerOption(value: 'frozen', label: 'Frozen'),
            ],
            onChanged: (value) => setState(() => _temperature = value),
          ),
          picker(
            label: 'Production Type',
            value: _chickenProductionType,
            options: const [
              CutLinkPickerOption(value: 'conventional', label: 'Conventional'),
              CutLinkPickerOption(value: 'free_range', label: 'Free Range'),
              CutLinkPickerOption(value: 'organic', label: 'Organic'),
              CutLinkPickerOption(value: 'other', label: 'Other'),
            ],
            onChanged: (value) =>
                setState(() => _chickenProductionType = value),
          ),
        ),
        const SizedBox(height: 14),
        _twoFields(
          picker(
            label: 'Halal',
            value: _halal,
            options: const [
              CutLinkPickerOption(
                value: 'not_specified',
                label: 'Not Specified',
              ),
              CutLinkPickerOption(value: 'halal', label: 'Halal'),
              CutLinkPickerOption(value: 'not_halal', label: 'Not Halal'),
            ],
            onChanged: (value) => setState(() => _halal = value),
          ),
          picker(
            label: 'Preparation',
            value: _chickenPreparation,
            options: const [
              CutLinkPickerOption(
                value: 'not_applicable',
                label: 'Not Applicable',
              ),
              CutLinkPickerOption(value: 'whole', label: 'Whole'),
              CutLinkPickerOption(value: 'fillet', label: 'Fillet'),
              CutLinkPickerOption(value: 'diced', label: 'Diced'),
              CutLinkPickerOption(value: 'strips', label: 'Strips'),
              CutLinkPickerOption(value: 'sliced', label: 'Sliced'),
              CutLinkPickerOption(value: 'minced', label: 'Minced'),
              CutLinkPickerOption(value: 'butterflied', label: 'Butterflied'),
              CutLinkPickerOption(value: 'schnitzel', label: 'Schnitzel'),
              CutLinkPickerOption(
                value: 'portion_controlled',
                label: 'Portion Controlled',
              ),
              CutLinkPickerOption(value: 'other', label: 'Other'),
            ],
            onChanged: (value) => setState(() => _chickenPreparation = value),
          ),
        ),
        const SizedBox(height: 14),
        _twoFields(
          TextFormField(
            controller: _chickenSizeWeight,
            decoration: const InputDecoration(
              labelText: 'Size / Weight (optional)',
              hintText: 'Example: 1.8-2.0 kg or 200 g portions',
              border: OutlineInputBorder(),
            ),
          ),
          TextFormField(
            controller: _chickenCartonSize,
            decoration: const InputDecoration(
              labelText: 'Pack / Carton Size (optional)',
              hintText: 'Example: 5 kg, 10 kg, 12 units',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: AppBar(
        title: const Text(
          'Add Product',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Supplier Product',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF262626),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isChicken
                        ? 'Chicken uses cut, sub-cut and practical product specifications instead of beef-style grades.'
                        : 'Create an inventory product using the CutLink animal, cut and category structure.',
                    style: const TextStyle(
                      color: Color(0xFF6A6A6A),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Product Classification',
                    subtitle: _isChicken
                        ? 'Choose Chicken, the main cut and the sub-cut. Grade is not required for Chicken.'
                        : 'Choose the animal, main cut, specification and category.',
                    icon: Icons.account_tree_outlined,
                    child: Column(
                      children: [
                        _twoFields(
                          _cutLinkPickerField(
                            label: 'Animal',
                            value: _animalId,
                            options: _animals
                                .map(
                                  (e) => {
                                    'value': e['id'].toString(),
                                    'label': e['name'].toString(),
                                    'subtitle': 'Browse ${e['name']} catalogue',
                                  },
                                )
                                .toList(),
                            onSelected: _selectAnimal,
                            enabled: !_saving,
                            hint: 'Choose animal',
                            validator: (value) =>
                                value == null ? 'Animal is required.' : null,
                          ),
                          _cutLinkPickerField(
                            label: _isChicken
                                ? 'Main Cut'
                                : 'Section / Main Cut',
                            value: _sectionId,
                            options: _sections
                                .map(
                                  (e) => {
                                    'value': e['id'].toString(),
                                    'label': e['name'].toString(),
                                    'subtitle': e['is_miscellaneous'] == true
                                        ? 'Other / miscellaneous'
                                        : 'Main cut',
                                  },
                                )
                                .toList(),
                            onSelected: _selectSection,
                            enabled:
                                _animalId != null &&
                                !_loadingSections &&
                                !_saving,
                            loading: _loadingSections,
                            hint: _animalId == null
                                ? 'Choose animal first'
                                : 'Choose main cut',
                            validator: (value) =>
                                value == null ? 'Main cut is required.' : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _cutLinkPickerField(
                          label: _isChicken ? 'Sub-cut' : 'Cut / Specification',
                          value: _specificationId,
                          options: _specifications
                              .map(
                                (e) => {
                                  'value': e['id'].toString(),
                                  'label': _specLabel(e),
                                  'subtitle':
                                      e['specification_type'] ==
                                          'supplier_custom'
                                      ? 'Supplier custom specification'
                                      : _isChicken
                                      ? 'Chicken sub-cut'
                                      : 'CutLink specification',
                                },
                              )
                              .toList(),
                          onSelected: _selectSpecification,
                          enabled:
                              _sectionId != null &&
                              !_loadingSpecifications &&
                              !_saving,
                          loading: _loadingSpecifications,
                          hint: _sectionId == null
                              ? 'Choose main cut first'
                              : 'Choose sub-cut',
                          validator: (value) =>
                              value == null ? 'Sub-cut is required.' : null,
                        ),
                        if (!_isChicken) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _sectionId == null || _saving
                                  ? null
                                  : _addManualSpecification,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Specification Manually'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _cutLinkPickerField(
                            label: 'Grade / AUS-MEAT Category',
                            value: _gradeId,
                            options: _grades
                                .map(
                                  (e) => {
                                    'value': e['id'].toString(),
                                    'label': _gradeLabel(e),
                                    'subtitle':
                                        e['description']?.toString() ?? '',
                                  },
                                )
                                .toList(),
                            onSelected: (value) async {
                              setState(() => _gradeId = value);
                            },
                            enabled:
                                _grades.isNotEmpty &&
                                !_loadingGrades &&
                                !_saving,
                            loading: _loadingGrades,
                            hint: _specificationId == null
                                ? 'Choose specification first'
                                : _grades.isEmpty && !_loadingGrades
                                ? 'No mapped categories'
                                : 'Choose grade / category',
                            helperText: _specificationId == null
                                ? 'Choose a specification first.'
                                : _grades.isEmpty && !_loadingGrades
                                ? 'No categories are mapped to this specification yet.'
                                : 'The supplier price below is specific to this category.',
                            validator: (value) => _isChicken || value != null
                                ? null
                                : 'Category is required.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isChicken) ...[
                    const SizedBox(height: 14),
                    _sectionCard(
                      title: 'Chicken Specifications',
                      subtitle:
                          'These describe the actual product variation without creating duplicate sub-categories.',
                      icon: Icons.tune_outlined,
                      child: _chickenSpecifications(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: 'Product Details',
                    subtitle:
                        'Supplier SKU, product identity, brand and description.',
                    icon: Icons.sell_outlined,
                    child: Column(
                      children: [
                        _twoFields(
                          TextFormField(
                            controller: _sku,
                            decoration: const InputDecoration(
                              labelText: 'Supplier SKU / Product Code',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => _required(v, 'Supplier SKU'),
                          ),
                          TextFormField(
                            controller: _productName,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Product Name',
                              helperText:
                                  'Linked to the selected CutLink sub-cut.',
                              prefixIcon: Icon(Icons.link_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => _required(v, 'Product name'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoFields(
                          TextFormField(
                            controller: _brand,
                            decoration: const InputDecoration(
                              labelText: 'Brand (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          TextFormField(
                            controller: _packaging,
                            decoration: const InputDecoration(
                              labelText: 'Packaging (optional)',
                              hintText: 'Example: vacuum packed',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _description,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 820;

                      final pricing = _sectionCard(
                        title: 'Pricing',
                        subtitle: _isChicken
                            ? 'Customer-facing Standard Price. Chicken remains ordered by carton and charged by actual kilograms where catch-weight applies.'
                            : 'Standard category price, GST inclusive.',
                        icon: Icons.payments_outlined,
                        child: TextFormField(
                          controller: _standardPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Standard Price inc GST',
                            prefixText: '\$',
                            suffixText: '/ kg',
                            border: OutlineInputBorder(),
                          ),
                          validator: _moneyValidator,
                        ),
                      );

                      final inventory = _sectionCard(
                        title: 'Inventory',
                        subtitle:
                            'Stock, minimum order and product availability.',
                        icon: Icons.warehouse_outlined,
                        child: Column(
                          children: [
                            _twoFields(
                              TextFormField(
                                controller: _availableCartons,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Current Stock',
                                  suffixText: 'cartons',
                                  border: OutlineInputBorder(),
                                ),
                                validator: _optionalPositive,
                              ),
                              TextFormField(
                                controller: _minimumCartons,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Minimum Order',
                                  suffixText: 'cartons',
                                  border: OutlineInputBorder(),
                                ),
                                validator: _optionalPositive,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoFields(
                              TextFormField(
                                controller: _piecesPerCarton,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Units / Pieces per Carton',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              CutLinkPickerField<String>(
                                label: 'Availability',
                                value: _availability,
                                options: const [
                                  CutLinkPickerOption(
                                    value: 'in_stock',
                                    label: 'In stock',
                                  ),
                                  CutLinkPickerOption(
                                    value: 'limited',
                                    label: 'Limited stock',
                                  ),
                                  CutLinkPickerOption(
                                    value: 'out_of_stock',
                                    label: 'Out of stock',
                                  ),
                                  CutLinkPickerOption(
                                    value: 'made_to_order',
                                    label: 'Made to order',
                                  ),
                                ],
                                enabled: !_saving,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _availability = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      );

                      if (narrow) {
                        return Column(
                          children: [
                            pricing,
                            const SizedBox(height: 14),
                            inventory,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: pricing),
                          const SizedBox(width: 14),
                          Expanded(flex: 6, child: inventory),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  if (!_isChicken)
                    _sectionCard(
                      title: 'Additional Product Details',
                      subtitle:
                          'Secondary red-meat attributes. These do not replace the selected category.',
                      icon: Icons.fact_check_outlined,
                      child: Column(
                        children: [
                          _twoFields(
                            CutLinkPickerField<String>(
                              label: 'Storage Condition',
                              value: _temperature,
                              options: const [
                                CutLinkPickerOption(
                                  value: 'fresh',
                                  label: 'Fresh',
                                ),
                                CutLinkPickerOption(
                                  value: 'chilled',
                                  label: 'Chilled',
                                ),
                                CutLinkPickerOption(
                                  value: 'frozen',
                                  label: 'Frozen',
                                ),
                              ],
                              enabled: !_saving,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _temperature = value);
                                }
                              },
                            ),
                            CutLinkPickerField<String>(
                              label: 'Halal Status',
                              value: _halal,
                              options: const [
                                CutLinkPickerOption(
                                  value: 'not_specified',
                                  label: 'Not specified',
                                ),
                                CutLinkPickerOption(
                                  value: 'halal',
                                  label: 'Halal',
                                ),
                                CutLinkPickerOption(
                                  value: 'not_halal',
                                  label: 'Not halal',
                                ),
                              ],
                              enabled: !_saving,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _halal = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            TextFormField(
                              controller: _marbling,
                              decoration: const InputDecoration(
                                labelText: 'Marbling / MB score (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextFormField(
                              controller: _breed,
                              decoration: const InputDecoration(
                                labelText: 'Breed / Program (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            TextFormField(
                              controller: _feedingDays,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Feeding Days (optional)',
                                hintText: 'Example: 100, 150, 200',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextFormField(
                              controller: _ribCount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Rib Count (optional)',
                                hintText: 'Example: 3, 5, 7',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            CutLinkPickerField<String>(
                              label: 'Bone State',
                              value: _boneState,
                              options: const [
                                CutLinkPickerOption(
                                  value: 'not_specified',
                                  label: 'Not specified',
                                ),
                                CutLinkPickerOption(
                                  value: 'bone_in',
                                  label: 'Bone in',
                                ),
                                CutLinkPickerOption(
                                  value: 'boneless',
                                  label: 'Boneless',
                                ),
                              ],
                              enabled: !_saving,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _boneState = value);
                                }
                              },
                            ),
                            CutLinkPickerField<String>(
                              label: 'Production Claim',
                              value: _productionClaim,
                              options: const [
                                CutLinkPickerOption(
                                  value: 'not_specified',
                                  label: 'Not specified',
                                ),
                                CutLinkPickerOption(
                                  value: 'grass_fed',
                                  label: 'Grass fed',
                                ),
                                CutLinkPickerOption(
                                  value: 'grain_fed',
                                  label: 'Grain fed',
                                ),
                                CutLinkPickerOption(
                                  value: 'mixed',
                                  label: 'Mixed / Combination',
                                ),
                                CutLinkPickerOption(
                                  value: 'other',
                                  label: 'Other',
                                ),
                              ],
                              enabled: !_saving,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _productionClaim = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _hgpFree,
                            title: const Text(
                              'HGP Free',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Supplier-declared production claim.',
                            ),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _hgpFree = value),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            TextFormField(
                              controller: _trim,
                              decoration: const InputDecoration(
                                labelText: 'Trim Specification (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextFormField(
                              controller: _fat,
                              decoration: const InputDecoration(
                                labelText: 'Fat Specification (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _twoFields(
                            TextFormField(
                              controller: _originCountry,
                              decoration: const InputDecoration(
                                labelText: 'Country of Origin',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            TextFormField(
                              controller: _originState,
                              decoration: const InputDecoration(
                                labelText: 'State of Origin (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_isChicken) const SizedBox(height: 14),
                  _sectionCard(
                    title: 'Supplier Notes',
                    subtitle:
                        'Optional internal/trade specification information.',
                    icon: Icons.notes_outlined,
                    child: TextFormField(
                      controller: _supplierNotes,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Specification / Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _darkRed,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                ? 'Saving...'
                                : _isChicken
                                ? 'Add Chicken Product'
                                : 'Add Product',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
