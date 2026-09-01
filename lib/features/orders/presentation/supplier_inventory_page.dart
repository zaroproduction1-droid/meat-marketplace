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
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 20,
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: _darkRed, size: 22),
              SizedBox(width: 10),
              Text(
                'Inventory & Pricing',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF0F1F2)),
                  bottom: BorderSide(color: Color(0xFFE4E6E8)),
                ),
              ),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  labelPadding: EdgeInsets.symmetric(horizontal: 14),
                  labelColor: _darkRed,
                  unselectedLabelColor: Color(0xFF666A70),
                  indicatorColor: _darkRed,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(
                      height: 46,
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      text: 'Inventory',
                    ),
                    Tab(
                      height: 46,
                      icon: Icon(Icons.price_change_outlined, size: 18),
                      text: 'Quick Pricing',
                    ),
                  ],
                ),
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
