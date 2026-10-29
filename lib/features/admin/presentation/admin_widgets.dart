import '../../../shared/theme/cutlink_appearance.dart';
import '../../../shared/widgets/ios_density.dart';
import 'admin_theme.dart';

import 'package:flutter/material.dart';

import '../services/platform_admin_service.dart';
import '../../memberships/services/membership_service.dart';

class AdminField {
  const AdminField(
    this.keyName,
    this.label, {
    this.required = false,
    this.lines = 1,
    this.options,
    this.number = false,
    this.date = false,
    this.checkbox = false,
    this.optionLabels = const {},
  });
  final String keyName, label;
  final bool required, number, date, checkbox;
  final Map<String, String> optionLabels;
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
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return AdminTheme(
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
                      IosPadding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(widget.explanation!),
                      ),
                    for (final f in widget.fields)
                      IosPadding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: f.checkbox
                            ? FormField<bool>(
                                initialValue:
                                    _controllers[f.keyName]!.text == 'true',
                                validator: (value) =>
                                    f.required && value != true
                                    ? 'Please confirm before continuing.'
                                    : null,
                                builder: (field) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(f.label),
                                      value: field.value ?? false,
                                      onChanged: _saving
                                          ? null
                                          : (value) {
                                              field.didChange(value);
                                              _controllers[f.keyName]!.text =
                                                  '${value == true}';
                                            },
                                    ),
                                    if (field.hasError)
                                      Text(
                                        field.errorText!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : f.options != null
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
                                      child: Text(
                                        f.optionLabels[v] ??
                                            v.replaceAll('_', ' '),
                                      ),
                                    ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (v) => _controllers[f.keyName]!.text =
                                          v ?? '',
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
                                                        firstDate: DateTime(
                                                          2000,
                                                        ),
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
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
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: IosPadding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class AdminStatus extends StatelessWidget {
  const AdminStatus(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    final (background, foreground) = switch (value) {
      'paid' || 'approved' || 'active' || 'published' => (
        CutLinkPalette.color(0xFFE7F4ED),
        const Color(0xFF286749),
      ),
      'overdue' ||
      'suspended' ||
      'rejected' => (CutLinkPalette.color(0xFFFBEAEC), const Color(0xFF9B3542)),
      'pending' ||
      'unpaid' ||
      'part_paid' ||
      'trial' => (CutLinkPalette.color(0xFFFFF3DA), const Color(0xFF8C661E)),
      _ => (CutLinkPalette.color(0xFFEDF1F6), CutLinkPalette.color(0xFF647386)),
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
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Row(
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
}

Future<bool> editSubscriptionAccount(
  BuildContext context,
  AdminRow business,
  AdminRow account,
) {
  final managed = MembershipService.map(account['membership']).isNotEmpty;
  final initial = account.isNotEmpty
      ? {
          ...account,
          'fee_basis': account['fee_gst_inclusive'] == true
              ? 'including_gst'
              : 'excluding_gst',
        }
      : <String, dynamic>{
          'plan_name': 'CutLink monthly',
          'fee_basis': 'including_gst',
          'monthly_fee': MembershipService.standardPrice(
            business['business_type'] == 'supplier',
          ).toStringAsFixed(2),
          'status': 'active',
          'billing_name': PlatformAdminService.name(business),
          'billing_email': business['business_email'] ?? '',
          'billing_address': [
            business['address_line_1'],
            business['address_line_2'],
            business['suburb'],
            business['state'],
            business['postcode'],
          ].where((value) => value != null && '$value'.isNotEmpty).join(', '),
          'payment_terms_days': '14',
          'next_billing_date': PlatformAdminService.iso(DateTime.now()),
        };
  return adminForm(
    context,
    title: account.isEmpty
        ? 'Manual billing account'
        : 'Billing contact & schedule',
    explanation: managed
        ? 'Your membership offer sets the price automatically. Pausing billing does not suspend business access.'
        : 'Custom billing uses the fee you enter. To start a founding offer, use Start membership on the business billing page.',
    initial: initial,
    fields: [
      const AdminField('billing_name', 'Bill to', required: true),
      const AdminField('billing_email', 'Billing email', required: true),
      const AdminField('billing_address', 'Billing address', lines: 2),
      const AdminField(
        'payment_terms_days',
        'Days to pay',
        required: true,
        number: true,
      ),
      const AdminField(
        'next_billing_date',
        'Next invoice starts',
        required: true,
        date: true,
      ),
      const AdminField(
        'status',
        'Billing',
        required: true,
        options: ['active', 'trial', 'paused', 'cancelled'],
        optionLabels: {
          'active': 'Active',
          'trial': 'Trial',
          'paused': 'Paused',
          'cancelled': 'Cancelled',
        },
      ),
      if (!managed) ...[
        const AdminField('plan_name', 'Invoice description', required: true),
        const AdminField(
          'monthly_fee',
          'Custom monthly fee (AUD)',
          required: true,
          number: true,
        ),
        const AdminField(
          'fee_basis',
          'Does that fee include GST?',
          required: true,
          options: ['including_gst', 'excluding_gst'],
          optionLabels: {
            'including_gst': 'Yes — GST included',
            'excluding_gst': 'No — add GST if registered',
          },
        ),
      ],
    ],
    submit: (data) async {
      await PlatformAdminService.action('save_account', {
        ...initial,
        ...data,
        'business_id': business['id'] ?? account['business_id'],
        'fee_gst_inclusive':
            (data['fee_basis'] ?? initial['fee_basis']) == 'including_gst',
      });
    },
  );
}
