import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogueProductImage extends StatelessWidget {
  const CatalogueProductImage({
    super.key,
    required this.product,
    this.thumbnail = false,
    this.imageHeight,
    this.imageWidth,
    this.fit = BoxFit.contain,
  });

  final Map<String, dynamic> product;
  final bool thumbnail;
  final double? imageHeight;
  final double? imageWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = product['photo_path']?.toString();
    final url = path == null || path.isEmpty
        ? null
        : Supabase.instance.client.storage
              .from('product-photos')
              .getPublicUrl(path);
    final cut =
        (product['meat_specifications'] as Map?)?['name']?.toString() ?? 'Cut';
    final height = imageHeight ?? (thumbnail ? 64.0 : 210.0);
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
      message: url != null
          ? '$cut • Supplier photo'
          : 'Photo not yet available',
      child: Container(
        width: imageWidth ?? (thumbnail ? 64 : null),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(thumbnail ? 8 : 14),
          border: Border.all(color: const Color(0xFFD9DCDE)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url != null)
              Image.network(
                url,
                height: height,
                width: double.infinity,
                fit: fit,
                filterQuality: FilterQuality.high,
                semanticLabel: '$cut supplier photo',
                errorBuilder: (_, _, _) => placeholder(),
              )
            else
              placeholder(),
          ],
        ),
      ),
    );
  }
}
