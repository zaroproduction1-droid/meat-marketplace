import 'package:flutter/material.dart';

import '../../pricing/presentation/quick_price_management_page.dart';
import '../../products/presentation/supplier_products_page.dart';

class SupplierInventoryPage extends StatelessWidget {
  const SupplierInventoryPage({super.key});

  static const _darkRed = Color(0xFF741C1C);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Supplier Inventory',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            labelColor: _darkRed,
            indicatorColor: _darkRed,
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory'),
              Tab(
                icon: Icon(Icons.price_change_outlined),
                text: 'Quick Pricing',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [SupplierProductsPage(), QuickPriceManagementPage()],
        ),
      ),
    );
  }
}
