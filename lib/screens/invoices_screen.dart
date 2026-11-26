import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_table.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Paid, 2: Pending, 3: Overdue

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);

    // Apply Filter & Search
    List<Invoice> filteredInvoices = provider.invoices.where((inv) {
      // Status Filter
      if (_selectedFilterIndex == 1 && inv.status != InvoiceStatus.paid) return false;
      if (_selectedFilterIndex == 2 && inv.status != InvoiceStatus.pending) return false;
      if (_selectedFilterIndex == 3 && inv.status != InvoiceStatus.overdue) return false;

      // Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchNumber = inv.invoiceNumber.toLowerCase().contains(query);
        final matchCustomer = inv.customerName.toLowerCase().contains(query);
        final matchEmail = inv.customerEmail.toLowerCase().contains(query);
        return matchNumber || matchCustomer || matchEmail;
      }

      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Tabs & Search Controls Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;

              return Column(
                children: [
                  Row(
                    children: [
                      // Search Bar
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Search Invoices (By #, Customer or Email)',
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => provider.setNavIndex(2),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(isNarrow ? '+' : '+ New Invoice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton, // #2563EB
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Buttons Segmented Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(0, 'All Invoices (${provider.invoices.length})', null),
                        const SizedBox(width: 10),
                        _buildFilterChip(1, 'Paid (${provider.paidCount})', AppColors.paid),
                        const SizedBox(width: 10),
                        _buildFilterChip(2, 'Pending (${provider.pendingCount})', AppColors.pending),
                        const SizedBox(width: 10),
                        _buildFilterChip(3, 'Due / Overdue (${provider.overdueCount})', AppColors.dueOverdue),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Invoices Table (#FFFFFF card container, #F1F5F9 table header)
          InvoiceTable(
            invoices: filteredInvoices,
            isLimitView: false,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, Color? activeColor) {
    final isSelected = _selectedFilterIndex == index;
    final color = activeColor ?? AppColors.primaryButton;

    return ChoiceChip(
      label: Text(
        label,
        style: AppTheme.timesFont(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilterIndex = index;
          });
        }
      },
      selectedColor: color,
      backgroundColor: AppColors.tableHeader, // #F1F5F9
      showCheckmark: false,
      side: BorderSide(
        color: isSelected ? color : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
