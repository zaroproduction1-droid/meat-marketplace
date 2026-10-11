import 'package:cutlink/features/memberships/services/membership_dates.dart';

void main() {
  void expect(DateTime actual, DateTime expected, String label) {
    if (actual != expected) {
      throw StateError('$label: $actual != $expected');
    }
  }

  expect(
    MembershipDates.boundary(DateTime(2024, 8, 31), 6),
    DateTime(2025, 2, 28),
    'Six free calendar months',
  );
  expect(
    MembershipDates.boundary(DateTime(2024, 8, 31), 18),
    DateTime(2026, 2, 28),
    'Eighteen calendar months',
  );
  expect(
    MembershipDates.boundary(DateTime(2024, 1, 31), 1),
    DateTime(2024, 2, 29),
    'Leap-year clamping',
  );
  expect(
    MembershipDates.boundary(DateTime(2024, 1, 31), 2),
    DateTime(2024, 3, 31),
    'Original day preserved after February',
  );
  expect(
    MembershipDates.periodEnd(DateTime(2024, 8, 31), DateTime(2025, 2, 28)),
    DateTime(2025, 3, 30),
    'Discount boundary invoice end',
  );
  expect(
    MembershipDates.periodEnd(DateTime(2024, 1, 31), DateTime(2024, 2, 29)),
    DateTime(2024, 3, 30),
    'Leap-year invoice end',
  );
  expect(
    MembershipDates.boundary(DateTime(2026, 10, 10), 6),
    DateTime(2027, 4, 10),
    'Ordinary activation',
  );
  expect(
    MembershipDates.periodEnd(DateTime(2026, 10, 10), DateTime(2027, 4, 10)),
    DateTime(2027, 5, 9),
    'Ordinary invoice period',
  );
  expect(
    MembershipDates.periodEnd(DateTime(2026, 9, 5), DateTime(2026, 9, 5)),
    DateTime(2026, 10, 4),
    'Sydney daylight-saving start',
  );
  expect(
    MembershipDates.periodEnd(DateTime(2026, 3, 6), DateTime(2026, 3, 6)),
    DateTime(2026, 4, 5),
    'Sydney daylight-saving end',
  );
}
