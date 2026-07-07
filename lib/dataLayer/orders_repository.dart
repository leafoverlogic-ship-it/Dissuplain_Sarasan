import 'package:firebase_database/firebase_database.dart';

class ProductRow {
  final String productCode;
  final String productName;
  final double mrp;
  final double rate;
  final int freePer10;
  final String? firebaseKey;

  static double resolveRate(ProductRow product) {
    return product.rate;
  }

  ProductRow({
    required this.productCode,
    required this.productName,
    required this.mrp,
    required this.rate,
    required this.freePer10,
    this.firebaseKey,
  });

  factory ProductRow.fromMap(Map m, {String? fallbackCode, String? firebaseKey}) {
    double _d(v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
    int _i(v) => int.tryParse(v?.toString() ?? '') ?? 0;
    final rawCode = (m['productCode'] ?? fallbackCode ?? '').toString().trim();
    return ProductRow(
      productCode: rawCode,
      productName: (m['productName'] ?? '').toString(),
      mrp: _d(m['MRP'] ?? m['mrp']),
      rate: _d(m['Rate'] ?? m['rate']),
      freePer10: _i(m['freeQtyPer10'] ?? m['freeQty'] ?? 0),
      firebaseKey: firebaseKey,
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
  final int amApprovalDate;
  final int gmApprovalDate;
  final int ceoApprovalDate;
  final String deliveryStatus;
  final int deliveryDate;
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
    required this.amApprovalDate,
    required this.gmApprovalDate,
    required this.ceoApprovalDate,
    required this.deliveryStatus,
    required this.deliveryDate,
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
      amApprovalDate: _i(m['amApprovalDate']),
      gmApprovalDate: _i(m['gmApprovalDate']),
      ceoApprovalDate: _i(m['ceoApprovalDate']),
      deliveryStatus: (m['deliveryStatus'] ?? 'Undelivered').toString(),
      deliveryDate: _i(m['deliveryDate']),
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

  static List<ProductRow> filterProductsForCategory({
    required List<ProductRow> products,
    required List<ProductCategoryRow> productCategoryRows,
    required String categoryCode,
  }) {
    if (products.isEmpty) return const <ProductRow>[];

    final normalizedCategory = categoryCode.trim().toUpperCase();
    if (normalizedCategory.isEmpty || productCategoryRows.isEmpty) {
      return [...products]..
          sort((a, b) => a.productName.compareTo(b.productName));
    }

    final mappedCodes = <String>{};
    for (final row in productCategoryRows) {
      if (row.categoryCode.trim().toUpperCase() == normalizedCategory) {
        mappedCodes.add(row.productCode.trim().toUpperCase());
      }
    }

    if (mappedCodes.isEmpty) {
      return [...products]..
          sort((a, b) => a.productName.compareTo(b.productName));
    }

    final allKnownCodes = <String>{
      for (final row in productCategoryRows)
        row.productCode.trim().toUpperCase(),
    };

    final visible = products.where((p) {
      final code = p.productCode.trim().toUpperCase();
      return mappedCodes.contains(code) || !allKnownCodes.contains(code);
    }).toList();

    visible.sort((a, b) => a.productName.compareTo(b.productName));
    return visible;
  }

  Stream<List<ProductRow>> streamProducts() {
    return _productsRef.onValue.map((event) {
      final out = <ProductRow>[];
      for (final c in event.snapshot.children) {
        final v = c.value;
        if (v is Map) {
          out.add(
            ProductRow.fromMap(
              Map<String, dynamic>.from(v),
              fallbackCode: c.key,
              firebaseKey: c.key,
            ),
          );
        }
      }
      out.sort((a, b) => a.productCode.compareTo(b.productCode));
      return out;
    });
  }

  Future<String?> _findProductStorageKey(String productCode) async {
    final code = productCode.trim();
    if (code.isEmpty) return null;

    final snap = await _productsRef.orderByChild('productCode').equalTo(code).get();
    if (!snap.exists) return null;

    for (final child in snap.children) {
      if (child.key != null && child.key!.isNotEmpty) {
        return child.key!;
      }
    }
    return null;
  }

  Future<void> _removeDuplicateProducts(String productCode, {String? keepKey}) async {
    final code = productCode.trim();
    if (code.isEmpty) return;

    final snap = await _productsRef.orderByChild('productCode').equalTo(code).get();
    if (!snap.exists) return;

    for (final child in snap.children) {
      final key = child.key;
      if (key != null && key.isNotEmpty && key != keepKey) {
        await _productsRef.child(key).remove();
      }
    }
  }

  Future<void> addProduct({
    required String productCode,
    required String productName,
    required double mrp,
    required double rate,
  }) async {
    final code = productCode.trim();
    if (code.isEmpty) return;

    final existingKey = await _findProductStorageKey(code);
    final targetKey = existingKey ?? code;

    await _productsRef.child(targetKey).set({
      'productCode': code,
      'productName': productName.trim(),
      'MRP': mrp,
      'Rate': rate,
      'mrp': mrp,
      'rate': rate,
    });

    await _removeDuplicateProducts(code, keepKey: targetKey);
  }

  Future<void> updateProduct({
    required String oldProductCode,
    required String productCode,
    required String productName,
    required double mrp,
    required double rate,
  }) async {
    final oldCode = oldProductCode.trim();
    final newCode = productCode.trim();
    if (oldCode.isEmpty || newCode.isEmpty) return;

    final oldStorageKey = await _findProductStorageKey(oldCode);
    final existingNewCodeKey = await _findProductStorageKey(newCode);
    final targetKey = existingNewCodeKey ?? oldStorageKey ?? newCode;

    if (oldCode.toLowerCase() != newCode.toLowerCase() && oldStorageKey != null && oldStorageKey != targetKey) {
      await _productsRef.child(oldStorageKey).remove();
    }

    await _productsRef.child(targetKey).set({
      'productCode': newCode,
      'productName': productName.trim(),
      'MRP': mrp,
      'Rate': rate,
      'mrp': mrp,
      'rate': rate,
    });

    await _removeDuplicateProducts(newCode, keepKey: targetKey);
  }

  Future<void> deleteProduct({required String productCode, String? storageKey}) async {
    final code = productCode.trim();
    if (code.isEmpty) return;

    if (storageKey != null && storageKey.trim().isNotEmpty) {
      await _productsRef.child(storageKey.trim()).remove();
    }

    final snap = await _productsRef.orderByChild('productCode').equalTo(code).get();
    if (!snap.exists) return;

    for (final child in snap.children) {
      final key = child.key;
      if (key != null && key.isNotEmpty) {
        await _productsRef.child(key).remove();
      }
    }
  }

  Future<void> clearAllProducts() async {
    await _productsRef.remove();
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
      'amApprovalDate': 0,
      'gmApprovalDate': 0,
      'ceoApprovalDate': 0,
      'deliveryStatus': 'Undelivered',
      'deliveryDate': 0,
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
    required String businessName,
    required String businessAddress,
    required String gstNumber,
    required String contactPerson,
    required String mobileNo,
    bool isFirstOrder = false,
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
      'businessDetails': {
        'businessName': businessName,
        'businessAddress': businessAddress,
        'gstNumber': gstNumber,
        'contactPerson': contactPerson,
        'mobileNo': mobileNo,
      },
      'salesPersonID': salesPersonID,
      'amApproverID': amApproverID,
      'gmApproverID': gmApproverID,
      'ceoApproverID': ceoApproverID,
      'amApprovalDate': 0,
      'gmApprovalDate': 0,
      'ceoApprovalDate': 0,
      'deliveryStatus': 'Undelivered',
      'deliveryDate': 0,
    });

    final clientsQuery = await FirebaseDatabase.instance
        .ref('Clients')
        .orderByChild('customerCode')
        .equalTo(customerCode)
        .get();

    String? clientKey;
    for (final child in clientsQuery.children) {
      if (child.key != null && child.key!.isNotEmpty) {
        clientKey = child.key!;
        break;
      }
    }

    if (clientKey != null) {
      final updateData = {
        'Business_Name': businessName,
        'Business_Address': businessAddress,
        'Business_Contact_Person': contactPerson,
        'Business_Mobile_No': mobileNo,
        'Business_GST_Number': gstNumber,
        'GST_Number': gstNumber,
        'Business_Details_Updated_At': now.millisecondsSinceEpoch,
      };
      // Set Date_of_Opening to the date of the first order
      if (isFirstOrder) {
        updateData['Date_of_Opening'] = now.millisecondsSinceEpoch;
      }
      await FirebaseDatabase.instance.ref('Clients/$clientKey').update(updateData);
    }
  }

  Future<void> updateConfirmation(
    String customerCode,
    String orderID,
    String newStatus, {
    String? approverId,
  }) async {
    final data = <String, Object?>{'orderConfirmation': newStatus};
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final id = approverId?.trim() ?? '';
    switch (newStatus) {
      case 'Awaiting GM Approval':
      case 'AM Confirmed': // legacy
        data['amApproverID'] = id;
        data['gmApproverID'] = '';
        data['ceoApproverID'] = '';
        data['amApprovalDate'] = nowMs;
        data['gmApprovalDate'] = 0;
        data['ceoApprovalDate'] = 0;
        break;
      case 'Awaiting CEO Approval':
      case 'GM Confirmed': // legacy
        if (id.isNotEmpty) data['gmApproverID'] = id;
        data['gmApprovalDate'] = nowMs;
        data['ceoApproverID'] = '';
        data['ceoApprovalDate'] = 0;
        break;
      case 'Confirmed':
      case 'CEO Confirmed': // legacy
        if (id.isNotEmpty) data['ceoApproverID'] = id;
        data['ceoApprovalDate'] = nowMs;
        break;
      case 'AM Cancelled':
        if (id.isNotEmpty) data['amApproverID'] = id;
        data['amApprovalDate'] = nowMs;
        data['gmApproverID'] = '';
        data['gmApprovalDate'] = 0;
        data['ceoApproverID'] = '';
        data['ceoApprovalDate'] = 0;
        break;
      case 'GM Cancelled':
        if (id.isNotEmpty) data['gmApproverID'] = id;
        data['gmApprovalDate'] = nowMs;
        data['ceoApproverID'] = '';
        data['ceoApprovalDate'] = 0;
        break;
      case 'CEO Cancelled':
        if (id.isNotEmpty) data['ceoApproverID'] = id;
        data['ceoApprovalDate'] = nowMs;
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
      // Sort products by name alphabetically
      out.sort((a, b) => a.productName.compareTo(b.productName));
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
