import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'catalogue_product_image.dart';

/// Photo choices remain a draft until the product itself is saved.
class ProductPhotoDraft extends ChangeNotifier {
  Map<String, dynamic> product = {};
  Uint8List? bytes;
  String? extension;
  String? preparedPath;
  bool dirty = false;
  bool hidden = false;
  bool _disposed = false;
  void load(Map<String, dynamic> value) {
    product = {...value};
    hidden = value['hide_catalogue_photo'] == true;
    bytes = null;
    dirty = false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (_disposed || result.isEmpty) {
      return;
    }
    final file = result.single;
    final data = await file.readAsBytes();
    if (data.isEmpty || data.length > 5 * 1024 * 1024) {
      throw Exception('Choose a PNG, JPG or WebP picture up to 5 MB.');
    }
    final codec = await ui.instantiateImageCodec(data, targetWidth: 1200);
    codec.dispose();
    if (_disposed) {
      return;
    }
    final ext = file.name.split('.').last.toLowerCase();
    extension = ext == 'jpeg' ? 'jpg' : ext;
    if (!['jpg', 'png', 'webp'].contains(extension)) {
      throw Exception('Choose PNG, JPG or WebP.');
    }
    bytes = data;
    hidden = false;
    dirty = true;
    notifyListeners();
  }

  void remove() {
    bytes = null;
    hidden = true;
    dirty = true;
    notifyListeners();
  }

  void useCatalogue() {
    bytes = null;
    hidden = false;
    dirty = true;
    notifyListeners();
  }

  Map<String, dynamic> get preview => {
    ...product,
    if (dirty) 'photo_path': null,
    'hide_catalogue_photo': hidden,
  };
  Future<void> prepare(String businessId, String productId) async {
    if (!dirty || bytes == null) {
      return;
    }
    final path =
        '$businessId/$productId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await Supabase.instance.client.storage
        .from('product-photos')
        .uploadBinary(
          path,
          bytes!,
          fileOptions: FileOptions(
            contentType: extension == 'jpg' ? 'image/jpeg' : 'image/$extension',
            upsert: false,
          ),
        );
    preparedPath = path;
  }

  Map<String, dynamic> get fields =>
      dirty ? {'photo_path': preparedPath, 'hide_catalogue_photo': hidden} : {};
  Future<void> committed() async {
    if (!dirty) {
      return;
    }
    final old = product['photo_path']?.toString();
    product = {...product, ...fields};
    final current = preparedPath;
    preparedPath = null;
    bytes = null;
    dirty = false;
    if (old != null && old.isNotEmpty && old != current) {
      try {
        await Supabase.instance.client.storage.from('product-photos').remove([
          old,
        ]);
      } catch (_) {
        /* Keep the saved product even if old-file cleanup fails. */
      }
    }
  }

  Future<void> discardUpload() async {
    final path = preparedPath;
    preparedPath = null;
    if (path != null) {
      try {
        await Supabase.instance.client.storage.from('product-photos').remove([
          path,
        ]);
      } catch (_) {}
    }
  }
}

class ProductPhotoEditor extends StatelessWidget {
  const ProductPhotoEditor({
    super.key,
    required this.draft,
    required this.enabled,
  });
  final ProductPhotoDraft draft;
  final bool enabled;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: draft,
    builder: (context, _) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        border: Border.all(color: const Color(0xFFE3E5E8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final image = SizedBox(
            width: 180,
            child: draft.bytes == null
                ? CatalogueProductImage(
                    product: draft.preview,
                    imageHeight: 110,
                  )
                : Image.memory(draft.bytes!, height: 110, fit: BoxFit.contain),
          );
          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                draft.dirty
                    ? 'Photo changes will be saved with this product.'
                    : 'Keep the catalogue picture or upload your own. PNG, JPG or WebP, up to 5 MB.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF666A70)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: !enabled
                        ? null
                        : () async {
                            try {
                              await draft.pick();
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to select picture: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Upload picture'),
                  ),
                  TextButton.icon(
                    onPressed: enabled ? draft.remove : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                  ),
                  TextButton(
                    onPressed: enabled ? draft.useCatalogue : null,
                    child: const Text('Use catalogue picture'),
                  ),
                ],
              ),
            ],
          );
          if (box.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [image, const SizedBox(height: 10), controls],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              image,
              const SizedBox(width: 18),
              Expanded(child: controls),
            ],
          );
        },
      ),
    ),
  );
}
