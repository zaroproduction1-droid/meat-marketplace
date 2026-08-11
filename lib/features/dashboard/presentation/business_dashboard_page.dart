import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/presentation/pending_businesses_page.dart';
import '../../marketplace/presentation/marketplace_products_page.dart';
import '../../pricing/presentation/supplier_price_lists_page.dart';
import '../../products/presentation/supplier_products_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  bool _isLoading = true;
  bool _isAdmin = false;

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
      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('business_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final businessId = membership['business_id'] as String;

      //
      // Load the business details.
      //
      final business = await Supabase.instance.client
          .from('businesses')
          .select('''
            id,
            legal_name,
            trading_name,
            business_type,
            verification_status,
            active
            ''')
          .eq('id', businessId)
          .single();

      final tradingName = business['trading_name'] as String?;

      final legalName = business['legal_name'] as String?;

      String businessName = 'Business';

      if (tradingName != null && tradingName.trim().isNotEmpty) {
        businessName = tradingName;
      } else if (legalName != null && legalName.trim().isNotEmpty) {
        businessName = legalName;
      }

      final businessType = business['business_type'] as String?;

      if (!mounted) {
        return;
      }

      setState(() {
        _businessName = businessName;
        _businessType = businessType;
        _isAdmin = isAdmin;
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
                          icon: Icons.inventory_2_outlined,
                          title: 'Products',
                          description:
                              'Manage the products your business supplies.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierProductsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.price_change_outlined,
                          title: 'Pricing',
                          description:
                              'Manage public, customer and private pricing.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SupplierPriceListsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.receipt_long_outlined,
                          title: 'Orders',
                          description: 'Manage customer orders.',
                          onTap: () {
                            _showComingSoon('Supplier orders');
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.local_shipping_outlined,
                          title: 'Delivery',
                          description: 'Manage delivery information.',
                          onTap: () {
                            _showComingSoon('Delivery management');
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
                          icon: Icons.compare_arrows_outlined,
                          title: 'Compare',
                          description: 'Compare products and supplier pricing.',
                          onTap: () {
                            _showComingSoon('Product comparison');
                          },
                        ),
                        _DashboardCard(
                          width: cardWidth,
                          icon: Icons.shopping_bag_outlined,
                          title: 'Orders',
                          description: 'View and manage your orders.',
                          onTap: () {
                            _showComingSoon('Butcher orders');
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
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

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
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E5E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF741C1C), size: 28),
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
