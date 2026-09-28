import 'admin_theme.dart';
import 'package:flutter/material.dart';
import '../services/platform_admin_service.dart';

class AdminField {
  const AdminField(
    this.keyName,
    this.label, {
    this.required = false,
    this.lines = 1,
    this.options,
    this.number = false,
    this.date = false,
  });
  final String keyName, label;
  final bool required, number, date;
  final int lines;
  final List<String>? options;
}

Future<bool> adminForm(
  BuildContext context, {
  required String title,
  required List<AdminField> fields,
  AdminRow initial = const {},
  required Future<void> Function(AdminRow) submit,
  String submitLabel = 'Save',
  String? explanation,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminForm(
        title: title,
        fields: fields,
        initial: initial,
        submit: submit,
        submitLabel: submitLabel,
        explanation: explanation,
      ),
    ) ??
    false;

class _AdminForm extends StatefulWidget {
  const _AdminForm({
    required this.title,
    required this.fields,
    required this.initial,
    required this.submit,
    required this.submitLabel,
    this.explanation,
  });
  final String title, submitLabel;
  final String? explanation;
  final List<AdminField> fields;
  final AdminRow initial;
  final Future<void> Function(AdminRow) submit;
  @override
  State<_AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<_AdminForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in widget.fields)
        f.keyName: TextEditingController(
          text: '${widget.initial[f.keyName] ?? ''}',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.submit({
        for (final e in _controllers.entries) e.key: e.value.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = PlatformAdminService.error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdminTheme(
    child: PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.explanation != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.explanation!),
                    ),
                  for (final f in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: f.options != null
                          ? DropdownButtonFormField<String>(
                              initialValue:
                                  f.options!.contains(
                                    _controllers[f.keyName]!.text,
                                  )
                                  ? _controllers[f.keyName]!.text
                                  : null,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: f.label),
                              items: [
                                for (final v in f.options!)
                                  DropdownMenuItem(
                                    value: v,
                                    child: Text(v.replaceAll('_', ' ')),
                                  ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) =>
                                        _controllers[f.keyName]!.text = v ?? '',
                              validator: (v) =>
                                  f.required && (v == null || v.isEmpty)
                                  ? 'Choose ${f.label.toLowerCase()}.'
                                  : null,
                            )
                          : TextFormField(
                              controller: _controllers[f.keyName],
                              enabled: !_saving,
                              minLines: f.lines,
                              maxLines: f.lines,
                              keyboardType: f.number
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true,
                                    )
                                  : (f.lines > 1
                                        ? TextInputType.multiline
                                        : TextInputType.text),
                              decoration: InputDecoration(
                                labelText: f.label,
                                hintText: f.date ? 'YYYY-MM-DD' : null,
                                suffixIcon: f.date
                                    ? IconButton(
                                        tooltip: 'Choose date',
                                        icon: const Icon(
                                          Icons.calendar_today_outlined,
                                        ),
                                        onPressed: _saving
                                            ? null
                                            : () async {
                                                final today = DateTime.now();
                                                final date =
                                                    await showDatePicker(
                                                      context: context,
                                                      initialDate:
                                                          DateTime.tryParse(
                                                            _controllers[f
                                                                    .keyName]!
                                                                .text,
                                                          ) ??
                                                          today,
                                                      firstDate: DateTime(2000),
                                                      lastDate: DateTime(2100),
                                                    );
                                                if (date != null && mounted) {
                                                  _controllers[f.keyName]!
                                                          .text =
                                                      PlatformAdminService.iso(
                                                        date,
                                                      );
                                                }
                                              },
                                      )
                                    : null,
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (f.required && s.isEmpty) {
                                  return 'Enter ${f.label.toLowerCase()}.';
                                }
                                if (s.isNotEmpty &&
                                    f.number &&
                                    (double.tryParse(s) == null ||
                                        !double.parse(s).isFinite ||
                                        double.parse(s) < 0)) {
                                  return 'Enter a valid positive amount or zero.';
                                }
                                if (s.isNotEmpty &&
                                    f.date &&
                                    (DateTime.tryParse(s) == null ||
                                        PlatformAdminService.iso(
                                              DateTime.parse(s),
                                            ) !=
                                            s)) {
                                  return 'Use YYYY-MM-DD.';
                                }
                                return null;
                              },
                            ),
                    ),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : widget.submitLabel),
          ),
        ],
      ),
    ),
  );
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class AdminStatus extends StatelessWidget {
  const AdminStatus(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (value) {
      'paid' ||
      'approved' ||
      'active' ||
      'published' => (const Color(0xFFE7F4ED), const Color(0xFF286749)),
      'overdue' ||
      'suspended' ||
      'rejected' => (const Color(0xFFFBEAEC), const Color(0xFF9B3542)),
      'pending' ||
      'unpaid' ||
      'part_paid' ||
      'trial' => (const Color(0xFFFFF3DA), const Color(0xFF8C661E)),
      _ => (const Color(0xFFEDF1F6), const Color(0xFF647386)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        value.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          letterSpacing: .4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AdminPager extends StatelessWidget {
  const AdminPager({
    super.key,
    required this.page,
    required this.more,
    required this.onPage,
  });
  final int page;
  final bool more;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Previous page',
        onPressed: page > 0 ? () => onPage(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Page ${page + 1}'),
      IconButton(
        tooltip: 'Next page',
        onPressed: more ? () => onPage(page + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

Future<bool> editSubscriptionAccount(
  BuildContext context,
  AdminRow business,
  AdminRow account,
) => adminForm(
  context,
  title: account.isEmpty
      ? 'Set up subscription account'
      : 'Edit subscription account',
  explanation:
      'Monthly fee is in AUD, before GST. Billing status does not automatically suspend business access.',
  initial: account.isNotEmpty
      ? account
      : {
          'plan_name': 'CutLink monthly',
          'status': 'active',
          'billing_name': PlatformAdminService.name(business),
          'billing_email': business['business_email'] ?? '',
          'billing_address': [
            business['address_line_1'],
            business['address_line_2'],
            business['suburb'],
            business['state'],
            business['postcode'],
          ].where((v) => v != null && '$v'.isNotEmpty).join(', '),
          'payment_terms_days': '14',
          'next_billing_date': PlatformAdminService.iso(DateTime.now()),
        },
  fields: const [
    AdminField('plan_name', 'Plan name', required: true),
    AdminField(
      'monthly_fee',
      'Monthly fee, excluding GST (AUD)',
      required: true,
      number: true,
    ),
    AdminField(
      'status',
      'Billing status',
      required: true,
      options: ['trial', 'active', 'paused', 'cancelled'],
    ),
    AdminField('billing_name', 'Bill to', required: true),
    AdminField('billing_email', 'Billing email', required: true),
    AdminField('billing_address', 'Billing address', lines: 2),
    AdminField(
      'payment_terms_days',
      'Payment terms (days)',
      required: true,
      number: true,
    ),
    AdminField(
      'next_billing_date',
      'Next billing date',
      required: true,
      date: true,
    ),
  ],
  submit: (data) async {
    await PlatformAdminService.action('save_account', {
      ...data,
      'business_id': business['id'] ?? account['business_id'],
    });
  },
);
