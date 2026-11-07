/// Keep this vocabulary in sync with cutlink_search_normalize in the migration.
/// Normalize punctuation and common compound spellings on both sides of search.
String normaliseCatalogueSearch(String value) {
  var text = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  for (final entry in const {
    r'\brib\s+eye\b': 'ribeye',
    r'\bstrip\s+loin\b': 'striploin',
    r'\btender\s+loin\b': 'tenderloin',
    r'\bscotchfillet\b': 'scotch fillet',
    r'\bgrainfed\b': 'grain fed',
    r'\bgrassfed\b': 'grass fed',
    r'\bbone\s+less\b': 'boneless',
  }.entries) {
    text = text.replaceAll(RegExp(entry.key), entry.value);
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Every keyword must match, in any order, across names, aliases, attributes
/// and supplier information. Short grade codes match complete words.
bool matchesCatalogueSearch(
  String query,
  Iterable<Object?> values, {
  String? halalStatus,
}) {
  var words = normaliseCatalogueSearch(query);
  if (words.isEmpty) return true;
  if (halalStatus != null) {
    final nonHalal = RegExp(r'\b(?:not|non) halal\b');
    if (nonHalal.hasMatch(words)) {
      if (halalStatus != 'not_halal') return false;
      words = words.replaceAll(nonHalal, '').trim();
    } else if (RegExp(r'\bhalal\b').hasMatch(words)) {
      if (halalStatus != 'halal') return false;
      words = words.replaceAll(RegExp(r'\bhalal\b'), '').trim();
    }
  }
  final text = normaliseCatalogueSearch(values.whereType<Object>().join(' '));
  final tokens = text.split(' ').toSet();
  return words
      .split(' ')
      .where((w) => w.isNotEmpty)
      .every(
        (w) => w.length <= 2
            ? tokens.contains(w)
            : tokens.any((t) => t.startsWith(w)),
      );
}
