import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supplier_photo_policy.dart';

final _supplierPhotoTermsRevision = ValueNotifier<int>(0);

Future<bool> ensureSupplierPhotoTerms(
  BuildContext context, {
  bool viewOnly = false,
}) async {
  final client = Supabase.instance.client;
  final status = Map<String, dynamic>.from(
    await client.rpc('supplier_photo_terms_status') as Map,
  );
  final accepted = status['accepted'] == true;
  if (accepted && !viewOnly) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (_) => _SupplierTermsDialog(accepted: accepted),
      ) ??
      false;
}

class _SupplierTermsDialog extends StatefulWidget {
  const _SupplierTermsDialog({required this.accepted});
  final bool accepted;
  @override
  State<_SupplierTermsDialog> createState() => _SupplierTermsDialogState();
}

class _SupplierTermsDialogState extends State<_SupplierTermsDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'accept_supplier_photo_terms',
        params: {'p_terms_version': SupplierPhotoPolicy.version},
      );
      _supplierPhotoTermsRevision.value++;
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The agreement could not be saved. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Supplier photo terms'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.accepted
                  ? 'You have accepted these terms.'
                  : 'Accept once for this supplier login account. You will not be asked for each photo.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const SelectableText(SupplierPhotoPolicy.terms),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving
            ? null
            : () => Navigator.pop(context, widget.accepted),
        child: Text(widget.accepted ? 'Close' : 'Not now'),
      ),
      if (!widget.accepted)
        FilledButton(
          onPressed: _saving ? null : _accept,
          child: Text(
            _saving ? 'Saving…' : 'I agree to the supplier photo terms',
          ),
        ),
    ],
  );
}

class SupplierPhotoTermsNotice extends StatefulWidget {
  const SupplierPhotoTermsNotice({super.key});
  @override
  State<SupplierPhotoTermsNotice> createState() =>
      _SupplierPhotoTermsNoticeState();
}

class _SupplierPhotoTermsNoticeState extends State<SupplierPhotoTermsNotice> {
  bool? _accepted;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _supplierPhotoTermsRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _supplierPhotoTermsRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await Supabase.instance.client.rpc(
        'supplier_photo_terms_status',
      );
      if (mounted) {
        setState(() => _accepted = (status as Map)['accepted'] == true);
      }
    } catch (_) {
      /* The reminder remains visible; Review terms can retry. */
    }
  }

  Future<void> _review() async {
    setState(() => _busy = true);
    try {
      if (await ensureSupplierPhotoTerms(context, viewOnly: true) && mounted) {
        setState(() => _accepted = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terms could not be loaded. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F2ED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE7D9D0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.copyright_outlined,
            size: 19,
            color: Color(0xFF741C1C),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product photos',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const Text(
                'Only upload photos you own or have permission to use. You are responsible for their accuracy and permissions.',
                style: TextStyle(fontSize: 12),
              ),
              if (_accepted == false)
                const Text(
                  'Accept the supplier photo terms once to enable uploads.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF741C1C)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: _busy ? null : _review,
          child: Text(
            _busy
                ? 'Loading…'
                : _accepted == true
                ? 'Terms'
                : 'Review terms',
          ),
        ),
      ],
    ),
  );
}
