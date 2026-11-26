import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String _searchQuery = '';

  void _showAddSupplierDialog(BuildContext context) {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final balanceController = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.invoiceCard, // #FFFFFF
          title: Text(
            'Add New Supplier / Vendor',
            style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: companyController,
                    decoration: const InputDecoration(labelText: 'Supplier Company Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Contact Person Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number *'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Warehouse / Factory Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Initial Balance Payable (₹)'),
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
                if (companyController.text.trim().isNotEmpty && phoneController.text.trim().isNotEmpty) {
                  final provider = Provider.of<BillingProvider>(context, listen: false);
                  provider.addSupplier(
                    Supplier(
                      id: const Uuid().v4(),
                      name: nameController.text.trim().isEmpty ? companyController.text.trim() : nameController.text.trim(),
                      companyName: companyController.text.trim(),
                      phone: phoneController.text.trim(),
                      email: emailController.text.trim(),
                      address: addressController.text.trim(),
                      balanceDue: double.tryParse(balanceController.text) ?? 0.0,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Supplier'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final provider = Provider.of<BillingProvider>(context);

    final filteredSuppliers = provider.suppliers.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.companyName.toLowerCase().contains(q) || s.name.toLowerCase().contains(q) || s.phone.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Add Supplier Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    labelText: 'Search Suppliers',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddSupplierDialog(context),
                icon: const Icon(Icons.domain_add_rounded, size: 18),
                label: const Text('+ Add Supplier'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Total Payable Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.invoiceCard, // #FFFFFF
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Supplier Accounts Payable',
                      style: AppTheme.timesFont(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(provider.totalSupplierDues),
                      style: AppTheme.timesFont(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dueOverdue,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary, // #CCCCFF
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.factory_rounded, color: AppColors.primary, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Suppliers Table Card #FFFFFF with Header #EAEAFF
          Container(
            decoration: BoxDecoration(
              color: AppColors.invoiceCard, // #FFFFFF
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Table Header #EAEAFF
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
                        flex: 3,
                        child: Text('Supplier Company', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('Contact Person & Phone', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text('Warehouse Address', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Balance Payable', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredSuppliers.length,
                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, index) {
                    final supplier = filteredSuppliers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.secondary,
                                  child: Text(
                                    supplier.companyName.substring(0, 1).toUpperCase(),
                                    style: AppTheme.timesFont(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    supplier.companyName,
                                    style: AppTheme.timesFont(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier.name,
                                  style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                Text(
                                  supplier.phone,
                                  style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              supplier.address,
                              style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currencyFormatter.format(supplier.balanceDue),
                              textAlign: TextAlign.right,
                              style: AppTheme.timesFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: supplier.balanceDue > 0 ? AppColors.dueOverdue : AppColors.paid,
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
  }
}
