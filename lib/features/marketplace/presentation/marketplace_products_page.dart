import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'marketplace_product_details_page.dart';
import '../../../shared/widgets/interactive_animal_browser.dart';
import '../../../shared/widgets/interactive_beef_cuts_map.dart';

class MarketplaceProductsPage extends StatefulWidget {
  const MarketplaceProductsPage({super.key});

  @override
  State<MarketplaceProductsPage> createState() =>
      _MarketplaceProductsPageState();
}

class _MarketplaceProductsPageState extends State<MarketplaceProductsPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  String _selectedAnimalCode = CutLinkAnimals.beef;
  String? _selectedAnimalRegionKey;
  String? _selectedSectionId;
  String? _selectedSpecificationId;
  String? _selectedGradeId;

  final Map<String, Map<String, dynamic>> _cataloguePathsByProductId = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('''
            id,
            sku,
            product_name,
            description,
            brand,
            origin_country,
            origin_state,
            temperature_state,
            available_quantity,
            quantity_unit,
            availability_status,
            supplier_business_id,
            product_variant_id,
            animal_type_id,
            cut_id,
            meat_animal_id,
            meat_section_id,
            meat_specification_id,
            meat_grade_id,
            active,
            catch_weight,

            marbling_score,
            grade,
            breed_program,
            piece_weight_min,
            piece_weight_max,
            piece_weight_unit,
            carton_weight,
            carton_weight_unit,
            pieces_per_carton,
            packaging_type,
            trim_specification,
            fat_specification,
            halal_status,
            supplier_specification,

            businesses(
              legal_name,
              trading_name
            ),

            animal_types(name),
            cuts(name),

            meat_animals(
              id,
              code,
              name
            ),
            meat_sections(
              id,
              code,
              name,
              is_miscellaneous,
              display_order
            ),
            meat_specifications(
              id,
              name,
              specification_type
            ),
            meat_grades(
              id,
              code,
              name
            ),

            product_variants(
              id,
              meat_product_id,
              variant_name,
              temperature_state,
              bone_state
            ),

            product_prices(
              amount,
              price_basis,
              minimum_quantity,
              active,

              price_lists(
                id,
                name,
                visibility,
                active
              )
            )
          ''')
          .eq('active', true)
          .order('product_name');

      final products = List<Map<String, dynamic>>.from(response);

      final meatProductIds = <String>{};

      for (final product in products) {
        final variant = _variant(product);
        final meatProductId = variant?['meat_product_id']?.toString();

        if (meatProductId != null && meatProductId.trim().isNotEmpty) {
          meatProductIds.add(meatProductId);
        }
      }

      final cataloguePathsByProductId = <String, Map<String, dynamic>>{};

      if (meatProductIds.isNotEmpty) {
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
              path_names,
              catalogue_path
            ''')
            .inFilter('id', meatProductIds.toList());

        for (final rawPath in pathResponse) {
          final path = Map<String, dynamic>.from(rawPath);
          final id = path['id']?.toString();

          if (id != null) {
            cataloguePathsByProductId[id] = path;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;
        _cataloguePathsByProductId
          ..clear()
          ..addAll(cataloguePathsByProductId);
        _isLoading = false;
      });

      _applySearch();
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

  Map<String, dynamic>? _variant(Map<String, dynamic> product) {
    final raw = product['product_variants'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return null;
  }

  Map<String, dynamic>? _cataloguePathRecord(Map<String, dynamic> product) {
    final variant = _variant(product);
    final meatProductId = variant?['meat_product_id']?.toString();

    if (meatProductId == null || meatProductId.trim().isEmpty) {
      return null;
    }

    return _cataloguePathsByProductId[meatProductId];
  }

  List<String> _canonicalCatalogueNames(Map<String, dynamic> product) {
    final names = <String>[];

    final variant = _variant(product);
    final pathRecord = _cataloguePathRecord(product);

    if (variant == null || pathRecord == null) {
      return names;
    }

    final speciesName = pathRecord['species_name']?.toString();

    if (speciesName != null && speciesName.trim().isNotEmpty) {
      names.add(speciesName);
    }

    final rawPathNames = pathRecord['path_names'];

    if (rawPathNames is List) {
      for (final value in rawPathNames) {
        final name = value?.toString();

        if (name != null && name.trim().isNotEmpty) {
          names.add(name);
        }
      }
    } else {
      final cataloguePath = pathRecord['catalogue_path']?.toString();

      if (cataloguePath != null && cataloguePath.trim().isNotEmpty) {
        final pathParts = cataloguePath.split('→');

        for (final rawPart in pathParts) {
          final part = rawPart.trim();

          if (part.isNotEmpty) {
            names.add(part);
          }
        }
      }
    }

    final variantName = variant['variant_name']?.toString();

    if (variantName != null && variantName.trim().isNotEmpty) {
      names.add(variantName);
    }

    return names;
  }

  String _cataloguePath(Map<String, dynamic> product) {
    final variant = _variant(product);
    final pathRecord = _cataloguePathRecord(product);

    if (variant != null && pathRecord != null) {
      final parts = <String>[];

      final speciesName = pathRecord['species_name']?.toString();
      final cataloguePath = pathRecord['catalogue_path']?.toString();
      final variantName = variant['variant_name']?.toString();

      if (speciesName != null && speciesName.trim().isNotEmpty) {
        parts.add(speciesName);
      }

      if (cataloguePath != null && cataloguePath.trim().isNotEmpty) {
        parts.add(cataloguePath);
      }

      if (variantName != null && variantName.trim().isNotEmpty) {
        parts.add(variantName);
      }

      if (parts.isNotEmpty) {
        return parts.join(' → ');
      }
    }

    final rawAnimalType = product['animal_types'];
    final rawCut = product['cuts'];

    String? animalName;
    String? cutName;

    if (rawAnimalType is Map) {
      animalName = rawAnimalType['name']?.toString();
    }

    if (rawCut is Map) {
      cutName = rawCut['name']?.toString();
    }

    final legacyNames = <String>[
      if (animalName != null && animalName.trim().isNotEmpty) animalName,
      if (cutName != null && cutName.trim().isNotEmpty) cutName,
    ];

    if (legacyNames.isNotEmpty) {
      return legacyNames.join(' → ');
    }

    return 'Catalogue not linked';
  }

  Map<String, dynamic>? _nestedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  String _animalCode(Map<String, dynamic> product) {
    return _nestedMap(
          product['meat_animals'],
        )?['code']?.toString().trim().toUpperCase() ??
        '';
  }

  String _sectionName(Map<String, dynamic> product) {
    return _nestedMap(product['meat_sections'])?['name']?.toString() ??
        'Unclassified';
  }

  String _specificationName(Map<String, dynamic> product) {
    return _nestedMap(product['meat_specifications'])?['name']?.toString() ??
        product['product_name']?.toString() ??
        'Unspecified cut';
  }

  String _gradeCode(Map<String, dynamic> product) {
    final value = _nestedMap(
      product['meat_grades'],
    )?['code']?.toString().trim();
    return value == null || value.isEmpty ? 'N/A' : value;
  }

  String _gradeName(Map<String, dynamic> product) {
    return _nestedMap(product['meat_grades'])?['name']?.toString().trim() ?? '';
  }

  List<Map<String, dynamic>> get _selectedAnimalProducts {
    return _products.where((product) {
      final animalCode = _animalCode(product);

      if (animalCode.isEmpty) {
        return false;
      }

      return animalCode == _selectedAnimalCode;
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedAnimalSections {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      final section = _nestedMap(product['meat_sections']);
      final id = section?['id']?.toString();

      if (section == null || id == null || id.isEmpty) continue;
      byId[id] = section;
    }

    final rows = byId.values.toList();

    rows.sort((a, b) {
      final aOrder = int.tryParse(a['display_order']?.toString() ?? '') ?? 9999;
      final bOrder = int.tryParse(b['display_order']?.toString() ?? '') ?? 9999;

      if (aOrder != bOrder) return aOrder.compareTo(bOrder);

      return (a['name']?.toString() ?? '').compareTo(
        b['name']?.toString() ?? '',
      );
    });

    return rows;
  }

  List<Map<String, dynamic>> get _availableSpecifications {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (_selectedSectionId != null &&
          product['meat_section_id']?.toString() != _selectedSectionId) {
        continue;
      }

      final specification = _nestedMap(product['meat_specifications']);
      final id = specification?['id']?.toString();

      if (specification == null || id == null || id.isEmpty) continue;
      byId[id] = specification;
    }

    final rows = byId.values.toList();

    rows.sort(
      (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
        (b['name']?.toString() ?? '').toLowerCase(),
      ),
    );

    return rows;
  }

  List<Map<String, dynamic>> get _availableGrades {
    final byId = <String, Map<String, dynamic>>{};

    for (final product in _selectedAnimalProducts) {
      if (_selectedSectionId != null &&
          product['meat_section_id']?.toString() != _selectedSectionId) {
        continue;
      }

      if (_selectedSpecificationId != null &&
          product['meat_specification_id']?.toString() !=
              _selectedSpecificationId) {
        continue;
      }

      final grade = _nestedMap(product['meat_grades']);
      final id = grade?['id']?.toString();

      if (grade == null || id == null || id.isEmpty) continue;
      byId[id] = grade;
    }

    final rows = byId.values.toList();

    rows.sort(
      (a, b) =>
          (a['code']?.toString() ?? '').compareTo(b['code']?.toString() ?? ''),
    );

    return rows;
  }

  Map<String, dynamic>? _sectionByCode(String code) {
    for (final section in _selectedAnimalSections) {
      if (section['code']?.toString() == code) return section;
    }
    return null;
  }

  String? _beefSectionCodeForRegion(String regionKey) {
    return switch (regionKey) {
      CutLinkBeefCutKeys.cheek => 'MISC',
      CutLinkBeefCutKeys.neck => 'NECK',
      CutLinkBeefCutKeys.shoulder => 'SHOULDER',
      CutLinkBeefCutKeys.chuck => 'CHUCK',
      CutLinkBeefCutKeys.blade => 'BLADE',
      CutLinkBeefCutKeys.brisket => 'BRISKET',
      CutLinkBeefCutKeys.shinShank => 'SHANK',
      CutLinkBeefCutKeys.ribs => 'RIB',
      CutLinkBeefCutKeys.ribEye => 'RIBEYE',
      CutLinkBeefCutKeys.plate => 'PLATE',
      CutLinkBeefCutKeys.skirt => 'SKIRT',
      CutLinkBeefCutKeys.loin => 'LOIN',
      CutLinkBeefCutKeys.flank => 'FLANK',
      CutLinkBeefCutKeys.rump => 'RUMP',
      CutLinkBeefCutKeys.round => 'HIND',
      CutLinkBeefCutKeys.silversideOutside => 'SILVERSIDE',
      CutLinkBeefCutKeys.oxTail => 'MISC',
      CutLinkBeefCutKeys.miscOffalOther => 'MISC',
      _ => null,
    };
  }

  void _selectAnimal(String animalCode) {
    if (animalCode == _selectedAnimalCode) return;

    setState(() {
      _selectedAnimalCode = animalCode;
      _selectedAnimalRegionKey = null;
      _selectedSectionId = null;
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });

    _applySearch();
  }

  void _selectAnimalRegion(String regionKey) {
    if (_selectedAnimalCode != CutLinkAnimals.beef) return;

    final sectionCode = _beefSectionCodeForRegion(regionKey);
    if (sectionCode == null) return;

    final section = _sectionByCode(sectionCode);
    if (section == null) return;

    setState(() {
      _selectedAnimalRegionKey = regionKey;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });

    _applySearch();
  }

  void _selectSection(Map<String, dynamic> section) {
    setState(() {
      _selectedAnimalRegionKey = null;
      _selectedSectionId = section['id']?.toString();
      _selectedSpecificationId = null;
      _selectedGradeId = null;
    });

    _applySearch();
  }

  void _applySearch() {
    if (!mounted) {
      return;
    }

    final search = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredProducts = _products.where((product) {
        if (_animalCode(product) != _selectedAnimalCode) {
          return false;
        }

        if (_selectedSectionId != null &&
            product['meat_section_id']?.toString() != _selectedSectionId) {
          return false;
        }

        if (_selectedSpecificationId != null &&
            product['meat_specification_id']?.toString() !=
                _selectedSpecificationId) {
          return false;
        }

        if (_selectedGradeId != null &&
            product['meat_grade_id']?.toString() != _selectedGradeId) {
          return false;
        }

        if (search.isEmpty) {
          return true;
        }

        final supplier = product['businesses'];

        String? tradingName;
        String? legalName;

        if (supplier is Map) {
          tradingName = supplier['trading_name']?.toString();
          legalName = supplier['legal_name']?.toString();
        }

        final catalogueNames = _canonicalCatalogueNames(product);
        final fullCataloguePath = _cataloguePath(product);

        final searchableValues = <dynamic>[
          product['product_name'],
          product['sku'],
          product['brand'],
          product['description'],
          product['origin_country'],
          product['origin_state'],
          product['temperature_state'],
          product['marbling_score'],
          product['grade'],
          product['breed_program'],
          product['packaging_type'],
          product['trim_specification'],
          product['fat_specification'],
          product['halal_status'],
          product['supplier_specification'],
          tradingName,
          legalName,
          fullCataloguePath,
          _sectionName(product),
          _specificationName(product),
          _gradeCode(product),
          _gradeName(product),
          ...catalogueNames,
        ];

        return searchableValues.any((value) {
          return value != null &&
              value.toString().toLowerCase().contains(search);
        });
      }).toList();

      _filteredProducts.sort((a, b) {
        final specCompare = _specificationName(
          a,
        ).toLowerCase().compareTo(_specificationName(b).toLowerCase());

        if (specCompare != 0) return specCompare;

        final gradeCompare = _gradeCode(a).compareTo(_gradeCode(b));
        if (gradeCompare != 0) return gradeCompare;

        return _supplierName(
          a,
        ).toLowerCase().compareTo(_supplierName(b).toLowerCase());
      });
    });
  }

  bool _usesCanonicalCatalogue(Map<String, dynamic> product) {
    return product['product_variant_id'] != null;
  }

  Map<String, dynamic>? _findVisiblePrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List || rawPrices.isEmpty) {
      return null;
    }

    Map<String, dynamic>? bestPrice;
    var bestPriority = 0;

    for (final rawPrice in rawPrices) {
      if (rawPrice is! Map) {
        continue;
      }

      final price = Map<String, dynamic>.from(rawPrice);

      if (price['active'] != true) {
        continue;
      }

      final rawPriceList = price['price_lists'];

      if (rawPriceList is! Map) {
        continue;
      }

      final priceList = Map<String, dynamic>.from(rawPriceList);

      if (priceList['active'] != true) {
        continue;
      }

      final visibility = priceList['visibility'] as String?;

      int priority;

      switch (visibility) {
        case 'private':
          priority = 3;
          break;
        case 'approved_customers':
          priority = 2;
          break;
        case 'public':
          priority = 1;
          break;
        default:
          priority = 0;
      }

      if (priority > bestPriority) {
        bestPriority = priority;
        bestPrice = price;
      }
    }

    return bestPrice;
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

  String _formatAvailability(String? value) {
    switch (value) {
      case 'in_stock':
        return 'In stock';
      case 'limited':
        return 'Limited';
      case 'out_of_stock':
        return 'Out of stock';
      case 'made_to_order':
        return 'Made to order';
      default:
        return 'Unknown';
    }
  }

  String _formatTemperature(String? value) {
    switch (value) {
      case 'fresh':
        return 'Fresh';
      case 'chilled':
        return 'Chilled';
      case 'frozen':
        return 'Frozen';
      default:
        return value ?? 'Not specified';
    }
  }

  String _supplierName(Map<String, dynamic> product) {
    final raw = product['businesses'];

    if (raw is! Map) {
      return 'Unknown supplier';
    }

    final supplier = Map<String, dynamic>.from(raw);

    final tradingName = supplier['trading_name']?.toString();

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName;
    }

    return supplier['legal_name']?.toString() ?? 'Unknown supplier';
  }

  String _formatNumber(dynamic value) {
    if (value == null) {
      return '';
    }

    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return value.toString();
    }

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _pieceWeightText(Map<String, dynamic> product) {
    final min = product['piece_weight_min'];
    final max = product['piece_weight_max'];
    final unit = product['piece_weight_unit']?.toString();

    if (min == null && max == null) {
      return '';
    }

    final suffix = unit == null || unit.trim().isEmpty ? '' : ' $unit';

    if (min != null && max != null) {
      return '${_formatNumber(min)}–${_formatNumber(max)}$suffix';
    }

    if (min != null) {
      return '${_formatNumber(min)}+$suffix';
    }

    return 'Up to ${_formatNumber(max)}$suffix';
  }

  String _cartonText(Map<String, dynamic> product) {
    final cartonWeight = product['carton_weight'];
    final cartonUnit = product['carton_weight_unit']?.toString();
    final piecesPerCarton = product['pieces_per_carton'];

    final parts = <String>[];

    if (cartonWeight != null) {
      final suffix = cartonUnit == null || cartonUnit.trim().isEmpty
          ? ''
          : ' $cartonUnit';
      parts.add('${_formatNumber(cartonWeight)}$suffix');
    }

    if (piecesPerCarton != null) {
      parts.add('${_formatNumber(piecesPerCarton)} pcs');
    }

    return parts.join(' • ');
  }

  String _availableText(Map<String, dynamic> product) {
    final quantity = product['available_quantity'];
    final unit = product['quantity_unit']?.toString();

    if (quantity == null) {
      return '';
    }

    final label = switch (unit) {
      'kilogram' => 'kg',
      'carton' => 'cartons',
      'unit' => 'units',
      _ => unit ?? '',
    };

    return '${_formatNumber(quantity)}${label.isEmpty ? '' : ' $label'}';
  }

  String _halalLabel(String? value) {
    switch (value) {
      case 'halal':
        return 'Halal';
      case 'not_halal':
        return 'Not halal';
      default:
        return '';
    }
  }

  Widget _specChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE1E1DE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF5A5A5A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4E4E4E),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _marketplaceChips(
    Map<String, dynamic> product, {
    required bool usesCanonicalCatalogue,
  }) {
    final chips = <Widget>[];

    chips.add(
      _specChip(
        icon: Icons.inventory_2_outlined,
        label: _formatAvailability(product['availability_status'] as String?),
      ),
    );

    final brand = product['brand']?.toString();
    final marbling = product['marbling_score']?.toString();
    final grade = product['grade']?.toString();
    final breedProgram = product['breed_program']?.toString();
    final pieceWeight = _pieceWeightText(product);
    final carton = _cartonText(product);
    final packaging = product['packaging_type']?.toString();
    final trim = product['trim_specification']?.toString();
    final fat = product['fat_specification']?.toString();
    final halal = _halalLabel(product['halal_status']?.toString());
    final originCountry = product['origin_country']?.toString();
    final originState = product['origin_state']?.toString();
    final available = _availableText(product);

    if (brand != null && brand.trim().isNotEmpty) {
      chips.add(_specChip(icon: Icons.sell_outlined, label: brand.trim()));
    }

    if (marbling != null && marbling.trim().isNotEmpty) {
      final clean = marbling.trim().replaceFirst(
        RegExp(r'^mb\s*', caseSensitive: false),
        '',
      );
      chips.add(
        _specChip(icon: Icons.auto_awesome_outlined, label: 'MB $clean'),
      );
    }

    if (grade != null && grade.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.workspace_premium_outlined, label: grade.trim()),
      );
    }

    if (breedProgram != null && breedProgram.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.badge_outlined, label: breedProgram.trim()),
      );
    }

    if (pieceWeight.isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.scale_outlined, label: 'Piece $pieceWeight'),
      );
    }

    if (carton.isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.inventory_2_outlined, label: 'Carton $carton'),
      );
    }

    if (packaging != null && packaging.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.all_inbox_outlined, label: packaging.trim()),
      );
    }

    if (trim != null && trim.trim().isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.content_cut_outlined, label: trim.trim()),
      );
    }

    if (fat != null && fat.trim().isNotEmpty) {
      chips.add(_specChip(icon: Icons.straighten_outlined, label: fat.trim()));
    }

    if (halal.isNotEmpty) {
      chips.add(_specChip(icon: Icons.verified_outlined, label: halal));
    }

    final originParts = <String>[
      if (originState != null && originState.trim().isNotEmpty)
        originState.trim(),
      if (originCountry != null && originCountry.trim().isNotEmpty)
        originCountry.trim(),
    ];

    if (originParts.isNotEmpty) {
      chips.add(
        _specChip(icon: Icons.public_outlined, label: originParts.join(', ')),
      );
    }

    if (available.isNotEmpty) {
      chips.add(
        _specChip(
          icon: Icons.inventory_outlined,
          label: 'Available $available',
        ),
      );
    }

    if (product['catch_weight'] == true) {
      chips.add(
        _specChip(icon: Icons.monitor_weight_outlined, label: 'Catch weight'),
      );
    }

    chips.add(
      _specChip(
        icon: usesCanonicalCatalogue
            ? Icons.account_tree_outlined
            : Icons.history,
        label: usesCanonicalCatalogue
            ? 'Recursive catalogue'
            : 'Legacy listing',
      ),
    );

    return chips;
  }

  Widget _thinChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
        selectedColor: const Color(0xFF741C1C),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFF741C1C) : const Color(0xFFD9D9D5),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF444444),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildSectionStrip() {
    final sections = _selectedAnimalSections;

    if (sections.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 37,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _thinChoice(
            label: 'All cuts',
            selected: _selectedSectionId == null,
            onTap: () {
              setState(() {
                _selectedAnimalRegionKey = null;
                _selectedSectionId = null;
                _selectedSpecificationId = null;
                _selectedGradeId = null;
              });
              _applySearch();
            },
          ),
          for (final section in sections)
            _thinChoice(
              label: section['name']?.toString() ?? 'Cut',
              selected: _selectedSectionId == section['id']?.toString(),
              onTap: () => _selectSection(section),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecificationStrip() {
    final specifications = _availableSpecifications;

    if (specifications.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _thinChoice(
            label: 'All subcategories',
            selected: _selectedSpecificationId == null,
            onTap: () {
              setState(() {
                _selectedSpecificationId = null;
                _selectedGradeId = null;
              });
              _applySearch();
            },
          ),
          for (final specification in specifications)
            _thinChoice(
              label: specification['name']?.toString() ?? 'Subcategory',
              selected:
                  _selectedSpecificationId == specification['id']?.toString(),
              onTap: () {
                setState(() {
                  _selectedSpecificationId = specification['id']?.toString();
                  _selectedGradeId = null;
                });
                _applySearch();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGradeStrip() {
    final grades = _availableGrades;

    if (grades.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _thinChoice(
            label: 'All grades',
            selected: _selectedGradeId == null,
            onTap: () {
              setState(() => _selectedGradeId = null);
              _applySearch();
            },
          ),
          for (final grade in grades)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                selected: _selectedGradeId == grade['id']?.toString(),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selectedColor: const Color(0xFF741C1C),
                backgroundColor: const Color(0xFFF4E5E5),
                side: const BorderSide(color: Color(0xFFD7B8B8)),
                label: Text(
                  grade['code']?.toString() ?? 'N/A',
                  style: TextStyle(
                    color: _selectedGradeId == grade['id']?.toString()
                        ? Colors.white
                        : const Color(0xFF741C1C),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedGradeId = grade['id']?.toString();
                  });
                  _applySearch();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradeBadge(Map<String, dynamic> product) {
    final code = _gradeCode(product);
    final name = _gradeName(product);

    return Container(
      width: 82,
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E5E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7B8B8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF741C1C),
              fontSize: code.length > 3 ? 22 : 28,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (name.isNotEmpty && name.toLowerCase() != code.toLowerCase()) ...[
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 9,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Browse Products',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadProducts,
            tooltip: 'Refresh products',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [Expanded(child: _buildBody())]),
    );
  }

  Widget _buildMarketplaceProductCard(Map<String, dynamic> product) {
    final price = _findVisiblePrice(product);
    final amount = price?['amount'];
    final priceBasis = price?['price_basis'] as String?;
    final usesCanonicalCatalogue = _usesCanonicalCatalogue(product);
    final chips = _marketplaceChips(
      product,
      usesCanonicalCatalogue: usesCanonicalCatalogue,
    );
    final supplierSpecification = product['supplier_specification']?.toString();

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  MarketplaceProductDetailsPage(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;

              final details = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _gradeBadge(product),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _specificationName(product),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _supplierName(product),
                          style: const TextStyle(
                            color: Color(0xFF741C1C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_sectionName(product)} • ${_formatTemperature(product['temperature_state'] as String?)}',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 12,
                          ),
                        ),
                        if (supplierSpecification != null &&
                            supplierSpecification.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            supplierSpecification.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
                    ),
                  ),
                ],
              );

              final priceBlock = Column(
                crossAxisAlignment: narrow
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  const Text(
                    'YOUR PRICE',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 10,
                      letterSpacing: .5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    amount == null
                        ? 'Contact supplier'
                        : '\$${_formatNumber(amount)}'
                              '${_formatPriceBasis(priceBasis).isEmpty ? '' : ' / ${_formatPriceBasis(priceBasis)}'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View supplier offer',
                        style: TextStyle(
                          color: Color(0xFF741C1C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 19,
                        color: Color(0xFF741C1C),
                      ),
                    ],
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, const SizedBox(height: 14), priceBlock],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 20),
                  priceBlock,
                ],
              );
            },
          ),
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
                onPressed: _loadProducts,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Browse meat by animal, cut and grade',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose the exact specification and grade before comparing supplier prices.',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  InteractiveAnimalBrowser(
                    selectedAnimalCode: _selectedAnimalCode,
                    selectedRegionKey: _selectedAnimalRegionKey,
                    onAnimalChanged: _selectAnimal,
                    onRegionSelected: _selectAnimalRegion,
                    maxWidth: 720,
                  ),
                  const SizedBox(height: 14),
                  _buildSectionStrip(),
                  const SizedBox(height: 7),
                  _buildSpecificationStrip(),
                  const SizedBox(height: 7),
                  _buildGradeStrip(),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search cut, grade, supplier, brand, origin or SKU',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_filteredProducts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 42),
                child: Text(
                  'No marketplace products match this animal, cut, grade or search.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              for (final product in _filteredProducts) ...[
                _buildMarketplaceProductCard(product),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
