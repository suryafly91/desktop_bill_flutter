import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _searchQuery = '';

  void _showAddExpenseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final notesController = TextEditingController();

    Widget buildForm(BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Log New Expense',
                style: AppTheme.timesFont(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          TextFormField(
            controller: titleController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Expense Title / Detail *',
              prefixIcon: Icon(Icons.description_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₹) *',
              prefixIcon: Icon(Icons.payments_outlined, color: AppColors.expenseAmount),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: categoryController,
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: Icon(Icons.notes_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty && amountController.text.isNotEmpty) {
                  final provider = Provider.of<BillingProvider>(context, listen: false);
                  provider.addExpense(
                    Expense(
                      id: const Uuid().v4(),
                      title: titleController.text.trim(),
                      amount: double.tryParse(amountController.text.trim()) ?? 0.0,
                      category: categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
                      date: DateTime.now(),
                      notes: notesController.text.trim(),
                    ),
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Expense logged successfully!', style: AppTheme.timesFont()), backgroundColor: AppColors.expenseAmount),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Save Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expenseAmount,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    if (MediaQuery.of(context).size.width >= 700) {
      showDialog(
        context: context,
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(child: buildForm(dialogCtx)),
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalCtx) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: buildForm(modalCtx),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final provider = Provider.of<BillingProvider>(context);

    final filteredExpenses = provider.expenses.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.title.toLowerCase().contains(q) || e.category.toLowerCase().contains(q);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header Title on Mobile
              if (isMobile) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Business Expenses',
                      style: AppTheme.timesFont(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddExpenseDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Log Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expenseAmount,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Search Bar & Desktop Action Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        labelText: 'Search Expenses',
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddExpenseDialog(context),
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                      label: const Text('+ Log Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expenseAmount,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Total Expense Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.expenseAmount.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Operating Expenses',
                          style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormatter.format(provider.totalExpenses),
                          style: AppTheme.timesFont(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.expenseAmount,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.expenseAmount.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.expenseAmount, size: 24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Expenses List Section
              filteredExpenses.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'No expenses logged',
                            style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Log Expense" to record business spending.',
                            style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : isMobile
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredExpenses.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final expense = filteredExpenses[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.expenseAmount.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_outlined, color: AppColors.expenseAmount, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(expense.title, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                        Text('${expense.category} • ${dateFormatter.format(expense.date)}', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '-${currencyFormatter.format(expense.amount)}',
                                        style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.expenseAmount),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                                        onPressed: () {
                                          provider.deleteExpense(expense.id);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.tableHeader,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text('Date', style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                                    Expanded(flex: 4, child: Text('Expense Title / Description', style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                                    Expanded(flex: 2, child: Text('Category', style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                                    Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                                    Expanded(flex: 1, child: Text('Action', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                                  ],
                                ),
                              ),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredExpenses.length,
                                separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                                itemBuilder: (context, index) {
                                  final expense = filteredExpenses[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(dateFormatter.format(expense.date), style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary))),
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(expense.title, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                              if (expense.notes.isNotEmpty) Text(expense.notes, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Expanded(flex: 2, child: Text(expense.category, style: AppTheme.timesFont(fontSize: 13, color: AppColors.textPrimary))),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '-${currencyFormatter.format(expense.amount)}',
                                            textAlign: TextAlign.right,
                                            style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.expenseAmount),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.dueOverdue),
                                              onPressed: () => provider.deleteExpense(expense.id),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
            ],
          ),
        );
      },
    );
  }
}
