import 'package:cutlink/shared/animal_catalogues/beef_preview_images.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> product(String section) => {
  'active': true,
  'availability_status': 'in_stock',
  'meat_animals': {'code': 'BEEF'},
  'meat_sections': {'code': section},
};

void main() {
  test('Each of the 18 beef main cuts maps to a distinct preview', () {
    final paths = <String>{};
    for (final code in [
      'BLADE',
      'BRISKET',
      'CHEEK',
      'CHUCK',
      'FLANK',
      'LOIN',
      'MISC',
      'NECK',
      'TAIL',
      'PLATE',
      'RIBEYE',
      'RIB',
      'HIND',
      'RUMP',
      'SHANK',
      'SHOULDER',
      'SILVERSIDE',
      'SKIRT',
    ]) {
      final asset = BeefPreviewImages.assetFor(product(code));
      expect(asset, startsWith('assets/images/beef-preview-'));
      paths.add(asset!);
    }
    expect(paths.length, 18);
  });
  test('Existing supplier photo always wins and product data is untouched', () {
    final p = product('RIBEYE')..['photo_path'] = 'supplier/actual-photo.png';
    final before = p.toString();
    expect(BeefPreviewImages.assetFor(p), isNull);
    expect(p.toString(), before);
  });
  test(
    'Unavailable, unknown stock and other animals never get beef previews',
    () {
      for (final status in ['out_of_stock', 'made_to_order', 'unknown', null]) {
        expect(
          BeefPreviewImages.assetFor(
            product('RIBEYE')..['availability_status'] = status,
          ),
          isNull,
        );
      }
      expect(
        BeefPreviewImages.assetFor(product('RIBEYE')..['active'] = false),
        isNull,
      );
      expect(
        BeefPreviewImages.assetFor(
          product('RIBEYE')..['meat_animals'] = {'code': 'LAMB'},
        ),
        isNull,
      );
      expect(BeefPreviewImages.assetFor(product('UNKNOWN')), isNull);
      expect(
        BeefPreviewImages.assetFor(
          product('RIB')..['availability_status'] = 'limited',
        ),
        isNotNull,
      );
    },
  );
  test('Compact products can match an exact beef section ID', () {
    final p = product('RIBEYE')..remove('meat_animals');
    p['meat_sections'] = {
      'id': '4d14b371-60fe-4754-ab7d-c42051b22a0d',
      'name': 'Rib Eye',
    };
    expect(BeefPreviewImages.assetFor(p), endsWith('beef-preview-ribeye.jpg'));
    p['meat_sections'] = {'name': 'Rib Eye'};
    expect(BeefPreviewImages.assetFor(p), isNull);
  });
}
