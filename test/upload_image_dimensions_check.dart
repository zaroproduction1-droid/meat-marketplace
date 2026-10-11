import 'dart:io';
import 'dart:typed_data';

import 'package:cutlink/shared/security/upload_image_dimensions.dart';

import 'fixtures/upload_image_fixtures.dart';

void main(List<String> args) {
  var checks = 0;
  void check(bool condition, String reason) {
    if (!condition) {
      throw StateError(reason);
    }
    checks++;
  }

  void accepts(Uint8List bytes, String name, {bool allowWebp = false}) {
    final size = UploadImageDimensions.validate(
      bytes,
      name,
      allowWebp: allowWebp,
    );
    check(size.width == 8 && size.height == 4, 'Incorrect dimensions: $name');
  }

  void rejects(Uint8List bytes, String name, {bool allowWebp = false}) {
    var rejected = false;
    try {
      UploadImageDimensions.validate(bytes, name, allowWebp: allowWebp);
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Unsafe image accepted: $name');
  }

  final png = UploadImageFixtures.png;
  final jpeg = UploadImageFixtures.jpeg;
  accepts(png, 'sample.png');
  accepts(png, 'sample.PNG');
  accepts(jpeg, 'sample.jpg');
  accepts(jpeg, 'sample.JPEG');
  accepts(UploadImageFixtures.lossyWebp, 'sample.webp', allowWebp: true);
  accepts(UploadImageFixtures.losslessWebp, 'sample.webp', allowWebp: true);
  accepts(UploadImageFixtures.alphaWebp, 'sample.webp', allowWebp: true);
  accepts(
    Uint8List.fromList([
      ...jpeg.sublist(0, 2),
      0xff,
      0xfe,
      0,
      4,
      65,
      66,
      ...jpeg.sublist(2),
    ]),
    'comment.jpg',
  );
  rejects(png, 'sample.jpg');
  rejects(jpeg, 'sample.png');
  rejects(UploadImageFixtures.lossyWebp, 'logo.webp');
  rejects(Uint8List(0), 'empty.png');
  rejects(Uint8List(5 * 1024 * 1024 + 1), 'large.png');
  rejects(Uint8List.fromList(png.sublist(0, 20)), 'short.png');
  rejects(Uint8List.fromList([255, 216, 255]), 'short.jpg');
  rejects(Uint8List.fromList([255, 216, 255, 224, 0, 1]), 'bad-segment.jpg');
  rejects(
    Uint8List.fromList([255, 216, 255, 224, 0, 10]),
    'truncated-segment.jpg',
  );
  rejects(Uint8List.fromList([255, 216, 255, 218]), 'missing-frame.jpg');
  rejects(Uint8List.fromList([255, 216, 255, 192, 0, 2]), 'short-frame.jpg');
  for (final size in [(0, 4), (8, 0), (8193, 4), (8, 8193), (6000, 5000)]) {
    final bytes = Uint8List.fromList(png);
    final data = ByteData.sublistView(bytes);
    data.setUint32(16, size.$1);
    data.setUint32(20, size.$2);
    rejects(bytes, 'unsafe-dimensions.png');
  }
  for (final size in [(8192, 1), (6000, 4000)]) {
    final bytes = Uint8List.fromList(png);
    final data = ByteData.sublistView(bytes);
    data.setUint32(16, size.$1);
    data.setUint32(20, size.$2);
    final result = UploadImageDimensions.validate(bytes, 'boundary.png');
    check(
      result.width == size.$1 && result.height == size.$2,
      'Valid limit rejected',
    );
  }
  final badPng = Uint8List.fromList(png)..[12] = 0;
  rejects(badPng, 'missing-ihdr.png');
  final badWebp = Uint8List.fromList(UploadImageFixtures.lossyWebp);
  ByteData.sublistView(badWebp).setUint32(4, 0, Endian.little);
  rejects(badWebp, 'bad-riff.webp', allowWebp: true);
  final badChunk = Uint8List.fromList(UploadImageFixtures.losslessWebp);
  ByteData.sublistView(badChunk).setUint32(16, 999999, Endian.little);
  rejects(badChunk, 'bad-chunk.webp', allowWebp: true);
  rejects(
    Uint8List.fromList(UploadImageFixtures.losslessWebp.sublist(0, 15)),
    'short.webp',
    allowWebp: true,
  );
  final badFrame = Uint8List.fromList(UploadImageFixtures.lossyWebp)..[23] = 0;
  rejects(badFrame, 'bad-vp8.webp', allowWebp: true);
  final unchanged = png.toList();
  UploadImageDimensions.validate(png, 'unchanged.png');
  check(
    Iterable<int>.generate(png.length).every((i) => png[i] == unchanged[i]),
    'Image bytes changed',
  );
  for (final path in args) {
    final file = File(path);
    final size = UploadImageDimensions.validate(
      file.readAsBytesSync(),
      file.uri.pathSegments.last,
      allowWebp: true,
    );
    stdout.writeln('Attached image accepted: ${size.width} x ${size.height}');
    checks++;
  }
  stdout.writeln('$checks image header/limit checks passed.');
}
