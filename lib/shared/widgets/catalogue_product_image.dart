import 'package:flutter/material.dart';

import '../animal_catalogues/catalogue_cut_images.dart';

class CatalogueProductImage extends StatelessWidget {
  const CatalogueProductImage({
    super.key,
    required this.product,
    this.thumbnail = false,
  });

  final Map<String, dynamic> product;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    final asset = catalogueImageAsset(product);
    final cut =
        (product['meat_specifications'] as Map?)?['name']?.toString() ?? 'Cut';
    final height = thumbnail ? 64.0 : 210.0;
    Widget placeholder() => SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: thumbnail ? 24 : 46,
              color: const Color(0xFF8A8F94),
            ),
            if (!thumbnail) ...[
              const SizedBox(height: 8),
              const Text(
                'Photo not yet available',
                style: TextStyle(color: Color(0xFF5F6469)),
              ),
            ],
          ],
        ),
      ),
    );
    return Tooltip(
      message: asset == null
          ? 'Photo not yet available'
          : '$cut • Illustrative image',
      child: Container(
        width: thumbnail ? 64 : null,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(thumbnail ? 8 : 14),
          border: Border.all(color: const Color(0xFFD9DCDE)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset == null)
              placeholder()
            else
              Image.asset(
                asset,
                height: height,
                width: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: thumbnail ? 160 : 800,
                semanticLabel: '$cut, illustrative image',
                errorBuilder: (_, _, _) => placeholder(),
              ),
            if (asset != null && !thumbnail)
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Text(
                  'Illustrative image • Actual product may vary',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF71777D)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
