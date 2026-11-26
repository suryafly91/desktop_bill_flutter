import 'package:billing_app/models/invoice.dart';
import 'package:billing_app/models/invoice_item.dart';
import 'package:billing_app/models/shop_profile.dart';
import 'package:billing_app/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testShop = ShopProfile(
    companyId: 'test-co',
    shopName: 'Discount Supermart',
    ownerName: 'Owner',
    address: '100 Main Road',
    mobile: '9876543210',
    gstin: '29ABCDE1234F1Z5',
    gstPercentage: 18.0,
    email: 'shop@example.com',
    logoPreset: 'mart',
    paperSize: '80mm',
    isConfigured: true,
  );

  group('InvoiceItem Discount Tests', () {
    test('calculates totalPrice subtracting line item discount', () {
      final item = InvoiceItem(
        id: 'item-1',
        description: 'Cotton Shirt',
        quantity: 2,
        unitPrice: 500.0,
        discount: 100.0,
      );

      expect(item.grossPrice, 1000.0);
      expect(item.discount, 100.0);
      expect(item.totalPrice, 900.0);
    });

    test('totalPrice clamps to 0 when discount exceeds gross price', () {
      final item = InvoiceItem(
        id: 'item-2',
        description: 'Promo Pen',
        quantity: 1,
        unitPrice: 20.0,
        discount: 50.0,
      );

      expect(item.totalPrice, 0.0);
    });

    test('serializes and deserializes discount to and from JSON', () {
      final item = InvoiceItem(
        id: 'item-3',
        description: 'Jeans',
        quantity: 1,
        unitPrice: 1200.0,
        discount: 200.0,
      );

      final json = item.toJson();
      expect(json['discount'], 200.0);

      final restored = InvoiceItem.fromJson(json);
      expect(restored.discount, 200.0);
      expect(restored.totalPrice, 1000.0);
    });
  });

  group('Invoice Bill Discount Tests', () {
    test('bill with line item discounts computes correct subtotal and total', () {
      final invoice = Invoice(
        id: 'inv-1',
        invoiceNumber: 'INV-1001',
        customerId: 'cust-1',
        customerName: 'Aarav Patel',
        customerEmail: 'aarav@example.com',
        customerPhone: '9876543210',
        items: [
          InvoiceItem(
            id: '1',
            description: 'Item A',
            quantity: 2,
            unitPrice: 500.0,
            discount: 100.0, // total 900
          ),
          InvoiceItem(
            id: '2',
            description: 'Item B',
            quantity: 1,
            unitPrice: 300.0,
            discount: 50.0, // total 250
          ),
        ],
        taxPercent: 0.0,
        discountPercent: 0.0,
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        status: InvoiceStatus.paid,
        isGstBill: false,
      );

      expect(invoice.grossSubtotal, 1300.0);
      expect(invoice.totalItemDiscounts, 150.0);
      expect(invoice.subtotal, 1150.0);
      expect(invoice.totalAmount, 1150.0);
    });

    test('bill with percentage discount applies discount to subtotal', () {
      final invoice = Invoice(
        id: 'inv-2',
        invoiceNumber: 'INV-1002',
        customerId: 'cust-1',
        customerName: 'Priya Sharma',
        customerEmail: '',
        items: [
          InvoiceItem(
            id: '1',
            description: 'Saree',
            quantity: 1,
            unitPrice: 2000.0,
          ),
        ],
        taxPercent: 0.0,
        discountPercent: 10.0, // 10% discount = Rs. 200
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        status: InvoiceStatus.paid,
        isGstBill: false,
      );

      expect(invoice.subtotal, 2000.0);
      expect(invoice.discountAmount, 200.0);
      expect(invoice.totalAmount, 1800.0);
    });

    test('bill with flat rupee discount applies exact discount amount', () {
      final invoice = Invoice(
        id: 'inv-3',
        invoiceNumber: 'INV-1003',
        customerId: 'cust-1',
        customerName: 'Rahul Verma',
        customerEmail: '',
        items: [
          InvoiceItem(
            id: '1',
            description: 'Shoes',
            quantity: 1,
            unitPrice: 1550.0,
          ),
        ],
        taxPercent: 0.0,
        discountPercent: 0.0,
        discountAmountValue: 50.0, // Flat Rs. 50 discount
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        status: InvoiceStatus.paid,
        isGstBill: false,
      );

      expect(invoice.subtotal, 1550.0);
      expect(invoice.discountAmount, 50.0);
      expect(invoice.totalAmount, 1500.0);
    });

    test('bill with item discount + overall discount + GST calculates accurately', () {
      // Subtotal = (2 * 500 - 100) = 900
      // GST (18%) on 900 = 162
      // Bill discount (10%) on 900 = 90
      // Total = 900 + 162 - 90 = 972
      final invoice = Invoice(
        id: 'inv-4',
        invoiceNumber: 'INV-1004',
        customerId: 'cust-1',
        customerName: 'Customer Test',
        customerEmail: '',
        items: [
          InvoiceItem(
            id: '1',
            description: 'Jacket',
            quantity: 2,
            unitPrice: 500.0,
            discount: 100.0,
          ),
        ],
        taxPercent: 18.0,
        discountPercent: 10.0,
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        status: InvoiceStatus.paid,
        isGstBill: true,
      );

      expect(invoice.subtotal, 900.0);
      expect(invoice.taxAmount, 162.0);
      expect(invoice.discountAmount, 90.0);
      expect(invoice.totalAmount, 972.0);
    });

    test('generates 58mm, 80mm and A4 PDFs with discounts without errors', () async {
      final invoice = Invoice(
        id: 'inv-5',
        invoiceNumber: 'INV-1005',
        customerId: 'cust-1',
        customerName: 'Discount Customer',
        customerEmail: 'cust@example.com',
        customerPhone: '9876543210',
        items: [
          InvoiceItem(
            id: '1',
            description: 'Item With Discount',
            quantity: 2,
            unitPrice: 250.0,
            discount: 50.0,
          ),
        ],
        taxPercent: 18.0,
        discountPercent: 5.0,
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        status: InvoiceStatus.paid,
        isGstBill: true,
      );

      final pdf58 = await PdfService.generateInvoicePdf(
        invoice: invoice,
        shopProfile: testShop,
        paperSize: BillPaperSize.mm58,
      );
      expect(pdf58.isNotEmpty, isTrue);

      final pdf80 = await PdfService.generateInvoicePdf(
        invoice: invoice,
        shopProfile: testShop,
        paperSize: BillPaperSize.mm80,
      );
      expect(pdf80.isNotEmpty, isTrue);

      final pdfA4 = await PdfService.generateInvoicePdf(
        invoice: invoice,
        shopProfile: testShop,
        paperSize: BillPaperSize.a4,
      );
      expect(pdfA4.isNotEmpty, isTrue);
    });
  });
}
