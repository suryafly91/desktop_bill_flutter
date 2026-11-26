import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billing_app/models/product.dart';
import 'package:billing_app/models/invoice.dart';
import 'package:billing_app/models/invoice_item.dart';
import 'package:billing_app/providers/billing_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product Variant Separation and Billing Tests', () {
    late BillingProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = BillingProvider();
    });

    test('1. Reverse Product List displays newly added products latest-first', () {
      final p1 = Product(id: 'prod-001', name: 'Cotton Shirt', mrpPrice: 500, unitPrice: 400, stockQuantity: 10, size: 'M');
      final p2 = Product(id: 'prod-002', name: 'Linen Shirt', mrpPrice: 600, unitPrice: 500, stockQuantity: 15, size: 'L');
      final p3 = Product(id: 'prod-003', name: 'Silk Kurti', mrpPrice: 800, unitPrice: 700, stockQuantity: 20, size: 'XL');

      provider.addProduct(p1);
      provider.addProduct(p2);
      provider.addProduct(p3);

      expect(provider.products.length, equals(3));
      expect(provider.products.first.id, equals('prod-003'));
      expect(provider.products[1].id, equals('prod-002'));
      expect(provider.products.last.id, equals('prod-001'));
    });

    test('2. Products with same name and price but different sizes are treated separately and matched by Name + Price + Size', () {
      final pSmall = Product(id: 'prod-001', name: 'Casual T-Shirt', mrpPrice: 499, unitPrice: 399, stockQuantity: 10, size: 'S');
      final pMedium = Product(id: 'prod-002', name: 'Casual T-Shirt', mrpPrice: 499, unitPrice: 399, stockQuantity: 10, size: 'M');
      final pLarge = Product(id: 'prod-003', name: 'Casual T-Shirt', mrpPrice: 499, unitPrice: 399, stockQuantity: 10, size: 'L');

      provider.addProduct(pSmall);
      provider.addProduct(pMedium);
      provider.addProduct(pLarge);

      // findProductIndex matches exact variant
      final idxSmall = provider.findProductIndex(name: 'Casual T-Shirt', price: 399, size: 'S');
      final idxMedium = provider.findProductIndex(name: 'Casual T-Shirt', price: 399, size: 'M');
      final idxLarge = provider.findProductIndex(name: 'Casual T-Shirt', price: 399, size: 'L');

      expect(idxSmall, isNot(equals(-1)));
      expect(idxMedium, isNot(equals(-1)));
      expect(idxLarge, isNot(equals(-1)));

      expect(provider.products.firstWhere((p) => p.size == 'S').id, equals('prod-001'));
      expect(provider.products.firstWhere((p) => p.size == 'M').id, equals('prod-002'));
      expect(provider.products.firstWhere((p) => p.size == 'L').id, equals('prod-003'));
    });

    test('3. Stock deduction affects only the specific size variant billed', () {
      final pSmall = Product(id: 'prod-001', name: 'Denim Jeans', mrpPrice: 1200, unitPrice: 999, stockQuantity: 15, size: '30');
      final pLarge = Product(id: 'prod-002', name: 'Denim Jeans', mrpPrice: 1200, unitPrice: 999, stockQuantity: 20, size: '34');

      provider.addProduct(pSmall);
      provider.addProduct(pLarge);

      // Bill 5 units of Size 30 only
      final invoice = Invoice(
        id: 'inv-001',
        invoiceNumber: 'INV-001',
        customerId: 'cust-1',
        customerName: 'Customer A',
        customerEmail: '',
        customerPhone: '',
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        status: InvoiceStatus.paid,
        items: [
          InvoiceItem(
            id: 'item-1',
            description: 'Denim Jeans',
            quantity: 5,
            unitPrice: 999,
            size: '30',
          ),
        ],
      );

      provider.addInvoice(invoice);

      final updatedSmall = provider.products.firstWhere((p) => p.id == 'prod-001');
      final updatedLarge = provider.products.firstWhere((p) => p.id == 'prod-002');

      // Size 30 reduced from 15 to 10
      expect(updatedSmall.stockQuantity, equals(10));
      // Size 34 remains untouched at 20
      expect(updatedLarge.stockQuantity, equals(20));
    });

    test('4. Invoices with multiple sizes calculate independently and do not merge quantities', () {
      final pS = Product(id: 'prod-s', name: 'Polo Shirt', mrpPrice: 800, unitPrice: 600, stockQuantity: 10, size: 'S');
      final pM = Product(id: 'prod-m', name: 'Polo Shirt', mrpPrice: 800, unitPrice: 600, stockQuantity: 10, size: 'M');

      provider.addProduct(pS);
      provider.addProduct(pM);

      final itemS = InvoiceItem(
        id: 'i1',
        description: 'Polo Shirt',
        quantity: 2,
        unitPrice: 600,
        size: 'S',
      );
      final itemM = InvoiceItem(
        id: 'i2',
        description: 'Polo Shirt',
        quantity: 3,
        unitPrice: 600,
        size: 'M',
      );

      final invoice = Invoice(
        id: 'inv-002',
        invoiceNumber: 'INV-002',
        customerId: 'cust-2',
        customerName: 'Customer B',
        customerEmail: '',
        customerPhone: '',
        issueDate: DateTime.now(),
        dueDate: DateTime.now(),
        status: InvoiceStatus.paid,
        items: [itemS, itemM],
      );

      provider.addInvoice(invoice);

      expect(invoice.items.length, equals(2));
      expect(invoice.items[0].totalPrice, equals(1200.0));
      expect(invoice.items[1].totalPrice, equals(1800.0));
      expect(invoice.totalAmount, equals(3000.0));

      final checkS = provider.products.firstWhere((p) => p.id == 'prod-s');
      final checkM = provider.products.firstWhere((p) => p.id == 'prod-m');

      expect(checkS.stockQuantity, equals(8));
      expect(checkM.stockQuantity, equals(7));
    });
  });
}
