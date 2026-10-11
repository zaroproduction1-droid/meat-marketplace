import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cutlink/shared/security/upload_file_type.dart';

void main() {
  var checks = 0;
  void reject(List<int> values, String name, {int maxBytes = 100}) {
    try {
      UploadFileType.validate(
        Uint8List.fromList(values),
        name,
        maxBytes: maxBytes,
      );
    } on FormatException {
      checks++;
      return;
    }
    throw StateError('Unsafe upload was accepted: $name');
  }

  void accept(List<int> values, String name, String mime) {
    final actual = UploadFileType.validate(
      Uint8List.fromList(values),
      name,
      maxBytes: 100,
    );
    if (actual != mime) {
      throw StateError('Wrong MIME type');
    }
    checks++;
  }

  reject([], 'empty.png');
  reject(utf8.encode('<script>alert(1)</script>'), 'picture.jpg');
  reject([137, 80, 78, 71, 13, 10, 26, 10], 'photo.jpg');
  reject(utf8.encode('<svg onload="evil()"/>'), 'notes.txt');
  reject(utf8.encode('<html>active</html>'), 'report.csv');
  reject([0, 1, 2], 'binary.txt');
  reject([1, 2, 3, 4], 'notes.txt', maxBytes: 3);
  reject([80, 75, 3, 4], 'program.exe');
  reject([80, 75, 3, 4], 'document.pdf');
  accept([137, 80, 78, 71, 13, 10, 26, 10], 'PHOTO.PNG', 'image/png');
  accept([255, 216, 255], 'photo.jpeg', 'image/jpeg');
  accept(utf8.encode('%PDF-1.7'), 'report.pdf', 'application/pdf');
  accept(utf8.encode('ordinary support text'), 'notes.txt', 'text/plain');
  accept(utf8.encode('column,value\nquantity,10'), 'report.csv', 'text/csv');
  stdout.writeln('$checks upload validation checks passed.');
}
