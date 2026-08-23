import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_invoice_page.dart';
import 'supplier_marketplace_order_detail_page.dart';
import 'supplier_work_order_page.dart';

class SupplierOrdersPage extends StatefulWidget {
  const SupplierOrdersPage({super.key, this.initialTabKey});

  final String? initialTabKey;

  @override
  State<SupplierOrdersPage> createState() => _SupplierOrdersPageState();
}

class _SupplierOrdersPageState extends State<SupplierOrdersPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  String? _supplierBusinessId;
  String? _updatingOrderId;
  String? _updatingIssueId;

  late final TabController _tabController;

  List<Map<String, dynamic>> _orders = [];

  static const _tabs = <_OrderTabDefinition>[
    _OrderTabDefinition(
      label: 'New',
      icon: Icons.notifications_none,
      key: 'new',
    ),
    _OrderTabDefinition(
      label: 'Work Orders',
      icon: Icons.assignment_outlined,
      key: 'work_orders',
    ),
    _OrderTabDefinition(
      label: 'Invoices',
      icon: Icons.receipt_long_outlined,
      key: 'invoices',
    ),
    _OrderTabDefinition(
      label: 'Dispatched',
      icon: Icons.local_shipping_outlined,
      key: 'dispatched',
    ),
    _OrderTabDefinition(
      label: 'Delivered / Complete',
      icon: Icons.task_alt,
      key: 'completed',
    ),
  ];

  @override
  void initState() {
    super.initState();

    var initialIndex = 0;
    final requestedKey = widget.initialTabKey;

    if (requestedKey != null) {
      final foundIndex = _tabs.indexWhere((tab) => tab.key == requestedKey);

      if (foundIndex >= 0) {
        initialIndex = foundIndex;
      }
    }

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final memberships = await Supabase.instance.client
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

      final businesses = await Supabase.instance.client
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

      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            order_number,
            butcher_business_id,
            supplier_business_id,
            status,
            order_source,
            source_reference,
            created_by_business_id,
            order_type,
            replacement_for_order_id,
            replacement_issue_id,
            replacement_for_order_number_snapshot,
            customer_reference,
            delivery_notes,
            fulfilment_method,
            internal_notes,
            supplier_customer_account_id,
            pricing_status,
            minimum_order_status,
            delivery_fee,
            subtotal,
            gst_amount,
            total_amount,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            issue_reporting_window_hours_snapshot,
            submitted_at,
            accepted_at,
            declined_at,
            supplier_rejection_reason,
            butcher_rejection_acknowledged_at,
            dispatched_at,
            delivered_at,
            completed_at,
            cancelled_at,
            created_at,
            updated_at,

            businesses!orders_butcher_business_id_fkey(
              id,
              legal_name,
              trading_name,
              business_email,
              business_phone,
              address_line_1,
              address_line_2,
              suburb,
              state,
              postcode
            ),

            supplier_customer_accounts(
              id,
              customer_name,
              legal_name,
              account_source
            ),

            invoices(
              id,
              invoice_number,
              status,
              invoice_date,
              total_amount,
              sent_to_butcher_at
            ),
            warehouse_work_orders(
              id,
              work_order_number,
              status
            ),

            order_items(
              id,
              product_id,
              product_name_snapshot,
              sku_snapshot,
              quantity,
              quantity_unit,
              unit_price,
              price_basis,
              line_subtotal,
              notes,
              supplied_quantity,
              supplied_quantity_unit,
              actual_weight,
              actual_weight_unit,
              final_line_amount,
              fulfilment_status,
              finalised_at,
              catch_weight_snapshot
            ),

            order_issues!order_issues_order_id_fkey(
              id,
              status,
              issue_reason,
              description,
              reported_at,
              within_reporting_window,
              resolution_type,
              supplier_response,
              credit_amount,
              pickup_required,
              replacement_required,
              approved_at,
              rejected_at,
              resolved_at,
              butcher_confirmed_at,
              butcher_confirmed_by_business_id,
              replacement_order_id,
              order_issue_messages(
                id,
                sender_business_id,
                sender_role,
                message,
                created_at
              )
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .order('updated_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _supplierBusinessId = supplierBusinessId;
        _orders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
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

  List<Map<String, dynamic>> _items(Map<String, dynamic> order) {
    final raw = order['order_items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _issues(Map<String, dynamic> order) {
    final raw = order['order_issues'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((issue) => Map<String, dynamic>.from(issue))
        .toList();
  }

  bool _hasOpenIssues(Map<String, dynamic> order) {
    return _issues(order).any((issue) {
      final status = issue['status']?.toString();

      return status != 'resolved' &&
          status != 'rejected' &&
          status != 'cancelled';
    });
  }

  List<Map<String, dynamic>> _ordersForTab(String key) {
    final marketplace = _orders.where(
      (order) => order['order_source']?.toString() == 'marketplace',
    );

    switch (key) {
      case 'new':
        return marketplace
            .where((order) => order['status']?.toString() == 'submitted')
            .toList();

      case 'work_orders':
        return marketplace.where((order) {
          final status = order['status']?.toString();
          final hasInvoice = _invoiceForOrder(order) != null;

          return (status == 'accepted' || status == 'processing') &&
              !hasInvoice;
        }).toList();

      case 'invoices':
        return marketplace
            .where((order) => _invoiceForOrder(order) != null)
            .toList();

      case 'dispatched':
        return marketplace
            .where((order) => order['status']?.toString() == 'dispatched')
            .toList();

      case 'completed':
        return marketplace
            .where((order) => order['status']?.toString() == 'completed')
            .toList();

      case 'issues':
        return marketplace.where(_hasOpenIssues).toList();

      default:
        return const <Map<String, dynamic>>[];
    }
  }

  int _countForTab(String key) {
    if (key == 'new') {
      var itemCount = 0;

      for (final order in _ordersForTab(key)) {
        itemCount += _items(order).length;
      }

      return itemCount;
    }

    if (key == 'issues') {
      var issueCount = 0;

      for (final order in _orders) {
        issueCount += _issues(order).where((issue) {
          final status = issue['status']?.toString();

          return status != 'resolved' &&
              status != 'rejected' &&
              status != 'cancelled';
        }).length;
      }

      return issueCount;
    }

    return _ordersForTab(key).length;
  }

  Map<String, dynamic>? _mapValue(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }

    return null;
  }

  Map<String, dynamic>? _canonicalButcherBusiness(Map<String, dynamic> order) {
    if (order['butcher_business_id'] == null) {
      return null;
    }

    return _mapValue(order['businesses']);
  }

  Map<String, dynamic>? _supplierCustomerAccount(Map<String, dynamic> order) {
    return _mapValue(order['supplier_customer_accounts']);
  }

  String _customerName(Map<String, dynamic> order) {
    final butcher = _canonicalButcherBusiness(order);

    if (butcher != null) {
      final tradingName = butcher['trading_name']?.toString().trim();

      if (tradingName != null && tradingName.isNotEmpty) {
        return tradingName;
      }

      final legalName = butcher['legal_name']?.toString().trim();

      if (legalName != null && legalName.isNotEmpty) {
        return legalName;
      }
    }

    final account = _supplierCustomerAccount(order);

    if (account != null) {
      final customerName = account['customer_name']?.toString().trim();

      if (customerName != null && customerName.isNotEmpty) {
        return customerName;
      }

      final legalName = account['legal_name']?.toString().trim();

      if (legalName != null && legalName.isNotEmpty) {
        return legalName;
      }
    }

    return order['butcher_business_id'] != null
        ? 'Registered CutLink butcher'
        : 'External customer';
  }

  String _businessAddress(Map<String, dynamic> business) {
    final lines = <String>[];

    final line1 = business['address_line_1']?.toString().trim();
    final line2 = business['address_line_2']?.toString().trim();

    if (line1 != null && line1.isNotEmpty) lines.add(line1);
    if (line2 != null && line2.isNotEmpty) lines.add(line2);

    final locality = <String>[
      if ((business['suburb']?.toString().trim() ?? '').isNotEmpty)
        business['suburb'].toString().trim(),
      if ((business['state']?.toString().trim() ?? '').isNotEmpty)
        business['state'].toString().trim(),
      if ((business['postcode']?.toString().trim() ?? '').isNotEmpty)
        business['postcode'].toString().trim(),
    ].join(' ');

    if (locality.isNotEmpty) lines.add(locality);

    return lines.isEmpty ? 'Not provided' : lines.join(', ');
  }

  String _displayValue(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? 'Not provided' : text;
  }

  Widget _customerIdentityCard(Map<String, dynamic> order) {
    final butcher = _canonicalButcherBusiness(order);
    final account = _supplierCustomerAccount(order);

    if (butcher != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1DE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 19,
                  color: Color(0xFF741C1C),
                ),
                SizedBox(width: 8),
                Text(
                  'Registered CutLink butcher',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _customerDetailLine(
              'Trading name',
              _displayValue(butcher['trading_name']),
            ),
            _customerDetailLine(
              'Legal name',
              _displayValue(butcher['legal_name']),
            ),
            _customerDetailLine(
              'Email',
              _displayValue(butcher['business_email']),
            ),
            _customerDetailLine(
              'Phone',
              _displayValue(butcher['business_phone']),
            ),
            _customerDetailLine('Address', _businessAddress(butcher)),
            if (account != null) ...[
              const Divider(height: 22),
              _customerDetailLine(
                'Supplier relationship',
                _displayValue(account['account_source']),
              ),
            ],
          ],
        ),
      );
    }

    if (account != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E1DE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supplier customer',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _customerDetailLine(
              'Customer',
              _displayValue(account['customer_name'] ?? account['legal_name']),
            ),
            _customerDetailLine(
              'Source',
              _displayValue(account['account_source']),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _customerDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCatchWeightItem(Map<String, dynamic> item) {
    return item['catch_weight_snapshot'] == true &&
        item['price_basis']?.toString() == 'kilogram';
  }

  bool _orderHasCatchWeight(Map<String, dynamic> order) {
    return _items(order).any(_isCatchWeightItem);
  }

  bool _catchWeightFulfilmentComplete(Map<String, dynamic> order) {
    final catchItems = _items(order).where(_isCatchWeightItem).toList();

    if (catchItems.isEmpty) {
      return true;
    }

    return catchItems.every((item) {
      return item['fulfilment_status']?.toString() == 'finalised' &&
          item['actual_weight'] != null &&
          item['final_line_amount'] != null;
    });
  }

  double _finalisedProductTotal(Map<String, dynamic> order) {
    var total = 0.0;

    for (final item in _items(order)) {
      if (_isCatchWeightItem(item)) {
        total += _asDouble(item['final_line_amount']);
      } else {
        total += _asDouble(item['line_subtotal']);
      }
    }

    return total;
  }

  Map<String, dynamic>? _workOrderForOrder(Map<String, dynamic> order) {
    final raw = order['warehouse_work_orders'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }

    return null;
  }

  Map<String, dynamic>? _invoiceForOrder(Map<String, dynamic> order) {
    final raw = order['invoices'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }

    return null;
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
    if (value == null) {
      return '0';
    }

    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return value.toString();
    }

    if (number == number.roundToDouble()) {
      return _withThousandsSeparators(number.toInt().toString());
    }

    final formatted = number
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return _withThousandsSeparators(formatted);
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('$value') ?? 0;
  }

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');

    if (number == null) {
      return '\$0.00';
    }

    return '\$${_withThousandsSeparators(number.toStringAsFixed(2))}';
  }

  String _unitLabel(String? value) {
    switch (value) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'cartons';
      case 'unit':
        return 'units';
      default:
        return value ?? '';
    }
  }

  String _priceBasisLabel(String? value) {
    switch (value) {
      case 'kilogram':
        return 'kg';
      case 'carton':
        return 'carton';
      case 'unit':
        return 'unit';
      default:
        return value ?? '';
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'submitted':
        return 'New';
      case 'accepted':
      case 'processing':
        return 'Work Order';
      case 'dispatched':
        return 'Dispatched';
      case 'completed':
        return 'Delivered / Complete';
      case 'declined':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status ?? 'Unknown';
    }
  }

  Color _statusBackground(String? status) {
    switch (status) {
      case 'accepted':
      case 'completed':
        return const Color(0xFFE8F5E9);

      case 'declined':
      case 'cancelled':
        return const Color(0xFFFDECEC);

      case 'processing':
        return const Color(0xFFFFF4E5);

      case 'dispatched':
      case 'delivered':
        return const Color(0xFFEAF6F8);

      case 'submitted':
      default:
        return const Color(0xFFEAF1FB);
    }
  }

  Color _statusForeground(String? status) {
    switch (status) {
      case 'accepted':
      case 'completed':
        return const Color(0xFF2E7D32);

      case 'declined':
      case 'cancelled':
        return const Color(0xFFB3261E);

      case 'processing':
        return const Color(0xFF9A5B00);

      case 'dispatched':
      case 'delivered':
        return const Color(0xFF27666F);

      case 'submitted':
      default:
        return const Color(0xFF315A8C);
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) {
      return '';
    }

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _paymentTermsText(Map<String, dynamic> order) {
    final method = order['payment_method_snapshot']?.toString();

    switch (method) {
      case 'account':
        final days = order['payment_terms_days_snapshot'];
        return '${_formatNumber(days)} day account';

      case 'prepaid':
        return 'Prepaid';

      case 'cod':
        return 'COD';

      default:
        return 'Not recorded';
    }
  }

  String _issueReasonLabel(String? reason) {
    switch (reason) {
      case 'wrong_product':
        return 'Wrong product';
      case 'quality_issue':
        return 'Quality issue';
      case 'damaged_product':
        return 'Damaged product';
      case 'missing_product':
        return 'Missing product';
      case 'quantity_issue':
        return 'Quantity issue';
      case 'temperature_issue':
        return 'Temperature issue';
      case 'packaging_issue':
        return 'Packaging issue';
      case 'other':
        return 'Other';
      default:
        return reason ?? 'Issue';
    }
  }

  bool _isReplacementOrder(Map<String, dynamic> order) {
    return order['order_type']?.toString() == 'replacement';
  }

  List<Map<String, dynamic>> _issueMessages(Map<String, dynamic> issue) {
    final raw = issue['order_issue_messages'];

    if (raw is! List) {
      return [];
    }

    final messages = raw
        .whereType<Map>()
        .map((message) => Map<String, dynamic>.from(message))
        .toList();

    messages.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');

      if (aDate == null && bDate == null) {
        return 0;
      }
      if (aDate == null) {
        return -1;
      }
      if (bDate == null) {
        return 1;
      }

      return aDate.compareTo(bDate);
    });

    return messages;
  }

  List<Map<String, dynamic>> _issueConversationEntries(
    Map<String, dynamic> issue,
  ) {
    final entries = <Map<String, dynamic>>[];

    void addSystem(String text, dynamic at) {
      if (text.trim().isEmpty) return;
      entries.add({'kind': 'system', 'message': text, 'created_at': at});
    }

    final reportedAt = issue['reported_at'];
    addSystem(
      'Issue reported: ${_issueReasonLabel(issue['issue_reason']?.toString())}.',
      reportedAt,
    );

    for (final message in _issueMessages(issue)) {
      entries.add({...message, 'kind': 'message'});
    }

    final status = issue['status']?.toString();
    final supplierHasReplied = _issueMessages(
      issue,
    ).any((message) => message['sender_role']?.toString() == 'supplier');

    if (status == 'requested' && !supplierHasReplied) {
      addSystem('Waiting for supplier response.', reportedAt);
    }

    final approvedAt = issue['approved_at'];
    if (approvedAt != null) {
      final resolution = _resolutionLabel(issue['resolution_type']?.toString());
      addSystem(
        'Resolution proposed: $resolution. Waiting for the butcher to review the supplier response.',
        approvedAt,
      );
    }

    final rejectedAt = issue['rejected_at'];
    if (rejectedAt != null) {
      addSystem('Issue rejected by supplier.', rejectedAt);
    }

    final resolvedAt = issue['resolved_at'];
    if (resolvedAt != null) {
      addSystem('Resolution completed. Issue closed.', resolvedAt);
    }

    final butcherConfirmedAt = issue['butcher_confirmed_at'];
    if (butcherConfirmedAt != null) {
      addSystem(
        'Butcher confirmed the resolution was completed satisfactorily.',
        butcherConfirmedAt,
      );
    }

    entries.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      return aDate.compareTo(bDate);
    });

    return entries;
  }

  Widget _supplierIssueConversationEntry(Map<String, dynamic> entry) {
    final kind = entry['kind']?.toString();
    final createdAt = _formatDate(entry['created_at']);

    if (kind == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            const Expanded(child: Divider()),
            const SizedBox(width: 9),
            Flexible(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${entry['message'] ?? ''}${createdAt.isEmpty ? '' : ' • $createdAt'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(child: Divider()),
          ],
        ),
      );
    }

    final butcher = entry['sender_role']?.toString() == 'butcher';
    return Align(
      alignment: butcher ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 9),
        child: Column(
          crossAxisAlignment: butcher
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                butcher ? 'Butcher' : 'You',
                style: TextStyle(
                  color: butcher
                      ? const Color(0xFF315A8C)
                      : const Color(0xFF741C1C),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
              decoration: BoxDecoration(
                color: butcher
                    ? const Color(0xFFEAF1FB)
                    : const Color(0xFFF5EAEA),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(butcher ? 3 : 12),
                  bottomRight: Radius.circular(butcher ? 12 : 3),
                ),
                border: Border.all(
                  color: butcher
                      ? const Color(0xFFC6D7EB)
                      : const Color(0xFFD7B8B8),
                ),
              ),
              child: Text(
                entry['message']?.toString() ?? '',
                style: const TextStyle(fontSize: 11.5, height: 1.4),
              ),
            ),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  createdAt,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createReplacementFulfilment(
    Map<String, dynamic> order,
    Map<String, dynamic> issue,
  ) async {
    final issueId = issue['id']?.toString();

    if (issueId == null || issueId.isEmpty || _updatingIssueId != null) {
      return;
    }

    final existingReplacement = issue['replacement_order_id']?.toString();

    if (existingReplacement != null && existingReplacement.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A replacement fulfilment already exists for this issue.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Replacement Fulfilment?'),
          content: Text(
            'Create a no-charge replacement order for the affected '
            'products in ${order['order_number'] ?? 'this order'}? '
            'It will start in Accepted and move through Processing, '
            'Dispatched, Delivered and Completed like a normal order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              child: const Text('Create Replacement'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _updatingIssueId = issueId;
    });

    try {
      final replacementId = await Supabase.instance.client.rpc(
        'create_replacement_order',
        params: {'target_issue_id': issueId},
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Replacement fulfilment created'
            '${replacementId == null ? '.' : ' successfully.'}',
          ),
        ),
      );

      await _loadOrders();

      if (mounted) {
        _tabController.animateTo(1);
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingIssueId = null;
        });
      }
    }
  }

  bool _isIssueClosed(Map<String, dynamic> issue) {
    final status = issue['status']?.toString();
    return status == 'resolved' ||
        status == 'rejected' ||
        status == 'cancelled';
  }

  Future<void> _confirmResolutionCompleted(
    Map<String, dynamic> order,
    Map<String, dynamic> issue,
  ) async {
    final issueId = issue['id']?.toString();
    final supplierBusinessId = _supplierBusinessId;

    if (issueId == null ||
        issueId.isEmpty ||
        supplierBusinessId == null ||
        _updatingIssueId != null ||
        _isIssueClosed(issue)) {
      return;
    }

    final resolution = _resolutionLabel(issue['resolution_type']?.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Resolution Completed?'),
          content: Text(
            'Confirm that the agreed resolution has actually been completed.\n\n'
            'Resolution: $resolution\n\n'
            'This closes the issue for both businesses but keeps the full '
            'complaint and resolution history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not Yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
              ),
              child: const Text('Confirm Completed'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _updatingIssueId = issueId;
    });

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await Supabase.instance.client
          .from('order_issues')
          .update({'status': 'resolved', 'resolved_at': now})
          .eq('id', issueId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Issue resolved for ${order['order_number'] ?? 'this order'}.',
          ),
        ),
      );

      await _loadOrders();

      // Issues now live in the dedicated Issues page.
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _updatingIssueId = null;
        });
      }
    }
  }

  String _resolutionLabel(String? value) {
    switch (value) {
      case 'replacement':
        return 'Replacement / exchange';
      case 'credit':
        return 'Account credit / credit note';
      case 'refund':
        return 'Refund';
      case 'collection':
        return 'Supplier collection';
      case 'other':
        return 'Other';
      default:
        return value?.replaceAll('_', ' ') ?? 'Not set';
    }
  }

  Future<void> _respondToIssue(
    Map<String, dynamic> order,
    Map<String, dynamic> issue,
  ) async {
    final issueId = issue['id']?.toString();

    if (issueId == null || issueId.isEmpty || _updatingIssueId != null) {
      return;
    }

    final responseController = TextEditingController();
    final creditController = TextEditingController(
      text: issue['credit_amount']?.toString() ?? '',
    );

    String action = issue['status']?.toString() == 'approved'
        ? 'approve'
        : 'approve';
    String resolutionType =
        issue['resolution_type']?.toString() ?? 'replacement';
    bool pickupRequired = issue['pickup_required'] == true;
    bool replacementRequired = issue['replacement_required'] == true;
    bool saving = false;
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> save() async {
                if (saving) return;

                final response = responseController.text.trim();
                final creditText = creditController.text.trim();
                final credit = creditText.isEmpty
                    ? null
                    : double.tryParse(creditText);

                if (response.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a message for the butcher.'),
                    ),
                  );
                  return;
                }

                if (creditText.isNotEmpty && (credit == null || credit < 0)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid credit amount.'),
                    ),
                  );
                  return;
                }

                setDialogState(() => saving = true);
                if (mounted) setState(() => _updatingIssueId = issueId);

                try {
                  final now = DateTime.now().toUtc().toIso8601String();
                  final update = <String, dynamic>{
                    'supplier_response': response,
                    'resolution_type': resolutionType,
                    'pickup_required': pickupRequired,
                    'replacement_required': replacementRequired,
                    'credit_amount': credit,
                  };

                  if (action == 'approve') {
                    update['status'] = 'approved';
                    update['approved_at'] = now;
                    update['rejected_at'] = null;
                    update['resolved_at'] = null;
                  } else {
                    update['status'] = 'rejected';
                    update['rejected_at'] = now;
                    update['approved_at'] = null;
                    update['resolved_at'] = null;
                  }

                  await Supabase.instance.client
                      .from('order_issues')
                      .update(update)
                      .eq('id', issueId);

                  await Supabase.instance.client
                      .from('order_issue_messages')
                      .insert({
                        'order_issue_id': issueId,
                        'sender_business_id': _supplierBusinessId,
                        'sender_role': 'supplier',
                        'message': response,
                      });

                  if (!dialogContext.mounted) return;
                  saved = true;
                  Navigator.of(dialogContext).pop();
                } on PostgrestException catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                    setDialogState(() => saving = false);
                  }
                }
              }

              return Dialog(
                backgroundColor: const Color(0xFFF7F7F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 650,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5EAEA),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.rule_folder_outlined,
                                color: Color(0xFF741C1C),
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Process Issue',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${order['order_number'] ?? 'Order'} • ${_customerName(order)}',
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE0E0DD)),
                          ),
                          child: Text(
                            _issueReasonLabel(
                              issue['issue_reason']?.toString(),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: action,
                                decoration: const InputDecoration(
                                  labelText: 'Decision',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'approve',
                                    child: Text('Approve / resolve'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'reject',
                                    child: Text('Reject issue'),
                                  ),
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setDialogState(() => action = value);
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: resolutionType,
                                decoration: const InputDecoration(
                                  labelText: 'Resolution',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'replacement',
                                    child: Text('Replacement / exchange'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'credit',
                                    child: Text('Account credit'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'refund',
                                    child: Text('Refund'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'collection',
                                    child: Text('Supplier collection'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text('Other'),
                                  ),
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setDialogState(
                                            () => resolutionType = value,
                                          );
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (resolutionType == 'credit' ||
                            resolutionType == 'refund') ...[
                          TextField(
                            controller: creditController,
                            enabled: !saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Credit / refund amount inc GST',
                              prefixText: r'$ ',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            FilterChip(
                              selected: pickupRequired,
                              label: const Text('Supplier pickup required'),
                              onSelected: saving
                                  ? null
                                  : (value) => setDialogState(
                                      () => pickupRequired = value,
                                    ),
                            ),
                            FilterChip(
                              selected: replacementRequired,
                              label: const Text('Replacement required'),
                              onSelected: saving
                                  ? null
                                  : (value) => setDialogState(
                                      () => replacementRequired = value,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: responseController,
                          minLines: 3,
                          maxLines: 5,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Message to butcher',
                            hintText:
                                'Explain what you are doing and what happens next.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 7),
                            FilledButton.icon(
                              onPressed: saving ? null : save,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF741C1C),
                              ),
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined, size: 17),
                              label: Text(saving ? 'Saving' : 'Save & Send'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (saved && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        await _loadOrders();
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Issue updated and message sent.')),
          );
        });
      }
    } finally {
      responseController.dispose();
      creditController.dispose();
      if (mounted) setState(() => _updatingIssueId = null);
    }
  }

  Future<void> _editFulfilment(
    Map<String, dynamic> order,
    Map<String, dynamic> item,
  ) async {
    final orderId = order['id']?.toString();
    final itemId = item['id']?.toString();

    if (orderId == null ||
        itemId == null ||
        _supplierBusinessId == null ||
        _updatingOrderId != null) {
      return;
    }

    final catchWeight = _isCatchWeightItem(item);
    final orderedQuantity = _asDouble(item['quantity']);

    final suppliedController = TextEditingController(
      text:
          item['supplied_quantity']?.toString() ??
          (orderedQuantity == orderedQuantity.roundToDouble()
              ? orderedQuantity.toInt().toString()
              : orderedQuantity.toString()),
    );

    final weightController = TextEditingController(
      text: item['actual_weight']?.toString() ?? '',
    );

    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> save() async {
                if (saving) {
                  return;
                }

                final supplied = double.tryParse(
                  suppliedController.text.trim(),
                );
                final actualWeight = double.tryParse(
                  weightController.text.trim(),
                );

                if (supplied == null || supplied < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid supplied quantity.'),
                    ),
                  );
                  return;
                }

                final suppliedUnit =
                    item['quantity_unit']?.toString() ?? 'unit';

                if ((suppliedUnit == 'carton' || suppliedUnit == 'unit') &&
                    supplied != supplied.roundToDouble()) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Supplied cartons and units must be whole numbers.',
                      ),
                    ),
                  );
                  return;
                }

                if (catchWeight &&
                    (actualWeight == null || actualWeight <= 0)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter the actual total kilograms supplied.',
                      ),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                if (mounted) {
                  setState(() {
                    _updatingOrderId = orderId;
                  });
                }

                try {
                  final update = <String, dynamic>{
                    'supplied_quantity': supplied,
                    'supplied_quantity_unit': suppliedUnit,
                    'fulfilment_status': 'finalised',
                    'finalised_at': DateTime.now().toUtc().toIso8601String(),
                  };

                  if (catchWeight) {
                    update['actual_weight'] = actualWeight;
                    update['actual_weight_unit'] = 'kilogram';
                  }

                  await Supabase.instance.client
                      .from('order_items')
                      .update(update)
                      .eq('id', itemId)
                      .eq('order_id', orderId);

                  await Supabase.instance.client.rpc(
                    'refresh_order_pricing_status',
                    params: {'target_order_id': orderId},
                  );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        catchWeight
                            ? 'Actual cartons and kilograms saved.'
                            : 'Fulfilment saved.',
                      ),
                    ),
                  );

                  await _loadOrders();
                } on PostgrestException catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.message)));

                    setDialogState(() {
                      saving = false;
                    });
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _updatingOrderId = null;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(
                  'Fulfil ${item['product_name_snapshot'] ?? 'product'}',
                ),
                content: SizedBox(
                  width: 540,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ordered: ${_formatNumber(item['quantity'])} '
                          '${_unitLabel(item['quantity_unit']?.toString())}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Locked rate: ${_money(item['unit_price'])}'
                          '${_priceBasisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_priceBasisLabel(item['price_basis']?.toString())}'}',
                        ),
                        if (catchWeight) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE1E1DE),
                              ),
                            ),
                            child: const Text(
                              'Enter the cartons actually supplied and the actual total kilograms from the warehouse scale. No estimated carton weight is used.',
                              style: TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: suppliedController,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity supplied',
                            suffixText: _unitLabel(
                              item['quantity_unit']?.toString(),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (catchWeight) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: weightController,
                            enabled: !saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Actual total supplied weight',
                              suffixText: 'kg',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Final amount will be calculated automatically as actual kg × locked rate.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF741C1C),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.scale_outlined),
                    label: Text(saving ? 'Saving...' : 'Save Fulfilment'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      suppliedController.dispose();
      weightController.dispose();
    }
  }

  Future<void> _openNewMarketplaceOrder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SupplierMarketplaceOrderDetailPage(orderId: orderId),
      ),
    );

    if (mounted) {
      await _loadOrders();
    }
  }

  Future<void> _completeMarketplaceOrder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty || _updatingOrderId == orderId) {
      return;
    }

    final pickup = order['fulfilment_method']?.toString() == 'pickup';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(pickup ? 'Confirm Collection' : 'Confirm Delivery'),
        content: Text(
          pickup
              ? 'Confirm the butcher has collected this order? This will mark it Picked Up / Complete.'
              : 'Confirm this order has been delivered? This will mark it Delivered / Complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF741C1C),
            ),
            icon: const Icon(Icons.task_alt),
            label: Text(
              pickup ? 'Picked Up / Complete' : 'Delivered / Complete',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _updatingOrderId = orderId);

    try {
      await Supabase.instance.client.rpc(
        'complete_marketplace_order_delivery',
        params: {'target_order_id': orderId},
      );

      if (!mounted) return;

      await _loadOrders();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingOrderId = null);
      }
    }
  }

  Future<void> _openIssuesPanel() async {
    String? selectedIssueId;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (issuesContext) {
          return StatefulBuilder(
            builder: (issuesContext, setIssuesState) {
              final entries = <Map<String, dynamic>>[];
              for (final order in _ordersForTab('issues')) {
                for (final issue in _issues(order)) {
                  if (_isIssueClosed(issue)) continue;
                  entries.add({'order': order, 'issue': issue});
                }
              }

              if (selectedIssueId == null && entries.isNotEmpty) {
                selectedIssueId = (entries.first['issue'] as Map)['id']
                    ?.toString();
              }

              if (selectedIssueId != null &&
                  !entries.any(
                    (entry) =>
                        (entry['issue'] as Map)['id']?.toString() ==
                        selectedIssueId,
                  )) {
                selectedIssueId = entries.isEmpty
                    ? null
                    : (entries.first['issue'] as Map)['id']?.toString();
              }

              Map<String, dynamic>? selectedEntry;
              for (final entry in entries) {
                final issue = Map<String, dynamic>.from(entry['issue'] as Map);
                if (issue['id']?.toString() == selectedIssueId) {
                  selectedEntry = entry;
                  break;
                }
              }

              Future<void> runAndRefresh(Future<void> Function() action) async {
                await action();
                if (!issuesContext.mounted) return;
                await Future<void>.delayed(const Duration(milliseconds: 100));
                setIssuesState(() {});
              }

              Widget queueRow(Map<String, dynamic> entry) {
                final order = Map<String, dynamic>.from(entry['order'] as Map);
                final issue = Map<String, dynamic>.from(entry['issue'] as Map);
                final issueId = issue['id']?.toString() ?? '';
                final selected = issueId == selectedIssueId;
                final status = issue['status']?.toString() ?? 'requested';

                return Material(
                  color: selected ? const Color(0xFFF5EAEA) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () =>
                        setIssuesState(() => selectedIssueId = issueId),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFB78585)
                              : const Color(0xFFE0E0DD),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.report_problem_outlined,
                              color: Color(0xFF9B3333),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _issueReasonLabel(
                                    issue['issue_reason']?.toString(),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${order['order_number'] ?? 'Order'} • ${_customerName(order)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 9.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.replaceAll('_', ' '),
                            style: const TextStyle(
                              color: Color(0xFF741C1C),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              Widget workspace() {
                if (selectedEntry == null) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 56,
                          color: Color(0xFF2E7D32),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No open marketplace issues',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final order = Map<String, dynamic>.from(
                  selectedEntry['order'] as Map,
                );
                final issue = Map<String, dynamic>.from(
                  selectedEntry['issue'] as Map,
                );
                final issueId = issue['id']?.toString() ?? '';
                final status = issue['status']?.toString() ?? 'requested';
                final resolutionType = issue['resolution_type']?.toString();
                final replacementOrderId = issue['replacement_order_id']
                    ?.toString();
                final conversation = _issueConversationEntries(issue);

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0DD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _issueReasonLabel(
                                      issue['issue_reason']?.toString(),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${order['order_number'] ?? 'Order'} • ${_customerName(order)}',
                                    style: const TextStyle(
                                      color: Color(0xFF741C1C),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF9A5B00),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((issue['description']?.toString().trim() ?? '')
                          .isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F6),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            issue['description'].toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 10.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      const Divider(height: 1),
                      Expanded(
                        child: conversation.isEmpty
                            ? const Center(
                                child: Text(
                                  'No conversation yet.',
                                  style: TextStyle(color: Color(0xFF777777)),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(14),
                                children: [
                                  for (final entry in conversation)
                                    _supplierIssueConversationEntry(entry),
                                ],
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBFBF9),
                          border: Border(
                            top: BorderSide(color: Color(0xFFE0E0DD)),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (replacementOrderId == null &&
                                resolutionType == 'replacement' &&
                                status != 'rejected')
                              OutlinedButton.icon(
                                onPressed: _updatingIssueId == issueId
                                    ? null
                                    : () => runAndRefresh(
                                        () => _createReplacementFulfilment(
                                          order,
                                          issue,
                                        ),
                                      ),
                                icon: const Icon(Icons.autorenew, size: 17),
                                label: const Text('Start Replacement'),
                              ),
                            if (status == 'approved' &&
                                resolutionType != 'replacement' &&
                                replacementOrderId == null)
                              FilledButton.icon(
                                onPressed: _updatingIssueId == issueId
                                    ? null
                                    : () => runAndRefresh(
                                        () => _confirmResolutionCompleted(
                                          order,
                                          issue,
                                        ),
                                      ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                ),
                                icon: const Icon(Icons.task_alt, size: 17),
                                label: const Text('Mark Resolved'),
                              ),
                            FilledButton.icon(
                              onPressed: _updatingIssueId == issueId
                                  ? null
                                  : () => runAndRefresh(
                                      () => _respondToIssue(order, issue),
                                    ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF741C1C),
                              ),
                              icon: const Icon(Icons.reply_outlined, size: 17),
                              label: Text(
                                status == 'requested'
                                    ? 'Process & Reply'
                                    : 'Reply / Update',
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    'Marketplace Issues',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Text(
                          '${entries.length} open',
                          style: const TextStyle(
                            color: Color(0xFF741C1C),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 850;

                          final queue = Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE0E0DD),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
                                  child: Text(
                                    'Open Issues',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: entries.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No open issues.',
                                            style: TextStyle(
                                              color: Color(0xFF777777),
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.all(8),
                                          itemCount: entries.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 6),
                                          itemBuilder: (_, index) =>
                                              queueRow(entries[index]),
                                        ),
                                ),
                              ],
                            ),
                          );

                          if (narrow) {
                            return ListView(
                              children: [
                                SizedBox(height: 300, child: queue),
                                const SizedBox(height: 10),
                                SizedBox(height: 650, child: workspace()),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 330, child: queue),
                              const SizedBox(width: 10),
                              Expanded(child: workspace()),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    if (mounted) await _loadOrders();
  }

  Future<void> _openWorkOrder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierWorkOrderPage(orderId: orderId),
      ),
    );

    if (mounted) {
      await _loadOrders();
    }
  }

  Future<void> _openInvoice(Map<String, dynamic> order) async {
    final invoice = _invoiceForOrder(order);
    final invoiceId = invoice?['id']?.toString();

    if (invoiceId == null || invoiceId.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No invoice is linked to this marketplace order yet.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierInvoicePage(invoiceId: invoiceId),
      ),
    );

    if (mounted) {
      await _loadOrders();
    }
  }

  Widget _actionButtons(Map<String, dynamic> order) {
    final status = order['status']?.toString();
    final orderId = order['id']?.toString();
    final pickup = order['fulfilment_method']?.toString() == 'pickup';
    final invoice = _invoiceForOrder(order);

    if (_updatingOrderId == orderId) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status) {
      case 'submitted':
        return FilledButton.icon(
          onPressed: () => _openNewMarketplaceOrder(order),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Review New Order'),
        );

      case 'accepted':
      case 'processing':
        if (invoice != null && pickup) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openInvoice(order),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  'Invoice ${invoice['invoice_number'] ?? ''}'.trim(),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _completeMarketplaceOrder(order),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF741C1C),
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Picked Up / Complete'),
              ),
            ],
          );
        }

        return FilledButton.icon(
          onPressed: () => _openWorkOrder(order),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Open Work Order'),
        );

      case 'dispatched':
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (invoice != null)
              OutlinedButton.icon(
                onPressed: () => _openInvoice(order),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  'Invoice ${invoice['invoice_number'] ?? ''}'.trim(),
                ),
              ),
            FilledButton.icon(
              onPressed: () => _completeMarketplaceOrder(order),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              icon: const Icon(Icons.task_alt),
              label: const Text('Delivered / Complete'),
            ),
          ],
        );

      case 'completed':
        if (invoice == null) return const SizedBox.shrink();

        return OutlinedButton.icon(
          onPressed: () => _openInvoice(order),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text('Invoice ${invoice['invoice_number'] ?? ''}'.trim()),
        );

      default:
        return const SizedBox.shrink();
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
          'Marketplace Orders',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openIssuesPanel,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.report_problem_outlined),
                if (_countForTab('issues') > 0)
                  Positioned(
                    right: -9,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3261E),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _countForTab('issues') > 99
                            ? '99+'
                            : _countForTab('issues').toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: const Text('Issues'),
          ),
          IconButton(
            onPressed: _loadOrders,
            tooltip: 'Refresh orders',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _isLoading || _errorMessage != null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF741C1C),
                    unselectedLabelColor: const Color(0xFF666666),
                    indicatorColor: const Color(0xFF741C1C),
                    tabs: [for (final tab in _tabs) _buildTab(tab)],
                  ),
                ),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildTab(_OrderTabDefinition tab) {
    final count = _countForTab(tab.key);

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: 18),
          const SizedBox(width: 7),
          Text(tab.label),
          if (count > 0) ...[
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tab.key == 'new' || tab.key == 'issues'
                    ? const Color(0xFFB3261E)
                    : const Color(0xFFE9E9E6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tab.key == 'new' || tab.key == 'issues'
                      ? Colors.white
                      : const Color(0xFF444444),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
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
              const Text(
                'Customer orders could not be loaded',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadOrders,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        for (final tab in _tabs) _buildTabContent(tab, _ordersForTab(tab.key)),
      ],
    );
  }

  Widget _buildTabContent(
    _OrderTabDefinition tab,
    List<Map<String, dynamic>> orders,
  ) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 70, color: const Color(0xFF741C1C)),
                      const SizedBox(height: 18),
                      Text(
                        _emptyTitle(tab.key),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _emptyDescription(tab.key),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            itemCount: orders.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, index) {
              final order = orders[index];

              if (tab.key == 'work_orders') {
                return _buildMarketplaceWorkOrderRow(order);
              }

              if (tab.key == 'new' ||
                  tab.key == 'invoices' ||
                  tab.key == 'dispatched' ||
                  tab.key == 'completed') {
                return _buildMarketplaceLifecycleRow(order, tab.key);
              }

              return _buildOrderCard(order);
            },
          ),
        ),
      ),
    );
  }

  String _emptyTitle(String key) {
    switch (key) {
      case 'new':
        return 'No new marketplace orders';
      case 'work_orders':
        return 'No marketplace work orders';
      case 'invoices':
        return 'No marketplace invoices';
      case 'dispatched':
        return 'Nothing dispatched';
      case 'completed':
        return 'No completed marketplace orders';
      case 'issues':
        return 'No marketplace issues';
      default:
        return 'No orders';
    }
  }

  String _emptyDescription(String key) {
    switch (key) {
      case 'new':
        return 'New butcher marketplace orders will appear here for review.';
      case 'work_orders':
        return 'Accepted marketplace orders stay here while the warehouse picks, weighs and invoices them.';
      case 'invoices':
        return 'Invoices created from marketplace orders appear here. External and manual invoices stay in the Dashboard Invoices ledger only.';
      case 'dispatched':
        return 'Delivery orders move here automatically when the final invoice is created.';
      case 'completed':
        return 'Delivered orders and collected pickup orders appear here as complete.';
      case 'issues':
        return 'Open marketplace issues will appear here.';
      default:
        return '';
    }
  }

  Widget _buildMarketplaceLifecycleRow(
    Map<String, dynamic> order,
    String tabKey,
  ) {
    final invoice = _invoiceForOrder(order);
    final items = _items(order);
    final pickup = order['fulfilment_method']?.toString() == 'pickup';

    IconData icon;
    Color iconBackground;
    Color iconForeground;
    String leadingLabel;
    String dateLabel;
    String dateValue;
    VoidCallback? onTap;

    switch (tabKey) {
      case 'new':
        icon = Icons.notifications_none;
        iconBackground = const Color(0xFFEAF1FB);
        iconForeground = const Color(0xFF315A8C);
        leadingLabel = order['order_number']?.toString() ?? 'New Order';
        dateLabel = 'Received';
        dateValue = _formatDate(order['submitted_at']);
        onTap = () => _openNewMarketplaceOrder(order);
        break;

      case 'invoices':
        icon = Icons.receipt_long_outlined;
        iconBackground = const Color(0xFFF5EAEA);
        iconForeground = const Color(0xFF741C1C);
        leadingLabel =
            invoice?['invoice_number']?.toString() ??
            order['order_number']?.toString() ??
            'Invoice';
        dateLabel = 'Invoice';
        dateValue = _formatDate(invoice?['invoice_date']);
        onTap = () => _openInvoice(order);
        break;

      case 'dispatched':
        icon = Icons.local_shipping_outlined;
        iconBackground = const Color(0xFFEAF6F8);
        iconForeground = const Color(0xFF27666F);
        leadingLabel =
            invoice?['invoice_number']?.toString() ??
            order['order_number']?.toString() ??
            'Dispatched';
        dateLabel = 'Dispatched';
        dateValue = _formatDate(order['dispatched_at']);
        onTap = () => _openInvoice(order);
        break;

      case 'completed':
        icon = pickup ? Icons.shopping_bag_outlined : Icons.task_alt;
        iconBackground = const Color(0xFFE8F5E9);
        iconForeground = const Color(0xFF2E7D32);
        leadingLabel =
            invoice?['invoice_number']?.toString() ??
            order['order_number']?.toString() ??
            'Complete';
        dateLabel = pickup ? 'Collected' : 'Delivered';
        dateValue = _formatDate(order['completed_at'] ?? order['delivered_at']);
        onTap = () => _openInvoice(order);
        break;

      default:
        icon = Icons.receipt_long_outlined;
        iconBackground = const Color(0xFFF0F0F0);
        iconForeground = const Color(0xFF555555);
        leadingLabel = order['order_number']?.toString() ?? 'Order';
        dateLabel = 'Updated';
        dateValue = _formatDate(order['updated_at']);
    }

    final quantityText = items.isEmpty
        ? 'No lines'
        : '${items.length} line${items.length == 1 ? '' : 's'}';

    final fulfilment = pickup ? 'Pickup' : 'Delivery';
    final requested = _formatDate(order['requested_fulfilment_date']);
    final invoiceTotal = invoice?['total_amount'];
    final totalText = invoiceTotal == null
        ? (order['pricing_status']?.toString() == 'pending_weight'
              ? 'Pending weight'
              : _money(order['total_amount']))
        : _money(invoiceTotal);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hasOpenIssues(order)
                  ? const Color(0xFFD8A0A0)
                  : const Color(0xFFE0E0DD),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 840;

              final identity = Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconForeground, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leadingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _customerName(order),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF741C1C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final facts = Wrap(
                spacing: 22,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CompactOrderFact(label: 'FULFILMENT', value: fulfilment),
                  _CompactOrderFact(label: 'ITEMS', value: quantityText),
                  _CompactOrderFact(
                    label: dateLabel.toUpperCase(),
                    value: dateValue.isEmpty ? 'Not recorded' : dateValue,
                  ),
                  if (requested.isNotEmpty && tabKey == 'new')
                    _CompactOrderFact(label: 'REQUESTED', value: requested),
                ],
              );

              final trailing = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tabKey != 'new')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  if (tabKey != 'new') const SizedBox(width: 14),
                  Icon(
                    Icons.chevron_right,
                    color: onTap == null
                        ? const Color(0xFFBBBBBB)
                        : const Color(0xFF741C1C),
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 11),
                    facts,
                    const SizedBox(height: 9),
                    Align(alignment: Alignment.centerRight, child: trailing),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 270, child: identity),
                  const SizedBox(width: 18),
                  Expanded(child: facts),
                  const SizedBox(width: 16),
                  trailing,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceWorkOrderRow(Map<String, dynamic> order) {
    final items = _items(order);
    final workOrder = _workOrderForOrder(order);
    final workOrderNumber =
        workOrder?['work_order_number']?.toString() ?? 'Work Order';
    final finalisedCount = items
        .where((item) => item['fulfilment_status']?.toString() == 'finalised')
        .length;
    final pickup = order['fulfilment_method']?.toString() == 'pickup';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openWorkOrder(order),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hasOpenIssues(order)
                  ? const Color(0xFFD8A0A0)
                  : const Color(0xFFE0E0DD),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EAEA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Color(0xFF741C1C),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workOrderNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _customerName(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF741C1C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _compactOrderMetric(
                  pickup ? 'PICKUP' : 'DELIVERY',
                  pickup
                      ? 'Collection'
                      : _formatDate(order['requested_fulfilment_date']),
                  pickup
                      ? Icons.shopping_bag_outlined
                      : Icons.local_shipping_outlined,
                ),
              ),
              Expanded(
                flex: 2,
                child: _compactOrderMetric(
                  'PICKING',
                  '$finalisedCount / ${items.length} lines',
                  Icons.checklist_outlined,
                ),
              ),
              Expanded(
                flex: 2,
                child: _compactOrderMetric(
                  'VALUE',
                  _orderHasCatchWeight(order) &&
                          !_catchWeightFulfilmentComplete(order)
                      ? 'Pending weight'
                      : _money(
                          _orderHasCatchWeight(order)
                              ? _finalisedProductTotal(order)
                              : order['total_amount'],
                        ),
                  Icons.payments_outlined,
                ),
              ),
              if (_hasOpenIssues(order))
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Tooltip(
                    message: 'Open issue',
                    child: Icon(
                      Icons.report_problem_outlined,
                      color: Color(0xFFB3261E),
                    ),
                  ),
                ),
              const Icon(Icons.chevron_right, color: Color(0xFF777777)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactOrderMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF777777)),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = _items(order);
    final issues = _issues(order);
    final status = order['status']?.toString();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: _hasOpenIssues(order)
              ? const Color(0xFFD8A0A0)
              : const Color(0xFFE0E0E0),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: status == 'submitted',
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order['order_number']?.toString() ?? 'Order',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _customerName(order),
                    style: const TextStyle(
                      color: Color(0xFF741C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_isReplacementOrder(order)) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        const Chip(
                          avatar: Icon(Icons.autorenew, size: 15),
                          label: Text('REPLACEMENT JOB'),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (order['replacement_for_order_number_snapshot'] !=
                            null)
                          Text(
                            'For ${order['replacement_for_order_number_snapshot']}',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_hasOpenIssues(order)) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.report_problem_outlined,
                      size: 15,
                      color: Color(0xFFB3261E),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Issue',
                      style: TextStyle(
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _statusBackground(status),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  color: _statusForeground(status),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text('${items.length} item${items.length == 1 ? '' : 's'}'),
              Text(
                _orderHasCatchWeight(order)
                    ? (_catchWeightFulfilmentComplete(order)
                          ? 'Final products ${_money(_finalisedProductTotal(order))}'
                          : 'Final total pending weight')
                    : 'Total ${_money(order['total_amount'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(_paymentTermsText(order)),
              if (_formatDate(order['submitted_at']).isNotEmpty)
                Text('Submitted ${_formatDate(order['submitted_at'])}'),
            ],
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 12),

          _customerIdentityCard(order),

          if (order['customer_reference'] != null &&
              order['customer_reference'].toString().trim().isNotEmpty)
            _InfoBox(
              title: 'Customer reference',
              value: order['customer_reference'].toString(),
            ),

          if (order['delivery_notes'] != null &&
              order['delivery_notes'].toString().trim().isNotEmpty)
            _InfoBox(
              title: 'Delivery notes',
              value: order['delivery_notes'].toString(),
            ),

          _InfoBox(title: 'Payment terms', value: _paymentTermsText(order)),

          if (_invoiceForOrder(order) != null)
            _InfoBox(
              title: 'Invoice',
              value:
                  '${_invoiceForOrder(order)?['invoice_number'] ?? 'Invoice'} • ${_statusLabel(_invoiceForOrder(order)?['status']?.toString())}',
            ),

          if (status == 'delivered' || status == 'completed')
            _InfoBox(
              title: 'Issue reporting window',
              value:
                  '${_formatNumber(order['issue_reporting_window_hours_snapshot'] ?? 24)} hours from delivery',
            ),

          if (issues.isNotEmpty) ...[
            const SizedBox(height: 4),
            if (issues.any((issue) => !_isIssueClosed(issue))) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Open Issues',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              for (final issue in issues.where(
                (issue) => !_isIssueClosed(issue),
              ))
                _buildIssueCard(order, issue),
            ],
            if (issues.any(_isIssueClosed)) ...[
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Closed Issues',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final issue in issues.where(_isIssueClosed))
                _buildIssueCard(order, issue),
            ],
            const SizedBox(height: 8),
          ],

          for (final item in items)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E4E1)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 680;
                  final catchWeight = _isCatchWeightItem(item);
                  final fulfilmentStatus =
                      item['fulfilment_status']?.toString() ?? 'pending';

                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name_snapshot']?.toString() ??
                            'Unnamed product',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (item['sku_snapshot'] != null &&
                          item['sku_snapshot']
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${item['sku_snapshot']}',
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                      const SizedBox(height: 7),
                      if (catchWeight)
                        Text(
                          '${_formatNumber(item['quantity'])} '
                          '${_unitLabel(item['quantity_unit']?.toString())} ordered'
                          ' at ${_money(item['unit_price'])} / kg',
                          style: const TextStyle(color: Color(0xFF555555)),
                        )
                      else
                        Text(
                          '${_formatNumber(item['quantity'])} '
                          '${_unitLabel(item['quantity_unit']?.toString())}'
                          ' × ${_money(item['unit_price'])}'
                          '${_priceBasisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_priceBasisLabel(item['price_basis']?.toString())}'}',
                          style: const TextStyle(color: Color(0xFF555555)),
                        ),
                      if (catchWeight) ...[
                        const SizedBox(height: 7),
                        if (item['actual_weight'] == null)
                          const Text(
                            'Actual supplied kg and final product total pending.',
                            style: TextStyle(
                              color: Color(0xFF8A5A00),
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else ...[
                          Text(
                            'Supplied: ${_formatNumber(item['supplied_quantity'])} '
                            '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Actual weight: ${_formatNumber(item['actual_weight'])} kg',
                          ),
                        ],
                      ] else if (item['supplied_quantity'] != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          'Supplied: ${_formatNumber(item['supplied_quantity'])} '
                          '${_unitLabel(item['supplied_quantity_unit']?.toString())}',
                        ),
                      ],
                      if (item['notes'] != null &&
                          item['notes'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          'Notes: ${item['notes']}',
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                      if (status == 'accepted' || status == 'processing') ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _editFulfilment(order, item),
                          icon: const Icon(Icons.scale_outlined),
                          label: Text(
                            fulfilmentStatus == 'finalised'
                                ? 'Edit Fulfilment'
                                : 'Enter Fulfilment',
                          ),
                        ),
                      ],
                    ],
                  );

                  final right = catchWeight
                      ? Text(
                          item['final_line_amount'] == null
                              ? 'Final total pending'
                              : _money(item['final_line_amount']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        )
                      : Text(
                          item['final_line_amount'] != null
                              ? _money(item['final_line_amount'])
                              : _money(item['line_subtotal']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [left, const SizedBox(height: 10), right],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 16),
                      right,
                    ],
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _orderHasCatchWeight(order)
                  ? Column(
                      children: [
                        _TotalRow(
                          label: 'Products',
                          value: _catchWeightFulfilmentComplete(order)
                              ? _money(_finalisedProductTotal(order))
                              : 'Pending final weight',
                        ),
                        _TotalRow(
                          label: 'Delivery',
                          value: _asDouble(order['delivery_fee']) == 0
                              ? 'Free'
                              : _money(order['delivery_fee']),
                        ),
                        const Divider(),
                        _TotalRow(
                          label: 'Final order total',
                          value: _catchWeightFulfilmentComplete(order)
                              ? _money(
                                  _finalisedProductTotal(order) +
                                      _asDouble(order['delivery_fee']),
                                )
                              : 'Pending supplier weight',
                          bold: true,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _TotalRow(
                          label: 'Products',
                          value: _money(order['subtotal']),
                        ),
                        _TotalRow(
                          label: 'Delivery',
                          value: _asDouble(order['delivery_fee']) == 0
                              ? 'Free'
                              : _money(order['delivery_fee']),
                        ),
                        const Divider(),
                        _TotalRow(
                          label: 'Order total',
                          value: _money(order['total_amount']),
                          bold: true,
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tax is finalised on the invoice using the supplier-configured tax category and rate.',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          if (status == 'submitted' ||
              status == 'accepted' ||
              status == 'processing' ||
              status == 'dispatched' ||
              status == 'delivered') ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: _actionButtons(order),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssueCard(
    Map<String, dynamic> order,
    Map<String, dynamic> issue,
  ) {
    final status = issue['status']?.toString() ?? 'requested';
    final withinWindow = issue['within_reporting_window'] == true;
    final issueId = issue['id']?.toString();
    final closed = _isIssueClosed(issue);
    final resolutionType = issue['resolution_type']?.toString();
    final replacementOrderId = issue['replacement_order_id']?.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFF5F5F3) : const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: closed ? const Color(0xFFD7D7D2) : const Color(0xFFE4BABA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _issueReasonLabel(issue['issue_reason']?.toString()),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Chip(
                avatar: Icon(
                  closed ? Icons.lock_outline : Icons.circle_outlined,
                  size: 15,
                ),
                label: Text(closed ? 'CLOSED' : 'OPEN'),
                visualDensity: VisualDensity.compact,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: status == 'resolved'
                      ? const Color(0xFFE8F5E9)
                      : status == 'rejected'
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: status == 'resolved'
                        ? const Color(0xFF2E7D32)
                        : status == 'rejected'
                        ? const Color(0xFFB3261E)
                        : const Color(0xFF9A5B00),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                withinWindow ? 'Within reporting window' : 'Reported late',
                style: TextStyle(
                  color: withinWindow
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF9A5B00),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (issue['description'] != null &&
              issue['description'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(issue['description'].toString()),
          ],
          if (_formatDate(issue['reported_at']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reported ${_formatDate(issue['reported_at'])}',
              style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
            ),
          ],
          if (issue['supplier_response'] != null &&
              issue['supplier_response'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Your response: ${issue['supplier_response']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (resolutionType != null) ...[
            const SizedBox(height: 6),
            Text(
              'Resolution: ${_resolutionLabel(resolutionType)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (status == 'resolved') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: issue['butcher_confirmed_at'] != null
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    issue['butcher_confirmed_at'] != null
                        ? Icons.verified_outlined
                        : Icons.hourglass_top_outlined,
                    size: 16,
                    color: issue['butcher_confirmed_at'] != null
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF9A5B00),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    issue['butcher_confirmed_at'] != null
                        ? 'Butcher confirmed resolution'
                        : 'Awaiting butcher confirmation',
                    style: TextStyle(
                      color: issue['butcher_confirmed_at'] != null
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF9A5B00),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_asDouble(issue['credit_amount']) > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Credit: ${_money(issue['credit_amount'])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (issue['pickup_required'] == true) ...[
            const SizedBox(height: 6),
            const Text('Supplier pickup required'),
          ],
          if (issue['replacement_required'] == true) ...[
            const SizedBox(height: 6),
            const Text('Replacement required'),
          ],
          if (_issueMessages(issue).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Conversation',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            for (final message in _issueMessages(issue))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: message['sender_role']?.toString() == 'butcher'
                      ? const Color(0xFFF3F3F1)
                      : const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${message['sender_role']?.toString() == 'butcher' ? 'Butcher' : 'Supplier'}: '
                  '${message['message'] ?? ''}',
                ),
              ),
          ],
          const SizedBox(height: 12),
          if (closed)
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                avatar: const Icon(Icons.task_alt, size: 16),
                label: Text(
                  status == 'rejected'
                      ? 'Rejected and closed'
                      : 'Resolution completed',
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                if (replacementOrderId == null &&
                    resolutionType == 'replacement' &&
                    status != 'rejected')
                  OutlinedButton.icon(
                    onPressed: _updatingIssueId == issueId
                        ? null
                        : () => _createReplacementFulfilment(order, issue),
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Start Replacement Fulfilment'),
                  )
                else if (replacementOrderId != null)
                  const Chip(
                    avatar: Icon(Icons.autorenew, size: 16),
                    label: Text('Replacement fulfilment in progress'),
                  ),
                if (status == 'approved' &&
                    resolutionType != 'replacement' &&
                    replacementOrderId == null)
                  FilledButton.icon(
                    onPressed: _updatingIssueId == issueId
                        ? null
                        : () => _confirmResolutionCompleted(order, issue),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Confirm Resolution Completed'),
                  ),
                OutlinedButton.icon(
                  onPressed: _updatingIssueId == issueId
                      ? null
                      : () => _respondToIssue(order, issue),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text(
                    status == 'approved'
                        ? 'Reply / Update'
                        : 'Reply / Process Issue',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactOrderFact extends StatelessWidget {
  const _CompactOrderFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OrderTabDefinition {
  const _OrderTabDefinition({
    required this.label,
    required this.icon,
    required this.key,
  });

  final String label;
  final IconData icon;
  final String key;
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E1DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(value),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 15,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
