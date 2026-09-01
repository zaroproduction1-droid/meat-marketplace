import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubmittedOrdersPage extends StatefulWidget {
  const SubmittedOrdersPage({super.key});

  @override
  State<SubmittedOrdersPage> createState() => _SubmittedOrdersPageState();
}

class _SubmittedOrdersPageState extends State<SubmittedOrdersPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  String? _butcherBusinessId;
  String? _updatingOrderId;
  String? _reportingIssueOrderId;
  String? _sendingFollowUpIssueId;
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  List<Map<String, dynamic>> _orders = [];

  static const _tabs = <_ButcherOrderTab>[
    _ButcherOrderTab(
      label: 'Pending',
      key: 'pending',
      icon: Icons.schedule_outlined,
    ),
    _ButcherOrderTab(
      label: 'Preparing',
      key: 'preparing',
      icon: Icons.inventory_2_outlined,
    ),
    _ButcherOrderTab(
      label: 'Fulfilment',
      key: 'fulfilment',
      icon: Icons.local_shipping_outlined,
    ),
    _ButcherOrderTab(label: 'Complete', key: 'completed', icon: Icons.task_alt),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchController.addListener(_handleSearchChanged);
    _loadOrders();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
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

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final butcherBusinessId = membership['business_id'] as String;

      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            order_number,
            butcher_business_id,
            supplier_business_id,
            status,
            order_source,
            fulfilment_method,
            order_type,
            replacement_for_order_id,
            replacement_issue_id,
            replacement_for_order_number_snapshot,
            customer_reference,
            delivery_notes,
            delivery_fee,
            delivery_zone_name_snapshot,
            delivery_postcode_snapshot,
            delivery_minimum_order_snapshot,
            delivery_lead_time_days_snapshot,
            delivery_cutoff_time_snapshot,
            pickup_available_snapshot,
            subtotal,
            gst_amount,
            total_amount,
            payment_method_snapshot,
            payment_terms_days_snapshot,
            issue_reporting_window_hours_snapshot,
            requested_fulfilment_date,
            requested_fulfilment_time,
            confirmed_fulfilment_date,
            confirmed_fulfilment_time,
            fulfilment_schedule_confirmed_at,
            ready_for_pickup_at,
            picked_up_at,
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

            businesses!orders_supplier_business_id_fkey(
              legal_name,
              trading_name
            ),

            invoices(
              id,
              invoice_number,
              status,
              total_amount,
              invoice_date,
              due_date,
              sent_to_butcher_at
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
              notes
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
              order_issue_items(
                order_item_id,
                affected_quantity
              ),
              order_issue_messages(
                id,
                sender_business_id,
                sender_role,
                message,
                created_at
              )
            )
          ''')
          .eq('butcher_business_id', butcherBusinessId)
          .neq('status', 'draft')
          .order('updated_at', ascending: false);

      if (!mounted) {
        return;
      }

      final visibleOrders = List<Map<String, dynamic>>.from(response).where((
        order,
      ) {
        final supplierRejected =
            order['status']?.toString() == 'declined' &&
            order['order_source']?.toString() == 'marketplace';

        if (supplierRejected &&
            order['butcher_rejection_acknowledged_at'] != null) {
          return false;
        }

        return true;
      }).toList();

      setState(() {
        _butcherBusinessId = butcherBusinessId;
        _orders = visibleOrders;
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

  String _supplierName(Map<String, dynamic> order) {
    final raw = order['businesses'];

    if (raw is! Map) {
      return 'Unknown supplier';
    }

    final supplier = Map<String, dynamic>.from(raw);

    final tradingName = supplier['trading_name']?.toString();

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName.trim();
    }

    return supplier['legal_name']?.toString() ?? 'Unknown supplier';
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

  bool _hasSupplierUpdate(Map<String, dynamic> issue) {
    final response = issue['supplier_response']?.toString().trim() ?? '';
    final status = issue['status']?.toString();

    return response.isNotEmpty ||
        status == 'approved' ||
        status == 'rejected' ||
        status == 'resolved';
  }

  int _supplierUpdateCount() {
    var count = 0;

    for (final order in _orders) {
      count += _issues(order).where(_hasSupplierUpdate).length;
    }

    return count;
  }

  String _issueStatusLabel(String? status) {
    switch (status) {
      case 'requested':
        return 'Reported';
      case 'reviewing':
        return 'Supplier reviewing';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status?.replaceAll('_', ' ') ?? 'Reported';
    }
  }

  Color _issueStatusBackground(String? status) {
    switch (status) {
      case 'approved':
      case 'resolved':
        return const Color(0xFFE8F5E9);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFFDECEC);
      case 'reviewing':
        return const Color(0xFFFFF4E5);
      case 'requested':
      default:
        return const Color(0xFFEAF1FB);
    }
  }

  Color _issueStatusForeground(String? status) {
    switch (status) {
      case 'approved':
      case 'resolved':
        return const Color(0xFF2E7D32);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFB3261E);
      case 'reviewing':
        return const Color(0xFF9A5B00);
      case 'requested':
      default:
        return const Color(0xFF315A8C);
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
        return value?.replaceAll('_', ' ') ?? 'Not confirmed yet';
    }
  }

  String _issueUpdateDate(Map<String, dynamic> issue) {
    final status = issue['status']?.toString();

    switch (status) {
      case 'resolved':
        return _formatDate(issue['resolved_at']);
      case 'rejected':
        return _formatDate(issue['rejected_at']);
      case 'approved':
        return _formatDate(issue['approved_at']);
      default:
        return _formatDate(issue['reported_at']);
    }
  }

  Widget _buildIssueProgress(Map<String, dynamic> issue) {
    final status = issue['status']?.toString() ?? 'requested';
    final supplierUpdated = _hasSupplierUpdate(issue);

    final stages = <Map<String, dynamic>>[
      {'label': 'Reported', 'complete': true, 'active': status == 'requested'},
      {
        'label': 'Supplier reviewing',
        'complete': supplierUpdated || status == 'reviewing',
        'active': status == 'reviewing',
      },
      {
        'label': status == 'rejected' ? 'Rejected' : 'Resolution arranged',
        'complete':
            status == 'approved' ||
            status == 'rejected' ||
            status == 'resolved',
        'active': status == 'approved' || status == 'rejected',
      },
      {
        'label': 'Resolved',
        'complete': status == 'resolved',
        'active': status == 'resolved',
      },
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final stage in stages)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: stage['complete'] == true
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF1F1EF),
              borderRadius: BorderRadius.circular(999),
              border: stage['active'] == true
                  ? Border.all(
                      color: stage['label'] == 'Rejected'
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF2E7D32),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  stage['complete'] == true
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: stage['complete'] == true
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF666A70),
                ),
                const SizedBox(width: 5),
                Text(
                  stage['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: stage['label'] == 'Rejected'
                        ? const Color(0xFFB3261E)
                        : stage['complete'] == true
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF666A70),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _ordersForTab(String key) {
    switch (key) {
      case 'pending':
        return _orders.where((order) {
          final status = order['status']?.toString();

          // New orders and supplier-declined orders awaiting acknowledgement
          // stay in Pending so the butcher cannot miss the cancellation reason.
          return status == 'submitted' || status == 'declined';
        }).toList();

      case 'preparing':
        return _orders.where((order) {
          final status = order['status']?.toString();
          final hasInvoice = _invoiceForOrder(order) != null;

          return status == 'accepted' ||
              (status == 'processing' && !hasInvoice);
        }).toList();

      case 'fulfilment':
        return _orders.where((order) {
          final status = order['status']?.toString();
          final hasInvoice = _invoiceForOrder(order) != null;

          return status == 'dispatched' ||
              (status == 'processing' && hasInvoice);
        }).toList();

      case 'completed':
        return _orders
            .where((order) => order['status']?.toString() == 'completed')
            .toList();

      case 'issues':
        return _orders.where((order) => _issues(order).isNotEmpty).toList();

      default:
        return const <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _filteredOrdersForTab(String key) {
    final orders = _ordersForTab(key);
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return orders;
    }

    return orders.where((order) {
      final items = _items(order);
      final values = <String>[
        order['order_number']?.toString() ?? '',
        _supplierName(order),
        order['customer_reference']?.toString() ?? '',
        order['delivery_zone_name_snapshot']?.toString() ?? '',
        order['delivery_postcode_snapshot']?.toString() ?? '',
        _buyerLifecycleLabel(order),
        ...items.map((item) => item['product_name_snapshot']?.toString() ?? ''),
        ...items.map((item) => item['sku_snapshot']?.toString() ?? ''),
      ];

      return values.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  int _countForTab(String key) {
    if (key == 'issues') {
      final supplierUpdates = _supplierUpdateCount();

      if (supplierUpdates > 0) {
        return supplierUpdates;
      }

      var openCount = 0;

      for (final order in _orders) {
        openCount += _issues(order).where((issue) {
          final status = issue['status']?.toString();
          return status != 'resolved' &&
              status != 'rejected' &&
              status != 'cancelled';
        }).length;
      }

      return openCount;
    }

    return _ordersForTab(key).length;
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

  Future<void> _acknowledgeSupplierRejection(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty || _updatingOrderId == orderId) {
      return;
    }

    setState(() => _updatingOrderId = orderId);

    try {
      await Supabase.instance.client.rpc(
        'acknowledge_marketplace_order_rejection',
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

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();

    if (orderId == null ||
        orderId.isEmpty ||
        _butcherBusinessId == null ||
        order['status']?.toString() != 'submitted') {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Order?'),
          content: Text(
            'Cancel ${order['order_number'] ?? 'this order'} with ${_supplierName(order)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Order'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8D1B1B),
              ),
              child: const Text('Cancel Order'),
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
          .update({'status': 'cancelled'})
          .eq('id', orderId)
          .eq('butcher_business_id', _butcherBusinessId!)
          .eq('status', 'submitted');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order['order_number'] ?? 'Order'} was cancelled.'),
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

  Map<String, dynamic>? _replacementOrderForIssue(Map<String, dynamic> issue) {
    final replacementId = issue['replacement_order_id']?.toString();

    if (replacementId == null || replacementId.isEmpty) {
      return null;
    }

    for (final order in _orders) {
      if (order['id']?.toString() == replacementId) {
        return order;
      }
    }

    return null;
  }

  bool _isReplacementOrder(Map<String, dynamic> order) {
    return order['order_type']?.toString() == 'replacement';
  }

  Map<String, dynamic>? _activeIssueForOrder(Map<String, dynamic> order) {
    final issues = _issues(order);

    if (issues.isEmpty) {
      return null;
    }

    for (final issue in issues.reversed) {
      final status = issue['status']?.toString();
      if (status != 'resolved' && status != 'cancelled') {
        return issue;
      }
    }

    return issues.last;
  }

  Widget _issueChatBubble(Map<String, dynamic> message) {
    final supplier = message['sender_role']?.toString() == 'supplier';
    final body = message['message']?.toString().trim() ?? '';
    final date = _formatDate(message['created_at']);

    return Align(
      alignment: supplier ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 9),
        child: Column(
          crossAxisAlignment: supplier
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                supplier ? 'Supplier' : 'You',
                style: TextStyle(
                  color: supplier
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
                color: supplier
                    ? const Color(0xFFEAF1FB)
                    : const Color(0xFFF5EAEA),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(supplier ? 3 : 12),
                  bottomRight: Radius.circular(supplier ? 12 : 3),
                ),
                border: Border.all(
                  color: supplier
                      ? const Color(0xFFC6D7EB)
                      : const Color(0xFFD7B8B8),
                ),
              ),
              child: Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF2F2F2F),
                ),
              ),
            ),
            if (date.isNotEmpty) ...[
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  date,
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

  Widget _issueSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE1E1DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EAEA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: const Color(0xFF741C1C)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }

  Future<void> _followUpIssue(
    Map<String, dynamic> order,
    Map<String, dynamic> issue,
  ) async {
    final issueId = issue['id']?.toString();

    if (issueId == null ||
        issueId.isEmpty ||
        _butcherBusinessId == null ||
        _sendingFollowUpIssueId != null) {
      return;
    }

    final controller = TextEditingController();
    bool sending = false;
    bool messageSent = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> send() async {
                if (sending) return;

                final message = controller.text.trim();

                if (message.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a message first.')),
                  );
                  return;
                }

                setDialogState(() => sending = true);

                if (mounted) {
                  setState(() => _sendingFollowUpIssueId = issueId);
                }

                try {
                  await Supabase.instance.client
                      .from('order_issue_messages')
                      .insert({
                        'order_issue_id': issueId,
                        'sender_business_id': _butcherBusinessId,
                        'sender_role': 'butcher',
                        'message': message,
                      });

                  final currentStatus = issue['status']?.toString();

                  if (currentStatus == 'resolved' ||
                      currentStatus == 'rejected') {
                    await Supabase.instance.client
                        .from('order_issues')
                        .update({
                          'status': 'requested',
                          'resolved_at': null,
                          'rejected_at': null,
                        })
                        .eq('id', issueId);
                  }

                  if (!mounted || !dialogContext.mounted) return;

                  messageSent = true;
                  Navigator.of(dialogContext).pop();
                } on PostgrestException catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                    setDialogState(() => sending = false);
                  }
                }
              }

              final messages = _issueMessages(issue);

              return Dialog(
                backgroundColor: const Color(0xFFF7F8FA),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 720,
                  height: 650,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5EAEA),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.forum_outlined,
                                size: 19,
                                color: Color(0xFF741C1C),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _issueReasonLabel(
                                      issue['issue_reason']?.toString(),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${order['order_number'] ?? 'Order'} • ${_supplierName(order)}',
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: sending
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: messages.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 42,
                                      color: Color(0xFFAAAAAA),
                                    ),
                                    SizedBox(height: 9),
                                    Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  8,
                                ),
                                children: [
                                  for (final message in messages)
                                    _issueChatBubble(message),
                                ],
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE0E0DD)),
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                minLines: 1,
                                maxLines: 4,
                                enabled: !sending,
                                decoration: InputDecoration(
                                  hintText: 'Message supplier...',
                                  filled: true,
                                  fillColor: const Color(0xFFFAFAFB),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDADAD6),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDADAD6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 44,
                              child: FilledButton(
                                onPressed: sending ? null : send,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF741C1C),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: sending
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (messageSent && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 150));

        if (!mounted) return;

        await _loadOrders();

        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message sent to supplier.')),
          );
        });
      }
    } finally {
      controller.dispose();

      if (mounted) {
        setState(() => _sendingFollowUpIssueId = null);
      }
    }
  }

  bool _isWithinIssueWindow(Map<String, dynamic> order) {
    final deliveredAt = DateTime.tryParse(
      order['delivered_at']?.toString() ?? '',
    );

    if (deliveredAt == null) {
      return false;
    }

    final rawHours = order['issue_reporting_window_hours_snapshot'];
    final hours = rawHours is num
        ? rawHours.toInt()
        : int.tryParse(rawHours?.toString() ?? '') ?? 24;

    return DateTime.now().toUtc().isBefore(
          deliveredAt.toUtc().add(Duration(hours: hours)),
        ) ||
        DateTime.now().toUtc().isAtSameMomentAs(
          deliveredAt.toUtc().add(Duration(hours: hours)),
        );
  }

  String _issueWindowText(Map<String, dynamic> order) {
    final deliveredAt = DateTime.tryParse(
      order['delivered_at']?.toString() ?? '',
    );

    final rawHours = order['issue_reporting_window_hours_snapshot'];
    final hours = rawHours is num
        ? rawHours.toInt()
        : int.tryParse(rawHours?.toString() ?? '') ?? 24;

    if (deliveredAt == null) {
      return '$hours hour reporting window';
    }

    final deadline = deliveredAt.toUtc().add(Duration(hours: hours)).toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return 'Report within $hours hours of delivery. '
        'Deadline: ${two(deadline.day)}/${two(deadline.month)}/${deadline.year} '
        '${two(deadline.hour)}:${two(deadline.minute)}';
  }

  String _requestedOutcomeLabel(String value) {
    switch (value) {
      case 'replacement_exchange':
        return 'Replacement / exchange';
      case 'supplier_collection':
        return 'Supplier collection';
      case 'account_credit':
        return 'Account credit / credit note';
      case 'discuss_with_supplier':
        return 'Discuss with supplier';
      default:
        return value;
    }
  }

  Future<void> _reportIssue(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();

    if (orderId == null ||
        orderId.isEmpty ||
        _butcherBusinessId == null ||
        _reportingIssueOrderId != null) {
      return;
    }

    final orderStatus = order['status']?.toString();

    if (orderStatus != 'delivered' && orderStatus != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Issues can only be reported after the order has been delivered.',
          ),
        ),
      );
      return;
    }

    final items = _items(order);

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order has no products to report.')),
      );
      return;
    }

    final descriptionController = TextEditingController();
    final selectedItemIds = <String>{};

    String reason = 'quality_issue';
    String requestedOutcome = 'replacement_exchange';
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submitIssue() async {
                if (saving) {
                  return;
                }

                final description = descriptionController.text.trim();

                if (selectedItemIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select at least one affected product.'),
                    ),
                  );
                  return;
                }

                if (description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Describe what is wrong with the order.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                if (mounted) {
                  setState(() {
                    _reportingIssueOrderId = orderId;
                  });
                }

                try {
                  final issueDescription =
                      '$description\n\nRequested outcome: '
                      '${_requestedOutcomeLabel(requestedOutcome)}';

                  final createdIssue = await Supabase.instance.client
                      .from('order_issues')
                      .insert({
                        'order_id': orderId,
                        'status': 'requested',
                        'issue_reason': reason,
                        'description': issueDescription,
                      })
                      .select('id')
                      .single();

                  final issueId = createdIssue['id']?.toString();

                  if (issueId == null || issueId.isEmpty) {
                    throw Exception(
                      'The issue was created but its ID could not be read.',
                    );
                  }

                  await Supabase.instance.client
                      .from('order_issue_items')
                      .insert(
                        selectedItemIds.map((orderItemId) {
                          final selectedItem = items.firstWhere(
                            (item) => item['id']?.toString() == orderItemId,
                          );

                          return {
                            'order_issue_id': issueId,
                            'order_item_id': orderItemId,
                            'affected_quantity': selectedItem['quantity'],
                          };
                        }).toList(),
                      );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Issue reported for '
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
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Unable to report this issue: $error'),
                      ),
                    );

                    setDialogState(() {
                      saving = false;
                    });
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _reportingIssueOrderId = null;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(
                  'Report Issue / Return\n'
                  '${order['order_number'] ?? ''}',
                ),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isWithinIssueWindow(order)
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _issueWindowText(order),
                            style: TextStyle(
                              color: _isWithinIssueWindow(order)
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF9A5B00),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Affected products',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        for (final item in items)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selectedItemIds.contains(
                              item['id']?.toString(),
                            ),
                            title: Text(
                              item['product_name_snapshot']?.toString() ??
                                  'Unnamed product',
                            ),
                            subtitle: Text(
                              '${_formatNumber(item['quantity'])} '
                              '${_unitLabel(item['quantity_unit']?.toString())}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: saving
                                ? null
                                : (selected) {
                                    final itemId = item['id']?.toString();

                                    if (itemId == null || itemId.isEmpty) {
                                      return;
                                    }

                                    setDialogState(() {
                                      if (selected == true) {
                                        selectedItemIds.add(itemId);
                                      } else {
                                        selectedItemIds.remove(itemId);
                                      }
                                    });
                                  },
                          ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: reason,
                          decoration: const InputDecoration(
                            labelText: 'Issue reason',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'wrong_product',
                              child: Text('Wrong product'),
                            ),
                            DropdownMenuItem(
                              value: 'quality_issue',
                              child: Text('Quality issue'),
                            ),
                            DropdownMenuItem(
                              value: 'damaged_product',
                              child: Text('Damaged product'),
                            ),
                            DropdownMenuItem(
                              value: 'missing_product',
                              child: Text('Missing product'),
                            ),
                            DropdownMenuItem(
                              value: 'quantity_issue',
                              child: Text('Quantity issue'),
                            ),
                            DropdownMenuItem(
                              value: 'temperature_issue',
                              child: Text('Temperature issue'),
                            ),
                            DropdownMenuItem(
                              value: 'packaging_issue',
                              child: Text('Packaging issue'),
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
                                      reason = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: requestedOutcome,
                          decoration: const InputDecoration(
                            labelText:
                                'What would you like the supplier to do?',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'replacement_exchange',
                              child: Text('Replacement / exchange'),
                            ),
                            DropdownMenuItem(
                              value: 'supplier_collection',
                              child: Text('Supplier collection'),
                            ),
                            DropdownMenuItem(
                              value: 'account_credit',
                              child: Text('Account credit / credit note'),
                            ),
                            DropdownMenuItem(
                              value: 'discuss_with_supplier',
                              child: Text('Discuss with supplier'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      requestedOutcome = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: descriptionController,
                          minLines: 4,
                          maxLines: 7,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Describe the issue',
                            hintText:
                                'Explain what is wrong, the affected quantity, condition and any important delivery details.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The supplier will review this report and confirm the final resolution. '
                          'Submitting a request does not automatically create a refund or credit.',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            height: 1.4,
                            fontSize: 12,
                          ),
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
                    onPressed: saving ? null : submitIssue,
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
                        : const Icon(Icons.report_problem_outlined),
                    label: Text(saving ? 'Submitting...' : 'Submit Issue'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      descriptionController.dispose();

      if (mounted) {
        setState(() {
          _reportingIssueOrderId = null;
        });
      }
    }
  }

  Widget _buildTimeline(Map<String, dynamic> order) {
    final status = order['status']?.toString();

    const steps = <String>[
      'submitted',
      'accepted',
      'processing',
      'dispatched',
      'delivered',
      'completed',
    ];

    final currentIndex = steps.indexOf(status ?? '');
    final closed = status == 'cancelled' || status == 'declined';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E3DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order progress',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < steps.length; index++)
                _TimelineChip(
                  label: _statusLabel(steps[index]),
                  complete: !closed && currentIndex >= index,
                  active: !closed && currentIndex == index,
                ),
              if (closed)
                _TimelineChip(
                  label: _buyerLifecycleLabel(order),
                  complete: true,
                  active: true,
                  closed: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommercialDetails(Map<String, dynamic> order) {
    final window = order['issue_reporting_window_hours_snapshot'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E3DF)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _InfoBlock(
            label: 'Fulfilment',
            value: order['fulfilment_method']?.toString() == 'delivery'
                ? 'Delivery'
                : 'Pickup',
          ),
          _InfoBlock(label: 'Requested', value: _requestedSchedule(order)),
          _InfoBlock(label: 'Confirmed', value: _confirmedSchedule(order)),
          _InfoBlock(
            label: 'Current status',
            value: _buyerLifecycleLabel(order),
          ),
          _InfoBlock(label: 'Payment terms', value: _paymentTermsText(order)),
          _InfoBlock(
            label: 'Delivery zone',
            value:
                order['delivery_zone_name_snapshot']?.toString() ??
                'Not recorded',
          ),
          _InfoBlock(
            label: 'Delivery postcode',
            value:
                order['delivery_postcode_snapshot']?.toString() ??
                'Not recorded',
          ),
          _InfoBlock(
            label: 'Issue reporting window',
            value: window == null
                ? 'Not recorded'
                : '${_formatNumber(window)} hours',
          ),
        ],
      ),
    );
  }

  Widget _buildIssues(Map<String, dynamic> order) {
    final issues = _issues(order);
    final orderItems = _items(order);

    if (issues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in issues) ...[
          Builder(
            builder: (context) {
              final messages = _issueMessages(issue);
              final supplierUpdated = _hasSupplierUpdate(issue);
              final issueId = issue['id']?.toString();
              final sending =
                  issueId != null && _sendingFollowUpIssueId == issueId;

              final linkedItems = issue['order_issue_items'] is List
                  ? (issue['order_issue_items'] as List)
                        .whereType<Map>()
                        .map((link) => link['order_item_id']?.toString())
                        .whereType<String>()
                        .toSet()
                  : <String>{};

              final affectedNames = orderItems
                  .where((item) => linkedItems.contains(item['id']?.toString()))
                  .map(
                    (item) =>
                        item['product_name_snapshot']?.toString() ??
                        'Unnamed product',
                  )
                  .toList();

              final replacement = _replacementOrderForIssue(issue);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3E5E8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: supplierUpdated
                                ? const Color(0xFFEAF1FB)
                                : const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            supplierUpdated
                                ? Icons.mark_chat_unread_outlined
                                : Icons.report_problem_outlined,
                            size: 20,
                            color: supplierUpdated
                                ? const Color(0xFF315A8C)
                                : const Color(0xFF9A5B00),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                              const SizedBox(height: 3),
                              Text(
                                'Reported ${_formatDate(issue['reported_at'])}',
                                style: const TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 10.5,
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
                            color: _issueStatusBackground(
                              issue['status']?.toString(),
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _issueStatusLabel(issue['status']?.toString()),
                            style: TextStyle(
                              color: _issueStatusForeground(
                                issue['status']?.toString(),
                              ),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildIssueProgress(issue),
                    const SizedBox(height: 10),

                    _issueSectionCard(
                      title: 'Issue Summary',
                      icon: Icons.description_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (affectedNames.isNotEmpty) ...[
                            const Text(
                              'Affected products',
                              style: TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              affectedNames.join(', '),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                          ],
                          if (issue['description']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true) ...[
                            const Text(
                              'Description',
                              style: TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              issue['description'].toString(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),

                    _issueSectionCard(
                      title: 'Conversation',
                      icon: Icons.forum_outlined,
                      trailing: TextButton.icon(
                        onPressed: sending
                            ? null
                            : () => _followUpIssue(order, issue),
                        icon: const Icon(Icons.reply_outlined, size: 16),
                        label: Text(sending ? 'Sending' : 'Reply'),
                      ),
                      child: messages.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No messages yet. Send the supplier a message if you need an update.',
                                style: TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final message in messages)
                                  _issueChatBubble(message),
                              ],
                            ),
                    ),
                    const SizedBox(height: 9),

                    _issueSectionCard(
                      title: 'Resolution',
                      icon: Icons.task_alt_outlined,
                      child: supplierUpdated
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (issue['supplier_response']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true) ...[
                                  Text(
                                    issue['supplier_response'].toString(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Wrap(
                                  spacing: 18,
                                  runSpacing: 10,
                                  children: [
                                    _InfoBlock(
                                      label: 'Resolution',
                                      value: _resolutionLabel(
                                        issue['resolution_type']?.toString(),
                                      ),
                                    ),
                                    if (_asDouble(issue['credit_amount']) > 0)
                                      _InfoBlock(
                                        label: 'Credit',
                                        value:
                                            '${_money(issue['credit_amount'])} inc GST',
                                      ),
                                    _InfoBlock(
                                      label: 'Supplier pickup',
                                      value: issue['pickup_required'] == true
                                          ? 'Required'
                                          : 'Not required',
                                    ),
                                    _InfoBlock(
                                      label: 'Replacement',
                                      value:
                                          issue['replacement_required'] == true
                                          ? 'Required'
                                          : 'Not required',
                                    ),
                                  ],
                                ),
                                if (_issueUpdateDate(issue).isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Updated ${_issueUpdateDate(issue)}',
                                    style: const TextStyle(
                                      color: Color(0xFF777777),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : const Row(
                              children: [
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 17,
                                  color: Color(0xFF9A5B00),
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Waiting for supplier response.',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),

                    if (replacement != null) ...[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB7D7BA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.autorenew,
                              size: 19,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Replacement Order',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${replacement['order_number'] ?? 'Replacement'} • ${_statusLabel(replacement['status']?.toString())}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'No extra charge',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
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

  String _buyerLifecycleLabel(Map<String, dynamic> order) {
    final status = order['status']?.toString();
    final pickup = order['fulfilment_method']?.toString() == 'pickup';
    final hasInvoice = _invoiceForOrder(order) != null;
    final readyForPickup = order['ready_for_pickup_at'] != null;

    if (status == 'submitted') {
      return 'Awaiting Supplier';
    }

    if (status == 'accepted') {
      return 'Preparing';
    }

    if (status == 'processing') {
      if (pickup && readyForPickup) {
        return 'Ready for Pickup';
      }

      if (hasInvoice) {
        return pickup ? 'Invoice Ready' : 'Preparing for Delivery';
      }

      return 'Preparing';
    }

    if (status == 'dispatched') {
      return 'Out for Delivery';
    }

    if (status == 'completed') {
      return pickup ? 'Picked Up / Complete' : 'Delivered / Complete';
    }

    return _statusLabel(status);
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'processing':
        return 'Preparing';
      case 'dispatched':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Complete';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
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

  String _formatFulfilmentSchedule(dynamic dateValue, dynamic timeValue) {
    final rawDate = dateValue?.toString().trim() ?? '';
    final rawTime = timeValue?.toString().trim() ?? '';

    if (rawDate.isEmpty && rawTime.isEmpty) {
      return 'Not specified';
    }

    String dateText = rawDate;
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate != null) {
      final day = parsedDate.day.toString().padLeft(2, '0');
      final month = parsedDate.month.toString().padLeft(2, '0');
      dateText = '$day/$month/${parsedDate.year}';
    }

    String timeText = rawTime;
    if (rawTime.isNotEmpty) {
      final parts = rawTime.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          final hour12 = hour % 12 == 0 ? 12 : hour % 12;
          final period = hour >= 12 ? 'PM' : 'AM';
          timeText = '$hour12:${minute.toString().padLeft(2, '0')} $period';
        }
      }
    }

    if (dateText.isEmpty) return timeText;
    if (timeText.isEmpty) return dateText;
    return '$dateText • $timeText';
  }

  String _requestedSchedule(Map<String, dynamic> order) {
    return _formatFulfilmentSchedule(
      order['requested_fulfilment_date'],
      order['requested_fulfilment_time'],
    );
  }

  String _confirmedSchedule(Map<String, dynamic> order) {
    return _formatFulfilmentSchedule(
      order['confirmed_fulfilment_date'],
      order['confirmed_fulfilment_time'],
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) {
      return '';
    }

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _bestDate(Map<String, dynamic> order) {
    final status = order['status']?.toString();

    if (order['ready_for_pickup_at'] != null && status == 'processing') {
      return _formatDate(order['ready_for_pickup_at']);
    }

    switch (status) {
      case 'completed':
        return _formatDate(order['completed_at']);
      case 'declined':
        return _formatDate(order['declined_at']);
      case 'dispatched':
        return _formatDate(order['dispatched_at']);
      case 'delivered':
        return _formatDate(order['delivered_at']);
      case 'accepted':
      case 'processing':
        return _formatDate(order['accepted_at']);
      case 'cancelled':
        return _formatDate(order['cancelled_at']);
      case 'submitted':
      default:
        return _formatDate(order['submitted_at']);
    }
  }

  Future<void> _openIssuesPanel() async {
    String? selectedOrderId;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (issuesContext) {
          return StatefulBuilder(
            builder: (context, setIssuesState) {
              final issueOrders = _ordersForTab('issues');

              if (selectedOrderId == null && issueOrders.isNotEmpty) {
                selectedOrderId = issueOrders.first['id']?.toString();
              }

              Map<String, dynamic>? selectedOrder;
              for (final order in issueOrders) {
                if (order['id']?.toString() == selectedOrderId) {
                  selectedOrder = order;
                  break;
                }
              }

              Widget queueRow(Map<String, dynamic> order) {
                final selected = order['id']?.toString() == selectedOrderId;
                final openIssues = _issues(order).where((issue) {
                  final status = issue['status']?.toString();
                  return status != 'resolved' &&
                      status != 'rejected' &&
                      status != 'cancelled';
                }).length;

                return Material(
                  color: selected
                      ? const Color(0xFFF5EAEA)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () {
                      setIssuesState(() {
                        selectedOrderId = order['id']?.toString();
                      });
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFC79898)
                              : const Color(0xFFE3E3DF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: openIssues > 0
                                  ? const Color(0xFFFDECEC)
                                  : const Color(0xFFF1F6F1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              openIssues > 0
                                  ? Icons.report_problem_outlined
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: openIssues > 0
                                  ? const Color(0xFFB3261E)
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order['order_number']?.toString() ?? 'Order',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _supplierName(order),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (openIssues > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB3261E),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$openIssues',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              Widget workspace() {
                if (selectedOrder == null) {
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
                          'No issues or returns',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final order = selectedOrder;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3E5E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order['order_number']?.toString() ??
                                        'Order',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _supplierName(order),
                                    style: const TextStyle(
                                      color: Color(0xFF741C1C),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _openOrderWorkspace(order),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open Order'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: _buildIssues(order),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Scaffold(
                backgroundColor: const Color(0xFFF7F8FA),
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  title: const Text(
                    'Issues & Returns',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Center(
                        child: Text(
                          '${_countForTab('issues')} open',
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
                    constraints: const BoxConstraints(maxWidth: 1240),
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
                                color: const Color(0xFFE3E5E8),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(13, 11, 13, 9),
                                  child: Text(
                                    'Orders with Issues',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: issueOrders.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No issues or returns.',
                                            style: TextStyle(
                                              color: Color(0xFF777777),
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.all(8),
                                          itemCount: issueOrders.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 6),
                                          itemBuilder: (_, index) =>
                                              queueRow(issueOrders[index]),
                                        ),
                                ),
                              ],
                            ),
                          );

                          if (narrow) {
                            return ListView(
                              children: [
                                SizedBox(height: 310, child: queue),
                                const SizedBox(height: 10),
                                SizedBox(height: 620, child: workspace()),
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

    if (mounted) {
      await _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF741C1C),
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              'Orders',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: _openIssuesPanel,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF741C1C),
              side: const BorderSide(color: Color(0xFFD9DDE1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
            label: const Text('Issues & Returns'),
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
                preferredSize: const Size.fromHeight(112),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Search order number, supplier, product, SKU or reference',
                            prefixIcon: const Icon(Icons.search, size: 19),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: _searchController.clear,
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFFAFAFB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(
                                color: Color(0xFFDADAD6),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(
                                color: Color(0xFFDADAD6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: const Color(0xFF741C1C),
                        unselectedLabelColor: const Color(0xFF666A70),
                        indicatorColor: const Color(0xFF741C1C),
                        indicatorWeight: 3,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        tabs: [for (final tab in _tabs) _buildTab(tab)],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildTab(_ButcherOrderTab tab) {
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
                color: tab.key == 'pending' || tab.key == 'issues'
                    ? const Color(0xFFB3261E)
                    : const Color(0xFFE9E9E6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tab.key == 'pending' || tab.key == 'issues'
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
                'Orders could not be loaded',
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
      children: [for (final tab in _tabs) _buildTabContent(tab)],
    );
  }

  Widget _buildTabContent(_ButcherOrderTab tab) {
    final orders = _filteredOrdersForTab(tab.key);

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 68, color: const Color(0xFF741C1C)),
              const SizedBox(height: 16),
              Text(
                'No ${tab.label.toLowerCase()} orders',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildOrderCard(orders[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = _items(order);
    final status = order['status']?.toString();
    final statusDate = _bestDate(order);
    final invoice = _invoiceForOrder(order);
    final pickup = order['fulfilment_method']?.toString() == 'pickup';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openOrderWorkspace(order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasOpenIssues(order)
                  ? const Color(0xFFD8A0A0)
                  : const Color(0xFFE3E5E8),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 820;

              final identity = Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _statusBackground(status),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      pickup
                          ? Icons.shopping_bag_outlined
                          : Icons.local_shipping_outlined,
                      color: _statusForeground(status),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                order['order_number']?.toString() ?? 'Order',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_isReplacementOrder(order)) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E9F7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'REPLACEMENT',
                                  style: TextStyle(
                                    color: Color(0xFF6A3D78),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _supplierName(order),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF741C1C),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final facts = Wrap(
                spacing: 20,
                runSpacing: 7,
                children: [
                  _CompactBuyerOrderFact(
                    label: 'STATUS',
                    value: _buyerLifecycleLabel(order),
                  ),
                  _CompactBuyerOrderFact(
                    label: 'ITEMS',
                    value:
                        '${items.length} line${items.length == 1 ? '' : 's'}',
                  ),
                  _CompactBuyerOrderFact(
                    label: 'FULFILMENT',
                    value: pickup ? 'Pickup' : 'Delivery',
                  ),
                  _CompactBuyerOrderFact(
                    label: 'REQUESTED',
                    value: _requestedSchedule(order),
                  ),
                  if (order['confirmed_fulfilment_date'] != null ||
                      order['confirmed_fulfilment_time'] != null)
                    _CompactBuyerOrderFact(
                      label: 'CONFIRMED',
                      value: _confirmedSchedule(order),
                    ),
                  if (statusDate.isNotEmpty)
                    _CompactBuyerOrderFact(label: 'UPDATED', value: statusDate),
                ],
              );

              final totalText = invoice?['total_amount'] != null
                  ? _money(invoice?['total_amount'])
                  : _money(order['total_amount']);

              final trailing = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_issues(order).any(_hasSupplierUpdate))
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.mark_chat_unread_outlined,
                        color: Color(0xFF315A8C),
                        size: 19,
                      ),
                    )
                  else if (_hasOpenIssues(order))
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.report_problem_outlined,
                        color: Color(0xFFB3261E),
                        size: 19,
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL INC GST',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
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
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right, color: Color(0xFF741C1C)),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 10),
                    facts,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: trailing),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 290, child: identity),
                  const SizedBox(width: 18),
                  Expanded(child: facts),
                  const SizedBox(width: 14),
                  trailing,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openOrderWorkspace(Map<String, dynamic> order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => _buildOrderWorkspace(order)),
    );

    if (!mounted) {
      return;
    }

    await _loadOrders();
  }

  Widget _buildOrderWorkspace(Map<String, dynamic> order) {
    final items = _items(order);
    final status = order['status']?.toString();
    final orderId = order['id']?.toString();
    final pickup = order['fulfilment_method']?.toString() == 'pickup';

    Widget productsPanel() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E5E8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 9,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 19,
                    color: Color(0xFF741C1C),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Order Items',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} line${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (_, index) {
                  final item = items[index];

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE3E5E8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['product_name_snapshot']?.toString() ??
                                    'Unnamed product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (item['sku_snapshot']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'SKU ${item['sku_snapshot']}',
                                  style: const TextStyle(
                                    color: Color(0xFF777777),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${_formatNumber(item['quantity'])} '
                                '${_unitLabel(item['quantity_unit']?.toString())}'
                                ' × ${_money(item['unit_price'])}'
                                '${_priceBasisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_priceBasisLabel(item['price_basis']?.toString())}'} inc GST',
                                style: const TextStyle(
                                  color: Color(0xFF555555),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_money(item['line_subtotal'])} inc GST',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    Widget controlPanel() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E5E8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 9,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ListView(
          children: [
            _buildTimeline(order),
            _buildCommercialDetails(order),

            if (status == 'declined' &&
                order['order_source']?.toString() == 'marketplace') ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE7B7B3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cancelled by supplier',
                      style: TextStyle(
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order['supplier_rejection_reason']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true
                          ? order['supplier_rejection_reason'].toString()
                          : 'The supplier was unable to accept this order.',
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _updatingOrderId == orderId
                            ? null
                            : () async {
                                await _acknowledgeSupplierRejection(order);
                                if (!mounted) {
                                  return;
                                }
                                Navigator.of(context).pop();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF741C1C),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('OK, Remove Order'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            _buildIssues(order),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 9),

            _TotalRow(
              label: 'Products (inc GST)',
              value: _money(order['subtotal']),
            ),
            _TotalRow(
              label: 'Delivery (inc GST)',
              value: _asDouble(order['delivery_fee']) == 0
                  ? 'Free'
                  : _money(order['delivery_fee']),
            ),
            const Divider(height: 16),
            _TotalRow(
              label: 'Total inc GST',
              value: _money(order['total_amount']),
              bold: true,
            ),
            _TotalRow(
              label: 'GST included',
              value: _money(order['gst_amount']),
            ),

            if (status == 'submitted') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _updatingOrderId == orderId
                    ? null
                    : () async {
                        await _cancelOrder(order);
                        if (!mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Order'),
              ),
            ],

            if ((status == 'delivered' || status == 'completed') &&
                !_isReplacementOrder(order)) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final existingIssue = _activeIssueForOrder(order);
                  final followingUp =
                      existingIssue != null &&
                      _sendingFollowUpIssueId ==
                          existingIssue['id']?.toString();

                  return FilledButton.icon(
                    onPressed: existingIssue == null
                        ? (_reportingIssueOrderId == orderId
                              ? null
                              : () => _reportIssue(order))
                        : (followingUp
                              ? null
                              : () => _followUpIssue(order, existingIssue)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF741C1C),
                    ),
                    icon: Icon(
                      existingIssue == null
                          ? Icons.report_problem_outlined
                          : Icons.forum_outlined,
                    ),
                    label: Text(
                      existingIssue == null
                          ? (_isWithinIssueWindow(order)
                                ? 'Report Issue / Return'
                                : 'Contact Supplier About Issue')
                          : 'Follow Up Issue',
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          order['order_number']?.toString() ?? 'Order',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 920;

          final header = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3E5E8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _supplierName(order),
                        style: const TextStyle(
                          color: Color(0xFF741C1C),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pickup ? 'Pickup order' : 'Delivery order',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 11.5,
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
                    color: _statusBackground(status),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _buyerLifecycleLabel(order),
                    style: TextStyle(
                      color: _statusForeground(status),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (!desktop) {
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                header,
                const SizedBox(height: 10),
                SizedBox(height: 430, child: productsPanel()),
                const SizedBox(height: 10),
                SizedBox(height: 650, child: controlPanel()),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: productsPanel()),
                          const SizedBox(width: 12),
                          SizedBox(width: 365, child: controlPanel()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompactBuyerOrderFact extends StatelessWidget {
  const _CompactBuyerOrderFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ButcherOrderTab {
  const _ButcherOrderTab({
    required this.label,
    required this.key,
    required this.icon,
  });

  final String label;
  final String key;
  final IconData icon;
}

class _TimelineChip extends StatelessWidget {
  const _TimelineChip({
    required this.label,
    required this.complete,
    required this.active,
    this.closed = false,
  });

  final String label;
  final bool complete;
  final bool active;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final background = closed
        ? const Color(0xFFFDECEC)
        : complete
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFF1F1EF);

    final foreground = closed
        ? const Color(0xFFB3261E)
        : complete
        ? const Color(0xFF2E7D32)
        : const Color(0xFF666A70);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: active ? Border.all(color: foreground, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
