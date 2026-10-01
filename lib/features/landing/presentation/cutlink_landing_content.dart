import 'package:flutter/material.dart';

import '../../authentication/presentation/registration_type_page.dart';
import 'cutlink_explainer_video.dart';
import 'featured_businesses_section.dart';
import 'public_page_palette.dart';

class CutLinkLandingContent extends StatefulWidget {
  const CutLinkLandingContent({
    super.key,
    required this.onSignIn,
    required this.onRegister,
  });

  final VoidCallback onSignIn;
  final ValueChanged<BusinessType> onRegister;

  @override
  State<CutLinkLandingContent> createState() => _CutLinkLandingContentState();
}

class _CutLinkLandingContentState extends State<CutLinkLandingContent> {
  final _videoKey = GlobalKey();
  final _productKey = GlobalKey();
  final _communityKey = GlobalKey();
  bool _supplier = false;

  void _go(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      alignment: .08,
    );
  }

  Widget _brand() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.link_rounded, color: PublicPagePalette.primary, size: 30),
      SizedBox(width: 8),
      Text(
        'CutLink',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: PublicPagePalette.text,
          letterSpacing: -.8,
        ),
      ),
    ],
  );

  Widget _join(BusinessType role) {
    final supplier = role == BusinessType.supplier;
    final style = OutlinedButton.styleFrom(
      foregroundColor: PublicPagePalette.primary,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      side: const BorderSide(color: PublicPagePalette.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
    final label = Text(supplier ? 'Join as a supplier' : 'Join as a butcher');
    if (supplier) {
      return FilledButton(
        onPressed: () => widget.onRegister(role),
        style: FilledButton.styleFrom(
          backgroundColor: PublicPagePalette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: label,
      );
    }
    return OutlinedButton(
      onPressed: () => widget.onRegister(role),
      style: style,
      child: label,
    );
  }

  Widget _actions() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [_join(BusinessType.supplier), _join(BusinessType.butcher)],
  );

  Widget _frame(Widget child, {double vertical = 48}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1240),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 20 : 40,
          vertical: vertical,
        ),
        child: child,
      ),
    ),
  );

  Widget _header() => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: PublicPagePalette.border)),
    ),
    child: _frame(
      Row(
        children: [
          _brand(),
          const Spacer(),
          if (MediaQuery.sizeOf(context).width >= 1000) ...[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: PublicPagePalette.text,
              ),
              onPressed: () => _go(_videoKey),
              child: const Text('Watch CutLink'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: PublicPagePalette.text,
              ),
              onPressed: () => _go(_productKey),
              child: const Text('Inside CutLink'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: PublicPagePalette.text,
              ),
              onPressed: () => _go(_communityKey),
              child: const Text('Community'),
            ),
            const SizedBox(width: 16),
          ],
          OutlinedButton(
            onPressed: widget.onSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: PublicPagePalette.text,
              side: const BorderSide(color: PublicPagePalette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
      vertical: 16,
    ),
  );

  Widget _intro(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'SUPPLIERS + BUTCHERS',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
          color: PublicPagePalette.primary,
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Your meat trade.\nOne connected place.',
        style: TextStyle(
          fontSize: compact ? 36 : 48,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
          color: PublicPagePalette.text,
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Buying, selling and running your business — together in CutLink.',
        style: TextStyle(
          color: PublicPagePalette.muted,
          fontSize: 17,
          height: 1.5,
        ),
      ),
    ],
  );

  Widget _film() => Column(
    key: _videoKey,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: PublicPagePalette.text,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22933744),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: CutLinkExplainerVideo(),
        ),
      ),
      const SizedBox(height: 14),
      const Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 18,
            color: PublicPagePalette.primary,
          ),
          Text(
            'Watch CutLink · 80 seconds',
            style: TextStyle(
              color: PublicPagePalette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Sound on when you press play',
            style: TextStyle(color: PublicPagePalette.muted, fontSize: 12),
          ),
        ],
      ),
    ],
  );

  Widget _hero() => _frame(
    LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _intro(true),
              const SizedBox(height: 28),
              _film(),
              const SizedBox(height: 26),
              _actions(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _intro(false),
                  const SizedBox(height: 28),
                  _actions(),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Expanded(flex: 7, child: _film()),
          ],
        );
      },
    ),
    vertical: 48,
  );

  Widget _product() {
    final name = _supplier ? 'suppliers' : 'butchers';
    return ColoredBox(
      color: PublicPagePalette.surface,
      child: _frame(
        Column(
          key: _productKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'See it in action.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: PublicPagePalette.text,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('For butchers'),
                  selected: !_supplier,
                  onSelected: (_) => setState(() => _supplier = false),
                  selectedColor: const Color(0xFFF1E5E7),
                  labelStyle: const TextStyle(color: PublicPagePalette.primary),
                ),
                ChoiceChip(
                  label: const Text('For suppliers'),
                  selected: _supplier,
                  onSelected: (_) => setState(() => _supplier = true),
                  selectedColor: const Color(0xFFF1E5E7),
                  labelStyle: const TextStyle(color: PublicPagePalette.primary),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Semantics(
              image: true,
              label:
                  'CutLink $name application preview; business identities anonymised',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  _supplier
                      ? 'assets/images/cutlink_supplier_preview.webp'
                      : 'assets/images/cutlink_butcher_preview.webp',
                  key: ValueKey(_supplier),
                  width: double.infinity,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, error, stack) => const SizedBox(
                    height: 220,
                    child: Center(child: Text('Preview unavailable')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _supplier
                  ? 'Sales · Inventory · Buyer approvals · Accounting · Analytics'
                  : 'Marketplace · Ordering · Purchasing · Accounting · Analytics',
              style: const TextStyle(
                color: PublicPagePalette.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PublicPagePalette.primary,
        brightness: Brightness.light,
        surface: PublicPagePalette.background,
      ).copyWith(primary: PublicPagePalette.primary),
      dividerColor: PublicPagePalette.border,
    ),
    child: Scaffold(
      backgroundColor: PublicPagePalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _hero(),
                    _product(),
                    _frame(
                      KeyedSubtree(
                        key: _communityKey,
                        child: FeaturedBusinessesSection(
                          onRegister: widget.onRegister,
                        ),
                      ),
                    ),
                    _frame(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: PublicPagePalette.border),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 32,
                            runSpacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _brand(),
                              Text(
                                '© ${DateTime.now().year} CutLink',
                                style: const TextStyle(
                                  color: PublicPagePalette.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      vertical: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
