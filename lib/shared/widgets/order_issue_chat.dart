import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One participant-scoped conversation; sending never changes a resolution.
class OrderIssueChat extends StatefulWidget {
  const OrderIssueChat({
    super.key,
    required this.issue,
    required this.businessId,
    required this.role,
    required this.orderReference,
    required this.otherParty,
  });
  final Map<String, dynamic> issue;
  final String businessId;
  final String role;
  final String orderReference;
  final String otherParty;

  @override
  State<OrderIssueChat> createState() => _OrderIssueChatState();
}

class _OrderIssueChatState extends State<OrderIssueChat> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  late Map<String, dynamic> _issue;
  bool _loading = true;
  bool _fetching = false;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _issue = Map<String, dynamic>.from(widget.issue);
    _reload();
    // Only this open conversation is refreshed. No global listeners.
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_fetching || _sending) return;
    _fetching = true;
    final follow =
        !_loading && _scroll.hasClients && _scroll.position.extentAfter < 100;
    try {
      final client = Supabase.instance.client;
      final values = await Future.wait<dynamic>([
        client
            .from('order_issue_messages')
            .select()
            .eq('order_issue_id', widget.issue['id'].toString())
            .order('created_at')
            .order('id'),
        client
            .from('order_issues')
            .select()
            .eq('id', widget.issue['id'].toString())
            .single(),
      ]).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final rows = (values[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      // An in-flight refresh must not discard a message just sent locally.
      final ids = rows.map((row) => row['id']).toSet();
      rows.addAll(_messages.where((row) => !ids.contains(row['id'])));
      rows.sort((a, b) {
        final byDate = a['created_at'].toString().compareTo(
          b['created_at'].toString(),
        );
        return byDate != 0
            ? byDate
            : a['id'].toString().compareTo(b['id'].toString());
      });
      final changed = rows.length != _messages.length;
      setState(() {
        _messages = rows;
        _issue = Map<String, dynamic>.from(values[1] as Map);
        _loading = false;
        _error = null;
      });
      if (follow && changed) _toLatest();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Messages could not refresh. Your draft is still here.';
        });
      }
    } finally {
      _fetching = false;
    }
  }

  void _toLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (_sending || body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('order_issue_messages')
          .insert({
            'order_issue_id': widget.issue['id'],
            'sender_business_id': widget.businessId,
            'sender_role': widget.role,
            'message': body,
          })
          .select()
          .single();
      if (!mounted) return;
      _text.clear();
      setState(() {
        if (!_messages.any((m) => m['id'] == row['id'])) {
          _messages.add(Map<String, dynamic>.from(row));
        }
        _sent = true;
      });
      _toLatest();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Message could not be sent. Your draft has been kept; check the conversation before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _bubble(Map<String, dynamic> message) {
    final own = message['sender_business_id'] == widget.businessId;
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .86,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: own ? const Color(0xFF111C27) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E3E5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${own ? 'You' : widget.otherParty} • ${_date(message['created_at'])}',
                style: TextStyle(
                  fontSize: 11,
                  color: own ? Colors.white70 : const Color(0xFF656970),
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                message['message']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: own ? Colors.white : const Color(0xFF20252B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_issue['status']?.toString()) {
      'approved' => 'Resolution proposed',
      'under_review' => 'Under review',
      'resolved' => 'Resolved',
      'rejected' => 'Declined',
      'cancelled' => 'Cancelled',
      _ => 'Awaiting supplier review',
    };
    return PopScope(
      canPop: !_sending,
      child: Dialog(
        backgroundColor: const Color(0xFFF7F8FA),
        insetPadding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 8 : 24,
        ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 820,
          height: 760,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                child: Row(
                  children: [
                    const Icon(Icons.forum_outlined, color: Color(0xFF741C1C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.otherParty,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.orderReference} • $status',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh conversation',
                      onPressed: _sending ? null : _reload,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Close conversation',
                      onPressed: _sending
                          ? null
                          : () => Navigator.pop(context, _sent),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4E9E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Original issue',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  _issue['description']?.toString() ?? '',
                                ),
                                if ((_issue['resolution_type']?.toString() ??
                                        '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Proposed outcome: ${_issue['resolution_type'].toString().replaceAll('_', ' ')}',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_messages.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Ask a question or share an update below.',
                              ),
                            ),
                          ..._messages.map(_bubble),
                        ],
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF9B2424)),
                  ),
                ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text(
                      'Messages do not approve, reject or close the issue.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF656970)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            enabled: !_sending,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Write a message…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send message',
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
