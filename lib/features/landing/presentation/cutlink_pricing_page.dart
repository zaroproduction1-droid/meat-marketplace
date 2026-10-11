import 'package:flutter/material.dart';

import '../../../shared/widgets/cutlink_logo.dart';
import '../../authentication/presentation/registration_type_page.dart';
import '../../memberships/services/membership_service.dart';
import '../../legal/presentation/legal_info_page.dart';
import 'public_page_palette.dart';

class CutLinkPricingPage extends StatefulWidget {
  const CutLinkPricingPage({super.key});
  @override
  State<CutLinkPricingPage> createState() => _CutLinkPricingPageState();
}

class _CutLinkPricingPageState extends State<CutLinkPricingPage> {
  Map<String, dynamic>? _pricing;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Map<String, dynamic>? data;
    try {
      data = await MembershipService.publicPricing();
    } catch (_) {
      data = null;
    }
    if (mounted) {
      setState(() {
        _pricing = data;
        _loading = false;
      });
    }
  }

  void _join(BusinessType role) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RegistrationTypePage(initialBusinessType: role),
    ),
  );

  Widget _card(BusinessType role) {
    final supplier = role == BusinessType.supplier;
    final info = MembershipService.map(_pricing?[role.name]);
    final total = info['standard_total'] ?? (supplier ? 350 : 200);
    final remaining = (info['remaining'] as num?)?.toInt();
    final next = (info['next_position'] as num?)?.toInt();
    final enabled = info['offer_enabled'] == true;
    final known = info.isNotEmpty && remaining != null;
    final open = known && enabled && remaining > 0;
    final limit = supplier ? 15 : 25;
    final features = supplier
        ? const [
            'Inventory & customer pricing',
            'Quotes, sales & work orders',
            'Invoices, accounts & delivery',
            'Customer relationships & analytics',
            'Wholesale marketplace exposure',
          ]
        : const [
            'Browse suppliers & compare products',
            'Personalised supplier pricing',
            'Online orders & order history',
            'Supplier accounts & invoices',
            'Purchasing visibility & relationships',
          ];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PublicPagePalette.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplier ? 'Supplier' : 'Butcher',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            '${MembershipService.money(total)} AUD / month',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: PublicPagePalette.primary,
            ),
          ),
          const Text('Standard membership · GST inclusive'),
          const SizedBox(height: 18),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: PublicPagePalette.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PublicPagePalette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOUNDING ${supplier ? 'SUPPLIER' : 'BUTCHER'} OFFER',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PublicPagePalette.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loading
                      ? 'Checking availability…'
                      : !known
                      ? 'Availability could not be verified.'
                      : !enabled
                      ? 'Founding enrolment is currently paused.'
                      : remaining == 0
                      ? 'All founding places have been allocated.'
                      : '$remaining of $limit founding places remaining',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (open) ...[
                  const SizedBox(height: 8),
                  Text(
                    next != null &&
                            next <= 10 &&
                            (info['first_tier_remaining'] as num? ?? 0) > 0
                        ? 'Next eligible approval: 6 months free, then 12 months at ${supplier ? '\$175' : '\$100'}/month.'
                        : 'Next eligible approval: 6 months free, then ${supplier ? '\$350' : '\$200'}/month.',
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Places 1–10',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '\$0 × 6 months\n${supplier ? '\$175' : '\$100'} × 12 months\n${supplier ? '\$350' : '\$200'}/month thereafter',
                ),
                const SizedBox(height: 12),
                Text(
                  'Places 11–$limit',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '\$0 × 6 months\n${supplier ? '\$350' : '\$200'}/month thereafter',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _join(role),
              style: FilledButton.styleFrom(
                backgroundColor: PublicPagePalette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                supplier ? 'Join as a Supplier' : 'Join as a Butcher',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const CutLinkLogo(),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Refresh availability',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Simple pricing built for wholesale trade',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ordering, pricing, inventory, sales and accounts. One connected workflow.',
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) => c.maxWidth < 760
                      ? Column(
                          children: [
                            _card(BusinessType.supplier),
                            const SizedBox(height: 16),
                            _card(BusinessType.butcher),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _card(BusinessType.supplier)),
                            const SizedBox(width: 20),
                            Expanded(child: _card(BusinessType.butcher)),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your place starts with an approved business',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Signing up does not reserve a place. CutLink confirms genuine approved businesses in activation order. '
                  'Your confirmed start date begins the six free calendar months. First-tier members then receive twelve half-price months. '
                  'Standard pricing follows. Pausing or cancelling does not restart the offer; places are not automatically reused. '
                  'If places are filled or enrolment is paused, standard membership applies only after confirmation.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'All prices are AUD and GST inclusive. Payments currently use the invoice payment details.',
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalInfoPage(),
                    ),
                  ),
                  child: const Text('Privacy & policies'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
