import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/clear_data_dialog.dart';
import '../models/shop_profile.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _mobileController;
  late TextEditingController _gstinController;
  late TextEditingController _gstPercentageController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscCodeController;

  String _selectedLogo = 'store';
  String _logoBase64 = '';
  String _selectedPaperSize = '80mm';

  final List<Map<String, dynamic>> _logoOptions = [
    {'id': 'store', 'label': 'General Retail', 'icon': Icons.storefront_rounded},
    {'id': 'pos', 'label': 'POS & Hardware', 'icon': Icons.point_of_sale_rounded},
    {'id': 'tech', 'label': 'Tech & Electronics', 'icon': Icons.devices_other_rounded},
    {'id': 'apparel', 'label': 'Apparel & Fashion', 'icon': Icons.checkroom_rounded},
    {'id': 'mart', 'label': 'Grocery & Mart', 'icon': Icons.shopping_basket_rounded},
    {'id': 'pharma', 'label': 'Pharmacy & Care', 'icon': Icons.medical_services_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<BillingProvider>(context, listen: false).shopProfile;

    _shopNameController = TextEditingController(text: profile.shopName);
    _ownerNameController = TextEditingController(text: profile.ownerName);
    _mobileController = TextEditingController(text: profile.mobile);
    _gstinController = TextEditingController(text: profile.gstin);
    _gstPercentageController = TextEditingController(text: profile.gstPercentage.toStringAsFixed(0));
    _addressController = TextEditingController(text: profile.address);
    _emailController = TextEditingController(text: profile.email);
    _bankNameController = TextEditingController(text: profile.bankName);
    _accountNumberController = TextEditingController(text: profile.accountNumber);
    _ifscCodeController = TextEditingController(text: profile.ifscCode);
    _selectedLogo = profile.logoPreset;
    _logoBase64 = profile.logoBase64;
    _selectedPaperSize = profile.paperSize;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _gstinController.dispose();
    _gstPercentageController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCompressLogoImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
        final bytes = result.files.first.bytes!;
        final base64String = base64Encode(bytes);

        setState(() {
          _logoBase64 = base64String;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Company logo uploaded and compressed for thermal & invoice print header!',
                style: AppTheme.timesFont(),
              ),
              backgroundColor: AppColors.paid,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick logo image: $e', style: AppTheme.timesFont()),
            backgroundColor: AppColors.dueOverdue,
          ),
        );
      }
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<BillingProvider>(context, listen: false);

      final updatedProfile = provider.shopProfile.copyWith(
        shopName: _shopNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        gstin: _gstinController.text.trim(),
        gstPercentage: double.tryParse(_gstPercentageController.text.trim()) ?? 18.0,
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        ifscCode: _ifscCodeController.text.trim(),
        logoPreset: _selectedLogo,
        logoBase64: _logoBase64,
        paperSize: _selectedPaperSize,
        isConfigured: true,
      );

      provider.updateShopProfile(updatedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Company details & 80 mm logo saved successfully! Branding updated across all bills and Firestore.',
            style: AppTheme.timesFont(),
          ),
          backgroundColor: AppColors.paid,
        ),
      );

      provider.setNavIndex(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    final companyId = provider.currentCompanyId ?? provider.shopProfile.companyId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryButton,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.business_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Settings → Company Details',
                                    style: AppTheme.timesFont(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'ID: $companyId',
                                    style: AppTheme.timesFont(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The Shop Name, Address, Mobile, Logo & GSTIN updated here will automatically reflect on top of every bill and save to your company document in Firestore.',
                              style: AppTheme.timesFont(
                                fontSize: 13,
                                color: AppColors.sidebarText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Container #FFFFFF Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.invoiceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Select Company Logo Preset',
                        style: AppTheme.timesFont(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _logoOptions.map((opt) {
                          final isSelected = _selectedLogo == opt['id'];
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedLogo = opt['id'] as String;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryButton.withValues(alpha: 0.1) : AppColors.tableHeader,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryButton : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    opt['icon'] as IconData,
                                    size: 20,
                                    color: isSelected ? AppColors.primaryButton : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    opt['label'] as String,
                                    style: AppTheme.timesFont(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.primaryButton : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Custom Logo Upload for 80 mm Thermal Print Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.print_rounded, size: 20, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Company Logo for 80 mm Thermal Print Top Header',
                                  style: AppTheme.timesFont(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Upload your official store/company logo image. It will be compressed automatically and displayed centered at top size on all 80 mm (3 inch) thermal receipts.',
                              style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            if (_logoBase64.isNotEmpty) ...[
                              Container(
                                height: 70,
                                width: 220,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Center(
                                  child: Image.memory(
                                    base64Decode(_logoBase64),
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickAndCompressLogoImage,
                                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                                  label: Text(
                                    _logoBase64.isNotEmpty ? 'Change 80 mm Logo Image' : 'Upload Company Logo (80 mm Print)',
                                    style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                                if (_logoBase64.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _logoBase64 = '';
                                      });
                                    },
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                    label: Text('Remove', style: AppTheme.timesFont(color: const Color(0xFFDC2626), fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 20),

                      // Bill Paper Size Setting Section
                      Row(
                        children: [
                          Icon(Icons.aspect_ratio_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '2. Bill Paper Size Setting',
                            style: AppTheme.timesFont(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Default: 80mm Thermal',
                              style: AppTheme.timesFont(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select the default paper format for printing and previewing customer bills. Selected size is saved per company.',
                        style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),

                      // Dropdown & Choice Tiles for Paper Size
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPaperSize,
                        decoration: const InputDecoration(
                          labelText: 'Selected Paper Size *',
                          prefixIcon: Icon(Icons.print_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: BillPaperSize.values.map((size) {
                          return DropdownMenuItem<String>(
                            value: size.id,
                            child: Row(
                              children: [
                                Icon(
                                  (size == BillPaperSize.mm58 || size == BillPaperSize.mm80)
                                      ? Icons.receipt_long_rounded
                                      : size == BillPaperSize.mm127
                                          ? Icons.receipt_rounded
                                          : Icons.description_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  size.label,
                                  style: AppTheme.timesFont(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPaperSize = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: BillPaperSize.values.map((size) {
                          final isSelected = _selectedPaperSize == size.id;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPaperSize = size.id;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.tableHeader,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    size.label,
                                    style: AppTheme.timesFont(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => provider.setNavIndex(13),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Printer Settings & Hardware Configuration →'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 20),

                      Text(
                        '3. Company Information',
                        style: AppTheme.timesFont(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _shopNameController,
                              decoration: const InputDecoration(
                                labelText: 'Shop / Company Name *',
                                prefixIcon: Icon(Icons.storefront_rounded),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _ownerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Owner / Contact Person *',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mobileController,
                              decoration: const InputDecoration(
                                labelText: 'Business Mobile Number *',
                                prefixIcon: Icon(Icons.phone_rounded),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _gstinController,
                              decoration: const InputDecoration(
                                labelText: 'GSTIN Number (Optional)',
                                prefixIcon: Icon(Icons.verified_user_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _gstPercentageController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Default Company GST Rate (%) *',
                                prefixIcon: Icon(Icons.percent_rounded),
                                hintText: 'e.g. 18',
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Company Address *',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Business Email Address (Optional)',
                          prefixIcon: Icon(Icons.email_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bank & Payment Details Inputs (Optional / Not Required)
                      Row(
                        children: [
                          Icon(Icons.account_balance_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Bank & Payment Details (Optional)',
                            style: AppTheme.timesFont(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add bank details to show on printed bills & invoices. Leave empty if you do not want bank details on the bill.',
                        style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bankNameController,
                              decoration: const InputDecoration(
                                labelText: 'Bank Name (Optional)',
                                prefixIcon: Icon(Icons.account_balance_rounded),
                                hintText: 'Enter Bank Name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _ifscCodeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'IFSC Code (Optional)',
                                prefixIcon: Icon(Icons.pin_outlined),
                                hintText: 'Enter IFSC Code',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Account Number (Optional)',
                          prefixIcon: Icon(Icons.numbers_rounded),
                          hintText: 'Enter Bank Account Number',
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.save_rounded, size: 20),
                          label: const Text('Save Company Details & Apply Branding'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Danger Zone Data Clearing Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Danger Zone: Data & Storage Management',
                                  style: AppTheme.timesFont(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Permanently clear all invoices, products, customer records, expenses, and supplier data for company "$companyId".',
                              style: AppTheme.timesFont(
                                fontSize: 13,
                                color: const Color(0xFF7F1D1D),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => showClearAllDataConfirmationDialog(context),
                              icon: const Icon(Icons.delete_forever_rounded, size: 18),
                              label: const Text('Clear All Company Data'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
