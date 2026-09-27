import '../../../shared/widgets/cutlink_picker.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../../../shared/widgets/workspace_back_button.dart';
import '../../../shared/widgets/zoomable_pdf_preview.dart';
import '../../../shared/navigation/page_location.dart';
import '../services/credit_note_pdf.dart';

String creditRequestKey() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

double creditNumber(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
String creditMoney(dynamic v) => '\$${creditNumber(v).toStringAsFixed(2)}';

class CreditNotesPage extends StatefulWidget {
  const CreditNotesPage({
    super.key,
    required this.supplierView,
    this.invoiceId,
    this.accountId,
    this.embedded = false,
  });
  final bool supplierView;
  final String? invoiceId;
  final String? accountId;
  final bool embedded;
  @override
  State<CreditNotesPage> createState() => _CreditNotesPageState();
}

class _CreditNotesPageState extends State<CreditNotesPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _more = false;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var query = Supabase.instance.client
          .from('supplier_credit_notes')
          .select(
            '*, account_credits(amount,refunded_amount,net_amount,credit_allocations(amount,status)), supplier_credit_refunds(amount)',
          );
      if (widget.invoiceId != null) {
        query = query.eq('invoice_id', widget.invoiceId!);
      }
      if (widget.accountId != null) {
        query = query.eq('supplier_customer_account_id', widget.accountId!);
      }
      if (_search.text.trim().isNotEmpty) {
        query = query.ilike('credit_number', '%${_search.text.trim()}%');
      }
      final rows = await query
          .order('created_at', ascending: false)
          .range(_page * 40, _page * 40 + 40);
      if (!mounted) return;
      setState(() {
        _more = rows.length > 40;
        _rows = rows.take(40).map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreditNoteEditor(
          invoiceId: widget.invoiceId,
          accountId: widget.accountId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedded) {
      PageLocation.track(context, {
        'page': 'credits',
        'supplier': widget.supplierView,
        'invoice': widget.invoiceId,
        'account': widget.accountId,
      });
    }
    return CutLinkWorkspaceTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(
            automaticallyImplyLeading: !widget.embedded,
            leading: widget.embedded ? null : const WorkspaceBackButton(),
            title: const Text('Credit notes & refunds'),
            actions: [
              if (widget.supplierView)
                TextButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Credit'),
                ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: CutLinkSectionHeading(
                    title: 'Credits & refunds',
                    subtitle:
                        'Invoice adjustments, returned goods and available account credit.',
                    icon: Icons.assignment_return_outlined,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) {
                      _page = 0;
                      _load();
                    },
                    decoration: InputDecoration(
                      labelText: 'Search credit note number',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _page = 0;
                          _load();
                        },
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _rows.isEmpty
                      ? const Center(child: Text('No credit notes yet.'))
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final n = _rows[index];
                            final a = n['account_credits'] as Map? ?? {};
                            final refunded = creditNumber(a['refunded_amount']);
                            final available =
                                creditNumber(a['net_amount']) -
                                (a['credit_allocations'] as List? ?? [])
                                    .where((v) => v['status'] == 'active')
                                    .fold(
                                      0.0,
                                      (sum, v) =>
                                          sum + creditNumber(v['amount']),
                                    );
                            final snapshot =
                                n['invoice_snapshot'] as Map? ?? {};
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.receipt_long_outlined,
                                  color: Color(0xFF741C1C),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                titleTextStyle: const TextStyle(
                                  color: CutLinkWorkspaceTheme.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                                title: Text(
                                  '${n['credit_number']} • ${snapshot['customer_name_snapshot'] ?? ''}',
                                ),
                                subtitle: Text(
                                  '${snapshot['invoice_number'] ?? ''} • ${n['reason']}\n${refunded == 0
                                      ? (available > 0 ? 'Account credit available' : 'Applied to invoice')
                                      : refunded >= creditNumber(n['total_amount'])
                                      ? 'Refunded'
                                      : 'Partially refunded'}',
                                ),
                                trailing: Text(
                                  creditMoney(n['total_amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CreditNoteDetail(
                                        noteId: n['id'].toString(),
                                        supplierView: widget.supplierView,
                                      ),
                                    ),
                                  );
                                  if (mounted) _load();
                                },
                              ),
                            );
                          },
                        ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _page > 0 && !_loading
                          ? () {
                              _page--;
                              _load();
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page ${_page + 1}'),
                    TextButton(
                      onPressed: _more && !_loading
                          ? () {
                              _page++;
                              _load();
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreditNoteEditor extends StatefulWidget {
  const CreditNoteEditor({
    super.key,
    this.invoiceId,
    this.issueId,
    this.accountId,
  });
  final String? accountId;
  final String? invoiceId;
  final String? issueId;
  @override
  State<CreditNoteEditor> createState() => _CreditNoteEditorState();
}

class _CreditLine {
  _CreditLine(this.item, this.remaining, this.returnable, this.weightRemaining);
  final Map<String, dynamic> item;
  final double remaining, returnable, weightRemaining;
  bool selected = false, restock = false;
  final amount = TextEditingController(),
      quantity = TextEditingController(text: '0'),
      weight = TextEditingController(text: '0');
  void dispose() {
    amount.dispose();
    quantity.dispose();
    weight.dispose();
  }
}

class _CreditNoteEditorState extends State<CreditNoteEditor> {
  final _search = TextEditingController(), _notes = TextEditingController();
  final _key = creditRequestKey();
  String _reason = 'Returned goods';
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _invoices = [];
  final List<_CreditLine> _lines = [];
  @override
  void initState() {
    super.initState();
    if (widget.invoiceId != null) {
      _select(widget.invoiceId!);
    } else {
      _find();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final supplier = await Supabase.instance.client.rpc(
        'current_supplier_business_id',
      );
      var q = Supabase.instance.client
          .from('invoices')
          .select('id,invoice_number,customer_name_snapshot,total_amount')
          .eq('supplier_business_id', supplier.toString())
          .inFilter('status', ['issued', 'part_paid', 'paid']);
      if (widget.accountId != null) {
        q = q.eq('supplier_customer_account_id', widget.accountId!);
      }
      if (_search.text.trim().isNotEmpty) {
        q = q.ilike('invoice_number', '%${_search.text.trim()}%');
      }
      final rows = await q.order('created_at', ascending: false).limit(40);
      if (mounted) {
        setState(
          () => _invoices = rows
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(String id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = Supabase.instance.client;
      final values = await Future.wait<dynamic>([
        c.from('invoices').select('*,invoice_items(*)').eq('id', id).single(),
        c
            .from('supplier_credit_notes')
            .select('supplier_credit_note_lines(*)')
            .eq('invoice_id', id),
      ]);
      if (!mounted) return;
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      _invoice = Map<String, dynamic>.from(values[0] as Map);
      final previous = [
        for (final n in values[1] as List)
          ...n['supplier_credit_note_lines'] as List,
      ];
      for (final raw in _invoice!['invoice_items'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final used = previous.where((e) => e['invoice_item_id'] == item['id']);
        final remaining =
            creditNumber(item['line_amount']) -
            used.fold(0.0, (s, e) => s + creditNumber(e['amount']));
        final quantity =
            creditNumber(
              item['supplied_quantity'] ?? item['ordered_quantity'],
            ) -
            used.fold(0.0, (s, e) => s + creditNumber(e['quantity']));
        final weight =
            creditNumber(item['actual_weight']) -
            used.fold(0.0, (s, e) => s + creditNumber(e['weight_kg']));
        if (remaining > 0) {
          _lines.add(_CreditLine(item, remaining, quantity, weight));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue() async {
    final lines = _lines.where((l) => l.selected).toList();
    if (lines.isEmpty) {
      setState(() => _error = 'Choose at least one item.');
      return;
    }
    for (final l in lines) {
      final amount = double.tryParse(l.amount.text),
          q = double.tryParse(l.quantity.text),
          w = double.tryParse(l.weight.text);
      if (amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          amount > l.remaining ||
          q == null ||
          !q.isFinite ||
          q < 0 ||
          q > l.returnable ||
          w == null ||
          !w.isFinite ||
          w < 0 ||
          w > l.weightRemaining) {
        setState(
          () => _error =
              'Check amounts, returned units and kg against the remaining invoice quantities.',
        );
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await Supabase.instance.client.rpc(
        'create_supplier_credit_note',
        params: {
          'p_invoice_id': _invoice!['id'],
          'p_reason': _reason,
          'p_request_key': _key,
          'p_issue_id': widget.issueId,
          'p_notes': _notes.text.trim(),
          'p_lines': [
            for (final l in lines)
              {
                'invoice_item_id': l.item['id'],
                'amount': double.parse(l.amount.text),
                'quantity': double.parse(l.quantity.text),
                'weight_kg': double.parse(l.weight.text),
                'restock': l.restock,
              },
          ],
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              CreditNoteDetail(noteId: id.toString(), supplierView: true),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _number(TextEditingController c, String label, double max) => SizedBox(
    width: 180,
    child: TextField(
      controller: c,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Maximum ${max.toStringAsFixed(2)}',
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    PageLocation.track(context, {
      'page': 'credit_editor',
      'invoice': _invoice?['id'] ?? widget.invoiceId,
      'issue': widget.issueId,
      'account': widget.accountId,
    });
    final total = _lines
        .where((l) => l.selected)
        .fold(0.0, (s, l) => s + creditNumber(l.amount.text));
    return CutLinkWorkspaceTheme(
      child: PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: phoneAppBar(
            context,
            AppBar(title: const Text('Create credit note')),
          ),
          bottomNavigationBar: _invoice == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _issue,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text('Issue credit note • ${creditMoney(total)}'),
                    ),
                  ),
                ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const CutLinkSectionHeading(
                    title: 'Create a credit',
                    subtitle:
                        'Credit the original invoice. Any unused balance stays on the customer account.',
                    icon: Icons.assignment_return_outlined,
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_invoice == null) ...[
                    TextField(
                      controller: _search,
                      onSubmitted: (_) => _find(),
                      decoration: InputDecoration(
                        labelText: 'Find original invoice number',
                        suffixIcon: IconButton(
                          onPressed: _busy ? null : _find,
                          icon: const Icon(Icons.search),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final i in _invoices)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${i['invoice_number']} • ${i['customer_name_snapshot']}',
                          ),
                          trailing: Text(creditMoney(i['total_amount'])),
                          onTap: _busy
                              ? null
                              : () => _select(i['id'].toString()),
                        ),
                      ),
                  ] else ...[
                    Text(
                      '${_invoice!['invoice_number']} • ${_invoice!['customer_name_snapshot']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Select the affected items and credit amount. Returned units and kg are optional for price adjustments. Restock only goods physically received and approved for resale.',
                    ),
                    const SizedBox(height: 16),
                    CutLinkPickerField<String>(
                      value: _reason,
                      label: 'Credit reason',
                      enabled: !_busy,
                      enableSearch: false,
                      options: [
                        for (final r in [
                          'Returned goods',
                          'Damaged goods',
                          'Quality issue',
                          'Wrong product',
                          'Short supply',
                          'Price correction',
                          'Goodwill adjustment',
                          'Other',
                        ])
                          CutLinkPickerOption(value: r, label: r),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _reason = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    for (final l in _lines)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: l.selected,
                                title: Text(
                                  l.item['product_name_snapshot']?.toString() ??
                                      'Item',
                                ),
                                subtitle: Text(
                                  'Available credit ${creditMoney(l.remaining)}',
                                ),
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() {
                                        l.selected = v!;
                                        if (l.selected &&
                                            l.amount.text.isEmpty) {
                                          l.amount.text = l.remaining
                                              .toStringAsFixed(2);
                                        }
                                      }),
                              ),
                              if (l.selected) ...[
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _number(
                                      l.amount,
                                      'Credit inc GST',
                                      l.remaining,
                                    ),
                                    _number(
                                      l.quantity,
                                      'Returned ${l.item['supplied_quantity_unit'] ?? 'units'}',
                                      l.returnable,
                                    ),
                                    if (l.weightRemaining > 0)
                                      _number(
                                        l.weight,
                                        'Returned kg',
                                        l.weightRemaining,
                                      ),
                                  ],
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Return received goods to stock',
                                  ),
                                  subtitle: const Text(
                                    'Leave off for damaged, missing or non-resaleable goods.',
                                  ),
                                  value: l.restock,
                                  onChanged: _busy
                                      ? null
                                      : (v) => setState(() => l.restock = v),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (_lines.isEmpty)
                      const Text(
                        'All items on this invoice have already been credited.',
                      ),
                    TextField(
                      controller: _notes,
                      enabled: !_busy,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Customer-visible notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreditNoteDetail extends StatefulWidget {
  const CreditNoteDetail({
    super.key,
    required this.noteId,
    required this.supplierView,
  });
  final String noteId;
  final bool supplierView;
  @override
  State<CreditNoteDetail> createState() => _CreditNoteDetailState();
}

class _CreditNoteDetailState extends State<CreditNoteDetail> {
  Map<String, dynamic>? _note;
  bool _busy = false, _preview = false;
  String? _error;
  String? _refundKey;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final n = await Supabase.instance.client
          .from('supplier_credit_notes')
          .select(
            '*,supplier_credit_note_lines(*),supplier_credit_refunds(*),account_credits(*,credit_allocations(*))',
          )
          .eq('id', widget.noteId)
          .single();
      if (mounted) {
        setState(() {
          _note = Map<String, dynamic>.from(n);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double get _available {
    final c = _note?['account_credits'] as Map? ?? {};
    final used = (c['credit_allocations'] as List? ?? [])
        .where((a) => a['status'] == 'active')
        .fold(0.0, (s, a) => s + creditNumber(a['amount']));
    return (creditNumber(c['net_amount']) - used)
        .clamp(0, double.infinity)
        .toDouble();
  }

  Future<void> _refund() async {
    final amount = TextEditingController(text: _available.toStringAsFixed(2)),
        reference = TextEditingController();
    var method = 'bank_transfer';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => CutLinkWorkspaceTheme(
          child: AlertDialog(
            title: const Text('Record money refunded'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Record a refund only after returning the money. This does not send money through a bank or card provider.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount refunded',
                      helperText: 'Available credit ${creditMoney(_available)}',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  CutLinkPickerField<String>(
                    value: method,
                    label: 'Refund method',
                    enableSearch: false,
                    options: [
                      for (final v in [
                        'bank_transfer',
                        'cash',
                        'card',
                        'cheque',
                        'other',
                      ])
                        CutLinkPickerOption(
                          value: v,
                          label: v.replaceAll('_', ' '),
                        ),
                    ],
                    onChanged: (v) => change(() => method = v!),
                  ),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Transaction reference / receipt',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = double.tryParse(amount.text);
                  if (value == null ||
                      !value.isFinite ||
                      value <= 0 ||
                      value > _available) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter an amount within available credit.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, {
                    'amount': value,
                    'method': method,
                    'reference': reference.text.trim(),
                  });
                },
                child: const Text('Record refund'),
              ),
            ],
          ),
        ),
      ),
    );
    amount.dispose();
    reference.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _refundKey ??= creditRequestKey();
    try {
      await Supabase.instance.client.rpc(
        'refund_supplier_credit_note',
        params: {
          'p_credit_note_id': widget.noteId,
          'p_amount': result['amount'],
          'p_method': result['method'],
          'p_reference': result['reference'],
          'p_request_key': _refundKey,
        },
      );
      _refundKey = null;
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _allocate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = _note!;
      var q = Supabase.instance.client
          .from('invoices')
          .select('id,invoice_number,outstanding_amount')
          .eq('supplier_business_id', n['supplier_business_id'].toString())
          .inFilter('status', ['issued', 'part_paid'])
          .gt('outstanding_amount', 0);
      if (n['butcher_business_id'] != null) {
        q = q.eq('butcher_business_id', n['butcher_business_id'].toString());
      } else {
        q = q.eq(
          'supplier_customer_account_id',
          n['supplier_customer_account_id'].toString(),
        );
      }
      final rows = await q.order('due_date').limit(100);
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(
          () => _error =
              'No unpaid invoices. The credit remains available on this customer’s account.',
        );
        return;
      }
      String id = rows.first['id'].toString();
      final amount = TextEditingController(
        text: min(
          _available,
          creditNumber(rows.first['outstanding_amount']),
        ).toStringAsFixed(2),
      );
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, change) => CutLinkWorkspaceTheme(
            child: AlertDialog(
              title: const Text('Apply credit to invoice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CutLinkPickerField<String>(
                    value: id,
                    label: 'Invoice to credit',
                    options: [
                      for (final i in rows)
                        CutLinkPickerOption(
                          value: i['id'].toString(),
                          label:
                              '${i['invoice_number']} • ${creditMoney(i['outstanding_amount'])}',
                        ),
                    ],
                    onChanged: (v) => change(() {
                      id = v!;
                      amount.text = min(
                        _available,
                        creditNumber(
                          rows.firstWhere(
                            (r) => r['id'] == id,
                          )['outstanding_amount'],
                        ),
                      ).toStringAsFixed(2);
                    }),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount to apply',
                      prefixText: '\$ ',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'invoice_id': id,
                    'amount': double.tryParse(amount.text) ?? 0,
                  }),
                  child: const Text('Apply credit'),
                ),
              ],
            ),
          ),
        ),
      );
      amount.dispose();
      if (result == null || !mounted) return;
      await Supabase.instance.client.rpc(
        'allocate_account_credit',
        params: {
          'target_credit_id': n['account_credit_id'],
          'allocations_json': [result],
        },
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _document(bool print) async {
    try {
      final bytes = await CreditNotePdf.build(_note!);
      if (print) {
        await Printing.layoutPdf(
          name: _note!['credit_number'].toString(),
          onLayout: (_) => bytes,
        );
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${_note!['credit_number']}.pdf',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    PageLocation.track(context, {
      'page': 'credit_note',
      'id': widget.noteId,
      'supplier': widget.supplierView,
    });
    final n = _note;
    final credit = n?['account_credits'] as Map? ?? {};
    final refunded = creditNumber(credit['refunded_amount']);
    return CutLinkWorkspaceTheme(
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(
            title: Text(n?['credit_number']?.toString() ?? 'Credit note'),
            actions: [
              IconButton(
                onPressed: n == null ? null : () => _document(false),
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Download credit note',
              ),
              IconButton(
                onPressed: n == null ? null : () => _document(true),
                icon: const Icon(Icons.print_outlined),
                tooltip: 'Print credit note',
              ),
              IconButton(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        body: n == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(_error!),
              )
            : Column(
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Credit note'),
                          selected: !_preview,
                          onSelected: (_) => setState(() => _preview = false),
                        ),
                        ChoiceChip(
                          label: const Text('Preview'),
                          selected: _preview,
                          onSelected: (_) => setState(() => _preview = true),
                        ),
                        if (widget.supplierView) ...[
                          OutlinedButton.icon(
                            onPressed: _busy || _available <= 0
                                ? null
                                : _allocate,
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            label: const Text('Apply to invoice'),
                          ),
                          FilledButton.icon(
                            onPressed: _busy || _available <= 0
                                ? null
                                : _refund,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record refund'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: _preview
                        ? ZoomablePdfPreview(
                            documentKey: n['id'].toString(),
                            buildPdf: () => CreditNotePdf.build(n),
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  const CutLinkSectionHeading(
                                    title: 'Credit summary',
                                    subtitle:
                                        'Allocation, returned goods and refund history.',
                                    icon: Icons.receipt_long_outlined,
                                  ),
                                  Text(
                                    '${(n['invoice_snapshot'] as Map)['customer_name_snapshot']} • ${(n['invoice_snapshot'] as Map)['invoice_number']}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final columns =
                                          constraints.maxWidth >= 900
                                          ? 4
                                          : constraints.maxWidth >= 460
                                          ? 2
                                          : 1;
                                      final width =
                                          (constraints.maxWidth -
                                              (columns - 1) * 12) /
                                          columns;
                                      final tiles = [
                                        CutLinkMetricTile(
                                          label: 'Credit note total',
                                          value: creditMoney(n['total_amount']),
                                          icon: Icons.receipt_long_outlined,
                                        ),
                                        CutLinkMetricTile(
                                          label: 'Applied to invoices',
                                          value: creditMoney(
                                            creditNumber(n['total_amount']) -
                                                refunded -
                                                _available,
                                          ),
                                          icon: Icons.task_alt_rounded,
                                        ),
                                        CutLinkMetricTile(
                                          label: 'Money refunded',
                                          value: creditMoney(refunded),
                                          icon: Icons.payments_outlined,
                                        ),
                                        CutLinkMetricTile(
                                          label: 'Available account credit',
                                          value: creditMoney(_available),
                                          icon: Icons
                                              .account_balance_wallet_outlined,
                                        ),
                                      ];
                                      return Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          for (final tile in tiles)
                                            SizedBox(width: width, child: tile),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Reason: ${n['reason']}'),
                                  if ((n['notes']?.toString() ?? '').isNotEmpty)
                                    Text(n['notes'].toString()),
                                  const SizedBox(height: 16),
                                  for (final l
                                      in n['supplier_credit_note_lines']
                                          as List)
                                    Card(
                                      child: ListTile(
                                        title: Text(
                                          l['description'].toString(),
                                        ),
                                        subtitle: Text(
                                          '${l['quantity']} ${l['quantity_unit'] ?? 'units'} • ${l['weight_kg']} kg • ${l['restock'] == true ? 'Restocked' : 'Not restocked'}',
                                        ),
                                        trailing: Text(
                                          creditMoney(l['amount']),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Refund history',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if ((n['supplier_credit_refunds'] as List)
                                      .isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'No money refunded. Available credit stays on this supplier account.',
                                      ),
                                    ),
                                  for (final r
                                      in n['supplier_credit_refunds'] as List)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.payments_outlined,
                                      ),
                                      title: Text(
                                        '${creditMoney(r['amount'])} • ${r['method'].toString().replaceAll('_', ' ')}',
                                      ),
                                      subtitle: Text(
                                        '${r['refunded_at'].toString().split('T').first} ${r['reference'] ?? ''}',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
