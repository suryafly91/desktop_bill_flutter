import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, SnackBarAction, Color, Colors, Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/default_logo.dart';
import '../models/invoice.dart';
import '../models/shop_profile.dart';
import 'bluetooth_printer_service.dart';

class PdfService {
  static pw.Font? _notoSansRegular;
  static pw.Font? _notoSansBold;

  /// 58mm Thermal Receipt Roll Paper Format (Zero margins)
  static const PdfPageFormat roll58 = PdfPageFormat(
    58 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 0,
  );

  /// 80mm Thermal Receipt Roll Paper Format (Zero margins)
  static const PdfPageFormat roll80 = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 0,
  );

  /// Helper to get the correct PdfPageFormat for any BillPaperSize
  static PdfPageFormat getPageFormat(BillPaperSize paperSize) {
    switch (paperSize) {
      case BillPaperSize.mm58:
        return roll58;
      case BillPaperSize.mm80:
        return roll80;
      case BillPaperSize.mm127:
        return const PdfPageFormat(127 * PdfPageFormat.mm, double.infinity, marginAll: 6 * PdfPageFormat.mm);
      case BillPaperSize.a5:
        return PdfPageFormat.a5;
      case BillPaperSize.a4:
        return PdfPageFormat.a4;
    }
  }

  /// Loads and caches NotoSans Unicode font from assets with a fontFallback
  /// so that "•" (U+2022) and other special Unicode characters render cleanly.
  static Future<pw.ThemeData> getDocumentTheme() async {
    if (_notoSansRegular == null) {
      try {
        final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
        _notoSansRegular = pw.Font.ttf(fontData);
      } catch (e) {
        debugPrint('Warning: Could not load assets/fonts/NotoSans-Regular.ttf: $e');
      }
    }

    if (_notoSansBold == null) {
      try {
        final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
        _notoSansBold = pw.Font.ttf(boldData);
      } catch (e) {
        debugPrint('Warning: Could not load assets/fonts/NotoSans-Bold.ttf: $e');
      }
    }

    final regular = _notoSansRegular;
    final bold = _notoSansBold ?? regular;

    if (regular != null) {
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [regular],
      );
    }

    return pw.ThemeData.base();
  }

  static Future<Uint8List> generateQuotationPdf({
    required Invoice invoice,
    required ShopProfile shopProfile,
    BillPaperSize paperSize = BillPaperSize.a4,
  }) async {
    return generateInvoicePdf(
      invoice: invoice,
      shopProfile: shopProfile,
      paperSize: paperSize,
    );
  }

  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required ShopProfile shopProfile,
    BillPaperSize paperSize = BillPaperSize.a4,
  }) async {
    final theme = await getDocumentTheme();
    final pdf = pw.Document(theme: theme);

    // Decode logo image only if custom logo is set (ignore default FlyTowards logo)
    pw.MemoryImage? logoImage;
    if (shopProfile.logoBase64.isNotEmpty &&
        shopProfile.logoBase64 != kDefaultFlyTowardsLogoBase64) {
      try {
        final cleanBase64 = shopProfile.logoBase64.contains(',')
            ? shopProfile.logoBase64.split(',').last
            : shopProfile.logoBase64;
        final logoBytes = base64Decode(cleanBase64.trim());
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {
        logoImage = null;
      }
    }

    final primaryColor = PdfColor.fromHex('#0A3B74');

    switch (paperSize) {
      case BillPaperSize.mm58:
        _build58mmPdf(pdf, invoice, shopProfile, logoImage, primaryColor);
        break;
      case BillPaperSize.mm80:
        _build80mmPdf(pdf, invoice, shopProfile, logoImage, primaryColor);
        break;
      case BillPaperSize.mm127:
        _build127mmPdf(pdf, invoice, shopProfile, logoImage, primaryColor);
        break;
      case BillPaperSize.a5:
        _buildA5Pdf(pdf, invoice, shopProfile, logoImage, primaryColor);
        break;
      case BillPaperSize.a4:
        _buildA4Pdf(pdf, invoice, shopProfile, logoImage, primaryColor);
        break;
    }

    return pdf.save();
  }

  // --- 0. 58mm Thermal Receipt Layout ---
  static void _build58mmPdf(
    pw.Document pdf,
    Invoice invoice,
    ShopProfile shop,
    pw.MemoryImage? logoImage,
    PdfColor primaryColor,
  ) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final isQuotation = invoice.status == InvoiceStatus.quotation;

    pdf.addPage(
      pw.Page(
        pageFormat: roll58,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2 * PdfPageFormat.mm, vertical: 2 * PdfPageFormat.mm),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
              if (logoImage != null) ...[
                pw.Container(
                  height: 30,
                  width: 90,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 2),
              ],
              pw.Text(
                shop.shopName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              if (shop.address.isNotEmpty)
                pw.Text(
                  shop.address,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
                ),
              pw.Text(
                'Mob: ${shop.mobile}${(invoice.isGstBill && shop.gstin.isNotEmpty) ? ' • GST: ${shop.gstin}' : ''}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                isQuotation
                    ? '*** QUOTATION ***'
                    : (invoice.isGstBill ? '*** TAX INVOICE ***' : '*** RETAIL BILL ***'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 3),
              pw.Text('--------------------------------', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill#: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateFormatter.format(invoice.issueDate), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cust: ${invoice.customerName}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Pay: ${invoice.paymentMethod.label.toUpperCase()}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Text('--------------------------------', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),

              // Table Headers
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Text('--------------------------------', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),

              ...invoice.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(flex: 3, child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 7))),
                          pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
                          pw.Expanded(flex: 2, child: pw.Text(item.unitPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7))),
                          pw.Expanded(flex: 2, child: pw.Text(item.totalPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      if (item.discount > 0)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 3),
                          child: pw.Text(' (Disc: -${item.discount.toStringAsFixed(2)})', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                        ),
                    ],
                  ),
                );
              }),

              pw.Text('--------------------------------', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),

              _buildSummaryRow('Subtotal:', invoice.subtotal.toStringAsFixed(2), fontSize: 7),
              if (invoice.taxAmount > 0) ...[
                _buildSummaryRow('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2), fontSize: 7),
                _buildSummaryRow('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2), fontSize: 7),
              ],
              if (invoice.discountAmount > 0)
                _buildSummaryRow('Discount:', '-${invoice.discountAmount.toStringAsFixed(2)}', fontSize: 7),

              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoice.totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ],
              ),
              if (shop.bankName.isNotEmpty || shop.accountNumber.isNotEmpty || shop.ifscCode.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text('--------------------------------', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Text('BANK PAYMENT DETAILS', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                if (shop.bankName.isNotEmpty) pw.Text('Bank: ${shop.bankName}', style: const pw.TextStyle(fontSize: 6.5)),
                if (shop.accountNumber.isNotEmpty) pw.Text('A/C No: ${shop.accountNumber}', style: const pw.TextStyle(fontSize: 6.5)),
                if (shop.ifscCode.isNotEmpty) pw.Text('IFSC: ${shop.ifscCode}', style: const pw.TextStyle(fontSize: 6.5)),
              ],
              pw.SizedBox(height: 6),
              pw.Text('================================', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              pw.SizedBox(height: 3),
              pw.Text('Thank You! Visit Again', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              if (shop.shopName.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(shop.shopName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              ],
            ],
          ),
        );
      },
    ),
  );
  }

  // --- 1. 80mm Thermal Receipt Layout ---
  static void _build80mmPdf(
    pw.Document pdf,
    Invoice invoice,
    ShopProfile shop,
    pw.MemoryImage? logoImage,
    PdfColor primaryColor,
  ) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final isQuotation = invoice.status == InvoiceStatus.quotation;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  height: 40,
                  width: 120,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Text(
                shop.shopName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              if (shop.address.isNotEmpty)
                pw.Text(
                  shop.address,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
              pw.Text(
                'Mobile: ${shop.mobile}${(invoice.isGstBill && shop.gstin.isNotEmpty) ? ' • GSTIN: ${shop.gstin}' : ''}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                isQuotation
                    ? '*** QUOTATION ***'
                    : (invoice.isGstBill ? '*** TAX INVOICE ***' : '*** RETAIL BILL ***'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 4),
              pw.Text('-----------------------------------------', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill #: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateFormatter.format(invoice.issueDate), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cust: ${invoice.customerName}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Pay: ${invoice.paymentMethod.label.toUpperCase()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Text('-----------------------------------------', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),

              // Table Headers
              pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Text('-----------------------------------------', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),

              ...invoice.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(flex: 4, child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 8))),
                          pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                          pw.Expanded(flex: 2, child: pw.Text(item.unitPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          pw.Expanded(flex: 2, child: pw.Text(item.totalPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      if (item.discount > 0)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 4),
                          child: pw.Text(' (Item Disc: -${item.discount.toStringAsFixed(2)})', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        ),
                    ],
                  ),
                );
              }),

              pw.Text('-----------------------------------------', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),

              _buildSummaryRow('Subtotal:', invoice.subtotal.toStringAsFixed(2)),
              if (invoice.taxAmount > 0) ...[
                _buildSummaryRow('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2)),
                _buildSummaryRow('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2)),
              ],
              if (invoice.discountAmount > 0)
                _buildSummaryRow('Discount:', '-${invoice.discountAmount.toStringAsFixed(2)}'),

              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoice.totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ],
              ),
              if (shop.bankName.isNotEmpty || shop.accountNumber.isNotEmpty || shop.ifscCode.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('-----------------------------------------', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('BANK PAYMENT DETAILS', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                if (shop.bankName.isNotEmpty) pw.Text('Bank: ${shop.bankName}', style: const pw.TextStyle(fontSize: 7)),
                if (shop.accountNumber.isNotEmpty) pw.Text('A/C No: ${shop.accountNumber}', style: const pw.TextStyle(fontSize: 7)),
                if (shop.ifscCode.isNotEmpty) pw.Text('IFSC: ${shop.ifscCode}', style: const pw.TextStyle(fontSize: 7)),
              ],
              pw.SizedBox(height: 8),
              pw.Text('=========================================', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text('Thank You! Visit Again', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              if (shop.shopName.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(shop.shopName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              ],
            ],
          );
        },
      ),
    );
  }

  // --- 2. 127mm (5 Inch) Thermal / Compact Layout ---
  static void _build127mmPdf(
    pw.Document pdf,
    Invoice invoice,
    ShopProfile shop,
    pw.MemoryImage? logoImage,
    PdfColor primaryColor,
  ) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final isQuotation = invoice.status == InvoiceStatus.quotation;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          127 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 6 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(height: 45, width: 110, child: pw.Image(logoImage, fit: pw.BoxFit.contain))
                  else
                    pw.Text(shop.shopName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(isQuotation ? 'QUOTATION' : 'TAX INVOICE', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Bill #: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${dateFormatter.format(invoice.issueDate)}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('${shop.shopName} • ${shop.address}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.Text('Mobile: ${shop.mobile}${shop.gstin.isNotEmpty ? ' • GSTIN: ${shop.gstin}' : ''}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.SizedBox(height: 10),
              pw.Divider(color: primaryColor, thickness: 1),
              pw.SizedBox(height: 6),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer: ${invoice.customerName} (${invoice.customerPhone})', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Payment: ${invoice.paymentMethod.label}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 10),

              // Items Table
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                child: pw.Column(
                  children: [
                    pw.Container(
                      color: PdfColors.grey200,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: pw.Row(
                        children: [
                          pw.Expanded(flex: 4, child: pw.Text('Item Description', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 2, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                    ),
                    ...invoice.items.map((item) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 4,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(item.description, style: const pw.TextStyle(fontSize: 9)),
                                  if (item.discount > 0)
                                    pw.Text('Item Disc: -${item.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                            pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                            pw.Expanded(flex: 2, child: pw.Text(item.unitPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                            pw.Expanded(flex: 2, child: pw.Text(item.totalPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 180,
                  child: pw.Column(
                    children: [
                      _buildSummaryRow('Subtotal:', invoice.subtotal.toStringAsFixed(2)),
                      if (invoice.taxAmount > 0) ...[
                        _buildSummaryRow('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2)),
                        _buildSummaryRow('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2)),
                      ],
                      if (invoice.discountAmount > 0)
                        _buildSummaryRow('Discount:', '-${invoice.discountAmount.toStringAsFixed(2)}'),
                      pw.Divider(color: primaryColor, thickness: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoice.totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Thank You! Visit Again', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    if (shop.shopName.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(shop.shopName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 3. A5 Layout ---
  static void _buildA5Pdf(
    pw.Document pdf,
    Invoice invoice,
    ShopProfile shop,
    pw.MemoryImage? logoImage,
    PdfColor primaryColor,
  ) {
    final dateFormatter = DateFormat('dd MMM yyyy');
    final isQuotation = invoice.status == InvoiceStatus.quotation;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logoImage != null)
                    pw.Container(height: 45, width: 130, child: pw.Image(logoImage, fit: pw.BoxFit.contain))
                  else
                    pw.Text(shop.shopName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Text(
                    isQuotation ? 'QUOTATION' : 'TAX INVOICE',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shop.shopName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                        pw.Text('Phone: ${shop.mobile}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                        if (shop.gstin.isNotEmpty) pw.Text('GSTIN: ${shop.gstin}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Number: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${dateFormatter.format(invoice.issueDate)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Billed To: ${invoice.customerName}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      if (invoice.customerPhone.isNotEmpty) pw.Text('Phone: ${invoice.customerPhone}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Container(height: 1.5, color: primaryColor),
              pw.SizedBox(height: 12),

              // Items Table
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(color: primaryColor, width: 1)),
                child: pw.Column(
                  children: [
                    pw.Container(
                      color: PdfColors.grey200,
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Row(
                        children: [
                          pw.Expanded(flex: 5, child: pw.Text('Item Description', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                    ),
                    ...invoice.items.map((item) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 5,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(item.description, style: const pw.TextStyle(fontSize: 9)),
                                  if (item.discount > 0)
                                    pw.Text('Item Disc: -${item.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                            pw.Expanded(flex: 2, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                            pw.Expanded(flex: 2, child: pw.Text(item.unitPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                            pw.Expanded(flex: 2, child: pw.Text(item.totalPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              pw.Spacer(),

              // Summary
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      _buildSummaryRow('Subtotal:', invoice.subtotal.toStringAsFixed(2)),
                      if (invoice.taxAmount > 0) ...[
                        _buildSummaryRow('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2)),
                        _buildSummaryRow('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', (invoice.taxAmount / 2).toStringAsFixed(2)),
                      ],
                      if (invoice.discountAmount > 0)
                        _buildSummaryRow('Discount:', '-${invoice.discountAmount.toStringAsFixed(2)}'),
                      pw.Container(height: 1, color: primaryColor),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text(invoice.totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Container(height: 1, color: primaryColor),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Thank You! Visit Again — ${shop.shopName}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  if (shop.mobile.isNotEmpty) pw.Text('Phone: ${shop.mobile}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 4. A4 Corporate Layout ---
  static void _buildA4Pdf(
    pw.Document pdf,
    Invoice invoice,
    ShopProfile shopProfile,
    pw.MemoryImage? logoImage,
    PdfColor primaryColor,
  ) {
    final dateFormatter = DateFormat('dd MMM yyyy');
    final isQuotation = invoice.status == InvoiceStatus.quotation;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Accent Bar
              pw.Container(
                height: 12,
                width: double.infinity,
                color: primaryColor,
              ),

              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              if (logoImage != null) ...[
                                pw.Container(
                                  height: 50,
                                  width: 100,
                                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                                ),
                                pw.SizedBox(width: 12),
                              ],
                              pw.Text(
                                shopProfile.shopName.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          pw.Text(
                            isQuotation
                                ? 'QUOTATION'
                                : (invoice.isGstBill ? 'TAX INVOICE' : 'RETAIL INVOICE'),
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 24),

                      // Company & Customer Details Row
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  shopProfile.shopName,
                                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                                ),
                                if (shopProfile.address.isNotEmpty)
                                  pw.Text(
                                    shopProfile.address,
                                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                                  ),
                                if (invoice.isGstBill && shopProfile.gstin.isNotEmpty) ...[
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    'GSTIN: ${shopProfile.gstin}',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                                pw.SizedBox(height: 16),
                                pw.Text(
                                  isQuotation ? 'Quotation To:' : 'Bill To:',
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  invoice.customerName.isNotEmpty ? invoice.customerName : 'Valued Customer',
                                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                                ),
                                if (invoice.customerEmail.isNotEmpty)
                                  pw.Text(invoice.customerEmail, style: const pw.TextStyle(fontSize: 10)),
                                if (invoice.customerPhone.isNotEmpty)
                                  pw.Text(invoice.customerPhone, style: const pw.TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            flex: 5,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.SizedBox(
                                      width: 100,
                                      child: pw.Text(
                                        isQuotation ? 'Quotation Number' : 'Invoice Number',
                                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                                      ),
                                    ),
                                    pw.Text(
                                      invoice.invoiceNumber,
                                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 4),
                                pw.Row(
                                  children: [
                                    pw.SizedBox(
                                      width: 100,
                                      child: pw.Text(
                                        isQuotation ? 'Quotation Date' : 'Invoice Date',
                                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                                      ),
                                    ),
                                    pw.Text(
                                      dateFormatter.format(invoice.issueDate),
                                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (shopProfile.bankName.isNotEmpty || shopProfile.accountNumber.isNotEmpty || shopProfile.ifscCode.isNotEmpty) ...[
                                  pw.SizedBox(height: 16),
                                  pw.Text(
                                    'Payment information',
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  if (shopProfile.bankName.isNotEmpty)
                                    pw.Text('Bank Name: ${shopProfile.bankName}', style: const pw.TextStyle(fontSize: 10)),
                                  pw.Text('Company Name: ${shopProfile.shopName}', style: const pw.TextStyle(fontSize: 10)),
                                  if (shopProfile.accountNumber.isNotEmpty)
                                    pw.Text('Account Number: ${shopProfile.accountNumber}', style: const pw.TextStyle(fontSize: 10)),
                                  if (shopProfile.ifscCode.isNotEmpty)
                                    pw.Text('IFSC CODE : ${shopProfile.ifscCode}', style: const pw.TextStyle(fontSize: 10)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 28),

                      // Line Items Table Header
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: primaryColor, width: 1.5),
                            bottom: pw.BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 5,
                              child: pw.Text(
                                'Description',
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                'Quantity',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                'Rate',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                'Total',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Table Body Rows
                      ...invoice.items.map((item) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 10),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 5,
                                child: pw.Text(
                                  item.description,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  '${item.quantity}',
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(0) : '',
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  item.totalPrice > 0 ? item.totalPrice.toStringAsFixed(0) : '',
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      pw.Spacer(),

                      // Summary Totals Section
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Container(
                          width: 220,
                          child: pw.Column(
                            children: [
                              _buildSummaryRow('Subtotal :', invoice.subtotal.toStringAsFixed(2)),
                              if (invoice.taxAmount > 0) ...[
                                _buildSummaryRow('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%) :', (invoice.taxAmount / 2).toStringAsFixed(2)),
                                _buildSummaryRow('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%) :', (invoice.taxAmount / 2).toStringAsFixed(2)),
                              ],
                              if (invoice.discountAmount > 0)
                                _buildSummaryRow('Discount :', '-${invoice.discountAmount.toStringAsFixed(2)}'),
                              pw.SizedBox(height: 6),
                              pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border(
                                    top: pw.BorderSide(color: primaryColor, width: 1.2),
                                    bottom: pw.BorderSide(color: primaryColor, width: 1.2),
                                  ),
                                ),
                                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      'Grand Total :',
                                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                    ),
                                    pw.Text(
                                      invoice.totalAmount.toStringAsFixed(2),
                                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 30),

                      // Thank You & Sign Area
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Thank You! Visit Again',
                                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                shopProfile.shopName,
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Container(width: 140, height: 1, color: primaryColor),
                              pw.SizedBox(height: 4),
                              pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 10, color: primaryColor)),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Bottom Footer Bar
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: primaryColor, width: 1)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      shopProfile.email.isNotEmpty ? shopProfile.email : '',
                      style: pw.TextStyle(fontSize: 10, color: primaryColor),
                    ),
                    pw.Text(
                      'Thank You! Visit Again • ${shopProfile.shopName}',
                      style: pw.TextStyle(fontSize: 10, color: primaryColor, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      shopProfile.mobile.isNotEmpty ? 'Phone ${shopProfile.mobile}' : '',
                      style: pw.TextStyle(fontSize: 10, color: primaryColor),
                    ),
                  ],
                ),
              ),
              pw.Container(
                height: 10,
                width: double.infinity,
                color: primaryColor,
              ),
            ],
          );
        },
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
          pw.Text(' $value', style: pw.TextStyle(fontSize: fontSize)),
        ],
      ),
    );
  }

  static Future<String?> downloadOrSharePdf({
    required Invoice invoice,
    required ShopProfile shopProfile,
    BillPaperSize paperSize = BillPaperSize.a4,
    BuildContext? context,
  }) async {
    final bytes = await generateInvoicePdf(
      invoice: invoice,
      shopProfile: shopProfile,
      paperSize: paperSize,
    );

    final cleanNum = invoice.invoiceNumber.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final filename = invoice.status == InvoiceStatus.quotation
        ? 'Quotation_$cleanNum.pdf'
        : 'Invoice_$cleanNum.pdf';

    // Desktop: On Windows, save the file directly to disk
    if (!kIsWeb && Platform.isWindows) {
      String? savePath;
      try {
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save ${invoice.status == InvoiceStatus.quotation ? "Quotation" : "Invoice"} PDF',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
      } catch (e) {
        debugPrint('FilePicker saveFile error: $e');
      }

      // If user cancelled dialog or FilePicker was unavailable, save to Downloads folder
      if (savePath == null) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final downloadsDir = Directory('$userProfile\\Downloads');
          if (downloadsDir.existsSync()) {
            savePath = '${downloadsDir.path}\\$filename';
          }
        }
      }

      if (savePath != null) {
        if (!savePath.toLowerCase().endsWith('.pdf')) {
          savePath = '$savePath.pdf';
        }
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        debugPrint('Successfully saved PDF to: $savePath');

        if (context != null && context.mounted) {
          final writtenPath = savePath;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: ${file.uri.pathSegments.last}'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () {
                  try {
                    Process.run('explorer.exe', ['/select,', writtenPath]);
                  } catch (_) {}
                },
              ),
            ),
          );
        }
        return savePath;
      }
    }

    // Mobile / Web: Share PDF via system share sheet
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
    return null;
  }

  static Future<Printer?> printPdf({
    required Invoice invoice,
    required ShopProfile shopProfile,
    BillPaperSize paperSize = BillPaperSize.a4,
    Printer? targetPrinter,
  }) async {
    final bytes = await generateInvoicePdf(
      invoice: invoice,
      shopProfile: shopProfile,
      paperSize: paperSize,
    );

    final docName = invoice.status == InvoiceStatus.quotation
        ? 'Quotation_${invoice.invoiceNumber}'
        : 'Invoice_${invoice.invoiceNumber}';

    final pageFormat = getPageFormat(paperSize);

    // Platform check:
    // Printing.listPrinters() is only supported on Windows, macOS, and Linux.
    // On Android and iOS, it throws UnimplementedError.
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (!isDesktop) {
      // On Android / iOS, invoke system print preview / spooler directly
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: docName,
        format: pageFormat,
        usePrinterSettings: true,
      );
      return null;
    }

    // --- Desktop (Windows / macOS / Linux) printer discovery & direct print ---
    List<Printer> printers = [];
    try {
      printers = await Printing.listPrinters();
    } catch (e) {
      debugPrint('Error listing printers: $e');
    }

    // 2. Identify the Windows System Default Printer
    Printer? defaultPrinter;
    try {
      defaultPrinter = printers.firstWhere((p) => p.isDefault);
    } catch (_) {}

    // 3. Check for saved printer configuration in preferences
    final savedConfig = await BluetoothPrinterService.getSavedPrinterConfig();
    Printer? savedPrinter;
    if (!savedConfig.isAuto && savedConfig.name.isNotEmpty) {
      try {
        savedPrinter = printers.firstWhere((p) => p.name == savedConfig.name);
      } catch (_) {}
    }

    if (savedPrinter == null) {
      final savedName = await BluetoothPrinterService.getSavedThermalPrinterName();
      if (savedName != null && savedName.isNotEmpty) {
        try {
          savedPrinter = printers.firstWhere((p) => p.name == savedName);
        } catch (_) {}
      }
    }

    // 4. Identify any connected Bluetooth or POS thermal printer
    Printer? bluetoothPrinter;
    try {
      bluetoothPrinter = printers.firstWhere((p) => isBluetoothOrThermalPrinter(p));
    } catch (_) {}

    // 5. Select printer:
    // - If explicit targetPrinter passed, use it
    // - If user explicitly configured a printer in Settings (!savedConfig.isAuto), prioritize it!
    // - Otherwise use Windows system default printer
    // - Fallback to any detected thermal printer or any physical non-virtual printer
    Printer? printerToUse;
    if (targetPrinter != null && !isVirtualPrinter(targetPrinter.name)) {
      printerToUse = targetPrinter;
    } else if (savedPrinter != null && !savedConfig.isAuto && !isVirtualPrinter(savedPrinter.name)) {
      printerToUse = savedPrinter;
    } else if (defaultPrinter != null && !isVirtualPrinter(defaultPrinter.name)) {
      printerToUse = defaultPrinter;
    } else if (savedPrinter != null && !isVirtualPrinter(savedPrinter.name)) {
      printerToUse = savedPrinter;
    } else if (bluetoothPrinter != null) {
      printerToUse = bluetoothPrinter;
    } else {
      try {
        printerToUse = printers.firstWhere((p) => !isVirtualPrinter(p.name));
      } catch (_) {}
    }

    // 6. Direct printing for Windows system default printer (e.g. Canon A4, MT580P):
    if (printerToUse != null && !isVirtualPrinter(printerToUse.name)) {
      // Special check: If printer is Generic / Text Only and paper is thermal, use raw bytes
      if ((paperSize == BillPaperSize.mm58 || paperSize == BillPaperSize.mm80) &&
          (printerToUse.name.contains('Generic') || printerToUse.url.contains('COM'))) {
        final rawEscPos = BluetoothPrinterService.generateInvoiceEscPos(
          invoice: invoice,
          shopProfile: shopProfile,
          paperSize: paperSize,
        );
        final rawSuccess = await BluetoothPrinterService.sendRawBytes(rawEscPos);
        if (rawSuccess) return printerToUse;
      }

      try {
        final success = await Future.value(
          Printing.directPrintPdf(
            printer: printerToUse,
            onLayout: (PdfPageFormat format) async => bytes,
            name: docName,
            usePrinterSettings: true,
          ),
        ).timeout(const Duration(seconds: 5));

        if (success) {
          return printerToUse;
        }
      } catch (e) {
        debugPrint('Direct print to ${printerToUse.name} failed or timed out: $e. Falling back to print dialog.');
      }
    }

    // 7. Safe Fallback / System Print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: docName,
      format: pageFormat,
      usePrinterSettings: true,
    );

    return null;
  }

  static Future<bool> printPdfDirect({
    required Invoice invoice,
    required ShopProfile shopProfile,
    required BillPaperSize paperSize,
    Printer? targetPrinter,
  }) async {
    final printed = await printPdf(
      invoice: invoice,
      shopProfile: shopProfile,
      paperSize: paperSize,
      targetPrinter: targetPrinter,
    );
    return printed != null;
  }

  /// Checks if a printer is a Bluetooth, USB, or Thermal POS printer (e.g. MT580P, POS-58)
  static bool isBluetoothOrThermalPrinter(Printer printer) {
    final name = printer.name.toLowerCase();
    final url = printer.url.toLowerCase();
    final model = (printer.model ?? '').toLowerCase();
    final comment = (printer.comment ?? '').toLowerCase();
    return name.contains('bluetooth') ||
        name.contains('pos') ||
        name.contains('thermal') ||
        name.contains('receipt') ||
        name.contains('mt580') ||
        name.contains('mt58') ||
        name.contains('580') ||
        name.contains('58mm') ||
        name.contains('80mm') ||
        name.contains('pos-58') ||
        name.contains('pos58') ||
        name.contains('pos-80') ||
        name.contains('pos80') ||
        name.contains('58') ||
        name.contains('80') ||
        name.contains('rpp') ||
        name.contains('mtp') ||
        name.contains('tvs') ||
        name.contains('xprinter') ||
        name.contains('rongta') ||
        name.contains('inner') ||
        name.contains('esc') ||
        name.contains('gprinter') ||
        name.contains('hprt') ||
        name.contains('bixolon') ||
        name.contains('zebra') ||
        url.contains('bluetooth') ||
        url.contains('rfcomm') ||
        url.contains('bth') ||
        url.contains('usb') ||
        model.contains('pos') ||
        model.contains('thermal') ||
        model.contains('580') ||
        comment.contains('bluetooth');
  }

  /// Identifies generic virtual print drivers (PDF, XPS, OneNote, Fax)
  static bool isVirtualPrinter(String name) {
    final lower = name.toLowerCase();
    return lower.contains('microsoft print to pdf') ||
        lower.contains('onenote') ||
        lower.contains('fax') ||
        lower.contains('xps') ||
        lower.contains('writer') ||
        lower.contains('send to onenote');
  }
}
