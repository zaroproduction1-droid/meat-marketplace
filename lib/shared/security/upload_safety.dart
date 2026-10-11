import 'dart:typed_data';
import 'dart:ui' as ui;

import 'upload_file_type.dart';

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
    final mime = validate(bytes, name, maxBytes: 5 * 1024 * 1024);
    if (![
      'image/png',
      'image/jpeg',
      if (allowWebp) 'image/webp',
    ].contains(mime)) {
      throw const FormatException('Choose a PNG or JPG image.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width > 8192 ||
          descriptor.height > 8192 ||
          descriptor.width * descriptor.height > 24000000) {
        throw const FormatException(
          'Choose an image under 24 megapixels and 8192 pixels per side.',
        );
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'The image could not be decoded. Choose a valid PNG, JPG or WebP.',
      );
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
