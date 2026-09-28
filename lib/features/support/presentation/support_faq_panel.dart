import 'package:flutter/material.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';

class SupportFaqPanel extends StatefulWidget {
  const SupportFaqPanel({
    super.key,
    required this.businessType,
    this.adminMode = false,
  });
  final String businessType;
  final bool adminMode;
  @override
  State<SupportFaqPanel> createState() => _SupportFaqPanelState();
}

class _SupportFaqPanelState extends State<SupportFaqPanel> {
  String _role = 'butcher', _search = '';
  static const _entries = <(String, String, String)>[
    (
      'supplier',
      'Which price does a customer receive?',
      'A customer-specific VIP price takes priority, followed by an applicable Trade price, then Standard pricing. Set the price for the correct product and pricing unit. VIP prices are private to assigned customers.',
    ),
    (
      'supplier',
      'How do I set a VIP price?',
      'Open Inventory & Pricing, find the product and open its Pricing tab. Search under VIP customer prices, choose Set VIP price, enter the agreed amount and save. Approve the customer relationship first. In the inventory quick editor, queued price changes must also be saved.',
    ),
    (
      'supplier',
      'How do catch-weight cartons work?',
      'Enter stock and pick quantity in cartons. Pricing is per kilogram. Record the actual picked weight on the Work Order; that weight multiplied by the locked price determines the line value. Piece weight describes each cut, not the whole carton.',
    ),
    (
      'supplier',
      'What if my piece size is not listed?',
      'Choose an existing size for the selected sub-cut, or enter your exact weight or range. For example, 4.7 kg is stored as a product attribute and can appear in butcher size filters once the active product is available to them. Use the correct kg or g unit.',
    ),
    (
      'supplier',
      'How do I turn a quote into an invoice?',
      'Convert the Quote to a Work Order, pick the items and finalise actual weights, then create the invoice. Check discounts, delivery and public comments before invoicing. Invoice creation does not dispatch the order; complete delivery or pickup separately.',
    ),
    (
      'supplier',
      'Which comments can my customer see?',
      'Public comments can appear on customer documents and previews. Private comments stay supplier-only and do not print. Never put supplier-only information in a public comment or product description.',
    ),
    (
      'supplier',
      'How do I handle a return after invoicing?',
      'Open the invoice and use Credit. Select the returned items or amount and the reason. Choose restocking only for stock that can safely return to inventory. Record refunds separately when money is actually returned; an account credit is not a cash refund.',
    ),
    (
      'supplier',
      'What happens to an extra customer payment?',
      'Confirm only money you have received. Allocate it to outstanding invoices. Any remaining amount stays unallocated for a later invoice; do not create another invoice simply to use the balance.',
    ),
    (
      'supplier',
      'Why can I not assign a driver?',
      'Add an active driver under Delivery → Drivers & Vehicles. Check the order has a complete delivery address. Pickup orders do not need a delivery run.',
    ),
    (
      'butcher',
      'How do I find a particular product?',
      'Open Browse Products, choose the animal, main cut and sub-cut, then use relevant size, category, brand, marbling or other filters. Search by product name or supplier SKU. Clear a restrictive filter if no offers match.',
    ),
    (
      'butcher',
      'Why does the invoice differ from my order estimate?',
      'Catch-weight products are charged using the actual weight picked by the supplier. Check the actual kg, locked rate, discounts and delivery charge on the invoice. Raise an issue against the order if something looks wrong.',
    ),
    (
      'butcher',
      'Why can I see an invoice stage but not open the invoice?',
      'The supplier must make the final invoice available to you. A supplier Work Order is their picking document and is not your invoice. Contact the supplier if you are waiting for the final document.',
    ),
    (
      'butcher',
      'What is the difference between saved searches and favourite products?',
      'A saved search restores your chosen browsing filters. A favourite product keeps a specific supplier offer. Manage favourites to choose up to four products for your dashboard. Availability and current prices can change.',
    ),
    (
      'butcher',
      'How do payments and credits affect my balance?',
      'Submitting a payment tells the supplier about it; they still confirm receipt and allocate it. An allocated credit reduces the relevant invoice balance. Unallocated money or account credit can remain available for future invoices.',
    ),
    (
      'butcher',
      'How do I report missing or incorrect goods?',
      'Open the affected order and raise a marketplace issue with the details and relevant attachments. Use its conversation to agree a resolution with the supplier. Any credit or refund must be recorded against the invoice, not just mentioned in chat.',
    ),
    (
      'all',
      'How do I contact CutLink?',
      'Use Support tickets → New Ticket. Describe the problem and include the order or invoice number. Attach files, then press Send when ready. You can request reopening of a resolved ticket; CutLink reviews the request.',
    ),
    (
      'all',
      'Why is my business account on hold?',
      'The restricted-access page shows the reason and allows contact with CutLink Support. For an overdue subscription, use the payment details on the invoice and contact support with the payment reference. Access is restored after payment is verified and the hold is reviewed.',
    ),
    (
      'all',
      'Can I print or download a document?',
      'Open the document preview and use Download or Print. Zoom in to inspect the document and use Reset to restore the starting view. Downloaded invoices and credit notes are separate documents; retain both for your records.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final rows = _entries
        .where(
          (e) =>
              (e.$1 == (widget.adminMode ? _role : widget.businessType) ||
                  e.$1 == 'all') &&
              '${e.$2} ${e.$3}'.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const CutLinkSectionHeading(
          title: 'Help & frequently asked questions',
          subtitle:
              'Practical guides for the parts of CutLink that need a little explanation.',
          icon: Icons.help_outline,
        ),
        if (widget.adminMode)
          Wrap(
            spacing: 8,
            children: [
              for (final role in ['butcher', 'supplier'])
                ChoiceChip(
                  label: Text(
                    role == 'butcher' ? 'For butchers' : 'For suppliers',
                  ),
                  selected: _role == role,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
        const SizedBox(height: 14),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search help',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No matching guide. Open a support ticket and we can help.',
            ),
          ),
        for (final e in rows)
          Card(
            child: ExpansionTile(
              key: ValueKey(e.$2),
              title: Text(
                e.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text(e.$3, style: const TextStyle(height: 1.5))],
            ),
          ),
      ],
    );
  }
}
