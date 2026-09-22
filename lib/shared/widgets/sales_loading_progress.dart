import 'dart:async';
import 'package:flutter/material.dart';

/// Stage and stock progress come from completed requests, never a fake timer.
class SalesLoadingProgress extends StatefulWidget {
  const SalesLoadingProgress({
    super.key,
    required this.stage,
    required this.loaded,
    required this.total,
  });
  final int stage;
  final int loaded;
  final int? total;

  @override
  State<SalesLoadingProgress> createState() => _SalesLoadingProgressState();
}

class _SalesLoadingProgressState extends State<SalesLoadingProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _clock;
  int _seconds = 0;
  static const _red = Color(0xFF741C1C);
  static const _labels = ['Connect', 'Stock', 'Catalogue', 'Orders', 'Ready'];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _seconds++);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
      _pulse.value = 1;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.stage == 4;
    final stockProgress = widget.total == null
        ? null
        : widget.total! == 0
        ? 1.0
        : (widget.loaded / widget.total!).clamp(0.0, 1.0).toDouble();
    final messages = [
      'Connecting to your supplier account',
      widget.total == null
          ? 'Loading your stock and prices'
          : '${widget.loaded} of ${widget.total} products loaded',
      'Preparing animal cuts and filters',
      'Checking new marketplace orders',
      'Your sales workspace is ready',
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5DDDC)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: Tween<double>(begin: .55, end: 1).animate(_pulse),
                  child: Icon(
                    ready
                        ? Icons.check_circle_rounded
                        : Icons.inventory_2_outlined,
                    size: 54,
                    color: ready ? Colors.green.shade700 : _red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  ready ? 'Ready to sell' : 'Preparing your sales workspace',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    messages[widget.stage],
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 18),
                if (widget.stage == 1 && stockProgress != null)
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: stockProgress),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 350),
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      color: _red,
                      backgroundColor: const Color(0xFFF1E8E7),
                    ),
                  )
                else
                  LinearProgressIndicator(
                    value: ready ? 1 : null,
                    minHeight: 8,
                    color: _red,
                    backgroundColor: const Color(0xFFF1E8E7),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < _labels.length; i++)
                      Chip(
                        avatar: Icon(
                          i < widget.stage || ready
                              ? Icons.check
                              : Icons.circle,
                          size: 14,
                          color: i <= widget.stage ? _red : Colors.grey,
                        ),
                        label: Text(_labels[i]),
                        backgroundColor: i == widget.stage
                            ? const Color(0xFFF1E8E7)
                            : Colors.white,
                      ),
                  ],
                ),
                if (!ready) ...[
                  const SizedBox(height: 12),
                  Text(
                    _seconds >= 15
                        ? 'Large stock lists can take longer. Progress updates as each batch arrives. ${_seconds}s elapsed.'
                        : 'Loading your latest stock and pricing...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
