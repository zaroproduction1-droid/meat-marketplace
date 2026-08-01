import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/authentication/presentation/registration_type_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabasePublishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL is missing from the .env file.');
  }

  if (supabasePublishableKey == null || supabasePublishableKey.isEmpty) {
    throw Exception('SUPABASE_PUBLISHABLE_KEY is missing from the .env file.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const MeatMarketplaceApp());
}

class MeatMarketplaceApp extends StatelessWidget {
  const MeatMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSW Meat Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A1F1F),
          brightness: Brightness.light,
        ),
        fontFamily: 'Arial',
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const Color darkRed = Color(0xFF741C1C);
  static const Color darkText = Color(0xFF1D1D1D);
  static const Color softBackground = Color(0xFFF7F7F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _NavigationBar(),
            const _HeroSection(),
            const _HowItWorksSection(),
            const _FeatureSection(),
            const _PilotSection(),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;

          if (isMobile) {
            return Row(
              children: [
                const Expanded(child: _Logo()),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('The mobile menu will be added later.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu),
                ),
              ],
            );
          }

          return const Row(
            children: [
              _Logo(),
              Spacer(),
              _NavItem(label: 'How It Works'),
              SizedBox(width: 28),
              _NavItem(label: 'For Suppliers'),
              SizedBox(width: 28),
              _NavItem(label: 'For Butchers'),
              SizedBox(width: 28),
              _SignInButton(),
              SizedBox(width: 12),
              _RegisterButton(),
            ],
          );
        },
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.storefront_outlined, color: LandingPage.darkRed, size: 34),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            'NSW Meat Marketplace',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: LandingPage.darkText,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: LandingPage.darkText,
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        _showComingSoon(context, 'Sign in');
      },
      child: const Text('Sign In'),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const RegistrationTypePage()),
        );
      },
      style: FilledButton.styleFrom(
        backgroundColor: LandingPage.darkRed,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
      child: const Text('Register'),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF741C1C), Color(0xFF9B2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 90),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 850;

              if (isMobile) {
                return const Column(
                  children: [_HeroText(), SizedBox(height: 40), _HeroCard()],
                );
              }

              return const Row(
                children: [
                  Expanded(flex: 6, child: _HeroText()),
                  SizedBox(width: 60),
                  Expanded(flex: 4, child: _HeroCard()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wholesale meat ordering, made simpler.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 52,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Connect meat suppliers with verified butchers across NSW. '
          'Search products, compare specifications, view authorised '
          'pricing and submit orders from one marketplace.',
          style: TextStyle(
            color: Color(0xFFF7EDED),
            fontSize: 20,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RegistrationTypePage(
                      initialBusinessType: BusinessType.supplier,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: LandingPage.darkRed,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 18,
                ),
              ),
              child: const Text(
                'Join as a Supplier',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RegistrationTypePage(
                      initialBusinessType: BusinessType.butcher,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 18,
                ),
              ),
              child: const Text(
                'Join as a Butcher',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 12,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 46,
              color: LandingPage.darkRed,
            ),
            const SizedBox(height: 20),
            const Text(
              'Built for the meat industry',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: LandingPage.darkText,
              ),
            ),
            const SizedBox(height: 18),
            const _CheckItem(text: 'Public and private pricing'),
            const _CheckItem(text: 'Product specification comparison'),
            const _CheckItem(text: 'Catch-weight ordering support'),
            const _CheckItem(text: 'Supplier delivery rules'),
            const _CheckItem(text: 'Repeat orders and favourites'),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F7F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF287A38)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Supabase connection active',
                      style: TextStyle(
                        color: Color(0xFF245E2D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          const Icon(Icons.check, size: 20, color: LandingPage.darkRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: LandingPage.darkText),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'How it works',
      subtitle:
          'One marketplace designed around supplier approval, accurate product information and simple ordering.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth < 700 ? 1 : 3;

          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 22,
            mainAxisSpacing: 22,
            childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.15,
            children: const [
              _InformationCard(
                number: '1',
                icon: Icons.verified_user_outlined,
                title: 'Businesses register',
                description:
                    'Suppliers and butchers submit their business details '
                    'for marketplace approval.',
              ),
              _InformationCard(
                number: '2',
                icon: Icons.manage_search_outlined,
                title: 'Products are discovered',
                description:
                    'Butchers search and compare structured products from '
                    'multiple approved suppliers.',
              ),
              _InformationCard(
                number: '3',
                icon: Icons.receipt_long_outlined,
                title: 'Orders are confirmed',
                description:
                    'Suppliers review order requests, confirm quantities '
                    'and manage any substitutions.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _SectionContainer(
        title: 'Designed for suppliers and butchers',
        subtitle:
            'The pilot will focus on the tools needed to publish products, compare offers and submit genuine wholesale orders.',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;

            if (isMobile) {
              return const Column(
                children: [
                  _RoleCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'For Suppliers',
                    items: [
                      'Create and manage products',
                      'Control price visibility',
                      'Set delivery rules',
                      'Receive and review orders',
                      'Upload catalogues by CSV',
                    ],
                  ),
                  SizedBox(height: 24),
                  _RoleCard(
                    icon: Icons.store_outlined,
                    title: 'For Butchers',
                    items: [
                      'Search multiple suppliers',
                      'Compare product specifications',
                      'View authorised pricing',
                      'Submit order requests',
                      'Save favourites and repeat orders',
                    ],
                  ),
                ],
              );
            }

            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _RoleCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'For Suppliers',
                    items: [
                      'Create and manage products',
                      'Control price visibility',
                      'Set delivery rules',
                      'Receive and review orders',
                      'Upload catalogues by CSV',
                    ],
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: _RoleCard(
                    icon: Icons.store_outlined,
                    title: 'For Butchers',
                    items: [
                      'Search multiple suppliers',
                      'Compare product specifications',
                      'View authorised pricing',
                      'Submit order requests',
                      'Save favourites and repeat orders',
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PilotSection extends StatelessWidget {
  const _PilotSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF222222),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 70),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
              const Text(
                'Greater Sydney pilot',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'The first pilot will focus on beef, lamb and poultry, '
                'with a small group of suppliers and butcher shops.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD7D7D7),
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () {
                  _showComingSoon(context, 'Pilot registration');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: LandingPage.darkRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                ),
                child: const Text(
                  'Register Your Interest',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF171717),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
      child: const Center(
        child: Text(
          '© 2026 NSW Meat Marketplace. Pilot application.',
          style: TextStyle(color: Color(0xFFBDBDBD)),
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: LandingPage.darkText,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color: Color(0xFF5E5E5E),
                  ),
                ),
              ),
              const SizedBox(height: 45),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFF3E4E4),
                  foregroundColor: LandingPage.darkRed,
                  child: Text(
                    number,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                Icon(icon, size: 38, color: LandingPage.darkRed),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(height: 1.5, color: Color(0xFF5E5E5E)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LandingPage.darkRed, size: 45),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: LandingPage.darkRed,
                    size: 21,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature will be built in the next development stages.'),
    ),
  );
}
