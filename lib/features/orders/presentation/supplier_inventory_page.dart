import 'package:flutter/material.dart';

import '../../pricing/presentation/quick_price_management_page.dart';
import '../../products/presentation/supplier_products_page.dart';

class SupplierInventoryPage extends StatelessWidget {
  const SupplierInventoryPage({
    super.key,
    this.embedded = false,
    this.initialTabIndex = 0,
  });

  final bool embedded;
  final int initialTabIndex;

  static const _darkRed = Color(0xFF741C1C);
  static const _workspaceBackground = Color(0xFFF7F8FA);

  Widget _tabBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF0F1F2)),
          bottom: BorderSide(color: Color(0xFFE3E5E8)),
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
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
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
    );
  }

  Widget _workspaceHeader() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3E5E8))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EAEA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _darkRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 1),
                Text(
                  'Manage products, stock, specifications and pricing',
                  style: TextStyle(
                    color: Color(0xFF74787E),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabView() {
    return const TabBarView(
      children: [SupplierProductsPage(), QuickPriceManagementPage()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: embedded
          ? ColoredBox(
              color: _workspaceBackground,
              child: Column(
                children: [
                  _workspaceHeader(),
                  _tabBar(),
                  Expanded(child: _tabView()),
                ],
              ),
            )
          : Scaffold(
              backgroundColor: _workspaceBackground,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(64),
                  child: _tabBar(),
                ),
              ),
              body: _tabView(),
            ),
    );
  }
}
