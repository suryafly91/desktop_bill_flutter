import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../providers/billing_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_preview_dialog.dart';

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditQuotationDialog(BuildContext context, Invoice quotation) {
    final nameController = TextEditingController(text: quotation.customerName);
    final phoneController = TextEditingController(text: quotation.customerPhone);
    final emailController = TextEditingController(text: quotation.customerEmail);
    final notesController = TextEditingController(text: quotation.notes);
    double discountPercent = quotation.discountPercent;
    double taxPercent = quotation.taxPercent;
    bool isGstBill = quotation.isGstBill;

    final List<_EditQuotationItemInput> itemInputs = quotation.items.map((item) {
      return _EditQuotationItemInput(
        id: item.id,
        desc: item.description,
        qty: item.quantity,
        price: item.unitPrice,
        discount: item.discount,
        mrp: item.mrpPrice,
        cost: item.costPrice,
        unit: item.unit,
        size: item.size,
        color: item.color,
      );
    }).toList();

    if (itemInputs.isEmpty) {
      itemInputs.add(_EditQuotationItemInput(id: const Uuid().v4(), desc: '', qty: 1, price: 0.0));
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double subtotal = itemInputs.fold(0.0, (sum, i) => sum + i.total);
            double taxAmount = isGstBill ? (subtotal * taxPercent / 100.0) : 0.0;
            double discountAmount = (subtotal * discountPercent / 100.0);
            double grandTotal = (subtotal + taxAmount - discountAmount).clamp(0.0, 99999999.0);

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: Colors.purple.shade700, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Quotation #${quotation.invoiceNumber}',
                    style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 600,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Information', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(labelText: 'Customer Name *', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              decoration: const InputDecoration(labelText: 'Phone Number', isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email Address', isDense: true),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Quotation Items', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          TextButton.icon(
                            onPressed: () {
                              setStateDialog(() {
                                itemInputs.add(_EditQuotationItemInput(id: const Uuid().v4(), desc: '', qty: 1, price: 0.0));
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('+ Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      ...itemInputs.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: TextFormField(
                                      initialValue: item.desc,
                                      decoration: const InputDecoration(labelText: 'Description *', isDense: true),
                                      onChanged: (val) {
                                        item.desc = val;
                                        setStateDialog(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.qty.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                                      onChanged: (val) {
                                        item.qty = int.tryParse(val) ?? 1;
                                        setStateDialog(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: item.price.toStringAsFixed(0),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(labelText: 'Rate (₹)', isDense: true),
                                      onChanged: (val) {
                                        item.price = double.tryParse(val) ?? 0.0;
                                        setStateDialog(() {});
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    onPressed: itemInputs.length > 1
                                        ? () {
                                            setStateDialog(() {
                                              itemInputs.removeAt(idx);
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: taxPercent.toStringAsFixed(0),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'GST Tax (%)', isDense: true),
                              onChanged: (val) {
                                taxPercent = double.tryParse(val) ?? 0.0;
                                setStateDialog(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: discountPercent.toStringAsFixed(0),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Discount (%)', isDense: true),
                              onChanged: (val) {
                                discountPercent = double.tryParse(val) ?? 0.0;
                                setStateDialog(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Notes / Remarks', isDense: true),
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Updated Total Amount:', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('₹${grandTotal.toStringAsFixed(2)}', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final updatedItems = itemInputs
                        .where((i) => i.desc.trim().isNotEmpty)
                        .map((i) => InvoiceItem(
                              id: i.id,
                              description: i.desc.trim(),
                              quantity: i.qty,
                              unitPrice: i.price,
                              discount: i.discount,
                              mrpPrice: i.mrp,
                              costPrice: i.cost,
                              unit: i.unit,
                              size: i.size,
                              color: i.color,
                            ))
                        .toList();

                    if (updatedItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please keep at least one valid item in the quotation.', style: AppTheme.timesFont()), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final updatedQuotation = quotation.copyWith(
                      customerName: nameController.text.trim().isNotEmpty ? nameController.text.trim() : quotation.customerName,
                      customerPhone: phoneController.text.trim(),
                      customerEmail: emailController.text.trim(),
                      items: updatedItems,
                      taxPercent: taxPercent,
                      discountPercent: discountPercent,
                      isGstBill: isGstBill,
                      notes: notesController.text.trim(),
                    );

                    final provider = Provider.of<BillingProvider>(context, listen: false);
                    provider.updateInvoice(updatedQuotation);

                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Quotation ${quotation.invoiceNumber} updated successfully!', style: AppTheme.timesFont()),
                        backgroundColor: Colors.purple.shade700,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
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
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final provider = Provider.of<BillingProvider>(context);

    // Filter invoices where status is Quotation
    final quotations = provider.invoices.where((inv) {
      if (inv.status != InvoiceStatus.quotation) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchNum = inv.invoiceNumber.toLowerCase().contains(q);
        final matchName = inv.customerName.toLowerCase().contains(q);
        final matchPhone = inv.customerPhone.toLowerCase().contains(q);
        return matchNum || matchName || matchPhone;
      }
      return true;
    }).toList();

    final totalQuotationAmount = quotations.fold(0.0, (sum, q) => sum + q.totalAmount);

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header & Quick Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.request_quote_rounded, color: Colors.purple.shade700, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Quotations & Estimates',
                          style: AppTheme.timesFont(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage price estimates, edit quotations, download A4 PDFs, and convert to official bills.',
                      style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    provider.setNavIndex(2); // Create New Bill Screen
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('+ Create Quotation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Stats Cards Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;
                final cards = [
                  _buildStatCard(
                    title: 'Total Quotations',
                    value: '${quotations.length}',
                    icon: Icons.description_rounded,
                    color: Colors.purple.shade700,
                  ),
                  _buildStatCard(
                    title: 'Total Quoted Value',
                    value: currencyFormatter.format(totalQuotationAmount),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                  ),
                ];

                if (isMobile) {
                  return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
                }

                return Row(
                  children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 14), child: c))).toList(),
                );
              },
            ),
            const SizedBox(height: 20),

            // Search Bar & Filter Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search quotation by No, Customer Name or Phone...',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quotations Table Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: quotations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.request_quote_outlined, size: 56, color: Colors.purple.shade200),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty ? 'No quotations match your search.' : 'No saved quotations found.',
                              style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Select "Quotation" in the Create Bill screen to save estimates.',
                              style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => provider.setNavIndex(2),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create New Quotation'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quotations.length,
                      separatorBuilder: (ctx, idx) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (ctx, idx) {
                        final q = quotations[idx];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.description_rounded, color: Colors.purple.shade700, size: 22),
                          ),
                          title: Row(
                            children: [
                              Text(
                                q.invoiceNumber,
                                style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Quotation',
                                  style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Customer: ${q.customerName} (${q.customerPhone.isEmpty ? 'No Phone' : q.customerPhone}) • Date: ${dateFormatter.format(q.issueDate)}',
                              style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormatter.format(q.totalAmount),
                                    style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                  Text(
                                    '${q.items.length} item(s)',
                                    style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              ElevatedButton.icon(
                                onPressed: () => _showEditQuotationDialog(context, q),
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  PdfService.downloadOrSharePdf(
                                    invoice: q,
                                    shopProfile: provider.shopProfile,
                                    context: context,
                                  );
                                },
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                label: const Text('Download A4 PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _showEditQuotationDialog(context, q);
                                  } else if (action == 'preview') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => InvoicePreviewDialog(invoice: q),
                                    );
                                  } else if (action == 'convert_paid') {
                                    provider.updateInvoiceStatus(q.id, InvoiceStatus.paid);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Quotation ${q.invoiceNumber} converted to Paid Bill!', style: AppTheme.timesFont()), backgroundColor: AppColors.paid),
                                    );
                                  } else if (action == 'convert_pending') {
                                    provider.updateInvoiceStatus(q.id, InvoiceStatus.pending);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Quotation ${q.invoiceNumber} converted to Pending Khata!', style: AppTheme.timesFont()), backgroundColor: AppColors.pending),
                                    );
                                  } else if (action == 'delete') {
                                    provider.deleteInvoice(q.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Quotation ${q.invoiceNumber} deleted.', style: AppTheme.timesFont())),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'edit', child: Row(children: const [Icon(Icons.edit_rounded, color: Colors.amber, size: 18), SizedBox(width: 8), Text('Edit Quotation')])),
                                  PopupMenuItem(value: 'preview', child: Row(children: const [Icon(Icons.visibility_rounded, size: 18), SizedBox(width: 8), Text('Preview / Print')])),
                                  PopupMenuItem(value: 'convert_paid', child: Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.paid, size: 18), const SizedBox(width: 8), const Text('Convert to Paid Bill')])),
                                  PopupMenuItem(value: 'convert_pending', child: Row(children: [Icon(Icons.hourglass_bottom_rounded, color: AppColors.pending, size: 18), const SizedBox(width: 8), const Text('Convert to Pending Khata')])),
                                  PopupMenuItem(value: 'delete', child: Row(children: const [Icon(Icons.delete_rounded, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete Quotation')])),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: AppTheme.timesFont(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditQuotationItemInput {
  final String id;
  String desc;
  int qty;
  double price;
  double discount;
  double mrp;
  double cost;
  String unit;
  String size;
  String color;

  _EditQuotationItemInput({
    required this.id,
    required this.desc,
    required this.qty,
    required this.price,
    this.discount = 0.0,
    this.mrp = 0.0,
    this.cost = 0.0,
    this.unit = 'Pcs',
    this.size = '',
    this.color = '',
  });

  double get total => ((qty * price) - discount).clamp(0.0, 99999999.0);
}
