import '../../../shared/theme/cutlink_appearance.dart';
import '../../../shared/widgets/ios_density.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/cutlink_logo.dart';
import '../../authentication/presentation/registration_type_page.dart';
import '../../legal/presentation/legal_info_page.dart';
import '../../memberships/services/membership_service.dart';
import 'public_page_palette.dart';

const _royal = Color(0xFF651B2B);
const _gold = Color(0xFFEED3A7);

class CutLinkPricingPage extends StatefulWidget {
  const CutLinkPricingPage({super.key});

  @override
  State<CutLinkPricingPage> createState() => _CutLinkPricingPageState();
}

class _CutLinkPricingPageState extends State<CutLinkPricingPage> {
  Map<String, dynamic>? _pricing;
  bool _loading = true;
  BusinessType _role = BusinessType.supplier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool feedback = false}) async {
    if (feedback && _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _pricing = null;
    });
    Map<String, dynamic>? data;
    try {
      data = await MembershipService.publicPricing();
    } catch (_) {
      data = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pricing = data;
      _loading = false;
    });
    if (feedback) {
      final verified = ['supplier', 'butcher'].every(
        (role) => _PricingData.from(
          MembershipService.map(data?[role]),
          fallback: MembershipService.standardPrice(role == 'supplier'),
          limit: role == 'supplier' ? 15 : 25,
        ).known,
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              verified
                  ? 'Founding availability refreshed.'
                  : 'We couldn’t check places right now. Your place is confirmed after approval.',
            ),
          ),
        );
    }
  }

  void _join(BusinessType role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistrationTypePage(initialBusinessType: role),
      ),
    );
  }

  Widget _foundingCard(
    _PricingData data, {
    required bool first,
    required bool supplier,
  }) {
    final role = supplier ? 'suppliers' : 'butchers';
    final limit = supplier ? 15 : 25;
    final remaining = first ? data.firstRemaining : data.laterRemaining;
    final availability = _loading
        ? 'Checking places…'
        : !data.known
        ? 'Subject to availability'
        : remaining == 0
        ? 'Places filled'
        : !data.enabled
        ? 'Enrolment paused'
        : '$remaining places left';
    return _MembershipPanel(
      founding: true,
      child: IosPadding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FoundingSeal(),
            const IosGap(height: 14),
            Text(
              first ? 'First 10 $role' : 'Next ${limit - 10} $role',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _gold,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const IosGap(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                availability,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const IosGap(height: 24),
            const Text(
              'FREE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                height: 1.05,
              ),
            ),
            const IosGap(height: 7),
            const Text(
              'for your first 6 months',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const IosPadding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Color(0xFFB6757F), height: 1),
            ),
            if (first) ...[
              _PriceStage(
                label: 'Next 12 months',
                amount: MembershipService.money(data.discounted),
              ),
              const IosGap(height: 14),
            ],
            _PriceStage(
              label: first ? 'After that' : 'After your free months',
              amount: MembershipService.money(data.standard),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plans() {
    final role = _role;
    final supplier = role == BusinessType.supplier;
    final data = _PricingData.from(
      MembershipService.map(_pricing?[role.name]),
      fallback: MembershipService.standardPrice(supplier),
      limit: supplier ? 15 : 25,
    );
    final unavailable = !data.known || _loading;
    final status = _loading
        ? 'Checking founding places…'
        : !data.known
        ? 'Places are confirmed after business approval.'
        : data.remaining == 0
        ? 'All founding places are filled. Standard membership is available.'
        : !data.enabled
        ? 'Founding enrolment is currently paused.'
        : '${data.remaining} of ${supplier ? 15 : 25} founding places left';
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: CutLinkPalette.color(0xFFFAF8F7),
            border: Border.all(color: PublicPagePalette.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                'Standard membership',
                style: TextStyle(color: PublicPagePalette.muted, fontSize: 13),
              ),
              const IosGap(height: 5),
              Text(
                '${MembershipService.money(data.standard)} / month',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _royal,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const IosGap(height: 28),
        const Text(
          'Founding membership',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _royal,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const IosGap(height: 7),
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PublicPagePalette.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        if (!unavailable && !data.enabled)
          IosPadding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'The offers below are a preview.',
              style: TextStyle(color: PublicPagePalette.muted, fontSize: 12),
            ),
          ),
        const IosGap(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final first = _foundingCard(data, first: true, supplier: supplier);
            final later = _foundingCard(data, first: false, supplier: supplier);
            if (constraints.maxWidth < 660 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4) {
              return Column(children: [first, const IosGap(height: 16), later]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 20),
                  Expanded(child: later),
                ],
              ),
            );
          },
        ),
        const IosGap(height: 18),
        Text(
          'All prices are AUD and include GST.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PublicPagePalette.muted, fontSize: 12),
        ),
        const IosGap(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _join(role),
              style: FilledButton.styleFrom(
                backgroundColor: _royal,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Register as a ${supplier ? 'supplier' : 'butcher'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const IosGap(height: 10),
        Text(
          'Signing up doesn’t reserve a founding place.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: PublicPagePalette.muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const IosGap(height: 20),
        Container(
          decoration: BoxDecoration(
            color: CutLinkPalette.color(0xFFFAF8F7),
            border: Border.all(color: PublicPagePalette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: ValueKey('how-${role.name}'),
            title: const Text(
              'How it works',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            textColor: _royal,
            collapsedTextColor: _royal,
            iconColor: _royal,
            collapsedIconColor: _royal,
            shape: const Border(),
            collapsedShape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              _Note(
                icon: Icons.verified_outlined,
                text:
                    'CutLink approves your business and confirms your founding place. Places follow confirmation order.',
              ),
              _Note(
                icon: Icons.event_available_outlined,
                text:
                    'Your 6 free months start on the date CutLink confirms your membership.',
              ),
              _Note(
                icon: Icons.receipt_long_outlined,
                text:
                    'You pay the amounts shown above using your invoice payment details. Half-price amounts are rounded to cents.',
              ),
              _Note(
                icon: Icons.info_outline_rounded,
                text:
                    'If founding places are filled or paused, standard pricing applies only after confirmation. Pausing or cancelling doesn’t restart an offer or free up a place.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: CutLinkPalette.surface,
      appBar: AppBar(
        backgroundColor: CutLinkPalette.surface,
        surfaceTintColor: Colors.white,
        foregroundColor: _royal,
        title: const CutLinkLogo(width: 132, height: 32),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(feedback: true),
            tooltip: 'Refresh founding places',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: IosPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: reducedMotion ? 0 : 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Straightforward pricing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PublicPagePalette.text,
                        fontSize: MediaQuery.sizeOf(context).width < 480
                            ? 28
                            : 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.15,
                      ),
                    ),
                    const IosGap(height: 22),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<BusinessType>(
                          direction:
                              MediaQuery.textScalerOf(context).scale(1) > 1.4
                              ? Axis.vertical
                              : Axis.horizontal,
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: BusinessType.supplier,
                              label: Text('Supplier'),
                              icon: Icon(Icons.inventory_2_outlined),
                            ),
                            ButtonSegment(
                              value: BusinessType.butcher,
                              label: Text('Butcher'),
                              icon: Icon(Icons.storefront_outlined),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (values) =>
                              setState(() => _role = values.first),
                          style: ButtonStyle(
                            foregroundColor: const WidgetStatePropertyAll(
                              _royal,
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? CutLinkPalette.color(0xFFF5E9EC)
                                  : Colors.white,
                            ),
                            side: WidgetStatePropertyAll(
                              BorderSide(
                                color: CutLinkPalette.color(0xFFE5D5D9),
                              ),
                            ),
                            textStyle: const WidgetStatePropertyAll(
                              TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const IosGap(height: 22),
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: reducedMotion ? 0 : 200),
                      child: KeyedSubtree(
                        key: ValueKey(_role),
                        child: _plans(),
                      ),
                    ),
                    const IosGap(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LegalInfoPage(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: PublicPagePalette.muted,
                      ),
                      child: const Text('Privacy & policies'),
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
}

class _PriceStage extends StatelessWidget {
  const _PriceStage({required this.label, required this.amount});
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _gold, fontSize: 13),
        ),
        const IosGap(height: 5),
        Text(
          '$amount / month',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return IosPadding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _royal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: PublicPagePalette.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipPanel extends StatefulWidget {
  const _MembershipPanel({required this.founding, required this.child});
  final bool founding;
  final Widget child;

  @override
  State<_MembershipPanel> createState() => _MembershipPanelState();
}

class _MembershipPanelState extends State<_MembershipPanel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
        ),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CutLinkPalette.surface,
          gradient: widget.founding
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_royal, Color(0xFF8B2E40), Color(0xFF511522)],
                )
              : null,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: widget.founding
                ? _gold.withValues(alpha: _hovered ? .65 : .3)
                : PublicPagePalette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _royal.withValues(alpha: _hovered ? .16 : .08),
              blurRadius: _hovered ? 36 : 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _FoundingSeal extends StatelessWidget {
  const _FoundingSeal();

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _gold.withValues(alpha: .65)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _gold.withValues(alpha: .14),
              _gold.withValues(alpha: .03),
            ],
          ),
          boxShadow: [
            BoxShadow(color: _gold.withValues(alpha: .08), blurRadius: 24),
          ],
        ),
        child: const CustomPaint(size: Size(34, 28), painter: _CrownPainter()),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _gold;
    final crown = Path()
      ..moveTo(size.width * .12, size.height * .72)
      ..lineTo(size.width * .04, size.height * .22)
      ..lineTo(size.width * .31, size.height * .43)
      ..lineTo(size.width * .5, size.height * .06)
      ..lineTo(size.width * .69, size.height * .43)
      ..lineTo(size.width * .96, size.height * .22)
      ..lineTo(size.width * .88, size.height * .72)
      ..close();
    canvas.drawPath(crown, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .12,
          size.height * .81,
          size.width * .76,
          size.height * .12,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => false;
}

class _PricingData {
  const _PricingData({
    required this.standard,
    required this.discounted,
    required this.known,
    required this.enabled,
    required this.remaining,
    required this.firstRemaining,
    required this.laterRemaining,
  });
  final num standard;
  final num discounted;
  final bool known;
  final bool enabled;
  final int remaining;
  final int firstRemaining;
  final int laterRemaining;

  factory _PricingData.from(
    Map<String, dynamic> info, {
    required num fallback,
    required int limit,
  }) {
    final total = num.tryParse(info['standard_total'].toString());
    final standard = total != null && total.isFinite && total > 0
        ? total
        : fallback;
    final cents = (standard * 100).round();
    final half = ((cents + 1) ~/ 2) / 100;
    final discount = num.tryParse(info['discounted_total'].toString());
    final remaining = info['remaining'];
    final next = info['next_position'];
    final known =
        total != null &&
        total.isFinite &&
        total > 0 &&
        remaining is int &&
        remaining >= 0 &&
        remaining <= limit &&
        next is int &&
        next > 0 &&
        next <= limit + 1 &&
        info['offer_enabled'] is bool;
    final firstRemaining = known
        ? (11 - next).clamp(0, 10).clamp(0, remaining).toInt()
        : 0;
    return _PricingData(
      standard: standard,
      discounted:
          discount != null &&
              discount.isFinite &&
              discount > 0 &&
              discount == half
          ? discount
          : half,
      known: known,
      enabled: known && info['offer_enabled'] == true,
      remaining: known ? remaining : 0,
      firstRemaining: firstRemaining,
      laterRemaining: known ? remaining - firstRemaining : 0,
    );
  }
}
