import 'dart:typed_data';
import 'dart:ui' as ui;

import 'upload_file_type.dart';
import 'upload_image_dimensions.dart';

/// Client-side defence in depth. Storage/RLS and malware scanning remain server controls.
abstract final class UploadSafety {
  static String validate(
    Uint8List bytes,
    String name, {
    required int maxBytes,
  }) => UploadFileType.validate(bytes, name, maxBytes: maxBytes);

  static Future<void> validateImage(
    Uint8List bytes,
    String name, {
    bool allowWebp = false,
  }) async {
    UploadImageDimensions.validate(bytes, name, allowWebp: allowWebp);
    ui.Codec? codec;
    ui.Image? image;
    try {
      // Encoded ImageDescriptor.width/height throw UnsupportedError on web.
      // Header dimensions are checked above before any pixel decode. A small
      // first-frame decode verifies the data using the same cross-platform API
      // as image rendering, without changing the original upload bytes.
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 64,
        targetHeight: 64,
        allowUpscaling: false,
      );
      image = (await codec.getNextFrame()).image;
      if (image.width <= 0 || image.height <= 0) {
        throw const FormatException('The image has invalid dimensions.');
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw FormatException(
        allowWebp
            ? 'The image could not be opened. Choose another PNG, JPG or WebP.'
            : 'The image could not be opened. Choose another PNG or JPG.',
      );
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
