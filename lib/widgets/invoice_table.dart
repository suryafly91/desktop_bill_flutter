import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/billing_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'invoice_preview_dialog.dart';

class InvoiceTable extends StatelessWidget {
  final List<Invoice> invoices;
  final bool isLimitView;

  const InvoiceTable({
    super.key,
    required this.invoices,
    this.isLimitView = false,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final provider = Provider.of<BillingProvider>(context, listen: false);

    if (invoices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.invoiceCard, // #FFFFFF
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No Invoices Found',
              style: AppTheme.timesFont(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Click "+ New Invoice" to generate your first invoice.',
              style: AppTheme.timesFont(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        if (isMobile) {
          // Mobile Card View
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: isLimitView && invoices.length > 5 ? 5 : invoices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.invoiceCard, // #FFFFFF
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: AppTheme.timesFont(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        StatusBadge(status: invoice.status, isCompact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      invoice.customerName,
                      style: AppTheme.timesFont(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Due: ${dateFormatter.format(invoice.dueDate)}',
                      style: AppTheme.timesFont(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currencyFormatter.format(invoice.totalAmount),
                          style: AppTheme.timesFont(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryButton, // #2563EB
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Download PDF',
                              icon: const Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 20),
                              onPressed: () {
                                PdfService.downloadOrSharePdf(
                                  invoice: invoice,
                                  shopProfile: provider.shopProfile,
                                  paperSize: provider.shopProfile.paperSizeEnum,
                                  context: context,
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.visibility_rounded, color: AppColors.primaryButton, size: 20),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => InvoicePreviewDialog(invoice: invoice),
                                );
                              },
                            ),
                            PopupMenuButton<InvoiceStatus>(
                              icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                              onSelected: (status) => provider.updateInvoiceStatus(invoice.id, status),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: InvoiceStatus.paid, child: Text('Mark Paid')),
                                const PopupMenuItem(value: InvoiceStatus.pending, child: Text('Mark Pending')),
                                const PopupMenuItem(value: InvoiceStatus.overdue, child: Text('Mark Overdue')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Desktop Table View (#FFFFFF card container, #F1F5F9 table header)
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SizedBox(
              width: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.invoiceCard, // #FFFFFF
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Table Header #F1F5F9
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: AppColors.tableHeader, // #F1F5F9
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Invoice #',
                              style: AppTheme.timesFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Customer',
                              style: AppTheme.timesFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Due Date',
                              style: AppTheme.timesFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Amount',
                              style: AppTheme.timesFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Status',
                              style: AppTheme.timesFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Actions',
                              textAlign: TextAlign.right,
                              style: AppTheme.timesFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rows
                    Column(
                      children: (isLimitView && invoices.length > 5 ? invoices.take(5) : invoices).map((invoice) {
                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => InvoicePreviewDialog(invoice: invoice),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        invoice.invoiceNumber,
                                        style: AppTheme.timesFont(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primaryButton, // #2563EB
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            invoice.customerName,
                                            style: AppTheme.timesFont(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            invoice.customerEmail,
                                            style: AppTheme.timesFont(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        dateFormatter.format(invoice.dueDate),
                                        style: AppTheme.timesFont(
                                          fontSize: 13,
                                          color: invoice.status == InvoiceStatus.overdue
                                              ? AppColors.dueOverdue
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currencyFormatter.format(invoice.totalAmount),
                                        style: AppTheme.timesFont(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: StatusBadge(status: invoice.status, isCompact: true),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              tooltip: 'Download PDF',
                                              icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF0284C7)),
                                              onPressed: () {
                                                PdfService.downloadOrSharePdf(
                                                  invoice: invoice,
                                                  shopProfile: provider.shopProfile,
                                                  paperSize: provider.shopProfile.paperSizeEnum,
                                                  context: context,
                                                );
                                              },
                                            ),
                                            IconButton(
                                              tooltip: 'View Invoice',
                                              icon: Icon(Icons.visibility_outlined, size: 18, color: AppColors.primaryButton),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => InvoicePreviewDialog(invoice: invoice),
                                                );
                                              },
                                            ),
                                            PopupMenuButton<InvoiceStatus>(
                                              tooltip: 'Update Status',
                                              icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                              onSelected: (status) => provider.updateInvoiceStatus(invoice.id, status),
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value: InvoiceStatus.paid,
                                                  child: Text('Mark Paid', style: AppTheme.timesFont(color: AppColors.paid, fontWeight: FontWeight.bold)),
                                                ),
                                                PopupMenuItem(
                                                  value: InvoiceStatus.pending,
                                                  child: Text('Mark Pending', style: AppTheme.timesFont(color: AppColors.pending, fontWeight: FontWeight.bold)),
                                                ),
                                                PopupMenuItem(
                                                  value: InvoiceStatus.overdue,
                                                  child: Text('Mark Due / Overdue', style: AppTheme.timesFont(color: AppColors.dueOverdue, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              tooltip: 'Delete Invoice',
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.dueOverdue),
                                              onPressed: () {
                                                provider.deleteInvoice(invoice.id);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Invoice ${invoice.invoiceNumber} deleted.', style: AppTheme.timesFont()),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(color: AppColors.border, height: 1, thickness: 0.5),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
