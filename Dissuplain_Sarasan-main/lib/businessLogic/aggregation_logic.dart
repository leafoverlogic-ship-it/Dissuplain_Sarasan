// File: lib/businessLogic/aggregation_logic.dart

import '../dataLayer/region_area_data.dart';
import '../dataLayer/area_subarea_data.dart';
import '../dataLayer/subarea_daily_data.dart';
import '../dataLayer/product_list.dart';

Map<String, dynamic> calculateProductMetrics({
  required String region,
  required String area,
  required String subArea,
  required String product,
}) {
  // 1) Resolve subareas
  List<String> subAreas;
  if (subArea != 'All') {
    subAreas = [subArea];
  } else if (area != 'All') {
    subAreas = (areaToSubAreas[area] ?? []).toList();
  } else if (region != 'All') {
    final areas = regionToAreas[region] ?? [];
    subAreas = areas
        .expand((a) => areaToSubAreas[a] ?? const <String>[])
        .toList()
        .cast<String>();
  } else {
    subAreas = areaToSubAreas.values
        .expand((e) => e)
        .toSet()
        .toList()
        .cast<String>();
  }

  // 2) Resolve products
  final products = (product == 'All')
      ? productList.where((p) => p != 'All').toList()
      : <String>[product];

  // Ensure we have day-wise data
  seedDailyDataUpToToday();

  final today = DateTime.now();
  final startOfMonth = DateTime(today.year, today.month, 1);
  final startOfQuarter = _quarterStart(today);
  final startOfFY = fiscalYearStart(today);

  // 3) Aggregate helpers
  Map<String, int> dtd = _sumRange(subAreas, products, _sameDay(today), _sameDay(today));
  Map<String, int> mtd = _sumRange(subAreas, products, startOfMonth, today);
  Map<String, int> qtd = _sumRange(subAreas, products, startOfQuarter, today);
  Map<String, int> ytd = _sumRange(subAreas, products, startOfFY, today);

  return {
    'dtd_target': dtd['target']!,
    'dtd_achieved': dtd['achieved']!,
    'mtd_target': mtd['target']!,
    'mtd_achieved': mtd['achieved']!,
    'qtd_target': qtd['target']!,
    'qtd_achieved': qtd['achieved']!,
    'ytd_target': ytd['target']!,
    'ytd_achieved': ytd['achieved']!,
  };
}

DateTime _sameDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _quarterStart(DateTime today) {
  // Fiscal quarters: Q1 Apr-Jun, Q2 Jul-Sep, Q3 Oct-Dec, Q4 Jan-Mar
  final y = today.year;
  final m = today.month;
  if (m >= 4 && m <= 6) return DateTime(y, 4, 1);   // Q1
  if (m >= 7 && m <= 9) return DateTime(y, 7, 1);   // Q2
  if (m >= 10 && m <= 12) return DateTime(y, 10, 1); // Q3
  // Jan–Mar = Q4 of FY that started last year
  return DateTime(y, 1, 1); // Q4 start
}

/// Sums daily target/achieved for subareas × products over [from..to] inclusive.
Map<String, int> _sumRange(
  List<String> subAreas,
  List<String> products,
  DateTime from,
  DateTime to,
) {
  int target = 0;
  int achieved = 0;

  final fromKey = _fmt(from);
  final toKey = _fmt(to);

  for (final sa in subAreas) {
    final prodMap = subAreaProductDailyData[sa];
    if (prodMap == null) continue;

    for (final p in products) {
      final dayMap = prodMap[p];
      if (dayMap == null) continue;

      // Iterate days from 'from' to 'to' inclusive
      for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        final k = _fmt(d);
        final row = dayMap[k];
        if (row == null) continue;
        target += row['target'] ?? 0;
        achieved += row['achieved'] ?? 0;
      }
    }
  }

  return {'target': target, 'achieved': achieved};
}

String _fmt(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}
