import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../providers/billing_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_preview_dialog.dart';
import '../widgets/product_search_modal.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _invoiceNumber;
  bool _initializedInvoiceNumber = false;
  Customer? _selectedCustomer;
  final _customNameController = TextEditingController();
  final _customPhoneController = TextEditingController();
  final _customEmailController = TextEditingController();

  final DateTime _issueDate = DateTime.now();

  InvoiceStatus _selectedStatus = InvoiceStatus.paid;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  final _paymentRefController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isGstBill = true;
  double _taxPercent = 18.0;
  bool _isDiscountPercent = true; // true: %, false: ₹ flat amount
  final TextEditingController _discountController = TextEditingController();

  final List<_InvoiceLineItemInput> _lineItems = [];
  final TextEditingController _productSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lineItems.add(_InvoiceLineItemInput(emptyByDefault: _selectedStatus == InvoiceStatus.quotation));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedInvoiceNumber) {
      final provider = Provider.of<BillingProvider>(context, listen: false);
      _invoiceNumber = 'INV-${1000 + provider.invoices.length + 1}';
      _taxPercent = provider.shopProfile.gstPercentage;
      _initializedInvoiceNumber = true;
    }
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _customPhoneController.dispose();
    _customEmailController.dispose();
    _paymentRefController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    _discountController.dispose();
    for (var item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addProductToBill(Product p) {
    setState(() {
      final cleanPSize = (p.size.trim().isEmpty || p.size.trim() == 'Free Size' || p.size.trim() == 'N/A' || p.size.trim().toLowerCase() == 'none')
          ? ''
          : p.size.trim();

      final existingIdx = _lineItems.indexWhere((item) {
        final matchesName = item.descriptionController.text.trim().toLowerCase() == p.name.trim().toLowerCase();
        final matchesPrice = (double.tryParse(item.priceController.text) ?? 0.0) == p.unitPrice;
        final matchesSize = item.size.trim().toLowerCase() == cleanPSize.toLowerCase();
        return matchesName && matchesPrice && matchesSize;
      });

      if (existingIdx != -1) {
        final currentQty = int.tryParse(_lineItems[existingIdx].quantityController.text) ?? 0;
        _lineItems[existingIdx].quantityController.text = (currentQty + 1).toString();
      } else {
        if (_lineItems.length == 1 && _lineItems[0].descriptionController.text.trim().isEmpty) {
          _lineItems[0].populateFromProduct(p);
        } else {
          final newItem = _InvoiceLineItemInput();
          newItem.populateFromProduct(p);
          _lineItems.add(newItem);
        }
      }
    });

    final sizeInfo = p.size.trim().isNotEmpty && p.size.trim() != 'Free Size' ? ' (${p.size.trim()})' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${p.name}$sizeInfo" to bill!', style: AppTheme.timesFont()),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _updateProductQuantityInBill(Product p, int newQty) {
    setState(() {
      final cleanPSize = (p.size.trim().isEmpty || p.size.trim() == 'Free Size' || p.size.trim() == 'N/A' || p.size.trim().toLowerCase() == 'none')
          ? ''
          : p.size.trim();

      final existingIdx = _lineItems.indexWhere((item) {
        final matchesName = item.descriptionController.text.trim().toLowerCase() == p.name.trim().toLowerCase();
        final matchesPrice = (double.tryParse(item.priceController.text) ?? 0.0) == p.unitPrice;
        final matchesSize = item.size.trim().toLowerCase() == cleanPSize.toLowerCase();
        return matchesName && matchesPrice && matchesSize;
      });

      if (existingIdx != -1) {
        if (newQty <= 0) {
          _lineItems.removeAt(existingIdx);
          if (_lineItems.isEmpty) {
            _lineItems.add(_InvoiceLineItemInput(emptyByDefault: _selectedStatus == InvoiceStatus.quotation));
          }
        } else {
          _lineItems[existingIdx].quantityController.text = newQty.toString();
        }
      } else if (newQty > 0) {
        if (_lineItems.length == 1 && _lineItems[0].descriptionController.text.trim().isEmpty) {
          _lineItems[0].populateFromProduct(p);
          _lineItems[0].quantityController.text = newQty.toString();
        } else {
          final newItem = _InvoiceLineItemInput();
          newItem.populateFromProduct(p);
          newItem.quantityController.text = newQty.toString();
          _lineItems.add(newItem);
        }
      }
    });
  }

  Map<String, int> _buildCurrentBillProductQuantities(List<Product> products) {
    final Map<String, int> map = {};
    for (var lineItem in _lineItems) {
      final name = lineItem.descriptionController.text.trim().toLowerCase();
      if (name.isEmpty) continue;
      final qty = int.tryParse(lineItem.quantityController.text) ?? 0;
      if (qty <= 0) continue;
      final price = double.tryParse(lineItem.priceController.text) ?? 0.0;
      final size = lineItem.size.trim().toLowerCase();

      // Find matching product variant by Name + Price + Size
      int pIndex = products.indexWhere((p) {
        final matchesName = p.name.trim().toLowerCase() == name;
        final matchesPrice = (p.unitPrice - price).abs() < 0.01;
        final pSize = (p.size.trim().isEmpty || p.size.trim() == 'Free Size' || p.size.trim() == 'N/A' || p.size.trim().toLowerCase() == 'none')
            ? ''
            : p.size.trim().toLowerCase();
        return matchesName && matchesPrice && pSize == size;
      });

      // Fallback matching
      if (pIndex == -1) {
        pIndex = products.indexWhere((p) => p.name.trim().toLowerCase() == name);
      }

      if (pIndex != -1) {
        map[products[pIndex].id] = (map[products[pIndex].id] ?? 0) + qty;
      }
    }
    return map;
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get _taxAmount => _isGstBill ? (_subtotal * _taxPercent) / 100.0 : 0.0;

  double get _parsedDiscountInput {
    final text = _discountController.text.trim();
    return double.tryParse(text) ?? 0.0;
  }

  double get _discountPercent {
    if (_isDiscountPercent) {
      return _parsedDiscountInput.clamp(0.0, 100.0);
    } else {
      if (_subtotal <= 0) return 0.0;
      return ((_discountAmount / _subtotal) * 100.0).clamp(0.0, 100.0);
    }
  }

  double get _discountAmount {
    if (_isDiscountPercent) {
      return (_subtotal * _discountPercent) / 100.0;
    } else {
      return _parsedDiscountInput.clamp(0.0, _subtotal);
    }
  }

  double get _grandTotal {
    final grand = _subtotal + _taxAmount - _discountAmount;
    return grand < 0 ? 0.0 : grand;
  }

  void _saveInvoice({bool printImmediately = false}) {
    final validItems = _lineItems.where((i) => i.descriptionController.text.trim().isNotEmpty).toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one product item to the bill.', style: AppTheme.timesFont()),
          backgroundColor: AppColors.dueOverdue,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final provider = Provider.of<BillingProvider>(context, listen: false);

      String custId;
      String custName;
      String custPhone;
      String custEmail;

      if (_selectedCustomer != null) {
        custId = _selectedCustomer!.id;
        custName = _selectedCustomer!.name;
        custPhone = _selectedCustomer!.phone;
        custEmail = _selectedCustomer!.email;
      } else {
        custId = const Uuid().v4();
        custName = _customNameController.text.trim();
        custPhone = _customPhoneController.text.trim();
        custEmail = _customEmailController.text.trim();
      }

      final items = validItems.map((input) {
        final itemDiscount = double.tryParse(input.discountController.text.trim()) ?? 0.0;
        return InvoiceItem(
          id: const Uuid().v4(),
          description: input.descriptionController.text.trim(),
          quantity: int.tryParse(input.quantityController.text) ?? 1,
          unitPrice: double.tryParse(input.priceController.text) ?? 0.0,
          discount: itemDiscount,
          mrpPrice: input.mrpPrice,
          costPrice: input.costPrice,
          unit: input.unit,
          size: input.size,
          color: input.color,
        );
      }).toList();

      final currentDiscountPercent = _discountPercent;
      final currentDiscountAmount = _discountAmount;

      final newInvoice = Invoice(
        id: const Uuid().v4(),
        invoiceNumber: _invoiceNumber,
        customerId: custId,
        customerName: custName.isNotEmpty ? custName : 'Walk-in Customer',
        customerEmail: custEmail,
        customerPhone: custPhone,
        issueDate: _issueDate,
        dueDate: _issueDate,
        items: items,
        taxPercent: _isGstBill ? _taxPercent : 0.0,
        discountPercent: currentDiscountPercent,
        discountAmountValue: !_isDiscountPercent ? currentDiscountAmount : 0.0,
        isGstBill: _isGstBill,
        status: _selectedStatus,
        paymentMethod: _selectedPaymentMethod,
        paymentRef: _paymentRefController.text.trim(),
        notes: _notesController.text.trim(),
      );

      provider.addInvoice(newInvoice);

      if (printImmediately) {
        showDialog(
          context: context,
          builder: (context) => InvoicePreviewDialog(invoice: newInvoice),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (dialogCtx) {
          final isQuotation = newInvoice.status == InvoiceStatus.quotation;

          return AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Icon(
                  isQuotation ? Icons.request_quote_rounded : Icons.check_circle,
                  color: isQuotation ? Colors.purple.shade700 : AppColors.paid,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  isQuotation ? 'Quotation Saved Successfully!' : 'Bill Saved Successfully!',
                  style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isQuotation ? "Quotation" : "Invoice"} Number: $_invoiceNumber',
                  style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Customer: ${newInvoice.customerName} (${newInvoice.customerPhone.isEmpty ? 'No Phone' : newInvoice.customerPhone})',
                  style: AppTheme.timesFont(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  'Total Amount: ₹${_grandTotal.toStringAsFixed(2)}',
                  style: AppTheme.timesFont(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            actions: [
              if (isQuotation) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    PdfService.downloadOrSharePdf(
                      invoice: newInvoice,
                      shopProfile: provider.shopProfile,
                      context: context,
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Download A4 PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    showDialog(
                      context: context,
                      builder: (context) => InvoicePreviewDialog(invoice: newInvoice),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Preview / Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    provider.setNavIndex(12); // Quotations Module
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton),
                  child: const Text('View Quotations'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    PdfService.downloadOrSharePdf(
                      invoice: newInvoice,
                      shopProfile: provider.shopProfile,
                      paperSize: provider.shopProfile.paperSizeEnum,
                      context: context,
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    showDialog(
                      context: context,
                      builder: (context) => InvoicePreviewDialog(invoice: newInvoice),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text('Print Bill (${provider.shopProfile.paperSizeEnum.label})'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
                if (newInvoice.customerPhone.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      provider.shareInvoiceToWhatsApp(newInvoice);
                      provider.setNavIndex(1);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('WhatsApp Bill'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                  ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    provider.setNavIndex(1);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton),
                  child: const Text('View All Bills'),
                ),
              ],
            ],
          );
        },
      );
    }
  }

  Widget _buildCustomerCard(bool isMobile, BillingProvider provider) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Customer Details',
                style: AppTheme.timesFont(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<Customer?>(
            initialValue: _selectedCustomer,
            decoration: const InputDecoration(
              labelText: 'Select Existing Customer (Optional)',
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: [
              const DropdownMenuItem<Customer?>(
                value: null,
                child: Text('+ New / Walk-in Customer'),
              ),
              ...provider.customers.map((c) {
                return DropdownMenuItem<Customer?>(
                  value: c,
                  child: Text('${c.name} (${c.phone.isEmpty ? 'No Phone' : c.phone})'),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                _selectedCustomer = val;
                if (val != null) {
                  _customNameController.text = val.name;
                  _customPhoneController.text = val.phone;
                  _customEmailController.text = val.email;
                } else {
                  _customNameController.clear();
                  _customPhoneController.clear();
                  _customEmailController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 14),

          if (isMobile) ...[
            TextFormField(
              controller: _customNameController,
              decoration: InputDecoration(
                labelText: 'Customer Name *',
                prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number (WhatsApp)',
                prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 18),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name *',
                      prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _customPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (WhatsApp)',
                      prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchProductsCard(bool isMobile, BillingProvider provider, BoxConstraints constraints) {
    final currentBillQuantities = _buildCurrentBillProductQuantities(provider.products);

    void openModal({String? category}) {
      TrendingProductSearchModal.show(
        context,
        initialSelectedQuantities: currentBillQuantities,
        initialCategory: category,
        onAddProduct: (product) => _addProductToBill(product),
        onUpdateQuantity: (product, newQty) => _updateProductQuantityInBill(product, newQty),
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.manage_search_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search & Select Products',
                      style: AppTheme.timesFont(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${provider.products.length} products available in catalog (or manually type below)',
                      style: AppTheme.timesFont(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => openModal(),
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text('Catalog Modal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          InkWell(
            onTap: () => openModal(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search product by Name, SKU, Category or scan barcode...',
                      style: AppTheme.timesFont(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillItemsCard(bool isMobile, BillingProvider provider, NumberFormat currencyFormatter) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Products in ${_selectedStatus == InvoiceStatus.quotation ? "Quotation" : "Bill"} (${_lineItems.length})',
                  style: AppTheme.timesFont(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _lineItems.add(_InvoiceLineItemInput(emptyByDefault: _selectedStatus == InvoiceStatus.quotation));
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lineItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final item = _lineItems[idx];
              final itemTotal = item.totalPrice;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Item #${idx + 1}',
                            style: AppTheme.timesFont(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (item.size.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Size: ${item.size.trim()}',
                              style: AppTheme.timesFont(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          'Total: ',
                          style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          currencyFormatter.format(itemTotal),
                          style: AppTheme.timesFont(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dueOverdue, size: 20),
                          tooltip: 'Remove Item',
                          onPressed: _lineItems.length > 1
                              ? () {
                                  setState(() {
                                    _lineItems.removeAt(idx);
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: item.descriptionController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Product / Item Name *',
                        hintText: 'Enter item description or search product above',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: item.quantityController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: item.priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Rate (₹)',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: item.discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Discount (₹)',
                              hintText: '0',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isMobile, NumberFormat currencyFormatter) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calculate_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Payment & Status Summary',
                style: AppTheme.timesFont(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bill Type Selection: GST Bill (With GST) vs Non-GST Bill (Without GST)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.tableHeader,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isGstBill = true;
                        if (_taxPercent == 0) {
                          final provider = Provider.of<BillingProvider>(context, listen: false);
                          _taxPercent = provider.shopProfile.gstPercentage > 0
                              ? provider.shopProfile.gstPercentage
                              : 18.0;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isGstBill ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 16,
                            color: _isGstBill ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'With GST Bill',
                            style: AppTheme.timesFont(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isGstBill ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isGstBill = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isGstBill ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_rounded,
                            size: 16,
                            color: !_isGstBill ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Without GST Bill',
                            style: AppTheme.timesFont(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_isGstBill ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal:', style: AppTheme.timesFont(fontSize: 14, color: AppColors.textSecondary)),
              Text(currencyFormatter.format(_subtotal), style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),

          if (_isGstBill) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GST Tax Rate (%):', style: AppTheme.timesFont(fontSize: 14, color: AppColors.textSecondary)),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    key: ValueKey('gst_rate_$_taxPercent'),
                    initialValue: _taxPercent.toStringAsFixed(0),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    onChanged: (val) {
                      setState(() {
                        _taxPercent = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GST Amount (${_taxPercent.toStringAsFixed(0)}%):', style: AppTheme.timesFont(fontSize: 14, color: AppColors.textSecondary)),
                Text(currencyFormatter.format(_taxAmount), style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Overall Bill Discount with % and ₹ Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Overall Discount:', style: AppTheme.timesFont(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.tableHeader,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (!_isDiscountPercent) {
                              setState(() {
                                _isDiscountPercent = true;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isDiscountPercent ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '%',
                              style: AppTheme.timesFont(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isDiscountPercent ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (_isDiscountPercent) {
                              setState(() {
                                _isDiscountPercent = false;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: !_isDiscountPercent ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '₹',
                              style: AppTheme.timesFont(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: !_isDiscountPercent ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0',
                    prefixText: _isDiscountPercent ? '' : '₹',
                    suffixText: _isDiscountPercent ? '%' : '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isDiscountPercent
                      ? 'Discount Amount (${_discountPercent.toStringAsFixed(0)}%):'
                      : 'Discount Amount (Flat):',
                  style: AppTheme.timesFont(fontSize: 13, color: AppColors.paid, fontWeight: FontWeight.w600),
                ),
                Text(
                  '-${currencyFormatter.format(_discountAmount)}',
                  style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.paid),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total:',
                style: AppTheme.timesFont(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                currencyFormatter.format(_grandTotal),
                style: AppTheme.timesFont(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),

         Row(
  children: [
    Expanded(
      child: DropdownButtonFormField<PaymentMethod>(
        isExpanded: true, // Add this
        initialValue: _selectedPaymentMethod,
        decoration: const InputDecoration(
          labelText: 'Payment Mode',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
        ),
        items: PaymentMethod.values.map((pm) {
          return DropdownMenuItem(
            value: pm,
            child: Text(
              pm.label,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _selectedPaymentMethod = val);
          }
        },
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: DropdownButtonFormField<InvoiceStatus>(
        isExpanded: true, // Add this
        initialValue: _selectedStatus,
        decoration: const InputDecoration(
          labelText: 'Status',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
        ),
        items: [
          DropdownMenuItem(
            value: InvoiceStatus.paid,
            child: Text(
              'Paid',
              overflow: TextOverflow.ellipsis,
              style: AppTheme.timesFont(
                color: AppColors.paid,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DropdownMenuItem(
            value: InvoiceStatus.pending,
            child: Text(
              'Pending Khata',
              overflow: TextOverflow.ellipsis,
              style: AppTheme.timesFont(
                color: AppColors.pending,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DropdownMenuItem(
            value: InvoiceStatus.quotation,
            child: Text(
              'Quotation',
              overflow: TextOverflow.ellipsis,
              style: AppTheme.timesFont(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedStatus = val;
              if (val == InvoiceStatus.quotation &&
                  _lineItems.length == 1 &&
                  _lineItems[0].descriptionController.text.isEmpty) {
                _lineItems[0].quantityController.clear();
                _lineItems[0].priceController.clear();
                _lineItems[0].discountController.clear();
              }
            });
          }
        },
      ),
    ),
  ],
),
          const SizedBox(height: 20),

          if (_selectedStatus != InvoiceStatus.quotation) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveInvoice(printImmediately: true),
                    icon: const Icon(Icons.print_rounded, size: 20),
                    label: const Text('Save & Print Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveInvoice(printImmediately: false),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('Save & Issue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveInvoice(printImmediately: false),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 22),
                label: const Text('Save & Generate Quotation (A4 PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final provider = Provider.of<BillingProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;
        final isDesktopSplit = constraints.maxWidth >= 1000;

        final customerCard = _buildCustomerCard(isMobile, provider);
        final searchProductsCard = _buildSearchProductsCard(isMobile, provider, constraints);
        final billItemsCard = _buildBillItemsCard(isMobile, provider, currencyFormatter);
        final summaryCard = _buildSummaryCard(isMobile, currencyFormatter);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedStatus == InvoiceStatus.quotation ? 'Create Quotation / Estimate' : 'Create New Bill',
                      style: AppTheme.timesFont(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: _selectedStatus == InvoiceStatus.quotation ? Colors.purple.shade700 : AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tableHeader,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Invoice #: $_invoiceNumber',
                        style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (isDesktopSplit)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            customerCard,
                            const SizedBox(height: 16),
                            searchProductsCard,
                            const SizedBox(height: 16),
                            billItemsCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            summaryCard,
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  customerCard,
                  const SizedBox(height: 16),
                  searchProductsCard,
                  const SizedBox(height: 16),
                  billItemsCard,
                  const SizedBox(height: 16),
                  summaryCard,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InvoiceLineItemInput {
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController();
  final priceController = TextEditingController();
  final discountController = TextEditingController();
  String unit = 'Pcs';
  String size = '';
  String color = '';

  double mrpPrice = 0.0;
  double costPrice = 0.0;

  _InvoiceLineItemInput({bool emptyByDefault = false}) {
    // Keep quantity input field empty by default
    quantityController.text = '';
    priceController.text = '';
    discountController.text = '';
  }

  void populateFromProduct(Product p) {
    descriptionController.text = p.name;
    priceController.text = p.unitPrice.toStringAsFixed(2);
    quantityController.text = '1';
    discountController.text = '';
    mrpPrice = p.mrpPrice;
    costPrice = p.unitCostPrice;
    final cleanSize = p.size.trim();
    size = (cleanSize.isEmpty || cleanSize == 'Free Size' || cleanSize == 'N/A' || cleanSize.toLowerCase() == 'none')
        ? ''
        : cleanSize;
    color = p.color.trim();
    unit = p.unit;
  }

  double get discount => double.tryParse(discountController.text.trim()) ?? 0.0;
  double get grossPrice => (int.tryParse(quantityController.text.trim()) ?? 0) * (double.tryParse(priceController.text.trim()) ?? 0.0);

  double get totalPrice {
    final total = grossPrice - discount;
    return total < 0 ? 0.0 : total;
  }

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();
    discountController.dispose();
  }
}
