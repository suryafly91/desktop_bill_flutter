import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('MMMM dd, yyyy');
    final provider = Provider.of<BillingProvider>(context);

    // Today's Metrics
    final todaySales = provider.todaySalesTotal;
    final todayMrp = provider.todayMrpTotal;
    final todayGrossProfit = provider.todayGrossProfit; // MRP vs Selling Price Today Profit
    final todayExpenses = provider.todayExpensesTotal;
    final todayNetProfit = provider.todayNetProfit; // Amount less profit (Gross Profit minus Expenses)

    final todayInvoicesList = provider.todayInvoices;
    final todayExpensesList = provider.todayExpensesList;

    // Overall Metrics
    final totalSales = provider.totalSales;
    final totalExpenses = provider.totalExpenses;
    final netProfit = provider.netProfit;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Report & Analytics',
                        style: AppTheme.timesFont(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Date: ${dateFormatter.format(DateTime.now())}',
                        style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tableHeader,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.today_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('Today Live', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. TODAY PROFIT & EXPENSE CARDS GRID
              Text(
                "Today's Profit & Expense Summary",
                style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),

              if (isMobile) ...[
                // Mobile Stacked Summary Cards
                _buildReportCard(
                  'Today Total Sales',
                  currencyFormatter.format(todaySales),
                  '${todayInvoicesList.length} Bills Issued Today',
                  Icons.point_of_sale_rounded,
                  AppColors.primary,
                  bgTint: AppColors.primary.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 10),
                _buildReportCard(
                  'Today Cost / MRP Total',
                  currencyFormatter.format(todayMrp),
                  'Inventory Stock Valuation',
                  Icons.price_change_outlined,
                  AppColors.textSecondary,
                  bgTint: Colors.white,
                ),
                const SizedBox(height: 10),
                _buildReportCard(
                  "Today's Profit (Selling - MRP)",
                  currencyFormatter.format(todayGrossProfit),
                  'Gross Margin Before Expenses',
                  Icons.trending_up_rounded,
                  AppColors.paid,
                  bgTint: AppColors.paid.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 10),
                _buildReportCard(
                  "Today's Expenses",
                  currencyFormatter.format(todayExpenses),
                  '${todayExpensesList.length} Expense Logs Today',
                  Icons.receipt_rounded,
                  AppColors.dueOverdue,
                  bgTint: AppColors.dueOverdue.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 10),
                _buildReportCard(
                  'Today Net Profit',
                  currencyFormatter.format(todayNetProfit),
                  'Gross Profit Minus Today Expenses',
                  Icons.account_balance_wallet_rounded,
                  todayNetProfit >= 0 ? AppColors.primary : AppColors.dueOverdue,
                  isHighlighted: true,
                  bgTint: AppColors.tableHeader,
                ),
              ] else ...[
                // Desktop Flexible Row / Wrap layout (prevents fixed height overflow)
                Row(
                  children: [
                    Expanded(
                      child: _buildReportCard(
                        'Today Total Sales',
                        currencyFormatter.format(todaySales),
                        '${todayInvoicesList.length} Bills Issued Today',
                        Icons.point_of_sale_rounded,
                        AppColors.primary,
                        bgTint: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildReportCard(
                        "Today's Profit (Selling - MRP)",
                        currencyFormatter.format(todayGrossProfit),
                        'Gross Margin Before Expenses',
                        Icons.trending_up_rounded,
                        AppColors.paid,
                        bgTint: AppColors.paid.withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildReportCard(
                        'Today Net Profit',
                        currencyFormatter.format(todayNetProfit),
                        'Gross Profit Minus Expenses',
                        Icons.account_balance_wallet_rounded,
                        todayNetProfit >= 0 ? AppColors.primary : AppColors.dueOverdue,
                        isHighlighted: true,
                        bgTint: AppColors.tableHeader,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // 2. TODAY'S BILLS BREAKDOWN LIST
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's Bills & Sales Ledger",
                          style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${todayInvoicesList.length} Invoices',
                          style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    todayInvoicesList.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text('No bills created today yet.', style: AppTheme.timesFont(color: AppColors.textSecondary)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todayInvoicesList.length,
                            separatorBuilder: (_, _) => const Divider(height: 12, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final inv = todayInvoicesList[index];
                              final invProfit = inv.items.fold(0.0, (sum, item) => sum + item.itemProfit);

                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${inv.invoiceNumber} - ${inv.customerName}',
                                          style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          'Items: ${inv.items.length} • Mode: ${inv.paymentMethod.label}',
                                          style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currencyFormatter.format(inv.totalAmount),
                                        style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                      ),
                                      Text(
                                        'Profit: +${currencyFormatter.format(invProfit)}',
                                        style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.paid),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. OVERALL BUSINESS STATEMENTS
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All-Time Financial Statement Overview',
                      style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    _buildReportLine('All Time Total Sales Revenue', currencyFormatter.format(totalSales), AppColors.primary),
                    const Divider(height: 16, color: AppColors.border),
                    _buildReportLine('All Time Total Expenses', '-${currencyFormatter.format(totalExpenses)}', AppColors.dueOverdue),
                    const Divider(height: 16, color: AppColors.border),
                    _buildReportLine('All Time Net Operating Profit', currencyFormatter.format(netProfit), AppColors.paid, isBold: true, fontSize: 18),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportCard(
    String title,
    String amount,
    String subtitle,
    IconData icon,
    Color color, {
    bool isHighlighted = false,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? color : AppColors.border,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: AppTheme.timesFont(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.timesFont(fontSize: 10, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportLine(String label, String value, Color color, {bool isBold = false, double fontSize = 15}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.timesFont(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.textPrimary),
        ),
        Text(
          value,
          style: AppTheme.timesFont(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
