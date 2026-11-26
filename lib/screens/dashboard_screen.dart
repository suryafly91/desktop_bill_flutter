import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/invoice_table.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final provider = Provider.of<BillingProvider>(context);
    final shop = provider.shopProfile;
    final lowStockCount = provider.lowStockProducts.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Quick Action Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${shop.shopName}!',
                          style: AppTheme.timesFont(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Local business overview: Customer dues, inventory restock alerts, and daily sales.',
                          style: AppTheme.timesFont(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    ElevatedButton.icon(
                      onPressed: () => provider.setNavIndex(2),
                      icon: const Icon(Icons.add_circle_rounded, size: 18),
                      label: const Text('+ Create Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Low Stock Alert Banner (if any)
          if (lowStockCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.pending.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.pending, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.pending, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Low Stock Alert: $lowStockCount item(s) need restocking soon!',
                      style: AppTheme.timesFont(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => provider.setNavIndex(4), // Products
                    icon: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      'Manage Stock',
                      style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 4 Stat Cards (Responsive Column on mobile, GridView on desktop)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final cards = [
                StatCard(
                  title: 'Total Sales Revenue',
                  amount: provider.totalSales,
                  subtitle: '${provider.invoices.length} Total Generated Bills',
                  icon: Icons.trending_up_rounded,
                  amountColor: AppColors.primary,
                  iconBgColor: AppColors.primary,
                ),
                StatCard(
                  title: 'Customer Dues (Khata)',
                  amount: provider.totalCustomerDues,
                  subtitle: 'Outstanding unpaid balances',
                  icon: Icons.menu_book_rounded,
                  amountColor: AppColors.dueOverdue,
                  iconBgColor: AppColors.dueOverdue,
                ),
                StatCard(
                  title: 'Net Profit Margin',
                  amount: provider.netProfit,
                  subtitle: 'Sales minus Expenses',
                  icon: Icons.account_balance_rounded,
                  amountColor: AppColors.profitAmount,
                  iconBgColor: AppColors.profitAmount,
                ),
                StatCard(
                  title: 'Supplier Dues Payable',
                  amount: provider.totalSupplierDues,
                  subtitle: 'Vendor accounts payable',
                  icon: Icons.factory_rounded,
                  amountColor: AppColors.pending,
                  iconBgColor: AppColors.pending,
                ),
              ];

              if (isMobile) {
                return Column(
                  children: cards.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  )).toList(),
                );
              }

              return GridView.count(
                crossAxisCount: constraints.maxWidth < 1100 ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: cards,
              );
            },
          ),
          const SizedBox(height: 28),

          // Quick Action Bar for Local Business Workflow
          Text(
            'Local Business Quick Actions',
            style: AppTheme.timesFont(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionButton(
                  context,
                  '+ Record Payment',
                  Icons.attach_money_rounded,
                  AppColors.paid,
                  () => provider.setNavIndex(3),
                ),
                const SizedBox(width: 12),
                _buildQuickActionButton(
                  context,
                  '+ New Invoice',
                  Icons.add_circle_outline_rounded,
                  AppColors.primary,
                  () => provider.setNavIndex(2),
                ),
                const SizedBox(width: 12),
                _buildQuickActionButton(
                  context,
                  '+ Log Stock Purchase',
                  Icons.shopping_bag_rounded,
                  AppColors.primary,
                  () => provider.setNavIndex(9),
                ),
                const SizedBox(width: 12),
                _buildQuickActionButton(
                  context,
                  'WhatsApp Reminders',
                  Icons.send_rounded,
                  AppColors.primary,
                  () => provider.setNavIndex(3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Customer Accounts Outstanding Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Customer Accounts Due (Khata Summary)',
                  style: AppTheme.timesFont(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => provider.setNavIndex(3),
                icon: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                label: Text(
                  'Manage All Khata Dues',
                  style: AppTheme.timesFont(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Dues Preview Table Container #FFFFFF with Header #EAEAFF
          Container(
            decoration: BoxDecoration(
              color: AppColors.invoiceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 600),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.tableHeader,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 180, child: Text('Customer Name', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                          SizedBox(width: 140, child: Text('Phone', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                          SizedBox(width: 140, child: Text('Balance Due', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                          SizedBox(width: 140, child: Text('Action', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                        ],
                      ),
                    ),
                    Column(
                      children: provider.customers.where((c) => c.dueBalance > 0).take(4).map((customer) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 180,
                                    child: Text(customer.name, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: Text(customer.phone, style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary)),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      currencyFormatter.format(customer.dueBalance),
                                      style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.dueOverdue),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => provider.sendWhatsAppDueReminder(customer),
                                        icon: Icon(Icons.send_rounded, size: 14, color: AppColors.primary),
                                        label: Text('Reminder', style: AppTheme.timesFont(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: AppColors.border, height: 1),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Recent Invoices Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Generated Bills',
                style: AppTheme.timesFont(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => provider.setNavIndex(1),
                icon: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                label: Text(
                  'View All Bills',
                  style: AppTheme.timesFont(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Invoice Table (#FFFFFF with Header #EAEAFF)
          InvoiceTable(
            invoices: provider.invoices,
            isLimitView: true,
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Created @ FlyTowards',
              style: AppTheme.timesFont(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
