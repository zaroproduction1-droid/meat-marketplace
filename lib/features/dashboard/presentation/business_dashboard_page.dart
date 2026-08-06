import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../products/presentation/supplier_products_page.dart';
import '../../pricing/presentation/supplier_price_lists_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  bool _isLoading = true;
  bool _isSigningOut = false;

  String _businessName = '';
  String _businessType = '';

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user was found.');
      }

      final membership = await Supabase.instance.client
          .from('business_memberships')
          .select('businesses(legal_name, trading_name, business_type)')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .single();

      final business = Map<String, dynamic>.from(
        membership['businesses'] as Map,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final tradingName = business['trading_name'] as String?;

        final legalName = business['legal_name'] as String? ?? '';

        _businessName = tradingName != null && tradingName.trim().isNotEmpty
            ? tradingName
            : legalName;

        _businessType = business['business_type'] as String? ?? '';

        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load the business dashboard.')),
      );
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature will be built next.')));
  }

  @override
  Widget build(BuildContext context) {
    final isSupplier = _businessType == 'supplier';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'NSW Meat Marketplace',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $_businessName',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isSupplier
                            ? 'Manage your supplier catalogue, pricing and orders.'
                            : 'Browse suppliers, compare products and manage orders.',
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF5E5E5E),
                        ),
                      ),
                      const SizedBox(height: 36),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth < 700
                              ? constraints.maxWidth
                              : 320.0;

                          final cards = isSupplier
                              ? [
                                  _DashboardCard(
                                    width: cardWidth,
                                    icon: Icons.inventory_2_outlined,
                                    title: 'Products',
                                    description:
                                        'Create and manage your catalogue.',
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
                                        'Manage public and private prices.',
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
                                    description:
                                        'Review incoming customer orders.',
                                    onTap: () {
                                      _showComingSoon('Supplier orders');
                                    },
                                  ),
                                  _DashboardCard(
                                    width: cardWidth,
                                    icon: Icons.local_shipping_outlined,
                                    title: 'Delivery',
                                    description:
                                        'Configure delivery areas and days.',
                                    onTap: () {
                                      _showComingSoon(
                                        'Supplier delivery settings',
                                      );
                                    },
                                  ),
                                ]
                              : [
                                  _DashboardCard(
                                    width: cardWidth,
                                    icon: Icons.search,
                                    title: 'Browse Products',
                                    description:
                                        'Search products from approved suppliers.',
                                    onTap: () {
                                      _showComingSoon('Product marketplace');
                                    },
                                  ),
                                  _DashboardCard(
                                    width: cardWidth,
                                    icon: Icons.compare_arrows,
                                    title: 'Compare',
                                    description:
                                        'Compare product specifications and prices.',
                                    onTap: () {
                                      _showComingSoon('Product comparison');
                                    },
                                  ),
                                  _DashboardCard(
                                    width: cardWidth,
                                    icon: Icons.shopping_cart_outlined,
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
                                    description:
                                        'Save products for repeat ordering.',
                                    onTap: () {
                                      _showComingSoon('Favourite products');
                                    },
                                  ),
                                ];

                          return Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: cards,
                          );
                        },
                      ),
                    ],
                  ),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 42, color: const Color(0xFF741C1C)),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(height: 1.4, color: Color(0xFF5E5E5E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
