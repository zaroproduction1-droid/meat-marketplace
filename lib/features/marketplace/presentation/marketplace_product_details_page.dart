import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/animal_catalogues/product_variant.dart';
import '../../orders/presentation/draft_orders_page.dart';
import '../../../shared/widgets/catalogue_product_image.dart';

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

  Map<String, dynamic> _supplierProfile = {};
  bool _loadingSupplierProfile = true;
  bool _supplierProfileFailed = false;

  Future<void> _loadSupplierProfile() async {
    if (mounted) {
      setState(() {
        _loadingSupplierProfile = true;
        _supplierProfileFailed = false;
      });
    }
    try {
      final id = widget.product['supplier_business_id']?.toString();
      if (id == null || id.isEmpty) throw StateError('Missing supplier');
      final profile = await Supabase.instance.client
          .from('businesses')
          .select(
            'trading_name, legal_name, logo_path, business_email, business_phone, '
            'address_line_1, address_line_2, suburb, state, postcode',
          )
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _supplierProfile = profile == null
            ? {}
            : Map<String, dynamic>.from(profile);
        _supplierProfileFailed = profile == null;
      });
    } catch (_) {
      if (mounted) setState(() => _supplierProfileFailed = true);
    } finally {
      if (mounted) setState(() => _loadingSupplierProfile = false);
    }
  }

  Widget _supplierContactPanel() {
    String value(String key) => _supplierProfile[key]?.toString().trim() ?? '';
    final embedded = widget.product['businesses'];
    final logoPath = value('logo_path').isNotEmpty
        ? value('logo_path')
        : embedded is Map
        ? embedded['logo_path']?.toString().trim() ?? ''
        : '';
    final name = value('trading_name').isNotEmpty
        ? value('trading_name')
        : value('legal_name').isNotEmpty
        ? value('legal_name')
        : _supplierName();
    final address = [
      value('address_line_1'),
      value('address_line_2'),
      [
        value('suburb'),
        value('state'),
        value('postcode'),
      ].where((v) => v.isNotEmpty).join(' '),
    ].where((v) => v.isNotEmpty).join('\n');
    Widget contact(IconData icon, String text, String fallback) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF741C1C)),
          const SizedBox(width: 9),
          Expanded(
            child: SelectableText(
              text.isEmpty ? fallback : text,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
    const fallbackLogo = Icon(
      Icons.storefront_outlined,
      size: 34,
      color: Color(0xFF741C1C),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DEDB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 64,
                child: logoPath.isEmpty
                    ? fallbackLogo
                    : Image.network(
                        Supabase.instance.client.storage
                            .from('business-branding')
                            .getPublicUrl(logoPath),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        semanticLabel: '$name logo',
                        errorBuilder: (_, error, stackTrace) => fallbackLogo,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SUPPLIER',
                      style: TextStyle(fontSize: 10, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_loadingSupplierProfile)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_supplierProfileFailed)
            TextButton.icon(
              onPressed: _loadSupplierProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry supplier contact details'),
            )
          else ...[
            contact(
              Icons.location_on_outlined,
              address,
              'Address not provided',
            ),
            contact(
              Icons.email_outlined,
              value('business_email'),
              'Email not provided',
            ),
            contact(
              Icons.phone_outlined,
              value('business_phone'),
              'Phone not provided',
            ),
          ],
        ],
      ),
    );
  }

  bool _isCheckingRelationship = true;
  bool _isSubmittingRequest = false;
  bool _isAddingToOrder = false;

  double _orderQuantityPreview = 1;

  String? _relationshipStatus;
  String? _butcherBusinessId;

  @override
  void initState() {
    super.initState();
    _loadRelationshipStatus();
    _loadSupplierProfile();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
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

  String _speciesName() {
    final value = _newAnimalName();
    return value.isEmpty ? 'Not linked' : value;
  }

  String _currentCatalogueProductName() {
    final value = _newSpecificationName();
    return value.trim().isEmpty ? 'Not linked' : value;
  }

  String _variantName() {
    final code = _newGradeCode();
    final name = _newGradeName();

    if (code == 'N/A' && name.isEmpty) {
      return 'Not linked';
    }

    if (name.isEmpty || name == code) {
      return code;
    }

    return '$code - $name';
  }

  String _fullCataloguePath() {
    final parts = <String>[
      _newAnimalName(),
      _newSectionName(),
      _newSpecificationName(),
    ];

    final grade = _variantName();
    if (grade != 'Not linked') {
      parts.add(grade);
    }

    final visible = parts.where((value) => value.trim().isNotEmpty).toList();
    return visible.isEmpty ? 'Catalogue not linked' : visible.join(' → ');
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
    final label = productSizeLabel(widget.product);
    return label.isEmpty ? 'Not provided' : label;
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

  Widget _compactField(
    String label,
    String value, {
    double width = 180,
    bool prominent = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .45,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: prominent ? 4 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF202020),
                fontSize: prominent ? 18 : 13,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E3E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF741C1C), size: 18),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _productImagePlaceholder() {
    return CatalogueProductImage(product: widget.product);
  }

  Widget _compactOrderCard(Map<String, dynamic> product) {
    final price = _findVisiblePrice();
    final amount = price?['amount'];
    final unitPrice = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '');
    final quantityUnit = _orderQuantityUnit(price);
    final unitLabel = _orderQuantityUnitLabel(quantityUnit);
    final minimum = price?['minimum_quantity'];
    final catchWeightKgPricing = _isCatchWeightKgPricing(price);
    final requiresWholeNumber =
        quantityUnit == 'carton' || quantityUnit == 'unit';
    final estimatedTotal = !catchWeightKgPricing && unitPrice != null
        ? unitPrice * _orderQuantityPreview
        : null;
    final unavailable = product['availability_status'] == 'out_of_stock';

    return _compactCard(
      title: 'Order Product',
      icon: Icons.add_shopping_cart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCustomerPriceDisplay(
            visiblePrice: price,
            alignment: CrossAxisAlignment.start,
            priceFontSize: 25,
          ),
          if (minimum != null) ...[
            const SizedBox(height: 4),
            Text(
              'Minimum ${_formatNumber(minimum)} $unitLabel',
              style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          if (unitPrice == null)
            const Text(
              'A visible price is required before ordering.',
              style: TextStyle(color: Color(0xFF666666)),
            )
          else if (unavailable)
            const Text(
              'This product is currently out of stock.',
              style: TextStyle(color: Color(0xFFB3261E)),
            )
          else ...[
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.numberWithOptions(
                decimal: !requiresWholeNumber,
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
                isDense: true,
                labelText: 'Quantity',
                suffixText: unitLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      catchWeightKgPricing
                          ? 'Final total after weighing'
                          : 'Order total',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    catchWeightKgPricing
                        ? 'Pending weight'
                        : _formatMoney(estimatedTotal ?? 0),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF741C1C),
                    ),
                  ),
                ],
              ),
            ),
            if (catchWeightKgPricing) ...[
              const SizedBox(height: 7),
              const Text(
                'The supplier confirms actual kilograms during preparation.',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isAddingToOrder ? null : _addToOrder,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
                padding: const EdgeInsets.symmetric(vertical: 15),
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
              label: Text(_isAddingToOrder ? 'Adding' : 'Add to Order'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactProductDetails(BuildContext context) {
    final product = widget.product;
    final visiblePrice = _findVisiblePrice();
    final supplierSpecification =
        product['supplier_specification']?.toString().trim() ?? '';

    final detailFields = <MapEntry<String, String>>[
      MapEntry('SKU', product['sku']?.toString() ?? 'Not provided'),
      MapEntry('Brand', _textValue('brand')),
      MapEntry('Available', _availableQuantityText()),
      MapEntry('Animal', _speciesName()),
      MapEntry('Section', _newSectionName()),
      MapEntry('Specification', _currentCatalogueProductName()),
      MapEntry('Grade', _variantName()),
      MapEntry(
        'Temperature',
        _formatTemperature(product['temperature_state'] as String?),
      ),
      MapEntry(
        'Availability',
        _formatAvailability(product['availability_status'] as String?),
      ),
    ];

    final meatFields = <MapEntry<String, String>>[
      MapEntry('Grade / category', _variantName()),
      MapEntry(
        'Temperature',
        _formatTemperature(product['temperature_state'] as String?),
      ),
      MapEntry('Bone', _textValue('bone_state')),
      MapEntry('Marbling', _textValue('marbling_score')),
      MapEntry('Breed / program', _textValue('breed_program')),
      MapEntry('Trim', _textValue('trim_specification')),
      MapEntry('Fat', _textValue('fat_specification')),
      MapEntry('Piece weight', _pieceWeightText()),
      MapEntry('Carton', _cartonText()),
      MapEntry('Packaging', _textValue('packaging_type')),
      MapEntry(
        'Origin',
        [_textValue('origin_country'), _textValue('origin_state')]
            .where(
              (value) => value != 'Not specified' && value != 'Not provided',
            )
            .join(' • '),
      ),
    ];

    Widget fields(
      List<MapEntry<String, String>> values, {
      bool prominent = false,
    }) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720
              ? 4
              : constraints.maxWidth >= 470
              ? 2
              : 1;
          final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 1,
            children: [
              for (final item in values)
                if (item.value.trim().isNotEmpty &&
                    item.value != 'Not specified' &&
                    item.value != 'Not provided')
                  _compactField(
                    item.key,
                    item.value,
                    width: width,
                    prominent: prominent,
                  ),
            ],
          );
        },
      );
    }

    final identity = _compactCard(
      title: 'Product',
      icon: Icons.inventory_2_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 700;
          final image = SizedBox(
            width: stack ? double.infinity : 265,
            child: _productImagePlaceholder(),
          );
          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _gradeIdentityBadge(),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _newSpecificationName(),
                          style: const TextStyle(
                            fontSize: 25,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _supplierName(),
                          style: const TextStyle(
                            color: Color(0xFF741C1C),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _fullCataloguePath(),
                style: const TextStyle(
                  color: Color(0xFF5E6469),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _buildCustomerPriceDisplay(
                visiblePrice: visiblePrice,
                alignment: CrossAxisAlignment.start,
                priceFontSize: 23,
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
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
                      avatar: const Icon(Icons.verified_outlined, size: 16),
                      label: Text(_halalLabel()),
                    ),
                  if (product['catch_weight'] == true)
                    const Chip(label: Text('Catch weight')),
                ],
              ),
            ],
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                image,
                const SizedBox(height: 14),
                information,
                const SizedBox(height: 14),
                _supplierContactPanel(),
              ],
            );
          }
          final wide = constraints.maxWidth >= 1100;
          final productRow = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const SizedBox(width: 18),
              Expanded(child: information),
              if (wide) ...[
                const SizedBox(width: 18),
                SizedBox(width: 340, child: _supplierContactPanel()),
              ],
            ],
          );
          return wide
              ? productRow
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    productRow,
                    const SizedBox(height: 14),
                    _supplierContactPanel(),
                  ],
                );
        },
      ),
    );

    final details = Column(
      children: [
        _compactCard(
          title: 'Product Details',
          icon: Icons.fact_check_outlined,
          child: fields(detailFields),
        ),
        const SizedBox(height: 10),
        _compactCard(
          title: 'Specifications',
          icon: Icons.tune_outlined,
          child: fields(meatFields, prominent: true),
        ),
        const SizedBox(height: 10),
        _compactCard(
          title: 'Halal',
          icon: Icons.verified_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _halalLabel(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: product['halal_status'] == 'halal'
                      ? const Color(0xFF246342)
                      : const Color(0xFF555B61),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                product['halal_status'] == 'halal'
                    ? 'Declared Halal by the supplier. Contact the supplier for certification details.'
                    : product['halal_status'] == 'not_halal'
                    ? 'The supplier has marked this product as not Halal.'
                    : 'The supplier has not specified Halal status for this product.',
                style: const TextStyle(color: Color(0xFF5E6469), height: 1.35),
              ),
            ],
          ),
        ),
        if (supplierSpecification.isNotEmpty) ...[
          const SizedBox(height: 10),
          _compactCard(
            title: 'Supplier Specification',
            icon: Icons.description_outlined,
            child: Text(
              supplierSpecification,
              style: const TextStyle(color: Color(0xFF4E5357), height: 1.4),
            ),
          ),
        ],
      ],
    );

    final side = Column(
      children: [
        _compactOrderCard(product),
        const SizedBox(height: 10),
        _compactCard(
          title: 'Supplier Access',
          icon: Icons.verified_user_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Approved customers can access customer pricing and order from this supplier.',
                style: TextStyle(
                  color: Color(0xFF5E6469),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              _buildRelationshipButton(),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Product Details',
          style: TextStyle(fontWeight: FontWeight.w800),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          return SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 16 : 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  children: [
                    identity,
                    const SizedBox(height: 10),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 10),
                          SizedBox(width: 350, child: side),
                        ],
                      )
                    else ...[
                      side,
                      const SizedBox(height: 10),
                      details,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCompactProductDetails(context);
  }
}
