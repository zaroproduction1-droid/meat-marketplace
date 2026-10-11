import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Retains a request key after uncertain transport failures within this process.
/// This does not move money. Pending keys do not survive an application restart.
abstract final class RetrySafePayments {
  static final _pending = <String, String>{};
  static String _key() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<dynamic> call(
    String operation,
    Map<String, dynamic> params,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to record payment.');
    }
    final identity = '$userId:$operation:${jsonEncode(params)}';
    // Bound memory without silently losing uncertain requests.
    if (!_pending.containsKey(identity) && _pending.length >= 100) {
      throw StateError(
        'Several payments need review. Check your account history before recording more.',
      );
    }
    final key = _pending.putIfAbsent(identity, _key);
    final response = await Supabase.instance.client.rpc(
      operation,
      params: {...params, 'p_request_key': key},
    );
    _pending.remove(identity);
    return response;
  }
}
