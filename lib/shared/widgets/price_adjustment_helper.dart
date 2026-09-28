import 'package:flutter/material.dart';

/// Calculates a fixed price; it does not create an ongoing discount rule.
class PriceAdjustmentHelper extends StatefulWidget {
  const PriceAdjustmentHelper({
    super.key,
    required this.standardPrice,
    required this.amountController,
  });
  final double standardPrice;
  final TextEditingController amountController;
  @override
  State<PriceAdjustmentHelper> createState() => _PriceAdjustmentHelperState();
}

class _PriceAdjustmentHelperState extends State<PriceAdjustmentHelper> {
  final _discount = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Standard price: \$${widget.standardPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Discount from Standard',
                  suffixText: '%',
                  errorText: _error,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                final discount = double.tryParse(_discount.text);
                if (discount == null ||
                    !discount.isFinite ||
                    discount < 0 ||
                    discount > 100) {
                  setState(() => _error = 'Enter 0–100');
                  return;
                }
                setState(() => _error = null);
                widget.amountController.text =
                    (widget.standardPrice * (1 - discount / 100))
                        .toStringAsFixed(2);
              },
              child: const Text('Calculate'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Creates a fixed price below. Later Standard price changes will not change it.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
