/// Display formatting only. Never use grouped text in stored values or editors.
class CutLinkNumbers {
  const CutLinkNumbers._();
  static num? _parse(Object? value) {
    final result = value is num
        ? value
        : num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '');
    return result != null && result.isFinite ? result : null;
  }

  static String number(
    Object? value, {
    int decimals = 0,
    bool trimZeros = false,
    String fallback = '0',
  }) {
    final parsed = _parse(value);
    if (parsed == null) {
      return fallback;
    }
    final places = decimals.clamp(0, 20).toInt();
    var raw = parsed is int
        ? '${parsed.toString()}${places == 0 ? '' : '.${List.filled(places, '0').join()}'}'
        : parsed.toStringAsFixed(places);
    if (raw.startsWith('-') && num.tryParse(raw) == 0) {
      raw = raw.substring(1);
    }
    if (trimZeros && raw.contains('.')) {
      raw = raw
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    final parts = raw.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length == 1 ? whole : '$whole.${parts[1]}';
  }

  static String integer(Object? value) => number(value);
  static String quantity(
    Object? value, {
    int decimals = 3,
    String fallback = '0',
  }) => number(value, decimals: decimals, trimZeros: true, fallback: fallback);
  static String money(Object? value) {
    final text = number(value, decimals: 2, fallback: '0.00');
    return text.startsWith('-') ? '-\$${text.substring(1)}' : '\$$text';
  }
}
