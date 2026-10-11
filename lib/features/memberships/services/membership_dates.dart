/// Calendar-month boundaries remain anchored to the original activation day.
/// Never add months to an already-clamped February date.
abstract final class MembershipDates {
  static DateTime boundary(DateTime start, int months) {
    final last = DateTime(start.year, start.month + months + 1, 0).day;
    return DateTime(
      start.year,
      start.month + months,
      start.day > last ? last : start.day,
    );
  }

  static DateTime periodEnd(DateTime activation, DateTime periodStart) {
    final months =
        (periodStart.year - activation.year) * 12 +
        periodStart.month -
        activation.month;
    final next = boundary(activation, months + 1);
    return DateTime(next.year, next.month, next.day - 1);
  }
}
