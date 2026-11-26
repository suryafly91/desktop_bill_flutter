import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billing_app/models/product.dart';
import 'package:billing_app/providers/billing_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product Sequential ID and SKU Range Tests', () {
    late BillingProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = BillingProvider();
    });

    test('Initial SKU range starts from 0001 when catalog is empty', () {
      expect(provider.products.isEmpty, isTrue);
      // Default stock of 10 items
      final range10 = provider.calculateProductSkuRange(10);
      expect(range10, equals('0001 to 0010'));

      // Stock of 1 item
      final range1 = provider.calculateProductSkuRange(1);
      expect(range1, equals('0001'));
    });

    test('Product ID does NOT reverse backwards when stock is sold or adjusted', () {
      // Simulate adding a product that ended at 1499 (e.g. "1490 to 1499")
      final product1 = Product(
        id: 'prod-001',
        name: 'Silk Saree Blue',
        mrpPrice: 1500,
        unitPrice: 1200,
        stockQuantity: 10,
        sku: '1490 to 1499',
      );
      provider.addProduct(product1);

      // Verify max SKU unit is 1499
      expect(provider.getMaxSkuUnit(), equals(1499));

      // Simulate selling 4 units in billing (stock drops to 6)
      provider.adjustProductStock(product1.id, 6);
      expect(provider.totalStockUnits, equals(6));

      // In the old buggy code, startUnit would be totalStockUnits + 1 = 6 + 1 = 7 (or 1495 + 1 = 1496)!
      // In the fixed code, it must start at 1500, never reversing backwards!
      final nextRange = provider.calculateProductSkuRange(10);
      expect(nextRange, equals('1500 to 1509'));

      final nextSingleRange = provider.calculateProductSkuRange(1);
      expect(nextSingleRange, equals('1500'));
    });

    test('Handles single numeric SKU like "1499" and increments to 1500', () {
      final product1 = Product(
        id: 'prod-001',
        name: 'Cotton Kurti',
        mrpPrice: 999,
        unitPrice: 799,
        stockQuantity: 1,
        sku: '1499',
      );
      provider.addProduct(product1);

      expect(provider.getMaxSkuUnit(), equals(1499));

      // Next product with stock 10 must start at 1500
      final nextRange = provider.calculateProductSkuRange(10);
      expect(nextRange, equals('1500 to 1509'));

      // Next product with stock 1 must be 1500
      final nextSingle = provider.calculateProductSkuRange(1);
      expect(nextSingle, equals('1500'));
    });

    test('nextProductId is strictly monotonic and does not duplicate on deletion', () {
      final p1 = Product(id: 'prod-001', name: 'Item 1', mrpPrice: 100, unitPrice: 100, stockQuantity: 5);
      final p2 = Product(id: 'prod-002', name: 'Item 2', mrpPrice: 100, unitPrice: 100, stockQuantity: 5);
      final p3 = Product(id: 'prod-003', name: 'Item 3', mrpPrice: 100, unitPrice: 100, stockQuantity: 5);

      provider.addProduct(p1);
      provider.addProduct(p2);
      provider.addProduct(p3);

      expect(provider.nextProductId, equals('004'));

      // Delete prod-002
      provider.deleteProduct(p2.id);
      expect(provider.products.length, equals(2));

      // nextProductId should still be 004, NOT 003
      expect(provider.nextProductId, equals('004'));
    });

    test('calculateProductSkuRange with excludeProductId ignores the product being edited', () {
      final p1 = Product(id: 'prod-001', name: 'Item 1', mrpPrice: 100, unitPrice: 100, stockQuantity: 10, sku: '1490 to 1499');
      // Suppose p2 was mistakenly added with 1496 to 1505
      final p2 = Product(id: 'prod-002', name: 'Item 2', mrpPrice: 100, unitPrice: 100, stockQuantity: 10, sku: '1496 to 1505');

      provider.addProduct(p1);
      provider.addProduct(p2);

      // Recalculating SKU for p2 by excluding p2 should find max from p1 (1499) and assign 1500 to 1509
      final fixedRange = provider.calculateProductSkuRange(10, excludeProductId: p2.id);
      expect(fixedRange, equals('1500 to 1509'));
    });

    test('isSkuDuplicate detects existing SKU collisions', () {
      final p1 = Product(id: 'prod-001', name: 'Item 1', mrpPrice: 100, unitPrice: 100, stockQuantity: 10, sku: '1490 to 1499');
      provider.addProduct(p1);

      expect(provider.isSkuDuplicate('1490 to 1499'), isTrue);
      expect(provider.isSkuDuplicate('1490 TO 1499'), isTrue);
      expect(provider.isSkuDuplicate('1500 to 1509'), isFalse);

      // Excluding self during edit should not report duplicate
      expect(provider.isSkuDuplicate('1490 to 1499', excludeProductId: p1.id), isFalse);
    });

    test('Product.matchesQuery matches individual item numbers within a range', () {
      final product = Product(
        id: 'prod-001',
        name: 'Kanchipuram Pattu Saree',
        mrpPrice: 5000,
        unitPrice: 4200,
        stockQuantity: 10,
        category: 'Silk Sarees',
        color: 'Crimson Red',
        material: 'Pure Silk',
        size: 'Free Size',
        sku: '1490 to 1499',
      );

      // Searching exact SKU
      expect(product.matchesQuery('1490 to 1499'), isTrue);

      // Searching a unit number inside the range (1496)
      expect(product.matchesQuery('1496'), isTrue);
      expect(product.matchesQuery('1490'), isTrue);
      expect(product.matchesQuery('1499'), isTrue);

      // Number outside the range
      expect(product.matchesQuery('1489'), isFalse);
      expect(product.matchesQuery('1500'), isFalse);

      // Text attributes
      expect(product.matchesQuery('Kanchipuram'), isTrue);
      expect(product.matchesQuery('Silk Sarees'), isTrue);
      expect(product.matchesQuery('Crimson'), isTrue);
      expect(product.matchesQuery('Pure Silk'), isTrue);
      expect(product.matchesQuery('prod-001'), isTrue);
    });
  });
}
