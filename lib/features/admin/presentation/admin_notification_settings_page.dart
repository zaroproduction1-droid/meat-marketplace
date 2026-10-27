import '../../../shared/widgets/ios_density.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/cutlink_review_theme.dart';
import '../../../shared/widgets/workspace_back_button.dart';

final adminNotificationPreferencesRevision = ValueNotifier<int>(0);

class AdminNotificationSettingsPage extends StatefulWidget {
  const AdminNotificationSettingsPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<AdminNotificationSettingsPage> createState() =>
      _AdminNotificationSettingsPageState();
}

class _AdminNotificationSettingsPageState
    extends State<AdminNotificationSettingsPage> {
  bool _loading = true, _saving = false, _enabled = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await Supabase.instance.client.rpc('admin_product_notification_inbox')
              as Map;
      if (mounted) {
        setState(() {
          _enabled = data['enabled'] != false;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Notification settings could not be loaded.';
        });
      }
    }
  }

  Future<void> _save(bool value) async {
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in required');
      }
      await client.from('admin_product_notification_settings').upsert({
        'user_id': user.id,
        'enabled': value,
      });
      adminNotificationPreferencesRevision.value++;
      if (mounted) {
        setState(() {
          _enabled = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The preference could not be saved. Please retry.',
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
    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Notifications',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const IosGap(height: 6),
        const Text('Choose the alerts shown in your admin notification bell.'),
        const IosGap(height: 20),
        if (_loading)
          const LinearProgressIndicator()
        else
          Card(
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              secondary: const Icon(Icons.fact_check_outlined),
              title: const Text('Product reports and corrections'),
              subtitle: const Text(
                'New reports, saved supplier changes, confirmations and replies. History stays available when alerts are muted.',
              ),
              value: _enabled,
              onChanged: _saving ? null : _save,
            ),
          ),
        if (_saving) const LinearProgressIndicator(),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Retry')),
      ],
    );
    return CutLinkReviewTheme(
      child: widget.embedded
          ? content
          : Scaffold(
              appBar: AppBar(
                leading: const WorkspaceBackButton(),
                title: const Text('Admin settings'),
              ),
              body: content,
            ),
    );
  }
}
