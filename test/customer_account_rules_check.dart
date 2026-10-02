// This standalone Dart check also runs without Flutter or a package configuration.
// Keep its relative import so it does not depend on the app's pubspec name.
// ignore: avoid_relative_lib_imports
import '../lib/features/customers/services/customer_account_rules.dart';

void check(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

void main() {
  check(CustomerAccountRules.emailError('') == null, 'Optional email');
  check(
    CustomerAccountRules.emailError('accounts@example.com') == null,
    'Valid email',
  );
  check(
    CustomerAccountRules.emailError('accounts@') != null,
    'Reject invalid email',
  );
  for (final value in ['abc', '-1', 'NaN', 'Infinity']) {
    check(
      CustomerAccountRules.numberError(value) != null,
      'Reject invalid credit: $value',
    );
  }
  check(CustomerAccountRules.numberError('0') == null, 'Zero is valid');
  check(
    CustomerAccountRules.numberError('1.5', integer: true) != null,
    'Terms need whole days',
  );
  check(
    CustomerAccountRules.orderBlock({'account_hold': true}, 'PO1') != null,
    'Hold blocks even with PO',
  );
  check(
    CustomerAccountRules.orderBlock({'require_purchase_order': true}, '  ') !=
        null,
    'Blank PO rejected',
  );
  check(
    CustomerAccountRules.orderBlock({'require_purchase_order': true}, 'PO1') ==
        null,
    'Valid PO',
  );
  final today = DateTime(2026, 10, 2);
  final invoices = <Map<String, dynamic>>[
    for (final days in [0, 1, 30, 31, 60, 61, 90, 91])
      {
        'status': 'issued',
        'outstanding_amount': 10,
        'due_date': today
            .subtract(Duration(days: days))
            .toIso8601String()
            .split('T')
            .first,
      },
    {'status': 'void', 'outstanding_amount': 900, 'due_date': '2020-01-01'},
    {'status': 'draft', 'outstanding_amount': 900, 'due_date': '2020-01-01'},
    {'status': 'part_paid', 'outstanding_amount': 0, 'due_date': '2020-01-01'},
  ];
  final buckets = CustomerAccountRules.ageing(invoices, today);
  check(
    buckets['Current'] == 10 &&
        buckets['1–30 days'] == 20 &&
        buckets['31–60 days'] == 20 &&
        buckets['61–90 days'] == 20 &&
        buckets['90+ days'] == 10,
    'Age boundaries or excluded documents',
  );
}
