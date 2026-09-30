import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../landing/presentation/featured_businesses_section.dart';

class AdminFeaturedBusinessesPanel extends StatefulWidget {
  const AdminFeaturedBusinessesPanel({super.key});
  @override
  State<AdminFeaturedBusinessesPanel> createState() =>
      _AdminFeaturedBusinessesPanelState();
}

class _AdminFeaturedBusinessesPanelState
    extends State<AdminFeaturedBusinessesPanel> {
  List<Map<String, dynamic>> _slots = [], _businesses = [];
  bool _loading = true, _saving = false;
  String? _error;
  String _search = '';
  Timer? _timer;
  int _request = 0;
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
      final data = Map<String, dynamic>.from(
        await Supabase.instance.client.rpc(
              'cutlink_admin_featured_list',
              params: {'p_search': _search},
            )
            as Map,
      );
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _slots = (data['slots'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _businesses = (data['businesses'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = 'Could not load featured businesses. Please retry.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save(String role, int slot, String? id) async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc(
        'cutlink_admin_featured_set',
        params: {'p_type': role, 'p_slot': slot, 'p_business_id': id},
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Front page selection saved.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PostgrestException
                  ? e.message
                  : 'Could not save. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Choose who appears on the front page',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Choose up to five suppliers and five butchers. Changes publish immediately. Only approved, active businesses with a logo can be selected. Selecting an existing business moves it to the chosen position. Totals count all registered businesses.',
      ),
      const SizedBox(height: 18),
      TextField(
        enabled: !_saving,
        decoration: const InputDecoration(
          labelText: 'Search businesses by name',
          prefixIcon: Icon(Icons.search),
          helperText: 'Search narrows the choices below (up to 100 matches).',
        ),
        onChanged: (value) {
          _search = value;
          _timer?.cancel();
          _timer = Timer(const Duration(milliseconds: 350), _load);
        },
      ),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) ...[
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
      for (final role in ['supplier', 'butcher']) ...[
        const SizedBox(height: 24),
        Text(
          role == 'supplier'
              ? 'Suppliers — five positions'
              : 'Butchers — five positions',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        for (var slot = 1; slot <= 5; slot++) _slot(role, slot),
      ],
    ],
  );
  Widget _slot(String role, int slot) {
    final matches = _slots.where(
      (r) => r['business_type'] == role && r['slot'] == slot,
    );
    final selected = matches.isEmpty ? null : matches.first;
    final options = <String, Map<String, dynamic>>{
      for (final b in _businesses.where((b) => b['business_type'] == role))
        b['id'] as String: b,
    };
    if (selected != null) {
      options[selected['id'] as String] = selected;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position $slot',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (selected != null) ...[
              Row(
                children: [
                  BusinessDisplayLogo(
                    path: selected['logo_path'] as String?,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${selected['name']}${selected['eligible'] == false ? ' (hidden — account is not eligible)' : ''}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              key: ValueKey('$role-$slot-${selected?['id']}-$_request'),
              initialValue: selected?['id'] as String? ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Business to display',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Empty — do not show a business'),
                ),
                for (final b in options.values)
                  DropdownMenuItem(
                    value: b['id'] as String,
                    enabled: (b['logo_path'] as String? ?? '').isNotEmpty,
                    child: Text(
                      '${b['name']}${(b['logo_path'] as String? ?? '').isEmpty ? ' — needs a logo' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving || _loading || _error != null
                  ? null
                  : (value) => _save(role, slot, value == '' ? null : value),
            ),
          ],
        ),
      ),
    );
  }
}
