/// Temporary reference art only. Supplier photo paths and stock records are
/// never edited. Disable with --dart-define=CUTLINK_BEEF_PREVIEW=false.
abstract final class BeefPreviewImages {
  static const enabled = bool.fromEnvironment(
    'CUTLINK_BEEF_PREVIEW',
    defaultValue: true,
  );
  static const _cuts = {
    'BLADE': 'blade',
    'BRISKET': 'brisket',
    'CHEEK': 'cheek',
    'CHUCK': 'chuck',
    'FLANK': 'flank',
    'LOIN': 'loin',
    'MISC': 'offal',
    'NECK': 'neck',
    'TAIL': 'oxtail',
    'PLATE': 'plate',
    'RIBEYE': 'ribeye',
    'RIB': 'ribs',
    'HIND': 'round',
    'RUMP': 'rump',
    'SHANK': 'shank',
    'SHOULDER': 'shoulder',
    'SILVERSIDE': 'silverside',
    'SKIRT': 'skirt',
  };
  static const _names = {
    'BLADE': 'BLADE',
    'BRISKET': 'BRISKET',
    'CHEEK': 'CHEEK',
    'CHUCK': 'CHUCK',
    'FLANK': 'FLANK',
    'LOIN': 'LOIN',
    'MISCELLANEOUS / OFFAL': 'MISC',
    'NECK': 'NECK',
    'OXTAIL': 'TAIL',
    'OX TAIL': 'TAIL',
    'PLATE': 'PLATE',
    'RIB EYE': 'RIBEYE',
    'RIBS': 'RIB',
    'ROUND': 'HIND',
    'RUMP': 'RUMP',
    'SHIN / SHANK': 'SHANK',
    'SHOULDER': 'SHOULDER',
    'SILVERSIDE / OUTSIDE': 'SILVERSIDE',
    'SKIRT': 'SKIRT',
  };
  static const _sectionIds = {
    '017af93c-52b6-468c-877f-46eb6cb13928': 'BLADE',
    '3beceef1-1979-4d81-9fae-8c10d189fd34': 'BRISKET',
    '17c0cedd-8ca3-464f-9495-6291b6a05b87': 'CHEEK',
    'd7b65884-b56a-4839-8210-9b51cf163734': 'CHUCK',
    '315c6667-3927-4b81-ada6-8c1c17e0f05e': 'FLANK',
    'bd7d4cb8-99d3-4515-a0b9-0a46ef2084af': 'LOIN',
    '0b552bbe-0a59-4ce2-bb9c-0cf769cdaba3': 'MISC',
    '8f59a82b-f8b0-43f5-8b20-c5c8281e96a4': 'NECK',
    'eed7dae9-638b-4f3c-b1a8-267fb19e1d66': 'TAIL',
    '67ec81a4-ad6b-4f00-9492-253c436ef4ac': 'PLATE',
    '4d14b371-60fe-4754-ab7d-c42051b22a0d': 'RIBEYE',
    'd693e870-6e7e-43a4-baf6-6179462d50e2': 'RIB',
    'cb583b45-f43f-4b34-bf17-82e3f6a1751e': 'HIND',
    'ff6ed856-5b39-4082-8331-2288b86abc72': 'RUMP',
    'b81de15c-2066-4b06-9db1-bd96ee17f45a': 'SHANK',
    '72fb608e-c483-4a45-ae09-9d22e6e82c29': 'SHOULDER',
    'e6269f02-904e-4a08-a307-1e04076ab995': 'SILVERSIDE',
    '1fb0998c-fc4b-4e90-b004-36bfb1018cb6': 'SKIRT',
  };

  static Map? _map(dynamic value) => value is Map ? value : null;
  static String? assetFor(Map<String, dynamic> product) {
    if (!enabled ||
        (product['photo_path']?.toString().trim().isNotEmpty ?? false) ||
        product['active'] != true ||
        !const {
          'in_stock',
          'limited',
        }.contains(product['availability_status'])) {
      return null;
    }
    final animal = _map(product['meat_animals']);
    final section = _map(product['meat_sections']);
    final sectionCode = _sectionIds[section?['id'] ?? product['section_id']];
    final animalCode = animal?['code']?.toString().toUpperCase();
    if (animalCode != null && animalCode != 'BEEF') {
      return null;
    }
    // An exact section ID is unambiguous even when the compact row omits animal.
    if (animalCode != 'BEEF' && sectionCode == null) {
      return null;
    }
    final code =
        sectionCode ??
        section?['code']?.toString().toUpperCase() ??
        _names[section?['name']?.toString().trim().toUpperCase()];
    final name = _cuts[code];
    return name == null ? null : 'assets/images/beef-preview-$name.jpg';
  }
}
