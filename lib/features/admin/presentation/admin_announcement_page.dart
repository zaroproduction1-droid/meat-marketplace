import 'admin_theme.dart';
import 'announcement_style.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';
import '../../../shared/widgets/phone_layout.dart';
import '../services/platform_admin_service.dart';
import 'admin_widgets.dart';

class AdminAnnouncementPage extends StatefulWidget {
  const AdminAnnouncementPage({super.key});
  @override
  State<AdminAnnouncementPage> createState() => _AdminAnnouncementPageState();
}

class _AdminAnnouncementPageState extends State<AdminAnnouncementPage> {
  final _title = TextEditingController(), _body = TextEditingController();
  String _audience = 'all', _channel = 'both', _tone = 'normal';
  final Map<String, String> _selected = {};
  DateTime? _expiry;
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _targets() async {
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _BusinessTargets(selected: _selected),
    );
    if (selected != null && mounted) {
      setState(() {
        _selected.clear();
        _selected.addAll(selected);
      });
    }
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty ||
        _body.text.trim().isEmpty ||
        (_audience == 'selected' && _selected.isEmpty)) {
      setState(
        () => _error =
            'Enter a title and message, and select the target businesses.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Preview announcement'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AnnouncementStyle.background(_tone),
                    border: Border.all(color: const Color(0xFFE3E5E8)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AnnouncementStyle.icon(_tone),
                        color: AnnouncementStyle.foreground(_tone),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AnnouncementStyle.labels[_tone]!,
                          style: TextStyle(
                            color: AnnouncementStyle.foreground(_tone),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _title.text.trim(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(_body.text.trim()),
                const Divider(),
                Text(
                  'Audience: ${_audience == 'all'
                      ? 'All businesses'
                      : _audience == 'selected'
                      ? '${_selected.length} selected businesses'
                      : '${_audience}s'}',
                ),
                Text(
                  'Delivery: ${_channel == 'both' ? 'Banner and notification' : _channel}',
                ),
                Text(
                  _expiry == null
                      ? 'Banner remains until archived.'
                      : 'Banner expires ${PlatformAdminService.date(_expiry!.toIso8601String())}',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Publish now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PlatformAdminService.action('publish_announcement', {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'audience': _audience,
        'channel': _channel,
        'tone': _tone,
        'business_ids': _audience == 'selected'
            ? _selected.keys.toList()
            : <String>[],
        'expires_at': _expiry?.toUtc().toIso8601String(),
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
      child: Scaffold(
        appBar: phoneAppBar(
          context,
          AppBar(title: const Text('New announcement')),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CutLinkSectionHeading(
                  title: 'Reach your businesses',
                  subtitle: 'Publish a CutLink notice to the right audience.',
                  icon: Icons.campaign_outlined,
                ),
                const SizedBox(height: 18),
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _tone,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Banner colour / message type',
                        ),
                        items: [
                          for (final item in AnnouncementStyle.labels.entries)
                            DropdownMenuItem(
                              value: item.key,
                              child: Text(item.value),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _tone = value!),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _title,
                        enabled: !_saving,
                        maxLength: 160,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _body,
                        enabled: !_saving,
                        minLines: 5,
                        maxLines: 12,
                        maxLength: 5000,
                        decoration: const InputDecoration(labelText: 'Message'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _audience,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Audience',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All businesses'),
                          ),
                          DropdownMenuItem(
                            value: 'supplier',
                            child: Text('Suppliers'),
                          ),
                          DropdownMenuItem(
                            value: 'butcher',
                            child: Text('Butchers'),
                          ),
                          DropdownMenuItem(
                            value: 'selected',
                            child: Text('Selected businesses'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _audience = v!),
                      ),
                      if (_audience == 'selected') ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _targets,
                          icon: const Icon(Icons.business_outlined),
                          label: Text(
                            'Choose businesses (${_selected.length})',
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final b in _selected.entries)
                              Chip(
                                label: Text(b.value),
                                onDeleted: _saving
                                    ? null
                                    : () => setState(
                                        () => _selected.remove(b.key),
                                      ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _channel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Delivery',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'banner',
                            child: Text('Top banner'),
                          ),
                          DropdownMenuItem(
                            value: 'notification',
                            child: Text('Notification'),
                          ),
                          DropdownMenuItem(
                            value: 'both',
                            child: Text('Banner and notification'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _channel = v!),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _expiry ??
                                          DateTime.now().add(
                                            const Duration(days: 7),
                                          ),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 730),
                                      ),
                                    );
                                    if (d != null && mounted) {
                                      setState(
                                        () => _expiry = DateTime(
                                          d.year,
                                          d.month,
                                          d.day,
                                          23,
                                          59,
                                          59,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              _expiry == null
                                  ? 'Set banner expiry (optional)'
                                  : 'Expires ${PlatformAdminService.date(_expiry!.toIso8601String())}',
                            ),
                          ),
                          if (_expiry != null)
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _expiry = null),
                              child: const Text('Clear expiry'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Notifications remain in the inbox until the user deletes them. Archiving removes the banner; it does not recall delivered notifications.',
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _publish,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(
                          _saving ? 'Publishing…' : 'Preview & publish',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BusinessTargets extends StatefulWidget {
  const _BusinessTargets({required this.selected});
  final Map<String, String> selected;
  @override
  State<_BusinessTargets> createState() => _BusinessTargetsState();
}

class _BusinessTargetsState extends State<_BusinessTargets> {
  late final Map<String, String> _selected = Map.of(widget.selected);
  List<AdminRow> _rows = [];
  int _page = 0, _request = 0;
  String _search = '';
  String? _error;
  bool _loading = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = PlatformAdminService.rows(
        await PlatformAdminService.query(
          'businesses',
          search: _search,
          offset: _page * 50,
        ),
      );
      if (mounted && request == _request) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = PlatformAdminService.error(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose businesses'),
    content: SizedBox(
      width: 600,
      height: MediaQuery.sizeOf(context).height * .55,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search business or email',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) {
              _search = v;
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 350), () {
                _page = 0;
                _load();
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const AdminLoading()
                : _error != null
                ? Text(_error!)
                : ListView(
                    children: [
                      for (final b in _rows.take(50))
                        CheckboxListTile(
                          value: _selected.containsKey('${b['id']}'),
                          title: Text(PlatformAdminService.name(b)),
                          subtitle: Text(
                            '${b['business_type']} · ${b['business_email'] ?? ''}',
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected['${b['id']}'] =
                                  PlatformAdminService.name(b);
                            } else {
                              _selected.remove('${b['id']}');
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          AdminPager(
            page: _page,
            more: _rows.length > 50,
            onPage: (v) {
              _page = v;
              _load();
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _selected),
        child: Text('Use ${_selected.length} businesses'),
      ),
    ],
  );
}
