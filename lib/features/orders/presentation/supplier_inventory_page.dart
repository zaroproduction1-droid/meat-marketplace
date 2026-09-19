import 'package:flutter/material.dart';
import '../../pricing/presentation/quick_price_management_page.dart';

/// Both historic entry points now open the same stock and pricing workspace.
class SupplierInventoryPage extends StatelessWidget {
  const SupplierInventoryPage({
    super.key,
    this.embedded = false,
    this.initialTabIndex = 0,
  });
  final bool embedded;
  final int initialTabIndex;
  @override
  Widget build(BuildContext context) => const QuickPriceManagementPage();
}
