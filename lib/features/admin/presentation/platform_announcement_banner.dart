import 'announcement_style.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/platform_admin_service.dart';

/// One lightweight refresh per minute, with no unfiltered realtime listener.
class PlatformAnnouncementBanner extends StatefulWidget {
  const PlatformAnnouncementBanner({super.key, required this.businessId});
  final String businessId;
  @override
  State<PlatformAnnouncementBanner> createState() =>
      _PlatformAnnouncementBannerState();
}

class _PlatformAnnouncementBannerState extends State<PlatformAnnouncementBanner>
    with WidgetsBindingObserver {
  List<AdminRow> _rows = [];
  final Set<String> _dismissed = {};
  Timer? _timer;
  bool _fetching = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant PlatformAnnouncementBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _rows = [];
      _dismissed.clear();
      _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_fetching) {
      return;
    }
    _fetching = true;
    final id = widget.businessId;
    try {
      final rows = PlatformAdminService.rows(
        await Supabase.instance.client.rpc(
          'list_platform_banners',
          params: {'p_business_id': id},
        ),
      );
      if (mounted && id == widget.businessId) {
        setState(() => _rows = rows);
      }
    } catch (_) {
      /* Keep the workspace usable during a temporary connection issue. */
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows
        .where((r) => !_dismissed.contains('${r['id']}'))
        .toList();
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final row = rows.first;
    final tone = row['tone']?.toString() ?? 'normal';
    final foreground = AnnouncementStyle.foreground(tone);
    return Material(
      color: AnnouncementStyle.background(tone),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: Row(
              children: [
                Icon(AnnouncementStyle.icon(tone), color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('${row['title']}'),
                        content: SingleChildScrollView(
                          child: Text('${row['body']}'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${row['body']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          rows.length > 1
                              ? 'Read more · ${rows.length} notices'
                              : 'Read more',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss for this session',
                  onPressed: () =>
                      setState(() => _dismissed.add('${row['id']}')),
                  icon: Icon(Icons.close, size: 20, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
