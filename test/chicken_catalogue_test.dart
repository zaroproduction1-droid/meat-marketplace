import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:meat_marketplace/shared/chicken_catalogue_repository.dart';
import 'package:meat_marketplace/shared/widgets/chicken_cut_catalogue.dart';

void main() {
  final catalogue = ChickenCutCatalogue(
    sections: [
      for (final entry in ChickenCutCatalogue.regionNames.entries)
        {'id': entry.key, 'name': entry.value, 'hotspot_key': entry.key},
      {'id': 'skin', 'name': 'Skin'},
      {'id': 'bones', 'name': 'Bones'},
    ],
    specifications: [
      for (final entry in <String, List<String>>{
        'whole-chicken': ['Whole Chicken', 'Butterflied Chicken'],
        'neck': ['Necks'],
        'back-frame': ['Chicken Frames', 'Chicken Backs'],
        'wing': [
          'Whole Wings',
          'Wingettes',
          'Drumettes',
          'Wing Tips',
          'Skin On Wings',
        ],
        'breast': [
          'Breast Fillet',
          'Breast Strips',
          'Supplier Custom Breast Cut',
        ],
        'tenderloin': ['Tenderloins'],
        'tail': ['Chicken Tails'],
        'maryland': ['Chicken Maryland'],
        'thigh': ['Thigh Fillet', 'Bone In Thigh', 'Skin On Thigh'],
        'drumstick': ['Drumsticks', 'Skin On Drumsticks'],
        'chicken-chop-cutlet': ['Chicken Chop', 'Chicken Cutlet'],
        'mince-manufacturing': ['Chicken Mince', 'Manufacturing Meat'],
        'misc-offal-other': ['Hearts', 'Livers', 'Gizzards', 'Giblets', 'Feet'],
        'skin': ['Chicken Skin'],
        'bones': ['Chicken Bones'],
      }.entries)
        for (final name in entry.value)
          {'id': name, 'name': name, 'section_id': entry.key},
    ],
  );

  Set<String> names(String region) => catalogue
      .specificationsFor(region: region)
      .map((spec) => spec['name'] as String)
      .toSet();

  test('every saved sub-cut is reachable without any supplier listings', () {
    final reachable = {
      for (final region in ChickenCutCatalogue.regionNames.keys)
        ...names(region),
    };
    expect(reachable, catalogue.specifications.map((s) => s['name']).toSet());
    expect(names('wing'), containsAll(['Wingettes', 'Drumettes', 'Wing Tips']));
    expect(names('breast'), contains('Supplier Custom Breast Cut'));
  });

  test(
    'parent regions include child sections and all related byproduct sections',
    () {
      expect(names('breast'), containsAll(['Breast Fillet', 'Tenderloins']));
      expect(
        names('maryland'),
        containsAll(['Chicken Maryland', 'Thigh Fillet', 'Drumsticks']),
      );
      expect(names('back-frame'), {
        'Chicken Frames',
        'Chicken Backs',
        'Chicken Skin',
        'Chicken Bones',
      });
      expect(names('tenderloin'), isNot(contains('Breast Fillet')));
      expect(names('thigh'), isNot(contains('Drumsticks')));
    },
  );

  test(
    'diagram scope and exact section scope filter the same saved sub-cuts as products',
    () {
      for (final region in ChickenCutCatalogue.regionNames.keys) {
        for (final spec in catalogue.specifications) {
          // The specification parent is authoritative even for an old listing
          // whose redundant section ID has drifted.
          final product = {
            'meat_specification_id': spec['id'],
            'meat_section_id': 'old-section',
          };
          expect(
            catalogue.productMatches(product, region: region),
            names(region).contains(spec['name']),
          );
          expect(
            catalogue.productMatches(
              product,
              sectionId: spec['section_id'] as String,
            ),
            isTrue,
          );
        }
      }
      expect(
        catalogue.specificationsFor(sectionId: 'breast').map((s) => s['name']),
        isNot(contains('Tenderloins')),
      );
    },
  );

  test(
    'nested tenderloins and wing portions resolve from wider saved sections',
    () {
      const nested = ChickenCutCatalogue(
        sections: [
          {'id': 'breast', 'name': 'Breast'},
          {'id': 'other', 'name': 'Other'},
        ],
        specifications: [
          {'id': 'tender', 'name': 'Tenderloins', 'section_id': 'breast'},
          {'id': 'drumette', 'name': 'Drumettes', 'section_id': 'other'},
        ],
      );
      expect(
        nested.specificationsFor(region: 'tenderloin').single['id'],
        'tender',
      );
      expect(nested.specificationsFor(region: 'wing').single['id'], 'drumette');
    },
  );

  test(
    'loads the full active catalogue, paginating beyond one page without querying stock',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <Uri>[];
      server.listen((request) async {
        requests.add(request.uri);
        final table = request.uri.pathSegments.last;
        Object data;
        if (table == 'meat_animals') {
          data = [
            {'id': 'chicken'},
          ];
        } else if (table == 'meat_sections') {
          data = [
            {'id': 'breast', 'name': 'Breast'},
          ];
        } else {
          expect(table, 'meat_specifications');
          expect(request.uri.queryParameters['animal_id'], 'eq.chicken');
          expect(request.uri.queryParameters['is_active'], 'eq.true');
          final offset = int.parse(
            request.uri.queryParameters['offset'] ?? '0',
          );
          data = [
            for (var i = offset; i < 501 && i < offset + 500; i++)
              {'id': '$i', 'name': 'Custom sub-cut $i', 'section_id': 'breast'},
          ];
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(data));
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      addTearDown(client.dispose);
      final result = await ChickenCatalogueRepository(client).load();
      expect(result.specificationsFor(region: 'breast'), hasLength(501));
      expect(
        requests.where((uri) => uri.path.endsWith('meat_specifications')),
        hasLength(2),
      );
      expect(requests.any((uri) => uri.path.endsWith('products')), isFalse);
    },
  );
}
