import '../../../shared/theme/cutlink_appearance.dart';
import '../../../shared/widgets/ios_density.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/ios_workspace.dart';

import '../../../shared/widgets/cutlink_workspace_theme.dart';

/// Admin-only presentation layer; shared supplier/butcher styling is untouched.
class AdminTheme extends StatelessWidget {
  const AdminTheme({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  static Color get ink => CutLinkPalette.color(0xFF172638);
  static Color get muted => CutLinkPalette.color(0xFF647386);
  static Color get canvas => CutLinkPalette.color(0xFFF3F5F8);
  static const accent = Color(0xFF741C1C);
  static Color get line => CutLinkPalette.color(0xFFE3E8EF);
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return CutLinkWorkspaceTheme(
      child: Builder(
        builder: (context) {
          if (!enabled) {
            return child;
          }
          final base = Theme.of(context);
          if (useIosWorkspace(context)) {
            return Theme(data: IosWorkspaceStyle.theme(base), child: child);
          }
          return Theme(
            data: base.copyWith(
              scaffoldBackgroundColor: canvas,
              dividerColor: line,
              textTheme: base.textTheme
                  .apply(bodyColor: ink, displayColor: ink)
                  .copyWith(
                    bodyMedium: base.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.4,
                      color: ink,
                    ),
                    bodySmall: base.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.4,
                      color: muted,
                    ),
                    titleLarge: base.textTheme.titleLarge?.copyWith(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
              cardTheme: CardThemeData(
                color: CutLinkPalette.surface,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: line),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: CutLinkPalette.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                titleTextStyle: TextStyle(
                  color: ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              listTileTheme: ListTileThemeData(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                iconColor: muted,
                titleTextStyle: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                subtitleTextStyle: TextStyle(
                  color: muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              chipTheme: base.chipTheme.copyWith(
                backgroundColor: CutLinkPalette.surface,
                selectedColor: CutLinkPalette.color(0xFFF3E7E8),
                side: BorderSide(color: line),
                labelStyle: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              appBarTheme: base.appBarTheme.copyWith(
                toolbarHeight: 64,
                titleSpacing: 8,
              ),
              inputDecorationTheme: base.inputDecorationTheme.copyWith(
                fillColor: CutLinkPalette.color(0xFFFAFBFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                labelStyle: TextStyle(color: muted, fontSize: 13),
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class AdminNavigation extends StatelessWidget {
  const AdminNavigation({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.child,
  });
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final Widget child;
  static IconData icon(String key) => switch (key) {
    'homepage' => Icons.home_outlined,
    'overview' => Icons.space_dashboard_outlined,
    'analytics' => Icons.insights_outlined,
    'businesses' => Icons.business_outlined,
    'billing' || 'accounts' => Icons.account_balance_wallet_outlined,
    'invoices' => Icons.receipt_long_outlined,
    'announcements' => Icons.campaign_outlined,
    'audit' => Icons.history_rounded,
    'support' => Icons.support_agent,
    _ => Icons.tune_rounded,
  };
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return LayoutBuilder(
      builder: (context, c) {
        if (useIosWorkspace(context)) {
          final selected = switch (value) {
            'overview' => 0,
            'businesses' => 1,
            'billing' => 3,
            _ => 4,
          };
          return Column(
            children: [
              Expanded(child: child),
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                IosBottomBar(
                  index: selected,
                  tabs: const [
                    IosTab('Home', Icons.home_outlined),
                    IosTab('Businesses', Icons.business_outlined),
                    IosTab('Reports', Icons.flag_outlined),
                    IosTab('Billing', Icons.account_balance_wallet_outlined),
                    IosTab('More', Icons.person_outline_rounded),
                  ],
                  onSelected: (index) {
                    if (index < 4) {
                      onChanged(
                        ['overview', 'businesses', 'support', 'billing'][index],
                      );
                      return;
                    }
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (sheetContext) => SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Admin tools',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const IosGap(height: 12),
                              for (final entry in items.entries)
                                IosMenuRow(
                                  link: IosMenuLink(
                                    entry.value,
                                    icon(entry.key),
                                    () {
                                      Navigator.pop(sheetContext);
                                      onChanged(entry.key);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        }
        if (c.maxWidth < 1050) {
          return Column(
            children: [
              IosPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: c.maxWidth < 600
                    ? DropdownButtonFormField<String>(
                        key: ValueKey(value),
                        initialValue: value,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Admin section',
                        ),
                        items: [
                          for (final entry in items.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Row(
                                children: [
                                  Icon(icon(entry.key), size: 18),
                                  const SizedBox(width: 10),
                                  Text(entry.value),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (section) {
                          if (section != null) {
                            onChanged(section);
                          }
                        },
                      )
                    : Wrap(
                        spacing: 4,
                        runSpacing: 6,
                        children: [
                          for (final entry in items.entries)
                            IosPadding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: Icon(icon(entry.key), size: 17),
                                label: Text(entry.value),
                                selected: value == entry.key,
                                onSelected: (_) => onChanged(entry.key),
                              ),
                            ),
                        ],
                      ),
              ),
              Expanded(child: child),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 214,
              decoration: BoxDecoration(
                color: CutLinkPalette.surface,
                border: Border(right: BorderSide(color: AdminTheme.line)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  IosPadding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 18),
                    child: Text(
                      'ADMIN WORKSPACE',
                      style: TextStyle(
                        color: AdminTheme.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final entry in items.entries)
                    IosPadding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Material(
                        color: value == entry.key
                            ? CutLinkPalette.color(0xFFF4E8E9)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Icon(
                            icon(entry.key),
                            size: 20,
                            color: value == entry.key
                                ? AdminTheme.accent
                                : AdminTheme.muted,
                          ),
                          horizontalTitleGap: 10,
                          title: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: value == entry.key
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          onTap: () => onChanged(entry.key),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class AdminStatTile extends StatelessWidget {
  const AdminStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.note,
    this.onTap,
  });
  final String label, value;
  final String? note;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: IosPadding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CutLinkPalette.color(0xFFF4E8E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: AdminTheme.accent),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.north_east, size: 16, color: AdminTheme.muted),
                ],
              ),
              const IosGap(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const IosGap(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.muted,
                ),
              ),
              if (note != null)
                IosPadding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    note!,
                    style: TextStyle(fontSize: 11, color: AdminTheme.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminTileGrid extends StatelessWidget {
  const AdminTileGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return LayoutBuilder(
      builder: (_, c) {
        final columns = c.maxWidth >= 1060
            ? 4
            : c.maxWidth >= 760
            ? 3
            : c.maxWidth >= 490
            ? 2
            : 1;
        final width = (c.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key, this.label = 'Loading workspace…'});
  final String label;
  @override
  Widget build(BuildContext context) {
    AppearanceScope.watch(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: IosPadding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_motion_outlined,
                color: AdminTheme.muted,
                size: 34,
              ),
              const IosGap(height: 20),
              Text(label, style: TextStyle(color: AdminTheme.muted)),
              const IosGap(height: 16),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}
