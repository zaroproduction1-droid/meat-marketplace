import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/presentation/pending_businesses_page.dart';
import '../../marketplace/presentation/marketplace_products_page.dart';
import '../../customers/presentation/supplier_customer_requests_page.dart';
import '../../delivery/presentation/supplier_delivery_settings_page.dart';
import '../../orders/presentation/submitted_orders_page.dart';
import '../../orders/presentation/butcher_accounts_page.dart';
import '../../orders/presentation/butcher_settings_page.dart';
import '../../orders/presentation/supplier_settings_page.dart';
import '../../orders/presentation/supplier_invoices_page.dart';
import '../../orders/presentation/supplier_inventory_page.dart';
import '../../orders/presentation/supplier_sales_page.dart';
import '../../orders/presentation/supplier_work_orders_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  bool _isLoading = true;
  bool _isAdmin = false;

  int _newSupplierOrderCount = 0;

  String? _errorMessage;
  String? _businessName;
  String? _businessType;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      //
      // Check whether this user is an administrator.
      //
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .single();

      final isAdmin = profile['is_admin'] as bool? ?? false;

      //
      // Find the business this user belongs to.
      //
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

      //
      // Load every active business membership instead of taking an arbitrary
      // first membership. If this user belongs to a supplier business, the
      // supplier workspace wins so supplier users cannot accidentally land in
      // the butcher marketplace.
      //
      final businesses = await Supabase.instance.client
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

      final businessId = business['id'] as String;

      final tradingName = business['trading_name'] as String?;

      final legalName = business['legal_name'] as String?;

      String businessName = 'Business';

      if (tradingName != null && tradingName.trim().isNotEmpty) {
        businessName = tradingName;
      } else if (legalName != null && legalName.trim().isNotEmpty) {
        businessName = legalName;
      }

      final businessType = business['business_type'] as String?;

      var newSupplierOrderCount = 0;

      if (businessType == 'supplier') {
        final newOrders = await Supabase.instance.client
            .from('orders')
            .select('''
              id,
              order_items(id)
            ''')
            .eq('supplier_business_id', businessId)
            .eq('status', 'submitted');

        for (final order in newOrders) {
          final rawItems = order['order_items'];

          if (rawItems is List) {
            newSupplierOrderCount += rawItems.length;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _businessName = businessName;
        _businessType = businessType;
        _isAdmin = isAdmin;
        _newSupplierOrderCount = newSupplierOrderCount;
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be added in a later development phase.'),
      ),
    );
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _formatBusinessType() {
    switch (_businessType) {
      case 'supplier':
        return 'Supplier';
      case 'butcher':
        return 'Butcher';
      default:
        return 'Business';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Dashboard'),
        ),
        body: Center(
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
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loadDashboard,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
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
              Text(
                _formatBusinessType(),
                style: const TextStyle(
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
                      //
                      // SUPPLIER DASHBOARD
                      //
                      if (_businessType == 'supplier') ...[
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.point_of_sale_outlined,
                          title: 'Sales',
                          description:
                              'Search your stock, create sales orders and move jobs through work orders and invoicing.',
                          badgeCount: _newSupplierOrderCount,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierSalesPage(),
                              ),
                            );

                            if (!mounted) {
                              return;
                            }

                            await _loadDashboard();
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.inventory_2_outlined,
                          title: 'Inventory',
                          description:
                              'Manage your stock, add products and update pricing.',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierInventoryPage(),
                              ),
                            );

                            if (!mounted) {
                              return;
                            }

                            await _loadDashboard();
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.people_alt_outlined,
                          title: 'Customers & Accounts',
                          description:
                              'Approve butcher requests and manage account terms.',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierCustomerRequestsPage(),
                              ),
                            );

                            if (!mounted) {
                              return;
                            }

                            await _loadDashboard();
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.assignment_outlined,
                          title: 'Work Orders',
                          description:
                              'Manage warehouse picking, weighing and fulfilment.',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierWorkOrdersPage(),
                              ),
                            );

                            if (!mounted) {
                              return;
                            }

                            await _loadDashboard();
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.request_quote_outlined,
                          title: 'Invoices',
                          description:
                              'View draft, issued, paid and outstanding invoices.',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierInvoicesPage(),
                              ),
                            );

                            if (!mounted) {
                              return;
                            }

                            await _loadDashboard();
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          description:
                              'Configure invoice details, banking information and supplier settings.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierSettingsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.local_shipping_outlined,
                          title: 'Delivery',
                          description:
                              'Manage delivery days, cut-off times, zones and minimum orders.',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierDeliverySettingsPage(),
                              ),
                            );

                            if (!mounted) {
                              return;
                            }

                            await _loadDashboard();
                          },
                        ),
                      ],

                      //
                      // BUTCHER DASHBOARD
                      //
                      if (_businessType == 'butcher') ...[
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.storefront_outlined,
                          title: 'Browse Products',
                          description:
                              'Browse products from approved suppliers.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MarketplaceProductsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.shopping_bag_outlined,
                          title: 'Orders',
                          description: 'View and track your submitted orders.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SubmittedOrdersPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Accounts',
                          description:
                              'View COD payments, outstanding balances and invoices from your suppliers.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ButcherAccountsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          description:
                              'Manage business, billing and account preferences.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ButcherSettingsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.favorite_border,
                          title: 'Favourites',
                          description: 'View saved products and suppliers.',
                          onTap: () {
                            _showComingSoon('Favourites');
                          },
                        ),
                      ],

                      //
                      // ADMIN CARD
                      //
                      // This ONLY appears when:
                      // profiles.is_admin = true
                      //
                      if (_isAdmin)
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Admin',
                          description: 'Review pending business applications.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PendingBusinessesPage(),
                              ),
                            );
                          },
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
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
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
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
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
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
