import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  final bool isDrawer;

  const Sidebar({
    super.key,
    this.isDrawer = false,
  });

  IconData _getShopLogoIcon(String logoPreset) {
    switch (logoPreset) {
      case 'pos':
        return Icons.point_of_sale_rounded;
      case 'tech':
        return Icons.devices_other_rounded;
      case 'apparel':
        return Icons.checkroom_rounded;
      case 'mart':
        return Icons.shopping_basket_rounded;
      case 'pharma':
        return Icons.medical_services_rounded;
      case 'store':
      default:
        return Icons.storefront_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    final profile = provider.shopProfile;

    final allNavItems = [
      _NavItem(0, 'Dashboard', Icons.dashboard_rounded),
      _NavItem(1, 'Invoices & Bills', Icons.receipt_long_rounded),
      _NavItem(2, 'Create New Bill / Quotation', Icons.add_circle_outline_rounded),
      _NavItem(12, 'Quotations & Estimates', Icons.request_quote_rounded),
      _NavItem(4, 'Products & Stock', Icons.inventory_2_rounded),
      _NavItem(5, 'Customers Directory', Icons.people_alt_rounded),
      _NavItem(6, 'Expenses', Icons.account_balance_wallet_rounded),
      _NavItem(7, 'Reports', Icons.analytics_rounded),
      _NavItem(8, 'Suppliers', Icons.factory_rounded),
      _NavItem(9, 'Purchases', Icons.shopping_bag_rounded),
      _NavItem(10, 'Company Details', Icons.business_rounded),
      _NavItem(11, 'Theme & Appearance', Icons.palette_rounded),
      _NavItem(13, 'Printer Settings', Icons.print_rounded),
    ];

    // Filter items allowed for the current logged-in role
    final navItems = allNavItems.where((item) => provider.canAccessNavIndex(item.index)).toList();

    return Container(
      width: 260,
      height: double.infinity,
      color: AppColors.sidebar, // #0818A8 Royal Blue
      child: Column(
        children: [
          // Branding Header using Saved Shop Profile & Accent #A7C7E7
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Icon(
                        _getShopLogoIcon(profile.logoPreset),
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.shopName.isNotEmpty
                            ? profile.shopName
                            : 'My Store',
                        style: AppTheme.timesFont(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.gstin.trim().isNotEmpty
                            ? 'GSTIN: ${profile.gstin}'
                            : 'Mobile: ${profile.mobile}',
                        style: AppTheme.timesFont(
                          fontSize: 11,
                          color: AppColors.secondary, // #CCCCFF
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E2CB8), height: 1, thickness: 1),
          const SizedBox(height: 12),

          // Navigation List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = provider.currentNavIndex == item.index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tileColor: isSelected ? AppColors.sidebarActiveBg : Colors.transparent,
                      leading: Icon(
                        item.icon,
                        color: isSelected ? AppColors.secondary : AppColors.sidebarText,
                        size: 20,
                      ),
                      title: Text(
                        item.title,
                        style: AppTheme.timesFont(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.sidebarActiveText : AppColors.sidebarText,
                        ),
                      ),
                      onTap: () {
                        provider.setNavIndex(item.index);
                        if (isDrawer) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // App Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Text(
              'Created @ FlyTowards',
              style: AppTheme.timesFont(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final int index;
  final String title;
  final IconData icon;

  _NavItem(this.index, this.title, this.icon);
}
