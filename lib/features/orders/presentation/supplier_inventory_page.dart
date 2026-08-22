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
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(42),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _darkRed,
                unselectedLabelColor: Color(0xFF666666),
                indicatorColor: _darkRed,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                labelPadding: EdgeInsets.symmetric(horizontal: 16),
                tabs: [
                  Tab(height: 40, text: 'Inventory'),
                  Tab(height: 40, text: 'Quick Pricing'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [SupplierProductsPage(), QuickPriceManagementPage()],
        ),
      ),
    );
  }
}
