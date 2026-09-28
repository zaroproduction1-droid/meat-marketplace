import 'package:flutter/material.dart';
import '../../authentication/presentation/registration_type_page.dart';

/// Public marketing content is independent of authentication and account state.
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
  static const _ink = Color(0xFF282B28);
  static const _red = Color(0xFF852D3D);
  static const _muted = Color(0xFF61665F);
  static const _paper = Color(0xFFF7F3EC);
  final _how = GlobalKey(),
      _suppliers = GlobalKey(),
      _butchers = GlobalKey(),
      _faq = GlobalKey();
  static const _green = Color(0xFF315D4E);
  static const _sage = Color(0xFFEDF3ED);
  bool _supplierDemo = true;
  int _featureIndex = 0;
  final _features = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _brand({bool light = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.link_rounded, color: Colors.white, size: 27),
      ),
      const SizedBox(width: 9),
      Text(
        'CutLink',
        style: TextStyle(
          color: light ? Colors.white : _ink,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
    ],
  );

  Widget _join(BusinessType role, {bool outline = false, bool light = false}) {
    final label = role == BusinessType.supplier
        ? 'Join as a supplier'
        : 'Join as a butcher';
    if (outline) {
      return OutlinedButton.icon(
        onPressed: () => widget.onRegister(role),
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: light ? Colors.white : _ink,
          side: BorderSide(
            color: light ? Colors.white54 : const Color(0xFFC9CED3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => widget.onRegister(role),
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      ),
    );
  }

  Widget _section({
    required Widget child,
    Color color = Colors.white,
    Key? sectionKey,
    double vertical = 64,
  }) => Container(
    key: sectionKey,
    width: double.infinity,
    decoration: BoxDecoration(
      color: color,
      border: Border(
        bottom: BorderSide(
          color: color == _ink ? Colors.transparent : const Color(0xFFE9E5DD),
        ),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600 ? 20 : 40,
        vertical: vertical,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    ),
  );

  Widget _heading(
    String eyebrow,
    String title,
    String body, {
    bool light = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: TextStyle(
          color: light ? const Color(0xFFE9ADB5) : _red,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        title,
        style: TextStyle(
          color: light ? Colors.white : _ink,
          fontSize: MediaQuery.sizeOf(context).width < 600 ? 29 : 38,
          height: 1.12,
          letterSpacing: -.9,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Text(
          body,
          style: TextStyle(
            color: light ? const Color(0xFFBECBD6) : _muted,
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ),
    ],
  );

  Widget _grid(List<Widget> children, {int desktopColumns = 3}) =>
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 960
              ? desktopColumns
              : c.maxWidth >= 620
              ? 2
              : 1;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final child in children)
                SizedBox(
                  width: (c.maxWidth - (columns - 1) * 18) / columns,
                  child: child,
                ),
            ],
          );
        },
      );

  Widget _navigation() => _section(
    vertical: 16,
    child: LayoutBuilder(
      builder: (context, c) => Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: _brand()),
            ),
          ),
          const SizedBox(width: 12),
          if (c.maxWidth >= 1000) ...[
            TextButton(
              onPressed: () => _scrollTo(_how),
              child: const Text('How it works'),
            ),
            TextButton(
              onPressed: () => _scrollTo(_suppliers),
              child: const Text('Suppliers'),
            ),
            TextButton(
              onPressed: () => _scrollTo(_butchers),
              child: const Text('Butchers'),
            ),
            TextButton(
              onPressed: () => _scrollTo(_features),
              child: const Text('Features'),
            ),
            TextButton(
              onPressed: () => _scrollTo(_faq),
              child: const Text('FAQs'),
            ),
            const SizedBox(width: 14),
          ],
          OutlinedButton(
            onPressed: widget.onSignIn,
            child: const Text('Sign in'),
          ),
          if (c.maxWidth < 1000)
            PopupMenuButton<String>(
              tooltip: 'Explore CutLink',
              icon: const Icon(Icons.menu_rounded),
              onSelected: (value) => _scrollTo(switch (value) {
                'suppliers' => _suppliers,
                'butchers' => _butchers,
                'faq' => _faq,
                'features' => _features,
                _ => _how,
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'how', child: Text('How it works')),
                PopupMenuItem(value: 'suppliers', child: Text('For suppliers')),
                PopupMenuItem(value: 'butchers', child: Text('For butchers')),
                PopupMenuItem(
                  value: 'features',
                  child: Text('Explore features'),
                ),
                PopupMenuItem(value: 'faq', child: Text('FAQs')),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _hero() => _section(
    color: _paper,
    vertical: 64,
    child: LayoutBuilder(
      builder: (context, c) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FOR AUSTRALIAN MEAT SUPPLIERS & BUTCHERS',
              style: TextStyle(
                color: _red,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Wholesale meat.\nOne place to\ndo business.',
              style: TextStyle(
                color: _ink,
                fontSize: c.maxWidth < 620 ? 40 : 58,
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1.8,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Suppliers sell and manage their stock. Butchers find the right cuts and place orders. CutLink connects the whole process.',
              style: TextStyle(color: _ink, fontSize: 19, height: 1.55),
            ),
            const SizedBox(height: 16),
            const Text(
              'From product specifications and pricing to actual weights, invoices, delivery and payments — keep the details together, instead of chasing them across calls, messages and paperwork.',
              style: TextStyle(color: _muted, fontSize: 16, height: 1.65),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _join(BusinessType.supplier),
                _join(BusinessType.butcher, outline: true),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _scrollTo(_how),
              icon: const Icon(Icons.south_rounded, size: 18),
              label: const Text('See how an order works'),
              style: TextButton.styleFrom(foregroundColor: _green),
            ),
            const SizedBox(height: 8),
            const Text(
              'Business accounts only • Built for the wholesale trade',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
        );
        if (c.maxWidth < 960) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 36), _workflowPreview()],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 6, child: copy),
            const SizedBox(width: 48),
            Expanded(flex: 5, child: _workflowPreview()),
          ],
        );
      },
    ),
  );

  Widget _workflowPreview() {
    final steps = _supplierDemo
        ? const [
            (
              'Order received',
              'Review the customer’s request',
              Icons.inbox_outlined,
            ),
            (
              'Pick & weigh',
              'Record the actual quantity supplied',
              Icons.scale_outlined,
            ),
            (
              'Create invoice',
              'Turn final weights into a clear document',
              Icons.receipt_long_outlined,
            ),
            (
              'Dispatch or pickup',
              'Keep the customer informed',
              Icons.local_shipping_outlined,
            ),
          ]
        : const [
            (
              'Find your cut',
              'Choose the specification you need',
              Icons.manage_search_rounded,
            ),
            (
              'Compare suppliers',
              'See matching products and available prices',
              Icons.compare_arrows_rounded,
            ),
            (
              'Place your order',
              'Send a request for supplier approval',
              Icons.shopping_bag_outlined,
            ),
            (
              'Track & reconcile',
              'Follow fulfilment and your account',
              Icons.account_balance_wallet_outlined,
            ),
          ];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDDCD2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'WHAT CAN I DO WITH CUTLINK?',
            style: TextStyle(
              color: _green,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final supplier in [true, false])
                ChoiceChip(
                  label: Text(supplier ? 'Supplier view' : 'Butcher view'),
                  selected: _supplierDemo == supplier,
                  onSelected: (_) => setState(() {
                    _supplierDemo = supplier;
                    _featureIndex = 0;
                  }),
                  selectedColor: _supplierDemo
                      ? const Color(0xFFF5E6E7)
                      : _sage,
                  backgroundColor: Colors.white,
                  labelStyle: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: i == 1
                      ? (_supplierDemo ? const Color(0xFFF5E6E7) : _sage)
                      : _paper,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Icon(
                      steps[i].$3,
                      color: _supplierDemo ? _red : _green,
                      size: 23,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$1,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            steps[i].$2,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '0${i + 1}',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Text(
            'An overview of the workflow. Each business has its own workspace.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _problemCard(
    String title,
    String problem,
    String solution,
    IconData icon,
  ) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3E5E8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _red, size: 27),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(problem, style: const TextStyle(color: _muted, height: 1.6)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1),
        ),
        const Text(
          'WITH CUTLINK',
          style: TextStyle(
            color: _red,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(solution, style: const TextStyle(color: _ink, height: 1.6)),
      ],
    ),
  );

  Widget _roleSection({required bool supplier}) {
    final features = supplier
        ? const [
            (
              'Stock & pricing',
              'Keep products, sizes, grades, brands and stock together. Manage standard and customer-specific VIP pricing.',
              Icons.inventory_2_outlined,
            ),
            (
              'Sales & preparation',
              'Create quotes and work orders, pick products and enter actual weights. Add discounts and customer-facing comments.',
              Icons.scale_outlined,
            ),
            (
              'Invoices & accounts',
              'Issue invoices, allocate payments and track outstanding balances. Manage credits and recorded refunds when goods are returned.',
              Icons.receipt_long_outlined,
            ),
            (
              'Delivery & pickup',
              'Organise drivers, delivery runs and packing lists, or mark orders ready for pickup. Manage marketplace and direct customers.',
              Icons.local_shipping_outlined,
            ),
            (
              'Direct customer accounts',
              'Your customer does not need to join CutLink for you to create their quote, manage their order and keep an account balance. Download documents to share with them.',
              Icons.people_outline_rounded,
            ),
            (
              'Returns & credits',
              'Credit an invoiced item, record the reason and handle stock returns where appropriate. Keep credit notes and recorded refunds connected to the customer account.',
              Icons.assignment_return_outlined,
            ),
          ]
        : const [
            (
              'Find the right product',
              'Browse by animal, cut and sub-cut. Refine results by relevant specifications such as brand, size, grade or halal status.',
              Icons.search_rounded,
            ),
            (
              'Compare & save',
              'Compare matching supplier offers and prices available to your account. Save favourite products and searches for next time.',
              Icons.favorite_border_rounded,
            ),
            (
              'Know where your order is',
              'Send an order request, see supplier approval and preparation, then follow delivery or pickup. Open invoices once the supplier shares them.',
              Icons.shopping_bag_outlined,
            ),
            (
              'Keep your account clear',
              'View invoices and account balances, submit payment details for confirmation, and follow credits or order issues in one place.',
              Icons.account_balance_wallet_outlined,
            ),
            (
              'Make regular buying easier',
              'Save a specific supplier product or save your search criteria. Choose favourite products for your dashboard so your usual purchases are easier to find.',
              Icons.bookmark_border_rounded,
            ),
            (
              'Resolve issues in context',
              'Raise an issue against an order and talk with the supplier in the same conversation. Follow the resolution and any credit issued to your account.',
              Icons.forum_outlined,
            ),
          ];
    final title = supplier
        ? 'Your sales desk, warehouse\nand accounts — connected.'
        : 'Buy what your shop needs.\nKeep track of every order.';
    return _section(
      sectionKey: supplier ? _suppliers : _butchers,
      color: supplier ? Colors.white : _sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            supplier ? 'For suppliers' : 'For butchers',
            title,
            supplier
                ? 'List what you have, set your prices and manage each sale through to payment. Use CutLink for marketplace orders and for customers who order directly from you.'
                : 'Find the cut, size and brand you need, compare supplier offers and place your order. Then follow its progress and keep your invoices, payments and credits in one place.',
          ),
          const SizedBox(height: 30),
          _grid([
            for (final feature in features)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: supplier ? _paper : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(feature.$3, color: supplier ? _red : _green, size: 26),
                    const SizedBox(height: 15),
                    Text(
                      feature.$1,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      feature.$2,
                      style: const TextStyle(color: _muted, height: 1.6),
                    ),
                  ],
                ),
              ),
          ], desktopColumns: 2),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _join(supplier ? BusinessType.supplier : BusinessType.butcher),
              Text(
                supplier
                    ? 'Your stock. Your customer relationships. Your workflow.'
                    : 'Your regular suppliers, with a clearer way to order.',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _howItWorks() => _section(
    sectionKey: _how,
    color: _sage,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Follow one order',
          'From “I need stock” to “order complete”.',
          'Here is what happens when a butcher places an order with a supplier on CutLink.',
        ),
        const SizedBox(height: 30),
        _grid([
          for (final step in const [
            (
              '01',
              'Choose the product',
              'BUTCHER',
              'Browse the animal catalogue, choose a cut and sub-cut, then compare the available specifications, suppliers and prices.',
            ),
            (
              '02',
              'Send & approve the order',
              'BOTH BUSINESSES',
              'The butcher sends an order request. It stays pending until the supplier approves it and starts preparation.',
            ),
            (
              '03',
              'Pick & weigh',
              'SUPPLIER',
              'The supplier works through the order and records actual quantities and weights. The butcher sees preparation progress, not the internal work order.',
            ),
            (
              '04',
              'Create & share the invoice',
              'SUPPLIER',
              'Final quantities and locked prices form the invoice. The butcher can open it once the supplier shares it.',
            ),
            (
              '05',
              'Deliver or collect',
              'BOTH BUSINESSES',
              'The supplier arranges dispatch or marks the order ready for pickup. Delivery or collection is recorded separately from invoicing.',
            ),
            (
              '06',
              'Keep the account up to date',
              'BOTH BUSINESSES',
              'The butcher submits payment details. The supplier confirms receipt and allocates funds, with outstanding balances and credits kept on the account.',
            ),
          ])
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDCE6DC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.$1,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    step.$3,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.$2,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.$4,
                    style: const TextStyle(color: _muted, height: 1.6),
                  ),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Actual weights. Clear invoice amounts.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A simple catch-weight example',
                style: TextStyle(color: Color(0xFFD4E4D8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  for (final value in const [
                    ('ACTUAL WEIGHT', '42 kg'),
                    ('LOCKED RATE', '\$12 / kg'),
                    ('LINE AMOUNT', '\$504'),
                  ])
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.$1,
                          style: const TextStyle(
                            color: Color(0xFFD4E4D8),
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Illustration only, before any applicable tax, delivery or discounts. '
                'The final invoice reflects what was actually supplied.',
                style: TextStyle(
                  color: Color(0xFFD4E4D8),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _featureGuide() {
    final features = _supplierDemo
        ? const [
            (
              'Inventory & pricing',
              Icons.inventory_2_outlined,
              'List the product once. Keep the useful details together.',
              'Choose the animal, cut and sub-cut, then add the specifications that apply. '
                  'Customers can compare what you actually sell instead of guessing from a product name.',
              [
                'Grades, brands, sizes and relevant commercial specifications',
                'Stock availability and supplier product codes',
                'Standard prices and customer-specific VIP pricing',
              ],
            ),
            (
              'Quotes & work orders',
              Icons.scale_outlined,
              'Move from a quote to an order your team can prepare.',
              'Use a work order to pick stock, enter actual weights and see the running total before creating the invoice.',
              [
                'Convert a quote into a work order',
                'Carry discounts and public comments through the document stages',
                'Keep supplier-private notes separate from customer documents',
              ],
            ),
            (
              'Invoices & accounts',
              Icons.receipt_long_outlined,
              'See the invoice and the wider customer account.',
              'Manage invoices, payment allocations and credit notes together so your team can see what has been paid and what remains outstanding.',
              [
                'Branded documents to preview, download and print',
                'Allocate received payments, including remaining unallocated funds',
                'Manage direct customers as well as CutLink members',
              ],
            ),
            (
              'Delivery & pickup',
              Icons.local_shipping_outlined,
              'Give the warehouse and driver a clear next step.',
              'Invoicing and fulfilment are separate. Arrange a delivery run or prepare an order for pickup when the goods are ready.',
              [
                'Manage delivery runs, drivers and vehicles',
                'Download packing lists for deliveries',
                'Record dispatch, collection and completion',
              ],
            ),
          ]
        : const [
            (
              'Product search',
              Icons.manage_search_rounded,
              'Start with the cut. Narrow it down to what you need.',
              'Browse the animal catalogue or search directly. Compare matching supplier products using the relevant details for that animal and cut.',
              [
                'Animal, main cut and sub-cut browsing',
                'Relevant filters for size, grade, brand and halal status',
                'Supplier information, available stock and account pricing',
              ],
            ),
            (
              'Favourites',
              Icons.favorite_border_rounded,
              'Make your regular purchases easier to find.',
              'Save the exact supplier product you buy, or save a search when you want to compare the options again next time.',
              [
                'Separate product and search favourites',
                'Filter your saved favourites',
                'Choose up to four favourite products for your dashboard',
              ],
            ),
            (
              'Orders & invoices',
              Icons.shopping_bag_outlined,
              'Know what is happening after you place the order.',
              'Follow supplier approval, preparation and fulfilment. View the final invoice when the supplier makes it available to you.',
              [
                'Clear order stages for delivery and pickup',
                'Invoice preview with zoom, download and print',
                'Product specifications and actual supplied quantities',
              ],
            ),
            (
              'Accounts & help',
              Icons.forum_outlined,
              'Keep payment records and order conversations together.',
              'View your account with each supplier and submit payment details for confirmation. If something is wrong, raise it against the order.',
              [
                'Invoices, payments and available credits',
                'Order issue conversations with the supplier',
                'CutLink support tickets with file attachments',
              ],
            ),
          ];
    final selected = features[_featureIndex];
    final accent = _supplierDemo ? _red : _green;
    final detail = Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 22 : 32),
      decoration: BoxDecoration(
        color: _supplierDemo ? const Color(0xFFFBF0EE) : _sage,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(selected.$2, color: accent, size: 36),
          const SizedBox(height: 20),
          Text(
            selected.$3,
            style: const TextStyle(
              color: _ink,
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            selected.$4,
            style: const TextStyle(color: _muted, fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 22),
          for (final point in selected.$5)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(color: _ink, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final menu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < features.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => setState(() => _featureIndex = i),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(18),
                backgroundColor: i == _featureIndex ? accent : Colors.white,
                foregroundColor: i == _featureIndex ? Colors.white : _ink,
                side: BorderSide(
                  color: i == _featureIndex ? accent : const Color(0xFFE0E3DC),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(features[i].$2, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      features[i].$1,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
    return _section(
      sectionKey: _features,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Explore the tools',
            'What is inside CutLink?',
            'Choose your business type, then select a feature to see how it helps with the day-to-day work.',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final supplier in [true, false])
                ChoiceChip(
                  label: Text(supplier ? 'I am a supplier' : 'I am a butcher'),
                  selected: _supplierDemo == supplier,
                  selectedColor: supplier ? const Color(0xFFF5E6E7) : _sage,
                  labelStyle: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() {
                    _supplierDemo = supplier;
                    _featureIndex = 0;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < 760
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [menu, const SizedBox(height: 12), detail],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: menu),
                      const SizedBox(width: 28),
                      Expanded(flex: 3, child: detail),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _gettingStarted() => _section(
    color: _paper,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Getting started',
          'Set up your business. Then make it yours.',
          'Choose the right account for your business and complete registration. Once approved, you can set up the details that matter to your work.',
        ),
        const SizedBox(height: 28),
        _grid([
          _problemCard(
            '1. Register your business',
            'Choose Supplier if you sell wholesale meat, or Butcher if you buy for your shop.',
            'Add your business details and submit your registration for approval.',
            Icons.storefront_outlined,
          ),
          _problemCard(
            '2. Set up your workspace',
            'Suppliers add products, prices, customer accounts and fulfilment details.',
            'Butchers complete their business and delivery details, then explore suppliers and products.',
            Icons.tune_rounded,
          ),
          _problemCard(
            '3. Start trading',
            'Suppliers manage incoming orders and direct sales. Butchers place orders and save their regular products.',
            'Use the in-app FAQs or contact CutLink support if you need help along the way.',
            Icons.handshake_outlined,
          ),
        ]),
      ],
    ),
  );

  Widget _faqs() => _section(
    sectionKey: _faq,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'A few useful answers',
          'Questions you may already have.',
          'The essentials for deciding whether CutLink fits your business.',
        ),
        const SizedBox(height: 26),
        for (final qa in const [
          (
            'Is CutLink the seller of the meat?',
            'CutLink connects suppliers and butcher businesses and provides the tools to manage their trade. The products, prices and fulfilment arrangements come from the supplier selling the goods.',
          ),
          (
            'Can I use CutLink on my phone?',
            'Yes. CutLink has layouts for phones and desktop screens. You can access it in your web browser to browse products, check orders and manage your work.',
          ),
          (
            'Does submitting payment details mean the invoice is paid?',
            'The supplier still needs to confirm receipt and allocate the payment. Submitting payment details records your payment claim; it does not itself transfer money or confirm payment.',
          ),
          (
            'Who is CutLink for?',
            'CutLink is for wholesale meat suppliers and butcher businesses. It is a business-to-business system, not a shopping site for the general public. Businesses register with their details for approval.',
          ),
          (
            'Does it handle actual weights?',
            'Yes. Suppliers can enter actual supplied weights on the work order for catch-weight products. The final invoice uses the supplied quantities and applicable locked prices, with any commercial adjustments.',
          ),
          (
            'Can a supplier manage customers who are not CutLink members?',
            'Yes. Suppliers can manage direct customer accounts, orders, invoices and account balances alongside marketplace customers. Those customers do not need a CutLink login for the supplier to manage their account.',
          ),
          (
            'Can I keep customer-specific pricing?',
            'Yes. Suppliers can manage VIP or customer-specific pricing. Butchers see the prices made available to their account.',
          ),
          (
            'What happens if there is a problem with an order?',
            'The butcher and supplier can raise and discuss an order issue within CutLink. Suppliers can issue credit notes and record refunds where appropriate. For help using CutLink itself, either business can open a support ticket and attach files.',
          ),
          (
            'Are delivery and pickup both supported?',
            'Yes. Suppliers manage their delivery arrangements and runs, while pickup has its own ready and collected stages. Availability and commercial terms depend on the supplier.',
          ),
        ])
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE3E5E8)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                qa.$1,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(qa.$2, style: const TextStyle(color: _muted, height: 1.6)),
              ],
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: SelectionArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _navigation(),
              _hero(),
              _section(
                vertical: 22,
                color: _paper,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 26,
                  runSpacing: 12,
                  children: [
                    const Text(
                      'BUILT AROUND YOUR TRADE',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    for (final animal in [
                      'Beef',
                      'Veal',
                      'Lamb',
                      'Mutton',
                      'Goat',
                      'Chicken',
                    ])
                      Text(
                        animal,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              _section(
                color: _paper,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'The daily back-and-forth',
                      'Less chasing. Fewer loose ends.',
                      'A missed message, an unclear specification or an invoice that needs chasing can slow down both businesses. Give the work a clear place to happen.',
                    ),
                    const SizedBox(height: 30),
                    _grid([
                      _problemCard(
                        '“Which cut did you mean?”',
                        'A product name alone may not tell you the brand, size, grade or preparation required.',
                        'Structured product details help the butcher choose and the supplier prepare the right specification.',
                        Icons.manage_search_rounded,
                      ),
                      _problemCard(
                        '“Has my order been picked?”',
                        'Updates get spread across calls, messages and handwritten notes.',
                        'Order stages make approval, preparation, delivery and pickup easier to follow.',
                        Icons.forum_outlined,
                      ),
                      _problemCard(
                        '“What do I still owe?”',
                        'Invoices, payments and returned goods can be difficult to reconcile across separate records.',
                        'Invoices, payment allocations, credits and account balances sit in the same system.',
                        Icons.receipt_long_outlined,
                      ),
                    ]),
                  ],
                ),
              ),
              _roleSection(supplier: true),
              _roleSection(supplier: false),
              _howItWorks(),
              _featureGuide(),
              _gettingStarted(),
              _faqs(),
              _section(
                color: _paper,
                vertical: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'Ready to get started?',
                      'Bring your business to CutLink.',
                      'Selling wholesale meat? Register as a supplier. Buying for your butcher shop? Register as a butcher.',
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _join(BusinessType.supplier),
                        _join(BusinessType.butcher, outline: true),
                      ],
                    ),
                  ],
                ),
              ),
              _section(
                color: _ink,
                vertical: 28,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 28,
                  runSpacing: 20,
                  children: [
                    _brand(light: true),
                    Text(
                      '© ${DateTime.now().year} CutLink. Wholesale meat, connected.',
                      style: const TextStyle(
                        color: Color(0xFFB4C3CF),
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onSignIn,
                      child: const Text(
                        'Already registered? Sign in',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
