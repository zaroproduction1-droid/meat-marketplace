import 'dart:typed_data';

import 'upload_file_type.dart';

/// Reads encoded dimensions before decoding pixels, including on Flutter web.
/// A header is not proof that the complete image can be decoded; the caller
/// must also perform a bounded platform decode before accepting the upload.
abstract final class UploadImageDimensions {
  static ({int width, int height}) validate(
    Uint8List bytes,
    String name, {
    bool allowWebp = false,
  }) {
    final mime = UploadFileType.validate(
      bytes,
      name,
      maxBytes: 5 * 1024 * 1024,
    );
    if (mime != 'image/png' &&
        mime != 'image/jpeg' &&
        !(allowWebp && mime == 'image/webp')) {
      throw FormatException(
        allowWebp
            ? 'Choose a PNG, JPG or WebP image.'
            : 'Choose a PNG or JPG image.',
      );
    }
    final size = switch (mime) {
      'image/png' => _png(bytes),
      'image/jpeg' => _jpeg(bytes),
      _ => _webp(bytes),
    };
    if (size.width <= 0 || size.height <= 0) {
      _invalid();
    }
    if (size.width > 8192 ||
        size.height > 8192 ||
        size.width * size.height > 24000000) {
      throw const FormatException(
        'Choose an image no larger than 24 megapixels and 8192 pixels per side.',
      );
    }
    return size;
  }

  static Never _invalid() => throw const FormatException(
    'The image header is incomplete or invalid. Choose another PNG, JPG or WebP image.',
  );

  static ({int width, int height}) _png(Uint8List bytes) {
    if (bytes.length < 33 ||
        ByteData.sublistView(bytes).getUint32(8) != 13 ||
        !_matches(bytes, 12, [73, 72, 68, 82])) {
      _invalid();
    }
    final data = ByteData.sublistView(bytes);
    return (width: data.getUint32(16), height: data.getUint32(20));
  }

  static ({int width, int height}) _jpeg(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 2; // Skip the already validated JPEG start-of-image signature.
    while (offset < bytes.length) {
      if (bytes[offset] != 0xff) {
        _invalid();
      }
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) {
        _invalid();
      }
      final marker = bytes[offset++];
      if (marker == 0 || marker == 0xd9 || marker == 0xda) {
        _invalid();
      }
      if (marker == 0x01 ||
          marker == 0xd8 ||
          (marker >= 0xd0 && marker <= 0xd7)) {
        continue;
      }
      if (offset + 2 > bytes.length) {
        _invalid();
      }
      final length = data.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) {
        _invalid();
      }
      if (marker >= 0xc0 &&
          marker <= 0xcf &&
          marker != 0xc4 &&
          marker != 0xc8 &&
          marker != 0xcc) {
        if (length < 8) {
          _invalid();
        }
        return (
          width: data.getUint16(offset + 5),
          height: data.getUint16(offset + 3),
        );
      }
      offset += length;
    }
    _invalid();
  }

  static ({int width, int height}) _webp(Uint8List bytes) {
    if (bytes.length < 20) {
      _invalid();
    }
    final data = ByteData.sublistView(bytes);
    final end = data.getUint32(4, Endian.little) + 8;
    if (end != bytes.length) {
      _invalid();
    }
    var offset = 12;
    while (offset + 8 <= end) {
      final length = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      final next = start + length + (length.isOdd ? 1 : 0);
      if (next > end) {
        _invalid();
      }
      if (_matches(bytes, offset, [86, 80, 56, 88])) {
        // VP8X
        if (length != 10) {
          _invalid();
        }
        int uint24(int at) =>
            bytes[at] + bytes[at + 1] * 256 + bytes[at + 2] * 65536;
        return (width: uint24(start + 4) + 1, height: uint24(start + 7) + 1);
      }
      if (_matches(bytes, offset, [86, 80, 56, 32])) {
        // VP8
        if (length < 10 ||
            bytes[start].isOdd ||
            !_matches(bytes, start + 3, [157, 1, 42])) {
          _invalid();
        }
        return (
          width: data.getUint16(start + 6, Endian.little) & 0x3fff,
          height: data.getUint16(start + 8, Endian.little) & 0x3fff,
        );
      }
      if (_matches(bytes, offset, [86, 80, 56, 76])) {
        // VP8L
        if (length < 5 || bytes[start] != 0x2f) {
          _invalid();
        }
        final packed = data.getUint32(start + 1, Endian.little);
        if ((packed >> 29) != 0) {
          _invalid();
        }
        return (
          width: (packed & 0x3fff) + 1,
          height: ((packed >> 14) & 0x3fff) + 1,
        );
      }
      offset = next;
    }
    _invalid();
  }

  static bool _matches(Uint8List bytes, int offset, List<int> expected) {
    if (offset + expected.length > bytes.length) {
      return false;
    }
    for (var i = 0; i < expected.length; i++) {
      if (bytes[offset + i] != expected[i]) {
        return false;
      }
    }
    return true;
  }
}
