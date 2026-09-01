import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supplier_work_order_page.dart';

class SupplierWorkOrdersPage extends StatefulWidget {
  const SupplierWorkOrdersPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SupplierWorkOrdersPage> createState() => _SupplierWorkOrdersPageState();
}

class _SupplierWorkOrdersPageState extends State<SupplierWorkOrdersPage>
    with SingleTickerProviderStateMixin {
  static const _darkRed = Color(0xFF741C1C);

  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _workOrders = [];
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _tabs = [
    'all',
    'created',
    'printed',
    'picking',
    'picked',
    'completed',
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _loadWorkOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _resolveSupplierBusinessId() async {
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

    for (final raw in businesses) {
      if (raw['business_type']?.toString() == 'supplier') {
        final id = raw['id']?.toString();

        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    }

    throw Exception('No active supplier business membership was found.');
  }

  Future<void> _loadWorkOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final supplierBusinessId = await _resolveSupplierBusinessId();

      final response = await client
          .from('warehouse_work_orders')
          .select('''
            id,
            order_id,
            supplier_business_id,
            work_order_number,
            status,
            warehouse_instructions,
            picked_by,
            checked_by,
            printed_at,
            picking_started_at,
            picked_at,
            completed_at,
            created_at,
            updated_at,
            orders(
              id,
              order_number,
              status,
              customer_reference,
              order_source,
              supplier_customer_accounts(
                id,
                customer_name,
                legal_name,
                account_source
              ),
              businesses!orders_butcher_business_id_fkey(
                id,
                trading_name,
                legal_name
              ),
              order_items(
                id,
                product_name_snapshot,
                sku_snapshot,
                quantity,
                quantity_unit,
                supplied_quantity,
                supplied_quantity_unit,
                actual_weight,
                actual_weight_unit,
                fulfilment_status,
                catch_weight_snapshot
              )
            )
          ''')
          .eq('supplier_business_id', supplierBusinessId)
          .neq('status', 'completed')
          .order('created_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _workOrders = (response as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();

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

  Map<String, dynamic>? _order(Map<String, dynamic> workOrder) {
    final raw = workOrder['orders'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }

    return null;
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> workOrder) {
    final raw = _order(workOrder)?['order_items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _customerName(Map<String, dynamic> workOrder) {
    final order = _order(workOrder);

    final accountRaw = order?['supplier_customer_accounts'];

    if (accountRaw is Map) {
      final account = Map<String, dynamic>.from(accountRaw);

      final customerName = account['customer_name']?.toString().trim();
      final legalName = account['legal_name']?.toString().trim();

      if (customerName != null && customerName.isNotEmpty) {
        return customerName;
      }

      if (legalName != null && legalName.isNotEmpty) {
        return legalName;
      }
    }

    final butcherRaw = order?['businesses'];

    if (butcherRaw is Map) {
      final butcher = Map<String, dynamic>.from(butcherRaw);

      final tradingName = butcher['trading_name']?.toString().trim();
      final legalName = butcher['legal_name']?.toString().trim();

      if (tradingName != null && tradingName.isNotEmpty) {
        return tradingName;
      }

      if (legalName != null && legalName.isNotEmpty) {
        return legalName;
      }
    }

    return 'Customer';
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'created':
        return 'Created';
      case 'printed':
        return 'Printed';
      case 'picking':
        return 'Picking';
      case 'picked':
        return 'Picked';
      case 'completed':
        return 'Completed';
      default:
        return value ?? 'Unknown';
    }
  }

  String _orderSourceLabel(String? value) {
    switch (value) {
      case 'marketplace':
        return 'Marketplace';
      case 'phone':
        return 'Phone';
      case 'email':
        return 'Email';
      case 'sales_rep':
        return 'Sales Rep';
      case 'manual':
        return 'Manual';
      case 'replacement':
        return 'Replacement';
      default:
        return value ?? '';
    }
  }

  int _countForStatus(String status) {
    if (status == 'all') {
      return _workOrders.length;
    }

    return _workOrders
        .where((workOrder) => workOrder['status']?.toString() == status)
        .length;
  }

  int _finalisedLineCount(Map<String, dynamic> workOrder) {
    return _items(workOrder)
        .where((item) => item['fulfilment_status']?.toString() == 'finalised')
        .length;
  }

  List<Map<String, dynamic>> get _filteredWorkOrders {
    final selectedStatus = _tabs[_tabController.index];
    final query = _searchController.text.trim().toLowerCase();

    return _workOrders.where((workOrder) {
      if (selectedStatus != 'all' &&
          workOrder['status']?.toString() != selectedStatus) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final order = _order(workOrder);

      final searchText =
          [
                workOrder['work_order_number'],
                order?['order_number'],
                order?['customer_reference'],
                _customerName(workOrder),
                order?['order_source'],
              ]
              .whereType<Object>()
              .map((value) {
                return value.toString().toLowerCase();
              })
              .join(' ');

      return searchText.contains(query);
    }).toList();
  }

  Future<void> _openWorkOrder(Map<String, dynamic> workOrder) async {
    final orderId = workOrder['order_id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierWorkOrderPage(orderId: orderId),
      ),
    );

    if (mounted) {
      await _loadWorkOrders();
    }
  }

  Widget _statusChip(String status) {
    Color background;
    Color foreground;

    switch (status) {
      case 'created':
        background = const Color(0xFFF0F0F0);
        foreground = const Color(0xFF555555);
        break;
      case 'printed':
        background = const Color(0xFFE9EEF8);
        foreground = const Color(0xFF315F8C);
        break;
      case 'picking':
        background = const Color(0xFFFFF1D8);
        foreground = const Color(0xFF8A5B00);
        break;
      case 'picked':
        background = const Color(0xFFE7F0FA);
        foreground = const Color(0xFF275A89);
        break;
      case 'completed':
        background = const Color(0xFFE5F4E9);
        foreground = const Color(0xFF25663A);
        break;
      default:
        background = const Color(0xFFF0F0F0);
        foreground = const Color(0xFF555555);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildWorkOrderCard(Map<String, dynamic> workOrder) {
    final order = _order(workOrder);
    final items = _items(workOrder);
    final finalised = _finalisedLineCount(workOrder);
    final status = workOrder['status']?.toString() ?? 'created';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 7),
      shadowColor: const Color(0x12000000),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE3E5E8)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openWorkOrder(workOrder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        workOrder['work_order_number']?.toString() ??
                            'Work Order',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _customerName(workOrder),
                    style: const TextStyle(
                      color: _darkRed,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _MiniInfo(
                        label: 'Sales order',
                        value: order?['order_number']?.toString() ?? '',
                      ),
                      _MiniInfo(
                        label: 'Source',
                        value: _orderSourceLabel(
                          order?['order_source']?.toString(),
                        ),
                      ),
                      _MiniInfo(label: 'Lines', value: '${items.length}'),
                      _MiniInfo(
                        label: 'Finalised',
                        value: '$finalised / ${items.length}',
                      ),
                    ],
                  ),
                  if ((workOrder['warehouse_instructions']?.toString().trim() ??
                          '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      workOrder['warehouse_instructions'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              );

              final action = OutlinedButton.icon(
                onPressed: () => _openWorkOrder(workOrder),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _darkRed,
                  side: const BorderSide(color: Color(0xFFDDB7BC)),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.assignment_outlined, size: 17),
                label: const Text('Open Work Order'),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 10), action],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 14),
                  action,
                ],
              );
            },
          ),
        ),
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
              const Icon(Icons.error_outline, size: 60, color: _darkRed),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _loadWorkOrders,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredWorkOrders;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Column(
          children: [
            if (!widget.embedded)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE3E5E8)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x07000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warehouse_outlined, color: _darkRed, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Warehouse Work Queue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pick, weigh, check and finalise active supplier orders.',
                              style: TextStyle(
                                color: Color(0xFF666A70),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, widget.embedded ? 14 : 0, 18, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Search work order, sales order, customer or reference',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFB),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE3E5E8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE3E5E8)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE3E5E8)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _darkRed,
                  unselectedLabelColor: const Color(0xFF666A70),
                  indicatorColor: _darkRed,
                  indicatorWeight: 3,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  labelStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                  tabs: [
                    Tab(text: 'All (${_countForStatus('all')})'),
                    Tab(text: 'Created (${_countForStatus('created')})'),
                    Tab(text: 'Printed (${_countForStatus('printed')})'),
                    Tab(text: 'Picking (${_countForStatus('picking')})'),
                    Tab(text: 'Picked (${_countForStatus('picked')})'),
                    Tab(text: 'Completed (${_countForStatus('completed')})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.assignment_outlined,
                              size: 42,
                              color: Color(0xFFAAAAAA),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? 'No work orders in this section.'
                                  : 'No work orders match your search.',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWorkOrders,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildWorkOrderCard(filtered[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspaceHeader() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EAEA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: _darkRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Work Orders',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 1),
                Text(
                  'Manage fulfilment, weighing and order preparation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF74787E),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadWorkOrders,
            tooltip: 'Refresh work orders',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ColoredBox(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            _workspaceHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

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
            Icon(Icons.assignment_outlined, color: _darkRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Work Orders',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadWorkOrders,
            tooltip: 'Refresh work orders',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE4E6E8)),
        ),
      ),
      body: _buildBody(),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

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
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
