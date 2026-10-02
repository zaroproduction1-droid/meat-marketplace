class CustomerAccountRules {
  static String? emailError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Enter a valid email address.';
  }

  static String? numberError(
    String? value, {
    bool integer = false,
    bool optional = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty && optional) {
      return null;
    }
    final number = integer ? int.tryParse(text) : double.tryParse(text);
    return number != null && number.isFinite && number >= 0
        ? null
        : 'Enter a valid non-negative ${integer ? 'whole number' : 'amount'}.';
  }

  static String? postcodeError(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty || RegExp(r'^\d{4}$').hasMatch(text)
        ? null
        : 'Enter a four-digit postcode.';
  }

  static String? orderBlock(Map<String, dynamic> account, String? reference) {
    if (account['account_hold'] == true) {
      return 'This customer account is on hold. Contact the supplier account manager.';
    }
    if (account['active'] == false) {
      return 'This customer account is inactive.';
    }
    if (account['require_purchase_order'] == true &&
        (reference?.trim().isEmpty ?? true)) {
      return 'A customer purchase order number is required.';
    }
    return null;
  }

  static Map<String, double> ageing(
    Iterable<Map<String, dynamic>> invoices,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <String, double>{
      'Current': 0,
      '1–30 days': 0,
      '31–60 days': 0,
      '61–90 days': 0,
      '90+ days': 0,
    };
    for (final invoice in invoices) {
      if (!['issued', 'part_paid'].contains(invoice['status'])) {
        continue;
      }
      final amount =
          double.tryParse('${invoice['outstanding_amount'] ?? 0}') ?? 0;
      if (!amount.isFinite || amount <= 0) {
        continue;
      }
      final due = DateTime.tryParse('${invoice['due_date'] ?? ''}');
      final age = due == null
          ? 0
          : today.difference(DateTime(due.year, due.month, due.day)).inDays;
      final key = age <= 0
          ? 'Current'
          : age <= 30
          ? '1–30 days'
          : age <= 60
          ? '31–60 days'
          : age <= 90
          ? '61–90 days'
          : '90+ days';
      buckets[key] = buckets[key]! + amount;
    }
    return buckets;
  }
}
