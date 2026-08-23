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
  bool _isLoadingCatalogue = true;
  bool _isAddingToOrder = false;

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
                ? 'Product added to your draft order.'
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
    final usesCanonicalCatalogue = _usesCanonicalCatalogue();
    final catalogueNames = _catalogueProductPathNames();

    final visiblePrice = _findVisiblePrice();
    final minimumQuantity = visiblePrice?['minimum_quantity'];

    final supplierSpecification = product['supplier_specification']
        ?.toString()
        .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Product Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _openDraftOrdersPage,
            tooltip: 'Draft orders',
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
          const SizedBox(width: 8),
        ],
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 650;

                          final titleBlock = Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _gradeIdentityBadge(),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _newSpecificationName(),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    if (_newSectionName().isNotEmpty)
                                      Text(
                                        [
                                          if (_newAnimalName().isNotEmpty)
                                            _newAnimalName(),
                                          _newSectionName(),
                                        ].join(' • '),
                                        style: const TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _supplierName(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF741C1C),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
                              _buildCustomerPriceDisplay(
                                visiblePrice: visiblePrice,
                                alignment: narrow
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                priceFontSize: 24,
                              ),
                              if (minimumQuantity != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Minimum: ${_formatNumber(minimumQuantity)}',
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ],
                          );

                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                titleBlock,
                                const SizedBox(height: 18),
                                priceBlock,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: titleBlock),
                              const SizedBox(width: 24),
                              priceBlock,
                            ],
                          );
                        },
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

                          if (_halalLabel() != 'Not specified')
                            Chip(
                              avatar: const Icon(
                                Icons.verified_outlined,
                                size: 17,
                              ),
                              label: Text(_halalLabel()),
                            ),

                          if (product['catch_weight'] == true)
                            const Chip(
                              avatar: Icon(
                                Icons.monitor_weight_outlined,
                                size: 17,
                              ),
                              label: Text('Catch weight'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      _section(
                        title: 'Product Information',
                        children: [
                          _DetailRow(
                            label: 'SKU',
                            value: product['sku']?.toString() ?? 'Not provided',
                          ),
                          _DetailRow(
                            label: 'Brand',
                            value: _textValue('brand'),
                          ),
                          _DetailRow(
                            label: 'Available quantity',
                            value: _availableQuantityText(),
                          ),
                          _DetailRow(
                            label: 'Storage condition',
                            value: _formatTemperature(
                              product['temperature_state'] as String?,
                            ),
                          ),
                          _DetailRow(
                            label: 'Availability',
                            value: _formatAvailability(
                              product['availability_status'] as String?,
                            ),
                          ),
                          if (usesCanonicalCatalogue) ...[
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
                        ],
                      ),

                      if (product['meat_specification_id'] != null &&
                          product['meat_grade_id'] != null)
                        _section(
                          title: 'Exact Marketplace Selection',
                          children: [
                            _DetailRow(
                              label: 'Animal',
                              value: _newAnimalName().isEmpty
                                  ? 'Not specified'
                                  : _newAnimalName(),
                            ),
                            _DetailRow(
                              label: 'Cut section',
                              value: _newSectionName().isEmpty
                                  ? 'Not specified'
                                  : _newSectionName(),
                            ),
                            _DetailRow(
                              label: 'Specification',
                              value: _newSpecificationName(),
                            ),
                            _DetailRow(
                              label: 'Grade / category',
                              value: _newGradeName().isEmpty
                                  ? _newGradeCode()
                                  : '${_newGradeCode()} — ${_newGradeName()}',
                            ),
                            const Text(
                              'This exact supplier + specification + grade is what will be locked into the order.',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                      _section(
                        title: 'Meat Specifications',
                        children: [
                          _DetailRow(
                            label: 'Marbling / MB score',
                            value: _textValue('marbling_score'),
                          ),
                          _DetailRow(
                            label: 'Grade',
                            value: _newGradeName().isEmpty
                                ? _newGradeCode()
                                : '${_newGradeCode()} — ${_newGradeName()}',
                          ),
                          _DetailRow(
                            label: 'Breed / program',
                            value: _textValue('breed_program'),
                          ),
                          _DetailRow(
                            label: 'Halal status',
                            value: _halalLabel(),
                          ),
                          _DetailRow(
                            label: 'Trim specification',
                            value: _textValue('trim_specification'),
                          ),
                          _DetailRow(
                            label: 'Fat specification',
                            value: _textValue('fat_specification'),
                          ),
                        ],
                      ),

                      _section(
                        title: 'Piece and Carton Details',
                        children: [
                          _DetailRow(
                            label: 'Piece weight',
                            value: _pieceWeightText(),
                          ),
                          _DetailRow(label: 'Carton', value: _cartonText()),
                          _DetailRow(
                            label: 'Packaging',
                            value: _textValue('packaging_type'),
                          ),
                          _DetailRow(
                            label: 'Catch weight',
                            value: product['catch_weight'] == true
                                ? 'Yes'
                                : 'No',
                          ),
                        ],
                      ),

                      _section(
                        title: 'Origin',
                        children: [
                          _DetailRow(
                            label: 'Country',
                            value: _textValue('origin_country'),
                          ),
                          _DetailRow(
                            label: 'State',
                            value: _textValue('origin_state'),
                          ),
                        ],
                      ),

                      if (supplierSpecification != null &&
                          supplierSpecification.isNotEmpty)
                        _section(
                          title: 'Supplier Specification',
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F8F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE1E1DE),
                                ),
                              ),
                              child: Text(
                                supplierSpecification,
                                style: const TextStyle(
                                  height: 1.5,
                                  color: Color(0xFF4E4E4E),
                                ),
                              ),
                            ),
                          ],
                        ),

                      _section(
                        title: 'Add to Order',
                        children: [
                          Builder(
                            builder: (context) {
                              final price = _findVisiblePrice();
                              final amount = price?['amount'];
                              final quantityUnit = _orderQuantityUnit(price);
                              final unitLabel = _orderQuantityUnitLabel(
                                quantityUnit,
                              );
                              final minimum = price?['minimum_quantity'];
                              final catchWeightKgPricing =
                                  _isCatchWeightKgPricing(price);
                              final requiresWholeNumber =
                                  quantityUnit == 'carton' ||
                                  quantityUnit == 'unit';

                              final unitPrice = amount is num
                                  ? amount.toDouble()
                                  : double.tryParse(amount?.toString() ?? '');

                              final estimatedTotal =
                                  !catchWeightKgPricing && unitPrice != null
                                  ? unitPrice * _orderQuantityPreview
                                  : null;

                              if (amount == null || unitPrice == null) {
                                return const Text(
                                  'A visible price is required before this product can be added to an order.',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    height: 1.5,
                                  ),
                                );
                              }

                              if (product['availability_status'] ==
                                  'out_of_stock') {
                                return const Text(
                                  'This product is currently out of stock and cannot be added to an order.',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    height: 1.5,
                                  ),
                                );
                              }

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final narrow = constraints.maxWidth < 700;

                                  final quantityAndButton = Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    crossAxisAlignment: WrapCrossAlignment.end,
                                    children: [
                                      SizedBox(
                                        width: 190,
                                        child: TextField(
                                          controller: _quantityController,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                decimal: !requiresWholeNumber,
                                              ),
                                          onChanged: (value) {
                                            final parsed = double.tryParse(
                                              value.trim(),
                                            );

                                            setState(() {
                                              _orderQuantityPreview =
                                                  parsed != null && parsed > 0
                                                  ? parsed
                                                  : 0;
                                            });
                                          },
                                          decoration: InputDecoration(
                                            labelText: 'Quantity',
                                            suffixText: unitLabel,
                                            helperText: catchWeightKgPricing
                                                ? 'Enter the number of cartons to order. Final weight is confirmed by the supplier.'
                                                : minimum == null
                                                ? null
                                                : 'Minimum ${_formatNumber(minimum)}',
                                            border: const OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _isAddingToOrder
                                            ? null
                                            : _addToOrder,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF741C1C,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 18,
                                          ),
                                        ),
                                        icon: _isAddingToOrder
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.add_shopping_cart,
                                              ),
                                        label: Text(
                                          _isAddingToOrder
                                              ? 'Adding'
                                              : 'Add to Order',
                                        ),
                                      ),
                                    ],
                                  );

                                  final priceSummary = Container(
                                    width: narrow ? double.infinity : 290,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F8F6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE1E1DE),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Price',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${_formatMoney(unitPrice)} / ${_formatPriceBasis(price?['price_basis']?.toString())}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF741C1C),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Divider(height: 1),
                                        const SizedBox(height: 14),
                                        if (catchWeightKgPricing) ...[
                                          const Text(
                                            'Final total',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          const Text(
                                            'Pending final weight',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            '${_formatNumber(_orderQuantityPreview)} $unitLabel ordered at ${_formatMoney(unitPrice)} / kg',
                                            style: const TextStyle(
                                              color: Color(0xFF666666),
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          const Text(
                                            'The supplier confirms the actual kilograms when the order is prepared.',
                                            style: TextStyle(
                                              color: Color(0xFF666666),
                                              height: 1.4,
                                            ),
                                          ),
                                        ] else ...[
                                          const Text(
                                            'Order total',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            estimatedTotal == null
                                                ? '\$0.00'
                                                : _formatMoney(estimatedTotal),
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${_formatNumber(_orderQuantityPreview)} $unitLabel × ${_formatMoney(unitPrice)}',
                                            style: const TextStyle(
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );

                                  if (narrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        priceSummary,
                                        const SizedBox(height: 16),
                                        quantityAndButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      priceSummary,
                                      const SizedBox(width: 20),
                                      Expanded(child: quantityAndButton),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      _section(
                        title: 'Supplier Access',
                        children: [
                          const Text(
                            'Request access to become an approved customer of this supplier and view customer-only pricing.',
                            style: TextStyle(
                              color: Color(0xFF5E5E5E),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildRelationshipButton(),
                        ],
                      ),
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
