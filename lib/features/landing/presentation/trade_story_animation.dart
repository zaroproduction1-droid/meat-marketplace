import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'public_page_palette.dart';

/// A labelled example of a delivery order, never a live customer record.
class TradeStoryAnimation extends StatefulWidget {
  const TradeStoryAnimation({super.key});
  @override
  State<TradeStoryAnimation> createState() => _TradeStoryAnimationState();
}

class _TradeStoryAnimationState extends State<TradeStoryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  bool _paused = false;
  bool _reduced = false;
  int? _selected;
  static const _steps = [
    (
      'Send order',
      'BUTCHER → SUPPLIER',
      'The butcher selects Scotch fillet, reviews the available price and sends an order for 2 pieces.',
      'Order request travels to the supplier',
      Icons.shopping_basket_outlined,
    ),
    (
      'Approve & prepare',
      'SUPPLIER → BUTCHER',
      'The supplier checks availability and accepts the order. It becomes a work order ready for picking.',
      'Approval returns to the butcher',
      Icons.task_alt_rounded,
    ),
    (
      'Pick & weigh',
      'AT THE SUPPLIER',
      'The supplier picks the 2 pieces and records their actual weight. The locked price stays at \$24 per kg.',
      'Actual weight recorded: 9.4 kg',
      Icons.scale_outlined,
    ),
    (
      'Create invoice',
      'SUPPLIER → BUTCHER',
      'The recorded weight produces a \$225.60 product value. The supplier creates the invoice; the goods are not dispatched yet.',
      'Invoice becomes available to the butcher',
      Icons.receipt_long_outlined,
    ),
    (
      'Dispatch delivery',
      'SUPPLIER → BUTCHER',
      'The supplier dispatches the prepared order with its packing list. The butcher can follow the delivery stage.',
      'Goods travel to the butcher shop',
      Icons.local_shipping_outlined,
    ),
    (
      'Complete & review',
      'AT THE BUTCHER',
      'Delivery is completed. Both businesses retain the order and invoice; the butcher can review the account and submit payment details.',
      'Delivered. Invoice remains in the account.',
      Icons.inventory_2_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      if (reduced) {
        _clock.stop();
      } else if (!_paused) {
        _clock.repeat();
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _choose(int stage) {
    _clock.stop();
    setState(() {
      _paused = true;
      _selected = stage;
      _clock.value = (stage + .9) / _steps.length;
    });
  }

  void _toggle() {
    if (_reduced) {
      return;
    }
    setState(() {
      _paused = !_paused;
      _selected = null;
    });
    if (_paused) {
      _clock.stop();
    } else {
      _clock.repeat();
    }
  }

  Widget _party(String title, IconData icon, bool active) => SizedBox(
    width: 74,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: _reduced
              ? Duration.zero
              : const Duration(milliseconds: 250),
          width: 58,
          height: 64,
          decoration: BoxDecoration(
            color: PublicPagePalette.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? PublicPagePalette.primary
                  : PublicPagePalette.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: active ? PublicPagePalette.primary : PublicPagePalette.muted,
            size: 30,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PublicPagePalette.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
  Widget _scene(int stage, double phase) {
    final moving = stage == 0 || stage == 1 || stage == 3 || stage == 4;
    final travel = Curves.easeInOutCubic.transform(
      ((phase - .15) / .65).clamp(0.0, 1.0),
    );
    final icon = _steps[stage].$5;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) {
            const left = 55.0;
            final right = box.maxWidth - 91;
            final x = stage == 0
                ? lerpDouble(left, right, travel)!
                : lerpDouble(right, left, travel)!;
            return Stack(
              children: [
                Positioned(
                  left: 35,
                  right: 35,
                  top: 31,
                  child: CustomPaint(
                    size: Size(box.maxWidth - 70, 2),
                    painter: _RoutePainter(forward: stage == 0, moving: moving),
                  ),
                ),
                // The labels determine the scene height, including larger text sizes.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _party(
                      'Butcher shop',
                      Icons.storefront_outlined,
                      stage == 0 || stage == 5,
                    ),
                    _party(
                      'Meat supplier',
                      Icons.warehouse_outlined,
                      stage >= 1 && stage <= 4,
                    ),
                  ],
                ),
                if (moving)
                  Positioned(
                    left: _reduced || _selected != null
                        ? (left + right) / 2
                        : x,
                    top: 13,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: PublicPagePalette.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 23),
                    ),
                  )
                else
                  Positioned(
                    left: (box.maxWidth - 76) / 2,
                    top: 4,
                    child: Container(
                      width: 76,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: PublicPagePalette.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PublicPagePalette.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stage == 2
                                ? Icons.scale_outlined
                                : Icons.task_alt_rounded,
                            color: PublicPagePalette.primary,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stage == 2
                                ? '${(_reduced || _selected != null ? 9.4 : 9.4 * travel).toStringAsFixed(1)} kg'
                                : 'Received',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: PublicPagePalette.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          _steps[stage].$4,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PublicPagePalette.muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _summary(int stage) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: PublicPagePalette.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PublicPagePalette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 18,
              color: PublicPagePalette.primary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'EXAMPLE ORDER · SCOTCH FILLET',
                style: TextStyle(
                  color: PublicPagePalette.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            const Text(
              '2 pieces',
              style: TextStyle(color: PublicPagePalette.text, fontSize: 12),
            ),
            const Text(
              '\$24/kg',
              style: TextStyle(color: PublicPagePalette.text, fontSize: 12),
            ),
            Text(
              stage >= 2 ? '9.4 kg actual' : 'Weight at picking',
              style: const TextStyle(
                color: PublicPagePalette.muted,
                fontSize: 12,
              ),
            ),
            Text(
              stage >= 3
                  ? '\$225.60 product value'
                  : 'Final value after weighing',
              style: const TextStyle(
                color: PublicPagePalette.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, child) {
      final position = _clock.value * _steps.length;
      final stage = _selected ?? position.floor().clamp(0, _steps.length - 1);
      final step = _steps[stage];
      return Container(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 18 : 26,
        ),
        decoration: BoxDecoration(
          color: PublicPagePalette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: PublicPagePalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ONE ORDER, FROM START TO FINISH',
                    style: TextStyle(
                      color: PublicPagePalette.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _reduced
                      ? 'Reduced motion: choose a step below'
                      : _paused
                      ? 'Play story'
                      : 'Pause story',
                  onPressed: _reduced ? null : _toggle,
                  icon: Icon(
                    _paused || _reduced
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: PublicPagePalette.muted,
                  ),
                ),
              ],
            ),
            const Text(
              'The butcher orders.\nThe supplier fulfils.',
              style: TextStyle(
                color: PublicPagePalette.text,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            _scene(stage, position - position.floor()),
            const SizedBox(height: 20),
            _summary(stage),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey(stage),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP ${stage + 1} OF ${_steps.length} · ${step.$2}',
                    style: const TextStyle(
                      color: PublicPagePalette.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.$1,
                    style: const TextStyle(
                      color: PublicPagePalette.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    step.$3,
                    style: const TextStyle(
                      color: PublicPagePalette.muted,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  OutlinedButton(
                    onPressed: () => _choose(i),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: i == stage
                          ? PublicPagePalette.primary
                          : PublicPagePalette.background,
                      foregroundColor: i == stage
                          ? Colors.white
                          : PublicPagePalette.muted,
                      side: BorderSide(
                        color: i == stage
                            ? PublicPagePalette.primary
                            : PublicPagePalette.border,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      '${i + 1}. ${_steps[i].$1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Illustrative delivery order. Product value excludes delivery and other adjustments. Pickup uses ready/collected stages. Payment remains subject to supplier confirmation.',
              style: TextStyle(
                color: PublicPagePalette.muted,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.forward, required this.moving});
  final bool forward;
  final bool moving;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PublicPagePalette.border
      ..strokeWidth = 2;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    if (moving) {
      final x = forward ? size.width * .72 : size.width * .28;
      final direction = forward ? -1 : 1;
      paint.color = PublicPagePalette.primary;
      canvas.drawLine(Offset(x, 0), Offset(x + direction * 6, -5), paint);
      canvas.drawLine(Offset(x, 0), Offset(x + direction * 6, 5), paint);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.forward != forward || old.moving != moving;
}
