import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceProductDetailsPage extends StatefulWidget {
  const MarketplaceProductDetailsPage({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  State<MarketplaceProductDetailsPage> createState() =>
      _MarketplaceProductDetailsPageState();
}

class _MarketplaceProductDetailsPageState
    extends State<MarketplaceProductDetailsPage> {
  bool _isCheckingRelationship = true;
  bool _isSubmittingRequest = false;
  bool _isLoadingCatalogue = true;

  String? _relationshipStatus;
  String? _butcherBusinessId;

  Map<String, dynamic>? _cataloguePathRecord;

  @override
  void initState() {
    super.initState();

    _loadRelationshipStatus();
    _loadCataloguePath();
  }

  Future<void> _loadCataloguePath() async {
    if (!_usesCanonicalCatalogue()) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCatalogue = false;
      });

      return;
    }

    try {
      final variant = _variant();

      final meatProductId = variant?['meat_product_id']?.toString();

      if (meatProductId == null || meatProductId.trim().isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _cataloguePathRecord = null;
          _isLoadingCatalogue = false;
        });

        return;
      }

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
            path_names,
            catalogue_path
            ''')
          .eq('id', meatProductId)
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _cataloguePathRecord = Map<String, dynamic>.from(response);

        _isLoadingCatalogue = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cataloguePathRecord = null;
        _isLoadingCatalogue = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catalogue could not be loaded: ${error.message}'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cataloguePathRecord = null;
        _isLoadingCatalogue = false;
      });
    }
  }

  Future<void> _loadRelationshipStatus() async {
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

      final butcherBusinessId = membership['business_id'] as String;

      final supplierBusinessId =
          widget.product['supplier_business_id'] as String;

      final relationships = await Supabase.instance.client
          .from('supplier_customer_relationships')
          .select('status')
          .eq('supplier_business_id', supplierBusinessId)
          .eq('butcher_business_id', butcherBusinessId)
          .limit(1);

      if (!mounted) {
        return;
      }

      setState(() {
        _butcherBusinessId = butcherBusinessId;

        _relationshipStatus = relationships.isEmpty
            ? null
            : relationships.first['status'] as String?;

        _isCheckingRelationship = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingRelationship = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingRelationship = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to check supplier access.')),
      );
    }
  }

  Future<void> _requestSupplierAccess() async {
    final butcherBusinessId = _butcherBusinessId;

    if (butcherBusinessId == null) {
      return;
    }

    setState(() {
      _isSubmittingRequest = true;
    });

    try {
      await Supabase.instance.client
          .from('supplier_customer_relationships')
          .insert({
            'supplier_business_id': widget.product['supplier_business_id'],
            'butcher_business_id': butcherBusinessId,
            'status': 'requested',
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _relationshipStatus = 'requested';
        _isSubmittingRequest = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier access request sent.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingRequest = false;
      });

      var message = error.message;

      if (error.code == '23505') {
        message = 'A supplier relationship already exists.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Map<String, dynamic>? _variant() {
    final raw = widget.product['product_variants'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return null;
  }

  bool _usesCanonicalCatalogue() {
    return widget.product['product_variant_id'] != null;
  }

  String _speciesName() {
    final name = _cataloguePathRecord?['species_name']?.toString();

    if (name != null && name.trim().isNotEmpty) {
      return name;
    }

    final rawAnimalType = widget.product['animal_types'];

    if (rawAnimalType is Map) {
      return rawAnimalType['name']?.toString() ?? 'Not linked';
    }

    return 'Not linked';
  }

  List<String> _catalogueProductPathNames() {
    final names = <String>[];

    final rawPathNames = _cataloguePathRecord?['path_names'];

    if (rawPathNames is List) {
      for (final rawName in rawPathNames) {
        final name = rawName?.toString();

        if (name != null && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }

      return names;
    }

    final cataloguePath = _cataloguePathRecord?['catalogue_path']?.toString();

    if (cataloguePath != null && cataloguePath.trim().isNotEmpty) {
      for (final rawPart in cataloguePath.split('→')) {
        final part = rawPart.trim();

        if (part.isNotEmpty) {
          names.add(part);
        }
      }
    }

    return names;
  }

  String _catalogueProductPath() {
    final path = _cataloguePathRecord?['catalogue_path']?.toString();

    if (path != null && path.trim().isNotEmpty) {
      return path;
    }

    final names = _catalogueProductPathNames();

    if (names.isNotEmpty) {
      return names.join(' → ');
    }

    return 'Not linked';
  }

  String _currentCatalogueProductName() {
    final name = _cataloguePathRecord?['name']?.toString();

    if (name != null && name.trim().isNotEmpty) {
      return name;
    }

    final names = _catalogueProductPathNames();

    if (names.isNotEmpty) {
      return names.last;
    }

    final rawCut = widget.product['cuts'];

    if (rawCut is Map) {
      return rawCut['name']?.toString() ?? 'Not linked';
    }

    return 'Not linked';
  }

  String _variantName() {
    final variant = _variant();

    final name = variant?['variant_name']?.toString();

    if (name != null && name.trim().isNotEmpty) {
      return name;
    }

    return 'Not linked';
  }

  String _fullCataloguePath() {
    if (_usesCanonicalCatalogue()) {
      final parts = <String>[];

      final species = _speciesName();

      final cataloguePath = _catalogueProductPath();

      final variant = _variantName();

      if (species != 'Not linked') {
        parts.add(species);
      }

      if (cataloguePath != 'Not linked') {
        parts.add(cataloguePath);
      }

      if (variant != 'Not linked') {
        parts.add(variant);
      }

      if (parts.isNotEmpty) {
        return parts.join(' → ');
      }
    }

    final legacyParts = <String>[];

    final rawAnimalType = widget.product['animal_types'];

    final rawCut = widget.product['cuts'];

    if (rawAnimalType is Map) {
      final animalName = rawAnimalType['name']?.toString();

      if (animalName != null && animalName.trim().isNotEmpty) {
        legacyParts.add(animalName);
      }
    }

    if (rawCut is Map) {
      final cutName = rawCut['name']?.toString();

      if (cutName != null && cutName.trim().isNotEmpty) {
        legacyParts.add(cutName);
      }
    }

    if (legacyParts.isNotEmpty) {
      return legacyParts.join(' → ');
    }

    return 'Catalogue not linked';
  }

  String _supplierName() {
    final raw = widget.product['businesses'];

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

  String _formatAvailability(String? value) {
    switch (value) {
      case 'in_stock':
        return 'In stock';

      case 'limited':
        return 'Limited stock';

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

      case 'frozen':
        return 'Frozen';

      case 'chilled':
        return 'Chilled';

      default:
        return value ?? 'Not specified';
    }
  }

  Widget _buildRelationshipButton() {
    if (_isCheckingRelationship) {
      return const CircularProgressIndicator();
    }

    switch (_relationshipStatus) {
      case 'approved':
        return const Chip(
          avatar: Icon(Icons.verified, size: 18),
          label: Text('Approved customer'),
        );

      case 'requested':
        return const Chip(
          avatar: Icon(Icons.schedule, size: 18),
          label: Text('Access request pending'),
        );

      case 'declined':
        return const Chip(
          avatar: Icon(Icons.cancel_outlined, size: 18),
          label: Text('Access request declined'),
        );

      case 'suspended':
        return const Chip(
          avatar: Icon(Icons.block, size: 18),
          label: Text('Supplier access suspended'),
        );

      default:
        return FilledButton.icon(
          onPressed: _isSubmittingRequest ? null : _requestSupplierAccess,
          icon: _isSubmittingRequest
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add_alt_1),
          label: Text(
            _isSubmittingRequest
                ? 'Sending Request'
                : 'Request Supplier Access',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    final usesCanonicalCatalogue = _usesCanonicalCatalogue();

    final catalogueNames = _catalogueProductPathNames();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Product Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['product_name'] as String? ?? 'Unnamed product',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _supplierName(),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF741C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 22),

                      if (_isLoadingCatalogue && usesCanonicalCatalogue)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: LinearProgressIndicator(),
                        )
                      else
                        Text(
                          _fullCataloguePath(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5E5E5E),
                            height: 1.5,
                          ),
                        ),

                      const SizedBox(height: 18),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (_speciesName() != 'Not linked')
                            Chip(label: Text(_speciesName())),

                          if (usesCanonicalCatalogue)
                            for (final name in catalogueNames)
                              Chip(label: Text(name)),

                          if (!usesCanonicalCatalogue &&
                              _currentCatalogueProductName() != 'Not linked')
                            Chip(label: Text(_currentCatalogueProductName())),

                          Chip(
                            label: Text(
                              _formatTemperature(
                                product['temperature_state'] as String?,
                              ),
                            ),
                          ),

                          Chip(
                            label: Text(
                              _formatAvailability(
                                product['availability_status'] as String?,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      const Divider(),

                      const SizedBox(height: 20),

                      const Text(
                        'Product Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 18),

                      _DetailRow(
                        label: 'SKU',
                        value: product['sku']?.toString() ?? 'Not provided',
                      ),

                      _DetailRow(
                        label: 'Brand',
                        value: product['brand']?.toString() ?? 'Not provided',
                      ),

                      _DetailRow(
                        label: 'Available quantity',
                        value:
                            '${product['available_quantity'] ?? 'Not provided'} '
                            '${product['quantity_unit'] ?? ''}',
                      ),

                      if (usesCanonicalCatalogue) ...[
                        const SizedBox(height: 8),

                        _DetailRow(label: 'Species', value: _speciesName()),

                        _DetailRow(
                          label: 'Catalogue path',
                          value: _catalogueProductPath(),
                        ),

                        _DetailRow(
                          label: 'Current product / cut',
                          value: _currentCatalogueProductName(),
                        ),

                        _DetailRow(label: 'Variant', value: _variantName()),
                      ],

                      const SizedBox(height: 28),

                      const Divider(),

                      const SizedBox(height: 20),

                      const Text(
                        'Supplier Access',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Request access to become an approved customer of this supplier and view customer-only pricing.',
                        style: TextStyle(color: Color(0xFF5E5E5E), height: 1.5),
                      ),

                      const SizedBox(height: 20),

                      _buildRelationshipButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 210,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
