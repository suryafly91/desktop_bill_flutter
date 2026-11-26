import 'package:billing_app/models/invoice.dart';
import 'package:billing_app/models/invoice_item.dart';
import 'package:billing_app/models/shop_profile.dart';
import 'package:billing_app/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('58mm thermal receipt PDF generates with Unicode bullet • and 0 margin', () async {
    final shop = ShopProfile(
      companyId: 'test-co',
      shopName: 'Test Thermal Shop',
      ownerName: 'Owner',
      address: '123 Market Street',
      mobile: '9876543210',
      gstin: '29ABCDE1234F1Z5',
      gstPercentage: 18.0,
      email: 'test@example.com',
      logoPreset: 'store',
      logoBase64: '',
      paperSize: '58mm',
      isConfigured: true,
      bankName: 'Test Bank',
      accountNumber: '1234567890',
      ifscCode: 'TEST0001',
    );

    final invoice = Invoice(
      id: 'inv-1',
      invoiceNumber: 'INV-1001',
      customerId: 'cust-1',
      customerName: 'Customer • Test',
      customerEmail: 'cust@test.com',
      customerPhone: '9999999999',
      items: [
        InvoiceItem(
          id: '1',
          description: 'Item 1 • Thermal Print',
          quantity: 2,
          unitPrice: 50.0,
        ),
      ],
      taxPercent: 18.0,
      discountPercent: 0.0,
      issueDate: DateTime.now(),
      dueDate: DateTime.now(),
      paymentMethod: PaymentMethod.cash,
      status: InvoiceStatus.paid,
      isGstBill: true,
    );

    // Verify roll58 format has 58mm width and 0 margins
    expect(PdfService.roll58.width, closeTo(58 * PdfPageFormat.mm, 0.01));
    expect(PdfService.roll58.marginLeft, 0.0);
    expect(PdfService.roll58.marginRight, 0.0);
    expect(PdfService.roll58.marginTop, 0.0);
    expect(PdfService.roll58.marginBottom, 0.0);

    // Generate 58mm PDF containing bullet • glyphs
    final pdfBytes = await PdfService.generateInvoicePdf(
      invoice: invoice,
      shopProfile: shop,
      paperSize: BillPaperSize.mm58,
    );

    expect(pdfBytes.isNotEmpty, isTrue);
  });
}
