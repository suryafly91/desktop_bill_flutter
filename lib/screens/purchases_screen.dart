import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase.dart';
import '../models/invoice_item.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String _searchQuery = '';

  void _showAddPurchaseDialog(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context, listen: false);

    Supplier? selectedSupplier = provider.suppliers.isNotEmpty ? provider.suppliers.first : null;
    Product? selectedProduct = provider.products.isNotEmpty ? provider.products.first : null;

    final quantityController = TextEditingController(text: '1');
    final costPriceController = TextEditingController(text: selectedProduct?.unitCostPrice.toStringAsFixed(2) ?? '');
    final notesController = TextEditingController();

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final purchaseNo = 'PO-2026-$timestamp';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: AppColors.invoiceCard, // #FFFFFF
              title: Text(
                'Log Stock Purchase from Supplier ($purchaseNo)',
                style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Select Supplier
                      DropdownButtonFormField<Supplier>(
                        initialValue: selectedSupplier,
                        decoration: const InputDecoration(labelText: 'Select Vendor / Supplier *'),
                        items: provider.suppliers.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s.companyName));
                        }).toList(),
                        onChanged: (val) => setStateModal(() => selectedSupplier = val),
                      ),
                      const SizedBox(height: 14),

                      // Select Product to restock
                      DropdownButtonFormField<Product>(
                        initialValue: selectedProduct,
                        decoration: const InputDecoration(labelText: 'Select Product to Restock *'),
                        items: provider.products.map((p) {
                          return DropdownMenuItem(value: p, child: Text('${p.name} (Current Stock: ${p.stockQuantity})'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateModal(() {
                              selectedProduct = val;
                              costPriceController.text = val.unitCostPrice.toStringAsFixed(2);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Quantity Restocked *'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: costPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Unit Cost Price (₹) *'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Purchase Order Notes / Batch No.'),
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
                    if (selectedSupplier != null && selectedProduct != null) {
                      final q = int.tryParse(quantityController.text) ?? 1;
                      final c = double.tryParse(costPriceController.text) ?? 0.0 ;
                      final total = q * c;

                      provider.addPurchase(
                        Purchase(
                          id: const Uuid().v4(),
                          purchaseNumber: purchaseNo,
                          supplierId: selectedSupplier!.id,
                          supplierName: selectedSupplier!.companyName,
                          date: DateTime.now(),
                          items: [
                            InvoiceItem(
                              id: const Uuid().v4(),
                              description: selectedProduct!.name,
                              quantity: q,
                              unitPrice: c,
                              size: selectedProduct!.size,
                              color: selectedProduct!.color,
                              unit: selectedProduct!.unit,
                            ),
                          ],
                          totalAmount: total,
                          paymentStatus: 'Paid',
                          notes: notesController.text.trim(),
                        ),
                      );

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Stock purchase recorded! $q units added to ${selectedProduct!.name}.', style: AppTheme.timesFont()),
                          backgroundColor: AppColors.paid,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Save & Increment Stock'),
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

    final filteredPurchases = provider.purchases.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.purchaseNumber.toLowerCase().contains(q) || p.supplierName.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    labelText: 'Search Purchase Orders',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddPurchaseDialog(context),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('+ Log Purchase'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Purchase Orders Table Card #FFFFFF with Header #EAEAFF
          Container(
            decoration: BoxDecoration(
              color: AppColors.invoiceCard, // #FFFFFF
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Header #EAEAFF
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.tableHeader, // #EAEAFF
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('PO #', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('Supplier', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Date', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('Restocked Items', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Total Cost', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPurchases.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, index) {
                    final purchase = filteredPurchases[index];
                    final itemSummary = purchase.items.map((i) => '${i.description} (x${i.quantity})').join(', ');

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(purchase.purchaseNumber, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(purchase.supplierName, style: AppTheme.timesFont(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(dateFormatter.format(purchase.date), style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(itemSummary, style: AppTheme.timesFont(fontSize: 13, color: AppColors.textPrimary)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currencyFormatter.format(purchase.totalAmount),
                              textAlign: TextAlign.right,
                              style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
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
  }
}
