import 'dart:convert';
import 'dart:typed_data';

/// Checks bounded bytes and signatures; does not certify files as malware-free.
abstract final class UploadFileType {
  static String validate(
    Uint8List bytes,
    String name, {
    required int maxBytes,
  }) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'The file is empty or exceeds the upload limit.',
      );
    }
    final extension = name.split('.').last.toLowerCase();
    bool starts(List<int> prefix) =>
        bytes.length >= prefix.length &&
        List.generate(
          prefix.length,
          (i) => bytes[i] == prefix[i],
        ).every((v) => v);
    final jpeg = starts([255, 216, 255]);
    final png = starts([137, 80, 78, 71, 13, 10, 26, 10]);
    final webp =
        starts([82, 73, 70, 70]) &&
        bytes.length >= 12 &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
    final pdf = starts([37, 80, 68, 70, 45]);
    final zip = starts([80, 75, 3, 4]);
    final office = starts([208, 207, 17, 224, 161, 177, 26, 225]);
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        if (jpeg) {
          return 'image/jpeg';
        }
        break;
      case 'png':
        if (png) {
          return 'image/png';
        }
        break;
      case 'webp':
        if (webp) {
          return 'image/webp';
        }
        break;
      case 'pdf':
        if (pdf) {
          return 'application/pdf';
        }
        break;
      case 'zip':
        if (zip) {
          return 'application/zip';
        }
        break;
      case 'docx':
        if (zip) {
          return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        }
        break;
      case 'xlsx':
        if (zip) {
          return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        }
        break;
      case 'doc':
        if (office) {
          return 'application/msword';
        }
        break;
      case 'xls':
        if (office) {
          return 'application/vnd.ms-excel';
        }
        break;
      case 'txt':
      case 'csv':
        final text = utf8.decode(bytes);
        if (text.contains('\u0000') ||
            RegExp(
              r'<\s*(?:!doctype|html|svg|script|iframe|object|embed)\b',
              caseSensitive: false,
            ).hasMatch(text)) {
          throw const FormatException(
            'Active HTML or SVG content is not accepted.',
          );
        }
        return extension == 'csv' ? 'text/csv' : 'text/plain';
    }
    throw const FormatException(
      'The file contents do not match an accepted file type.',
    );
  }
}
