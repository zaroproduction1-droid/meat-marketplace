import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_work_order_page.dart';

class SupplierQuoteEditorPage extends StatefulWidget {
  const SupplierQuoteEditorPage({
    super.key,
    this.initialProductId,
    this.quoteOrderId,
  });

  final String? initialProductId;
  final String? quoteOrderId;

  @override
  State<SupplierQuoteEditorPage> createState() =>
      _SupplierQuoteEditorPageState();
}

class _SupplierQuoteEditorPageState extends State<SupplierQuoteEditorPage> {
  static const _darkRed = Color(0xFF741C1C);
  final _sourceReferenceController = TextEditingController();
  final _customerReferenceController = TextEditingController();
  final _deliveryNotesController = TextEditingController();
  final _internalNotesController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _deliveryFeeController = TextEditingController(text: '0');

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _supplierBusinessId;
  String? _selectedCustomerAccountId;
  String? _editingQuoteNumber;
  int _editingQuoteRevision = 0;
  String _orderSource = 'phone';
  String _paymentMethod = 'cod';
  int _paymentTermsDays = 0;
  String _fulfilmentMethod = 'delivery';
  DateTime? _requestedFulfilmentDate;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _lines = [];

  @override
  void initState() {
    super.initState();
    _productSearchController.addListener(_refresh);
    _loadPage();
  }

  @override
  void dispose() {
    _sourceReferenceController.dispose();
    _customerReferenceController.dispose();
    _deliveryNotesController.dispose();
    _internalNotesController.dispose();
    _deliveryFeeController.dispose();
    _productSearchController.removeListener(_refresh);
    _productSearchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
          .eq('status', 'active');

      final businessIds = <String>[
        for (final raw in memberships)
          if (raw['business_id'] != null) raw['business_id'].toString(),
      ];

      if (businessIds.isEmpty) {
        throw Exception('No active business membership was found.');
      }

      final businesses = await client
          .from('businesses')
          .select('id, business_type, active')
          .inFilter('id', businessIds)
          .eq('active', true);

      String? supplierBusinessId;

      for (final raw in businesses) {
        if (raw['business_type']?.toString() == 'supplier') {
          supplierBusinessId = raw['id']?.toString();
          break;
        }
      }

      if (supplierBusinessId == null || supplierBusinessId.isEmpty) {
        throw Exception('No active supplier business membership was found.');
      }

      final customerResponse = await client
          .from('supplier_customer_accounts')
          .select(
            'id, customer_name, legal_name, account_source, linked_butcher_business_id, account_reference, payment_method, payment_terms_days, contact_name, email, phone, abn, delivery_address_line_1, delivery_address_line_2, delivery_suburb, delivery_state, delivery_postcode, active',
          )
          .eq('supplier_business_id', supplierBusinessId)
          .eq('active', true)
          .order('customer_name');

      final productResponse = await client
          .from('products')
          .select(
            'id, sku, product_name, active, order_unit, quantity_unit, price_basis, weight_type, catch_weight, product_prices(id, amount, price_basis, minimum_quantity, minimum_quantity_unit, active, price_lists(id, name, visibility, active))',
          )
          .eq('supplier_business_id', supplierBusinessId)
          .eq('active', true)
          .order('product_name');

      if (!mounted) {
        return;
      }
      final customers = List<Map<String, dynamic>>.from(customerResponse);
      final products = List<Map<String, dynamic>>.from(productResponse);

      final firstCustomer = customers.isEmpty ? null : customers.first;

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _customers = customers;
        _products = products;
        _selectedCustomerAccountId = firstCustomer?['id']?.toString();
        _paymentMethod = firstCustomer?['payment_method']?.toString() ?? 'cod';
        _paymentTermsDays =
            (firstCustomer?['payment_terms_days'] as num?)?.toInt() ?? 0;
        _isLoading = false;
      });

      final quoteOrderId = widget.quoteOrderId;

      if (quoteOrderId != null && quoteOrderId.isNotEmpty) {
        await _loadExistingQuote(quoteOrderId);
      } else {
        final initialProductId = widget.initialProductId;

        if (initialProductId != null && initialProductId.isNotEmpty) {
          Map<String, dynamic>? initialProduct;

          for (final product in products) {
            if (product['id']?.toString() == initialProductId) {
              initialProduct = product;
              break;
            }
          }

          if (initialProduct != null && mounted) {
            final productToAdd = initialProduct;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _addProduct(productToAdd);
              }
            });
          }
        }
      }
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

  bool _isCatchWeight(Map<String, dynamic> product) {
    return product['weight_type']?.toString() == 'catch_weight' ||
        product['catch_weight'] == true;
  }

  String _orderUnit(Map<String, dynamic> product) {
    if (_isCatchWeight(product)) {
      return 'carton';
    }
    final configured = product['order_unit']?.toString();
    if (configured == 'carton' ||
        configured == 'kilogram' ||
        configured == 'unit') {
      return configured!;
    }
    final stockUnit = product['quantity_unit']?.toString();
    if (stockUnit == 'carton' ||
        stockUnit == 'kilogram' ||
        stockUnit == 'unit') {
      return stockUnit!;
    }
    return 'unit';
  }

  String _priceBasis(Map<String, dynamic> product) {
    if (_isCatchWeight(product)) {
      return 'kilogram';
    }
    final configured = product['price_basis']?.toString();
    if (configured == 'carton' ||
        configured == 'kilogram' ||
        configured == 'unit') {
      return configured!;
    }
    return 'unit';
  }

  String _unitLabel(String value) => switch (value) {
    'carton' => 'cartons',
    'kilogram' => 'kg',
    'unit' => 'units',
    _ => value,
  };

  String _basisLabel(String value) => switch (value) {
    'carton' => 'carton',
    'kilogram' => 'kg',
    'unit' => 'unit',
    _ => value,
  };

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number == null ? '\$0.00' : '\$${number.toStringAsFixed(2)}';
  }

  Map<String, dynamic>? _standardPrice(Map<String, dynamic> product) {
    final rawPrices = product['product_prices'];
    if (rawPrices is! List) {
      return null;
    }
    for (final raw in rawPrices) {
      if (raw is! Map) {
        continue;
      }
      final price = Map<String, dynamic>.from(raw);
      if (price['active'] != true) {
        continue;
      }
      final rawList = price['price_lists'];
      if (rawList is! Map) {
        continue;
      }
      final list = Map<String, dynamic>.from(rawList);
      if (list['active'] == true &&
          list['visibility']?.toString() == 'public') {
        return price;
      }
    }
    return null;
  }

  Map<String, dynamic>? _selectedCustomer() {
    final id = _selectedCustomerAccountId;
    if (id == null) {
      return null;
    }
    for (final customer in _customers) {
      if (customer['id']?.toString() == id) {
        return customer;
      }
    }
    return null;
  }

  void _applyCustomerDefaults(String? customerId) {
    _selectedCustomerAccountId = customerId;

    final customer = _selectedCustomer();
    if (customer == null) {
      return;
    }

    final method = customer['payment_method']?.toString();
    _paymentMethod = const {'cod', 'prepaid', 'account'}.contains(method)
        ? method!
        : 'cod';
    _paymentTermsDays = (customer['payment_terms_days'] as num?)?.toInt() ?? 0;
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _addCustomerInline() async {
    final supplierBusinessId = _supplierBusinessId;

    if (supplierBusinessId == null) {
      return;
    }

    final businessNameController = TextEditingController();
    final legalNameController = TextEditingController();
    final abnController = TextEditingController();
    final contactNameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final address1Controller = TextEditingController();
    final address2Controller = TextEditingController();
    final suburbController = TextEditingController();
    final stateController = TextEditingController(text: 'NSW');
    final postcodeController = TextEditingController();

    String paymentMethod = 'cod';
    int paymentTermsDays = 0;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Customer'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add the caller without leaving the sale.',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: businessNameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Business / restaurant name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: legalNameController,
                        decoration: const InputDecoration(
                          labelText: 'Legal name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: abnController,
                        decoration: const InputDecoration(
                          labelText: 'ABN (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactNameController,
                        decoration: const InputDecoration(
                          labelText: 'Contact person',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: address1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Delivery address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: address2Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address line 2 (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: suburbController,
                              decoration: const InputDecoration(
                                labelText: 'Suburb',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: stateController,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: postcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Postcode',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Default payment method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cod', child: Text('COD')),
                          DropdownMenuItem(
                            value: 'prepaid',
                            child: Text('Prepaid'),
                          ),
                          DropdownMenuItem(
                            value: 'account',
                            child: Text('Account'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            paymentMethod = value;
                            if (value != 'account') {
                              paymentTermsDays = 0;
                            } else if (paymentTermsDays == 0) {
                              paymentTermsDays = 7;
                            }
                          });
                        },
                      ),
                      if (paymentMethod == 'account') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: paymentTermsDays == 0
                              ? 7
                              : paymentTermsDays,
                          decoration: const InputDecoration(
                            labelText: 'Payment terms',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 7, child: Text('7 days')),
                            DropdownMenuItem(value: 14, child: Text('14 days')),
                            DropdownMenuItem(value: 30, child: Text('30 days')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => paymentTermsDays = value);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  onPressed: () {
                    final businessName = businessNameController.text.trim();

                    if (businessName.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter the customer business name.'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop({
                      'customer_name': businessName,
                      'legal_name': _nullable(legalNameController.text),
                      'abn': _nullable(abnController.text),
                      'contact_name': _nullable(contactNameController.text),
                      'phone': _nullable(phoneController.text),
                      'email': _nullable(emailController.text),
                      'delivery_address_line_1': _nullable(
                        address1Controller.text,
                      ),
                      'delivery_address_line_2': _nullable(
                        address2Controller.text,
                      ),
                      'delivery_suburb': _nullable(suburbController.text),
                      'delivery_state': _nullable(stateController.text),
                      'delivery_postcode': _nullable(postcodeController.text),
                      'payment_method': paymentMethod,
                      'payment_terms_days': paymentMethod == 'account'
                          ? paymentTermsDays
                          : 0,
                      'issue_reporting_window_hours': 24,
                    });
                  },
                  child: const Text('Add Customer'),
                ),
              ],
            );
          },
        );
      },
    );

    businessNameController.dispose();
    legalNameController.dispose();
    abnController.dispose();
    contactNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    address1Controller.dispose();
    address2Controller.dispose();
    suburbController.dispose();
    stateController.dispose();
    postcodeController.dispose();

    if (result == null) {
      return;
    }

    try {
      final inserted = await Supabase.instance.client
          .from('supplier_customer_accounts')
          .insert({
            'supplier_business_id': supplierBusinessId,
            'account_source': 'manual',
            ...result,
            'active': true,
          })
          .select(
            'id, customer_name, legal_name, account_source, linked_butcher_business_id, account_reference, payment_method, payment_terms_days, contact_name, email, phone, abn, delivery_address_line_1, delivery_address_line_2, delivery_suburb, delivery_state, delivery_postcode, active',
          )
          .single();

      final customer = Map<String, dynamic>.from(inserted);

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = [..._customers, customer]
          ..sort(
            (a, b) => (a['customer_name']?.toString() ?? '').compareTo(
              b['customer_name']?.toString() ?? '',
            ),
          );
        _applyCustomerDefaults(customer['id']?.toString());
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added and selected.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _selectFulfilmentDate() async {
    final now = DateTime.now();
    final initial =
        _requestedFulfilmentDate ?? now.add(const Duration(days: 1));

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (selected != null && mounted) {
      setState(() => _requestedFulfilmentDate = selected);
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) {
      return 'Choose date';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _loadExistingQuote(String orderId) async {
    final response = await Supabase.instance.client
        .from('orders')
        .select('''
          id,
          order_number,
          quote_revision,
          status,
          order_source,
          source_reference,
          customer_reference,
          delivery_notes,
          internal_notes,
          payment_method_snapshot,
          payment_terms_days_snapshot,
          fulfilment_method,
          requested_fulfilment_date,
          delivery_fee,
          supplier_customer_account_id,
          order_items(
            id,
            product_id,
            product_name_snapshot,
            sku_snapshot,
            quantity,
            quantity_unit,
            unit_price,
            price_basis,
            catch_weight_snapshot,
            notes
          )
        ''')
        .eq('id', orderId)
        .single();

    if (response['status']?.toString() != 'draft') {
      throw Exception('Only draft quotes can be edited.');
    }

    final itemRows = response['order_items'] is List
        ? List<Map<String, dynamic>>.from(
            (response['order_items'] as List).whereType<Map>().map(
              (row) => Map<String, dynamic>.from(row),
            ),
          )
        : <Map<String, dynamic>>[];

    if (!mounted) {
      return;
    }

    setState(() {
      _editingQuoteNumber = response['order_number']?.toString() ?? 'Quote';
      _editingQuoteRevision =
          (response['quote_revision'] as num?)?.toInt() ?? 0;
      _selectedCustomerAccountId = response['supplier_customer_account_id']
          ?.toString();
      _orderSource = response['order_source']?.toString() ?? 'phone';
      _paymentMethod = response['payment_method_snapshot']?.toString() ?? 'cod';
      _paymentTermsDays =
          (response['payment_terms_days_snapshot'] as num?)?.toInt() ?? 0;
      _fulfilmentMethod =
          response['fulfilment_method']?.toString() ?? 'delivery';

      final requestedDate = response['requested_fulfilment_date']?.toString();

      _requestedFulfilmentDate = requestedDate == null
          ? null
          : DateTime.tryParse(requestedDate);

      _sourceReferenceController.text =
          response['source_reference']?.toString() ?? '';
      _customerReferenceController.text =
          response['customer_reference']?.toString() ?? '';
      _deliveryNotesController.text =
          response['delivery_notes']?.toString() ?? '';
      _internalNotesController.text =
          response['internal_notes']?.toString() ?? '';
      _deliveryFeeController.text =
          (response['delivery_fee'] as num?)?.toString() ?? '0';

      _lines = itemRows.map((item) {
        return <String, dynamic>{
          'product_id': item['product_id']?.toString(),
          'product_name':
              item['product_name_snapshot']?.toString() ?? 'Product',
          'sku': item['sku_snapshot']?.toString(),
          'quantity': item['quantity'],
          'quantity_unit': item['quantity_unit']?.toString() ?? 'unit',
          'unit_price': item['unit_price'],
          'price_basis': item['price_basis']?.toString() ?? 'unit',
          'catch_weight_snapshot': item['catch_weight_snapshot'] == true,
          'notes': item['notes']?.toString(),
        };
      }).toList();
    });
  }

  String _quoteDisplayNumber() {
    final number = _editingQuoteNumber;

    if (number == null) {
      return 'New Quote';
    }

    if (_editingQuoteRevision <= 0) {
      return number;
    }

    return '$number #$_editingQuoteRevision';
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final search = _productSearchController.text.trim().toLowerCase();
    if (search.isEmpty) {
      return _products;
    }
    return _products.where((product) {
      final name = product['product_name']?.toString().toLowerCase() ?? '';
      final sku = product['sku']?.toString().toLowerCase() ?? '';
      return name.contains(search) || sku.contains(search);
    }).toList();
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) {
      return;
    }
    if (_lines.any((line) => line['product_id']?.toString() == productId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is already on the order.')),
      );
      return;
    }

    final catchWeight = _isCatchWeight(product);
    final quantityUnit = _orderUnit(product);
    final priceBasis = _priceBasis(product);
    final standardPrice = _standardPrice(product);
    final quantityController = TextEditingController(text: '1');
    final rateController = TextEditingController(
      text: standardPrice?['amount']?.toString() ?? '',
    );
    final notesController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quantity = double.tryParse(quantityController.text.trim());
            final rate = double.tryParse(rateController.text.trim());
            final whole = quantityUnit == 'carton' || quantityUnit == 'unit';
            final validQuantity =
                quantity != null &&
                quantity > 0 &&
                (!whole || quantity == quantity.roundToDouble());
            final validRate = rate != null && rate >= 0;
            return AlertDialog(
              title: Text(product['product_name']?.toString() ?? 'Add product'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (catchWeight) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE3E3DF)),
                          ),
                          child: const Text(
                            'Catch-weight product: enter cartons ordered and the agreed \$/kg rate. Final kilograms and product total are confirmed after weighing.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                      TextField(
                        controller: quantityController,
                        autofocus: true,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: !whole,
                        ),
                        inputFormatters: whole
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Order quantity',
                          suffixText: _unitLabel(quantityUnit),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: rateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Agreed rate',
                          prefixText: r'$ ',
                          suffixText: '/ ${_basisLabel(priceBasis)}',
                          helperText: standardPrice == null
                              ? 'Enter the agreed customer rate.'
                              : 'Standard price: ${_money(standardPrice['amount'])} / ${_basisLabel(priceBasis)}. You may override it for this order.',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Line notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: validQuantity && validRate
                      ? () => Navigator.of(dialogContext).pop({
                          'product_id': productId,
                          'product_name':
                              product['product_name']?.toString() ??
                              'Unnamed product',
                          'sku': product['sku']?.toString(),
                          'quantity': quantity,
                          'quantity_unit': quantityUnit,
                          'unit_price': rate,
                          'price_basis': priceBasis,
                          'catch_weight_snapshot': catchWeight,
                          'notes': notesController.text.trim(),
                        })
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: _darkRed),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
    rateController.dispose();
    notesController.dispose();
    if (result != null && mounted) {
      setState(() => _lines.add(result));
    }
  }

  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final quantityUnit = line['quantity_unit']?.toString() ?? 'unit';
    final priceBasis = line['price_basis']?.toString() ?? 'unit';
    final catchWeight = line['catch_weight_snapshot'] == true;
    final quantityController = TextEditingController(
      text: line['quantity']?.toString() ?? '1',
    );
    final rateController = TextEditingController(
      text: line['unit_price']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: line['notes']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final quantity = double.tryParse(quantityController.text.trim());
          final rate = double.tryParse(rateController.text.trim());
          final whole = quantityUnit == 'carton' || quantityUnit == 'unit';
          final validQuantity =
              quantity != null &&
              quantity > 0 &&
              (!whole || quantity == quantity.roundToDouble());
          final validRate = rate != null && rate >= 0;
          return AlertDialog(
            title: Text(line['product_name']?.toString() ?? 'Edit line'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (catchWeight) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Catch-weight: cartons ordered, rate per kg.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: !whole,
                    ),
                    inputFormatters: whole
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      suffixText: _unitLabel(quantityUnit),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Agreed rate',
                      prefixText: r'$ ',
                      suffixText: '/ ${_basisLabel(priceBasis)}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Line notes (optional)',
                      border: OutlineInputBorder(),
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
              FilledButton(
                onPressed: validQuantity && validRate
                    ? () => Navigator.of(dialogContext).pop({
                        ...line,
                        'quantity': quantity,
                        'unit_price': rate,
                        'notes': notesController.text.trim(),
                      })
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    quantityController.dispose();
    rateController.dispose();
    notesController.dispose();
    if (result != null && mounted) {
      setState(() => _lines[index] = result);
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<Map<String, dynamic>> _rpcItems() {
    return _lines
        .map(
          (line) => {
            'product_id': line['product_id'],
            'quantity': line['quantity'],
            'quantity_unit': line['quantity_unit'],
            'unit_price': line['unit_price'],
            'price_basis': line['price_basis'],
            'catch_weight_snapshot': line['catch_weight_snapshot'] == true,
            'notes': line['notes'],
          },
        )
        .toList();
  }

  Future<void> _saveQuote() async {
    final customerAccountId = _selectedCustomerAccountId;

    if (customerAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or add a customer.')),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product.')),
      );
      return;
    }

    final deliveryFee =
        double.tryParse(_deliveryFeeController.text.trim()) ?? 0;

    if (deliveryFee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery fee cannot be negative.')),
      );
      return;
    }

    final customer = _selectedCustomer();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Quote?'),
        content: Text(
          'Save this quote for ${customer?['customer_name'] ?? 'this customer'}?\n\n'
          'Catch-weight rates are agreed now. Final supplied kilograms and the final invoice amount are confirmed after fulfilment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save Quote'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final editingQuoteId = widget.quoteOrderId;

      if (editingQuoteId != null && editingQuoteId.isNotEmpty) {
        final revision = await Supabase.instance.client.rpc(
          'update_supplier_sales_desk_quote',
          params: {
            'target_order_id': editingQuoteId,
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': _orderSource,
            'p_source_reference': _nullIfEmpty(_sourceReferenceController.text),
            'p_customer_reference': _nullIfEmpty(
              _customerReferenceController.text,
            ),
            'p_delivery_notes': _nullIfEmpty(_deliveryNotesController.text),
            'p_internal_notes': _nullIfEmpty(_internalNotesController.text),
            'p_payment_method': _paymentMethod,
            'p_payment_terms_days': _paymentTermsDays,
            'p_fulfilment_method': _fulfilmentMethod,
            'p_requested_fulfilment_date': _requestedFulfilmentDate
                ?.toIso8601String()
                .split('T')
                .first,
            'p_delivery_fee': _fulfilmentMethod == 'delivery' ? deliveryFee : 0,
            'p_items': _rpcItems(),
          },
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _editingQuoteRevision = (revision as num).toInt();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quote saved as ${_quoteDisplayNumber()}.')),
        );

        Navigator.of(context).pop(editingQuoteId);
      } else {
        final quoteId = await Supabase.instance.client.rpc(
          'create_supplier_sales_desk_quote',
          params: {
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': _orderSource,
            'p_source_reference': _nullIfEmpty(_sourceReferenceController.text),
            'p_customer_reference': _nullIfEmpty(
              _customerReferenceController.text,
            ),
            'p_delivery_notes': _nullIfEmpty(_deliveryNotesController.text),
            'p_internal_notes': _nullIfEmpty(_internalNotesController.text),
            'p_payment_method': _paymentMethod,
            'p_payment_terms_days': _paymentTermsDays,
            'p_fulfilment_method': _fulfilmentMethod,
            'p_requested_fulfilment_date': _requestedFulfilmentDate
                ?.toIso8601String()
                .split('T')
                .first,
            'p_delivery_fee': _fulfilmentMethod == 'delivery' ? deliveryFee : 0,
            'p_items': _rpcItems(),
          },
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quote saved.')));

        Navigator.of(context).pop(quoteId);
      }
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createWorkOrder() async {
    final customerAccountId = _selectedCustomerAccountId;

    if (customerAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or add a customer.')),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product.')),
      );
      return;
    }

    final deliveryFee =
        double.tryParse(_deliveryFeeController.text.trim()) ?? 0;

    if (deliveryFee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery fee cannot be negative.')),
      );
      return;
    }

    final customer = _selectedCustomer();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Work Order?'),
        content: Text(
          'Create the warehouse work order for ${customer?['customer_name'] ?? 'this customer'}?\n\n'
          'The agreed rates will be locked. Catch-weight final totals remain pending until the warehouse records the actual supplied weight.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _darkRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Create Work Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final editingQuoteId = widget.quoteOrderId;
      late final String orderId;

      if (editingQuoteId != null && editingQuoteId.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'update_supplier_sales_desk_quote',
          params: {
            'target_order_id': editingQuoteId,
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': _orderSource,
            'p_source_reference': _nullIfEmpty(_sourceReferenceController.text),
            'p_customer_reference': _nullIfEmpty(
              _customerReferenceController.text,
            ),
            'p_delivery_notes': _nullIfEmpty(_deliveryNotesController.text),
            'p_internal_notes': _nullIfEmpty(_internalNotesController.text),
            'p_payment_method': _paymentMethod,
            'p_payment_terms_days': _paymentTermsDays,
            'p_fulfilment_method': _fulfilmentMethod,
            'p_requested_fulfilment_date': _requestedFulfilmentDate
                ?.toIso8601String()
                .split('T')
                .first,
            'p_delivery_fee': _fulfilmentMethod == 'delivery' ? deliveryFee : 0,
            'p_items': _rpcItems(),
          },
        );

        await Supabase.instance.client.rpc(
          'convert_supplier_quote_to_sales_order',
          params: {'target_order_id': editingQuoteId},
        );

        orderId = editingQuoteId;
      } else {
        final orderIdRaw = await Supabase.instance.client.rpc(
          'create_supplier_sales_desk_order',
          params: {
            'p_supplier_customer_account_id': customerAccountId,
            'p_order_source': _orderSource,
            'p_source_reference': _nullIfEmpty(_sourceReferenceController.text),
            'p_customer_reference': _nullIfEmpty(
              _customerReferenceController.text,
            ),
            'p_delivery_notes': _nullIfEmpty(_deliveryNotesController.text),
            'p_internal_notes': _nullIfEmpty(_internalNotesController.text),
            'p_payment_method': _paymentMethod,
            'p_payment_terms_days': _paymentTermsDays,
            'p_fulfilment_method': _fulfilmentMethod,
            'p_requested_fulfilment_date': _requestedFulfilmentDate
                ?.toIso8601String()
                .split('T')
                .first,
            'p_delivery_fee': _fulfilmentMethod == 'delivery' ? deliveryFee : 0,
            'p_items': _rpcItems(),
          },
        );

        orderId = orderIdRaw.toString();
      }

      await Supabase.instance.client.rpc(
        'create_or_get_warehouse_work_order',
        params: {'target_order_id': orderId},
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Work order created. You can print it for the warehouse now.',
          ),
        ),
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SupplierWorkOrderPage(orderId: orderId),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Phone Sales Desk',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(),
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
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadPage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Order details',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCustomerAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Customer',
                      hintText: 'Select an existing customer',
                      border: OutlineInputBorder(),
                    ),
                    items: _customers.map((customer) {
                      final name =
                          customer['customer_name']?.toString() ?? 'Customer';
                      final source = customer['account_source']?.toString();

                      return DropdownMenuItem(
                        value: customer['id']?.toString(),
                        child: Text(
                          source == 'manual' ? '$name • External' : name,
                        ),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() => _applyCustomerDefaults(value));
                          },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _addCustomerInline,
                  style: FilledButton.styleFrom(
                    backgroundColor: _darkRed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Customer'),
                ),
              ],
            ),
            if (_selectedCustomer() != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  [
                    if ((_selectedCustomer()?['contact_name']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty)
                      _selectedCustomer()?['contact_name'],
                    if ((_selectedCustomer()?['phone']?.toString().trim() ?? '')
                        .isNotEmpty)
                      _selectedCustomer()?['phone'],
                    if ((_selectedCustomer()?['email']?.toString().trim() ?? '')
                        .isNotEmpty)
                      _selectedCustomer()?['email'],
                  ].whereType<Object>().join(' • '),
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _orderSource,
              decoration: const InputDecoration(
                labelText: 'Order source',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'phone', child: Text('Phone')),
                DropdownMenuItem(value: 'email', child: Text('Email')),
                DropdownMenuItem(value: 'sales_rep', child: Text('Sales Rep')),
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _orderSource = value);
                      }
                    },
            ),
            const SizedBox(height: 14),
            const Text(
              'Commercial details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cod', child: Text('COD')),
                      DropdownMenuItem(
                        value: 'prepaid',
                        child: Text('Prepaid'),
                      ),
                      DropdownMenuItem(
                        value: 'account',
                        child: Text('Account'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _paymentMethod = value;
                              if (value != 'account') {
                                _paymentTermsDays = 0;
                              } else if (_paymentTermsDays == 0) {
                                _paymentTermsDays = 7;
                              }
                            });
                          },
                  ),
                ),
                if (_paymentMethod == 'account')
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      initialValue: _paymentTermsDays == 0
                          ? 7
                          : _paymentTermsDays,
                      decoration: const InputDecoration(
                        labelText: 'Terms',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                        DropdownMenuItem(value: 14, child: Text('14 days')),
                        DropdownMenuItem(value: 30, child: Text('30 days')),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _paymentTermsDays = value);
                              }
                            },
                    ),
                  ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _fulfilmentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Pickup / delivery',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'delivery',
                        child: Text('Delivery'),
                      ),
                      DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _fulfilmentMethod = value;
                                if (value == 'pickup') {
                                  _deliveryFeeController.text = '0';
                                }
                              });
                            }
                          },
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _selectFulfilmentDate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _requestedFulfilmentDate == null
                          ? 'Fulfilment date'
                          : _dateLabel(_requestedFulfilmentDate),
                    ),
                  ),
                ),
                if (_fulfilmentMethod == 'delivery')
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _deliveryFeeController,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Delivery fee',
                        prefixText: r'$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _sourceReferenceController,
              decoration: const InputDecoration(
                labelText: 'Source reference (optional)',
                hintText:
                    'Example: phone call note, email subject, rep reference',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _customerReferenceController,
              decoration: const InputDecoration(
                labelText: 'Customer reference / PO (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _deliveryNotesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Delivery notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _internalNotesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Internal notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'Products',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _productSearchController,
              decoration: const InputDecoration(
                labelText: 'Find a product',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: _filteredProducts.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No matching products.'),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final catchWeight = _isCatchWeight(product);
                        final standardPrice = _standardPrice(product);
                        return ListTile(
                          title: Text(
                            product['product_name']?.toString() ??
                                'Unnamed product',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (product['sku'] != null &&
                                  product['sku'].toString().trim().isNotEmpty)
                                'SKU ${product['sku']}',
                              if (catchWeight) 'Order cartons • priced / kg',
                              if (standardPrice != null)
                                'Standard ${_money(standardPrice['amount'])} / ${_basisLabel(_priceBasis(product))}',
                            ].join(' • '),
                          ),
                          trailing: FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _addProduct(product),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 22),
            if (_lines.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Text(
                  'No products added yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF666666)),
                ),
              )
            else
              for (var i = 0; i < _lines.length; i++)
                _buildLineCard(i, _lines[i]),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Finish the phone call',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Save a pricing enquiry as a quote, or create the sale and warehouse work order immediately.',
                    style: TextStyle(color: Color(0xFF666666), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 620;

                      final quoteButton = OutlinedButton.icon(
                        onPressed: _isSaving ? null : _saveQuote,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        icon: const Icon(Icons.description_outlined),
                        label: Text(
                          widget.quoteOrderId == null
                              ? 'Save Quote'
                              : 'Save Quote Revision',
                        ),
                      );

                      final workOrderButton = FilledButton.icon(
                        onPressed: _isSaving ? null : _createWorkOrder,
                        style: FilledButton.styleFrom(
                          backgroundColor: _darkRed,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.assignment_outlined),
                        label: Text(
                          _isSaving ? 'Creating...' : 'Create Work Order',
                        ),
                      );

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            quoteButton,
                            const SizedBox(height: 10),
                            workOrderButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: quoteButton),
                          const SizedBox(width: 12),
                          Expanded(child: workOrderButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineCard(int index, Map<String, dynamic> line) {
    final catchWeight = line['catch_weight_snapshot'] == true;
    final quantity = line['quantity'];
    final quantityUnit = line['quantity_unit']?.toString() ?? 'unit';
    final rate = line['unit_price'];
    final basis = line['price_basis']?.toString() ?? 'unit';
    String? knownLineTotal;
    if (!catchWeight) {
      final q = quantity is num
          ? quantity.toDouble()
          : double.tryParse('$quantity');
      final r = rate is num ? rate.toDouble() : double.tryParse('$rate');
      if (q != null && r != null) {
        knownLineTotal = _money(q * r);
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: Text(
          line['product_name']?.toString() ?? 'Product',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            catchWeight
                ? '$quantity ${_unitLabel(quantityUnit)} ordered at ${_money(rate)} / ${_basisLabel(basis)} • Final total pending weight'
                : '$quantity ${_unitLabel(quantityUnit)} × ${_money(rate)} / ${_basisLabel(basis)} = ${knownLineTotal ?? 'Pending'}',
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              onPressed: _isSaving ? null : () => _editLine(index),
              tooltip: 'Edit line',
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() => _lines.removeAt(index)),
              tooltip: 'Remove line',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
