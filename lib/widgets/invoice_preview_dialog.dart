import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../models/shop_profile.dart';
import '../providers/billing_provider.dart';
import '../services/pdf_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class InvoicePreviewDialog extends StatefulWidget {
  final Invoice invoice;
  final BillPaperSize? initialPaperSize;

  const InvoicePreviewDialog({
    super.key,
    required this.invoice,
    this.initialPaperSize,
  });

  @override
  State<InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<InvoicePreviewDialog> {
  late BillPaperSize _selectedPaperSize;
  bool _initializedSize = false;
  bool _isPrinting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedSize) {
      final provider = Provider.of<BillingProvider>(context, listen: false);
      _selectedPaperSize = widget.initialPaperSize ?? provider.shopProfile.paperSizeEnum;
      _initializedSize = true;
    }
  }

  IconData _getShopLogoIcon(String logoPreset) {
    switch (logoPreset) {
      case 'pos':
        return Icons.point_of_sale_rounded;
      case 'tech':
        return Icons.devices_other_rounded;
      case 'apparel':
        return Icons.checkroom_rounded;
      case 'mart':
        return Icons.shopping_basket_rounded;
      case 'pharma':
        return Icons.medical_services_rounded;
      case 'store':
      default:
        return Icons.storefront_rounded;
    }
  }

  Future<void> _printBill(BuildContext context, BillingProvider provider) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      // 1. If thermal paper size (58mm or 80mm), prioritize Bluetooth / Serial / Default thermal print
      if (_selectedPaperSize == BillPaperSize.mm58 || _selectedPaperSize == BillPaperSize.mm80) {
        bool success = false;
        try {
          success = await BluetoothPrinterService.directPrint(
            invoice: widget.invoice,
            shopProfile: provider.shopProfile,
            paperSize: _selectedPaperSize,
          );
        } catch (e) {
          debugPrint('Direct thermal print error: $e, falling back to spooler/PDF printing...');
        }

        if (success && context.mounted) {
          final devName = BluetoothPrinterService.connectedDeviceName ?? 'Thermal Receipt Printer';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receipt printed to $devName (${_selectedPaperSize.label})',
                      style: AppTheme.timesFont(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.paid,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      // 2. Standard document / Canon A4 or System Spooler printing
      final printedPrinter = await PdfService.printPdf(
        invoice: widget.invoice,
        shopProfile: provider.shopProfile,
        paperSize: _selectedPaperSize,
      );
      if (context.mounted) {
        if (printedPrinter != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bill sent directly to ${printedPrinter.name}',
                      style: AppTheme.timesFont(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.paid,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Print dialog opened.',
                      style: AppTheme.timesFont(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.paid,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e', style: AppTheme.timesFont()),
            backgroundColor: AppColors.dueOverdue,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final provider = Provider.of<BillingProvider>(context);
    final shop = provider.shopProfile;
    final invoice = widget.invoice;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: BoxConstraints(maxWidth: _selectedPaperSize.widthPx.clamp(480.0, 880.0)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header Bar with Paper Size Switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.tableHeader, // #F1F5F9
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Bill Preview',
                        style: AppTheme.timesFont(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Paper Size Dropdown Switcher
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<BillPaperSize>(
                          value: _selectedPaperSize,
                          isDense: true,
                          icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                          items: BillPaperSize.values.map((size) {
                            return DropdownMenuItem<BillPaperSize>(
                              value: size,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    (size == BillPaperSize.mm58 || size == BillPaperSize.mm80)
                                        ? Icons.receipt_long_rounded
                                        : size == BillPaperSize.mm127
                                            ? Icons.receipt_rounded
                                            : Icons.description_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    size.label,
                                    style: AppTheme.timesFont(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newSize) {
                            if (newSize != null) {
                              setState(() {
                                _selectedPaperSize = newSize;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    StatusBadge(status: invoice.status),
                    const SizedBox(width: 8),

                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Dynamic Paper Layout Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _selectedPaperSize == BillPaperSize.mm58
                            ? 340.0
                            : _selectedPaperSize == BillPaperSize.mm80
                                ? 420.0
                                : double.infinity,
                      ),
                      child: _buildPaperLayout(
                        paperSize: _selectedPaperSize,
                        shop: shop,
                        invoice: invoice,
                        currencyFormatter: currencyFormatter,
                        dateFormatter: dateFormatter,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Actions Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status Quick Changer
                      PopupMenuButton<InvoiceStatus>(
                        initialValue: invoice.status,
                        onSelected: (newStatus) {
                          provider.updateInvoiceStatus(invoice.id, newStatus);
                          Navigator.of(context).pop();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: InvoiceStatus.paid,
                            child: Text('Mark as Paid', style: AppTheme.timesFont(color: AppColors.paid, fontWeight: FontWeight.bold)),
                          ),
                          PopupMenuItem(
                            value: InvoiceStatus.pending,
                            child: Text('Mark as Pending', style: AppTheme.timesFont(color: AppColors.pending, fontWeight: FontWeight.bold)),
                          ),
                          PopupMenuItem(
                            value: InvoiceStatus.overdue,
                            child: Text('Mark as Due / Overdue', style: AppTheme.timesFont(color: AppColors.dueOverdue, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note_rounded, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('Status', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.w600)),
                              const Icon(Icons.arrow_drop_down_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // WhatsApp Share Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final success = await provider.shareInvoiceToWhatsApp(invoice);
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open WhatsApp link.', style: AppTheme.timesFont())),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text('WhatsApp', style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.paid),
                      ),
                      const SizedBox(width: 8),

                      // Download PDF Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          await PdfService.downloadOrSharePdf(
                            invoice: invoice,
                            shopProfile: shop,
                            paperSize: _selectedPaperSize,
                            context: context,
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text('Download PDF', style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 8),

                      // Print Bill Button
                      ElevatedButton.icon(
                        onPressed: _isPrinting ? null : () => _printBill(context, provider),
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print_rounded, size: 16),
                        label: Text(
                          _isPrinting ? 'Printing...' : 'Print ${_selectedPaperSize.label}',
                          style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                      const SizedBox(width: 8),

                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close', style: AppTheme.timesFont(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperLayout({
    required BillPaperSize paperSize,
    required ShopProfile shop,
    required Invoice invoice,
    required NumberFormat currencyFormatter,
    required DateFormat dateFormatter,
  }) {
    switch (paperSize) {
      case BillPaperSize.mm58:
        return _build58mmThermalLayout(shop, invoice, currencyFormatter, dateFormatter);
      case BillPaperSize.mm80:
        return _build80mmThermalLayout(shop, invoice, currencyFormatter, dateFormatter);
      case BillPaperSize.mm127:
        return _build127mmLayout(shop, invoice, currencyFormatter, dateFormatter);
      case BillPaperSize.a5:
        return _buildA5Layout(shop, invoice, currencyFormatter, dateFormatter);
      case BillPaperSize.a4:
        return _buildA4Layout(shop, invoice, currencyFormatter, dateFormatter);
    }
  }

  Widget _buildDashedLine([String char = '-']) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.maxWidth;
          const dashWidth = 5.0;
          const dashGap = 3.0;
          final dashCount = (boxWidth / (dashWidth + dashGap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount > 0 ? dashCount : 1, (_) {
              return SizedBox(
                width: dashWidth,
                height: char == '=' ? 1.5 : 1.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: char == '=' ? Colors.black87 : Colors.black45,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // --- 0. 58mm Thermal Layout ---
  Widget _build58mmThermalLayout(ShopProfile shop, Invoice invoice, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFA), // Thermal receipt paper tint
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (shop.logoBase64.isNotEmpty) ...[
            SizedBox(
              height: 40,
              width: 120,
              child: Image.memory(
                base64Decode(shop.logoBase64),
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            shop.shopName.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 2),
          if (shop.address.isNotEmpty)
            Text(shop.address, textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black87)),
          Text(
            'Mob: ${shop.mobile}${(invoice.isGstBill && shop.gstin.trim().isNotEmpty) ? ' • GST: ${shop.gstin}' : ''}',
            textAlign: TextAlign.center,
            style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black87),
          ),
          if (shop.email.trim().isNotEmpty)
            Text('Email: ${shop.email}', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(
            invoice.status == InvoiceStatus.quotation
                ? '*** QUOTATION ***'
                : (invoice.isGstBill ? '*** TAX INVOICE ***' : '*** RETAIL BILL ***'),
            textAlign: TextAlign.center,
            style: AppTheme.timesFont(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          _buildDashedLine('-'),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BILL#: ${invoice.invoiceNumber}', style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(dateFormatter.format(invoice.issueDate), style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black87)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CUST: ${invoice.customerName}', style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black87)),
              Text('PAY: ${invoice.paymentMethod.label.toUpperCase()}', style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          if (invoice.customerPhone.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('PHONE: ${invoice.customerPhone}', style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black87)),
            ),
          const SizedBox(height: 4),
          _buildDashedLine('-'),

          // Items Table Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('ITEM', style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          _buildDashedLine('-'),

          ...invoice.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: Text(item.fullDescription, style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black))),
                      Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black))),
                      Expanded(flex: 2, child: Text(item.unitPrice.toStringAsFixed(0), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black))),
                      Expanded(flex: 2, child: Text(item.totalPrice.toStringAsFixed(0), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black))),
                    ],
                  ),
                  if (item.discount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '  (Item Disc: -₹${item.discount.toStringAsFixed(2)})',
                        style: AppTheme.timesFont(fontSize: 8.5, color: Colors.black54, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            );
          }),

          _buildDashedLine('-'),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SUBTOTAL:', style: AppTheme.timesFont(fontSize: 9.5)),
              Text(invoice.subtotal.toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold)),
            ],
          ),
          if (invoice.taxAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', style: AppTheme.timesFont(fontSize: 9.5)),
                Text((invoice.taxAmount / 2).toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', style: AppTheme.timesFont(fontSize: 9.5)),
                Text((invoice.taxAmount / 2).toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (invoice.discountAmount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.discountPercent > 0
                      ? 'DISCOUNT (${invoice.discountPercent.toStringAsFixed(invoice.discountPercent % 1 == 0 ? 0 : 1)}%):'
                      : 'DISCOUNT:',
                  style: AppTheme.timesFont(fontSize: 9.5),
                ),
                Text('-${invoice.discountAmount.toStringAsFixed(2)}', style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold)),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL AMOUNT:', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(invoice.totalAmount.toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),

          if (shop.bankName.isNotEmpty || shop.accountNumber.isNotEmpty || shop.ifscCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildDashedLine('-'),
            Text('BANK PAYMENT DETAILS', style: AppTheme.timesFont(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.black)),
            if (shop.bankName.isNotEmpty) Text('Bank: ${shop.bankName}', style: AppTheme.timesFont(fontSize: 8, color: Colors.black87)),
            if (shop.accountNumber.isNotEmpty) Text('A/C No: ${shop.accountNumber}', style: AppTheme.timesFont(fontSize: 8, color: Colors.black87)),
            if (shop.ifscCode.isNotEmpty) Text('IFSC: ${shop.ifscCode}', style: AppTheme.timesFont(fontSize: 8, color: Colors.black87)),
          ],

          const SizedBox(height: 6),
          _buildDashedLine('='),
          const SizedBox(height: 4),
          Text('Thank You! Visit Again', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (shop.shopName.isNotEmpty)
            Text(shop.shopName, textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text('Paper Size: 58 mm Thermal', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 8.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // --- 1. 80mm Thermal Layout ---
  Widget _build80mmThermalLayout(ShopProfile shop, Invoice invoice, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFA), // Thermal receipt paper tint
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (shop.logoBase64.isNotEmpty) ...[
            SizedBox(
              height: 55,
              width: 160,
              child: Image.memory(
                base64Decode(shop.logoBase64),
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            shop.shopName.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 2),
          Text(shop.address, textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 11, color: Colors.black87)),
          Text(
            'Mobile: ${shop.mobile}${(invoice.isGstBill && shop.gstin.trim().isNotEmpty) ? ' • GSTIN: ${shop.gstin}' : ''}',
            textAlign: TextAlign.center,
            style: AppTheme.timesFont(fontSize: 11, color: Colors.black87),
          ),
          if (shop.email.trim().isNotEmpty)
            Text('Email: ${shop.email}', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 11, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(
            invoice.status == InvoiceStatus.quotation
                ? '*** QUOTATION ***'
                : (invoice.isGstBill ? '*** TAX INVOICE ***' : '*** RETAIL BILL (NON-GST) ***'),
            textAlign: TextAlign.center,
            style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          _buildDashedLine('-'),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BILL NO: ${invoice.invoiceNumber}', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(dateFormatter.format(invoice.issueDate), style: AppTheme.timesFont(fontSize: 11, color: Colors.black87)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CUSTOMER: ${invoice.customerName}', style: AppTheme.timesFont(fontSize: 11, color: Colors.black87)),
              Text('PAY: ${invoice.paymentMethod.label.toUpperCase()}', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          if (invoice.customerPhone.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('PHONE: ${invoice.customerPhone}', style: AppTheme.timesFont(fontSize: 11, color: Colors.black87)),
            ),
          const SizedBox(height: 4),
          _buildDashedLine('-'),

          // Items Table Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('ITEM NAME', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('PRICE', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          _buildDashedLine('-'),

          ...invoice.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(flex: 4, child: Text(item.fullDescription, style: AppTheme.timesFont(fontSize: 11, color: Colors.black))),
                      Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 11, color: Colors.black))),
                      Expanded(flex: 2, child: Text(item.unitPrice.toStringAsFixed(0), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11, color: Colors.black))),
                      Expanded(flex: 2, child: Text(item.totalPrice.toStringAsFixed(0), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                    ],
                  ),
                  if (item.discount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '  (Item Disc: -₹${item.discount.toStringAsFixed(2)})',
                        style: AppTheme.timesFont(fontSize: 9.5, color: Colors.black54, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            );
          }),

          _buildDashedLine('-'),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SUBTOTAL:', style: AppTheme.timesFont(fontSize: 11)),
              Text(invoice.subtotal.toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          if (invoice.taxAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', style: AppTheme.timesFont(fontSize: 11)),
                Text((invoice.taxAmount / 2).toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', style: AppTheme.timesFont(fontSize: 11)),
                Text((invoice.taxAmount / 2).toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (invoice.discountAmount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.discountPercent > 0
                      ? 'DISCOUNT (${invoice.discountPercent.toStringAsFixed(invoice.discountPercent % 1 == 0 ? 0 : 1)}%):'
                      : 'DISCOUNT:',
                  style: AppTheme.timesFont(fontSize: 11),
                ),
                Text('-${invoice.discountAmount.toStringAsFixed(2)}', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL AMOUNT:', style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(invoice.totalAmount.toStringAsFixed(2), style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),

          if (shop.bankName.isNotEmpty || shop.accountNumber.isNotEmpty || shop.ifscCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildDashedLine('-'),
            Text('BANK PAYMENT DETAILS', style: AppTheme.timesFont(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black)),
            if (shop.bankName.isNotEmpty) Text('Bank: ${shop.bankName}', style: AppTheme.timesFont(fontSize: 9, color: Colors.black87)),
            if (shop.accountNumber.isNotEmpty) Text('A/C No: ${shop.accountNumber}', style: AppTheme.timesFont(fontSize: 9, color: Colors.black87)),
            if (shop.ifscCode.isNotEmpty) Text('IFSC: ${shop.ifscCode}', style: AppTheme.timesFont(fontSize: 9, color: Colors.black87)),
          ],

          const SizedBox(height: 6),
          _buildDashedLine('='),
          const SizedBox(height: 4),
          Text('Thank You! Visit Again', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (shop.shopName.isNotEmpty)
            Text(shop.shopName, textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text('Paper Size: 80 mm Thermal', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 9, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // --- 2. 127mm (5 Inch) Thermal / Compact Layout ---
  Widget _build127mmLayout(ShopProfile shop, Invoice invoice, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shop.logoBase64.isNotEmpty)
                SizedBox(
                  height: 50,
                  width: 120,
                  child: Image.memory(base64Decode(shop.logoBase64), fit: BoxFit.contain, errorBuilder: (ctx, e, s) => const SizedBox.shrink()),
                )
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: Icon(_getShopLogoIcon(shop.logoPreset), color: Colors.white, size: 20),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.shopName, style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('${shop.address} • ${shop.mobile}', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                    if (shop.gstin.isNotEmpty) Text('GSTIN: ${shop.gstin}', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(invoice.invoiceNumber, style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text(dateFormatter.format(invoice.issueDate), style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Customer: ${invoice.customerName} (${invoice.customerPhone})', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Pay: ${invoice.paymentMethod.label}', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),

          // Items Table
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.tableHeader),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text('Item', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                ...invoice.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: Text(item.fullDescription, style: AppTheme.timesFont(fontSize: 11))),
                        Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 11))),
                        Expanded(flex: 2, child: Text(currencyFormatter.format(item.unitPrice), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11))),
                        Expanded(flex: 2, child: Text(currencyFormatter.format(item.totalPrice), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paper Size: 127mm (5 Inch)', style: AppTheme.timesFont(fontSize: 10, color: AppColors.textSecondary)),
              Row(
                children: [
                  Text('Total Amount: ', style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(currencyFormatter.format(invoice.totalAmount), style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. A5 — 148 × 210 mm Layout ---
  Widget _buildA5Layout(ShopProfile shop, Invoice invoice, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shop.logoBase64.isNotEmpty)
                      SizedBox(
                        height: 55,
                        width: 160,
                        child: Image.memory(base64Decode(shop.logoBase64), fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                      )
                    else
                      Text(shop.shopName, style: AppTheme.timesFont(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text(shop.address, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                    Text('Mobile: ${shop.mobile}${shop.gstin.isNotEmpty ? ' • GSTIN: ${shop.gstin}' : ''}', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                    child: Text('TAX INVOICE', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 6),
                  Text('Invoice #: ${invoice.invoiceNumber}', style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('Date: ${dateFormatter.format(invoice.issueDate)}', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          // Customer Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.tableHeader, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billed To Customer:', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    Text(invoice.customerName, style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (invoice.customerPhone.isNotEmpty) Text('Phone: ${invoice.customerPhone}', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Payment Method:', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    Text(invoice.paymentMethod.label, style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    if (invoice.paymentRef.isNotEmpty) Text('Ref: ${invoice.paymentRef}', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items Table
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.tableHeader),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text('Item Description', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Unit Price', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                ...invoice.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: Text(item.fullDescription, style: AppTheme.timesFont(fontSize: 12))),
                        Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 12))),
                        Expanded(flex: 2, child: Text(currencyFormatter.format(item.unitPrice), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 12))),
                        Expanded(flex: 2, child: Text(currencyFormatter.format(item.totalPrice), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paper Size: A5 (148 × 210 mm)', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.tableHeader, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Text('Grand Total: ', style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(currencyFormatter.format(invoice.totalAmount), style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 4. A4 — 210 × 297 mm Official Corporate Layout ---
  Widget _buildA4Layout(ShopProfile shop, Invoice invoice, NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shop.logoBase64.isNotEmpty)
                      SizedBox(
                        height: 60,
                        width: 180,
                        child: Image.memory(base64Decode(shop.logoBase64), fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: Icon(_getShopLogoIcon(shop.logoPreset), color: Colors.white, size: 28),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.shopName, style: AppTheme.timesFont(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          if (shop.gstin.isNotEmpty) Text('GSTIN: ${shop.gstin}', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(height: 2),
                          Text('${shop.address}\nMobile: ${shop.mobile}${shop.email.isNotEmpty ? ' • Email: ${shop.email}' : ''}', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('OFFICIAL TAX INVOICE', style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text('Invoice No: ${invoice.invoiceNumber}', style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('Issue Date: ${dateFormatter.format(invoice.issueDate)}', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                  Text('Due Date: ${dateFormatter.format(invoice.dueDate)}', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // Customer & Payment Info Cards Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billed To Customer:', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(invoice.customerName, style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('${invoice.customerEmail} ${invoice.customerPhone.isNotEmpty ? '• ${invoice.customerPhone}' : ''}', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Payment Information:', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.tableHeader, borderRadius: BorderRadius.circular(6)),
                    child: Text(invoice.paymentMethod.label, style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ),
                  if (invoice.paymentRef.isNotEmpty) Text('Ref: ${invoice.paymentRef}', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // A4 Detailed Itemized Table
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.tableHeader, borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text('Item Description', style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(flex: 2, child: Text('Unit Price', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(flex: 2, child: Text('Total Amount', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13))),
                    ],
                  ),
                ),
                ...invoice.items.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.fullDescription, style: AppTheme.timesFont(fontSize: 13)),
                              if (item.discount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Item Discount: -${currencyFormatter.format(item.discount)}',
                                    style: AppTheme.timesFont(fontSize: 11, color: AppColors.paid, fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: AppTheme.timesFont(fontSize: 13))),
                        Expanded(flex: 2, child: Text(currencyFormatter.format(item.unitPrice), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 13))),
                        Expanded(flex: 2, child: Text(currencyFormatter.format(item.totalPrice), textAlign: TextAlign.right, style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Breakdown & Signatory Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (invoice.notes.isNotEmpty) ...[
                      Text('Notes / Special Instructions:', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(invoice.notes, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 14),
                    Text('Paper Format: A4 (210 × 297 mm)', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 260,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.tableHeader, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    _buildSummaryLine('Subtotal', currencyFormatter.format(invoice.subtotal)),
                    if (invoice.taxPercent > 0) _buildSummaryLine('Tax (${invoice.taxPercent}%)', '+${currencyFormatter.format(invoice.taxAmount)}'),
                    if (invoice.discountAmount > 0)
                      _buildSummaryLine(
                        invoice.discountPercent > 0
                            ? 'Discount (${invoice.discountPercent.toStringAsFixed(invoice.discountPercent % 1 == 0 ? 0 : 1)}%)'
                            : 'Discount (Flat)',
                        '-${currencyFormatter.format(invoice.discountAmount)}',
                      ),
                    const Divider(color: AppColors.border, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Grand Total', style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text(currencyFormatter.format(invoice.totalAmount), style: AppTheme.timesFont(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
