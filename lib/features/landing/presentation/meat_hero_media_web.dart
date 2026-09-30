import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class MeatHeroMedia extends StatefulWidget {
  const MeatHeroMedia({super.key});
  @override
  State<MeatHeroMedia> createState() => _MeatHeroMediaState();
}

class _MeatHeroMediaState extends State<MeatHeroMedia> {
  web.HTMLVideoElement? _video;
  bool _playing = true;
  bool _reduce = false;
  String _url(String name) => Uri.parse(
    web.document.baseURI,
  ).resolve('assets/assets/images/$name').toString();
  void _sync() {
    final video = _video;
    if (video == null) {
      return;
    }
    if (_playing && !_reduce) {
      video.play().toDart.ignore();
    } else {
      video.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void dispose() {
    _video?.pause();
    _video?.removeAttribute('src');
    _video?.load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/cutlink_hero_poster.webp', fit: BoxFit.cover),
      HtmlElementView.fromTagName(
        tagName: 'video',
        onElementCreated: (Object element) {
          final video = element as web.HTMLVideoElement;
          _video = video;
          video
            ..src = _url('cutlink_hero.mp4')
            ..poster = _url('cutlink_hero_poster.webp')
            ..muted = true
            ..loop = true
            ..autoplay = !_reduce
            ..preload = 'metadata';
          video.setAttribute('playsinline', '');
          video.setAttribute(
            'aria-label',
            'Fresh beef, lamb and chicken on a butcher workbench',
          );
          video.style
            ..width = '100%'
            ..height = '100%'
            ..objectFit = 'cover'
            ..pointerEvents = 'none';
          _sync();
        },
      ),
      const Positioned(
        left: 18,
        top: 18,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xBB10191F),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'THE TRADE, CONNECTED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 12,
        bottom: 12,
        child: IconButton.filled(
          tooltip: _playing && !_reduce ? 'Pause animation' : 'Play animation',
          onPressed: () {
            setState(() {
              _playing = !(_playing && !_reduce);
              _reduce = false;
            });
            _sync();
          },
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xCC10191F),
            foregroundColor: Colors.white,
          ),
          icon: Icon(
            _playing && !_reduce
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
          ),
        ),
      ),
    ],
  );
}
