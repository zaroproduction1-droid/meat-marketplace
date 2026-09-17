/// Matches words across catalogue names, aliases and product attributes.
/// Callers retain the selected animal/cut and customer visibility rules.
bool matchesCatalogueSearch(
  String query,
  Iterable<Object?> values, {
  String? halalStatus,
}) {
  String normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  var words = normalise(query);
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
  final text = normalise(values.whereType<Object>().join(' '));
  return words
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .every(text.contains);
}
