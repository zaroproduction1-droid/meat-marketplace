import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A dated read of the ledger, not an extra charge on this invoice.
class InvoiceAccountBalance {
  const InvoiceAccountBalance._();

  static Future<Map<String, dynamic>> load(String invoiceId) async {
    final result = await Supabase.instance.client.rpc(
      'get_invoice_account_balance',
      params: {'target_invoice_id': invoiceId},
    );
    final data = Map<String, dynamic>.from(result as Map);
    if (data['account_balance'] == null || data['as_at'] == null) {
      throw StateError('Account balance is unavailable. Please refresh.');
    }
    return data;
  }

  static Future<Map<String, dynamic>?> tryLoad(String invoiceId) async {
    try {
      return await load(invoiceId);
    } catch (_) {
      // Never present a failed request as a zero account balance.
      return null;
    }
  }
}

class InvoiceAccountBalancePanel extends StatelessWidget {
  const InvoiceAccountBalancePanel({super.key, required this.balance});

  final Map<String, dynamic>? balance;

  @override
  Widget build(BuildContext context) {
    final data = balance;
    if (data == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Account balance unavailable. Refresh to try again.'),
      );
    }
    double amount(String key) => (data[key] as num).toDouble();
    String money(double value) {
      final parts = value.abs().toStringAsFixed(2).split('.');
      final whole = parts.first.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
      return '${value < 0 ? '-' : ''}\$$whole.${parts.last}';
    }

    final net = amount('account_balance');
    final asAt = DateTime.parse(data['as_at'].toString()).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${two(asAt.day)}/${two(asAt.month)}/${asAt.year} '
        '${two(asAt.hour)}:${two(asAt.minute)}';
    Widget row(String title, double value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          const SizedBox(width: 8),
          Text(
            money(value),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            net < 0 ? 'Account in credit' : 'Account balance',
            net.abs(),
            strong: true,
          ),
          if (amount('unallocated_payments') > 0 ||
              amount('available_credit') > 0) ...[
            row('Unpaid invoices', amount('outstanding_invoices')),
            if (amount('unallocated_payments') > 0)
              row('Less unallocated payments', -amount('unallocated_payments')),
            if (amount('available_credit') > 0)
              row('Less available credits', -amount('available_credit')),
          ],
          const SizedBox(height: 5),
          Text(
            'As at $timestamp. '
            '${data['invoice_included'] == true ? 'Includes this invoice.' : 'This draft/void invoice is not included.'} '
            '${data['scope'] == 'sent_invoices' ? 'Sent invoices only. ' : ''}'
            'Not an additional charge. Pending payments excluded.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
