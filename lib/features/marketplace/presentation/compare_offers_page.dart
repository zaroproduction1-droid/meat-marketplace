import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompareOffersPage extends StatefulWidget {
  const CompareOffersPage({super.key, required this.selectedProduct});

  final Map<String, dynamic> selectedProduct;

  @override
  State<CompareOffersPage> createState() => _CompareOffersPageState();
}

class _CompareOffersPageState extends State<CompareOffersPage> {
  static const Color _darkRed = Color(0xFF741C1C);

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedOfferIds = <String>{};

  bool _isLoading = true;
  bool _isAddingToOrder = false;
  String? _errorMessage;

  String _sortBy = 'lowest_price';
  bool _inStockOnly = false;
  String _temperatureFilter = 'all';
  String _halalFilter = 'all';

  String? _butcherBusinessId;
  String? _butcherPostcode;

  List<Map<String, dynamic>> _offers = [];
  final Map<String, Map<String, dynamic>> _relationshipsBySupplierId = {};
  final Map<String, Map<String, dynamic>> _deliverySettingsBySupplierId = {};
  final Map<String, List<int>> _deliveryDaysBySupplierId = {};
  final Map<String, List<Map<String, dynamic>>> _deliveryZonesBySupplierId = {};

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _selectedVariantId() {
    return widget.selectedProduct['product_variant_id']?.toString() ?? '';
  }

  Future<void> _loadOffers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final memberships = await client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1);

      if (memberships.isEmpty) {
        throw Exception('Your butcher business could not be identified.');
      }

      final butcherBusinessId = memberships.first['business_id']?.toString();

      if (butcherBusinessId == null || butcherBusinessId.isEmpty) {
        throw Exception('Your butcher business could not be identified.');
      }

      final businessRows = await client
          .from('businesses')
          .select('postcode')
          .eq('id', butcherBusinessId)
          .limit(1);

      String? butcherPostcode;

      if (businessRows.isNotEmpty) {
        final raw = businessRows.first['postcode']?.toString().trim();
        if (raw != null && raw.isNotEmpty) {
          butcherPostcode = raw;
        }
      }

      var query = client
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
        order_unit,
        weight_type,
        price_basis,
        availability_status,
        supplier_business_id,
        product_variant_id,
        animal_type_id,
        cut_id,
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
          minimum_quantity_unit,
          active,
          price_lists(
            id,
            name,
            visibility,
            active
          )
        )
      ''')
          .eq('active', true);

      final variantId = _selectedVariantId();

      dynamic response;

      if (variantId.isNotEmpty) {
        response = await query.eq('product_variant_id', variantId);
      } else {
        final cutId = widget.selectedProduct['cut_id']?.toString();
        final productName = widget.selectedProduct['product_name']?.toString();

        if (cutId == null ||
            cutId.isEmpty ||
            productName == null ||
            productName.trim().isEmpty) {
          response = <Map<String, dynamic>>[widget.selectedProduct];
        } else {
          response = await query
              .eq('cut_id', cutId)
              .eq('product_name', productName);
        }
      }

      final offers = List<Map<String, dynamic>>.from(response);

      final supplierIds = offers
          .map((offer) => offer['supplier_business_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final relationshipsBySupplierId = <String, Map<String, dynamic>>{};
      final deliverySettingsBySupplierId = <String, Map<String, dynamic>>{};
      final deliveryDaysBySupplierId = <String, List<int>>{};
      final deliveryZonesBySupplierId = <String, List<Map<String, dynamic>>>{};

      if (supplierIds.isNotEmpty) {
        final relationships = await client
            .from('supplier_customer_relationships')
            .select('''
              supplier_business_id,
              butcher_business_id,
              status,
              payment_method,
              payment_terms_days,
              credit_limit
            ''')
            .eq('butcher_business_id', butcherBusinessId)
            .inFilter('supplier_business_id', supplierIds.toList());

        for (final raw in relationships) {
          final relationship = Map<String, dynamic>.from(raw);
          final supplierId = relationship['supplier_business_id']?.toString();

          if (supplierId != null && supplierId.isNotEmpty) {
            relationshipsBySupplierId[supplierId] = relationship;
          }
        }

        final settings = await client
            .from('supplier_delivery_settings')
            .select('''
              supplier_business_id,
              minimum_order_amount,
              default_lead_time_days,
              order_cutoff_time,
              pickup_available,
              delivery_notes,
              active
            ''')
            .inFilter('supplier_business_id', supplierIds.toList());

        for (final raw in settings) {
          final setting = Map<String, dynamic>.from(raw);
          final supplierId = setting['supplier_business_id']?.toString();

          if (supplierId != null && supplierId.isNotEmpty) {
            deliverySettingsBySupplierId[supplierId] = setting;
          }
        }

        final days = await client
            .from('supplier_delivery_days')
            .select('supplier_business_id, weekday, active')
            .inFilter('supplier_business_id', supplierIds.toList())
            .eq('active', true);

        for (final raw in days) {
          final supplierId = raw['supplier_business_id']?.toString();
          final weekdayRaw = raw['weekday'];

          if (supplierId == null || supplierId.isEmpty) {
            continue;
          }

          final weekday = weekdayRaw is int
              ? weekdayRaw
              : int.tryParse('$weekdayRaw');

          if (weekday == null || weekday < 1 || weekday > 7) {
            continue;
          }

          deliveryDaysBySupplierId
              .putIfAbsent(supplierId, () => <int>[])
              .add(weekday);
        }

        if (butcherPostcode != null) {
          final zones = await client
              .from('supplier_delivery_zones')
              .select('''
                id,
                supplier_business_id,
                zone_name,
                minimum_order_amount,
                delivery_fee,
                lead_time_days,
                active,
                notes,
                supplier_delivery_zone_postcodes!inner(
                  postcode
                )
              ''')
              .inFilter('supplier_business_id', supplierIds.toList())
              .eq('active', true)
              .eq('supplier_delivery_zone_postcodes.postcode', butcherPostcode);

          for (final raw in zones) {
            final zone = Map<String, dynamic>.from(raw);
            final supplierId = zone['supplier_business_id']?.toString();

            if (supplierId == null || supplierId.isEmpty) {
              continue;
            }

            deliveryZonesBySupplierId
                .putIfAbsent(supplierId, () => <Map<String, dynamic>>[])
                .add(zone);
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _butcherBusinessId = butcherBusinessId;
        _butcherPostcode = butcherPostcode;
        _offers = offers;

        _relationshipsBySupplierId
          ..clear()
          ..addAll(relationshipsBySupplierId);

        _deliverySettingsBySupplierId
          ..clear()
          ..addAll(deliverySettingsBySupplierId);

        _deliveryDaysBySupplierId
          ..clear()
          ..addAll(deliveryDaysBySupplierId);

        _deliveryZonesBySupplierId
          ..clear()
          ..addAll(deliveryZonesBySupplierId);

        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _visiblePrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

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

      final visibility = priceList['visibility']?.toString();

      final priority = switch (visibility) {
        'private' => 3,
        'approved_customers' => 2,
        'public' => 1,
        _ => 0,
      };

      if (priority > bestPriority) {
        bestPriority = priority;
        bestPrice = price;
      }
    }

    return bestPrice;
  }

  Map<String, dynamic>? _standardPrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];

    if (rawPrices is! List) return null;

    for (final rawPrice in rawPrices) {
      if (rawPrice is! Map) continue;

      final price = Map<String, dynamic>.from(rawPrice);
      if (price['active'] != true) continue;

      final rawPriceList = price['price_lists'];
      if (rawPriceList is! Map) continue;

      final priceList = Map<String, dynamic>.from(rawPriceList);

      if (priceList['active'] == true &&
          priceList['visibility']?.toString() == 'public') {
        return price;
      }
    }

    return null;
  }

  String _priceLabel(Map<String, dynamic>? price) {
    final rawPriceList = price?['price_lists'];

    if (rawPriceList is! Map) {
      return 'Standard Price';
    }

    return switch (rawPriceList['visibility']?.toString()) {
      'private' => 'Your Special Price',
      'approved_customers' => 'Your Trade Price',
      _ => 'Standard Price',
    };
  }

  double? _priceAmount(Map<String, dynamic> product) {
    final raw = _visiblePrice(product)?['amount'];

    if (raw is num) {
      return raw.toDouble();
    }

    return double.tryParse('${raw ?? ''}');
  }

  String _supplierName(Map<String, dynamic> product) {
    final raw = product['businesses'];

    if (raw is! Map) return 'Unknown supplier';

    final tradingName = raw['trading_name']?.toString().trim();
    if (tradingName != null && tradingName.isNotEmpty) {
      return tradingName;
    }

    return raw['legal_name']?.toString() ?? 'Unknown supplier';
  }

  String _supplierId(Map<String, dynamic> product) {
    return product['supplier_business_id']?.toString() ?? '';
  }

  Map<String, dynamic>? _deliverySetting(Map<String, dynamic> product) {
    return _deliverySettingsBySupplierId[_supplierId(product)];
  }

  List<Map<String, dynamic>> _matchingZones(Map<String, dynamic> product) {
    return _deliveryZonesBySupplierId[_supplierId(product)] ??
        <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _singleDeliveryZone(Map<String, dynamic> product) {
    final zones = _matchingZones(product);
    return zones.length == 1 ? zones.first : null;
  }

  List<int> _deliveryDays(Map<String, dynamic> product) {
    final values = _deliveryDaysBySupplierId[_supplierId(product)] ?? <int>[];

    final result = List<int>.from(values)..sort();
    return result;
  }

  int? _leadDays(Map<String, dynamic> product) {
    final zone = _singleDeliveryZone(product);
    final setting = _deliverySetting(product);

    final raw = zone?['lead_time_days'] ?? setting?['default_lead_time_days'];

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();

    return int.tryParse('${raw ?? ''}');
  }

  DateTime? _nextDeliveryDate(Map<String, dynamic> product) {
    final setting = _deliverySetting(product);
    final zones = _matchingZones(product);
    final weekdays = _deliveryDays(product);

    if (setting == null ||
        setting['active'] != true ||
        zones.length != 1 ||
        weekdays.isEmpty) {
      return null;
    }

    final leadDays = _leadDays(product);
    if (leadDays == null) return null;

    final now = DateTime.now();

    var earliest = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: leadDays));

    final cutoff = setting['order_cutoff_time']?.toString();

    if (cutoff != null && cutoff.trim().isNotEmpty) {
      final parts = cutoff.split(':');

      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);

        if (hour != null && minute != null) {
          final cutoffToday = DateTime(
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );

          if (now.isAfter(cutoffToday)) {
            earliest = earliest.add(const Duration(days: 1));
          }
        }
      }
    }

    for (var offset = 0; offset <= 35; offset++) {
      final candidate = earliest.add(Duration(days: offset));

      if (weekdays.contains(candidate.weekday)) {
        return candidate;
      }
    }

    return null;
  }

  dynamic _deliveryMinimum(Map<String, dynamic> product) {
    final zone = _singleDeliveryZone(product);
    final setting = _deliverySetting(product);

    return zone?['minimum_order_amount'] ?? setting?['minimum_order_amount'];
  }

  String _deliveryFeeText(Map<String, dynamic> product) {
    final zones = _matchingZones(product);

    if (_butcherPostcode == null || _butcherPostcode!.isEmpty) {
      return 'Delivery: postcode required';
    }

    if (zones.isEmpty) {
      return 'Delivery: not configured';
    }

    if (zones.length > 1) {
      return 'Delivery: configuration error';
    }

    final raw = zones.first['delivery_fee'];

    if (raw == null) {
      return 'Delivery: not configured';
    }

    final fee = raw is num ? raw.toDouble() : double.tryParse('$raw');

    if (fee == null) {
      return 'Delivery: not configured';
    }

    return fee == 0
        ? 'Delivery: Free'
        : 'Delivery: ${_formatMoney(fee)} inc GST';
  }

  String _nextDeliveryText(Map<String, dynamic> product) {
    final setting = _deliverySetting(product);
    final zones = _matchingZones(product);

    if (setting == null || setting['active'] != true) {
      return 'Not configured';
    }

    if (_butcherPostcode == null || _butcherPostcode!.isEmpty) {
      return 'Postcode required';
    }

    if (zones.isEmpty) {
      return 'Not configured for postcode';
    }

    if (zones.length > 1) {
      return 'Configuration error';
    }

    final value = _nextDeliveryDate(product);

    if (value == null) {
      return 'Not configured';
    }

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[value.weekday - 1]} '
        '${value.day} ${months[value.month - 1]}';
  }

  String _relationshipStatus(Map<String, dynamic> product) {
    final relationship = _relationshipsBySupplierId[_supplierId(product)];

    return switch (relationship?['status']?.toString()) {
      'approved' => 'Approved customer',
      'requested' => 'Access requested',
      'declined' => 'Not approved',
      _ => 'Standard customer',
    };
  }

  String _paymentTerms(Map<String, dynamic> product) {
    final relationship = _relationshipsBySupplierId[_supplierId(product)];

    if (relationship?['status']?.toString() != 'approved') {
      return 'Standard supplier terms';
    }

    final method = relationship?['payment_method']?.toString();

    switch (method) {
      case 'cod':
        return 'COD';
      case 'prepaid':
        return 'Prepaid';
      case 'account':
        final daysRaw = relationship?['payment_terms_days'];
        final days = daysRaw is num
            ? daysRaw.toInt()
            : int.tryParse('${daysRaw ?? ''}');

        return days == null
            ? 'Account'
            : 'Account • $days day${days == 1 ? '' : 's'}';
      default:
        return 'Supplier terms';
    }
  }

  double _qualityScore(Map<String, dynamic> offer) {
    var score = 0.0;

    final marblingText =
        offer['marbling_score']?.toString().trim().toLowerCase() ?? '';

    final marblingMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(marblingText);

    if (marblingMatch != null) {
      final marbling = double.tryParse(marblingMatch.group(1) ?? '');

      if (marbling != null) {
        // Marbling is the strongest numeric quality signal currently
        // available in the product schema.
        score += marbling * 100;
      }
    }

    if (offer['grade']?.toString().trim().isNotEmpty == true) {
      score += 10;
    }

    if (offer['breed_program']?.toString().trim().isNotEmpty == true) {
      score += 5;
    }

    if (offer['origin_country']?.toString().trim().isNotEmpty == true ||
        offer['origin_state']?.toString().trim().isNotEmpty == true) {
      score += 2;
    }

    return score;
  }

  Widget _sortMenuItem({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredAndSortedOffers() {
    final search = _searchController.text.trim().toLowerCase();

    final result = _offers.where((offer) {
      if (_inStockOnly &&
          offer['availability_status']?.toString() != 'in_stock') {
        return false;
      }

      if (_temperatureFilter != 'all' &&
          offer['temperature_state']?.toString() != _temperatureFilter) {
        return false;
      }

      if (_halalFilter == 'halal' &&
          offer['halal_status']?.toString() != 'halal') {
        return false;
      }

      if (search.isNotEmpty) {
        final searchable = <dynamic>[
          _supplierName(offer),
          offer['brand'],
          offer['grade'],
          offer['marbling_score'],
          offer['breed_program'],
          offer['origin_country'],
          offer['origin_state'],
          offer['trim_specification'],
          offer['fat_specification'],
          offer['packaging_type'],
          offer['supplier_specification'],
          offer['temperature_state'],
          offer['halal_status'],
        ];

        final matches = searchable.any(
          (value) =>
              value != null && value.toString().toLowerCase().contains(search),
        );

        if (!matches) {
          return false;
        }
      }

      return true;
    }).toList();

    int availabilityRank(Map<String, dynamic> offer) {
      return switch (offer['availability_status']?.toString()) {
        'in_stock' => 0,
        'limited' => 1,
        'made_to_order' => 2,
        'out_of_stock' => 3,
        _ => 4,
      };
    }

    result.sort((a, b) {
      switch (_sortBy) {
        case 'most_expensive':
          final ap = _priceAmount(a);
          final bp = _priceAmount(b);

          if (ap == null && bp == null) return 0;
          if (ap == null) return 1;
          if (bp == null) return -1;
          return bp.compareTo(ap);

        case 'best_quality':
          final qualityCompare = _qualityScore(b).compareTo(_qualityScore(a));

          if (qualityCompare != 0) {
            return qualityCompare;
          }

          final ap = _priceAmount(a);
          final bp = _priceAmount(b);

          if (ap == null && bp == null) return 0;
          if (ap == null) return 1;
          if (bp == null) return -1;

          return bp.compareTo(ap);

        case 'earliest_delivery':
          final ad = _nextDeliveryDate(a);
          final bd = _nextDeliveryDate(b);

          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);

        case 'supplier':
          return _supplierName(
            a,
          ).toLowerCase().compareTo(_supplierName(b).toLowerCase());

        case 'stock':
          return availabilityRank(a).compareTo(availabilityRank(b));

        case 'lowest_price':
        default:
          final ap = _priceAmount(a);
          final bp = _priceAmount(b);

          if (ap == null && bp == null) return 0;
          if (ap == null) return 1;
          if (bp == null) return -1;
          return ap.compareTo(bp);
      }
    });

    return result;
  }

  bool _isCatchWeightProduct(Map<String, dynamic> product) {
    return product['weight_type']?.toString() == 'catch_weight' ||
        product['catch_weight'] == true;
  }

  String _orderQuantityUnit(
    Map<String, dynamic> product,
    Map<String, dynamic>? visiblePrice,
  ) {
    // Locked CutLink rule:
    // catch-weight meat is priced per kg but ALWAYS ordered by carton.
    if (_isCatchWeightProduct(product)) {
      return 'carton';
    }

    final configuredOrderUnit = product['order_unit']?.toString();

    if (configuredOrderUnit == 'kilogram' ||
        configuredOrderUnit == 'carton' ||
        configuredOrderUnit == 'unit') {
      return configuredOrderUnit!;
    }

    final legacyUnit = product['quantity_unit']?.toString();

    if (legacyUnit == 'kilogram' ||
        legacyUnit == 'carton' ||
        legacyUnit == 'unit') {
      return legacyUnit!;
    }

    final basis = visiblePrice?['price_basis']?.toString();

    if (basis == 'kilogram' || basis == 'carton' || basis == 'unit') {
      return basis!;
    }

    return 'unit';
  }

  String _minimumQuantityUnit(
    Map<String, dynamic> product,
    Map<String, dynamic>? visiblePrice,
  ) {
    if (_isCatchWeightProduct(product)) {
      return 'carton';
    }

    final configured = visiblePrice?['minimum_quantity_unit']?.toString();

    if (configured == 'kilogram' ||
        configured == 'carton' ||
        configured == 'unit') {
      return configured!;
    }

    return _orderQuantityUnit(product, visiblePrice);
  }

  String _orderQuantityUnitLabel(String value) {
    return switch (value) {
      'kilogram' => 'kg',
      'carton' => 'cartons',
      'unit' => 'units',
      _ => value,
    };
  }

  String _minimumQuantityText(
    Map<String, dynamic> product,
    Map<String, dynamic>? visiblePrice,
  ) {
    final minimum = visiblePrice?['minimum_quantity'];

    if (minimum == null) {
      return '';
    }

    final unit = _minimumQuantityUnit(product, visiblePrice);

    return '${_formatNumber(minimum)} ${_orderQuantityUnitLabel(unit)}';
  }

  Future<void> _showAddToOrderDialog(Map<String, dynamic> product) async {
    if (_isAddingToOrder) return;

    final visiblePrice = _visiblePrice(product);

    if (visiblePrice == null || visiblePrice['amount'] == null) {
      _showMessage('This offer does not currently have a visible price.');
      return;
    }

    if (product['availability_status']?.toString() == 'out_of_stock') {
      _showMessage('This offer is currently out of stock.');
      return;
    }

    final minimumRaw = visiblePrice['minimum_quantity'];
    final minimum = minimumRaw is num
        ? minimumRaw.toDouble()
        : double.tryParse('${minimumRaw ?? ''}');

    final quantityUnit = _orderQuantityUnit(product, visiblePrice);
    final quantityUnitLabel = _orderQuantityUnitLabel(quantityUnit);
    final minimumUnit = _minimumQuantityUnit(product, visiblePrice);
    final minimumText = _minimumQuantityText(product, visiblePrice);

    final isCatchWeightKgPricing =
        _isCatchWeightProduct(product) &&
        visiblePrice['price_basis']?.toString() == 'kilogram';

    final quantityController = TextEditingController(
      text: minimum != null && minimum > 1 && minimumUnit == quantityUnit
          ? _formatNumber(minimum)
          : '1',
    );

    final basis = isCatchWeightKgPricing
        ? 'kilogram'
        : visiblePrice['price_basis']?.toString();

    final unitPriceRaw = visiblePrice['amount'];
    final unitPrice = unitPriceRaw is num
        ? unitPriceRaw.toDouble()
        : double.tryParse('$unitPriceRaw');

    if (unitPrice == null) {
      quantityController.dispose();
      _showMessage('The visible price could not be read.');
      return;
    }

    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final entered = double.tryParse(quantityController.text.trim());

            final requiresWholeNumber =
                quantityUnit == 'carton' || quantityUnit == 'unit';

            final validWholeNumber =
                !requiresWholeNumber ||
                entered == null ||
                entered == entered.roundToDouble();

            final knownOrderTotal =
                !isCatchWeightKgPricing && entered != null && entered > 0
                ? entered * unitPrice
                : null;

            return AlertDialog(
              title: Text('Add ${product['product_name'] ?? 'offer'}'),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _supplierName(product),
                      style: const TextStyle(
                        color: _darkRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${_formatMoney(unitPrice)} / '
                      '${_priceBasisLabel(basis)} inc GST',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (minimum != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Minimum order: $minimumText',
                        style: const TextStyle(color: Color(0xFF666666)),
                      ),
                    ],
                    if (isCatchWeightKgPricing) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE1E1DE)),
                        ),
                        child: const Text(
                          'Order cartons now. Final kilograms and the final product total are confirmed by the supplier when the order is prepared.',
                          style: TextStyle(
                            color: Color(0xFF555555),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TextField(
                      controller: quantityController,
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: !requiresWholeNumber,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity ($quantityUnitLabel)',
                        helperText: requiresWholeNumber
                            ? 'Enter a whole number of $quantityUnitLabel.'
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (!validWholeNumber) ...[
                      const SizedBox(height: 7),
                      const Text(
                        'Cartons and units must be entered as whole numbers.',
                        style: TextStyle(
                          color: _darkRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (isCatchWeightKgPricing) ...[
                      const Text(
                        'Final total',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pending final weight',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _darkRed,
                        ),
                      ),
                      if (entered != null && entered > 0) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${_formatNumber(entered)} $quantityUnitLabel ordered '
                          'at ${_formatMoney(unitPrice)} / kg',
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                    ] else
                      Text(
                        'Order total: '
                        '${_formatMoney(knownOrderTotal ?? 0)} inc GST',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _darkRed,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed:
                      entered == null || entered <= 0 || !validWholeNumber
                      ? null
                      : () => Navigator.of(dialogContext).pop(entered),
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to Order'),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();

    if (quantity == null) {
      return;
    }

    final requiresWholeNumber =
        quantityUnit == 'carton' || quantityUnit == 'unit';

    if (requiresWholeNumber && quantity != quantity.roundToDouble()) {
      _showMessage('Cartons and units must be entered as whole numbers.');
      return;
    }

    if (minimum != null && minimumUnit == quantityUnit && quantity < minimum) {
      _showMessage('Minimum order is $minimumText.');
      return;
    }

    await _addToOrder(
      product: product,
      visiblePrice: visiblePrice,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  Future<void> _addToOrder({
    required Map<String, dynamic> product,
    required Map<String, dynamic> visiblePrice,
    required double quantity,
    required double unitPrice,
  }) async {
    final butcherBusinessId = _butcherBusinessId;

    if (butcherBusinessId == null || butcherBusinessId.isEmpty) {
      _showMessage('Your butcher business could not be identified.');
      return;
    }

    final supplierBusinessId = product['supplier_business_id']?.toString();
    final productId = product['id']?.toString();

    if (supplierBusinessId == null ||
        supplierBusinessId.isEmpty ||
        productId == null ||
        productId.isEmpty) {
      _showMessage('This offer is missing required order information.');
      return;
    }

    final catchWeightSnapshot = _isCatchWeightProduct(product);

    final priceBasis = catchWeightSnapshot
        ? 'kilogram'
        : visiblePrice['price_basis']?.toString();

    final quantityUnit = _orderQuantityUnit(product, visiblePrice);

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
          .select(
            'id, quantity, quantity_unit, price_basis, catch_weight_snapshot',
          )
          .eq('order_id', orderId)
          .eq('product_id', productId)
          .limit(1);

      final productName =
          product['product_name']?.toString() ?? 'Unnamed product';
      final sku = product['sku']?.toString();

      if (existingItems.isNotEmpty) {
        final existingItem = Map<String, dynamic>.from(existingItems.first);

        final existingRaw = existingItem['quantity'];
        final existingQuantity = existingRaw is num
            ? existingRaw.toDouble()
            : double.tryParse('${existingRaw ?? ''}') ?? 0;

        final existingQuantityUnit = existingItem['quantity_unit']?.toString();

        // Do not mathematically combine a legacy kg draft quantity
        // with the new carton ordering model.
        final updatedQuantity = existingQuantityUnit == quantityUnit
            ? existingQuantity + quantity
            : quantity;

        await client
            .from('order_items')
            .update({
              'product_name_snapshot': productName,
              'sku_snapshot': sku,
              'quantity': updatedQuantity,
              'quantity_unit': quantityUnit,
              'unit_price': unitPrice,
              'price_basis': priceBasis,
              'catch_weight_snapshot': catchWeightSnapshot,
            })
            .eq('id', existingItem['id']);
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

      if (!mounted) return;

      _showMessage(
        orderNumber == null || orderNumber.trim().isEmpty
            ? 'Offer added to your draft order.'
            : 'Offer added to $orderNumber.',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to add offer to order: $error');
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

    if (number == null) return '\$0.00';

    return '\$${_withThousandsSeparators(number.toStringAsFixed(2))}';
  }

  String _priceBasisLabel(String? value) {
    return switch (value) {
      'kilogram' => 'kg',
      'carton' => 'carton',
      'unit' => 'unit',
      _ => 'unit',
    };
  }

  String _availabilityLabel(String? value) {
    return switch (value) {
      'in_stock' => 'In stock',
      'limited' => 'Limited',
      'out_of_stock' => 'Out of stock',
      'made_to_order' => 'Made to order',
      _ => 'Unknown',
    };
  }

  String _temperatureLabel(String? value) {
    return switch (value) {
      'fresh' => 'Fresh',
      'chilled' => 'Chilled',
      'frozen' => 'Frozen',
      _ => value ?? 'Not specified',
    };
  }

  String _optionalText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Not specified' : text;
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBlock(Map<String, dynamic> product) {
    final visible = _visiblePrice(product);

    if (visible == null || visible['amount'] == null) {
      return const Text(
        'Price unavailable',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      );
    }

    final standard = _standardPrice(product);
    final visibleAmount = _priceAmount(product);
    final standardRaw = standard?['amount'];
    final standardAmount = standardRaw is num
        ? standardRaw.toDouble()
        : double.tryParse('${standardRaw ?? ''}');

    final visibleBasis = visible['price_basis']?.toString();
    final standardBasis = standard?['price_basis']?.toString();
    final label = _priceLabel(visible);

    final discounted =
        label != 'Standard Price' &&
        visibleAmount != null &&
        standardAmount != null &&
        standardAmount > visibleAmount &&
        visibleBasis == standardBasis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (discounted)
          Text(
            '${_formatMoney(standardAmount)} / '
            '${_priceBasisLabel(standardBasis)} inc GST',
            style: const TextStyle(
              color: Color(0xFF777777),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          '${_formatMoney(visible['amount'])} / '
          '${_priceBasisLabel(visibleBasis)} inc GST',
          style: const TextStyle(
            color: _darkRed,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: label == 'Standard Price'
                ? const Color(0xFF666666)
                : _darkRed,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        if (discounted)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Save ${_formatMoney(standardAmount - visibleAmount)} / '
              '${_priceBasisLabel(visibleBasis)}',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _compactBadge({
    required IconData icon,
    required String text,
    Color? foreground,
    Color? background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? const Color(0xFFF5F5F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground ?? const Color(0xFF555555)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground ?? const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  String _shortMinimumText(Map<String, dynamic> product) {
    final visiblePrice = _visiblePrice(product);
    final minimum = visiblePrice?['minimum_quantity'];

    if (minimum == null) {
      return 'No product minimum';
    }

    return 'Min ${_minimumQuantityText(product, visiblePrice)}';
  }

  String _shortDeliveryMinimumText(Map<String, dynamic> product) {
    final minimum = _deliveryMinimum(product);

    if (minimum == null) {
      return 'Delivery order value: not set';
    }

    return 'Delivery order value: ${_formatMoney(minimum)} inc GST';
  }

  Widget _offerCard(Map<String, dynamic> product) {
    final productId = product['id']?.toString() ?? '';
    final expanded = _expandedOfferIds.contains(productId);
    final visiblePrice = _visiblePrice(product);
    final leadDays = _leadDays(product);

    final availability = _availabilityLabel(
      product['availability_status']?.toString(),
    );
    final temperature = _temperatureLabel(
      product['temperature_state']?.toString(),
    );

    final isHalal = product['halal_status']?.toString() == 'halal';
    final relationship = _relationshipStatus(product);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 720;

                final supplierSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _supplierName(product),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      relationship,
                      style: TextStyle(
                        color: relationship == 'Approved customer'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF666666),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _compactBadge(
                          icon: Icons.inventory_2_outlined,
                          text: availability,
                          foreground:
                              product['availability_status'] == 'in_stock'
                              ? const Color(0xFF2E7D32)
                              : null,
                          background:
                              product['availability_status'] == 'in_stock'
                              ? const Color(0xFFEAF5EC)
                              : null,
                        ),
                        _compactBadge(
                          icon: Icons.ac_unit_outlined,
                          text: temperature,
                        ),
                        if (isHalal)
                          _compactBadge(
                            icon: Icons.verified_outlined,
                            text: 'Halal',
                            foreground: const Color(0xFF2E7D32),
                            background: const Color(0xFFEAF5EC),
                          ),
                        if (_optionalText(product['grade']) != 'Not specified')
                          _compactBadge(
                            icon: Icons.workspace_premium_outlined,
                            text: _optionalText(product['grade']),
                          ),
                        if (_isCatchWeightProduct(product))
                          _compactBadge(
                            icon: Icons.monitor_weight_outlined,
                            text: 'Order cartons • priced / kg',
                            foreground: _darkRed,
                            background: const Color(0xFFF4E5E5),
                          ),
                      ],
                    ),
                  ],
                );

                final priceSection = Column(
                  crossAxisAlignment: narrow
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    _priceBlock(product),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _isAddingToOrder || visiblePrice == null
                          ? null
                          : () => _showAddToOrderDialog(product),
                      style: FilledButton.styleFrom(
                        backgroundColor: _darkRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add to Order'),
                    ),
                  ],
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      supplierSection,
                      const SizedBox(height: 16),
                      priceSection,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: supplierSection),
                    const SizedBox(width: 24),
                    priceSection,
                  ],
                );
              },
            ),
            const SizedBox(height: 15),
            const Divider(height: 1),
            const SizedBox(height: 13),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _compactBadge(
                  icon: Icons.local_shipping_outlined,
                  text: _nextDeliveryText(product),
                ),
                _compactBadge(
                  icon: Icons.payments_outlined,
                  text: _deliveryFeeText(product),
                ),
                _compactBadge(
                  icon: Icons.shopping_basket_outlined,
                  text: _shortMinimumText(product),
                ),
                _compactBadge(
                  icon: Icons.receipt_long_outlined,
                  text: _shortDeliveryMinimumText(product),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (expanded) {
                      _expandedOfferIds.remove(productId);
                    } else {
                      _expandedOfferIds.add(productId);
                    }
                  });
                },
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                label: Text(expanded ? 'Hide details' : 'View details'),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 650;

                    final left = Column(
                      children: [
                        _detail(
                          'Available stock',
                          product['available_quantity'] == null
                              ? 'Not specified'
                              : '${_formatNumber(product['available_quantity'])} '
                                    '${_priceBasisLabel(product['quantity_unit']?.toString())}',
                        ),
                        _detail('Brand', _optionalText(product['brand'])),
                        _detail(
                          'Marbling',
                          _optionalText(product['marbling_score']),
                        ),
                        _detail(
                          'Breed / program',
                          _optionalText(product['breed_program']),
                        ),
                        _detail(
                          'Origin',
                          [
                                    _optionalText(product['origin_state']),
                                    _optionalText(product['origin_country']),
                                  ]
                                  .where((value) => value != 'Not specified')
                                  .join(', ')
                                  .trim()
                                  .isEmpty
                              ? 'Not specified'
                              : [
                                      _optionalText(product['origin_state']),
                                      _optionalText(product['origin_country']),
                                    ]
                                    .where((value) => value != 'Not specified')
                                    .join(', '),
                        ),
                        _detail(
                          'Trim',
                          _optionalText(product['trim_specification']),
                        ),
                      ],
                    );

                    final right = Column(
                      children: [
                        _detail(
                          'Packaging',
                          _optionalText(product['packaging_type']),
                        ),
                        _detail(
                          'Delivery zone',
                          _singleDeliveryZone(
                                product,
                              )?['zone_name']?.toString() ??
                              (_matchingZones(product).length > 1
                                  ? 'Configuration error'
                                  : 'Not configured'),
                        ),
                        _detail(
                          'Lead time',
                          leadDays == null
                              ? 'Not configured'
                              : '$leadDays day'
                                    '${leadDays == 1 ? '' : 's'}',
                        ),
                        _detail(
                          'Pickup',
                          _deliverySetting(product)?['pickup_available'] == true
                              ? 'Available'
                              : 'Not available',
                        ),
                        _detail('Payment terms', _paymentTerms(product)),
                      ],
                    );

                    if (narrow) {
                      return Column(children: [left, right]);
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 26),
                        Expanded(child: right),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _activeFilterCount() {
    var count = 0;

    if (_inStockOnly) count++;
    if (_temperatureFilter != 'all') count++;
    if (_halalFilter != 'all') count++;
    if (_searchController.text.trim().isNotEmpty) count++;

    return count;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _inStockOnly = false;
      _temperatureFilter = 'all';
      _halalFilter = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final offers = _filteredAndSortedOffers();
    final activeFilters = _activeFilterCount();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Choose Supplier',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadOffers,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: _darkRed),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loadOffers,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
                  children: [
                    Text(
                      widget.selectedProduct['product_name']?.toString() ??
                          'Selected product',
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_offers.length} supplier offer'
                      '${_offers.length == 1 ? '' : 's'} available',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            'Search supplier, brand, grade, origin, marbling or specification',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 230,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _sortBy,
                                decoration: const InputDecoration(
                                  labelText: 'Sort',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'lowest_price',
                                    child: _sortMenuItem(
                                      icon: Icons.south_outlined,
                                      label: 'Lowest price',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'most_expensive',
                                    child: _sortMenuItem(
                                      icon: Icons.north_outlined,
                                      label: 'Most expensive',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'best_quality',
                                    child: _sortMenuItem(
                                      icon: Icons.workspace_premium_outlined,
                                      label: 'Best quality',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'earliest_delivery',
                                    child: _sortMenuItem(
                                      icon: Icons.local_shipping_outlined,
                                      label: 'Earliest delivery',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'stock',
                                    child: _sortMenuItem(
                                      icon: Icons.inventory_2_outlined,
                                      label: 'Best availability',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'supplier',
                                    child: _sortMenuItem(
                                      icon: Icons.sort_by_alpha,
                                      label: 'Supplier A–Z',
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _sortBy = value;
                                  });
                                },
                              ),
                            ),
                            FilterChip(
                              selected: _inStockOnly,
                              avatar: const Icon(
                                Icons.inventory_2_outlined,
                                size: 17,
                              ),
                              label: const Text('In stock'),
                              onSelected: (value) {
                                setState(() {
                                  _inStockOnly = value;
                                });
                              },
                            ),
                            FilterChip(
                              selected: _temperatureFilter == 'fresh',
                              avatar: const Icon(Icons.spa_outlined, size: 17),
                              label: const Text('Fresh'),
                              onSelected: (value) {
                                setState(() {
                                  _temperatureFilter = value ? 'fresh' : 'all';
                                });
                              },
                            ),
                            FilterChip(
                              selected: _temperatureFilter == 'chilled',
                              avatar: const Icon(
                                Icons.thermostat_outlined,
                                size: 17,
                              ),
                              label: const Text('Chilled'),
                              onSelected: (value) {
                                setState(() {
                                  _temperatureFilter = value
                                      ? 'chilled'
                                      : 'all';
                                });
                              },
                            ),
                            FilterChip(
                              selected: _temperatureFilter == 'frozen',
                              avatar: const Icon(
                                Icons.ac_unit_outlined,
                                size: 17,
                              ),
                              label: const Text('Frozen'),
                              onSelected: (value) {
                                setState(() {
                                  _temperatureFilter = value ? 'frozen' : 'all';
                                });
                              },
                            ),
                            FilterChip(
                              selected: _halalFilter == 'halal',
                              avatar: const Icon(
                                Icons.verified_outlined,
                                size: 17,
                              ),
                              label: const Text('Halal'),
                              onSelected: (value) {
                                setState(() {
                                  _halalFilter = value ? 'halal' : 'all';
                                });
                              },
                            ),
                            if (activeFilters > 0)
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(
                                  Icons.filter_alt_off_outlined,
                                  size: 18,
                                ),
                                label: Text('Clear ($activeFilters)'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          '${offers.length} result'
                          '${offers.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (offers.isEmpty)
                      const Card(
                        elevation: 0,
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                            child: Text(
                              'No supplier offers match these filters.',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final offer in offers) ...[
                        _offerCard(offer),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
    );
  }
}
