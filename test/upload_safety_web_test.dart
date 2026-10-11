import 'dart:typed_data';

import 'package:cutlink/shared/security/upload_safety.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/upload_image_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Run with flutter test --platform chrome to exercise the actual web codec.
  test(
    'PNG upload validates without encoded ImageDescriptor dimensions',
    () async {
      await UploadSafety.validateImage(UploadImageFixtures.png, 'test.png');
    },
  );
  test('JPEG logo upload validates on web', () async {
    await UploadSafety.validateImage(UploadImageFixtures.jpeg, 'test.jpg');
  });
  test('JPEG uppercase extension validates', () async {
    await UploadSafety.validateImage(UploadImageFixtures.jpeg, 'test.JPEG');
  });
  for (final (label, bytes) in [
    ('lossy', UploadImageFixtures.lossyWebp),
    ('lossless', UploadImageFixtures.losslessWebp),
    ('alpha', UploadImageFixtures.alphaWebp),
  ]) {
    test('Product photo $label WebP validates', () async {
      await UploadSafety.validateImage(bytes, 'test.webp', allowWebp: true);
    });
  }
  test('Logo WebP remains disallowed', () async {
    await expectLater(
      UploadSafety.validateImage(UploadImageFixtures.lossyWebp, 'logo.webp'),
      throwsFormatException,
    );
  });
  test('Wrong filename type remains rejected', () async {
    await expectLater(
      UploadSafety.validateImage(UploadImageFixtures.png, 'test.jpg'),
      throwsFormatException,
    );
  });
  test('Oversized header rejected before decoding pixels', () async {
    final bytes = UploadImageFixtures.png;
    ByteData.sublistView(bytes).setUint32(16, 9000);
    await expectLater(
      UploadSafety.validateImage(bytes, 'large.png'),
      throwsFormatException,
    );
  });
  test('Valid header but corrupt pixel data remains rejected', () async {
    // Keep the PNG header intact but remove the image-data and end chunks.
    final truncated = Uint8List.fromList(
      UploadImageFixtures.png.sublist(0, 33),
    );
    await expectLater(
      UploadSafety.validateImage(truncated, 'truncated.png'),
      throwsFormatException,
    );
  });
}
