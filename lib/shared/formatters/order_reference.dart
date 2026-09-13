String cutLinkOrderReference(dynamic raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return 'Order';

  final match = RegExp(r'(\d+)$').firstMatch(text);
  if (match == null) return text;

  final number = int.tryParse(match.group(1)!);
  if (number == null) return text;

  return '#$number';
}
