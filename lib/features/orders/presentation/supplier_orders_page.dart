import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierOrdersPage extends StatefulWidget {
  const SupplierOrdersPage({super.key});

  @override
  State<SupplierOrdersPage> createState() => _SupplierOrdersPageState();
}

class _SupplierOrdersPageState extends State<SupplierOrdersPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  String? _supplierBusinessId;
  String? _updatingOrderId;

  late final TabController _tabController;

  List<Map<String, dynamic>> _orders = [];

  static const _tabs = <_OrderTabDefinition>[
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
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
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

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final supplierBusinessId = membership['business_id'] as String;

      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            order_number,
            butcher_business_id,
            supplier_business_id,
            status,
            customer_reference,
            delivery_notes,
            internal_notes,
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
              resolved_at
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .neq('status', 'draft')
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
        return _orders.where(_hasOpenIssues).toList();

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
    final raw = order['businesses'];

    if (raw is! Map) {
      return 'Unknown customer';
    }

    final customer = Map<String, dynamic>.from(raw);

    final tradingName = customer['trading_name']?.toString();

    if (tradingName != null && tradingName.trim().isNotEmpty) {
      return tradingName.trim();
    }

    return customer['legal_name']?.toString() ?? 'Unknown customer';
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
          .update({
            'status': newStatus,
          })
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderId = null;
        });
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
        return FilledButton.icon(
          onPressed: () => _changeStatus(order, 'processing'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Start Processing'),
        );

      case 'processing':
        return FilledButton.icon(
          onPressed: () => _changeStatus(order, 'dispatched'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF741C1C),
          ),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Mark Dispatched'),
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
            _hasOpenIssues(order)
                ? 'Resolve Issues First'
                : 'Mark Completed',
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
                    tabs: [
                      for (final tab in _tabs)
                        _buildTab(tab),
                    ],
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
              constraints: const BoxConstraints(
                minWidth: 22,
                minHeight: 22,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
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
      return const Center(
        child: CircularProgressIndicator(),
      );
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
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
        for (final tab in _tabs)
          _buildTabContent(
            tab,
            _ordersForTab(tab.key),
          ),
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
                      Icon(
                        tab.icon,
                        size: 70,
                        color: const Color(0xFF741C1C),
                      ),
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
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20,
        ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),
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
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
              ),
              Text(
                'Total ${_money(order['total_amount'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _paymentTermsText(order),
              ),
              if (_formatDate(order['submitted_at']).isNotEmpty)
                Text(
                  'Submitted ${_formatDate(order['submitted_at'])}',
                ),
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

          _InfoBox(
            title: 'Payment terms',
            value: _paymentTermsText(order),
          ),

          if (status == 'delivered' || status == 'completed')
            _InfoBox(
              title: 'Issue reporting window',
              value:
                  '${_formatNumber(order['issue_reporting_window_hours_snapshot'] ?? 24)} hours from delivery',
            ),

          if (issues.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Reported issues',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final issue in issues) _buildIssueCard(issue),
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
                border: Border.all(
                  color: const Color(0xFFE4E4E1),
                ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item['sku_snapshot'] != null &&
                          item['sku_snapshot'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${item['sku_snapshot']}',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        '${_formatNumber(item['quantity'])} '
                        '${_unitLabel(item['quantity_unit']?.toString())}'
                        ' × ${_money(item['unit_price'])}'
                        '${_priceBasisLabel(item['price_basis']?.toString()).isEmpty ? '' : ' / ${_priceBasisLabel(item['price_basis']?.toString())}'}',
                        style: const TextStyle(
                          color: Color(0xFF555555),
                        ),
                      ),
                      if (item['notes'] != null &&
                          item['notes'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          'Notes: ${item['notes']}',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ],
                  );

                  final right = Text(
                    _money(item['line_subtotal']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: 10),
                        right,
                      ],
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
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Subtotal',
                    value: _money(order['subtotal']),
                  ),
                  _TotalRow(
                    label: 'GST',
                    value: _money(order['gst_amount']),
                  ),
                  const Divider(),
                  _TotalRow(
                    label: 'Total',
                    value: _money(order['total_amount']),
                    bold: true,
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

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final status = issue['status']?.toString() ?? 'requested';
    final withinWindow = issue['within_reporting_window'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE4BABA),
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
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Color(0xFFB3261E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 12,
              ),
            ),
          ],
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
  const _InfoBox({
    required this.title,
    required this.value,
  });

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
        border: Border.all(
          color: const Color(0xFFE1E1DE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
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
          Expanded(
            child: Text(
              label,
              style: style,
            ),
          ),
          Text(
            value,
            style: style,
          ),
        ],
      ),
    );
  }
}
