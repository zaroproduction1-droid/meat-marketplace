import '../theme/cutlink_appearance.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import '../drafts/local_draft_store.dart';

class LocalDraftRecovery extends StatefulWidget {
  const LocalDraftRecovery({
    super.key,
    required this.scope,
    required this.controllers,
    required this.values,
    required this.restoreValues,
    required this.child,
    required this.isBusy,
    required this.isCurrentUser,
    this.expand = true,
  });
  final String scope;
  final Map<String, TextEditingController> controllers;
  final Map<String, dynamic> Function() values;
  final Future<void> Function(Map<String, dynamic>) restoreValues;
  final bool Function() isBusy;
  final bool Function() isCurrentUser;
  final Widget child;
  final bool expand;
  @override
  State<LocalDraftRecovery> createState() => LocalDraftRecoveryState();
}

class LocalDraftRecoveryState extends State<LocalDraftRecovery> {
  bool get restoring => _restoring;
  bool get awaitingDecision => _pending != null;
  Map<String, dynamic>? _pending;
  late String _baseline;
  String? _lastWritten;
  bool _ready = false;
  bool _restoring = false;
  bool _stopped = false;
  String? _status;

  Map<String, dynamic> _capture() => {
    'text': widget.controllers.map(
      (key, controller) => MapEntry(key, controller.text),
    ),
    'values': widget.values(),
  };
  @override
  void initState() {
    super.initState();
    _baseline = jsonEncode(_capture());
    for (final c in widget.controllers.values) {
      c.addListener(_changed);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final draft = await LocalDraftStore.read(widget.scope);
      if (!mounted || !widget.isCurrentUser() || _stopped) {
        return;
      }
      setState(() {
        _pending = draft != null && jsonEncode(draft) != jsonEncode(_capture())
            ? draft
            : null;
        _ready = true;
      });
      if (draft == null) {
        _changed();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = true;
          _status = 'Draft recovery is unavailable on this device.';
        });
      }
    }
  }

  @override
  void didUpdateWidget(LocalDraftRecovery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Page controllers are stable; changing a product selection rebuilds this widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _changed();
      }
    });
  }

  void _changed() {
    if (!_ready ||
        _restoring ||
        _stopped ||
        _pending != null ||
        !widget.isCurrentUser() ||
        widget.isBusy()) {
      return;
    }
    final data = _capture();
    final encoded = jsonEncode(data);
    if (encoded == _baseline) {
      if (_lastWritten != null) {
        _lastWritten = null;
        LocalDraftStore.clear(widget.scope).catchError((Object _) {});
      }
      return;
    }
    if (encoded == _lastWritten) {
      return;
    }
    _lastWritten = encoded;
    LocalDraftStore.write(widget.scope, data)
        .then((_) {
          if (mounted &&
              !_stopped &&
              _lastWritten == encoded &&
              _status != 'Draft saved on this device.') {
            setState(() => _status = 'Draft saved on this device.');
          }
        })
        .catchError((Object _) {
          _lastWritten = null;
          if (mounted && !_stopped) {
            setState(
              () => _status =
                  'Draft could not be backed up. Keep this page open.',
            );
          }
        });
  }

  /// Stop new backups before removing the stored draft after a committed save.
  Future<void> clearDraft({bool stop = true}) async {
    _stopped = stop;
    _pending = null;
    _baseline = jsonEncode(_capture());
    _lastWritten = null;
    await LocalDraftStore.clear(widget.scope);
    if (mounted) {
      setState(() => _status = null);
    }
  }

  Future<void> _restore() async {
    final draft = _pending;
    if (draft == null || widget.isBusy() || !widget.isCurrentUser()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _restoring = true);
    try {
      await widget.restoreValues(
        Map<String, dynamic>.from(draft['values'] as Map),
      );
      if (!mounted || !widget.isCurrentUser()) {
        return;
      }
      final text = Map<String, dynamic>.from(draft['text'] as Map);
      for (final entry in widget.controllers.entries) {
        final value = text[entry.key];
        if (value is String) {
          entry.value.text = value;
        }
      }
      setState(() {
        _pending = null;
        _restoring = false;
        _status =
            'Draft restored. Review it before saving. Select images and attachments again.';
      });
      _changed();
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _status =
              'Could not restore selections. Reconnect and try again, or discard this draft.';
        });
      }
    }
  }

  Future<void> _discard() async {
    try {
      await clearDraft(stop: false);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _status = 'Could not discard the stored draft. Please try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in widget.controllers.values) {
      c.removeListener(_changed);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Column(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pending != null || _status != null)
          Material(
            color: CutLinkPalette.color(0xFFF0F3F7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _pending != null
                        ? (_status ??
                              'An unsaved draft is available on this device.')
                        : _status!,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (_pending != null) ...[
                    TextButton(
                      onPressed: _restoring || widget.isBusy()
                          ? null
                          : _restore,
                      child: Text(_restoring ? 'Restoring…' : 'Restore draft'),
                    ),
                    TextButton(
                      onPressed: _restoring || widget.isBusy()
                          ? null
                          : _discard,
                      child: const Text('Discard'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (widget.expand)
          Expanded(
            child: AbsorbPointer(absorbing: _restoring, child: widget.child),
          )
        else
          AbsorbPointer(absorbing: _restoring, child: widget.child),
      ],
    );
  }
}
