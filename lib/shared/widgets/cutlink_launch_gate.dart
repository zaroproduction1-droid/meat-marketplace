import 'dart:async';

import 'launch_page_ready.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

/// Runs startup once while the iPhone launch animation is visible. The normal
/// application mounts as soon as startup succeeds, underneath the fading cover.
class CutLinkLaunchGate extends StatefulWidget {
  const CutLinkLaunchGate({
    super.key,
    required this.initialise,
    required this.child,
    this.waitForFirstPage = false,
  });
  final Future<void> Function() initialise;
  final Widget child;
  final bool waitForFirstPage;

  @override
  State<CutLinkLaunchGate> createState() => _CutLinkLaunchGateState();
}

class _CutLinkLaunchGateState extends State<CutLinkLaunchGate>
    with TickerProviderStateMixin {
  late final AnimationController _animation;
  late final AnimationController _ambient;
  bool _ready = false;
  bool _pageReady = false;
  bool _failed = false;
  bool _running = false;
  bool _covered = true;
  bool _leaving = false;
  bool _motionConfigured = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1100),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (!_reduceMotion && !_failed) {
              _ambient.repeat(reverse: true);
            }
            _reveal();
          }
        });
    unawaited(_start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_motionConfigured || reduceMotion != _reduceMotion) {
      _motionConfigured = true;
      _reduceMotion = reduceMotion;
      if (reduceMotion) {
        _ambient.stop();
        _animation.value = 1;
      } else if (!_animation.isCompleted) {
        _animation.forward();
      }
    }
  }

  Future<void> _start() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      await widget.initialise();
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
        _failed = false;
      });
      _reveal();
    } catch (_) {
      if (mounted) {
        _ambient.stop();
        setState(() => _failed = true);
      }
    } finally {
      _running = false;
    }
  }

  void _reveal() {
    if (!mounted ||
        !_ready ||
        (widget.waitForFirstPage && !_pageReady) ||
        !_animation.isCompleted ||
        _leaving) {
      return;
    }
    // Paint the ready app behind the cover first, preserving its state while
    // the cover fades; no second startup, route replacement or duplicate login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_leaving) {
        _ambient.stop();
        setState(() {
          _leaving = true;
          if (_reduceMotion) {
            _covered = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _ambient.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_ready)
          ExcludeSemantics(
            excluding: _covered,
            child: IgnorePointer(
              ignoring: _covered,
              child: LaunchPageReady(
                onReady: () {
                  if (!mounted || _pageReady) {
                    return;
                  }
                  setState(() => _pageReady = true);
                  _reveal();
                },
                child: widget.child,
              ),
            ),
          ),
        if (_covered)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _leaving ? 0 : 1,
              duration: Duration(milliseconds: _reduceMotion ? 0 : 180),
              onEnd: () {
                // A zero-duration transition may complete during widget
                // updates. Remove the cover only after that frame is built.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_leaving && mounted && _covered) {
                    setState(() => _covered = false);
                  }
                });
              },
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                child: Theme(
                  data: ThemeData.dark(),
                  child: Material(
                    key: const ValueKey('cutlink-launch-cover'),
                    color: const Color(0xFF171719),
                    child: SafeArea(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_animation, _ambient]),
                        builder: (context, _) {
                          final t = Curves.easeOutCubic.transform(
                            _animation.value,
                          );
                          final word = _reduceMotion
                              ? 1.0
                              : Curves.easeInOutCubic.transform(
                                  ((_animation.value - .28) / .52)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                                );
                          return Column(
                            children: [
                              const Spacer(),
                              Semantics(
                                label: 'CutLink is starting',
                                image: true,
                                child: ExcludeSemantics(
                                  child: SizedBox(
                                    width: 340,
                                    height: 150,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          width: 145,
                                          height: 145,
                                          child: Transform.translate(
                                            offset: Offset(
                                              97.5 * (1 - word),
                                              8 * (1 - t),
                                            ),
                                            child: Transform.scale(
                                              scale:
                                                  (.88 + .12 * t) *
                                                  (_animation.isCompleted &&
                                                          !_reduceMotion
                                                      ? .985 +
                                                            .015 *
                                                                _ambient.value
                                                      : 1),
                                              child: Opacity(
                                                opacity: t,
                                                child: ShaderMask(
                                                  blendMode: BlendMode.srcIn,
                                                  shaderCallback: (bounds) =>
                                                      const LinearGradient(
                                                        begin:
                                                            Alignment.topRight,
                                                        end: Alignment
                                                            .bottomLeft,
                                                        colors: [
                                                          Color(0xFFFF4665),
                                                          Color(0xFFE71940),
                                                          Color(0xFFAC1533),
                                                        ],
                                                      ).createShader(bounds),
                                                  child: Image.asset(
                                                    'assets/images/CutLink-Launch-Symbol.png',
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.high,
                                                    excludeFromSemantics: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 138,
                                          right: 0,
                                          top: 43,
                                          child: Opacity(
                                            opacity: word,
                                            child: Transform.translate(
                                              offset: Offset(
                                                12 * (1 - word),
                                                0,
                                              ),
                                              child: const FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'CutLink',
                                                  style: TextStyle(
                                                    fontSize: 40,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -1,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 140,
                                          right: 30,
                                          bottom: 20,
                                          child: Opacity(
                                            opacity: word,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: FractionallySizedBox(
                                                widthFactor: word,
                                                child: Container(
                                                  height: 2,
                                                  color: const Color(
                                                    0xFFE71940,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_failed) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'CutLink could not start. Check your connection and try again.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _failed = false);
                                    unawaited(_start());
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Try again'),
                                ),
                              ] else if (_animation.isCompleted &&
                                  (!_ready ||
                                      (widget.waitForFirstPage && !_pageReady)))
                                Semantics(
                                  label: 'Finishing startup',
                                  liveRegion: true,
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 28),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
