import '../theme/cutlink_appearance.dart';
import '../formatters/cutlink_numbers.dart';
import '../animal_catalogues/supplier_variant_options.dart';
import 'cutlink_review_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import 'catalogue_product_image.dart';

const moderationReasonLabels = <String, String>{
  'copyright': 'Photo rights or copyright',
  'wrong_photo': 'Photo does not match the product',
  'misleading': 'Misleading content',
  'inappropriate': 'Inappropriate content',
  'product_details': 'Incorrect or missing product details',
  'food_safety': 'Food safety or compliance concern',
  'duplicate': 'Duplicate listing',
  'corrected': 'Correction reviewed and accepted',
  'other': 'Other reason',
};
const moderationActionLabels = <String, String>{
  'remove_photo': 'Remove photo & block uploads',
  'remove_product': 'Take product off marketplace',
  'request_correction': 'Request a correction',
  'allow_photo': 'Allow a new photo',
  'allow_product': 'Restore product to marketplace',
};

class ProductReviewDetails extends StatelessWidget {
  const ProductReviewDetails({
    super.key,
    required this.product,
    this.prices = const [],
  });
  final Map<String, dynamic> product;
  final List<dynamic> prices;
  String _label(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    const excluded = {
      'retired_by_cutlink',
      'id',
      'supplier_business_id',
      'photo_path',
      'hide_catalogue_photo',
      'created_at',
      'updated_at',
      'meat_animal_id',
      'meat_section_id',
      'meat_specification_id',
      'meat_grade_id',
    };
    final details = product.entries
        .where(
          (e) =>
              !excluded.contains(e.key) &&
              e.value != null &&
              e.value.toString().isNotEmpty &&
              e.value is! Map &&
              e.value is! List,
        )
        .toList();
    return CutLinkReviewTheme(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                product['specification']?.toString() ??
                    product['product_name']?.toString() ??
                    'Product',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (product['supplier_name'] != null)
                Text(
                  product['supplier_name'].toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF741C1C),
                  ),
                ),
              const SizedBox(height: 12),
              if (SupplierVariantOptions.summary(product).isNotEmpty) ...[
                Text(
                  SupplierVariantOptions.summary(product),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                onTap: product['photo_path'] == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (c) => CutLinkReviewTheme(
                          child: Dialog(
                            child: SizedBox(
                              width: 950,
                              height: MediaQuery.sizeOf(c).height * .85,
                              child: Column(
                                children: [
                                  ListTile(
                                    title: const Text('Current product photo'),
                                    trailing: IconButton(
                                      onPressed: () => Navigator.pop(c),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                                  Expanded(
                                    child: InteractiveViewer(
                                      minScale: .5,
                                      maxScale: 6,
                                      child: Center(
                                        child: Image.network(
                                          Supabase.instance.client.storage
                                              .from('product-photos')
                                              .getPublicUrl(
                                                product['photo_path']
                                                    .toString(),
                                              ),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, error, stack) =>
                                              const Text(
                                                'Photo could not be loaded.',
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                child: CatalogueProductImage(
                  product: product,
                  imageHeight: 230,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Current product details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, box) => Wrap(
                  spacing: 18,
                  runSpacing: 12,
                  children: [
                    for (final e in details)
                      SizedBox(
                        width: box.maxWidth < 240 ? box.maxWidth : 240,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label(e.key),
                              style: TextStyle(
                                fontSize: 11,
                                color: CutLinkPalette.color(0xFF666666),
                              ),
                            ),
                            SelectableText(
                              e.value is num
                                  ? CutLinkNumbers.quantity(e.value)
                                  : e.value is bool
                                  ? (e.value == true ? 'Yes' : 'No')
                                  : e.value.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (prices.isNotEmpty) ...[
                const Divider(height: 30),
                const Text(
                  'Product pricing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final price in prices.whereType<Map>())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: SelectableText(
                      '${price['price_list']} (${price['visibility']}) · ${CutLinkNumbers.money(price['amount'])} / ${price['basis']} · minimum ${CutLinkNumbers.quantity(price['minimum_quantity'])} ${price['minimum_unit'] ?? ''} · ${price['active'] == true ? 'Active' : 'Inactive'}\nValid from ${price['valid_from'] ?? '—'} to ${price['valid_to'] ?? '—'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
