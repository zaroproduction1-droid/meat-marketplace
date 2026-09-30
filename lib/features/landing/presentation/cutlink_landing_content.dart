import 'package:flutter/material.dart';
import '../../authentication/presentation/registration_type_page.dart';
import 'featured_businesses_section.dart';
import 'landing_catalogue_section.dart';
import 'trade_story_animation.dart';
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
  static const _bg = PublicPagePalette.background,
      _panel = PublicPagePalette.surface,
      _line = PublicPagePalette.border,
      _muted = PublicPagePalette.muted,
      _red = PublicPagePalette.primary,
      _accent = PublicPagePalette.accent;
  final _scroll = ScrollController();
  final _how = GlobalKey(),
      _catalogue = GlobalKey(),
      _suppliers = GlobalKey(),
      _butchers = GlobalKey(),
      _community = GlobalKey(),
      _faq = GlobalKey();
  bool _top = false, _supplierSteps = false;
  GlobalKey? _active;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
  }

  void _scrolled() {
    final value = _scroll.offset > 500;
    if (value != _top) {
      setState(() => _top = value);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_scrolled);
    _scroll.dispose();
    super.dispose();
  }

  void _to(GlobalKey key) {
    setState(() => _active = key);
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Widget _join(BusinessType role, {bool outline = false}) {
    final label = role == BusinessType.supplier
        ? 'Join as a supplier'
        : 'Join as a butcher';
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22, vertical: 21),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      foregroundColor: WidgetStatePropertyAll(
        outline ? PublicPagePalette.primary : Colors.white,
      ),
    );
    return outline
        ? OutlinedButton.icon(
            onPressed: () => widget.onRegister(role),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(label),
            style: style.copyWith(
              side: const WidgetStatePropertyAll(BorderSide(color: _line)),
            ),
          )
        : FilledButton.icon(
            onPressed: () => widget.onRegister(role),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(label),
            style: style.copyWith(
              backgroundColor: const WidgetStatePropertyAll(_red),
            ),
          );
  }

  Widget _brand() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.link_rounded, size: 27, color: Colors.white),
      ),
      const SizedBox(width: 9),
      const Text(
        'CutLink',
        style: TextStyle(
          color: PublicPagePalette.text,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -.8,
        ),
      ),
    ],
  );
  Widget _header() => Container(
    decoration: const BoxDecoration(
      color: _bg,
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600 ? 18 : 32,
              vertical: 14,
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final nav = Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final item in [
                      ('How it works', _how),
                      ('Catalogue', _catalogue),
                      ('Suppliers', _suppliers),
                      ('Butchers', _butchers),
                      ('Community', _community),
                    ])
                      TextButton(
                        onPressed: () => _to(item.$2),
                        style: TextButton.styleFrom(
                          foregroundColor: _active == item.$2
                              ? _accent
                              : _muted,
                          backgroundColor: _active == item.$2
                              ? _panel
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 13,
                          ),
                        ),
                        child: Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                );
                final login = TextButton.icon(
                  onPressed: widget.onSignIn,
                  icon: const Icon(Icons.login_rounded, size: 17),
                  label: const Text('Sign in'),
                  style: TextButton.styleFrom(
                    foregroundColor: PublicPagePalette.text,
                  ),
                );
                if (box.maxWidth >= 1100) {
                  return Row(
                    children: [
                      _brand(),
                      const Spacer(),
                      nav,
                      const SizedBox(width: 20),
                      login,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [_brand(), login],
                      ),
                    ),
                    const SizedBox(height: 8),
                    nav,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  Widget _section({
    required Widget child,
    Key? anchor,
    Color color = _bg,
    double space = 76,
  }) => Container(
    key: anchor,
    width: double.infinity,
    decoration: BoxDecoration(
      color: color,
      border: const Border(bottom: BorderSide(color: PublicPagePalette.border)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600 ? 20 : 40,
            vertical: MediaQuery.sizeOf(context).width < 600
                ? space * .7
                : space,
          ),
          child: child,
        ),
      ),
    ),
  );
  Widget _heading(
    String eyebrow,
    String title,
    String description, {
    double max = 780,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          color: _accent,
          fontSize: 11,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Text(
          title,
          style: TextStyle(
            color: PublicPagePalette.text,
            fontSize: MediaQuery.sizeOf(context).width < 600 ? 31 : 42,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -1,
          ),
        ),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Text(
          description,
          style: const TextStyle(color: _muted, fontSize: 16, height: 1.65),
        ),
      ),
    ],
  );
  Widget _grid(List<Widget> children, {int columns = 3}) => LayoutBuilder(
    builder: (context, box) {
      final count = box.maxWidth >= 1000
          ? columns
          : box.maxWidth >= 650
          ? 2
          : 1;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final child in children)
            SizedBox(
              width: (box.maxWidth - 18 * (count - 1)) / count,
              child: child,
            ),
        ],
      );
    },
  );
  Widget _surface({required Widget child, Color color = _panel}) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
    ),
    child: child,
  );
  Widget _hero() => _section(
    space: 54,
    child: LayoutBuilder(
      builder: (context, box) {
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: PublicPagePalette.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: PublicPagePalette.border),
              ),
              child: const Text(
                'BUILT FOR THE WHOLESALE MEAT TRADE',
                style: TextStyle(
                  color: _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Less chasing.\nMore trading.',
              style: TextStyle(
                color: PublicPagePalette.text,
                fontSize: box.maxWidth < 650 ? 48 : 66,
                height: 1.02,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your meat trade.\nOne connected workspace.',
              style: TextStyle(
                color: _accent,
                fontSize: 21,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sales, stock, marketplace orders, invoicing, accounts and analytics—connected in one workspace for meat suppliers and butchers. Spend less time moving the same details between separate programs.',
              style: TextStyle(color: _muted, fontSize: 16, height: 1.7),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _join(BusinessType.butcher),
                _join(BusinessType.supplier, outline: true),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                for (final label in [
                  'Business accounts',
                  'Clear specifications',
                  'Delivery & pickup',
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: _accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
        const preview = TradeStoryAnimation();
        if (box.maxWidth < 950) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [intro, const SizedBox(height: 36), preview],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: intro),
            const SizedBox(width: 52),
            Expanded(child: preview),
          ],
        );
      },
    ),
  );
  Widget _tradeStrip() => _section(
    space: 22,
    color: _panel,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        const Text(
          'SIX ANIMALS. ONE CONNECTED CATALOGUE.',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        for (final name in [
          'Beef',
          'Veal',
          'Lamb',
          'Mutton',
          'Goat',
          'Chicken',
        ])
          Text(
            name,
            style: const TextStyle(
              color: PublicPagePalette.text,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
      ],
    ),
  );
  Widget _problems() => _section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Why CutLink',
          'Good trade should be easier to manage.',
          'Bring the details together so both businesses can spend less time checking messages and more time getting the order right.',
        ),
        const SizedBox(height: 32),
        _grid([
          for (final row in [
            (
              Icons.manage_search_rounded,
              '“Is this the cut I asked for?”',
              'A name alone can leave size, grade and preparation unclear.',
              'Choose from a visual catalogue and structured product specifications.',
            ),
            (
              Icons.notifications_active_outlined,
              '“Where is my order up to?”',
              'Phone calls and messages make progress hard to follow.',
              'Follow approval, picking, invoicing, dispatch and completion.',
            ),
            (
              Icons.account_balance_wallet_outlined,
              '“What do we still owe?”',
              'Loose invoices, payments and credits slow down reconciliation.',
              'Keep invoices, payment allocations, credit notes and balances together.',
            ),
          ])
            _surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.$1, color: _accent, size: 27),
                  const SizedBox(height: 18),
                  Text(
                    row.$2,
                    style: const TextStyle(
                      color: PublicPagePalette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    row.$3,
                    style: const TextStyle(color: _muted, height: 1.6),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: _line, height: 1),
                  ),
                  const Text(
                    'WITH CUTLINK',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    row.$4,
                    style: const TextStyle(
                      color: PublicPagePalette.text,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ],
    ),
  );
  Widget _howSection() {
    final steps = _supplierSteps
        ? [
            (
              '01',
              'List your products',
              'Choose the animal and cut, add clear specifications, availability and pricing.',
            ),
            (
              '02',
              'Confirm and prepare',
              'Review the order, pick the goods and record the actual weight where required.',
            ),
            (
              '03',
              'Invoice and fulfil',
              'Create the invoice, organise delivery or pickup and keep the account up to date.',
            ),
          ]
        : [
            (
              '01',
              'Find the right product',
              'Choose an animal and cut. Refine specifications and compare supplier products and available prices.',
            ),
            (
              '02',
              'Send your order',
              'Build the order and send it to the supplier for approval. Follow its progress in CutLink.',
            ),
            (
              '03',
              'Receive and reconcile',
              'Track delivery or pickup, see the final invoice and manage payments or order issues.',
            ),
          ];
    return _section(
      anchor: _how,
      color: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'How it works',
            'A simpler day, on both sides of the trade.',
            'Choose your role to see how an order moves through CutLink.',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final supplier in [false, true])
                ChoiceChip(
                  label: Text(
                    supplier ? 'I supply meat' : 'I run a butcher shop',
                  ),
                  selected: _supplierSteps == supplier,
                  onSelected: (_) => setState(() => _supplierSteps = supplier),
                  showCheckmark: false,
                  selectedColor: _red,
                  backgroundColor: _bg,
                  labelStyle: const TextStyle(
                    color: PublicPagePalette.text,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.all(13),
                  side: const BorderSide(color: _line),
                ),
            ],
          ),
          const SizedBox(height: 28),
          _grid([
            for (final row in steps)
              _surface(
                color: _bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.$1,
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      row.$2,
                      style: const TextStyle(
                        color: PublicPagePalette.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      row.$3,
                      style: const TextStyle(color: _muted, height: 1.65),
                    ),
                  ],
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _role(bool supplier) {
    final features = supplier
        ? [
            (
              Icons.point_of_sale_outlined,
              'Sales, quotes & work orders',
              'Create quotes and sales orders, approve incoming orders and keep preparation, invoices and order history together.',
            ),
            (
              Icons.inventory_2_outlined,
              'Inventory & product catalogue',
              'Manage products, stock quantities and availability by animal, cut, specification and grade. Keep your range ready to order.',
            ),
            (
              Icons.groups_outlined,
              'A marketplace of approved butchers',
              'Put your products in front of approved butcher businesses ready to source stock and send orders through CutLink.',
            ),
            (
              Icons.verified_user_outlined,
              'Authorise your customers',
              'Review butcher relationship requests, authorise customer access and manage VIP applications and commercial terms.',
            ),
            (
              Icons.price_change_outlined,
              'Pricing for each customer',
              'Manage Standard, Trade and VIP pricing, private price lists and customer-specific prices without maintaining scattered lists.',
            ),
            (
              Icons.account_balance_wallet_outlined,
              'Accounting for your trade',
              'Keep invoices, payments, allocations, credit notes, statements and outstanding customer balances in one accounts workspace.',
            ),
            (
              Icons.local_shipping_outlined,
              'Picking, weighing & fulfilment',
              'Record actual weights, create the invoice, then organise delivery runs, drivers, packing lists or pickup. Invoicing and dispatch remain separate stages.',
            ),
            (
              Icons.insights_outlined,
              'Sales & business analytics',
              'Review sales value, customers, products and business performance. Customise analytics sections and download reports.',
            ),
          ]
        : [
            (
              Icons.touch_app_outlined,
              'A marketplace built around cuts',
              'Start with Beef, Veal, Lamb, Mutton, Goat or Chicken. Choose a cut and specification, then explore supplier products.',
            ),
            (
              Icons.compare_arrows_rounded,
              'Supplier options & your prices',
              'Compare relevant product specifications and the prices available to your business before building your order.',
            ),
            (
              Icons.handshake_outlined,
              'Supplier relationships & VIP access',
              'Request access to supplier relationships and apply for VIP terms. Supplier approval controls the access and pricing you receive.',
            ),
            (
              Icons.shopping_basket_outlined,
              'Ordering & repeat purchasing',
              'Build draft orders, keep favourites and saved searches, then send orders for supplier approval without retyping product details.',
            ),
            (
              Icons.local_shipping_outlined,
              'Follow preparation & fulfilment',
              'Track submitted orders through preparation, invoicing and delivery or pickup. Open the related order documents as the job progresses.',
            ),
            (
              Icons.account_balance_wallet_outlined,
              'Purchasing accounts together',
              'View supplier invoices, credits, statements and balances. Submit payment details for the supplier to confirm and allocate.',
            ),
            (
              Icons.insights_outlined,
              'Purchasing & spend analytics',
              'Understand purchasing spend, supplier mix, products and buying performance with customisable analytics and downloadable reports.',
            ),
            (
              Icons.support_agent_outlined,
              'Order issues & support',
              'Raise order issues with the supplier, follow the outcome and use CutLink support tickets when you need help with the platform.',
            ),
          ];
    return _section(
      anchor: supplier ? _suppliers : _butchers,
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            supplier ? 'For suppliers' : 'For butchers',
            supplier
                ? 'Run your wholesale business in one place.'
                : 'Source, order and manage your shop’s purchasing.',
            supplier
                ? 'Sales, inventory, an approved buyer marketplace, customer authorisation, trade accounting, fulfilment and analytics—connected from the first quote to the final account balance.'
                : 'A connected purchasing workspace for finding stock, managing supplier relationships, tracking orders, reviewing accounts and understanding what your business buys.',
          ),
          const SizedBox(height: 32),
          _grid([
            for (final f in features)
              _surface(
                color: _panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(f.$1, color: _accent, size: 28),
                    const SizedBox(height: 18),
                    Text(
                      f.$2,
                      style: const TextStyle(
                        color: PublicPagePalette.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      f.$3,
                      style: const TextStyle(color: _muted, height: 1.65),
                    ),
                  ],
                ),
              ),
          ], columns: 2),
          const SizedBox(height: 26),
          _join(supplier ? BusinessType.supplier : BusinessType.butcher),
        ],
      ),
    );
  }

  Widget _comparison() => _section(
    color: _panel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'One connected system',
          'Stop spreading the same job across multiple programs.',
          'CutLink brings your meat marketplace, sales and purchasing, stock, trade accounts, fulfilment and analytics together. The order details stay connected as the work moves forward.',
        ),
        const SizedBox(height: 28),
        for (final row in [
          (
            'Product details',
            'Descriptions buried in messages',
            'Animal, cut and product specifications',
          ),
          (
            'Customer pricing',
            'Separate lists to keep checking',
            'Standard, Trade and customer-specific prices',
          ),
          (
            'Preparation',
            'Handwritten picking notes',
            'Work orders, quantities and recorded weights',
          ),
          (
            'Fulfilment',
            'Calls to ask what is ready',
            'Delivery and pickup stages with packing lists',
          ),
          (
            'Accounts',
            'Invoices and credits in different places',
            'Invoices, payments, credits and balances',
          ),
          (
            'Business insight',
            'Exporting numbers into separate reports',
            'Sales and purchasing analytics in the same workspace',
          ),
          (
            'Customer relationships',
            'Access and terms tracked separately',
            'Butcher authorisation, VIP requests and customer pricing',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, box) {
                final cells = [
                  Text(
                    row.$1,
                    style: const TextStyle(
                      color: PublicPagePalette.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    row.$2,
                    style: const TextStyle(color: _muted, height: 1.5),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: _accent,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          row.$3,
                          style: const TextStyle(
                            color: PublicPagePalette.text,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ];
                return _surface(
                  color: _bg,
                  child: box.maxWidth < 700
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cells[0],
                            const SizedBox(height: 12),
                            cells[1],
                            const SizedBox(height: 12),
                            cells[2],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(flex: 2, child: cells[0]),
                            const SizedBox(width: 20),
                            Expanded(flex: 3, child: cells[1]),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: cells[2]),
                          ],
                        ),
                );
              },
            ),
          ),
      ],
    ),
  );
  Widget _weightExample() => _section(
    space: 54,
    color: PublicPagePalette.background,
    child: LayoutBuilder(
      builder: (context, box) {
        final intro = _heading(
          'Catch-weight products',
          'Ordered quantity. Recorded weight. Clear final value.',
          'Some meat products are invoiced on their actual weight. CutLink connects the recorded kilograms to the locked price per kilogram.',
          max: 570,
        );
        final example = _surface(
          color: PublicPagePalette.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ILLUSTRATIVE EXAMPLE',
                style: TextStyle(
                  color: _accent,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              for (final line in [
                ('Product', 'Scotch fillet'),
                ('Ordered', '2 pieces'),
                ('Actual picked weight', '9.4 kg'),
                ('Locked unit price', '\$24.00 / kg'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.$1,
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        line.$2,
                        style: const TextStyle(
                          color: PublicPagePalette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(color: _line),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Product line value',
                      style: TextStyle(
                        color: PublicPagePalette.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '\$225.60',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '9.4 kg × \$24.00. Delivery, discounts and applicable taxes are handled on the document.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        );
        return box.maxWidth < 900
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 26), example],
              )
            : Row(
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 50),
                  Expanded(child: example),
                ],
              );
      },
    ),
  );
  Widget _faqs() => _section(
    anchor: _faq,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Questions, answered',
          'Know what to expect before you join.',
          'The essentials for suppliers and butcher shops.',
        ),
        const SizedBox(height: 28),
        for (final qa in [
          (
            'Who is CutLink for?',
            'CutLink is for wholesale meat suppliers and butcher businesses. Register the role that matches your business; approval is part of the account setup.',
          ),
          (
            'Which animals are in the catalogue?',
            'Beef, Veal, Lamb, Mutton, Goat and Chicken. The relevant cuts, specifications and grade options depend on the animal.',
          ),
          (
            'Does clicking a cut place an order?',
            'No. This page is a catalogue preview. Inside your account, choose the product and supplier, review the details and send the order for supplier approval.',
          ),
          (
            'Can suppliers use a specification that is not listed?',
            'Suppliers can retain custom specifications, such as a particular size, while using structured options where available. Those product details are visible to butchers.',
          ),
          (
            'How does VIP pricing work?',
            'The supplier controls customer-specific prices. A butcher sees the price available to their business. Access and commercial terms depend on the supplier relationship.',
          ),
          (
            'Are delivery and pickup supported?',
            'Yes. Suppliers manage their fulfilment arrangements. Delivery orders can use delivery runs and packing lists, while pickup follows ready and collected stages.',
          ),
          (
            'Does CutLink take payment for the meat?',
            'The app records payment details and account allocations. The supplier confirms receipt and applies the payment; payment arrangements remain between the businesses.',
          ),
          (
            'Where can I get help?',
            'Signed-in businesses can use Support, including role-specific FAQs and support tickets. Order issues can be raised with the supplier from the order workflow.',
          ),
        ])
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _line),
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: _accent,
              collapsedIconColor: _muted,
              title: Text(
                qa.$1,
                style: const TextStyle(
                  color: PublicPagePalette.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 20, 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qa.$2,
                  style: const TextStyle(color: _muted, height: 1.65),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _red,
        brightness: Brightness.light,
        surface: _panel,
      ),
      dividerColor: _line,
    ),
    child: Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _top
          ? FloatingActionButton.small(
              heroTag: 'landing-top',
              tooltip: 'Back to top',
              onPressed: () => _scroll.animateTo(
                0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              ),
              backgroundColor: _red,
              foregroundColor: Colors.white,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  _hero(),
                  _tradeStrip(),
                  _section(
                    anchor: _community,
                    space: 54,
                    color: _panel,
                    child: FeaturedBusinessesSection(
                      onRegister: widget.onRegister,
                    ),
                  ),
                  _problems(),
                  _howSection(),
                  _section(
                    anchor: _catalogue,
                    space: 42,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(
                          'Explore the catalogue',
                          'Start with the animal. Find the right cut.',
                          'Try the same interactive diagrams used in CutLink. Select an animal, tap a cut and see how the product search begins.',
                        ),
                        const SizedBox(height: 28),
                        LandingCatalogueSection(
                          onBrowse: () =>
                              widget.onRegister(BusinessType.butcher),
                        ),
                      ],
                    ),
                  ),
                  _role(true),
                  _role(false),
                  _comparison(),
                  _weightExample(),
                  _faqs(),
                  _section(
                    space: 60,
                    color: PublicPagePalette.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(
                          'Your next step',
                          'Bring your business to CutLink.',
                          'Suppliers: organise your stock, orders and customer prices. Butchers: find products, place orders and follow them through.',
                        ),
                        const SizedBox(height: 26),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _join(BusinessType.supplier),
                            _join(BusinessType.butcher, outline: true),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: widget.onSignIn,
                          style: TextButton.styleFrom(
                            foregroundColor: PublicPagePalette.text,
                          ),
                          child: const Text('Already registered? Sign in'),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    space: 30,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 24,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _brand(),
                        const Text(
                          'Wholesale meat. Connected.',
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () => _to(_faq),
                          style: TextButton.styleFrom(foregroundColor: _muted),
                          child: const Text('Questions & support'),
                        ),
                        Text(
                          '© ${DateTime.now().year} CutLink',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
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
