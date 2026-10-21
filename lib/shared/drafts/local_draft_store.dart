import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local convenience backups, never a source of committed business data.
class LocalDraftStore {
  static String choice(
    Map<String, dynamic> data,
    String key,
    String current,
    List<String> allowed,
  ) {
    final value = data[key];
    return value is String && allowed.contains(value) ? value : current;
  }

  static const _prefix = 'cutlink_draft_v1_';
  static final Map<String, Future<void>> _queues = {};
  static final Map<String, int> _generations = {};
  static String scope(
    String user,
    String business,
    String kind,
    String record,
  ) =>
      '$_prefix${base64Url.encode(utf8.encode(jsonEncode([user, business, kind, record])))}';

  static Future<Map<String, dynamic>?> read(String key) async {
    await _queues[key];
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    try {
      final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final saved = DateTime.parse(value['saved_at'] as String);
      if (value['version'] != 1 ||
          DateTime.now().difference(saved) > const Duration(days: 7) ||
          saved.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        await clear(key);
        return null;
      }
      return Map<String, dynamic>.from(value['data'] as Map);
    } catch (_) {
      await clear(key);
      return null;
    }
  }

  static Future<void> _enqueue(String key, Future<void> Function() action) {
    final previous = _queues[key] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => action());
    _queues[key] = next.catchError((Object _) {});
    return next;
  }

  static Future<void> write(String key, Map<String, dynamic> data) {
    final generation = _generations[key] ?? 0;
    final encoded = jsonEncode({
      'version': 1,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    });
    if (utf8.encode(encoded).length > 200000) {
      return Future<void>.error(StateError('Draft too large'));
    }
    return _enqueue(key, () async {
      if ((_generations[key] ?? 0) != generation) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, encoded)) {
        throw StateError('Draft storage unavailable');
      }
    });
  }

  static Future<void> clear(String key) {
    _generations[key] = (_generations[key] ?? 0) + 1;
    return _enqueue(key, () async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove(key)) {
        throw StateError('Draft could not be cleared');
      }
    });
  }
}
