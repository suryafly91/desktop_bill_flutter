import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class CustomerDuesScreen extends StatefulWidget {
  const CustomerDuesScreen({super.key});

  @override
  State<CustomerDuesScreen> createState() => _CustomerDuesScreenState();
}

class _CustomerDuesScreenState extends State<CustomerDuesScreen> {
  String _searchQuery = '';

  void _showRecordPaymentDialog(BuildContext context, Customer customer) {
    final amountController = TextEditingController(text: customer.dueBalance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.invoiceCard,
          title: Text(
            'Record Customer Payment (Khata)',
            style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: ${customer.name}',
                    style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Current Due Balance: ₹${customer.dueBalance.toStringAsFixed(2)}',
                    style: AppTheme.timesFont(fontSize: 14, color: AppColors.dueOverdue, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount Received (₹)',
                      prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final paidAmount = double.tryParse(amountController.text) ?? 0.0;
                if (paidAmount > 0) {
                  final provider = Provider.of<BillingProvider>(context, listen: false);
                  provider.recordCustomerPayment(customer.id, paidAmount);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment of ₹${paidAmount.toStringAsFixed(2)} recorded for ${customer.name}.', style: AppTheme.timesFont()),
                      backgroundColor: AppColors.paid,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Record Payment'),
            ),
          ],
        );
      },
    );
  }

  void _showFollowUpDialog(BuildContext context, Customer customer) {
    final notesController = TextEditingController(text: customer.followUpNotes);
    DateTime? selectedDate = customer.nextFollowUpDate ?? DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final dateFormatter = DateFormat('MMM dd, yyyy');
            return AlertDialog(
              backgroundColor: AppColors.invoiceCard,
              title: Text(
                'Update Follow-up & Contact Notes',
                style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer: ${customer.name}',
                        style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Follow-up Notes / Call Details',
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setStateModal(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Next Scheduled Follow-up Date',
                            suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                          ),
                          child: Text(
                            selectedDate != null ? dateFormatter.format(selectedDate!) : 'Select Date',
                            style: AppTheme.timesFont(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final provider = Provider.of<BillingProvider>(context, listen: false);
                    provider.updateCustomerFollowUp(customer.id, notesController.text.trim(), selectedDate);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Follow-up updated for ${customer.name}.', style: AppTheme.timesFont()),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Save Follow-up'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final provider = Provider.of<BillingProvider>(context);

    final dueCustomers = provider.customers.where((c) {
      if (c.dueBalance <= 0) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.email.toLowerCase().contains(q);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Dues Summary Header Card
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: AppColors.primary, // #0818A8 Deep Royal Blue
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary, // #CCCCFF
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Outstanding Dues (Khata)',
                            style: AppTheme.timesFont(
                              fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter.format(provider.totalCustomerDues),
                            style: AppTheme.timesFont(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${dueCustomers.length} Pending',
                        style: AppTheme.timesFont(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  labelText: 'Search Due Accounts (Customer Name or Phone)',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // Dues Table / Cards Section
              dueCustomers.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          'All customer accounts are settled! Zero outstanding dues.',
                          style: AppTheme.timesFont(fontSize: 15, color: AppColors.paid, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  : isMobile
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dueCustomers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final customer = dueCustomers[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.name,
                                              style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                            ),
                                            Text(customer.phone, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        currencyFormatter.format(customer.dueBalance),
                                        style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dueOverdue),
                                      ),
                                    ],
                                  ),
                                  if (customer.followUpNotes.isNotEmpty || customer.nextFollowUpDate != null) ...[
                                    const Divider(height: 14, color: AppColors.border),
                                    Text(
                                      customer.followUpNotes.isNotEmpty ? customer.followUpNotes : 'No notes',
                                      style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    if (customer.nextFollowUpDate != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Next Call: ${dateFormatter.format(customer.nextFollowUpDate!)}',
                                        style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ],
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showRecordPaymentDialog(context, customer),
                                          icon: const Icon(Icons.attach_money_rounded, size: 14),
                                          label: const Text('Pay'),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.paid, padding: const EdgeInsets.symmetric(vertical: 8)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.primary),
                                        onPressed: () => _showFollowUpDialog(context, customer),
                                        tooltip: 'Notes',
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => provider.sendWhatsAppDueReminder(customer),
                                          icon: const Icon(Icons.send_rounded, size: 14),
                                          label: const Text('WhatsApp'),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 8)),
                                        ),
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
                            color: AppColors.invoiceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
                              child: Column(
                                children: [
                                  // Header #EAEAFF
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppColors.tableHeader,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 180, child: Text('Customer Account', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                                        SizedBox(width: 130, child: Text('Balance Due', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                                        SizedBox(width: 220, child: Text('Follow-up Notes', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                                        SizedBox(width: 250, child: Text('Quick Actions', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary))),
                                      ],
                                    ),
                                  ),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: dueCustomers.length,
                                    separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                                    itemBuilder: (context, index) {
                                      final customer = dueCustomers[index];

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 180,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(customer.name, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                                  Text(customer.phone, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 130,
                                              child: Text(
                                                currencyFormatter.format(customer.dueBalance),
                                                style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.dueOverdue),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 220,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer.followUpNotes.isNotEmpty ? customer.followUpNotes : 'No notes',
                                                    style: AppTheme.timesFont(fontSize: 12, color: AppColors.textPrimary),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (customer.nextFollowUpDate != null)
                                                    Text(
                                                      'Next: ${dateFormatter.format(customer.nextFollowUpDate!)}',
                                                      style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 250,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  ElevatedButton.icon(
                                                    onPressed: () => _showRecordPaymentDialog(context, customer),
                                                    icon: const Icon(Icons.attach_money_rounded, size: 14),
                                                    label: const Text('Pay'),
                                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.paid, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  IconButton(
                                                    tooltip: 'Notes',
                                                    icon: Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.primary),
                                                    onPressed: () => _showFollowUpDialog(context, customer),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  ElevatedButton.icon(
                                                    onPressed: () => provider.sendWhatsAppDueReminder(customer),
                                                    icon: const Icon(Icons.send_rounded, size: 14),
                                                    label: const Text('WhatsApp'),
                                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                                  ),
                                                ],
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
                          ),
                        ),
            ],
          ),
        );
      },
    );
  }
}
