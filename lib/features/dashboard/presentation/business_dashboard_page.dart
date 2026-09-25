import '../../../shared/widgets/workspace_back_button.dart';
import '../../../shared/widgets/phone_layout.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/formatters/order_reference.dart';

import '../../admin/presentation/pending_businesses_page.dart';
import 'business_analytics_page.dart';
import 'butcher_favourite_products_panel.dart';
import '../../customers/presentation/supplier_customer_requests_page.dart';
import '../../delivery/presentation/supplier_delivery_settings_page.dart';
import '../../marketplace/presentation/butcher_vip_suppliers_page.dart';
import '../../marketplace/presentation/marketplace_products_page.dart';
import '../../marketplace/presentation/butcher_favourites_page.dart';
import '../../orders/presentation/butcher_accounts_page.dart';
import '../../orders/presentation/draft_orders_page.dart';
import '../../orders/presentation/butcher_settings_page.dart';
import '../../orders/presentation/submitted_orders_page.dart';
import '../../orders/presentation/supplier_inventory_page.dart';
import '../../orders/presentation/supplier_orders_page.dart';
import '../../orders/presentation/supplier_invoices_page.dart';
import '../../orders/presentation/supplier_sales_page.dart';
import '../../orders/presentation/supplier_settings_page.dart';
import '../../orders/presentation/supplier_unified_orders_page.dart';
import '../../orders/presentation/supplier_work_orders_page.dart';
import '../../support/presentation/support_center_page.dart';

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
  final _mobileNavigationScroll = ScrollController();
  bool get _useBottomNavigation => isPhoneLayout(context);

  Widget? _workspacePage;
  String _workspaceKey = 'dashboard';

  int _newSupplierOrderCount = 0;
  int _butcherCartItemCount = 0;
  int _supportUnreadCount = 0;

  String? _errorMessage;
  String? _businessId;
  String? _businessName;
  String? _businessType;
  String? _businessLogoUrl;

  List<Map<String, dynamic>> _butcherOrders = [];
  double _invoicedThisMonth = 0;
  List<Map<String, dynamic>> _butcherAccounts = [];

  List<Map<String, dynamic>> _supplierOrders = [];
  List<Map<String, dynamic>> _supplierAccounts = [];
  List<Map<String, dynamic>> _supplierInvoices = [];
  List<Map<String, dynamic>> _supplierProducts = [];
  List<Map<String, dynamic>> _supplierDeliveryRuns = [];
  int _pendingVipApplications = 0;

  List<_DashboardTilePreference> _dashboardPreferences = [];

  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeRefreshTimer;
  String? _realtimeBusinessId;
  String? _realtimeBusinessType;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _mobileNavigationScroll.dispose();
    _realtimeRefreshTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _loadDashboard({bool showLoading = true}) async {
    if (showLoading) {
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

      final profileRows = await client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .limit(1);

      final isAdmin =
          profileRows.isNotEmpty &&
          (profileRows.first['is_admin'] as bool? ?? false);

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
            active,
            logo_path
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
      final logoPath = business['logo_path']?.toString().trim() ?? '';
      final businessLogoUrl = logoPath.isEmpty
          ? null
          : client.storage.from('business-branding').getPublicUrl(logoPath);

      var newSupplierOrderCount = 0;
      var butcherOrders = <Map<String, dynamic>>[];
      var butcherInvoicedThisMonth = 0.0;
      var butcherAccounts = <Map<String, dynamic>>[];
      var butcherCartItemCount = 0;

      var supplierOrders = <Map<String, dynamic>>[];
      var supplierAccounts = <Map<String, dynamic>>[];
      var supplierInvoices = <Map<String, dynamic>>[];
      var supplierProducts = <Map<String, dynamic>>[];
      var supplierDeliveryRuns = <Map<String, dynamic>>[];
      var pendingVipApplications = 0;
      var supportUnreadCount = 0;

      var supportQuery = client.from('support_tickets').select('''
        last_message_at,
        requester_last_read_at,
        admin_last_read_at
      ''');
      if (!isAdmin) {
        supportQuery = supportQuery.eq('business_id', businessId);
      }
      final supportRows = await supportQuery;
      for (final row in supportRows) {
        final lastMessageAt = DateTime.tryParse(
          row['last_message_at']?.toString() ?? '',
        );
        final lastReadAt = DateTime.tryParse(
          row[isAdmin ? 'admin_last_read_at' : 'requester_last_read_at']
                  ?.toString() ??
              '',
        );
        if (lastMessageAt != null &&
            (lastReadAt == null || lastMessageAt.isAfter(lastReadAt))) {
          supportUnreadCount++;
        }
      }

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
              ready_for_pickup_at,
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

        final deliveryRunResponse = await client
            .from('supplier_delivery_runs')
            .select('''
              id,
              run_number,
              delivery_date,
              status,
              driver_id,
              vehicle_id,
              loaded_at,
              started_at,
              completed_at,
              supplier_delivery_run_stops(
                id,
                order_id,
                status
              )
            ''')
            .eq('supplier_business_id', businessId)
            .order('delivery_date', ascending: false)
            .order('created_at', ascending: false)
            .limit(80);

        supplierDeliveryRuns = List<Map<String, dynamic>>.from(
          deliveryRunResponse as List,
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
              fulfilment_method,
              requested_fulfilment_date,
              requested_fulfilment_time,
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
        butcherInvoicedThisMonth = await _loadButcherInvoicedThisMonth(
          businessId,
        );

        final cartRows = await client
            .from('orders')
            .select('id, order_items(id)')
            .eq('butcher_business_id', businessId)
            .eq('status', 'draft');
        for (final raw in cartRows) {
          final items = raw['order_items'];
          if (items is List) {
            butcherCartItemCount += items.length;
          }
        }

        final accountResponse = await client.rpc(
          'list_butcher_supplier_account_summaries',
          params: {'due_soon_days': 7},
        );

        butcherAccounts = List<Map<String, dynamic>>.from(
          accountResponse as List,
        );
      }

      List<_DashboardTilePreference> loadedDashboardPreferences = [];
      try {
        final preferenceRows = await client
            .from('user_dashboard_preferences')
            .select('layout')
            .eq('user_id', user.id)
            .eq('business_id', businessId)
            .limit(1);
        if (preferenceRows.isNotEmpty) {
          loadedDashboardPreferences = _dashboardPreferencesFromJson(
            preferenceRows.first['layout'],
          );
        }
      } on PostgrestException {
        // Dashboard preferences are optional; defaults remain available.
      }

      loadedDashboardPreferences = _normaliseDashboardPreferences(
        businessType ?? '',
        loadedDashboardPreferences,
      );

      if (!mounted) return;

      setState(() {
        _businessId = businessId;
        _businessName = businessName;
        _businessType = businessType;
        _businessLogoUrl = businessLogoUrl;
        _dashboardPreferences = loadedDashboardPreferences;
        _isAdmin = isAdmin;
        _newSupplierOrderCount = newSupplierOrderCount;
        _butcherOrders = butcherOrders;
        _invoicedThisMonth = butcherInvoicedThisMonth;
        _butcherAccounts = butcherAccounts;
        _butcherCartItemCount = butcherCartItemCount;
        _supportUnreadCount = supportUnreadCount;
        _supplierOrders = supplierOrders;
        _supplierAccounts = supplierAccounts;
        _supplierInvoices = supplierInvoices;
        _supplierProducts = supplierProducts;
        _supplierDeliveryRuns = supplierDeliveryRuns;
        _pendingVipApplications = pendingVipApplications;
        _isLoading = false;
      });

      _ensureRealtimeSubscription(businessId, businessType ?? '');
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

  void _ensureRealtimeSubscription(String businessId, String businessType) {
    if (_realtimeBusinessId == businessId &&
        _realtimeBusinessType == businessType &&
        _realtimeChannel != null) {
      return;
    }

    _realtimeRefreshTimer?.cancel();
    final oldChannel = _realtimeChannel;
    if (oldChannel != null) {
      Supabase.instance.client.removeChannel(oldChannel);
    }

    _realtimeBusinessId = businessId;
    _realtimeBusinessType = businessType;

    void scheduleRefresh(PostgresChangePayload _) {
      _realtimeRefreshTimer?.cancel();
      _realtimeRefreshTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) {
          _loadDashboard(showLoading: false);
        }
      });
    }

    final businessColumn = businessType == 'butcher'
        ? 'butcher_business_id'
        : 'supplier_business_id';
    var channel = Supabase.instance.client
        .channel('cutlink-dashboard-$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: businessColumn,
            value: businessId,
          ),
          callback: scheduleRefresh,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invoices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: businessColumn,
            value: businessId,
          ),
          callback: scheduleRefresh,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_tickets',
          filter: _isAdmin
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'business_id',
                  value: businessId,
                ),
          callback: scheduleRefresh,
        );

    if (businessType == 'supplier') {
      channel = channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'warehouse_work_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'supplier_business_id',
              value: businessId,
            ),
            callback: scheduleRefresh,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'supplier_business_id',
              value: businessId,
            ),
            callback: scheduleRefresh,
          );
    }

    _realtimeChannel = channel.subscribe();
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
    if (page is BusinessAnalyticsPage) return 'analytics';
    if (page is SupportCenterPage) return 'support';

    if (page is SupplierSalesPage) return 'sales';
    if (page is SupplierUnifiedOrdersPage) return 'invoices';
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
    if (_workspacePage != null &&
        _workspaceKey == nextKey &&
        _workspacePage.runtimeType == page.runtimeType) {
      return;
    }

    setState(() {
      _workspaceKey = nextKey;
      _workspacePage = page;
    });
  }

  Future<void> _openButcherCart() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DraftOrdersPage()));

    if (!mounted) return;
    await _loadDashboard();
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarCollapsed = !_sidebarCollapsed;
    });
  }

  Widget _sidebarTransitionFrame({required Widget child}) {
    final visualWidth = _sidebarCollapsed
        ? _collapsedSidebarWidth
        : _expandedSidebarWidth;

    return AnimatedContainer(
      duration: _sidebarAnimationDuration,
      curve: Curves.easeOutCubic,
      width: visualWidth,
      color: _deepNavy,
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  void _openAnalytics() {
    final businessId = _businessId;
    final businessType = _businessType;
    if (businessId == null || businessType == null) return;

    _openPage(
      BusinessAnalyticsPage(
        businessId: businessId,
        businessType: businessType,
        businessName: _businessName ?? 'Business',
      ),
      workspaceKey: 'analytics',
    );
  }

  void _openSettings() {
    if (_businessType == 'butcher') {
      _openPage(const ButcherSettingsPage());
      return;
    }

    _openPage(
      SupplierSettingsPage(
        embedded: true,
        onBrandingChanged: () {
          _refreshBusinessBranding();
        },
      ),
    );
  }

  void _openSupport() {
    final businessId = _businessId;
    if (businessId == null) return;

    _openPage(
      SupportCenterPage(businessId: businessId, adminMode: _isAdmin),
      workspaceKey: 'support',
    );
  }

  Future<void> _refreshBusinessBranding() async {
    final businessId = _businessId;
    if (businessId == null) return;

    try {
      final client = Supabase.instance.client;
      final business = await client
          .from('businesses')
          .select('trading_name, legal_name, logo_path')
          .eq('id', businessId)
          .single();
      if (!mounted) return;

      final tradingName = business['trading_name']?.toString().trim() ?? '';
      final legalName = business['legal_name']?.toString().trim() ?? '';
      final logoPath = business['logo_path']?.toString().trim() ?? '';
      final logoUrl = logoPath.isEmpty
          ? null
          : client.storage.from('business-branding').getPublicUrl(logoPath);

      setState(() {
        _businessName = tradingName.isNotEmpty
            ? tradingName
            : legalName.isNotEmpty
            ? legalName
            : _businessName;
        _businessLogoUrl = logoUrl;
      });
    } catch (_) {
      // Branding refresh is cosmetic; keep the existing dashboard state.
    }
  }

  Widget _businessLogoBadge({required double size, required String fallback}) {
    final logoUrl = _businessLogoUrl;

    Widget fallbackWidget() => Center(
      child: Text(
        (_businessName?.isNotEmpty ?? false)
            ? _businessName![0].toUpperCase()
            : fallback,
        style: TextStyle(
          color: Colors.white,
          fontSize: size <= 30 ? 11 : 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      padding: logoUrl == null ? EdgeInsets.zero : const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: logoUrl == null ? _darkRed : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: logoUrl == null
            ? null
            : Border.all(color: const Color(0xFFD9DDE1)),
      ),
      child: logoUrl == null
          ? fallbackWidget()
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.20),
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallbackWidget(),
              ),
            ),
    );
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

  int get _ordersThisMonth {
    final now = DateTime.now();

    return _butcherOrders.where((order) {
      final date = _orderDate(order);
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
  }

  Future<double> _loadButcherInvoicedThisMonth(String businessId) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
    ).toIso8601String().substring(0, 10);
    final end = DateTime(
      now.year,
      now.month + 1,
    ).toIso8601String().substring(0, 10);
    var cents = 0;
    // Read only this month's sent invoices, without the recent-order row limit.
    for (var offset = 0; ; offset += 500) {
      final rows = await Supabase.instance.client
          .from('invoices')
          .select('id,total_amount')
          .eq('butcher_business_id', businessId)
          .inFilter('status', ['issued', 'part_paid', 'paid'])
          .not('sent_to_butcher_at', 'is', null)
          .gte('invoice_date', start)
          .lt('invoice_date', end)
          .order('id')
          .range(offset, offset + 499);
      for (final row in rows) {
        cents += (_asDouble(row['total_amount']) * 100).round();
      }
      if (rows.length < 500) {
        break;
      }
    }
    return cents / 100;
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
      bottomNavigationBar:
          _useBottomNavigation && MediaQuery.viewInsetsOf(context).bottom == 0
          ? _mobileNavigation(supplier: false)
          : null,
      body: PhoneSafeArea(
        child: Row(
          children: [
            if (!_useBottomNavigation) _butcherSidebar(),
            Expanded(
              child: RepaintBoundary(
                child: _workspacePage != null
                    ? KeyedSubtree(
                        key: ValueKey(_workspaceKey),
                        child: WorkspaceBackScope(
                          onBack: () => _openDashboard(),
                          child: _workspacePage!,
                        ),
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
                                          _dashboardHeading(
                                            title:
                                                '${_greeting()}, ${_businessName ?? 'Butcher'}',
                                            subtitle:
                                                'Here’s what’s happening with your purchasing today.',
                                          ),
                                          const SizedBox(height: 18),
                                          _summaryGrid(),
                                          const SizedBox(height: 16),
                                          _buildCustomDashboardGrid(),
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
      ),
    );
  }

  Widget _dashboardHeading({required String title, required String subtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = OutlinedButton.icon(
          onPressed: _showDashboardCustomiser,
          icon: const Icon(Icons.dashboard_customize_outlined, size: 17),
          label: const Text('Customise dashboard'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF33383E),
            side: const BorderSide(color: Color(0xFFDADDE1)),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6A6E75),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 12),
              controls,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6A6E75),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            controls,
          ],
        );
      },
    );
  }

  List<_DashboardTilePreference> _defaultDashboardPreferences(String type) {
    final ids = type == 'supplier'
        ? const <String>[
            'supplier_attention',
            'supplier_orders',
            'supplier_work_orders',
            'supplier_accounts',
            'supplier_inventory',
            'supplier_sales',
            'supplier_support',
            'supplier_quick_actions',
          ]
        : const <String>[
            'butcher_attention',
            'butcher_recent_orders',
            'butcher_supplier_accounts',
            'butcher_delivery',
            'butcher_quick_reorder',
            'butcher_purchasing',
            'butcher_support',
            'butcher_quick_actions',
          ];

    return [
      for (final id in ids)
        _DashboardTilePreference(
          id: id,
          visible: true,
          wide: id == 'butcher_purchasing' || id == 'supplier_sales',
        ),
    ];
  }

  List<_DashboardTilePreference> _dashboardPreferencesFromJson(dynamic raw) {
    if (raw is! List) return [];
    final result = <_DashboardTilePreference>[];
    for (final item in raw) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        result.add(
          _DashboardTilePreference(
            id: id,
            visible: map['visible'] != false,
            wide: map['wide'] == true,
          ),
        );
      }
    }
    return result;
  }

  List<_DashboardTilePreference> _normaliseDashboardPreferences(
    String type,
    List<_DashboardTilePreference> current,
  ) {
    final defaults = _defaultDashboardPreferences(type);
    final allowed = defaults.map((item) => item.id).toSet();
    final result = <_DashboardTilePreference>[];

    for (final item in current) {
      if (allowed.contains(item.id) &&
          !result.any((existing) => existing.id == item.id)) {
        result.add(item.copy());
      }
    }

    for (final item in defaults) {
      if (!result.any((existing) => existing.id == item.id)) {
        result.add(item.copy());
      }
    }

    return result;
  }

  String _dashboardTileTitle(String id) {
    switch (id) {
      case 'supplier_attention':
      case 'butcher_attention':
        return 'Needs Attention';
      case 'supplier_orders':
        return 'Recent Orders';
      case 'supplier_work_orders':
        return 'Work Orders';
      case 'supplier_accounts':
        return 'Accounts Overview';
      case 'supplier_inventory':
        return 'Inventory Snapshot';
      case 'supplier_sales':
        return 'Sales Overview';
      case 'supplier_support':
      case 'butcher_support':
        return 'CutLink Support';
      case 'supplier_quick_actions':
      case 'butcher_quick_actions':
        return 'Quick Actions';
      case 'butcher_recent_orders':
        return 'Recent Orders';
      case 'butcher_supplier_accounts':
        return 'Supplier Accounts';
      case 'butcher_delivery':
        return 'Delivery Operations';
      case 'butcher_quick_reorder':
        return 'Favourite Products';
      case 'butcher_purchasing':
        return 'Purchasing Overview';
      default:
        return 'Dashboard Card';
    }
  }

  Widget _dashboardTileWidget(String id) {
    switch (id) {
      case 'supplier_attention':
        return _supplierAttentionCard();
      case 'supplier_orders':
        return _supplierOrdersCard();
      case 'supplier_work_orders':
        return _supplierWorkOrdersCard();
      case 'supplier_accounts':
        return _supplierAccountsOverviewCard();
      case 'supplier_inventory':
        return _supplierInventorySnapshotCard();
      case 'supplier_sales':
        return _supplierSalesOverviewCard();
      case 'supplier_support':
        return _supportDashboardCard();
      case 'supplier_quick_actions':
        return _supplierQuickActionsCard();
      case 'butcher_attention':
        return _attentionCard();
      case 'butcher_recent_orders':
        return _recentOrdersCard();
      case 'butcher_supplier_accounts':
        return _supplierAccountsCard();
      case 'butcher_delivery':
        return _butcherDeliveryOperationsCard();
      case 'butcher_quick_reorder':
        return _favouriteProductsCard();
      case 'butcher_purchasing':
        return _purchasingOverviewCard();
      case 'butcher_support':
        return _supportDashboardCard();
      case 'butcher_quick_actions':
        return _quickActionsCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _supportDashboardCard() {
    final unread = _supportUnreadCount;
    return _sectionCard(
      title: 'CutLink Support',
      trailing: unread > 0 ? _smallBadge(unread.toString()) : null,
      actionText: 'Open Support',
      onAction: _openSupport,
      child: InkWell(
        onTap: _openSupport,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8EDEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.support_agent, color: _darkRed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unread > 0
                          ? '$unread unread support ${unread == 1 ? 'message' : 'messages'}'
                          : 'Contact CutLink or review your tickets',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isAdmin
                          ? 'Review supplier and butcher support requests.'
                          : 'Create a ticket and chat directly with CutLink.',
                      style: const TextStyle(
                        color: Color(0xFF6A6E75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF777B82)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _butcherDeliveryOperationsCard() {
    final activeOrders = _butcherOrders.where((order) {
      final status = order['status']?.toString();
      return status != 'completed' &&
          status != 'cancelled' &&
          status != 'declined';
    }).toList();

    final deliveryOrders = activeOrders.where((order) {
      return order['fulfilment_method']?.toString() != 'pickup';
    }).length;

    final pickupOrders = activeOrders.where((order) {
      return order['fulfilment_method']?.toString() == 'pickup';
    }).length;

    final scheduledOrders = activeOrders.where((order) {
      final date = order['requested_fulfilment_date']?.toString().trim();
      return date != null && date.isNotEmpty;
    }).length;

    return _sectionCard(
      title: 'Fulfilment Overview',
      actionText: 'Open Orders',
      onAction: () => _openPage(const SubmittedOrdersPage()),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = <Widget>[
            _supplierInventoryMetric(
              Icons.local_shipping_outlined,
              'Delivery Orders',
              deliveryOrders.toString(),
            ),
            _supplierInventoryMetric(
              Icons.storefront_outlined,
              'Pickup Orders',
              pickupOrders.toString(),
            ),
            _supplierInventoryMetric(
              Icons.event_available_outlined,
              'Scheduled',
              scheduledOrders.toString(),
            ),
          ];

          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  Expanded(child: metrics[i]),
                  if (i != metrics.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          }

          return Column(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                metrics[i],
                if (i != metrics.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomDashboardGrid() {
    final visible = _dashboardPreferences
        .where((item) => item.visible)
        .toList();
    if (visible.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            const Icon(
              Icons.dashboard_customize_outlined,
              size: 34,
              color: _darkRed,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your dashboard is empty',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose which cards you want to see.',
              style: TextStyle(color: Color(0xFF6A6E75)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showDashboardCustomiser,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add dashboard cards'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                _dashboardTileWidget(visible[i].id),
                if (i != visible.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        var index = 0;
        while (index < visible.length) {
          final first = visible[index];
          if (first.wide) {
            rows.add(_dashboardTileWidget(first.id));
            index += 1;
          } else {
            _DashboardTilePreference? second;
            if (index + 1 < visible.length && !visible[index + 1].wide) {
              second = visible[index + 1];
            }

            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _dashboardTileWidget(first.id)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: second == null
                        ? const SizedBox.shrink()
                        : _dashboardTileWidget(second.id),
                  ),
                ],
              ),
            );
            index += second == null ? 1 : 2;
          }

          if (index < visible.length) {
            rows.add(const SizedBox(height: 14));
          }
        }

        return Column(children: rows);
      },
    );
  }

  Future<void> _saveDashboardPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    final businessId = _businessId;
    if (user == null || businessId == null) return;

    try {
      await Supabase.instance.client.from('user_dashboard_preferences').upsert({
        'user_id': user.id,
        'business_id': businessId,
        'layout': [for (final item in _dashboardPreferences) item.toJson()],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,business_id');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dashboard layout could not be saved: ${error.message}',
          ),
        ),
      );
    }
  }

  Future<void> _showDashboardCustomiser() async {
    final local = [for (final item in _dashboardPreferences) item.copy()];
    final result = await showDialog<List<_DashboardTilePreference>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return phoneDialog(
              context,
              AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.dashboard_customize_outlined, color: _darkRed),
                    SizedBox(width: 10),
                    Text('Customise dashboard'),
                  ],
                ),
                content: SizedBox(
                  width: 660,
                  height: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Drag cards to change their order. Hide cards you do not need, or make important cards full width.',
                        style: TextStyle(color: Color(0xFF666A70), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: local.length,
                          onReorderItem: (oldIndex, newIndex) {
                            setDialogState(() {
                              final item = local.removeAt(oldIndex);
                              local.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = local[index];
                            return Container(
                              key: ValueKey(item.id),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E4E7),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color: Color(0xFF888D93),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _dashboardTileTitle(item.id),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<bool>(
                                    tooltip: 'Card size',
                                    initialValue: item.wide,
                                    onSelected: (wide) {
                                      setDialogState(() => item.wide = wide);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: false,
                                        child: Text('Normal width'),
                                      ),
                                      PopupMenuItem(
                                        value: true,
                                        child: Text('Full width'),
                                      ),
                                    ],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFD9DCE0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item.wide
                                                ? Icons.aspect_ratio_rounded
                                                : Icons.crop_square_rounded,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            item.wide ? 'Wide' : 'Normal',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch.adaptive(
                                    value: item.visible,
                                    activeTrackColor: _darkRed,
                                    onChanged: (value) {
                                      setDialogState(
                                        () => item.visible = value,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      final defaults = _defaultDashboardPreferences(
                        _businessType ?? '',
                      );
                      setDialogState(() {
                        local
                          ..clear()
                          ..addAll([for (final item in defaults) item.copy()]);
                      });
                    },
                    child: const Text('Reset Default'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(local),
                    style: FilledButton.styleFrom(backgroundColor: _darkRed),
                    child: const Text('Save Layout'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _dashboardPreferences = [for (final item in result) item.copy()];
    });
    await _saveDashboardPreferences();
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
            label: 'Invoiced This Month',
            value: _money(_invoicedThisMonth),
            support: 'Sent invoices • Paid and unpaid',
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
          : PhoneTable(
              desktop: Column(
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
                              'Order ${cutLinkOrderReference(order['order_number'])}',
                              flex: 2,
                              strong: true,
                            ),
                            _tableCell(_supplierName(order), flex: 3),
                            _tableCell(
                              _date(
                                order['submitted_at'] ?? order['created_at'],
                              ),
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
                                  _orderStatusLabel(
                                    order['status']?.toString(),
                                  ),
                                  _orderStatusColor(
                                    order['status']?.toString(),
                                  ),
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
          : PhoneTable(
              desktop: Column(
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
                              account['supplier_name']?.toString() ??
                                  'Supplier',
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
            ),
    );
  }

  void _manageFavouriteProducts() {
    _openPage(
      ButcherFavouritesPage(
        businessId: _businessId ?? '',
        initialProducts: true,
        initialDashboard: true,
      ),
      workspaceKey: 'favourites',
    );
  }

  Widget _favouriteProductsCard() {
    final businessId = _businessId;
    if (businessId == null) {
      return const SizedBox.shrink();
    }
    return _sectionCard(
      title: 'Favourite Products',
      actionText: 'Manage favourites',
      onAction: _manageFavouriteProducts,
      child: ButcherFavouriteProductsPanel(
        key: ValueKey(businessId),
        businessId: businessId,
        onManage: _manageFavouriteProducts,
      ),
    );
  }

  Widget _purchasingOverviewCard() {
    final businessId = _businessId;
    if (businessId == null) {
      return const SizedBox.shrink();
    }

    return _sectionCard(
      title: 'Purchasing Overview',
      actionText: 'View analytics',
      onAction: _openAnalytics,
      child: BusinessAnalyticsOverviewPanel(
        businessId: businessId,
        businessType: 'butcher',
      ),
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
            () => _openPage(
              MarketplaceProductsPage(onBack: () => _openDashboard()),
            ),
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
            child: Flex(
              direction: _useBottomNavigation ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: _useBottomNavigation
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: _useBottomNavigation ? 0 : 1,
                  fit: FlexFit.tight,
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

  List<Widget> _butcherNavigationItems() => [
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
      onTap: () =>
          _openPage(MarketplaceProductsPage(onBack: () => _openDashboard())),
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
        ButcherFavouritesPage(businessId: _businessId ?? ''),
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
      onTap: _openAnalytics,
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
      Icons.support_agent_outlined,
      'Support',
      selected: _workspaceKey == 'support',
      badgeCount: _supportUnreadCount,
      onTap: _openSupport,
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
  ];

  Widget _butcherSidebar() {
    return _sidebarTransitionFrame(
      child: SafeArea(
        child: Column(
          children: [
            _sidebarHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _butcherNavigationItems(),
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
                                  _businessLogoBadge(size: 36, fallback: 'B'),
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

  Widget _mobileNavigation({required bool supplier}) {
    return Material(
      color: _deepNavy,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              _mobileNavigationArrow(false),
              Expanded(
                child: ListView(
                  controller: _mobileNavigationScroll,
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...supplier
                        ? _supplierNavigationItems()
                        : _butcherNavigationItems(),
                    _sideItem(Icons.logout_rounded, 'Logout', onTap: _signOut),
                  ],
                ),
              ),
              _mobileNavigationArrow(true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileNavigationArrow(bool forward) {
    return SizedBox(
      width: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: forward ? 'More menu options' : 'Previous menu options',
        icon: Icon(
          forward ? Icons.chevron_right : Icons.chevron_left,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () {
          if (!_mobileNavigationScroll.hasClients) {
            return;
          }
          final position = _mobileNavigationScroll.position;
          final target = (position.pixels + (forward ? 240 : -240))
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
          _mobileNavigationScroll.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        },
      ),
    );
  }

  Widget _mobileTopBar({required bool supplier}) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _businessName ?? 'CutLink',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => _openPage(
                  supplier
                      ? const SupplierNotificationSettingsPage()
                      : const ButcherNotificationSettingsPage(),
                  workspaceKey: 'notifications',
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              IconButton(
                tooltip: supplier ? 'New sale' : 'My cart',
                onPressed: supplier
                    ? () => _openPage(const SupplierSalesPage(embedded: true))
                    : _openButcherCart,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      supplier
                          ? Icons.add_shopping_cart
                          : Icons.shopping_cart_outlined,
                    ),
                    if (!supplier && _butcherCartItemCount > 0)
                      Positioned(
                        right: -10,
                        top: -10,
                        child: _sidebarBadge(
                          _butcherCartItemCount,
                          selected: false,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideItem(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool selected = false,
    int badgeCount = 0,
  }) {
    if (_useBottomNavigation) {
      final shortLabel = switch (label) {
        'Browse Products' => 'Browse',
        'Accounts & Invoices' => 'Accounts',
        'Customers & Accounts' => 'Customers',
        'Inventory & Pricing' => 'Inventory',
        _ => label,
      };
      return SizedBox(
        width: 88,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Material(
            color: selected ? _darkRed : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: Semantics(
              selected: selected,
              button: true,
              child: Tooltip(
                message: label,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(icon, color: Colors.white, size: 23),
                          if (badgeCount > 0)
                            Positioned(
                              right: -13,
                              top: -8,
                              child: _sidebarBadge(
                                badgeCount,
                                selected: selected,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
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
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(icon, color: Colors.white, size: 20),
                            if (badgeCount > 0 && !showLabel)
                              Positioned(
                                right: -10,
                                top: -9,
                                child: _sidebarBadge(
                                  badgeCount,
                                  selected: selected,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                    if (showLabel && badgeCount > 0) ...[
                      _sidebarBadge(badgeCount, selected: selected),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSalesOrders(String initialTabKey) {
    _openPage(
      SupplierOrdersPage(embedded: true, initialTabKey: initialTabKey),
      workspaceKey: 'sales',
    );
  }

  Widget _sidebarBadge(int count, {required bool selected}) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _deepNavy : _darkRed,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar({bool cartVisible = false}) {
    if (_useBottomNavigation) {
      return _mobileTopBar(supplier: false);
    }
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
            OutlinedButton(
              onPressed: _openButcherCart,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F252B),
                side: const BorderSide(color: Color(0xFFE0E2E5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 18),
                      if (_butcherCartItemCount > 0)
                        Positioned(
                          right: -9,
                          top: -9,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _darkRed,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _butcherCartItemCount > 99
                                  ? '99+'
                                  : '$_butcherCartItemCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  const Text('My Cart'),
                ],
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
                    _businessLogoBadge(size: 30, fallback: 'B'),
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

  Map<String, dynamic>? _invoiceForSupplierOrder(Map<String, dynamic> order) {
    final raw = order['invoices'];

    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }

    return null;
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

  int get _supplierOrdersNeedingAttentionCount {
    var newOrders = 0;
    var workOrders = 0;
    var invoices = 0;

    for (final order in _supplierOrders) {
      final status = order['status']?.toString();
      final source = order['order_source']?.toString();
      final workOrderRows = _workOrdersForSupplierOrder(order);
      final workOrder = workOrderRows.isEmpty ? null : workOrderRows.first;
      final invoice = _invoiceForSupplierOrder(order);

      if (source == 'marketplace' && status == 'submitted') {
        newOrders++;
      }

      if (workOrder != null &&
          workOrder['status']?.toString() != 'completed' &&
          invoice == null &&
          (status == 'accepted' || status == 'processing')) {
        workOrders++;
      }

      if (invoice != null &&
          status != 'completed' &&
          status != 'dispatched' &&
          order['ready_for_pickup_at'] == null) {
        invoices++;
      }
    }

    return newOrders + workOrders + invoices;
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

  int get _supplierActiveDeliveryRuns {
    return _supplierDeliveryRuns.where((run) {
      final status = run['status']?.toString();
      return status == 'ready' || status == 'loaded' || status == 'in_progress';
    }).length;
  }

  int get _supplierOutForDeliveryStops {
    var count = 0;
    for (final run in _supplierDeliveryRuns) {
      final rawStops = run['supplier_delivery_run_stops'];
      if (rawStops is! List) continue;
      count += rawStops.whereType<Map>().where((stop) {
        return stop['status']?.toString() == 'out_for_delivery';
      }).length;
    }
    return count;
  }

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
      bottomNavigationBar:
          _useBottomNavigation && MediaQuery.viewInsetsOf(context).bottom == 0
          ? _mobileNavigation(supplier: true)
          : null,
      body: PhoneSafeArea(
        child: Row(
          children: [
            if (!_useBottomNavigation) _supplierSidebar(),
            Expanded(
              child: RepaintBoundary(
                child: _workspacePage != null
                    ? KeyedSubtree(
                        key: ValueKey(_workspaceKey),
                        child: WorkspaceBackScope(
                          onBack: () => _openDashboard(),
                          child: _workspacePage!,
                        ),
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
                                          _dashboardHeading(
                                            title:
                                                '${_greeting()}, ${_businessName ?? 'Supplier'}',
                                            subtitle:
                                                'Here’s what’s happening across your sales and fulfilment today.',
                                          ),
                                          const SizedBox(height: 18),
                                          _supplierSummaryGrid(),
                                          const SizedBox(height: 16),
                                          _buildCustomDashboardGrid(),
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
          onTap: () => _openSalesOrders('new'),
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
          onTap: () => _openSalesOrders('invoices'),
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
          onTap: () => _openPage(const SupplierCustomerRequestsPage()),
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

    if (_supplierActiveDeliveryRuns > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.local_shipping_outlined,
          tint: const Color(0xFFEAF6F8),
          iconColor: const Color(0xFF27666F),
          message: _supplierOutForDeliveryStops > 0
              ? '$_supplierOutForDeliveryStops delivery stop${_supplierOutForDeliveryStops == 1 ? '' : 's'} currently out for delivery'
              : '$_supplierActiveDeliveryRuns active delivery run${_supplierActiveDeliveryRuns == 1 ? '' : 's'} need attention',
          action: 'Open Delivery',
          onTap: () => _openPage(const SupplierDeliverySettingsPage()),
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
          onTap: () => _openPage(const SupplierCustomerRequestsPage()),
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
          onTap: () => _openSalesOrders('new'),
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
      onAction: () => _openSalesOrders('new'),
      child: _supplierRecentOrders.isEmpty
          ? _emptyState(
              Icons.receipt_long_outlined,
              'No orders yet',
              'Supplier orders will appear here.',
            )
          : PhoneTable(
              desktop: Column(
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
                      onTap: () => _openSalesOrders('new'),
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
                              'Order ${cutLinkOrderReference(order['order_number'])}',
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
                                  _orderStatusLabel(
                                    order['status']?.toString(),
                                  ),
                                  _orderStatusColor(
                                    order['status']?.toString(),
                                  ),
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
    );
  }

  Widget _supplierWorkOrdersCard() {
    final rows = _supplierActiveWorkOrders;

    return _sectionCard(
      title: 'Work Orders',
      actionText: 'View All',
      onAction: () => _openSalesOrders('work_orders'),
      child: rows.isEmpty
          ? _emptyState(
              Icons.build_outlined,
              'No open work orders',
              'Active picking and fulfilment jobs will appear here.',
            )
          : PhoneTable(
              desktop: Column(
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
                      onTap: () => _openSalesOrders('work_orders'),
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
            ),
    );
  }

  Widget _supplierAccountsOverviewCard() {
    return _sectionCard(
      title: 'Accounts Overview',
      actionText: 'View All Accounts',
      onAction: () => _openPage(const SupplierCustomerRequestsPage()),
      child: _supplierTopAccounts.isEmpty
          ? _emptyState(
              Icons.account_balance_wallet_outlined,
              'No account balances',
              'Customer receivables will appear here.',
            )
          : PhoneTable(
              desktop: Column(
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
                      onTap: () =>
                          _openPage(const SupplierCustomerRequestsPage()),
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
                              account['customer_name']?.toString() ??
                                  'Customer',
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
    final businessId = _businessId;
    if (businessId == null) {
      return const SizedBox.shrink();
    }

    return _sectionCard(
      title: 'Sales Overview',
      actionText: 'View analytics',
      onAction: _openAnalytics,
      child: BusinessAnalyticsOverviewPanel(
        businessId: businessId,
        businessType: 'supplier',
      ),
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
            () => _openSalesOrders('new'),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.build_outlined,
            'Open Work Orders',
            () => _openSalesOrders('work_orders'),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.request_quote_outlined,
            'Issue Invoices',
            () => _openSalesOrders('invoices'),
          ),
          const SizedBox(height: 9),
          _quickAction(
            Icons.people_alt_outlined,
            'Customers & Accounts',
            () => _openPage(const SupplierCustomerRequestsPage()),
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

  List<Widget> _supplierNavigationItems() => [
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
      badgeCount: _newSupplierOrderCount,
      onTap: () => _openPage(const SupplierSalesPage(embedded: true)),
    ),
    _sideItem(
      Icons.inventory_2_outlined,
      'Inventory & Pricing',
      selected: _workspaceKey == 'inventory',
      onTap: () => _openPage(const SupplierInventoryPage(embedded: true)),
    ),
    _sideItem(
      Icons.receipt_long_outlined,
      'Invoices',
      selected: _workspaceKey == 'invoices',
      onTap: () => _openPage(const SupplierUnifiedOrdersPage(embedded: true)),
    ),
    _sideItem(
      Icons.people_alt_outlined,
      'Customers & Accounts',
      selected: _workspaceKey == 'customers',
      onTap: () => _openPage(const SupplierCustomerRequestsPage()),
    ),
    _sideItem(
      Icons.bar_chart_outlined,
      'Analytics',
      selected: _workspaceKey == 'analytics',
      onTap: _openAnalytics,
    ),
    _sideItem(
      Icons.local_shipping_outlined,
      'Delivery',
      selected: _workspaceKey == 'delivery',
      onTap: () => _openPage(const SupplierDeliverySettingsPage()),
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
      Icons.support_agent_outlined,
      'Support',
      selected: _workspaceKey == 'support',
      badgeCount: _supportUnreadCount,
      onTap: _openSupport,
    ),
    _sideItem(
      Icons.settings_outlined,
      'Settings',
      selected: _workspaceKey == 'settings',
      onTap: () => _openPage(const SupplierSettingsPage(embedded: true)),
    ),
    if (_isAdmin)
      _sideItem(
        Icons.admin_panel_settings_outlined,
        'Admin',
        selected: _workspaceKey == 'admin',
        onTap: () => _openPage(const PendingBusinessesPage()),
      ),
  ];

  Widget _supplierSidebar() {
    return _sidebarTransitionFrame(
      child: SafeArea(
        child: Column(
          children: [
            _sidebarHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _supplierNavigationItems(),
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
                                  _businessLogoBadge(size: 36, fallback: 'S'),
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
    if (_useBottomNavigation) {
      return _mobileTopBar(supplier: true);
    }
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
          OutlinedButton(
            onPressed: () =>
                _openPage(const SupplierOrdersPage(), workspaceKey: 'orders'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1F252B),
              side: const BorderSide(color: Color(0xFFE0E2E5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 18),
                    if (_supplierOrdersNeedingAttentionCount > 0)
                      Positioned(
                        right: -9,
                        top: -9,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _darkRed,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            _supplierOrdersNeedingAttentionCount > 99
                                ? '99+'
                                : '$_supplierOrdersNeedingAttentionCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 9),
                const Text('Orders'),
              ],
            ),
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
                    _businessLogoBadge(size: 30, fallback: 'S'),
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
      appBar: phoneAppBar(
        context,
        AppBar(
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
                        onTap: () =>
                            _openPage(const SupplierCustomerRequestsPage()),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.assignment_outlined,
                        title: 'Work Orders',
                        description:
                            'Manage warehouse picking, weighing and fulfilment.',
                        onTap: () => _openSalesOrders('work_orders'),
                      ),
                      _LegacyDashboardCard(
                        width: cardWidth,
                        icon: Icons.request_quote_outlined,
                        title: 'Invoices',
                        description:
                            'View draft, issued, paid and outstanding invoices.',
                        onTap: () => _openSalesOrders('invoices'),
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
                        icon: Icons.support_agent_outlined,
                        title: 'CutLink Support',
                        description:
                            'Create support tickets and chat with CutLink.',
                        badgeCount: _supportUnreadCount,
                        onTap: _openSupport,
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

class _DashboardTilePreference {
  _DashboardTilePreference({
    required this.id,
    required this.visible,
    required this.wide,
  });

  final String id;
  bool visible;
  bool wide;

  _DashboardTilePreference copy() {
    return _DashboardTilePreference(id: id, visible: visible, wide: wide);
  }

  Map<String, dynamic> toJson() => {'id': id, 'visible': visible, 'wide': wide};
}
