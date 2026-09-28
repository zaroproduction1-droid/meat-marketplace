import 'package:flutter/material.dart';

class AnnouncementStyle {
  static const labels = {
    'normal': 'White · General message',
    'good_news': 'Green · Good news',
    'issue': 'Red · Issue / alert',
  };
  static Color background(String tone) => switch (tone) {
    'good_news' => const Color(0xFF197A48),
    'issue' => const Color(0xFF8B1E2D),
    _ => Colors.white,
  };
  static Color foreground(String tone) => tone == 'good_news' || tone == 'issue'
      ? Colors.white
      : const Color(0xFF101D2B);
  static IconData icon(String tone) => switch (tone) {
    'good_news' => Icons.check_circle_outline,
    'issue' => Icons.warning_amber_rounded,
    _ => Icons.campaign_outlined,
  };
}
