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
  final int netBulkMOQ;
  final int schemeBulkMOQ;
  final double discountNETBulk;
  final double discountSchemeBulk;
  final int freeQtyBulkScheme;

  ProductCategoryRow({
    required this.productCode,
    required this.categoryCode,
    required this.discountNET,
    required this.discountScheme,
    required this.freePer10Scheme,
    required this.netBulkMOQ,
    required this.schemeBulkMOQ,
    required this.discountNETBulk,
    required this.discountSchemeBulk,
    required this.freeQtyBulkScheme,
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
      netBulkMOQ: _i(m['NETBulkMOQ']),
      schemeBulkMOQ: _i(m['SchemeBulkMOQ']),
      discountNETBulk: _d(m['discountNETBulk']),
      discountSchemeBulk: _d(m['discountSchemeBulk']),
      freeQtyBulkScheme: _i(m['freeQtyBulkScheme']),
    );
  }

  static ProductCategoryRow empty() => ProductCategoryRow(
    productCode: '',
    categoryCode: '',
    discountNET: 0,
    discountScheme: 0,
    freePer10Scheme: 0,
    netBulkMOQ: 0,
    schemeBulkMOQ: 0,
    discountNETBulk: 0,
    discountSchemeBulk: 0,
    freeQtyBulkScheme: 0,
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

class OrderDisplayLine {
  final String productCode;
  final String productName;
  final double productMRP;
  final int billQuantity;
  final int freeQuantity;
  final double rate;
  final double totalAmount;
  final String billingType;
  OrderDisplayLine({
    required this.productCode,
    required this.productName,
    required this.productMRP,
    required this.billQuantity,
    required this.freeQuantity,
    required this.rate,
    required this.totalAmount,
    required this.billingType,
  });
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
  final String amApproverID;
  final String gmApproverID;
  final String ceoApproverID;
  final Map<String, dynamic>? productsDetail; // MP-only
  final double? grandTotal; // MP-only (header sum)

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
    required this.amApproverID,
    required this.gmApproverID,
    required this.ceoApproverID,
    this.productsDetail,
    this.grandTotal,
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
      amApproverID: (m['amApproverID'] ?? '').toString(),
      gmApproverID: (m['gmApproverID'] ?? '').toString(),
      ceoApproverID: (m['ceoApproverID'] ?? '').toString(),
      productsDetail: (m['productsDetail'] is Map)
          ? Map<String, dynamic>.from(m['productsDetail'] as Map)
          : null,
      grandTotal: (m['grandTotal'] != null) ? _d(m['grandTotal']) : null,
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
    required String salesPersonID,
    String amApproverID = '',
    String gmApproverID = '',
    String ceoApproverID = '',
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
      'salesPersonID': salesPersonID,
      'amApproverID': amApproverID,
      'gmApproverID': gmApproverID,
      'ceoApproverID': ceoApproverID,
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

  Future<void> addMPOrder({
    required String customerCode,
    required String orderType,
    required String distributorID,
    required String salesPersonID,
    String amApproverID = '',
    String gmApproverID = '',
    String ceoApproverID = '',
    required double grandTotal,
    required Map<String, Map<String, dynamic>> productsDetail,
  }) async {
    final now = DateTime.now();
    final orderID = _makeOrderId(now);

    await _ordersRoot.child(customerCode).child(orderID).set({
      'customerCode': customerCode,
      'distributorID': distributorID,
      'orderConfirmation': 'New',
      'orderDate': now.millisecondsSinceEpoch,
      'orderID': orderID,
      'orderType': orderType,
      'grandTotal': grandTotal,
      'productsDetail': productsDetail, // { productCode: {...fields...}, ... }
      'salesPersonID': salesPersonID,
      'amApproverID': amApproverID,
      'gmApproverID': gmApproverID,
      'ceoApproverID': ceoApproverID,
    });
  }

  Future<void> updateConfirmation(
    String customerCode,
    String orderID,
    String newStatus, {
    String? approverId,
  }) async {
    final data = <String, Object?>{'orderConfirmation': newStatus};

    final id = approverId?.trim() ?? '';
    switch (newStatus) {
      case 'AM Confirmed':
        data['amApproverID'] = id;
        data['gmApproverID'] = '';
        data['ceoApproverID'] = '';
        break;
      case 'GM Confirmed':
        if (id.isNotEmpty) data['gmApproverID'] = id;
        break;
      case 'CEO Confirmed':
        if (id.isNotEmpty) data['ceoApproverID'] = id;
        break;
      case 'Cancelled':
      default:
        break;
    }
    await _ordersRoot.child(customerCode).child(orderID).update(data);
  }

  String _makeOrderId(DateTime dt) {
    final yy = dt.year.toString().padLeft(4, '0');
    final MM = dt.month.toString().padLeft(2, '0');
    final DD = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return 'ORD-$yy$MM$DD$hh$mm$ss';
  }

  List<OrderDisplayLine> linesFromEntryMP(OrderEntry h) {
    try {
      final dyn = h as dynamic;
      final raw = dyn.productsDetail as Map?; // must exist in MP orders
      if (raw == null || raw.isEmpty) return const <OrderDisplayLine>[];

      double _d(x) => x is num ? x.toDouble() : double.tryParse('$x') ?? 0.0;
      int _i(x) => x is num ? x.toInt() : int.tryParse('$x') ?? 0;

      final out = <OrderDisplayLine>[];
      raw.forEach((code, v) {
        final m = (v as Map).cast<String, dynamic>();
        out.add(
          OrderDisplayLine(
            productCode: '$code',
            productName: (m['productName'] ?? '').toString(),
            productMRP: _d(m['productMRP']),
            billQuantity: _i(m['billQuantity']),
            freeQuantity: _i(m['freeQuantity']),
            rate: _d(m['rate']),
            totalAmount: _d(m['totalAmount']),
            billingType: (m['billingType'] ?? 'NET').toString(),
          ),
        );
      });
      return out;
    } catch (_) {
      return const <OrderDisplayLine>[];
    }
  }

  double grandTotalFromEntryMP(OrderEntry h) {
    final lines = linesFromEntryMP(h);
    final sum = lines.fold<double>(0.0, (a, b) => a + b.totalAmount);
    return double.parse(sum.toStringAsFixed(2));
  }
}
