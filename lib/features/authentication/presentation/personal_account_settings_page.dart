import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/phone_layout.dart';

typedef AccountProfileLoader = Future<Map<String, dynamic>> Function();
typedef AccountProfileSaver =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> values);

/// The signed-in person's identity, separate from business and accounts contacts.
class PersonalAccountSettingsPage extends StatefulWidget {
  const PersonalAccountSettingsPage({
    super.key,
    this.loadProfile,
    this.saveProfile,
    this.signInEmail,
    this.embedded = false,
  });

  final AccountProfileLoader? loadProfile;
  final AccountProfileSaver? saveProfile;
  final String? signInEmail;

  /// Render directly inside Business profile without a separate page or scroll.
  final bool embedded;

  @override
  State<PersonalAccountSettingsPage> createState() =>
      _PersonalAccountSettingsPageState();
}

class _PersonalAccountSettingsPageState
    extends State<PersonalAccountSettingsPage> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _fill(Map<String, dynamic> row) {
    _first.text = row['first_name']?.toString() ?? '';
    _last.text = row['last_name']?.toString() ?? '';
    _phone.text = row['phone']?.toString() ?? '';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loader = widget.loadProfile;
      final Map<String, dynamic> row;
      if (loader != null) {
        row = await loader();
      } else {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user == null) {
          throw StateError('Sign in to edit your account.');
        }
        row = await client
            .from('profiles')
            .select('first_name,last_name,phone')
            .eq('id', user.id)
            .single();
      }
      if (mounted) {
        setState(() {
          _fill(row);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Could not load your account details.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final values = <String, dynamic>{
      'first_name': _first.text.trim(),
      'last_name': _last.text.trim(),
      'phone': _phone.text.trim(),
    };
    try {
      final saver = widget.saveProfile;
      final Map<String, dynamic> saved;
      if (saver != null) {
        saved = await saver(values);
      } else {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user == null) {
          throw StateError('Sign in to edit your account.');
        }
        saved = await client
            .from('profiles')
            .update(values)
            .eq('id', user.id)
            .select('first_name,last_name,phone')
            .single();
      }
      if (mounted) {
        setState(() => _fill(saved));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your contact details have been saved.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError =
              'Could not save your details. Your changes are kept here; try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.signInEmail ??
        (widget.loadProfile == null
            ? Supabase.instance.client.auth.currentUser?.email
            : null) ??
        '';
    final content = _loading
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        : _loadError != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_loadError!),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          )
        : Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your contact details',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your name appears on new support tickets and messages.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6D7177)),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final firstName = TextFormField(
                      key: const ValueKey('account-first-name'),
                      controller: _first,
                      enabled: !_saving,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your first name.'
                          : null,
                    );
                    final lastName = TextFormField(
                      key: const ValueKey('account-last-name'),
                      controller: _last,
                      enabled: !_saving,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Last name (optional)',
                      ),
                    );
                    if (constraints.maxWidth < 600) {
                      return Column(children: [firstName, lastName]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: firstName),
                        const SizedBox(width: 12),
                        Expanded(child: lastName),
                      ],
                    );
                  },
                ),
                TextFormField(
                  key: const ValueKey('account-phone'),
                  controller: _phone,
                  enabled: !_saving,
                  maxLength: 40,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Personal phone (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Sign-in email'),
                  child: SelectableText(email),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Previously sent messages keep their original name. '
                  'Save your contact details here; use the business save action '
                  'for the company details below.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6D7177)),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: const TextStyle(color: Color(0xFF741C1C)),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const ValueKey('account-save'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF741C1C),
                    ),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving…' : 'Save contact details'),
                  ),
                ),
              ],
            ),
          );
    return PopScope(
      canPop: !_saving,
      child: widget.embedded
          ? content
          : Scaffold(
              appBar: phoneAppBar(
                context,
                AppBar(title: const Text('Your contact details')),
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: content,
                  ),
                ),
              ),
            ),
    );
  }
}
