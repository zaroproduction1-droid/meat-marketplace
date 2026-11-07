/// Related events stay together; individual IDs remain available for read/undo.
class ActivityGroup {
  ActivityGroup(this.key, this.events);
  final String key;
  final List<Map<String, dynamic>> events;
  Map<String, dynamic> get latest => events.first;
  bool get unread => events.any((e) => e['read_at'] == null);
  DateTime? get date =>
      DateTime.tryParse(latest['created_at']?.toString() ?? '')?.toLocal();
}

List<ActivityGroup> groupActivities(List<Map<String, dynamic>> rows) {
  final ordered = [...rows]
    ..sort(
      (a, b) => (b['created_at']?.toString() ?? '').compareTo(
        a['created_at']?.toString() ?? '',
      ),
    );
  final groups = <String, ActivityGroup>{};
  for (final row in ordered) {
    final ref = row['reference_id']?.toString() ?? '';
    final category = row['category']?.toString() ?? '';
    final type = row['reference_type']?.toString() ?? '';
    // Only order/delivery status events share a timeline. Messages, payments
    // and unrelated events keep their own distinct action and read state.
    final key =
        ref.isNotEmpty &&
            type == 'order' &&
            ['orders', 'delivery'].contains(category)
        ? 'order:$ref'
        : 'event:${row['id']}';
    groups.putIfAbsent(key, () => ActivityGroup(key, [])).events.add(row);
  }
  return groups.values.toList();
}
