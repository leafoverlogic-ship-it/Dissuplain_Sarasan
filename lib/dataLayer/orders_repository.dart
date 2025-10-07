import 'package:firebase_database/firebase_database.dart';

class ProductRow {
  final String productCode;
  final String productName;
  final double mrp;
  final int freePer10;

  ProductRow({
    required this.productCode,
    required this.productName,
    required this.mrp,
    required this.freePer10,
  });

  factory ProductRow.fromMap(Map m) {
    double _d(v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
    int _i(v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return ProductRow(
      productCode: (m['productCode'] ?? '').toString(),
      productName: (m['productName'] ?? '').toString(),
      mrp: _d(m['MRP'] ?? m['mrp']),
      freePer10: _i(m['freeQtyPer10'] ?? m['freeQty'] ?? 0),
    );
  }
}

class ProductCategoryRow {
  final String productCode; // e.g. "NEO50"
  final String categoryCode; // e.g. "C"
  final double discountNET; // e.g. 0.44  (44% off)
  final double discountScheme; // e.g. 0.3825 (38.25% off)
  final int freePer10Scheme; // e.g. 1

  ProductCategoryRow({
    required this.productCode,
    required this.categoryCode,
    required this.discountNET,
    required this.discountScheme,
    required this.freePer10Scheme,
  });

  factory ProductCategoryRow.fromMap(Map m) {
    double _d(v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
    int _i(v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return ProductCategoryRow(
      productCode: (m['productCode'] ?? '').toString(),
      categoryCode: (m['categoryCode'] ?? '').toString(),
      discountNET: _d(m['discountNET']),
      discountScheme: _d(m['discountScheme']),
      freePer10Scheme: _i(m['freeQtyPer10Scheme']),
    );
  }

  static ProductCategoryRow empty() => ProductCategoryRow(
    productCode: '',
    categoryCode: '',
    discountNET: 0,
    discountScheme: 0,
    freePer10Scheme: 0,
  );
}

class CategoryRow {
  final String catCode;
  final String name;
  CategoryRow({required this.catCode, required this.name});

  factory CategoryRow.fromMap(Map m) => CategoryRow(
    catCode: (m['categoryCode'] ?? '').toString().trim(),
    name: (m['categoryName'] ?? '').toString().trim(),
  );
}

class DistributorRow {
  final String distributorID;
  final String firmName;
  final String? areaID;
  DistributorRow({
    required this.distributorID,
    required this.firmName,
    this.areaID,
  });

  factory DistributorRow.fromMap(Map m) {
    return DistributorRow(
      distributorID: (m['distributorID'] ?? '').toString(),
      firmName: (m['firmName'] ?? '').toString(),
      areaID: m['areaID']?.toString(),
    );
  }
}

class OrderEntry {
  final String orderID;
  final int orderDate;
  final String customerCode;
  final String orderType;
  final String billingType;
  final String productCode;
  final String productName;
  final double productMRP;
  final int billQuantity;
  final int freeQuantity;
  final double rate;
  final double totalAmount;
  final String distributorID;
  final String orderConfirmation;

  OrderEntry({
    required this.orderID,
    required this.orderDate,
    required this.customerCode,
    required this.orderType,
    required this.billingType,
    required this.productCode,
    required this.productName,
    required this.productMRP,
    required this.billQuantity,
    required this.freeQuantity,
    required this.rate,
    required this.totalAmount,
    required this.distributorID,
    required this.orderConfirmation,
  });

  factory OrderEntry.fromMap(String id, Map m) {
    double _d(v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
    int _i(v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return OrderEntry(
      orderID: (m['orderID'] ?? id).toString(),
      orderDate: _i(m['orderDate']),
      customerCode: (m['customerCode'] ?? '').toString(),
      orderType: (m['orderType'] ?? '').toString(),
      billingType: (m['billingType'] ?? '').toString(),
      productCode: (m['productCode'] ?? '').toString(),
      productName: (m['productName'] ?? '').toString(),
      productMRP: _d(m['productMRP']),
      billQuantity: _i(m['billQuantity']),
      freeQuantity: _i(m['freeQuantity']),
      rate: _d(m['rate']),
      totalAmount: _d(m['totalAmount']),
      distributorID: (m['distributorID'] ?? '').toString(),
      orderConfirmation: (m['orderConfirmation'] ?? 'New').toString(),
    );
  }
}

class OrdersRepository {
  final DatabaseReference _ordersRoot = FirebaseDatabase.instance.ref('Orders');
  final DatabaseReference _productsRef = FirebaseDatabase.instance.ref(
    'Products',
  );
  final DatabaseReference _distributorsRef = FirebaseDatabase.instance.ref(
    'Distributors',
  );

  Stream<List<ProductRow>> streamProducts() {
    return _productsRef.onValue.map((event) {
      final out = <ProductRow>[];
      for (final c in event.snapshot.children) {
        final v = c.value;
        if (v is Map) out.add(ProductRow.fromMap(v));
      }
      out.sort((a, b) => a.productCode.compareTo(b.productCode));
      return out;
    });
  }

  Stream<List<ProductCategoryRow>> streamProductCategories() {
    final ref = FirebaseDatabase.instance.ref('ProductCategory');
    return ref.onValue.map((event) {
      final list = <ProductCategoryRow>[];
      for (final c in event.snapshot.children) {
        final v = c.value;
        if (v is Map) list.add(ProductCategoryRow.fromMap(v));
      }
      return list;
    });
  }

  Stream<List<DistributorRow>> streamDistributors() {
    return _distributorsRef.onValue.map((event) {
      final out = <DistributorRow>[];
      for (final c in event.snapshot.children) {
        final v = c.value;
        if (v is Map) out.add(DistributorRow.fromMap(v));
      }
      out.sort(
        (a, b) => a.firmName.toLowerCase().compareTo(b.firmName.toLowerCase()),
      );
      return out;
    });
  }

  Stream<List<OrderEntry>> streamForCustomer(String customerCode) {
    final q = _ordersRoot.child(customerCode);
    return q.onValue.map((event) {
      final out = <OrderEntry>[];
      for (final c in event.snapshot.children) {
        final v = c.value;
        if (v is Map) out.add(OrderEntry.fromMap(c.key ?? '', v));
      }
      out.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      return out;
    });
  }

  Future<String> getCategoryCodeByName(String categoryName) async {
    try {
      final snap = await FirebaseDatabase.instance.ref('Categories').get();
      for (final child in snap.children) {
        final v = child.value;
        if (v is Map) {
          final row = CategoryRow.fromMap(v);
          if (row.name.toLowerCase() == categoryName.trim().toLowerCase()) {
            return row.catCode; // e.g. "S", "C", "P"
          }
        }
      }
    } catch (_) {}
    return '';
  }

  Future<void> addOrder({
    required String customerCode,
    required String orderType,
    required String billingType,
    required String productCode,
    required String productName,
    required double productMRP,
    required int billQuantity,
    required int freeQuantity,
    required double rate,
    required double totalAmount,
    required String distributorID,
  }) async {
    final now = DateTime.now();
    final orderID = _makeOrderId(now);
    await _ordersRoot.child(customerCode).child(orderID).set({
      'orderID': orderID,
      'orderDate': now.millisecondsSinceEpoch,
      'customerCode': customerCode,
      'orderType': orderType,
      'billingType': billingType,
      'productCode': productCode,
      'productName': productName,
      'productMRP': productMRP,
      'billQuantity': billQuantity,
      'freeQuantity': freeQuantity,
      'rate': rate,
      'totalAmount': totalAmount,
      'distributorID': distributorID,
      'orderConfirmation': 'New',
    });
  }

  Future<void> updateConfirmation(
    String customerCode,
    String orderID,
    String newStatus,
  ) async {
    await _ordersRoot.child(customerCode).child(orderID).update({
      'orderConfirmation': newStatus,
    });
  }

  String _makeOrderId(DateTime dt) {
    final yy = dt.year.toString().padLeft(4, '0');
    final MM = dt.month.toString().padLeft(2, '0');
    final DD = dt.day.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return 'ORD-$yy$MM$DD$mm$ss';
  }
}
