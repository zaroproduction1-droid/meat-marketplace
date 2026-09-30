import 'package:flutter/material.dart';
import '../../../shared/widgets/cutlink_workspace_theme.dart';

/// Admin-only presentation layer; shared supplier/butcher styling is untouched.
class AdminTheme extends StatelessWidget {
  const AdminTheme({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  static const ink = Color(0xFF172638);
  static const muted = Color(0xFF647386);
  static const canvas = Color(0xFFF3F5F8);
  static const accent = Color(0xFF741C1C);
  static const line = Color(0xFFE3E8EF);
  @override
  Widget build(BuildContext context) => CutLinkWorkspaceTheme(
    child: Builder(
      builder: (context) {
        if (!enabled) {
          return child;
        }
        final base = Theme.of(context);
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
              color: Colors.white,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: line),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              titleTextStyle: const TextStyle(
                color: ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            listTileTheme: const ListTileThemeData(
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFF3E7E8),
              side: const BorderSide(color: line),
              labelStyle: const TextStyle(
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
              fillColor: const Color(0xFFFAFBFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 17,
              ),
              labelStyle: const TextStyle(color: muted, fontSize: 13),
            ),
          ),
          child: child,
        );
      },
    ),
  );
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
    'accounts' => Icons.account_balance_wallet_outlined,
    'invoices' => Icons.receipt_long_outlined,
    'announcements' => Icons.campaign_outlined,
    'audit' => Icons.history_rounded,
    'support' => Icons.support_agent,
    _ => Icons.tune_rounded,
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 1050) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Wrap(
                spacing: 4,
                runSpacing: 6,
                children: [
                  for (final entry in items.entries)
                    Padding(
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
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AdminTheme.line)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Material(
                      color: value == entry.key
                          ? const Color(0xFFF4E8E9)
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
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E8E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: AdminTheme.accent),
                ),
                const Spacer(),
                if (onTap != null)
                  const Icon(
                    Icons.north_east,
                    size: 16,
                    color: AdminTheme.muted,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminTheme.muted,
              ),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  note!,
                  style: const TextStyle(fontSize: 11, color: AdminTheme.muted),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class AdminTileGrid extends StatelessWidget {
  const AdminTileGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
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

class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key, this.label = 'Loading workspace…'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_motion_outlined,
              color: AdminTheme.muted,
              size: 34,
            ),
            const SizedBox(height: 20),
            Text(label, style: const TextStyle(color: AdminTheme.muted)),
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ),
      ),
    ),
  );
}
