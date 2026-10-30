import 'package:cutlink/shared/widgets/ios_dashboard_sections.dart';

void main() {
  void check(bool value, String message) {
    if (!value) {
      throw StateError(message);
    }
  }

  for (final supplier in [false, true]) {
    final defaults = IosDashboardSection.defaults(supplier);
    check(
      !defaults.firstWhere((s) => s.id == 'ios_analytics').visible,
      'Analytics must be optional by default',
    );
    final saved = [
      const IosDashboardSection('ios_analytics'),
      const IosDashboardSection('ios_metrics', visible: false),
      const IosDashboardSection('ios_analytics'),
      const IosDashboardSection('desktop_card'),
      IosDashboardSection(supplier ? 'ios_buy_again' : 'ios_work_orders'),
    ];
    final result = IosDashboardSection.normalise(supplier, saved);
    check(
      result.first.id == 'ios_analytics' && result.first.visible,
      'Saved order and enabled shortcut must survive reload',
    );
    check(!result[1].visible, 'Hidden sections must stay hidden');
    check(
      result.length == defaults.length,
      'Unknown and duplicate entries must be excluded',
    );
    check(
      result.map((s) => s.id).toSet().length == result.length,
      'No duplicated dashboard sections',
    );
    final reset = IosDashboardSection.normalise(supplier, null);
    check(
      reset.map((s) => s.id).join(',') == defaults.map((s) => s.id).join(','),
      'Reset must restore the approved layout',
    );
  }
}
