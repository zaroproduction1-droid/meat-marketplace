import 'package:flutter/material.dart';
import 'admin_console_page.dart';

/// Retained entry point for older links; all approvals use the current admin UI.
class PendingBusinessesPage extends StatelessWidget {
  const PendingBusinessesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminConsolePage(initialTab: 'businesses');
}
