import 'package:firebase_database/firebase_database.dart';

/// Simplified backfill:
/// - Remove legacy amApprovalStatus
/// - Add/overwrite salesPersonID with default "SS-1114" if missing
/// - Add/overwrite amApproverID with default "SS-1114" if missing
/// - Ensure cdApplied = 0 where missing (per-line or single-product)
Future<void> backfillOrdersCdAndAm() async {
  const defaultId = 'SS-1114';
  final db = FirebaseDatabase.instance;
  final ordersRef = db.ref('Orders');
  final snap = await ordersRef.get();
  if (!snap.exists) {
    print('No orders found.');
    return;
  }

  final Map<String, Object?> updates = {};

  for (final custNode in snap.children) {
    final customerCode = custNode.key ?? '';
    for (final orderNode in custNode.children) {
      final orderId = orderNode.key ?? '';
      final orderPath = '$customerCode/$orderId';
      final orderMap = (orderNode.value as Map?) ?? {};

      // remove amApprovalStatus
      if (orderMap.containsKey('amApprovalStatus')) {
        updates['$orderPath/amApprovalStatus'] = null;
      }

      // defaults for salesPersonID and amApproverID
      if ((orderMap['salesPersonID'] ?? '').toString().trim().isEmpty) {
        updates['$orderPath/salesPersonID'] = defaultId;
      }
      if ((orderMap['amApproverID'] ?? '').toString().trim().isEmpty) {
        updates['$orderPath/amApproverID'] = defaultId;
      }

      final productsDetail = orderMap['productsDetail'];
      if (productsDetail is Map) {
        productsDetail.forEach((prodCode, prodVal) {
          final prodPath = '$orderPath/productsDetail/$prodCode';
          final prodMap = prodVal as Map?;
          final hasCd = prodMap != null && prodMap.containsKey('cdApplied');
          if (!hasCd) {
            updates['$prodPath/cdApplied'] = 0;
          }
        });
      } else {
        if (!orderMap.containsKey('cdApplied')) {
          updates['$orderPath/cdApplied'] = 0;
        }
      }
    }
  }

  if (updates.isEmpty) {
    print('Nothing to update.');
    return;
  }

  print('Applying ${updates.length} updates...');
  await ordersRef.update(updates);
  print('Backfill complete.');
}
