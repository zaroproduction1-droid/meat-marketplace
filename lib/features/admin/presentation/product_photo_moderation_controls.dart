import 'package:flutter/material.dart';
import 'admin_product_review_page.dart';

class ProductPhotoModerationControls extends StatelessWidget {
  const ProductPhotoModerationControls({
    super.key,
    required this.productId,
    this.ticketId,
    this.onChanged,
  });
  final String productId;
  final String? ticketId;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.manage_search, size: 18),
    label: const Text('Review this product'),
    onPressed: () async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminProductReviewPage(
            productId: productId,
            ticketId: ticketId,
            accessReason: 'Review supplier product from admin inventory',
          ),
        ),
      );
      onChanged?.call();
    },
  );
}
