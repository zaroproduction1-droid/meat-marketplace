import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_create_order_page.dart';
import 'supplier_invoice_page.dart';
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
      label: 'Quotes',
      icon: Icons.description_outlined,
      key: 'quotes',
    ),
    _OrderTabDefinition(
      label: 'New',
      icon: Icons.notifications_none,
      key: 'new',
    ),
    _OrderTabDefinition(
      label: 'Accepted',
      icon: Icons.check_circle_outline,
      key: 'accepted',
    ),
    _OrderTabDefinition(
      label: 'Processing',
      icon: Icons.inventory_2_outlined,
      key: 'processing',
    ),
    _OrderTabDefinition(
      label: 'Dispatched',
      icon: Icons.local_shipping_outlined,
      key: 'dispatched',
    ),
    _OrderTabDefinition(
      label: 'Delivered',
      icon: Icons.move_to_inbox_outlined,
      key: 'delivered',
    ),
    _OrderTabDefinition(
      label: 'Issues',
      icon: Icons.report_problem_outlined,
      key: 'issues',
    ),
    _OrderTabDefinition(
      label: 'Completed',
      icon: Icons.task_alt,
      key: 'completed',
    ),
    _OrderTabDefinition(
      label: 'Closed',
      icon: Icons.archive_outlined,
      key: 'closed',
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
            dispatched_at,
            delivered_at,
            completed_at,
            cancelled_at,
            created_at,
            updated_at,

            businesses!orders_butcher_business_id_fkey(
              legal_name,
              trading_name
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
    switch (key) {
      case 'quotes':
        return _orders.where((order) {
          final source = order['order_source']?.toString();
          return order['status']?.toString() == 'draft' &&
              order['supplier_customer_account_id'] != null &&
              order['created_by_business_id']?.toString() ==
                  _supplierBusinessId &&
              const {'phone', 'email', 'sales_rep', 'manual'}.contains(source);
        }).toList();

      case 'new':
        return _orders
            .where((order) => order['status']?.toString() == 'submitted')
            .toList();

      case 'accepted':
        return _orders
            .where((order) => order['status']?.toString() == 'accepted')
            .toList();

      case 'processing':
        return _orders
            .where((order) => order['status']?.toString() == 'processing')
            .toList();

      case 'dispatched':
        return _orders
            .where((order) => order['status']?.toString() == 'dispatched')
            .toList();

      case 'delivered':
        return _orders
            .where((order) => order['status']?.toString() == 'delivered')
            .toList();

      case 'issues':
        return _orders.where((order) => _issues(order).isNotEmpty).toList();

      case 'completed':
        return _orders
            .where((order) => order['status']?.toString() == 'completed')
            .toList();

      case 'closed':
        return _orders.where((order) {
          final status = order['status']?.toString();
          return status == 'declined' || status == 'cancelled';
        }).toList();

      default:
        return [];
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

  String _customerName(Map<String, dynamic> order) {
    final rawBusiness = order['businesses'];

    if (rawBusiness is Map) {
      final customer = Map<String, dynamic>.from(rawBusiness);

      final tradingName = customer['trading_name']?.toString();

      if (tradingName != null && tradingName.trim().isNotEmpty) {
        return tradingName.trim();
      }

      final legalName = customer['legal_name']?.toString();

      if (legalName != null && legalName.trim().isNotEmpty) {
        return legalName.trim();
      }
    }

    final rawAccount = order['supplier_customer_accounts'];

    if (rawAccount is Map) {
      final account = Map<String, dynamic>.from(rawAccount);

      final customerName = account['customer_name']?.toString();

      if (customerName != null && customerName.trim().isNotEmpty) {
        return customerName.trim();
      }

      final legalName = account['legal_name']?.toString();

      if (legalName != null && legalName.trim().isNotEmpty) {
        return legalName.trim();
      }
    }

    return 'Unknown customer';
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

  bool _allFulfilmentComplete(Map<String, dynamic> order) {
    final items = _items(order);

    if (items.isEmpty) {
      return false;
    }

    return items.every(
      (item) => item['fulfilment_status']?.toString() == 'finalised',
    );
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

  bool _invoiceIssued(Map<String, dynamic> order) {
    return _invoiceForOrder(order)?['status']?.toString() == 'issued';
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
      case 'draft':
        return 'Quote';

      case 'submitted':
        return 'New order';
      case 'accepted':
        return 'Accepted';
      case 'processing':
        return 'Processing';
      case 'dispatched':
        return 'Dispatched';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
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

      await Supabase.instance.client.from('order_issue_messages').insert({
        'order_issue_id': issueId,
        'sender_business_id': supplierBusinessId,
        'sender_role': 'supplier',
        'message':
            'Resolution completed and issue closed. Resolution: $resolution.',
      });

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

      if (mounted) {
        _tabController.animateTo(5);
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

    final responseController = TextEditingController(
      text: issue['supplier_response']?.toString() ?? '',
    );
    final creditController = TextEditingController(
      text: issue['credit_amount']?.toString() ?? '',
    );

    String action = 'approve';
    String resolutionType =
        issue['resolution_type']?.toString() ?? 'replacement';
    bool pickupRequired = issue['pickup_required'] == true;
    bool replacementRequired = issue['replacement_required'] == true;
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

                final response = responseController.text.trim();
                final creditText = creditController.text.trim();
                final credit = creditText.isEmpty
                    ? null
                    : double.tryParse(creditText);

                if (response.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a response for the butcher.'),
                    ),
                  );
                  return;
                }

                if (creditText.isNotEmpty && (credit == null || credit < 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid credit amount.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                if (mounted) {
                  setState(() {
                    _updatingIssueId = issueId;
                  });
                }

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
                  } else if (action == 'reject') {
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

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Issue updated for '
                        '${order['order_number'] ?? 'this order'}.',
                      ),
                    ),
                  );

                  await _loadOrders();

                  if (mounted) {
                    _tabController.animateTo(5);
                  }
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
                      _updatingIssueId = null;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(
                  'Process Issue\n'
                  '${order['order_number'] ?? ''}',
                ),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _issueReasonLabel(issue['issue_reason']?.toString()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (issue['description'] != null &&
                            issue['description']
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(issue['description'].toString()),
                        ],
                        if (_issueMessages(issue).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Conversation',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          for (final message in _issueMessages(issue))
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    message['sender_role']?.toString() ==
                                        'butcher'
                                    ? const Color(0xFFF3F3F1)
                                    : const Color(0xFFEAF1FB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${message['sender_role']?.toString() == 'butcher' ? 'Butcher' : 'You'}: '
                                '${message['message'] ?? ''}',
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: action,
                          decoration: const InputDecoration(
                            labelText: 'Action',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'approve',
                              child: Text('Approve issue'),
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
                                    setDialogState(() {
                                      action = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: resolutionType,
                          decoration: const InputDecoration(
                            labelText: 'Resolution',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'replacement',
                              child: Text('Replacement / exchange'),
                            ),
                            DropdownMenuItem(
                              value: 'credit',
                              child: Text('Account credit / credit note'),
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
                                    setDialogState(() {
                                      resolutionType = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: responseController,
                          minLines: 3,
                          maxLines: 6,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Reply / update to butcher',
                            hintText:
                                'Reply to the existing issue. Explain what happens next, including any collection, replacement or credit details.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: creditController,
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Credit amount (optional)',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: pickupRequired,
                          title: const Text('Supplier pickup required'),
                          onChanged: saving
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    pickupRequired = value;
                                  });
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: replacementRequired,
                          title: const Text('Replacement required'),
                          onChanged: saving
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    replacementRequired = value;
                                  });
                                },
                        ),
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
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving...' : 'Save Issue Update'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      responseController.dispose();
      creditController.dispose();

      if (mounted) {
        setState(() {
          _updatingIssueId = null;
        });
      }
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

  Future<void> _changeStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty || _supplierBusinessId == null) {
      return;
    }

    final currentStatus = order['status']?.toString();

    String action;
    String buttonLabel;

    switch (newStatus) {
      case 'accepted':
        action = 'accept';
        buttonLabel = 'Accept Order';
        break;
      case 'declined':
        action = 'decline';
        buttonLabel = 'Decline Order';
        break;
      case 'processing':
        action = 'start processing';
        buttonLabel = 'Start Processing';
        break;
      case 'dispatched':
        action = 'mark as dispatched';
        buttonLabel = 'Mark Dispatched';
        break;
      case 'delivered':
        action = 'mark as delivered';
        buttonLabel = 'Mark Delivered';
        break;
      case 'completed':
        action = 'complete';
        buttonLabel = 'Mark Completed';
        break;
      default:
        action = 'update';
        buttonLabel = 'Update Order';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(buttonLabel),
          content: Text(
            'Are you sure you want to $action '
            '${order['order_number'] ?? 'this order'} from '
            '${_customerName(order)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: newStatus == 'declined'
                    ? const Color(0xFF8D1B1B)
                    : const Color(0xFF741C1C),
              ),
              child: Text(buttonLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _updatingOrderId = orderId;
    });

    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId)
          .eq('supplier_business_id', _supplierBusinessId!)
          .eq('status', currentStatus!);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${order['order_number'] ?? 'Order'} is now '
            '${_statusLabel(newStatus).toLowerCase()}.',
          ),
        ),
      );

      await _loadOrders();
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
          _updatingOrderId = null;
        });
      }
    }
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
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierInvoicePage(orderId: orderId),
      ),
    );

    if (mounted) {
      await _loadOrders();
    }
  }

  Future<void> _convertQuoteToSalesOrder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Convert Quote to Sales Order?'),
        content: Text(
          'Convert ${order['order_number'] ?? 'this quote'} to an Accepted sales order?\n\n'
          'After conversion it can move to Work Order, fulfilment and invoicing.',
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
            child: const Text('Convert to Sales Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _updatingOrderId = orderId);

    try {
      await Supabase.instance.client.rpc(
        'convert_supplier_quote_to_sales_order',
        params: {'target_order_id': orderId},
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote converted to sales order.')),
      );

      await _loadOrders();

      if (mounted) {
        _tabController.animateTo(2);
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
        setState(() => _updatingOrderId = null);
      }
    }
  }

  Widget _actionButtons(Map<String, dynamic> order) {
    final status = order['status']?.toString();
    final orderId = order['id']?.toString();

    if (_updatingOrderId == orderId) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status) {
      case 'draft':
        return FilledButton.icon(
          onPressed: () => _convertQuoteToSalesOrder(order),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          icon: const Icon(Icons.arrow_forward_outlined),
          label: const Text('Convert to Sales Order'),
        );

      case 'submitted':
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _changeStatus(order, 'accepted'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Accept Order'),
            ),
            OutlinedButton.icon(
              onPressed: () => _changeStatus(order, 'declined'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Decline'),
            ),
          ],
        );

      case 'accepted':
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openWorkOrder(order),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Work Order'),
            ),
            FilledButton.icon(
              onPressed: () => _changeStatus(order, 'processing'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Start Processing'),
            ),
          ],
        );

      case 'processing':
        final fulfilmentComplete = _allFulfilmentComplete(order);
        final invoice = _invoiceForOrder(order);
        final invoiceIssued = _invoiceIssued(order);

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openWorkOrder(order),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Work Order'),
            ),
            OutlinedButton.icon(
              onPressed: fulfilmentComplete ? () => _openInvoice(order) : null,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(
                invoice == null
                    ? 'Create Invoice'
                    : 'Invoice ${invoice['invoice_number'] ?? ''}'.trim(),
              ),
            ),
            FilledButton.icon(
              onPressed: invoiceIssued
                  ? () => _changeStatus(order, 'dispatched')
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF741C1C),
              ),
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(
                !fulfilmentComplete
                    ? 'Finalise Fulfilment First'
                    : invoice == null
                    ? 'Create Invoice First'
                    : !invoiceIssued
                    ? 'Issue Invoice First'
                    : 'Mark Dispatched',
              ),
            ),
          ],
        );

      case 'dispatched':
        return FilledButton.icon(
          onPressed: () => _changeStatus(order, 'delivered'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          icon: const Icon(Icons.move_to_inbox_outlined),
          label: const Text('Mark Delivered'),
        );

      case 'delivered':
        return FilledButton.icon(
          onPressed: _hasOpenIssues(order)
              ? null
              : () => _changeStatus(order, 'completed'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          icon: const Icon(Icons.task_alt),
          label: Text(
            _hasOpenIssues(order) ? 'Resolve Issues First' : 'Mark Completed',
          ),
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
          'Customer Orders',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
                    final createdOrderId = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SupplierCreateOrderPage(),
                      ),
                    );

                    if (!mounted || createdOrderId == null) {
                      return;
                    }

                    await _loadOrders();

                    if (mounted) {
                      _tabController.animateTo(1);
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF741C1C),
            ),
            icon: const Icon(Icons.add),
            label: const Text('New Quote / Sale'),
          ),
          const SizedBox(width: 8),
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
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: orders.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 16);
            },
            itemBuilder: (context, index) {
              return _buildOrderCard(orders[index]);
            },
          ),
        ),
      ),
    );
  }

  String _emptyTitle(String key) {
    switch (key) {
      case 'new':
        return 'No new orders';
      case 'accepted':
        return 'No accepted orders';
      case 'processing':
        return 'Nothing processing';
      case 'dispatched':
        return 'Nothing dispatched';
      case 'delivered':
        return 'No delivered orders';
      case 'issues':
        return 'No open issues';
      case 'completed':
        return 'No completed orders';
      case 'closed':
        return 'No closed orders';
      default:
        return 'No orders';
    }
  }

  String _emptyDescription(String key) {
    switch (key) {
      case 'quotes':
        return 'Saved supplier quotes will appear here until they are converted to sales orders.';
      case 'new':
        return 'New orders submitted by butchers will appear here.';
      case 'accepted':
        return 'Orders you accept will move into this tab.';
      case 'processing':
        return 'Orders currently being prepared will appear here.';
      case 'dispatched':
        return 'Orders marked as dispatched will appear here.';
      case 'delivered':
        return 'Delivered orders remain here until they are completed.';
      case 'issues':
        return 'Reported quality, return, exchange or order issues will appear here.';
      case 'completed':
        return 'Completed orders will be stored here.';
      case 'closed':
        return 'Declined and cancelled orders will be stored here.';
      default:
        return '';
    }
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        initiallyExpanded: status == 'submitted',
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
