import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../orders/presentation/draft_orders_page.dart';

class MarketplaceProductDetailsPage extends StatefulWidget {
  const MarketplaceProductDetailsPage({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  State<MarketplaceProductDetailsPage> createState() =>
      _MarketplaceProductDetailsPageState();
}

class _MarketplaceProductDetailsPageState
    extends State<MarketplaceProductDetailsPage> {
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  bool _isCheckingRelationship = true;
  bool _isSubmittingRequest = false;
  // ignore: unused_field
  bool _isLoadingCatalogue = true;
  bool _isAddingToOrder = false;

  // ignore: unused_field
  double _orderQuantityPreview = 1;

  String? _relationshipStatus;
  String? _butcherBusinessId;

  Map<String, dynamic>? _cataloguePathRecord;

  @override
  void initState() {
    super.initState();
    _loadRelationshipStatus();
    _loadCataloguePath();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadCataloguePath() async {
    if (!_usesCanonicalCatalogue()) {
      if (!mounted) return;

      setState(() {
        _isLoadingCatalogue = false;
      });
      return;
    }

    try {
      final variant = _variant();
      final meatProductId = variant?['meat_product_id']?.toString();

      if (meatProductId == null || meatProductId.trim().isEmpty) {
        if (!mounted) return;

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

      if (!mounted) return;

      setState(() {
        _cataloguePathRecord = Map<String, dynamic>.from(response);
        _isLoadingCatalogue = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

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
      if (!mounted) return;

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

      if (!mounted) return;

      setState(() {
        _butcherBusinessId = butcherBusinessId;
        _relationshipStatus = relationships.isEmpty
            ? null
            : relationships.first['status'] as String?;
        _isCheckingRelationship = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _isCheckingRelationship = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;

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

    if (butcherBusinessId == null) return;

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

      if (!mounted) return;

      setState(() {
        _relationshipStatus = 'requested';
        _isSubmittingRequest = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier access request sent.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

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
        if (part.isNotEmpty) names.add(part);
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

  // ignore: unused_element
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

  // ignore: unused_element
  String _fullCataloguePath() {
    if (_usesCanonicalCatalogue()) {
      final parts = <String>[];

      final species = _speciesName();
      final cataloguePath = _catalogueProductPath();
      final variant = _variantName();

      if (species != 'Not linked') parts.add(species);
      if (cataloguePath != 'Not linked') parts.add(cataloguePath);
      if (variant != 'Not linked') parts.add(variant);

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

  Map<String, dynamic>? _findVisiblePrice() {
    final rawPrices = widget.product['product_prices'];

    if (rawPrices is! List || rawPrices.isEmpty) {
      return null;
    }

    Map<String, dynamic>? bestPrice;
    var bestPriority = 0;

    for (final rawPrice in rawPrices) {
      if (rawPrice is! Map) continue;

      final price = Map<String, dynamic>.from(rawPrice);
      if (price['active'] != true) continue;

      final rawPriceList = price['price_lists'];
      if (rawPriceList is! Map) continue;

      final priceList = Map<String, dynamic>.from(rawPriceList);
      if (priceList['active'] != true) continue;

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

  Map<String, dynamic>? _priceForVisibility(String visibility) {
    final rawPrices = widget.product['product_prices'];

    if (rawPrices is! List) {
      return null;
    }

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

      if (priceList['visibility']?.toString() == visibility) {
        return price;
      }
    }

    return null;
  }

  String _visiblePriceLabel(Map<String, dynamic>? price) {
    final rawPriceList = price?['price_lists'];

    if (rawPriceList is! Map) {
      return 'Standard Price';
    }

    switch (rawPriceList['visibility']?.toString()) {
      case 'private':
        return 'Your Special Price';
      case 'approved_customers':
        return 'Your Trade Price';
      case 'public':
      default:
        return 'Standard Price';
    }
  }

  Widget _buildCustomerPriceDisplay({
    required Map<String, dynamic>? visiblePrice,
    required CrossAxisAlignment alignment,
    double priceFontSize = 24,
  }) {
    if (visiblePrice == null || visiblePrice['amount'] == null) {
      return const Text(
        'Price unavailable',
        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF666666)),
      );
    }

    final visibleAmountRaw = visiblePrice['amount'];
    final visibleAmount = visibleAmountRaw is num
        ? visibleAmountRaw.toDouble()
        : double.tryParse('$visibleAmountRaw');

    final visibleBasis = visiblePrice['price_basis']?.toString();

    final standardPrice = _priceForVisibility('public');
    final standardAmountRaw = standardPrice?['amount'];
    final standardAmount = standardAmountRaw is num
        ? standardAmountRaw.toDouble()
        : double.tryParse('${standardAmountRaw ?? ''}');

    final standardBasis = standardPrice?['price_basis']?.toString();

    final priceLabel = _visiblePriceLabel(visiblePrice);
    final isDiscountedPrice =
        priceLabel != 'Standard Price' &&
        visibleAmount != null &&
        standardAmount != null &&
        standardAmount > visibleAmount &&
        standardBasis == visibleBasis;

    final saving = isDiscountedPrice ? standardAmount - visibleAmount : null;

    final savingPercent = isDiscountedPrice && standardAmount > 0
        ? (saving! / standardAmount) * 100
        : null;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (isDiscountedPrice) ...[
          Text(
            '${_formatMoney(standardAmount)} / ${_formatPriceBasis(standardBasis)}',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF777777),
              decoration: TextDecoration.lineThrough,
              decorationThickness: 2,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          '${_formatMoney(visibleAmountRaw)} / ${_formatPriceBasis(visibleBasis)}',
          style: TextStyle(
            fontSize: priceFontSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF741C1C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          priceLabel,
          style: TextStyle(
            color: priceLabel == 'Standard Price'
                ? const Color(0xFF666666)
                : const Color(0xFF741C1C),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        if (saving != null && savingPercent != null) ...[
          const SizedBox(height: 5),
          Text(
            'You save ${_formatMoney(saving)} / ${_formatPriceBasis(visibleBasis)} • ${savingPercent.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  String _orderQuantityUnit(Map<String, dynamic>? visiblePrice) {
    final configuredOrderUnit = widget.product['order_unit']?.toString();

    if (configuredOrderUnit == 'kilogram' ||
        configuredOrderUnit == 'carton' ||
        configuredOrderUnit == 'unit') {
      return configuredOrderUnit!;
    }

    final productUnit = widget.product['quantity_unit']?.toString();

    if (productUnit == 'kilogram' ||
        productUnit == 'carton' ||
        productUnit == 'unit') {
      return productUnit!;
    }

    final basis = visiblePrice?['price_basis']?.toString();

    if (basis == 'kilogram' || basis == 'carton' || basis == 'unit') {
      return basis!;
    }

    return 'unit';
  }

  bool _isCatchWeightProduct() {
    return widget.product['weight_type']?.toString() == 'catch_weight' ||
        widget.product['catch_weight'] == true;
  }

  bool _isCatchWeightKgPricing(Map<String, dynamic>? visiblePrice) {
    return _isCatchWeightProduct() &&
        visiblePrice?['price_basis']?.toString() == 'kilogram';
  }

  String _orderQuantityUnitLabel(String value) {
    switch (value) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'cartons';
      case 'unit':
        return 'units';
      default:
        return value;
    }
  }

  Map<String, dynamic>? _taxonomyMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  String _newAnimalName() {
    return _taxonomyMap(
          widget.product['meat_animals'],
        )?['name']?.toString().trim() ??
        '';
  }

  String _newSectionName() {
    return _taxonomyMap(
          widget.product['meat_sections'],
        )?['name']?.toString().trim() ??
        '';
  }

  String _newSpecificationName() {
    final value = _taxonomyMap(
      widget.product['meat_specifications'],
    )?['name']?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return widget.product['product_name']?.toString().trim() ??
        'Unnamed product';
  }

  String _newGradeCode() {
    final value = _taxonomyMap(
      widget.product['meat_grades'],
    )?['code']?.toString().trim();

    if (value != null && value.isNotEmpty) return value;

    final legacy = widget.product['grade']?.toString().trim();
    if (legacy != null && legacy.isNotEmpty) {
      final dash = legacy.indexOf(' - ');
      return dash > 0 ? legacy.substring(0, dash).trim() : legacy;
    }

    return 'N/A';
  }

  String _newGradeName() {
    final value = _taxonomyMap(
      widget.product['meat_grades'],
    )?['name']?.toString().trim();

    if (value != null && value.isNotEmpty) return value;
    return '';
  }

  String _orderLineProductNameSnapshot() {
    final specification = _newSpecificationName();
    final grade = _newGradeCode();

    if (grade == 'N/A') {
      return specification;
    }

    return '$specification • $grade';
  }

  Widget _gradeIdentityBadge() {
    final code = _newGradeCode();
    final name = _newGradeName();

    return Container(
      width: 104,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E5E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7B8B8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'GRADE',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 9,
              letterSpacing: .8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF741C1C),
              fontSize: code.length > 3 ? 25 : 33,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (name.isNotEmpty && name.toLowerCase() != code.toLowerCase()) ...[
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 9.5,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addToOrder() async {
    if (_isAddingToOrder) {
      return;
    }

    final butcherBusinessId = _butcherBusinessId;

    if (butcherBusinessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your butcher business could not be identified.'),
        ),
      );
      return;
    }

    final visiblePrice = _findVisiblePrice();

    if (visiblePrice == null || visiblePrice['amount'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This product does not currently have a visible price.',
          ),
        ),
      );
      return;
    }

    if (widget.product['availability_status'] == 'out_of_stock') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is currently out of stock.'),
        ),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity greater than 0.')),
      );
      return;
    }

    final quantityUnit = _orderQuantityUnit(visiblePrice);
    final catchWeightKgPricing = _isCatchWeightKgPricing(visiblePrice);
    final requiresWholeNumber =
        quantityUnit == 'carton' || quantityUnit == 'unit';

    if (requiresWholeNumber && quantity != quantity.roundToDouble()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cartons and units must be entered as whole numbers.'),
        ),
      );
      return;
    }

    final minimumRaw = visiblePrice['minimum_quantity'];
    final minimum = minimumRaw is num
        ? minimumRaw.toDouble()
        : double.tryParse(minimumRaw?.toString() ?? '');

    if (!catchWeightKgPricing && minimum != null && quantity < minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum order quantity is ${_formatNumber(minimum)}.'),
        ),
      );
      return;
    }

    final supplierBusinessId = widget.product['supplier_business_id']
        ?.toString();
    final productId = widget.product['id']?.toString();

    if (supplierBusinessId == null ||
        supplierBusinessId.isEmpty ||
        productId == null ||
        productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is missing required order information.'),
        ),
      );
      return;
    }

    final unitPriceRaw = visiblePrice['amount'];
    final unitPrice = unitPriceRaw is num
        ? unitPriceRaw.toDouble()
        : double.tryParse(unitPriceRaw.toString());

    if (unitPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The visible price could not be read.')),
      );
      return;
    }

    final catchWeightSnapshot = _isCatchWeightProduct();
    final priceBasis = catchWeightSnapshot
        ? 'kilogram'
        : visiblePrice['price_basis']?.toString();

    setState(() {
      _isAddingToOrder = true;
    });

    try {
      final client = Supabase.instance.client;

      final draftOrders = await client
          .from('orders')
          .select('id, order_number')
          .eq('butcher_business_id', butcherBusinessId)
          .eq('supplier_business_id', supplierBusinessId)
          .eq('status', 'draft')
          .order('created_at', ascending: false)
          .limit(1);

      late String orderId;
      String? orderNumber;

      if (draftOrders.isNotEmpty) {
        orderId = draftOrders.first['id'].toString();
        orderNumber = draftOrders.first['order_number']?.toString();
      } else {
        final createdOrder = await client
            .from('orders')
            .insert({
              'butcher_business_id': butcherBusinessId,
              'supplier_business_id': supplierBusinessId,
            })
            .select('id, order_number')
            .single();

        orderId = createdOrder['id'].toString();
        orderNumber = createdOrder['order_number']?.toString();
      }

      final existingItems = await client
          .from('order_items')
          .select('id, quantity')
          .eq('order_id', orderId)
          .eq('product_id', productId)
          .limit(1);

      final productName = _orderLineProductNameSnapshot();
      final sku = widget.product['sku']?.toString();

      if (existingItems.isNotEmpty) {
        final existingQuantityRaw = existingItems.first['quantity'];
        final existingQuantity = existingQuantityRaw is num
            ? existingQuantityRaw.toDouble()
            : double.tryParse(existingQuantityRaw?.toString() ?? '') ?? 0;

        await client
            .from('order_items')
            .update({
              'product_name_snapshot': productName,
              'sku_snapshot': sku,
              'quantity': existingQuantity + quantity,
              'quantity_unit': quantityUnit,
              'unit_price': unitPrice,
              'price_basis': priceBasis,
              'catch_weight_snapshot': catchWeightSnapshot,
            })
            .eq('id', existingItems.first['id']);
      } else {
        await client.from('order_items').insert({
          'order_id': orderId,
          'product_id': productId,
          'product_name_snapshot': productName,
          'sku_snapshot': sku,
          'quantity': quantity,
          'quantity_unit': quantityUnit,
          'unit_price': unitPrice,
          'price_basis': priceBasis,
          'catch_weight_snapshot': catchWeightSnapshot,
        });
      }

      if (!mounted) {
        return;
      }

      _quantityController.text = '1';

      setState(() {
        _orderQuantityPreview = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderNumber == null || orderNumber.trim().isEmpty
                ? 'Product added to your cart.'
                : 'Product added to $orderNumber.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add product to order: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToOrder = false;
        });
      }
    }
  }

  String _withThousandsSeparators(String value) {
    final parts = value.split('.');
    final whole = parts.first;
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    final formattedWhole = '${negative ? '-' : ''}${buffer.toString()}';

    if (parts.length == 1) {
      return formattedWhole;
    }

    return '$formattedWhole.${parts.sublist(1).join('.')}';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '';

    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) return value.toString();

    if (number == number.roundToDouble()) {
      return _withThousandsSeparators(number.toInt().toString());
    }

    final formatted = number
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return _withThousandsSeparators(formatted);
  }

  String _formatMoney(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return '\$0.00';
    }

    return '\$${_withThousandsSeparators(number.toStringAsFixed(2))}';
  }

  String _pieceWeightText() {
    final min = widget.product['piece_weight_min'];
    final max = widget.product['piece_weight_max'];
    final unit = widget.product['piece_weight_unit']?.toString();

    if (min == null && max == null) {
      return 'Not provided';
    }

    final suffix = unit == null || unit.trim().isEmpty ? '' : ' ${unit.trim()}';

    if (min != null && max != null) {
      return '${_formatNumber(min)}–${_formatNumber(max)}$suffix';
    }

    if (min != null) {
      return '${_formatNumber(min)}+$suffix';
    }

    return 'Up to ${_formatNumber(max)}$suffix';
  }

  String _cartonText() {
    final cartonWeight = widget.product['carton_weight'];
    final cartonUnit = widget.product['carton_weight_unit']?.toString();
    final piecesPerCarton = widget.product['pieces_per_carton'];

    final parts = <String>[];

    if (cartonWeight != null) {
      final suffix = cartonUnit == null || cartonUnit.trim().isEmpty
          ? ''
          : ' ${cartonUnit.trim()}';
      parts.add('${_formatNumber(cartonWeight)}$suffix');
    }

    if (piecesPerCarton != null) {
      parts.add('${_formatNumber(piecesPerCarton)} pieces');
    }

    if (parts.isEmpty) {
      return 'Not provided';
    }

    return parts.join(' • ');
  }

  String _availableQuantityText() {
    final quantity = widget.product['available_quantity'];
    final unit = widget.product['quantity_unit']?.toString();

    if (quantity == null) {
      return 'Not provided';
    }

    final label = switch (unit) {
      'kilogram' => 'kg',
      'carton' => 'cartons',
      'unit' => 'units',
      _ => unit ?? '',
    };

    return '${_formatNumber(quantity)}${label.isEmpty ? '' : ' $label'}';
  }

  String _halalLabel() {
    switch (widget.product['halal_status']?.toString()) {
      case 'halal':
        return 'Halal';
      case 'not_halal':
        return 'Not halal';
      default:
        return 'Not specified';
    }
  }

  String _textValue(String key) {
    final value = widget.product[key]?.toString().trim();

    if (value == null || value.isEmpty) {
      return 'Not provided';
    }

    return value;
  }

  Future<void> _openDraftOrdersPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DraftOrdersPage()));
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

  // ignore: unused_element
  Widget _section({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final visiblePrice = _findVisiblePrice();
    final rawPrice = visiblePrice?['amount'];
    final amount = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse('$rawPrice');
    final quantityUnit = _orderQuantityUnit(visiblePrice);
    final unitLabel = _orderQuantityUnitLabel(quantityUnit);
    final catchWeight = _isCatchWeightKgPricing(visiblePrice);
    final minimum = visiblePrice?['minimum_quantity'];
    final supplierSpecification = product['supplier_specification']
        ?.toString()
        .trim();

    Widget infoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 125,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget panel({
      required String title,
      required Widget child,
      IconData? icon,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: const Color(0xFF741C1C)),
                  const SizedBox(width: 7),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            child,
          ],
        ),
      );
    }

    Widget informationColumn() {
      return Column(
        children: [
          panel(
            title: 'Product',
            icon: Icons.inventory_2_outlined,
            child: Column(
              children: [
                infoRow(
                  'Animal',
                  _newAnimalName().isEmpty ? 'Not specified' : _newAnimalName(),
                ),
                infoRow(
                  'Cut',
                  _newSectionName().isEmpty
                      ? 'Not specified'
                      : _newSectionName(),
                ),
                infoRow('Subcategory', _newSpecificationName()),
                infoRow(
                  'Grade',
                  _newGradeName().isEmpty
                      ? _newGradeCode()
                      : '${_newGradeCode()} — ${_newGradeName()}',
                ),
                infoRow('SKU', product['sku']?.toString() ?? 'Not provided'),
                infoRow('Brand', _textValue('brand')),
                infoRow(
                  'Storage',
                  _formatTemperature(product['temperature_state'] as String?),
                ),
                infoRow(
                  'Availability',
                  _formatAvailability(
                    product['availability_status'] as String?,
                  ),
                ),
                infoRow('Available', _availableQuantityText()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          panel(
            title: 'Specification',
            icon: Icons.tune_outlined,
            child: Column(
              children: [
                infoRow('Marbling / MB', _textValue('marbling_score')),
                infoRow('Breed / program', _textValue('breed_program')),
                infoRow('Halal status', _halalLabel()),
                infoRow('Trim', _textValue('trim_specification')),
                infoRow('Fat spec', _textValue('fat_specification')),
                infoRow('Piece weight', _pieceWeightText()),
                infoRow('Carton', _cartonText()),
                infoRow('Packaging', _textValue('packaging_type')),
                infoRow(
                  'Catch weight',
                  product['catch_weight'] == true ? 'Yes' : 'No',
                ),
                infoRow(
                  'Origin',
                  [
                        if (_textValue('origin_state') != 'Not provided')
                          _textValue('origin_state'),
                        if (_textValue('origin_country') != 'Not provided')
                          _textValue('origin_country'),
                      ].join(', ').isEmpty
                      ? 'Not provided'
                      : [
                          if (_textValue('origin_state') != 'Not provided')
                            _textValue('origin_state'),
                          if (_textValue('origin_country') != 'Not provided')
                            _textValue('origin_country'),
                        ].join(', '),
                ),
              ],
            ),
          ),
          if (supplierSpecification != null &&
              supplierSpecification.isNotEmpty) ...[
            const SizedBox(height: 10),
            panel(
              title: 'Supplier Notes',
              icon: Icons.notes_outlined,
              child: Text(
                supplierSpecification,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      );
    }

    Widget orderPanel() {
      final canAdd =
          amount != null &&
          product['availability_status']?.toString() != 'out_of_stock';

      return panel(
        title: 'Add to Cart',
        icon: Icons.shopping_cart_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCustomerPriceDisplay(
              visiblePrice: visiblePrice,
              alignment: CrossAxisAlignment.start,
              priceFontSize: 25,
            ),
            if (minimum != null) ...[
              const SizedBox(height: 6),
              Text(
                'Minimum ${_formatNumber(minimum)} $unitLabel',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.numberWithOptions(
                decimal: quantityUnit == 'kilogram',
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value.trim());
                setState(() {
                  _orderQuantityPreview = parsed != null && parsed > 0
                      ? parsed
                      : 0;
                });
              },
              decoration: InputDecoration(
                labelText: 'Quantity',
                suffixText: unitLabel,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (catchWeight) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Final total pending weight. The supplier confirms actual kilograms during fulfilment.',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 11),
            FilledButton.icon(
              onPressed: !canAdd || _isAddingToOrder ? null : _addToOrder,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isAddingToOrder
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_shopping_cart),
              label: Text(_isAddingToOrder ? 'Adding...' : 'Add to Cart'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openDraftOrdersPage,
              icon: const Icon(Icons.shopping_cart_checkout_outlined),
              label: const Text('View Cart'),
            ),
          ],
        ),
      );
    }

    Widget supplierPanel() {
      return panel(
        title: 'Supplier',
        icon: Icons.storefront_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _supplierName(),
              style: const TextStyle(
                color: Color(0xFF741C1C),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            _buildRelationshipButton(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Product Information',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _openDraftOrdersPage,
            tooltip: 'Cart',
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0DD)),
                  ),
                  child: Row(
                    children: [
                      _gradeIdentityBadge(),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _newSpecificationName(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (_newAnimalName().isNotEmpty)
                                  _newAnimalName(),
                                if (_newSectionName().isNotEmpty)
                                  _newSectionName(),
                                _supplierName(),
                              ].join(' • '),
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (amount != null)
                        Text(
                          '\$${_formatNumber(amount)}'
                          '${_formatPriceBasis(visiblePrice?['price_basis']?.toString()).isEmpty ? '' : ' / ${_formatPriceBasis(visiblePrice?['price_basis']?.toString())}'}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 850;

                      if (narrow) {
                        return ListView(
                          children: [
                            informationColumn(),
                            const SizedBox(height: 10),
                            supplierPanel(),
                            const SizedBox(height: 10),
                            orderPanel(),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              child: informationColumn(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 350,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  supplierPanel(),
                                  const SizedBox(height: 10),
                                  orderPanel(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(value),
              ],
            );
          }

          return Row(
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
          );
        },
      ),
    );
  }
}
