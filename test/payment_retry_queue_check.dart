import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cutlink/shared/security/payment_retry_queue.dart';

Future<void> main() async {
  var checks = 0;
  var counter = 0;
  final storage = <String, String>{};
  final sent = <Map<String, dynamic>>[];
  var failSend = true;
  var failSave = false;
  Completer<void>? barrier;
  String key() =>
      '00000000-0000-4000-8000-${(++counter).toRadixString(16).padLeft(12, '0')}';
  PaymentRetryQueue queue({Duration? timeout}) => PaymentRetryQueue(
    load: (name) async => storage[name],
    save: (name, value) async {
      if (failSave) {
        throw StateError('Synthetic storage failure');
      }
      storage[name] = value;
    },
    send: (operation, params) async {
      sent.add(params);
      await barrier?.future;
      if (failSend) {
        throw const SocketException('Synthetic uncertain response');
      }
      return 'recorded';
    },
    newKey: key,
    timeout: timeout ?? const Duration(seconds: 1),
  );
  void check(bool condition, String reason) {
    if (!condition) {
      throw StateError(reason);
    }
    checks++;
  }

  Future<void> rejects(Future<dynamic> action) async {
    var rejected = false;
    try {
      await action;
    } catch (_) {
      rejected = true;
    }
    check(rejected, 'Expected a rejected operation');
  }

  const operation = 'record_account_payment';
  final params = <String, dynamic>{
    'amount': 12.5,
    'note': 'private customer payment note',
    'account': 'private-account-id',
    'nested': {'b': 2, 'a': 1},
  };
  await rejects(queue().call('user-one', operation, params));
  final first = sent.last['p_request_key'];
  check(
    !storage.toString().contains('private') &&
        !storage.toString().contains('12.5') &&
        !storage.toString().contains('user-one'),
    'Payment details or user identifiers persisted',
  );
  await rejects(
    queue().call('user-one', operation, {
      'nested': {'a': 1, 'b': 2},
      'account': params['account'],
      'note': params['note'],
      'amount': params['amount'],
    }),
  );
  check(
    sent.last['p_request_key'] == first,
    'Reload or canonical retry changed key',
  );
  await rejects(queue().call('user-two', operation, params));
  check(sent.last['p_request_key'] != first, 'Users shared request keys');
  failSend = false;
  check(
    await queue().call('user-one', operation, params) == 'recorded',
    'Retry failed',
  );
  check(
    sent.last['p_request_key'] == first,
    'Successful retry lost original key',
  );
  await queue().call('user-one', operation, params);
  check(
    sent.last['p_request_key'] != first,
    'New confirmed payment reused old key',
  );
  barrier = Completer<void>();
  final concurrent = queue();
  final count = sent.length;
  final one = concurrent.call('user-one', operation, params);
  final two = concurrent.call('user-one', operation, params);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  check(sent.length == count + 1, 'Concurrent identical calls sent twice');
  barrier.complete();
  await Future.wait([one, two]);
  barrier = null;
  failSave = true;
  final beforeFailure = sent.length;
  await rejects(queue().call('user-one', operation, {'amount': 99}));
  check(sent.length == beforeFailure, 'RPC sent without durable key');
  failSave = false;
  barrier = Completer<void>();
  await rejects(
    queue(
      timeout: const Duration(milliseconds: 10),
    ).call('user-one', operation, params),
  );
  final timeoutKey = sent.last['p_request_key'];
  barrier.complete();
  barrier = null;
  await queue().call('user-one', operation, params);
  check(
    sent.last['p_request_key'] == timeoutKey,
    'Timeout discarded uncertain key',
  );
  final name = storage.keys.first;
  storage[name] = '{bad json';
  final beforeCorrupt = sent.length;
  await rejects(queue().call('user-one', operation, params));
  check(
    sent.length == beforeCorrupt,
    'Corrupt storage allowed unsafe new payment',
  );
  storage[name] = jsonEncode({
    'version': 1,
    'pending': {
      for (var i = 0; i < 100; i++) i.toRadixString(16).padLeft(64, '0'): key(),
    },
  });
  await rejects(queue().call('user-one', operation, params));
  check(sent.length == beforeCorrupt, 'Queue capacity silently discarded keys');
  await rejects(queue().call('', operation, params));
  await rejects(queue().call('user-one', 'unrelated_operation', params));
  stdout.writeln(
    '$checks payment retry checks passed with synthetic storage and RPCs.',
  );
}
