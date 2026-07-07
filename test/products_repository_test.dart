import 'package:flutter_test/flutter_test.dart';
import 'package:dissuplain_app_web_mobile/dataLayer/orders_repository.dart';

void main() {
  group('ProductRow', () {
    test('uses a fallback product code when the payload has no productCode field', () {
      final row = ProductRow.fromMap(
        {
          'productName': 'Demo Product',
          'MRP': 120,
          'Rate': 100,
        },
        fallbackCode: 'P-001',
      );

      expect(row.productCode, 'P-001');
      expect(row.productName, 'Demo Product');
      expect(row.mrp, 120);
      expect(row.rate, 100);
    });

    test('uses the stored product rate instead of recomputing from MRP', () {
      final product = ProductRow(
        productCode: 'NEW-1',
        productName: 'New Product',
        mrp: 100,
        rate: 90,
        freePer10: 0,
      );

      expect(ProductRow.resolveRate(product), 90);
    });

    test('shows newly added products when category mappings are still incomplete', () {
      final products = [
        ProductRow(productCode: 'NEW-1', productName: 'New Product', mrp: 100, rate: 90, freePer10: 0),
      ];
      final rows = [
        ProductCategoryRow(
          productCode: 'OLD-1',
          categoryCode: 'S',
          discountNET: 0,
          discountScheme: 0,
          freePer10Scheme: 0,
          netBulkMOQ: 0,
          schemeBulkMOQ: 0,
          discountNETBulk: 0,
          discountSchemeBulk: 0,
          freeQtyBulkScheme: 0,
        ),
      ];

      final visible = OrdersRepository.filterProductsForCategory(
        products: products,
        productCategoryRows: rows,
        categoryCode: 'S',
      );

      expect(visible.map((p) => p.productCode), ['NEW-1']);
    });
  });
}
