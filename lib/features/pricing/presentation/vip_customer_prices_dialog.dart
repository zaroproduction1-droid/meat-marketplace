import '../../../shared/widgets/customer_price_display.dart';
import '../../../shared/widgets/sharp_logo.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class VipCustomerPriceDraft {
  const VipCustomerPriceDraft({
    required this.amountText,
    required this.priceBasis,
    required this.minimumText,
  });

  final String amountText;
  final String priceBasis;
  final String minimumText;

  bool matches(VipCustomerPriceDraft other) {
    bool sameNumber(String a, String b) =>
        a.trim() == b.trim() ||
        (double.tryParse(a.trim()) != null &&
            double.tryParse(a.trim()) == double.tryParse(b.trim()));
    if (amountText.trim().isEmpty && other.amountText.trim().isEmpty) {
      return true;
    }
    return sameNumber(amountText, other.amountText) &&
        priceBasis == other.priceBasis &&
        sameNumber(minimumText, other.minimumText);
  }

  String? priceError() {
    final amount = double.tryParse(amountText.trim());
    return amount == null || !amount.isFinite || amount < 0
        ? 'Enter a valid price of 0 or more.'
        : null;
  }

  String? minimumError(bool catchWeight) {
    if (minimumText.trim().isEmpty) {
      return null;
    }
    final minimum = double.tryParse(minimumText.trim());
    if (minimum == null || !minimum.isFinite || minimum <= 0) {
      return 'Enter a minimum greater than 0.';
    }
    if (catchWeight && minimum != minimum.roundToDouble()) {
      return 'Use a whole number of cartons.';
    }
    return null;
  }
}

class VipCustomerPriceEntry {
  const VipCustomerPriceEntry({
    required this.customerId,
    required this.name,
    required this.saved,
    required this.initial,
    this.logoUrl,
  });

  final String customerId;
  final String name;
  final String? logoUrl;
  final VipCustomerPriceDraft saved;
  final VipCustomerPriceDraft initial;
}

/// Edits remain in the inventory page's shared queue, including after closing.
class VipCustomerPricesDialog extends StatefulWidget {
  const VipCustomerPricesDialog({
    super.key,
    required this.productName,
    required this.customers,
    required this.catchWeight,
    required this.onDraftChanged,
    required this.pendingCount,
    required this.onSaveAll,
    this.standardPrice,
  });

  final String productName;
  final Map<String, dynamic>? standardPrice;
  final List<VipCustomerPriceEntry> customers;
  final bool catchWeight;
  final void Function(String customerId, VipCustomerPriceDraft? draft)
  onDraftChanged;
  final int Function() pendingCount;
  final Future<bool> Function() onSaveAll;

  @override
  State<VipCustomerPricesDialog> createState() =>
      _VipCustomerPricesDialogState();
}

class _VipCustomerPricesDialogState extends State<VipCustomerPricesDialog> {
  static const _red = Color(0xFF741C1C);
  final _search = TextEditingController();
  final Map<String, TextEditingController> _amounts = {};
  final Map<String, TextEditingController> _minimums = {};
  final Map<String, FocusNode> _focus = {};
  final Map<String, String> _bases = {};
  final Map<String, VipCustomerPriceDraft> _saved = {};
  final Set<String> _expanded = {};
  bool _saving = false;
  bool _showErrors = false;
  bool _saveFailed = false;
  bool _saveSucceeded = false;

  @override
  void initState() {
    super.initState();
    for (final customer in widget.customers) {
      final id = customer.customerId;
      _amounts[id] = TextEditingController(text: customer.initial.amountText);
      _minimums[id] = TextEditingController(text: customer.initial.minimumText);
      _focus[id] = FocusNode();
      _bases[id] = customer.initial.priceBasis;
      _saved[id] = customer.saved;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in [..._amounts.values, ..._minimums.values]) {
      controller.dispose();
    }
    for (final focus in _focus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  VipCustomerPriceDraft _draft(String id) => VipCustomerPriceDraft(
    amountText: _amounts[id]!.text,
    priceBasis: widget.catchWeight ? 'kilogram' : _bases[id]!,
    minimumText: _minimums[id]!.text,
  );

  bool _dirty(String id) => !_draft(id).matches(_saved[id]!);

  void _changed(String id) {
    widget.onDraftChanged(id, _dirty(id) ? _draft(id) : null);
    setState(() {
      _saveFailed = false;
      _saveSucceeded = false;
    });
  }

  void _undo(String id) {
    final original = _saved[id]!;
    _amounts[id]!.text = original.amountText;
    _minimums[id]!.text = original.minimumText;
    _bases[id] = original.priceBasis;
    _changed(id);
  }

  Future<void> _saveAll() async {
    if (_saving || widget.pendingCount() == 0) {
      return;
    }
    for (final customer in widget.customers) {
      final id = customer.customerId;
      if (!_dirty(id)) {
        continue;
      }
      final draft = _draft(id);
      if (draft.priceError() != null ||
          draft.minimumError(widget.catchWeight) != null) {
        setState(() {
          _showErrors = true;
          // Bring an invalid draft into view even if the lazy list has not
          // built its row, or the customer is hidden by another search.
          _search.text = customer.name;
          if (draft.minimumError(widget.catchWeight) != null) {
            _expanded.add(id);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _focus[id]!.requestFocus();
          }
        });
        return;
      }
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _saveFailed = false;
      _saveSucceeded = false;
    });
    var saved = false;
    try {
      saved = await widget.onSaveAll();
    } catch (_) {
      // The inventory queue remains intact when a request fails.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = !saved;
      _saveSucceeded = saved;
      if (saved) {
        for (final customer in widget.customers) {
          _saved[customer.customerId] = _draft(customer.customerId);
        }
        _showErrors = false;
      }
    });
  }

  String _basisLabel(String value) => switch (value) {
    'kilogram' => 'kg',
    'carton' => 'carton',
    _ => 'unit',
  };

  Widget _logo(VipCustomerPriceEntry customer) {
    final initials = customer.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    final fallback = Center(
      child: Text(
        initials.isEmpty ? 'B' : initials,
        style: const TextStyle(
          color: _red,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Container(
      key: ValueKey('vip-logo-${customer.customerId}'),
      width: 80,
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: customer.logoUrl == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SharpLogo.network(
                customer.logoUrl!,
                semanticLabel: '${customer.name} logo',
                errorBuilder: (_, error, stack) => fallback,
              ),
            ),
    );
  }

  Widget _row(VipCustomerPriceEntry customer) {
    final id = customer.customerId;
    final dirty = _dirty(id);
    final draft = _draft(id);
    final expanded = _expanded.contains(id);
    return InkWell(
      onTap: _saving ? null : () => _focus[id]!.requestFocus(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dirty ? const Color(0xFFFCF7F7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dirty
                ? _red.withValues(alpha: .35)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final identity = Row(
                  children: [
                    _logo(customer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (draft.priceError() == null)
                            CustomerPriceDisplay(
                              fontSize: 16,
                              product: {
                                'product_prices': [
                                  if (widget.standardPrice != null)
                                    widget.standardPrice!,
                                ],
                              },
                              visiblePrice: {
                                'amount': double.tryParse(
                                  draft.amountText.trim(),
                                ),
                                'price_basis': draft.priceBasis,
                                'active': true,
                                'price_lists': {
                                  'active': true,
                                  'visibility': 'private',
                                },
                              },
                            ),
                          const SizedBox(height: 4),
                          Text(
                            dirty
                                ? 'Unsaved change'
                                : _saved[id]!.amountText.isEmpty
                                ? 'No individual VIP price'
                                : 'Current VIP price',
                            style: TextStyle(
                              fontSize: 12,
                              color: dirty ? _red : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final field = TextField(
                  key: ValueKey('vip-price-$id'),
                  controller: _amounts[id],
                  focusNode: _focus[id],
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _changed(id),
                  decoration: InputDecoration(
                    labelText: 'Price inc GST',
                    hintText: 'Enter price',
                    prefixText: '\$ ',
                    suffixText: '/ ${_basisLabel(draft.priceBasis)}',
                    errorText: _showErrors && dirty ? draft.priceError() : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: dirty ? _red : const Color(0xFFD1D5DB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _red, width: 2),
                    ),
                  ),
                );
                if (constraints.maxWidth < 590) {
                  return Column(
                    children: [identity, const SizedBox(height: 14), field],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 18),
                    SizedBox(width: 230, child: field),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: ValueKey('vip-options-$id'),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            expanded ? _expanded.remove(id) : _expanded.add(id);
                          }),
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: const Text('Order options'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (dirty)
                    TextButton(
                      onPressed: _saving ? null : () => _undo(id),
                      child: const Text('Undo'),
                    ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              if (!widget.catchWeight) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('vip-basis-$id-${_bases[id]}'),
                  initialValue: _bases[id],
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Price basis',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'kilogram',
                      child: Text('Per kilogram'),
                    ),
                    DropdownMenuItem(
                      value: 'carton',
                      child: Text('Per carton'),
                    ),
                    DropdownMenuItem(value: 'unit', child: Text('Per unit')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            _bases[id] = value;
                            _changed(id);
                          }
                        },
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: ValueKey('vip-minimum-$id'),
                controller: _minimums[id],
                enabled: !_saving,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !widget.catchWeight,
                ),
                onChanged: (_) => _changed(id),
                decoration: InputDecoration(
                  labelText: widget.catchWeight
                      ? 'Minimum cartons (optional)'
                      : 'Minimum quantity (optional)',
                  errorText: _showErrors && dirty
                      ? draft.minimumError(widget.catchWeight)
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final customers = widget.customers
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
    final count = widget.pendingCount();
    final media = MediaQuery.of(context);
    final availableHeight = math.max(
      220.0,
      media.size.height - media.viewInsets.bottom - 32,
    );
    final height = math.min(
      availableHeight,
      (280 + widget.customers.length * (media.size.width < 650 ? 210 : 140))
          .clamp(420, 760)
          .toDouble(),
    );
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: const Color(0xFFF9FAFB),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: SizedBox(
          width: 900,
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VIP customer prices',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('vip-close'),
                      tooltip: 'Close and keep queued changes',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: TextField(
                  key: const ValueKey('vip-customer-search'),
                  controller: _search,
                  enabled: !_saving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search butchers',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: customers.isEmpty
                    ? const Center(
                        child: Text('No butchers match your search.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: customers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _row(customers[index]),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_saveFailed)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Save failed. Your edits are kept. Check the queued prices and try again.',
                          style: TextStyle(color: _red),
                        ),
                      ),
                    if (_saveSucceeded)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'All price changes saved.',
                          style: TextStyle(
                            color: Color(0xFF21643D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      count == 0
                          ? 'Edit prices above, then save them together.'
                          : '$count price change${count == 1 ? '' : 's'} ready to save',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const ValueKey('vip-save-all'),
                      onPressed: _saving || count == 0 ? null : _saveAll,
                      style: FilledButton.styleFrom(
                        backgroundColor: _red,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? 'Saving…'
                            : 'Save all changes${count == 0 ? '' : ' ($count)'}',
                      ),
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
