import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';
import 'sidebar.dart';
import '../screens/dashboard_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/create_invoice_screen.dart';
import '../screens/products_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/purchases_screen.dart';
import '../screens/shop_profile_screen.dart';
import '../screens/theme_settings_screen.dart';
import '../screens/login_screen.dart';
import 'clear_data_dialog.dart';

import '../screens/quotations_screen.dart';
import '../screens/printer_diagnostic_screen.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);

    if (!provider.isLoggedIn) {
      return const LoginScreen();
    }

    final screens = [
      const DashboardScreen(), // 0
      const InvoicesScreen(), // 1
      const CreateInvoiceScreen(), // 2
      const DashboardScreen(), // 3 (formerly CustomerDues)
      const ProductsScreen(), // 4
      const CustomersScreen(), // 5
      const ExpensesScreen(), // 6
      const ReportsScreen(), // 7
      const SuppliersScreen(), // 8
      const PurchasesScreen(), // 9
      const ShopProfileScreen(), // 10
      const ThemeSettingsScreen(), // 11
      const QuotationsScreen(), // 12
      const PrinterDiagnosticScreen(), // 13
    ];

    final screenTitles = [
      'Business Dashboard',
      'Saved Bills',
      'New Bill / Quotation',
      'Business Dashboard',
      'Products & Stock',
      'Customers',
      'Business Expenses',
      'Daily Profit & Reports',
      'Suppliers',
      'Purchase Orders',
      'Settings → Company Details',
      'Theme & Appearance Settings',
      'Quotations & Estimates',
      'Printer Settings & Hardware Configuration',
    ];

    // Mobile Bottom Navigation tabs mapping based on role
    final mobileBottomNavIndexes = provider.isAdmin
        ? [2, 4, 7, 6, 0]
        : [2, 4, 1];

    final mobileBottomNavItems = provider.isAdmin
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_rounded),
              label: 'New Bill',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              label: 'Daily Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_rounded),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_rounded),
              label: 'New Bill',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Saved Bills',
            ),
          ];

    int getMobileNavIndex(int current) {
      final idx = mobileBottomNavIndexes.indexOf(current);
      return idx != -1 ? idx : 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppColors.dashboardBg, // #F8FAFC
            body: Row(
              children: [
                const Sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      screenTitles[provider.currentNavIndex],
                                      style: AppTheme.timesFont(
                                        fontSize: constraints.maxWidth < 1050 ? 17 : 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.admin_panel_settings_rounded,
                                          size: 13,
                                          color: Color(0xFFB45309),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'ADMIN',
                                          style: AppTheme.timesFont(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => showClearAllDataConfirmationDialog(context),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Color(0xFFDC2626)),
                              label: Text(
                                constraints.maxWidth < 1100 ? 'Clear' : 'Clear Data',
                                style: AppTheme.timesFont(color: const Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                backgroundColor: const Color(0xFFFEF2F2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (provider.currentNavIndex != 2)
                              ElevatedButton.icon(
                                onPressed: () {
                                  provider.setNavIndex(2);
                                },
                                icon: const Icon(Icons.add_circle_rounded, size: 16),
                                label: Text(
                                  constraints.maxWidth < 1100 ? '+ Bill' : '+ New Bill',
                                  style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => provider.logout(),
                              icon: Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
                              tooltip: 'Logout',
                            ),
                            if (constraints.maxWidth >= 1080) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.tableHeader,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatCurrentDate(),
                                      style: AppTheme.timesFont(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            // Dashboard Top Right Logo Fixed FlyTowards Logo
                            Container(
                              height: 36,
                              width: 36,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SelectionArea(
                          child: screens[provider.currentNavIndex],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile View
          return Scaffold(
            backgroundColor: AppColors.dashboardBg, // #F8FAFC
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Text(
                screenTitles[provider.currentNavIndex],
                style: AppTheme.timesFont(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(color: AppColors.border, height: 1),
              ),
              actions: [
                if (provider.isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
                    onPressed: () => showClearAllDataConfirmationDialog(context),
                    tooltip: 'Clear All Data',
                  ),
                if (provider.currentNavIndex != 2)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                    onPressed: () => provider.setNavIndex(2),
                    tooltip: 'New Bill',
                  ),
                IconButton(
                  icon: Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                  onPressed: () => provider.logout(),
                  tooltip: 'Logout',
                ),
              ],
            ),
            drawer: const Drawer(
              child: Sidebar(isDrawer: true),
            ),
            body: screens[provider.currentNavIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: getMobileNavIndex(provider.currentNavIndex),
              onTap: (tabIdx) {
                provider.setNavIndex(mobileBottomNavIndexes[tabIdx]);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primary, // Deep Blue
              unselectedItemColor: AppColors.textSecondary,
              selectedLabelStyle: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: AppTheme.timesFont(fontSize: 10),
              items: mobileBottomNavItems,
            ),
          );
        }
      },
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}
