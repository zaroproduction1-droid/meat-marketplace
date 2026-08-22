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

  late final TabController _tabController;

  List<Map<String, dynamic>> _orders = [];

  static const _tabs = <_ButcherOrderTab>[
    _ButcherOrderTab(
      label: 'Pending',
      key: 'pending',
      icon: Icons.schedule_outlined,
    ),
    _ButcherOrderTab(
      label: 'Accepted',
      key: 'accepted',
      icon: Icons.check_circle_outline,
    ),
    _ButcherOrderTab(
      label: 'Processing',
      key: 'processing',
      icon: Icons.inventory_2_outlined,
    ),
    _ButcherOrderTab(
      label: 'Dispatched',
      key: 'dispatched',
      icon: Icons.local_shipping_outlined,
    ),
    _ButcherOrderTab(
      label: 'Delivered',
      key: 'delivered',
      icon: Icons.move_to_inbox_outlined,
    ),
    _ButcherOrderTab(
      label: 'Issues & Returns',
      key: 'issues',
      icon: Icons.report_problem_outlined,
    ),
    _ButcherOrderTab(
      label: 'Completed',
      key: 'completed',
      icon: Icons.task_alt,
    ),
    _ButcherOrderTab(
      label: 'Closed',
      key: 'closed',
      icon: Icons.archive_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
            submitted_at,
            accepted_at,
            declined_at,
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

            order_issues(
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

      setState(() {
        _butcherBusinessId = butcherBusinessId;
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
                      : const Color(0xFF777777),
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
                        : const Color(0xFF666666),
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

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> send() async {
                if (sending) {
                  return;
                }

                final message = controller.text.trim();

                if (message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter your follow-up message.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  sending = true;
                });

                if (mounted) {
                  setState(() {
                    _sendingFollowUpIssueId = issueId;
                  });
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

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Follow-up sent to the supplier.'),
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
                      sending = false;
                    });
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _sendingFollowUpIssueId = null;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(
                  'Follow Up Issue\n'
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
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_issueMessages(issue).isNotEmpty) ...[
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
                                        'supplier'
                                    ? const Color(0xFFEAF1FB)
                                    : const Color(0xFFF3F3F1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['sender_role']?.toString() ==
                                            'supplier'
                                        ? 'Supplier'
                                        : 'You',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(message['message']?.toString() ?? ''),
                                  if (_formatDate(
                                    message['created_at'],
                                  ).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(message['created_at']),
                                      style: const TextStyle(
                                        color: Color(0xFF777777),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                        TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: 6,
                          enabled: !sending,
                          decoration: const InputDecoration(
                            labelText: 'Follow-up message',
                            hintText:
                                'Ask for an update or add more information to the existing issue.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                  FilledButton.icon(
                    onPressed: sending ? null : send,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF741C1C),
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(sending ? 'Sending...' : 'Send Follow Up'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();

      if (mounted) {
        setState(() {
          _sendingFollowUpIssueId = null;
        });
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
        color: const Color(0xFFF8F8F6),
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
                  label: _statusLabel(status),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Issues & Returns',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            if (issues.any(_hasSupplierUpdate))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 15,
                      color: Color(0xFF315A8C),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Supplier update',
                      style: TextStyle(
                        color: Color(0xFF315A8C),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final issue in issues)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hasSupplierUpdate(issue)
                  ? const Color(0xFFF7FAFF)
                  : const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasSupplierUpdate(issue)
                    ? const Color(0xFFB8CDE8)
                    : const Color(0xFFE5D19A),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
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
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_hasSupplierUpdate(issue))
                      const Chip(
                        avatar: Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                        ),
                        label: Text('Supplier replied'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildIssueProgress(issue),

                if (issue['order_issue_items'] is List) ...[
                  Builder(
                    builder: (context) {
                      final links = (issue['order_issue_items'] as List)
                          .whereType<Map>()
                          .map((link) => link['order_item_id']?.toString())
                          .whereType<String>()
                          .toSet();

                      final names = orderItems
                          .where(
                            (item) => links.contains(item['id']?.toString()),
                          )
                          .map(
                            (item) =>
                                item['product_name_snapshot']?.toString() ??
                                'Unnamed product',
                          )
                          .toList();

                      if (names.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Affected: ${names.join(', ')}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                  ),
                ],

                if (issue['description'] != null &&
                    issue['description'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(issue['description'].toString()),
                ],

                if (_issueMessages(issue).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Conversation',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final message in _issueMessages(issue))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: message['sender_role']?.toString() == 'supplier'
                            ? const Color(0xFFEAF1FB)
                            : const Color(0xFFF3F3F1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${message['sender_role']?.toString() == 'supplier' ? 'Supplier' : 'Butcher'}: '
                        '${message['message'] ?? ''}',
                      ),
                    ),
                ],

                if (_replacementOrderForIssue(issue) != null) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final replacement = _replacementOrderForIssue(issue)!;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB7D7BA)),
                        ),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Chip(
                              avatar: Icon(Icons.autorenew, size: 16),
                              label: Text('REPLACEMENT ORDER'),
                            ),
                            Text(
                              replacement['order_number']?.toString() ??
                                  'Replacement',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Status: ${_statusLabel(replacement['status']?.toString())}',
                            ),
                            const Text(
                              'No extra charge',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                if (_hasSupplierUpdate(issue)) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD9E3F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supplier response',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF315A8C),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          issue['supplier_response']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? issue['supplier_response'].toString()
                              : 'The supplier has updated the status of this issue.',
                        ),
                        const SizedBox(height: 12),
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
                              value: issue['replacement_required'] == true
                                  ? 'Required'
                                  : 'Not required',
                            ),
                          ],
                        ),
                        if (_issueUpdateDate(issue).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Updated ${_issueUpdateDate(issue)}',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Waiting for supplier response.',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
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

  double _exGstAmount(Map<String, dynamic> order) {
    final total = _asDouble(order['total_amount']);
    return total / 1.10;
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
        return 'Submitted';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'processing':
        return 'Processing';
      case 'dispatched':
        return 'Dispatched';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'CutLink Orders',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
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
    final orders = _ordersForTab(tab.key);

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
          constraints: const BoxConstraints(maxWidth: 1150),
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
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
    final orderId = order['id']?.toString();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
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
                    _supplierName(order),
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
                          label: Text('REPLACEMENT'),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (order['replacement_for_order_number_snapshot'] !=
                            null)
                          Text(
                            'For ${order['replacement_for_order_number_snapshot']}',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
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
                'Total ${_money(order['total_amount'])} inc GST',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (statusDate.isNotEmpty) Text(statusDate),
              if (_issues(order).any(_hasSupplierUpdate))
                const Text(
                  'Supplier updated issue',
                  style: TextStyle(
                    color: Color(0xFF315A8C),
                    fontWeight: FontWeight.w800,
                  ),
                )
              else if (_hasOpenIssues(order))
                const Text(
                  'Issue open',
                  style: TextStyle(
                    color: Color(0xFFB3261E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 12),

          _buildTimeline(order),
          _buildCommercialDetails(order),

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
                  final narrow = constraints.maxWidth < 620;

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
                      Text(
                        '${_formatNumber(item['quantity'])} '
                        '${_unitLabel(item['quantity_unit']?.toString())}'
                        ' × ${_money(item['unit_price'])}'
                        '${_priceBasisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_priceBasisLabel(item['price_basis']?.toString())}'} inc GST',
                        style: const TextStyle(color: Color(0xFF555555)),
                      ),
                    ],
                  );

                  final right = Text(
                    '${_money(item['line_subtotal'])} inc GST',
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

          _buildIssues(order),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
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
                  const Divider(),
                  _TotalRow(
                    label: 'Total inc GST',
                    value: _money(order['total_amount']),
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  _TotalRow(
                    label: 'Total ex GST',
                    value: _money(_exGstAmount(order)),
                  ),
                  _TotalRow(
                    label: 'GST included',
                    value: _money(order['gst_amount']),
                  ),
                ],
              ),
            ),
          ),

          if (status == 'submitted') ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _updatingOrderId == orderId
                    ? null
                    : () => _cancelOrder(order),
                icon: _updatingOrderId == orderId
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Order'),
              ),
            ),
          ],

          if ((status == 'delivered' || status == 'completed') &&
              !_isReplacementOrder(order)) ...[
            const SizedBox(height: 18),
            Builder(
              builder: (context) {
                final existingIssue = _activeIssueForOrder(order);
                final followingUp =
                    existingIssue != null &&
                    _sendingFollowUpIssueId == existingIssue['id']?.toString();

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: existingIssue == null
                        ? (_isWithinIssueWindow(order)
                              ? const Color(0xFFF7F7F5)
                              : const Color(0xFFFFF4E5))
                        : const Color(0xFFEAF1FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: existingIssue == null
                          ? (_isWithinIssueWindow(order)
                                ? const Color(0xFFE0E0E0)
                                : const Color(0xFFE5C37A))
                          : const Color(0xFFB8CDE8),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final message = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existingIssue == null
                                ? 'Problem with this delivery?'
                                : 'Existing issue lodged',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            existingIssue == null
                                ? _issueWindowText(order)
                                : 'Continue the existing complaint instead of creating another request.',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              height: 1.4,
                            ),
                          ),
                        ],
                      );

                      final button = FilledButton.icon(
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
                              ? 'Report Issue / Return'
                              : 'Follow Up Issue',
                        ),
                      );

                      if (constraints.maxWidth < 700) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            message,
                            const SizedBox(height: 12),
                            button,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: message),
                          const SizedBox(width: 16),
                          button,
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ],
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
        : const Color(0xFF777777);

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
