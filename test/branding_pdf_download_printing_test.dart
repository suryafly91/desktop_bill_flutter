import 'dart:convert';
import 'dart:io';
import 'package:billing_app/models/default_logo.dart';
import 'package:billing_app/models/invoice.dart';
import 'package:billing_app/models/invoice_item.dart';
import 'package:billing_app/models/shop_profile.dart';
import 'package:billing_app/services/bluetooth_printer_service.dart';
import 'package:billing_app/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final customShop = ShopProfile(
    companyId: 'balaji-comp',
    shopName: 'Balaji Textiles & Garments',
    ownerName: 'Balaji V',
    address: '42 Bazaar Street, Madurai',
    mobile: '9840123456',
    gstin: '33AAAAA0000A1Z5',
    gstPercentage: 18.0,
    email: 'contact@balajitestiles.com',
    logoPreset: 'apparel',
    logoBase64: '',
    paperSize: '58mm',
    isConfigured: true,
  );

  final testInvoice = Invoice(
    id: 'inv-test-1',
    invoiceNumber: 'INV-2026-001',
    customerId: 'cust-1',
    customerName: 'Karthik Raja',
    customerPhone: '9876543210',
    customerEmail: 'karthik@example.com',
    issueDate: DateTime(2026, 10, 16),
    dueDate: DateTime(2026, 10, 23),
    items: [
      InvoiceItem(
        id: 'item-1',
        description: 'Cotton Silk Saree',
        quantity: 2,
        unitPrice: 1500.0,
        discount: 200.0,
      ),
    ],
    taxPercent: 5.0,
    status: InvoiceStatus.paid,
    paymentMethod: PaymentMethod.upi,
  );

  final testQuotation = Invoice(
    id: 'quot-test-1',
    invoiceNumber: 'QT-2026-005',
    customerId: 'cust-2',
    customerName: 'Rajesh Kumar',
    customerPhone: '9123456780',
    customerEmail: 'rajesh@example.com',
    issueDate: DateTime(2026, 10, 16),
    dueDate: DateTime(2026, 10, 30),
    items: [
      InvoiceItem(
        id: 'item-q1',
        description: 'Linen Formal Shirt',
        quantity: 5,
        unitPrice: 850.0,
        discount: 50.0,
      ),
    ],
    taxPercent: 0.0,
    status: InvoiceStatus.quotation,
    paymentMethod: PaymentMethod.cash,
  );

  group('Company Name & FlyTowards Removal Tests', () {
    test('ShopProfile.defaultProfile does not contain FlyTowards branding', () {
      final defaultProf = ShopProfile.defaultProfile();
      expect(defaultProf.shopName.toLowerCase().contains('flytowards'), isFalse);
      expect(defaultProf.email.toLowerCase().contains('flytowards'), isFalse);
      expect(defaultProf.logoBase64, isEmpty);
    });

    test('ShopProfile.fromJson sanitizes legacy FlyTowards fields', () {
      final legacyJson = {
        'companyId': 'legacy-comp',
        'shopName': 'Flytowards digital innovation',
        'ownerName': 'Flytowards Hub',
        'email': 'info@flytowardsdigitalinnovation.com',
        'logoBase64': kDefaultFlyTowardsLogoBase64,
        'mobile': '9080999823',
      };

      final parsed = ShopProfile.fromJson(legacyJson);
      expect(parsed.shopName.toLowerCase().contains('flytowards'), isFalse);
      expect(parsed.email, isEmpty);
      expect(parsed.logoBase64, isEmpty);
    });

    test('ShopProfile.fromJson preserves genuine custom company details', () {
      final customJson = {
        'companyId': 'custom-123',
        'shopName': 'Balaji Textiles & Garments',
        'ownerName': 'Balaji V',
        'email': 'contact@balajitestiles.com',
        'logoBase64': '',
        'mobile': '9840123456',
      };

      final parsed = ShopProfile.fromJson(customJson);
      expect(parsed.shopName, 'Balaji Textiles & Garments');
      expect(parsed.email, 'contact@balajitestiles.com');
      expect(parsed.mobile, '9840123456');
    });
  });

  group('PDF Generation & Footer Tests', () {
    test('generates 58mm, 80mm, 127mm, A5, and A4 PDFs with valid PDF headers', () async {
      for (final size in BillPaperSize.values) {
        final pdfBytes = await PdfService.generateInvoicePdf(
          invoice: testInvoice,
          shopProfile: customShop,
          paperSize: size,
        );
        expect(pdfBytes, isNotEmpty);
        // Standard PDF signature "%PDF-"
        final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
        expect(header, '%PDF-');
      }
    });

    test('generates Quotation PDF with valid format and header', () async {
      final quotBytes = await PdfService.generateQuotationPdf(
        invoice: testQuotation,
        shopProfile: customShop,
        paperSize: BillPaperSize.a4,
      );
      expect(quotBytes, isNotEmpty);
      final header = String.fromCharCodes(quotBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });

  group('ESC/POS Thermal Receipt MT580P Tests', () {
    test('generateInvoiceEscPos outputs "Thank You! Visit Again" and actual shop name', () {
      final escPosBytes = BluetoothPrinterService.generateInvoiceEscPos(
        invoice: testInvoice,
        shopProfile: customShop,
        paperSize: BillPaperSize.mm58,
      );

      final decoded = latin1.decode(escPosBytes);
      expect(decoded.contains('Thank You! Visit Again'), isTrue);
      expect(decoded.contains('Balaji Textiles & Garments'), isTrue);
      expect(decoded.toLowerCase().contains('flytowards'), isFalse);
    });

    test('generateTestReceiptEscPos outputs actual shop name and no FlyTowards', () {
      final testBytes = BluetoothPrinterService.generateTestReceiptEscPos(
        shopProfile: customShop,
        paperSize: BillPaperSize.mm58,
      );

      final decoded = latin1.decode(testBytes);
      expect(decoded.contains('BALAJI'), isTrue);
      expect(decoded.toLowerCase().contains('flytowards'), isFalse);
    });
  });

  group('PDF Download / Disk File Writing Tests', () {
    test('writes generated invoice and quotation PDF files directly to temporary storage', () async {
      final invoicePdf = await PdfService.generateInvoicePdf(
        invoice: testInvoice,
        shopProfile: customShop,
        paperSize: BillPaperSize.mm58,
      );
      final tempFile = File('${Directory.systemTemp.path}\\test_download_inv.pdf');
      await tempFile.writeAsBytes(invoicePdf);
      expect(await tempFile.exists(), isTrue);
      expect(await tempFile.length(), greaterThan(1000));
      await tempFile.delete();

      final quotPdf = await PdfService.generateQuotationPdf(
        invoice: testQuotation,
        shopProfile: customShop,
        paperSize: BillPaperSize.a4,
      );
      final tempQuotFile = File('${Directory.systemTemp.path}\\test_download_quot.pdf');
      await tempQuotFile.writeAsBytes(quotPdf);
      expect(await tempQuotFile.exists(), isTrue);
      expect(await tempQuotFile.length(), greaterThan(1000));
      await tempQuotFile.delete();
    });
  });

  group('InvoiceItem Size & Description Tests', () {
    test('InvoiceItem default constructor does not include (Size: M)', () {
      final item = InvoiceItem(
        id: 'test-size-1',
        description: 'Cotton Shirt',
        quantity: 1,
        unitPrice: 500.0,
      );
      expect(item.size, isEmpty);
      expect(item.fullDescription, equals('Cotton Shirt'));
      expect(item.fullDescription.contains('Size:'), isFalse);
      expect(item.fullDescription.contains('Size: M'), isFalse);
    });

    test('InvoiceItem.fromJson with no size defaults to empty string', () {
      final json = {
        'id': 'test-size-2',
        'description': 'Linen Kurti',
        'quantity': 2,
        'unitPrice': 750.0,
      };
      final item = InvoiceItem.fromJson(json);
      expect(item.size, isEmpty);
      expect(item.fullDescription, equals('Linen Kurti'));
    });

    test('InvoiceItem with explicit size formats correctly', () {
      final item = InvoiceItem(
        id: 'test-size-3',
        description: 'Silk Kurti',
        quantity: 1,
        unitPrice: 1200.0,
        size: 'XL',
      );
      expect(item.fullDescription, equals('Silk Kurti (Size: XL)'));
    });

    test('InvoiceItem with Free Size or N/A does not format size', () {
      final item1 = InvoiceItem(
        id: 'test-size-4',
        description: 'Dupatta',
        quantity: 1,
        unitPrice: 200.0,
        size: 'Free Size',
      );
      expect(item1.fullDescription, equals('Dupatta'));

      final item2 = InvoiceItem(
        id: 'test-size-5',
        description: 'Stole',
        quantity: 1,
        unitPrice: 150.0,
        size: 'N/A',
      );
      expect(item2.fullDescription, equals('Stole'));
    });

    test('InvoiceItem strips embedded (Size: M) or (size : m) from legacy descriptions', () {
      final item = InvoiceItem.fromJson({
        'id': 'test-legacy-1007',
        'description': 'test (Size: M)',
        'quantity': 1,
        'unitPrice': 100.0,
        'size': 'M',
      });
      expect(item.description, equals('test'));
      expect(item.size, isEmpty);
      expect(item.fullDescription, equals('test'));
      expect(item.fullDescription.toLowerCase().contains('(size: m)'), isFalse);
    });
  });

  group('Universal Commercial Printing Architecture Tests', () {
    test('UniversalPrinterConfig properties and labels operate correctly', () {
      const autoConfig = UniversalPrinterConfig(
        type: PrinterConnectionType.auto,
        name: 'Windows System Default',
      );
      expect(autoConfig.isAuto, isTrue);
      expect(autoConfig.isSystem, isFalse);
      expect(autoConfig.typeLabel, equals('Windows System Default'));

      const spoolerDocConfig = UniversalPrinterConfig(
        type: PrinterConnectionType.system,
        name: 'Canon G2000 series',
        isThermal: false,
      );
      expect(spoolerDocConfig.isSystem, isTrue);
      expect(spoolerDocConfig.isThermal, isFalse);
      expect(spoolerDocConfig.typeLabel, equals('Document Printer (Spooler)'));

      const spoolerThermalConfig = UniversalPrinterConfig(
        type: PrinterConnectionType.system,
        name: 'POS-80',
        isThermal: true,
      );
      expect(spoolerThermalConfig.isSystem, isTrue);
      expect(spoolerThermalConfig.isThermal, isTrue);
      expect(spoolerThermalConfig.typeLabel, equals('Thermal Spooler Driver'));

      const btConfig = UniversalPrinterConfig(
        type: PrinterConnectionType.bluetooth,
        name: 'InnerPrinter',
        address: '00:11:22:33:44:55',
        isThermal: true,
      );
      expect(btConfig.isBluetooth, isTrue);
      expect(btConfig.typeLabel, equals('Bluetooth Thermal (SPP)'));

      const serialConfig = UniversalPrinterConfig(
        type: PrinterConnectionType.serial,
        name: 'COM5',
        address: 'COM5',
        isThermal: true,
      );
      expect(serialConfig.isSerial, isTrue);
      expect(serialConfig.typeLabel, equals('Serial / USB COM Port'));
    });

    test('UniversalPrinterConfig copyWith updates fields correctly', () {
      const initial = UniversalPrinterConfig(
        type: PrinterConnectionType.auto,
        name: 'Default',
      );
      final updated = initial.copyWith(
        type: PrinterConnectionType.system,
        name: 'Canon G2000',
        address: 'USB001',
        isThermal: false,
      );
      expect(updated.type, equals(PrinterConnectionType.system));
      expect(updated.name, equals('Canon G2000'));
      expect(updated.address, equals('USB001'));
      expect(updated.isThermal, isFalse);
    });

    test('generateTestReceiptEscPos generates valid ESC/POS byte sequence', () {
      final bytes58 = BluetoothPrinterService.generateTestReceiptEscPos(
        shopProfile: customShop,
        paperSize: BillPaperSize.mm58,
      );
      expect(bytes58, isNotEmpty);
      expect(bytes58.first, equals(0x1B)); // ESC @ initialize command
      expect(bytes58[1], equals(0x40));

      final textOutput = utf8.decode(bytes58, allowMalformed: true);
      expect(textOutput.contains(customShop.shopName.toUpperCase()), isTrue);
      expect(textOutput.contains('THERMAL PRINTER TEST'), isTrue);
      expect(textOutput.contains('Thank You! Visit Again'), isTrue);

      final bytes80 = BluetoothPrinterService.generateTestReceiptEscPos(
        shopProfile: customShop,
        paperSize: BillPaperSize.mm80,
      );
      expect(bytes80, isNotEmpty);
      expect(bytes80.length, greaterThan(100));
    });

    test('EscPosBuilder sanitizes unicode rupee and special characters', () {
      final builder = EscPosBuilder();
      builder.textLine('Total: ₹ 1500.00 — Item “Special”');
      final decoded = utf8.decode(builder.bytes, allowMalformed: true);
      expect(decoded.contains('Rs. 1500.00'), isTrue);
      expect(decoded.contains('- Item "Special"'), isTrue);
    });
  });
}
