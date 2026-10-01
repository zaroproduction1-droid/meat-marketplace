import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class CutLinkExplainerVideo extends StatefulWidget {
  const CutLinkExplainerVideo({super.key});

  @override
  State<CutLinkExplainerVideo> createState() => _CutLinkExplainerVideoState();
}

class _CutLinkExplainerVideoState extends State<CutLinkExplainerVideo> {
  web.HTMLVideoElement? _video;
  final List<({web.EventTarget target, String type, JSFunction listener})>
  _listeners = [];

  String _url(String name) => Uri.parse(
    web.document.baseURI,
  ).resolve('assets/assets/images/$name').toString();

  void _listen(
    web.EventTarget target,
    String type,
    void Function(web.Event) callback,
  ) {
    final listener = callback.toJS;
    target.addEventListener(type, listener);
    _listeners.add((target: target, type: type, listener: listener));
  }

  void _create(Object element) {
    final root = element as web.HTMLDivElement;
    root.style.cssText =
        'position:relative;width:100%;height:100%;background:#202830;';
    final video = web.HTMLVideoElement()
      ..src = _url('cutlink_explainer.mp4')
      ..poster = _url('cutlink_explainer_poster.jpg')
      ..controls = true
      ..autoplay = false
      ..loop = false
      ..muted = false
      ..preload = 'metadata'
      ..setAttribute('playsinline', '')
      ..setAttribute(
        'aria-label',
        'CutLink: connecting suppliers and butchers. 80 second film.',
      );
    video.style.cssText =
        'display:block;width:100%;height:100%;object-fit:contain;';
    _video = video;

    final play = web.HTMLButtonElement()
      ..type = 'button'
      ..textContent = '▶  Watch the film'
      ..setAttribute('aria-label', 'Play the CutLink film with sound');
    play.style.cssText =
        'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);'
        'border:1px solid #ffffff55;border-radius:100px;background:#933744;color:white;'
        'padding:16px 24px;font:700 clamp(13px,2vw,18px) system-ui;white-space:nowrap;'
        'cursor:pointer;box-shadow:0 8px 30px #0005;';
    final status = web.HTMLParagraphElement()
      ..setAttribute('role', 'status')
      ..setAttribute('aria-live', 'polite');
    status.style.cssText =
        'position:absolute;bottom:44px;left:12px;right:12px;'
        'margin:0;color:white;text-align:center;font:14px system-ui;background:#202830;';

    _listen(play, 'click', (_) {
      status.textContent = '';
      play.setAttribute('hidden', '');
      // Invoked in the browser click event: sound is authorised by the gesture.
      video
          .play()
          .toDart
          .then<void>(
            (_) {},
            onError: (Object error) {
              if (mounted) {
                play.removeAttribute('hidden');
                status.textContent =
                    'Playback did not start. Please try again.';
              }
            },
          )
          .ignore();
    });
    _listen(video, 'playing', (_) {
      play.setAttribute('hidden', '');
      status.textContent = '';
    });
    _listen(video, 'ended', (_) {
      play.textContent = '▶  Watch again';
      play.removeAttribute('hidden');
    });
    _listen(video, 'error', (_) {
      play.removeAttribute('hidden');
      status.textContent =
          'The film could not load. Please refresh and try again.';
    });
    root.appendChild(video);
    root.appendChild(play);
    root.appendChild(status);
  }

  @override
  void dispose() {
    for (final entry in _listeners) {
      entry.target.removeEventListener(entry.type, entry.listener);
    }
    _listeners.clear();
    final video = _video;
    if (video != null) {
      video.pause();
      video.removeAttribute('src');
      video.load();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HtmlElementView.fromTagName(tagName: 'div', onElementCreated: _create);
}
