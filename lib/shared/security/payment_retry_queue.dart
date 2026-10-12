import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Keeps only hashes and random request keys on this device. Payment details
/// remain in the RPC request, never in the persisted retry queue.
class PaymentRetryQueue {
  PaymentRetryQueue({
    required this.load,
    required this.save,
    required this.send,
    required this.newKey,
    this.timeout = const Duration(seconds: 25),
  });

  final Future<String?> Function(String name) load;
  final Future<void> Function(String name, String value) save;
  final Future<dynamic> Function(String operation, Map<String, dynamic> params)
  send;
  final String Function() newKey;
  final Duration timeout;
  final _inFlight = <String, Future<dynamic>>{};
  Future<void> _tail = Future<void>.value();

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static dynamic _canonical(dynamic value) {
    if (value is Map<String, dynamic>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) {
      return value.map(_canonical).toList();
    }
    return value;
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, String>> _read(String name) async {
    final value = await load(name);
    if (value == null) {
      return {};
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != 1 ||
          decoded['pending'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final pending = decoded['pending'] as Map<String, dynamic>;
      if (pending.length > 100 ||
          pending.entries.any(
            (entry) =>
                !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key) ||
                entry.value is! String ||
                !RegExp(
                  r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
                ).hasMatch(entry.value as String),
          )) {
        throw const FormatException();
      }
      return pending.cast<String, String>();
    } on FormatException {
      throw StateError(
        'Payment retry information needs review. Check account history before recording this payment again.',
      );
    }
  }

  Future<void> _write(String name, Map<String, String> pending) =>
      save(name, jsonEncode({'version': 1, 'pending': pending}));

  Future<dynamic> call(
    String userId,
    String operation,
    Map<String, dynamic> params,
  ) {
    if (userId.isEmpty) {
      return Future<dynamic>.error(StateError('Sign in to record payment.'));
    }
    if (operation != 'record_account_payment' &&
        operation != 'submit_butcher_account_payment') {
      return Future<dynamic>.error(
        StateError('Unsupported payment operation.'),
      );
    }
    // Copy before the first await so a caller cannot mutate the reserved payload.
    final payload = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(_canonical(params))) as Map,
    );
    payload.remove('p_request_key');
    final storageName = 'cutlink.payment-retries.v1.${_hash(userId)}';
    final identity = _hash('$operation:${jsonEncode(payload)}');
    final flight = '$storageName:$identity';
    final existing = _inFlight[flight];
    if (existing != null) {
      return existing;
    }
    final result = _perform(storageName, identity, operation, payload);
    _inFlight[flight] = result;
    unawaited(
      result.then<void>(
        (_) {
          _inFlight.remove(flight);
        },
        onError: (Object _, StackTrace _) {
          _inFlight.remove(flight);
        },
      ),
    );
    return result;
  }

  Future<dynamic> _perform(
    String name,
    String identity,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final key = await _serial(() async {
      final pending = await _read(name);
      final existing = pending[identity];
      if (existing != null) {
        return existing;
      }
      if (pending.length >= 100) {
        throw StateError(
          'Several payments need review. Check account history before recording more.',
        );
      }
      final key = newKey();
      pending[identity] = key;
      await _write(name, pending);
      return key;
    });
    // An uncertain result deliberately retains its key. Do not expire these
    // automatically: the server may already have committed the payment.
    final response = await send(operation, {
      ...payload,
      'p_request_key': key,
    }).timeout(timeout);
    await _serial(() async {
      final pending = await _read(name);
      if (pending[identity] == key) {
        pending.remove(identity);
        await _write(name, pending);
      }
    });
    return response;
  }
}
