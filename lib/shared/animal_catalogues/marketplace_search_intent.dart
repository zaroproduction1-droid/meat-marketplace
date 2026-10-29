/// Opening Search is navigation, not an instruction to scan the catalogue.
bool hasMarketplaceSearchIntent({
  required bool cutSelected,
  required String query,
  required String supplierQuery,
  required bool halalOnly,
}) =>
    cutSelected ||
    query.trim().length >= 2 ||
    supplierQuery.trim().length >= 2 ||
    halalOnly;
