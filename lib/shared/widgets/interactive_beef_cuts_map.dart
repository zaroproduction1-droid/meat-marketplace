import 'interactive_cuts_map.dart';

/// Beef artwork and dimensions, preserved for existing callers.
class InteractiveBeefCutsMap extends InteractiveCutsMap {
  const InteractiveBeefCutsMap({
    super.key,
    required super.onCutSelected,
    super.selectedCut,
    super.assetPath,
    super.maxWidth,
    super.borderRadius,
  });
}

/// Canonical SVG data-cut values used by CutLink.
///
/// Pages can use these constants when mapping the SVG selection into
/// `meat_sections`.
abstract final class CutLinkBeefCutKeys {
  static const cheek = 'cheek';
  static const neck = 'neck';
  static const shoulder = 'shoulder';
  static const chuck = 'chuck';
  static const blade = 'blade';
  static const brisket = 'brisket';
  static const shinShank = 'shin-shank';
  static const ribs = 'ribs';
  static const ribEye = 'rib-eye';
  static const plate = 'plate';
  static const skirt = 'skirt';
  static const loin = 'loin';
  static const flank = 'flank';
  static const rump = 'rump';
  static const round = 'round';
  static const silversideOutside = 'silverside-outside';
  static const oxTail = 'ox-tail';
  static const miscOffalOther = 'misc-offal-other';

  static const all = <String>[
    cheek,
    neck,
    shoulder,
    chuck,
    blade,
    brisket,
    shinShank,
    ribs,
    ribEye,
    plate,
    skirt,
    loin,
    flank,
    rump,
    round,
    silversideOutside,
    oxTail,
    miscOffalOther,
  ];
}
