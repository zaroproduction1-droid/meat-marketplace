import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/presentation/pending_businesses_page.dart';
import '../../customers/presentation/supplier_customer_requests_page.dart';
import '../../delivery/presentation/supplier_delivery_settings_page.dart';
import '../../marketplace/presentation/butcher_vip_suppliers_page.dart';
import '../../marketplace/presentation/marketplace_products_page.dart';
import '../../orders/presentation/butcher_accounts_page.dart';
import '../../orders/presentation/butcher_settings_page.dart';
import '../../orders/presentation/submitted_orders_page.dart';
import '../../orders/presentation/supplier_inventory_page.dart';
import '../../orders/presentation/supplier_orders_page.dart';
import '../../orders/presentation/supplier_invoices_page.dart';
import '../../orders/presentation/supplier_sales_page.dart';
import '../../orders/presentation/supplier_settings_page.dart';
import '../../orders/presentation/supplier_unified_orders_page.dart';
import '../../orders/presentation/supplier_work_orders_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  static const double _collapsedSidebarWidth = 76;
  static const double _expandedSidebarWidth = 228;
  static const Duration _sidebarAnimationDuration = Duration(milliseconds: 170);
  static const Color _darkRed = Color(0xFF8B1E2D);
  static const Color _deepNavy = Color(0xFF081625);
  static const Color _canvas = Color(0xFFF7F8FA);

  bool _isLoading = true;
  bool _isAdmin = false;
  bool _sidebarCollapsed = false;
  double _sidebarLayoutWidth = _expandedSidebarWidth;
  bool _sidebarTransitioning = false;

  Widget? _workspacePage;
  String _workspaceKey = 'dashboard';

  int _newSupplierOrderCount = 0;

  String? _errorMessage;
  String? _businessName;
  String? _businessType;

  List<Map<String, dynamic>> _butcherOrders = [];
  List<Map<String, dynamic>> _butcherAccounts = [];

  List<Map<String, dynamic>> _supplierOrders = [];
  List<Map<String, dynamic>> _supplierAccounts = [];
  List<Map<String, dynamic>> _supplierInvoices = [];
  List<Map<String, dynamic>> _supplierProducts = [];
  int _pendingVipApplications = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDashboard() async {
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

      final profile = await client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .single();

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
          .select('''
            id,
            legal_name,
            trading_name,
            business_type,
            verification_status,
            active
          ''')
          .inFilter('id', businessIds)
          .eq('active', true);

      if (businesses.isEmpty) {
        throw Exception('No active business was found for this user.');
      }

      Map<String, dynamic>? business;

      for (final raw in businesses) {
        final candidate = Map<String, dynamic>.from(raw);
        if (candidate['business_type']?.toString() == 'supplier') {
          business = candidate;
          break;
        }
      }

      business ??= Map<String, dynamic>.from(businesses.first);

      final businessId = business['id'].toString();
      final businessType = business['business_type']?.toString();
      final tradingName = business['trading_name']?.toString().trim();
      final legalName = business['legal_name']?.toString().trim();

      final businessName = (tradingName != null && tradingName.isNotEmpty)
          ? tradingName
          : (legalName != null && legalName.isNotEmpty)
          ? legalName
          : 'Business';

      var newSupplierOrderCount = 0;
      var butcherOrders = <Map<String, dynamic>>[];
      var butcherAccounts = <Map<String, dynamic>>[];

      var supplierOrders = <Map<String, dynamic>>[];
      var supplierAccounts = <Map<String, dynamic>>[];
      var supplierInvoices = <Map<String, dynamic>>[];
      var supplierProducts = <Map<String, dynamic>>[];
      var pendingVipApplications = 0;

      if (businessType == 'supplier') {
        final supplierOrderResponse = await client
            .from('orders')
            .select('''
              id,
              order_number,
              butcher_business_id,
              supplier_customer_account_id,
              status,
              order_source,
              fulfilment_method,
              requested_fulfilment_date,
              requested_fulfilment_time,
              total_amount,
              submitted_at,
              created_at,
              updated_at,
              businesses!orders_butcher_business_id_fkey(
                legal_name,
                trading_name
              ),
              supplier_customer_accounts(
                customer_name,
                legal_name
              ),
              invoices(
                id,
                invoice_number,
                status,
                total_amount,
                outstanding_amount,
                sent_to_butcher_at
              ),
              warehouse_work_orders(
                id,
                work_order_number,
                status
              )
            ''')
            .eq('supplier_business_id', businessId)
            .order('updated_at', ascending: false)
            .limit(120);

        supplierOrders = List<Map<String, dynamic>>.from(
          supplierOrderResponse as List,
        );

        final accountResponse = await client.rpc(
          'list_supplier_account_summaries',
          params: {'due_soon_days': 7},
        );

        supplierAccounts = List<Map<String, dynamic>>.from(
          accountResponse as List,
        );

        final invoiceResponse = await client
            .from('invoices')
            .select('''
              id,
              invoice_number,
              supplier_customer_account_id,
              butcher_business_id,
              customer_name_snapshot,
              status,
              total_amount,
              outstanding_amount,
              amount_paid,
              credit_applied,
              invoice_date,
              due_date,
              issued_at,
              sent_to_butcher_at,
              created_at
            ''')
            .eq('supplier_business_id', businessId)
            .order('created_at', ascending: false)
            .limit(150);

        supplierInvoices = List<Map<String, dynamic>>.from(
          invoiceResponse as List,
        );

        final productResponse = await client
            .from('products')
            .select('''
              id,
              product_name,
              available_quantity,
              quantity_unit,
              availability_status,
              active
            ''')
            .eq('supplier_business_id', businessId)
            .eq('active', true)
            .order('product_name')
            .limit(1000);

        supplierProducts = List<Map<String, dynamic>>.from(
          productResponse as List,
        );

        final pendingVipResponse = await client
            .from('vip_trade_applications')
            .select('id')
            .eq('supplier_business_id', businessId)
            .eq('status', 'pending');

        pendingVipApplications = pendingVipResponse.length;

        for (final order in supplierOrders) {
          if (order['status']?.toString() == 'submitted') {
            newSupplierOrderCount++;
          }
        }
      }

      if (businessType == 'butcher') {
        final orderResponse = await client
            .from('orders')
            .select('''
              id,
              order_number,
              butcher_business_id,
              supplier_business_id,
              status,
              order_type,
              order_source,
              subtotal,
              gst_amount,
              total_amount,
              submitted_at,
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
                quantity,
                quantity_unit,
                unit_price,
                price_basis,
                line_subtotal
              )
            ''')
            .eq('butcher_business_id', businessId)
            .neq('status', 'draft')
            .order('updated_at', ascending: false)
            .limit(100);

        butcherOrders = List<Map<String, dynamic>>.from(orderResponse as List);

        final accountResponse = await client.rpc(
          'list_butcher_supplier_account_summaries',
          params: {'due_soon_days': 7},
        );

        butcherAccounts = List<Map<String, dynamic>>.from(
          accountResponse as List,
        );
      }

      if (!mounted) return;

      setState(() {
        _businessName = businessName;
        _businessType = businessType;
        _isAdmin = profile['is_admin'] as bool? ?? false;
        _newSupplierOrderCount = newSupplierOrderCount;
        _butcherOrders = butcherOrders;
        _butcherAccounts = butcherAccounts;
        _supplierOrders = supplierOrders;
        _supplierAccounts = supplierAccounts;
        _supplierInvoices = supplierInvoices;
        _supplierProducts = supplierProducts;
        _pendingVipApplications = pendingVipApplications;
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

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openDashboard({String workspaceKey = 'dashboard'}) {
    if (_workspacePage == null && _workspaceKey == workspaceKey) return;

    setState(() {
      _workspaceKey = workspaceKey;
      _workspacePage = null;
    });
  }

  String _workspaceKeyForPage(Widget page) {
    if (page is MarketplaceProductsPage) return 'browse';
    if (page is ButcherVipSuppliersPage) return 'suppliers';
    if (page is SubmittedOrdersPage) return 'orders';
    if (page is ButcherAccountsPage) return 'accounts';
    if (page is ButcherSettingsPage) return 'settings';

    if (page is SupplierSalesPage) return 'sales';
    if (page is SupplierUnifiedOrdersPage) return 'orders';
    if (page is SupplierOrdersPage) return 'orders';
    if (page is SupplierInventoryPage) return 'inventory';
    if (page is SupplierCustomerRequestsPage) return 'customers';
    if (page is SupplierWorkOrdersPage) return 'work_orders';
    if (page is SupplierDeliverySettingsPage) return 'delivery';
    if (page is SupplierInvoicesPage) return 'invoices';
    if (page is SupplierSettingsPage) return 'settings';

    if (page is PendingBusinessesPage) return 'admin';

    return page.runtimeType.toString();
  }

  void _openPage(Widget page, {String? workspaceKey}) {
    final nextKey = workspaceKey ?? _workspaceKeyForPage(page);
    if (_workspacePage != null && _workspaceKey == nextKey) return;

    setState(() {
      _workspaceKey = nextKey;
      _workspacePage = page;
    });
  }

  void _toggleSidebar() {
    if (_sidebarTransitioning) return;

    final collapsing = !_sidebarCollapsed;
    setState(() {
      _sidebarTransitioning = true;
      _sidebarCollapsed = collapsing;

      // Expansion reserves the final side-by-side space before its visual
      // animation. Collapse keeps the expanded reservation until animation
      // completion, so the workspace is never resized on animation frames.
      if (!collapsing) {
        _sidebarLayoutWidth = _expandedSidebarWidth;
      }
    });
  }

  void _onSidebarVisualAnimationEnd() {
    if (!_sidebarTransitioning) return;

    if (_sidebarCollapsed) {
      setState(() {
        _sidebarLayoutWidth = _collapsedSidebarWidth;
        _sidebarTransitioning = false;
      });
      return;
    }

    _sidebarTransitioning = false;
  }

  Widget _sidebarTransitionFrame({required Widget child}) {
    final visualWidth = _sidebarCollapsed
        ? _collapsedSidebarWidth
        : _expandedSidebarWidth;

    return SizedBox(
      width: _sidebarLayoutWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: _sidebarAnimationDuration,
          curve: Curves.easeOutCubic,
          width: visualWidth,
          color: _deepNavy,
          clipBehavior: Clip.hardEdge,
          onEnd: _onSidebarVisualAnimationEnd,
          child: child,
        ),
      ),
    );
  }

  void _openSettings() {
    if (_businessType == 'butcher') {
      _openPage(const ButcherSettingsPage());
      return;
    }

    _openPage(const SupplierSettingsPage(embedded: true));
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _asDouble(value);
    final negative = amount < 0;
    final absolute = amount.abs();
    final raw = absolute.toStringAsFixed(2);
    final parts = raw.split('.');
    final whole = parts.first;
    final decimals = parts.last;
    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '${negative ? '-' : ''}\$${buffer.toString()}.$decimals';
  }

  String _shortMoney(dynamic value) {
    final amount = _asDouble(value);

    if (amount.abs() >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}m';
    }

    if (amount.abs() >= 1000) {
      final decimals = amount.abs() >= 10000 ? 0 : 1;
      return '\$${(amount / 1000).toStringAsFixed(decimals)}k';
    }

    return _money(amount);
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '—';

    const months = <String>[
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

    return '${date.day} ${months[date.month - 1]}';
  }

  String _supplierName(Map<String, dynamic> order) {
    final raw = order['businesses'];

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final trading = map['trading_name']?.toString().trim();
      if (trading != null && trading.isNotEmpty) return trading;

      final legal = map['legal_name']?.toString().trim();
      if (legal != null && legal.isNotEmpty) return legal;
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      final map = Map<String, dynamic>.from(raw.first as Map);
      final trading = map['trading_name']?.toString().trim();
      if (trading != null && trading.isNotEmpty) return trading;

      final legal = map['legal_name']?.toString().trim();
      if (legal != null && legal.isNotEmpty) return legal;
    }

    return 'Supplier';
  }

  DateTime? _orderDate(Map<String, dynamic> order) {
    return DateTime.tryParse(
      (order['submitted_at'] ?? order['created_at'])?.toString() ?? '',
    )?.toLocal();
  }

  bool _countSpend(Map<String, dynamic> order) {
    final status = order['status']?.toString();
    return status != 'declined' && status != 'cancelled' && status != 'void';
  }

  int get _ordersThisMonth {
    final now = DateTime.now();

    return _butcherOrders.where((order) {
      final date = _orderDate(order);
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
  }

  double get _spendThisMonth {
    final now = DateTime.now();

    return _butcherOrders.fold<double>(0, (sum, order) {
      final date = _orderDate(order);
      if (date == null ||
          date.year != now.year ||
          date.month != now.month ||
          !_countSpend(order)) {
        return sum;
      }

      return sum + _asDouble(order['total_amount']);
    });
  }

  double get _outstandingTotal {
    return _butcherAccounts.fold<double>(
      0,
      (sum, account) => sum + _asDouble(account['outstanding_balance']),
    );
  }

  double get _dueSoonTotal {
    return _butcherAccounts.fold<double>(
      0,
      (sum, account) => sum + _asDouble(account['due_soon_amount']),
    );
  }

  double get _overdueTotal {
    return _butcherAccounts.fold<double>(
      0,
      (sum, account) => sum + _asDouble(account['overdue_amount']),
    );
  }

  int get _supplierAccountCount {
    return _butcherAccounts
        .where((account) => _asDouble(account['outstanding_balance']) > 0)
        .length;
  }

  List<Map<String, dynamic>> get _recentOrders =>
      _butcherOrders.take(5).toList();

  List<Map<String, dynamic>> get _topAccounts {
    final copy = [..._butcherAccounts];
    copy.sort(
      (a, b) => _asDouble(
        b['outstanding_balance'],
      ).compareTo(_asDouble(a['outstanding_balance'])),
    );
    return copy.take(4).toList();
  }

  List<_QuickReorderItem> get _quickReorders {
    final seen = <String>{};
    final output = <_QuickReorderItem>[];

    for (final order in _butcherOrders) {
      final items = order['order_items'];
      if (items is! List) continue;

      for (final raw in items) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);

        final name =
            item['product_name_snapshot']?.toString().trim() ?? 'Product';
        final key = '${order['supplier_business_id']}::$name'.toLowerCase();

        if (!seen.add(key)) continue;

        output.add(
          _QuickReorderItem(
            productName: name,
            supplierName: _supplierName(order),
            unitPrice: _asDouble(item['unit_price']),
            priceBasis: item['price_basis']?.toString(),
            lastOrdered: _orderDate(order),
          ),
        );

        if (output.length >= 4) return output;
      }
    }

    return output;
  }

  List<_MonthlySpend> get _sixMonthSpend {
    final now = DateTime.now();
    final months = <_MonthlySpend>[];

    for (var offset = 5; offset >= 0; offset--) {
      final monthDate = DateTime(now.year, now.month - offset, 1);
      var total = 0.0;

      for (final order in _butcherOrders) {
        final date = _orderDate(order);

        if (date != null &&
            date.year == monthDate.year &&
            date.month == monthDate.month &&
            _countSpend(order)) {
          total += _asDouble(order['total_amount']);
        }
      }

      months.add(_MonthlySpend(month: monthDate, amount: total));
    }

    return months;
  }

  String get _topSupplierThisMonth {
    final now = DateTime.now();
    final totals = <String, double>{};

    for (final order in _butcherOrders) {
      final date = _orderDate(order);
      if (date == null ||
          date.year != now.year ||
          date.month != now.month ||
          !_countSpend(order)) {
        continue;
      }

      final supplier = _supplierName(order);
      totals[supplier] =
          (totals[supplier] ?? 0) + _asDouble(order['total_amount']);
    }

    if (totals.isEmpty) return '—';

    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String get _mostPurchasedProduct {
    final counts = <String, double>{};

    for (final order in _butcherOrders) {
      final items = order['order_items'];
      if (items is! List) continue;

      for (final raw in items) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final name = item['product_name_snapshot']?.toString().trim();

        if (name == null || name.isEmpty) continue;

        counts[name] = (counts[name] ?? 0) + _asDouble(item['quantity']);
      }
    }

    if (counts.isEmpty) return '—';

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _orderStatusLabel(String? value) {
    return switch (value) {
      'submitted' => 'Submitted',
      'accepted' => 'Accepted',
      'processing' => 'Processing',
      'ready' => 'Ready',
      'dispatched' => 'Dispatched',
      'delivered' => 'Delivered',
      'completed' => 'Complete',
      'cancelled' => 'Cancelled',
      'declined' => 'Declined',
      _ => value == null || value.isEmpty ? 'Open' : value,
    };
  }

  Color _orderStatusColor(String? value) {
    return switch (value) {
      'completed' || 'delivered' => const Color(0xFF2E7D32),
      'cancelled' || 'declined' => const Color(0xFFB3261E),
      'dispatched' || 'ready' => const Color(0xFF315A8C),
      'submitted' || 'processing' || 'accepted' => const Color(0xFF9A6700),
      _ => const Color(0xFF666666),
    };
  }

  String _accountStatus(Map<String, dynamic> account) {
    if (_asDouble(account['overdue_amount']) > 0) return 'Overdue';
    if (_asDouble(account['due_soon_amount']) > 0) return 'Due Soon';
    if (_asDouble(account['outstanding_balance']) > 0) return 'Open';
    return 'Paid';
  }

  Color _accountStatusColor(String value) {
    return switch (value) {
      'Overdue' => const Color(0xFFB3261E),
      'Due Soon' => const Color(0xFF9A6700),
      'Open' => const Color(0xFF315A8C),
      _ => const Color(0xFF2E7D32),
    };
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _canvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: _canvas,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: _darkRed),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _loadDashboard,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_businessType == 'butcher') {
      return _buildButcherDashboard();
    }

    if (_businessType == 'supplier') {
      return _buildSupplierDashboard();
    }

    return _buildSupplierLegacyDashboard();
  }

  Widget _buildButcherDashboard() {
    return Scaffold(
      backgroundColor: _canvas,
      body: Row(
        children: [
          _butcherSidebar(),
          Expanded(
            child: RepaintBoundary(
              child: _workspacePage != null
                  ? KeyedSubtree(
                      key: ValueKey(_workspaceKey),
                      child: _workspacePage!,
                    )
                  : Column(
                      children: [
                        _topBar(cartVisible: true),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadDashboard,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                28,
                              ),
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1500,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          '${_greeting()}, ${_businessName ?? 'Butcher'}',
                                          style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Here’s what’s happening with your purchasing today.',
                                          style: TextStyle(
                                            color: Color(0xFF6A6E75),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        _summaryGrid(),
                                        const SizedBox(height: 16),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            if (constraints.maxWidth < 1050) {
                                              return Column(
                                                children: [
                                                  _attentionCard(),
                                                  const SizedBox(height: 14),
                                                  _recentOrdersCard(),
                                                  const SizedBox(height: 14),
                                                  _supplierAccountsCard(),
                                                ],
                                              );
                                            }

                                            return Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 9,
                                                  child: _attentionCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 13,
                                                  child: _recentOrdersCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 11,
                                                  child:
                                                      _supplierAccountsCard(),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            if (constraints.maxWidth < 1100) {
                                              return Column(
                                                children: [
                                                  _quickReorderCard(),
                                                  const SizedBox(height: 14),
                                                  _purchasingOverviewCard(),
                                                  const SizedBox(height: 14),
                                                  _quickActionsCard(),
                                                ],
                                              );
                                            }

                                            return Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 12,
                                                  child: _quickReorderCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 11,
                                                  child:
                                                      _purchasingOverviewCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 7,
                                                  child: _quickActionsCard(),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          _summaryCard(
            icon: Icons.shopping_cart_outlined,
            label: 'Orders This Month',
            value: _ordersThisMonth.toString(),
            support: 'Submitted purchase orders',
          ),
          _summaryCard(
            icon: Icons.attach_money_rounded,
            label: 'Total Spend',
            value: _money(_spendThisMonth),
            support: 'Across this month’s orders',
          ),
          _summaryCard(
            icon: Icons.receipt_long_outlined,
            label: 'Outstanding Accounts',
            value: _money(_outstandingTotal),
            support: 'Across $_supplierAccountCount suppliers',
          ),
          _summaryCard(
            icon: Icons.schedule_outlined,
            label: 'Due Soon',
            value: _money(_dueSoonTotal),
            support: _overdueTotal > 0
                ? '${_money(_overdueTotal)} already overdue'
                : 'Nothing overdue',
          ),
        ];

        if (constraints.maxWidth >= 1000) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(
                width: constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required String support,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF8EDEE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: _darkRed, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF262A30),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  support,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attentionCard() {
    final items = <_AttentionItem>[];

    if (_overdueTotal > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.warning_amber_rounded,
          tint: const Color(0xFFFFF0E0),
          iconColor: const Color(0xFFB85C00),
          message:
              '${_money(_overdueTotal)} is overdue across supplier accounts',
          action: 'View Accounts',
          onTap: () => _openPage(const ButcherAccountsPage()),
        ),
      );
    }

    if (_dueSoonTotal > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.receipt_long_outlined,
          tint: const Color(0xFFF8EDEE),
          iconColor: _darkRed,
          message: '${_money(_dueSoonTotal)} is due within the next 7 days',
          action: 'View Accounts',
          onTap: () => _openPage(const ButcherAccountsPage()),
        ),
      );
    }

    Map<String, dynamic>? readyOrder;

    for (final order in _butcherOrders) {
      final status = order['status']?.toString();
      if (status == 'ready' || status == 'dispatched') {
        readyOrder = order;
        break;
      }
    }

    if (readyOrder != null) {
      items.add(
        _AttentionItem(
          icon: Icons.local_shipping_outlined,
          tint: const Color(0xFFEAF2FB),
          iconColor: const Color(0xFF315A8C),
          message:
              'Order ${readyOrder['order_number'] ?? ''} is ${_orderStatusLabel(readyOrder['status']?.toString()).toLowerCase()}',
          action: 'View Order',
          onTap: () => _openPage(const SubmittedOrdersPage()),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _AttentionItem(
          icon: Icons.check_circle_outline,
          tint: const Color(0xFFEAF6ED),
          iconColor: const Color(0xFF2E7D32),
          message: 'Nothing urgent needs your attention right now',
          action: 'View Orders',
          onTap: () => _openPage(const SubmittedOrdersPage()),
        ),
      );
    }

    return _sectionCard(
      title: 'Needs Your Attention',
      trailing: items.length > 1 ? _smallBadge(items.length.toString()) : null,
      child: Column(
        children: [
          for (var i = 0; i < math.min(items.length, 4); i++) ...[
            _attentionRow(items[i]),
            if (i != math.min(items.length, 4) - 1)
              const Divider(height: 1, color: Color(0xFFE9EAEC)),
          ],
        ],
      ),
    );
  }

  Widget _attentionRow(_AttentionItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.message,
              style: const TextStyle(
                color: Color(0xFF383C42),
                fontSize: 11.8,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: item.onTap,
            style: TextButton.styleFrom(
              foregroundColor: _darkRed,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            child: Text(
              item.action,
              style: const TextStyle(
                fontSize: 10.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentOrdersCard() {
    return _sectionCard(
      title: 'Recent Orders',
      actionText: 'View All Orders',
      onAction: () => _openPage(const SubmittedOrdersPage()),
      child: _recentOrders.isEmpty
          ? _emptyState(
              Icons.shopping_bag_outlined,
              'No orders yet',
              'Your submitted orders will appear here.',
            )
          : Column(
              children: [
                const _TableHeader(
                  cells: [
                    _TableHeaderCell('Order', 2),
                    _TableHeaderCell('Supplier', 3),
                    _TableHeaderCell('Date', 2),
                    _TableHeaderCell('Total', 2),
                    _TableHeaderCell('Status', 2),
                  ],
                ),
                for (final order in _recentOrders)
                  InkWell(
                    onTap: () => _openPage(const SubmittedOrdersPage()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE9EAEC)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tableCell(
                            order['order_number']?.toString() ?? 'Order',
                            flex: 2,
                            strong: true,
                          ),
                          _tableCell(_supplierName(order), flex: 3),
                          _tableCell(
                            _date(order['submitted_at'] ?? order['created_at']),
                            flex: 2,
                          ),
                          _tableCell(
                            _money(order['total_amount']),
                            flex: 2,
                            strong: true,
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _statusChip(
                                _orderStatusLabel(order['status']?.toString()),
                                _orderStatusColor(order['status']?.toString()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _supplierAccountsCard() {
    return _sectionCard(
      title: 'Supplier Accounts',
      actionText: 'View Accounts',
      onAction: () => _openPage(const ButcherAccountsPage()),
      child: _topAccounts.isEmpty
          ? _emptyState(
              Icons.account_balance_wallet_outlined,
              'No supplier balances',
              'Supplier account balances will appear here.',
            )
          : Column(
              children: [
                const _TableHeader(
                  cells: [
                    _TableHeaderCell('Supplier', 3),
                    _TableHeaderCell('Outstanding', 2),
                    _TableHeaderCell('Status', 2),
                  ],
                ),
                for (final account in _topAccounts)
                  InkWell(
                    onTap: () => _openPage(const ButcherAccountsPage()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE9EAEC)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tableCell(
                            account['supplier_name']?.toString() ?? 'Supplier',
                            flex: 3,
                            strong: true,
                          ),
                          _tableCell(
                            _money(account['outstanding_balance']),
                            flex: 2,
                            strong: true,
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Builder(
                                builder: (_) {
                                  final status = _accountStatus(account);
                                  return _statusChip(
                                    status,
                                    _accountStatusColor(status),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _quickReorderCard() {
    final items = _quickReorders;

    return _sectionCard(
      title: 'Quick Reorder',
      actionText: 'Browse Products',
      onAction: () => _openPage(const MarketplaceProductsPage()),
      child: items.isEmpty
          ? _emptyState(
              Icons.refresh_rounded,
              'No reorder history yet',
              'Products from your recent orders will appear here.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final itemWidth = width >= 720
                    ? (width - 30) / 4
                    : width >= 430
                    ? (width - 10) / 2
                    : width;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: itemWidth,
                        child: _quickReorderTile(item),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _quickReorderTile(_QuickReorderItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF7ECEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.restaurant_menu_outlined,
                color: _darkRed,
                size: 31,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
          const SizedBox(height: 3),
          Text(
            item.supplierName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6E7278), fontSize: 10.8),
          ),
          const SizedBox(height: 8),
          Text(
            item.unitPrice > 0
                ? '${_money(item.unitPrice)}${item.priceBasis == 'kilogram' ? '/kg' : ''}'
                : 'Price varies',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          Text(
            item.lastOrdered == null
                ? 'Previously ordered'
                : 'Last ordered ${_date(item.lastOrdered)}',
            style: const TextStyle(color: Color(0xFF777B82), fontSize: 10.3),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openPage(const MarketplaceProductsPage()),
              icon: const Icon(Icons.shopping_cart_outlined, size: 16),
              label: const Text('Reorder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkRed,
                side: const BorderSide(color: Color(0xFFD7A8AE)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchasingOverviewCard() {
    final months = _sixMonthSpend;
    final maxValue = months.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.amount),
    );

    return _sectionCard(
      title: 'Purchasing Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Last 6 months',
            style: TextStyle(
              color: Color(0xFF73777E),
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < months.length; i++) ...[
                  Expanded(child: _monthBar(months[i], maxValue)),
                  if (i != months.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  Icons.emoji_events_outlined,
                  'Top Supplier',
                  _topSupplierThisMonth,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniMetric(
                  Icons.shopping_bag_outlined,
                  'Most Purchased',
                  _mostPurchasedProduct,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthBar(_MonthlySpend item, double maxValue) {
    final ratio = maxValue <= 0 ? 0.05 : item.amount / maxValue;
    const months = <String>[
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          item.amount <= 0 ? '—' : _shortMoney(item.amount),
          maxLines: 1,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: math.max(0.04, ratio),
              child: Container(
                decoration: BoxDecoration(
                  color: _darkRed,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          months[item.month.month - 1],
          style: const TextStyle(color: Color(0xFF6E7278), fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _miniMetric(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF7ECEE),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, color: _darkRed, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF73777E), fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickActionsCard() {
    return _sectionCard(
      title: 'Quick Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _quickAction(
            Icons.storefront_outlined,
            'Browse Products',
            () => _openPage(const MarketplaceProductsPage()),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.scale_outlined,
            'Compare Suppliers',
            () => _openPage(
              const MarketplaceProductsPage(),
              workspaceKey: 'compare',
            ),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.shopping_bag_outlined,
            'View Orders',
            () => _openPage(const SubmittedOrdersPage()),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.account_balance_wallet_outlined,
            'View Accounts',
            () => _openPage(const ButcherAccountsPage()),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.workspace_premium_outlined,
            'Supplier Access',
            () => _openPage(const ButcherVipSuppliersPage()),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: _darkRed,
        side: const BorderSide(color: Color(0xFFDDB7BC)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    String? actionText,
    VoidCallback? onAction,
    Widget? trailing,
  }) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ?trailing,
                if (actionText != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: _darkRed,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7E8EA)),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE3E5E8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9A9DA2), size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777B82), fontSize: 10.8),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {required int flex, bool strong = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF34383E),
            fontSize: 10.8,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.7,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _smallBadge(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _darkRed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _sidebarHeader() {
    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = _sidebarCollapsed || constraints.maxWidth < 150;
          final logoSize = compact ? 28.0 : 34.0;
          final toggleSize = compact ? 28.0 : 34.0;

          final logo = Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: _darkRed,
              borderRadius: BorderRadius.circular(compact ? 8 : 9),
            ),
            child: Icon(
              Icons.link_rounded,
              color: Colors.white,
              size: compact ? 18 : 21,
            ),
          );

          final toggle = IconButton(
            onPressed: _toggleSidebar,
            tooltip: _sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(width: toggleSize, height: 34),
            icon: Icon(
              _sidebarCollapsed
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              color: Colors.white,
              size: 21,
            ),
          );

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
            child: compact
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [logo, toggle],
                  )
                : Row(
                    children: [
                      logo,
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'CutLink',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      toggle,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _butcherSidebar() {
    return _sidebarTransitionFrame(
      child: SafeArea(
        child: Column(
          children: [
            _sidebarHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _sideItem(
                    Icons.grid_view_rounded,
                    'Dashboard',
                    selected: _workspaceKey == 'dashboard',
                    onTap: _openDashboard,
                  ),
                  _sideItem(
                    Icons.shopping_bag_outlined,
                    'Browse Products',
                    selected: _workspaceKey == 'browse',
                    onTap: () => _openPage(const MarketplaceProductsPage()),
                  ),
                  _sideItem(
                    Icons.scale_outlined,
                    'Compare',
                    selected: _workspaceKey == 'compare',
                    onTap: () => _openPage(
                      const MarketplaceProductsPage(),
                      workspaceKey: 'compare',
                    ),
                  ),
                  _sideItem(
                    Icons.people_outline,
                    'Suppliers',
                    selected: _workspaceKey == 'suppliers',
                    onTap: () => _openPage(const ButcherVipSuppliersPage()),
                  ),
                  _sideItem(
                    Icons.receipt_long_outlined,
                    'Orders',
                    selected: _workspaceKey == 'orders',
                    onTap: () => _openPage(const SubmittedOrdersPage()),
                  ),
                  _sideItem(
                    Icons.favorite_border,
                    'Favourites',
                    selected: _workspaceKey == 'favourites',
                    onTap: () => _openPage(
                      const MarketplaceProductsPage(),
                      workspaceKey: 'favourites',
                    ),
                  ),
                  _sideItem(
                    Icons.account_balance_wallet_outlined,
                    'Accounts & Invoices',
                    selected: _workspaceKey == 'accounts',
                    onTap: () => _openPage(const ButcherAccountsPage()),
                  ),
                  _sideItem(
                    Icons.bar_chart_outlined,
                    'Analytics',
                    selected: _workspaceKey == 'analytics',
                    onTap: () => _openDashboard(workspaceKey: 'analytics'),
                  ),
                  _sideItem(
                    Icons.notifications_none_rounded,
                    'Notifications',
                    selected: _workspaceKey == 'notifications',
                    onTap: () => _openPage(
                      const ButcherNotificationSettingsPage(),
                      workspaceKey: 'notifications',
                    ),
                  ),
                  _sideItem(
                    Icons.settings_outlined,
                    'Settings',
                    selected: _workspaceKey == 'settings',
                    onTap: () => _openPage(const ButcherSettingsPage()),
                  ),
                  if (_isAdmin)
                    _sideItem(
                      Icons.admin_panel_settings_outlined,
                      'Admin',
                      selected: _workspaceKey == 'admin',
                      onTap: () => _openPage(const PendingBusinessesPage()),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF263544))),
              ),
              child: Column(
                children: [
                  if (!_sidebarCollapsed)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 160) {
                          return const SizedBox.shrink();
                        }

                        return Material(
                          color: const Color(0xFF102335),
                          borderRadius: BorderRadius.circular(11),
                          child: InkWell(
                            onTap: _openSettings,
                            borderRadius: BorderRadius.circular(11),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _darkRed,
                                    child: Text(
                                      (_businessName?.isNotEmpty ?? false)
                                          ? _businessName![0].toUpperCase()
                                          : 'B',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _businessName ?? 'Butcher',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const Text(
                                          'Butcher Account',
                                          style: TextStyle(
                                            color: Color(0xFFAAB4BE),
                                            fontSize: 9.8,
                                          ),
                                        ),
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
                  _sideItem(Icons.logout_rounded, 'Logout', onTap: _signOut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideItem(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel = !_sidebarCollapsed && constraints.maxWidth >= 120;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: selected ? _darkRed : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 42,
                child: Row(
                  children: [
                    SizedBox(
                      width: showLabel ? 45 : constraints.maxWidth,
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    if (showLabel)
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.8,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar({bool cartVisible = false}) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E6E8))),
      ),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: () => _openPage(
              const ButcherNotificationSettingsPage(),
              workspaceKey: 'notifications',
            ),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          if (cartVisible) ...[
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: () => _openPage(const MarketplaceProductsPage()),
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('My Cart'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F252B),
                side: const BorderSide(color: Color(0xFFE0E2E5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openSettings,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E2E5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: _darkRed,
                      child: Text(
                        (_businessName?.isNotEmpty ?? false)
                            ? _businessName![0].toUpperCase()
                            : 'B',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _businessName ?? 'Business',
                          style: const TextStyle(
                            fontSize: 10.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _businessType == 'supplier'
                              ? 'Supplier'
                              : 'Butcher Account',
                          style: const TextStyle(
                            color: Color(0xFF777B82),
                            fontSize: 9.2,
                          ),
                        ),
                      ],
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

  String _supplierCustomerName(Map<String, dynamic> order) {
    final businessRaw = order['businesses'];

    if (businessRaw is Map) {
      final business = Map<String, dynamic>.from(businessRaw);
      final trading = business['trading_name']?.toString().trim();

      if (trading != null && trading.isNotEmpty) {
        return trading;
      }

      final legal = business['legal_name']?.toString().trim();

      if (legal != null && legal.isNotEmpty) {
        return legal;
      }
    }

    if (businessRaw is List && businessRaw.isNotEmpty) {
      final first = businessRaw.first;

      if (first is Map) {
        final business = Map<String, dynamic>.from(first);
        final trading = business['trading_name']?.toString().trim();

        if (trading != null && trading.isNotEmpty) {
          return trading;
        }

        final legal = business['legal_name']?.toString().trim();

        if (legal != null && legal.isNotEmpty) {
          return legal;
        }
      }
    }

    final accountRaw = order['supplier_customer_accounts'];

    if (accountRaw is Map) {
      final account = Map<String, dynamic>.from(accountRaw);
      final name = account['customer_name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }

      final legal = account['legal_name']?.toString().trim();

      if (legal != null && legal.isNotEmpty) {
        return legal;
      }
    }

    if (accountRaw is List && accountRaw.isNotEmpty) {
      final first = accountRaw.first;

      if (first is Map) {
        final account = Map<String, dynamic>.from(first);
        final name = account['customer_name']?.toString().trim();

        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    }

    return 'Customer';
  }

  List<Map<String, dynamic>> _workOrdersForSupplierOrder(
    Map<String, dynamic> order,
  ) {
    final raw = order['warehouse_work_orders'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    if (raw is Map) {
      return [Map<String, dynamic>.from(raw)];
    }

    return const <Map<String, dynamic>>[];
  }

  int get _supplierOrdersToProcess {
    const activeStatuses = <String>{
      'submitted',
      'accepted',
      'processing',
      'ready',
    };

    return _supplierOrders.where((order) {
      return activeStatuses.contains(order['status']?.toString());
    }).length;
  }

  int get _supplierOpenWorkOrders {
    var count = 0;

    for (final order in _supplierOrders) {
      for (final workOrder in _workOrdersForSupplierOrder(order)) {
        final status = workOrder['status']?.toString();

        if (status != 'completed' &&
            status != 'cancelled' &&
            status != 'closed') {
          count++;
        }
      }
    }

    return count;
  }

  int get _supplierInvoicesToIssue {
    return _supplierInvoices.where((invoice) {
      return invoice['status']?.toString() == 'ready';
    }).length;
  }

  double get _supplierInvoicesToIssueValue {
    return _supplierInvoices.fold<double>(0, (sum, invoice) {
      if (invoice['status']?.toString() != 'ready') {
        return sum;
      }

      return sum + _asDouble(invoice['total_amount']);
    });
  }

  double get _supplierReceivables {
    return _supplierAccounts.fold<double>(
      0,
      (sum, account) => sum + _asDouble(account['outstanding_balance']),
    );
  }

  double get _supplierOverdueReceivables {
    return _supplierAccounts.fold<double>(
      0,
      (sum, account) => sum + _asDouble(account['overdue_amount']),
    );
  }

  int get _supplierOverdueAccountCount {
    return _supplierAccounts.where((account) {
      return _asDouble(account['overdue_amount']) > 0;
    }).length;
  }

  int get _supplierLowStockCount {
    return _supplierProducts.where((product) {
      final availability = product['availability_status']?.toString();
      final quantity = _asDouble(product['available_quantity']);

      return availability == 'out_of_stock' ||
          availability == 'low_stock' ||
          quantity <= 0;
    }).length;
  }

  int get _supplierActiveProductCount => _supplierProducts.length;

  List<Map<String, dynamic>> get _supplierRecentOrders {
    return _supplierOrders.take(5).toList();
  }

  List<Map<String, dynamic>> get _supplierTopAccounts {
    final copy = [..._supplierAccounts];

    copy.sort(
      (a, b) => _asDouble(
        b['outstanding_balance'],
      ).compareTo(_asDouble(a['outstanding_balance'])),
    );

    return copy.take(5).toList();
  }

  List<Map<String, dynamic>> get _supplierActiveWorkOrders {
    final rows = <Map<String, dynamic>>[];

    for (final order in _supplierOrders) {
      for (final workOrder in _workOrdersForSupplierOrder(order)) {
        final status = workOrder['status']?.toString();

        if (status == 'completed' ||
            status == 'cancelled' ||
            status == 'closed') {
          continue;
        }

        rows.add({
          'customer_name': _supplierCustomerName(order),
          'order_number': order['order_number'],
          'requested_fulfilment_date': order['requested_fulfilment_date'],
          'requested_fulfilment_time': order['requested_fulfilment_time'],
          'status': status,
          ...workOrder,
        });
      }
    }

    return rows.take(5).toList();
  }

  List<_MonthlySpend> get _supplierSixMonthSales {
    final now = DateTime.now();
    final months = <_MonthlySpend>[];

    for (var offset = 5; offset >= 0; offset--) {
      final monthDate = DateTime(now.year, now.month - offset, 1);
      var total = 0.0;

      for (final order in _supplierOrders) {
        final rawDate = order['submitted_at'] ?? order['created_at'];
        final date = DateTime.tryParse(rawDate?.toString() ?? '')?.toLocal();

        if (date == null ||
            date.year != monthDate.year ||
            date.month != monthDate.month) {
          continue;
        }

        final status = order['status']?.toString();

        if (status == 'cancelled' || status == 'declined') {
          continue;
        }

        total += _asDouble(order['total_amount']);
      }

      months.add(_MonthlySpend(month: monthDate, amount: total));
    }

    return months;
  }

  String get _supplierTopCustomer {
    final totals = <String, double>{};

    for (final order in _supplierOrders) {
      final status = order['status']?.toString();

      if (status == 'cancelled' || status == 'declined') {
        continue;
      }

      final customer = _supplierCustomerName(order);

      totals[customer] =
          (totals[customer] ?? 0) + _asDouble(order['total_amount']);
    }

    if (totals.isEmpty) return '—';

    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _supplierOrderSourceLabel(Map<String, dynamic> order) {
    return order['order_source']?.toString() == 'marketplace'
        ? 'Marketplace'
        : 'Direct';
  }

  Color _supplierOrderSourceColor(Map<String, dynamic> order) {
    return order['order_source']?.toString() == 'marketplace'
        ? _darkRed
        : const Color(0xFF315A8C);
  }

  Widget _buildSupplierDashboard() {
    return Scaffold(
      backgroundColor: _canvas,
      body: Row(
        children: [
          _supplierSidebar(),
          Expanded(
            child: RepaintBoundary(
              child: _workspacePage != null
                  ? KeyedSubtree(
                      key: ValueKey(_workspaceKey),
                      child: _workspacePage!,
                    )
                  : Column(
                      children: [
                        _supplierTopBar(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadDashboard,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                28,
                              ),
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1500,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          '${_greeting()}, ${_businessName ?? 'Supplier'}',
                                          style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Here’s what’s happening across your sales and fulfilment today.',
                                          style: TextStyle(
                                            color: Color(0xFF6A6E75),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        _supplierSummaryGrid(),
                                        const SizedBox(height: 16),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            if (constraints.maxWidth < 1050) {
                                              return Column(
                                                children: [
                                                  _supplierAttentionCard(),
                                                  const SizedBox(height: 14),
                                                  _supplierOrdersCard(),
                                                  const SizedBox(height: 14),
                                                  _supplierWorkOrdersCard(),
                                                ],
                                              );
                                            }

                                            return Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 9,
                                                  child:
                                                      _supplierAttentionCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 13,
                                                  child: _supplierOrdersCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 11,
                                                  child:
                                                      _supplierWorkOrdersCard(),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            if (constraints.maxWidth < 1100) {
                                              return Column(
                                                children: [
                                                  _supplierAccountsOverviewCard(),
                                                  const SizedBox(height: 14),
                                                  _supplierInventorySnapshotCard(),
                                                  const SizedBox(height: 14),
                                                  _supplierSalesOverviewCard(),
                                                  const SizedBox(height: 14),
                                                  _supplierQuickActionsCard(),
                                                ],
                                              );
                                            }

                                            return Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 10,
                                                  child:
                                                      _supplierAccountsOverviewCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 8,
                                                  child:
                                                      _supplierInventorySnapshotCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 10,
                                                  child:
                                                      _supplierSalesOverviewCard(),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 7,
                                                  child:
                                                      _supplierQuickActionsCard(),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierSummaryGrid() {
    final cards = <Widget>[
      _summaryCard(
        icon: Icons.assignment_turned_in_outlined,
        label: 'Orders to Process',
        value: _supplierOrdersToProcess.toString(),
        support: 'Marketplace and direct orders',
      ),
      _summaryCard(
        icon: Icons.build_outlined,
        label: 'Open Work Orders',
        value: _supplierOpenWorkOrders.toString(),
        support: 'Warehouse jobs still active',
      ),
      _summaryCard(
        icon: Icons.request_quote_outlined,
        label: 'Invoices to Issue',
        value: _supplierInvoicesToIssue.toString(),
        support: _supplierInvoicesToIssueValue > 0
            ? '${_money(_supplierInvoicesToIssueValue)} ready'
            : 'Nothing waiting to issue',
      ),
      _summaryCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Outstanding Receivables',
        value: _money(_supplierReceivables),
        support: _supplierOverdueReceivables > 0
            ? '${_money(_supplierOverdueReceivables)} overdue'
            : 'No overdue balance',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1000) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(
                width: constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _supplierAttentionCard() {
    final items = <_AttentionItem>[];

    final marketplacePending = _supplierOrders.where((order) {
      return order['order_source']?.toString() == 'marketplace' &&
          order['status']?.toString() == 'submitted';
    }).length;

    if (marketplacePending > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.shopping_cart_checkout_outlined,
          tint: const Color(0xFFF8EDEE),
          iconColor: _darkRed,
          message:
              '$marketplacePending marketplace order${marketplacePending == 1 ? '' : 's'} await review',
          action: 'Review Orders',
          onTap: () =>
              _openPage(const SupplierUnifiedOrdersPage(embedded: true)),
        ),
      );
    }

    if (_supplierInvoicesToIssue > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.request_quote_outlined,
          tint: const Color(0xFFEAF2FB),
          iconColor: const Color(0xFF315A8C),
          message:
              '$_supplierInvoicesToIssue invoice${_supplierInvoicesToIssue == 1 ? '' : 's'} ready to issue',
          action: 'View Invoices',
          onTap: () => _openPage(
            const SupplierUnifiedOrdersPage(
              embedded: true,
              initialType: SupplierDocumentType.invoices,
            ),
          ),
        ),
      );
    }

    if (_supplierOverdueAccountCount > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.warning_amber_rounded,
          tint: const Color(0xFFFFF0E0),
          iconColor: const Color(0xFFB85C00),
          message:
              '$_supplierOverdueAccountCount account${_supplierOverdueAccountCount == 1 ? '' : 's'} have overdue balances',
          action: 'View Accounts',
          onTap: () =>
              _openPage(const SupplierCustomerRequestsPage(embedded: true)),
        ),
      );
    }

    if (_supplierLowStockCount > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.inventory_2_outlined,
          tint: const Color(0xFFF1ECFA),
          iconColor: const Color(0xFF6D378C),
          message:
              '$_supplierLowStockCount product${_supplierLowStockCount == 1 ? '' : 's'} need stock attention',
          action: 'View Inventory',
          onTap: () => _openPage(const SupplierInventoryPage(embedded: true)),
        ),
      );
    }

    if (_pendingVipApplications > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.workspace_premium_outlined,
          tint: const Color(0xFFFFF4D8),
          iconColor: const Color(0xFF8A6500),
          message:
              '$_pendingVipApplications VIP or credit application${_pendingVipApplications == 1 ? '' : 's'} waiting for review',
          action: 'Review',
          onTap: () =>
              _openPage(const SupplierCustomerRequestsPage(embedded: true)),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _AttentionItem(
          icon: Icons.check_circle_outline,
          tint: const Color(0xFFEAF6ED),
          iconColor: const Color(0xFF2E7D32),
          message: 'Nothing urgent needs your attention right now',
          action: 'View Orders',
          onTap: () =>
              _openPage(const SupplierUnifiedOrdersPage(embedded: true)),
        ),
      );
    }

    return _sectionCard(
      title: 'Needs Your Attention',
      trailing: items.length > 1 ? _smallBadge(items.length.toString()) : null,
      child: Column(
        children: [
          for (var i = 0; i < math.min(items.length, 5); i++) ...[
            _attentionRow(items[i]),
            if (i != math.min(items.length, 5) - 1)
              const Divider(height: 1, color: Color(0xFFE9EAEC)),
          ],
        ],
      ),
    );
  }

  Widget _supplierOrdersCard() {
    return _sectionCard(
      title: 'Today’s Orders',
      actionText: 'View All Orders',
      onAction: () =>
          _openPage(const SupplierUnifiedOrdersPage(embedded: true)),
      child: _supplierRecentOrders.isEmpty
          ? _emptyState(
              Icons.receipt_long_outlined,
              'No orders yet',
              'Supplier orders will appear here.',
            )
          : Column(
              children: [
                const _TableHeader(
                  cells: [
                    _TableHeaderCell('Order', 2),
                    _TableHeaderCell('Customer', 3),
                    _TableHeaderCell('Source', 2),
                    _TableHeaderCell('Fulfilment', 2),
                    _TableHeaderCell('Status', 2),
                  ],
                ),
                for (final order in _supplierRecentOrders)
                  InkWell(
                    onTap: () => _openPage(
                      const SupplierUnifiedOrdersPage(embedded: true),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE9EAEC)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tableCell(
                            order['order_number']?.toString() ?? 'Order',
                            flex: 2,
                            strong: true,
                          ),
                          _tableCell(_supplierCustomerName(order), flex: 3),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _statusChip(
                                _supplierOrderSourceLabel(order),
                                _supplierOrderSourceColor(order),
                              ),
                            ),
                          ),
                          _tableCell(
                            order['fulfilment_method']?.toString() == 'pickup'
                                ? 'Pickup'
                                : 'Delivery',
                            flex: 2,
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _statusChip(
                                _orderStatusLabel(order['status']?.toString()),
                                _orderStatusColor(order['status']?.toString()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _supplierWorkOrdersCard() {
    final rows = _supplierActiveWorkOrders;

    return _sectionCard(
      title: 'Work Orders',
      actionText: 'View All',
      onAction: () => _openPage(
        const SupplierUnifiedOrdersPage(
          embedded: true,
          initialType: SupplierDocumentType.workOrders,
        ),
      ),
      child: rows.isEmpty
          ? _emptyState(
              Icons.build_outlined,
              'No open work orders',
              'Active picking and fulfilment jobs will appear here.',
            )
          : Column(
              children: [
                const _TableHeader(
                  cells: [
                    _TableHeaderCell('Customer', 3),
                    _TableHeaderCell('Work Order', 2),
                    _TableHeaderCell('Requested', 2),
                    _TableHeaderCell('Status', 2),
                  ],
                ),
                for (final row in rows)
                  InkWell(
                    onTap: () => _openPage(
                      const SupplierUnifiedOrdersPage(
                        embedded: true,
                        initialType: SupplierDocumentType.workOrders,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE9EAEC)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tableCell(
                            row['customer_name']?.toString() ?? 'Customer',
                            flex: 3,
                            strong: true,
                          ),
                          _tableCell(
                            row['work_order_number']?.toString() ??
                                row['order_number']?.toString() ??
                                'Work Order',
                            flex: 2,
                          ),
                          _tableCell(
                            _date(row['requested_fulfilment_date']),
                            flex: 2,
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _statusChip(
                                _orderStatusLabel(row['status']?.toString()),
                                _orderStatusColor(row['status']?.toString()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _supplierAccountsOverviewCard() {
    return _sectionCard(
      title: 'Accounts Overview',
      actionText: 'View All Accounts',
      onAction: () =>
          _openPage(const SupplierCustomerRequestsPage(embedded: true)),
      child: _supplierTopAccounts.isEmpty
          ? _emptyState(
              Icons.account_balance_wallet_outlined,
              'No account balances',
              'Customer receivables will appear here.',
            )
          : Column(
              children: [
                const _TableHeader(
                  cells: [
                    _TableHeaderCell('Customer', 3),
                    _TableHeaderCell('Outstanding', 2),
                    _TableHeaderCell('Overdue', 2),
                    _TableHeaderCell('Status', 2),
                  ],
                ),
                for (final account in _supplierTopAccounts)
                  InkWell(
                    onTap: () => _openPage(
                      const SupplierCustomerRequestsPage(embedded: true),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE9EAEC)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tableCell(
                            account['customer_name']?.toString() ?? 'Customer',
                            flex: 3,
                            strong: true,
                          ),
                          _tableCell(
                            _money(account['outstanding_balance']),
                            flex: 2,
                            strong: true,
                          ),
                          _tableCell(
                            _money(account['overdue_amount']),
                            flex: 2,
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Builder(
                                builder: (_) {
                                  final overdue = _asDouble(
                                    account['overdue_amount'],
                                  );

                                  final outstanding = _asDouble(
                                    account['outstanding_balance'],
                                  );

                                  final status = overdue > 0
                                      ? 'Overdue'
                                      : outstanding > 0
                                      ? 'Current'
                                      : 'Paid';

                                  final color = overdue > 0
                                      ? const Color(0xFFB3261E)
                                      : outstanding > 0
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF666666);

                                  return _statusChip(status, color);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _supplierInventorySnapshotCard() {
    final availableCount = _supplierProducts.where((product) {
      final status = product['availability_status']?.toString();
      final quantity = _asDouble(product['available_quantity']);

      return status != 'out_of_stock' && quantity > 0;
    }).length;

    return _sectionCard(
      title: 'Inventory Snapshot',
      actionText: 'View Inventory',
      onAction: () => _openPage(const SupplierInventoryPage(embedded: true)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _supplierInventoryMetric(
            Icons.inventory_2_outlined,
            'Active products',
            _supplierActiveProductCount.toString(),
          ),
          const SizedBox(height: 12),
          _supplierInventoryMetric(
            Icons.check_circle_outline,
            'Available',
            availableCount.toString(),
          ),
          const SizedBox(height: 12),
          _supplierInventoryMetric(
            Icons.warning_amber_rounded,
            'Needs stock attention',
            _supplierLowStockCount.toString(),
            warning: _supplierLowStockCount > 0,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () =>
                _openPage(const SupplierInventoryPage(embedded: true)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _darkRed,
              side: const BorderSide(color: Color(0xFFDDB7BC)),
            ),
            icon: const Icon(Icons.inventory_outlined, size: 17),
            label: const Text('Manage Inventory'),
          ),
        ],
      ),
    );
  }

  Widget _supplierInventoryMetric(
    IconData icon,
    String label,
    String value, {
    bool warning = false,
  }) {
    final color = warning ? const Color(0xFFB85C00) : _darkRed;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E9EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF62666D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierSalesOverviewCard() {
    final months = _supplierSixMonthSales;
    final maxValue = months.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.amount),
    );

    final total = months.fold<double>(0, (sum, item) => sum + item.amount);

    return _sectionCard(
      title: 'Sales Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _supplierHeadlineMetric('Total Sales', _money(total)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _supplierHeadlineMetric(
                  'Top Customer',
                  _supplierTopCustomer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < months.length; i++) ...[
                  Expanded(child: _supplierMonthBar(months[i], maxValue)),
                  if (i != months.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierHeadlineMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF73777E),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _supplierMonthBar(_MonthlySpend item, double maxValue) {
    final ratio = maxValue <= 0 ? 0.05 : item.amount / maxValue;

    const months = <String>[
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          item.amount <= 0 ? '—' : _shortMoney(item.amount),
          maxLines: 1,
          style: const TextStyle(fontSize: 9.3, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: math.max(0.04, ratio),
              child: Container(
                decoration: BoxDecoration(
                  color: _darkRed,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          months[item.month.month - 1],
          style: const TextStyle(color: Color(0xFF6E7278), fontSize: 10),
        ),
      ],
    );
  }

  Widget _supplierQuickActionsCard() {
    return _sectionCard(
      title: 'Quick Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _quickAction(
            Icons.add_shopping_cart_outlined,
            'New Sale',
            () => _openPage(const SupplierSalesPage(embedded: true)),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.shopping_cart_checkout_outlined,
            'Review Orders',
            () => _openPage(const SupplierUnifiedOrdersPage(embedded: true)),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.build_outlined,
            'Open Work Orders',
            () => _openPage(
              const SupplierUnifiedOrdersPage(
                embedded: true,
                initialType: SupplierDocumentType.workOrders,
              ),
            ),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.request_quote_outlined,
            'Issue Invoices',
            () => _openPage(
              const SupplierUnifiedOrdersPage(
                embedded: true,
                initialType: SupplierDocumentType.invoices,
              ),
            ),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.people_alt_outlined,
            'Customers & Accounts',
            () => _openPage(const SupplierCustomerRequestsPage(embedded: true)),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.inventory_2_outlined,
            'Manage Inventory',
            () => _openPage(const SupplierInventoryPage(embedded: true)),
          ),
        ],
      ),
    );
  }

  Widget _supplierSidebar() {
    return _sidebarTransitionFrame(
      child: SafeArea(
        child: Column(
          children: [
            _sidebarHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _sideItem(
                    Icons.grid_view_rounded,
                    'Dashboard',
                    selected: _workspaceKey == 'dashboard',
                    onTap: _openDashboard,
                  ),
                  _sideItem(
                    Icons.point_of_sale_outlined,
                    'Sales',
                    selected: _workspaceKey == 'sales',
                    onTap: () =>
                        _openPage(const SupplierSalesPage(embedded: true)),
                  ),
                  _sideItem(
                    Icons.receipt_long_outlined,
                    'Orders',
                    selected: _workspaceKey == 'orders',
                    onTap: () => _openPage(
                      const SupplierUnifiedOrdersPage(embedded: true),
                    ),
                  ),
                  _sideItem(
                    Icons.inventory_2_outlined,
                    'Inventory',
                    selected: _workspaceKey == 'inventory',
                    onTap: () =>
                        _openPage(const SupplierInventoryPage(embedded: true)),
                  ),
                  _sideItem(
                    Icons.price_change_outlined,
                    'Pricing',
                    selected: _workspaceKey == 'pricing',
                    onTap: () => _openPage(
                      const SupplierInventoryPage(
                        embedded: true,
                        initialTabIndex: 1,
                      ),
                      workspaceKey: 'pricing',
                    ),
                  ),
                  _sideItem(
                    Icons.people_alt_outlined,
                    'Customers & Accounts',
                    selected: _workspaceKey == 'customers',
                    onTap: () => _openPage(
                      const SupplierCustomerRequestsPage(embedded: true),
                    ),
                  ),
                  _sideItem(
                    Icons.local_shipping_outlined,
                    'Delivery',
                    selected: _workspaceKey == 'delivery',
                    onTap: () =>
                        _openPage(const SupplierDeliverySettingsPage()),
                  ),
                  _sideItem(
                    Icons.bar_chart_outlined,
                    'Analytics',
                    selected: _workspaceKey == 'analytics',
                    onTap: () => _openDashboard(workspaceKey: 'analytics'),
                  ),
                  _sideItem(
                    Icons.notifications_none_rounded,
                    'Notifications',
                    selected: _workspaceKey == 'notifications',
                    onTap: () => _openPage(
                      const SupplierNotificationSettingsPage(),
                      workspaceKey: 'notifications',
                    ),
                  ),
                  _sideItem(
                    Icons.settings_outlined,
                    'Settings',
                    selected: _workspaceKey == 'settings',
                    onTap: () =>
                        _openPage(const SupplierSettingsPage(embedded: true)),
                  ),
                  if (_isAdmin)
                    _sideItem(
                      Icons.admin_panel_settings_outlined,
                      'Admin',
                      selected: _workspaceKey == 'admin',
                      onTap: () => _openPage(const PendingBusinessesPage()),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF263544))),
              ),
              child: Column(
                children: [
                  if (!_sidebarCollapsed)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 160) {
                          return const SizedBox.shrink();
                        }

                        return Material(
                          color: const Color(0xFF102335),
                          borderRadius: BorderRadius.circular(11),
                          child: InkWell(
                            onTap: _openSettings,
                            borderRadius: BorderRadius.circular(11),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _darkRed,
                                    child: Text(
                                      (_businessName?.isNotEmpty ?? false)
                                          ? _businessName![0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _businessName ?? 'Supplier',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const Text(
                                          'Supplier Account',
                                          style: TextStyle(
                                            color: Color(0xFFAAB4BE),
                                            fontSize: 9.8,
                                          ),
                                        ),
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
                  _sideItem(Icons.logout_rounded, 'Logout', onTap: _signOut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supplierTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E6E8))),
      ),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: () => _openPage(
              const SupplierNotificationSettingsPage(),
              workspaceKey: 'notifications',
            ),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _openPage(const SupplierSalesPage(embedded: true)),
            style: FilledButton.styleFrom(
              backgroundColor: _darkRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Sale'),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openSettings,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E2E5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: _darkRed,
                      child: Text(
                        (_businessName?.isNotEmpty ?? false)
                            ? _businessName![0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _businessName ?? 'Supplier',
                          style: const TextStyle(
                            fontSize: 10.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Supplier Account',
                          style: TextStyle(
                            color: Color(0xFF777B82),
                            fontSize: 9.2,
                          ),
                        ),
                      ],
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

  Widget _buildSupplierLegacyDashboard() {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadDashboard,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _signOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 50),
            children: [
              Text(
                'Welcome, ${_businessName ?? 'Business'}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Supplier',
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  double cardWidth;

                  if (constraints.maxWidth >= 900) {
                    cardWidth = (constraints.maxWidth - 32) / 3;
                  } else if (constraints.maxWidth >= 600) {
                    cardWidth = (constraints.maxWidth - 16) / 2;
                  } else {
                    cardWidth = constraints.maxWidth;
                  }

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.point_of_sale_outlined,
                        title: 'Sales',
                        description:
                            'Search stock, create sales orders and manage the sales workflow.',
                        badgeCount: _newSupplierOrderCount,
                        onTap: () =>
                            _openPage(const SupplierSalesPage(embedded: true)),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.inventory_2_outlined,
                        title: 'Inventory',
                        description: 'Manage stock, products and pricing.',
                        onTap: () => _openPage(
                          const SupplierInventoryPage(embedded: true),
                        ),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.people_alt_outlined,
                        title: 'Customers & Accounts',
                        description:
                            'Manage members, external customers and account terms.',
                        onTap: () => _openPage(
                          const SupplierCustomerRequestsPage(embedded: true),
                        ),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.assignment_outlined,
                        title: 'Work Orders',
                        description:
                            'Manage warehouse picking, weighing and fulfilment.',
                        onTap: () => _openPage(
                          const SupplierUnifiedOrdersPage(
                            embedded: true,
                            initialType: SupplierDocumentType.workOrders,
                          ),
                        ),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.request_quote_outlined,
                        title: 'Invoices',
                        description:
                            'View draft, issued, paid and outstanding invoices.',
                        onTap: () => _openPage(
                          const SupplierUnifiedOrdersPage(
                            embedded: true,
                            initialType: SupplierDocumentType.invoices,
                          ),
                        ),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.local_shipping_outlined,
                        title: 'Delivery',
                        description:
                            'Manage delivery days, zones and minimum orders.',
                        onTap: () =>
                            _openPage(const SupplierDeliverySettingsPage()),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        description:
                            'Configure business, invoicing and banking settings.',
                        onTap: () => _openPage(
                          const SupplierSettingsPage(embedded: true),
                        ),
                      ),
                      if (_isAdmin)
                        _LegacyDashboardCard(
                          width: cardWidth,
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Admin',
                          description: 'Review pending business applications.',
                          onTap: () => _openPage(const PendingBusinessesPage()),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReorderItem {
  const _QuickReorderItem({
    required this.productName,
    required this.supplierName,
    required this.unitPrice,
    required this.priceBasis,
    required this.lastOrdered,
  });

  final String productName;
  final String supplierName;
  final double unitPrice;
  final String? priceBasis;
  final DateTime? lastOrdered;
}

class _MonthlySpend {
  const _MonthlySpend({required this.month, required this.amount});

  final DateTime month;
  final double amount;
}

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.message,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String message;
  final String action;
  final VoidCallback onTap;
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.cells});

  final List<_TableHeaderCell> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              flex: cell.flex,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  cell.label,
                  style: const TextStyle(
                    color: Color(0xFF74787F),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableHeaderCell {
  const _TableHeaderCell(this.label, this.flex);

  final String label;
  final int flex;
}

class _LegacyDashboardCard extends StatelessWidget {
  const _LegacyDashboardCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.badgeCount = 0,
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFE0E0DD)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4E5E5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF741C1C),
                        size: 28,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB3261E),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF666666), height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
