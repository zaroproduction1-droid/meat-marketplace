import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_retry_queue.dart';

/// Retry-safe recording of trade payments. This does not move money.
abstract final class RetrySafePayments {
  static final _queue = PaymentRetryQueue(
    load: (name) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      return preferences.getString(name);
    },
    save: (name, value) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(name, value)) {
        throw StateError(
          'Cannot save the payment retry key. Check browser storage before trying again.',
        );
      }
    },
    send: (operation, params) async {
      return await Supabase.instance.client.rpc(operation, params: params);
    },
    newKey: _key,
  );
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
    return _queue.call(userId, operation, params);
  }
}
