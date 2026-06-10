// File: lib/dataLayer/subarea_daily_data.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'area_subarea_data.dart';
import 'product_list.dart';

/// subArea -> product -> date(yyyy-MM-dd) -> { 'target': int, 'achieved': int }
final Map<String, Map<String, Map<String, Map<String, int>>>>
    subAreaProductDailyData = {};

/// Fiscal year in India: Apr 1 -> Mar 31.
/// Returns fiscal year start for a given 'today'.
DateTime fiscalYearStart(DateTime today) {
  final fyYear = (today.month >= 4) ? today.year : today.year - 1;
  return DateTime(fyYear, 4, 1);
}

/// Seed daily mock data for all subareas/products from fiscal-year start up to 'today'.
/// Safe to call multiple times; it won't overwrite existing dates.
void seedDailyDataUpToToday({DateTime? today}) {
  final now = today ?? DateTime.now();
  final start = fiscalYearStart(now);
  final end = DateTime(now.year, now.month, now.day);

  final rnd = Random(42); // deterministic mock

  // List of real products (exclude 'All')
  final prods = productList.where((p) => p != 'All').toList();

  // All subareas from your mapping
  final allSubAreas = areaToSubAreas.values.expand((e) => e).toSet().toList();

  for (final sa in allSubAreas) {
    subAreaProductDailyData.putIfAbsent(sa, () => {});
    for (final p in prods) {
      subAreaProductDailyData[sa]!.putIfAbsent(p, () => {});

      // Walk each day in [start..end]
      for (DateTime d = start;
          !d.isAfter(end);
          d = d.add(const Duration(days: 1))) {
        final key = _fmt(d);
        if (subAreaProductDailyData[sa]![p]!.containsKey(key)) continue;

        // Mock target/achieved (tweak as you like)
        // Targets vary slightly by day; achieved ~ 85–110% of target
        final base = 250 + rnd.nextInt(200);             // 250–450
        final target = base + rnd.nextInt(120);          // +0–119
        final achieved = (target * (0.85 + rnd.nextDouble() * 0.25)).round();

        subAreaProductDailyData[sa]![p]![key] = {
          'target': target,
          'achieved': achieved,
        };
      }
    }
  }

  if (kDebugMode) {
    // print('Seeded daily data from $start to $end for ${allSubAreas.length} subareas.');
  }
}

String _fmt(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}
