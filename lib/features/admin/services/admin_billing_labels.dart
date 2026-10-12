/// Keep old bookmarks working while presenting one billing workspace.
String? adminBillingSection(String tab) => switch (tab) {
  'billing' || 'accounts' => 'accounts',
  'invoices' => 'invoices',
  'memberships' || 'pricing' => 'pricing',
  'settings' => 'settings',
  _ => null,
};

String adminOfferLabel(Map<String, dynamic> membership) {
  if (membership.isEmpty || membership['legacy'] == true) {
    return 'Custom billing';
  }
  if (membership['revoked_at'] != null) {
    return 'Standard membership';
  }
  return switch (membership['tier']) {
    'founding_tier_1' => 'Founding · free + half-price year',
    'founding_tier_2' => 'Founding · 6 months free',
    _ => 'Standard membership',
  };
}

/// Translate stored membership stage codes for the customer-facing invoice PDF.
String adminInvoiceDescription(dynamic description) =>
    (description?.toString() ?? 'CutLink membership')
        .replaceAll(
          '(free_founding, GST inclusive)',
          '(Founding free month, GST included)',
        )
        .replaceAll(
          '(founding_half_price, GST inclusive)',
          '(Founding half-price year, GST included)',
        )
        .replaceAll(
          '(standard, GST inclusive)',
          '(Standard membership, GST included)',
        );
