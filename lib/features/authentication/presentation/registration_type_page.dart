import 'package:flutter/material.dart';

import 'account_details_page.dart';

enum BusinessType { supplier, butcher }

class RegistrationTypePage extends StatefulWidget {
  const RegistrationTypePage({super.key, this.initialBusinessType});

  final BusinessType? initialBusinessType;

  @override
  State<RegistrationTypePage> createState() => _RegistrationTypePageState();
}

class _RegistrationTypePageState extends State<RegistrationTypePage> {
  BusinessType? selectedBusinessType;

  @override
  void initState() {
    super.initState();
    selectedBusinessType = widget.initialBusinessType;
  }

  void continueRegistration() {
    if (selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select whether you are registering as a supplier or butcher.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AccountDetailsPage(businessType: selectedBusinessType!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Create an account',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'How will you use the marketplace?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1D),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose your business type. You will provide your '
                  'business and verification details in the following steps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    color: Color(0xFF5E5E5E),
                  ),
                ),
                const SizedBox(height: 40),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;

                    final supplierCard = _BusinessTypeCard(
                      title: 'Meat Supplier',
                      description:
                          'List products, manage pricing, configure '
                          'delivery information and receive orders '
                          'from approved butcher businesses.',
                      icon: Icons.local_shipping_outlined,
                      selected: selectedBusinessType == BusinessType.supplier,
                      onTap: () {
                        setState(() {
                          selectedBusinessType = BusinessType.supplier;
                        });
                      },
                    );

                    final butcherCard = _BusinessTypeCard(
                      title: 'Butcher Business',
                      description:
                          'Browse suppliers, compare products, view '
                          'authorised pricing and submit wholesale '
                          'order requests.',
                      icon: Icons.storefront_outlined,
                      selected: selectedBusinessType == BusinessType.butcher,
                      onTap: () {
                        setState(() {
                          selectedBusinessType = BusinessType.butcher;
                        });
                      },
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          supplierCard,
                          const SizedBox(height: 20),
                          butcherCard,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: supplierCard),
                        const SizedBox(width: 20),
                        Expanded(child: butcherCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: continueRegistration,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF741C1C),
                    padding: const EdgeInsets.symmetric(vertical: 19),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Return to the marketplace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessTypeCard extends StatelessWidget {
  const _BusinessTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF741C1C);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? darkRed : const Color(0xFFD8D8D8),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    blurRadius: 18,
                    offset: Offset(0, 7),
                    color: Color(0x1A000000),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E5E5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 31, color: darkRed),
                ),
                const Spacer(),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? darkRed : const Color(0xFF999999),
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1D1D),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF5E5E5E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
