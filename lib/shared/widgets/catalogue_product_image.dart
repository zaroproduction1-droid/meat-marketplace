import '../theme/cutlink_appearance.dart';
import '../animal_catalogues/beef_preview_images.dart';

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
    this.allowGenericPreview = false,
  });

  final Map<String, dynamic> product;
  final bool thumbnail;
  final bool allowGenericPreview;
  final double? imageHeight;
  final double? imageWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    final path = product['photo_path']?.toString();
    final url = path == null || path.isEmpty
        ? null
        : Supabase.instance.client.storage
              .from('product-photos')
              .getPublicUrl(path);
    final preview = allowGenericPreview
        ? BeefPreviewImages.assetFor(product)
        : null;
    final cut =
        (product['meat_specifications'] as Map?)?['name']?.toString() ?? 'Cut';
    final height = imageHeight ?? (thumbnail ? 64.0 : 210.0);
    // imageHeight describes the complete tile, including its border. Child
    // content must take the remaining space when a compact parent constrains it.
    final contentHeight = (height - 2).clamp(0.0, double.infinity).toDouble();
    Widget placeholder() => SizedBox(
      height: contentHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: thumbnail ? 24 : 46,
              color: CutLinkPalette.color(0xFF8A8F94),
            ),
            if (!thumbnail) ...[
              const SizedBox(height: 8),
              Text(
                'Photo not yet available',
                style: TextStyle(color: CutLinkPalette.color(0xFF5F6469)),
              ),
            ],
          ],
        ),
      ),
    );
    return Tooltip(
      message: url != null
          ? '$cut • Supplier photo'
          : preview != null
          ? 'Generic AI-generated beef cut preview, not a supplier photo'
          : 'Photo not yet available',
      child: Container(
        width: imageWidth ?? (thumbnail ? 64 : null),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CutLinkPalette.surface,
          borderRadius: BorderRadius.circular(thumbnail ? 8 : 14),
          border: Border.all(color: CutLinkPalette.color(0xFFD9DCDE)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url != null)
              Image.network(
                url,
                height: contentHeight,
                width: double.infinity,
                fit: fit,
                filterQuality: FilterQuality.high,
                semanticLabel: '$cut supplier photo',
                errorBuilder: (_, _, _) => placeholder(),
              )
            else if (preview != null)
              Semantics(
                label: 'Generic beef cut preview, not a supplier photo',
                image: true,
                child: SizedBox(
                  height: contentHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        preview,
                        fit: fit,
                        filterQuality: FilterQuality.high,
                        cacheWidth: thumbnail ? 384 : 768,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => placeholder(),
                      ),
                      Positioned(
                        left: 3,
                        right: 3,
                        bottom: 3,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xDD202024),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Generic preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: thumbnail ? 8 : 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              placeholder(),
          ],
        ),
      ),
    );
  }
}
