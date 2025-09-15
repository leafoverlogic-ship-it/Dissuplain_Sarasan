import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Used only on web builds

class TestExportPage extends StatelessWidget {
  const TestExportPage({Key? key}) : super(key: key);

  // ---------- CSV helpers ----------
  String _csvEscape(String? s) {
    final v = (s ?? '').replaceAll('"', '""');
    return '"$v"';
  }

  String _eol() {
    if (kIsWeb) return '\r\n';
    try {
      return Platform.isWindows ? '\r\n' : '\n';
    } catch (_) {
      return '\n';
    }
  }

  String _fmtYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------- Cross-platform saver (no path_provider) ----------
  Future<String> _saveCsvCrossPlatform({
    required String fileName,
    required String csv,
  }) async {
    if (kIsWeb) {
      final blob = html.Blob([csv], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return 'via browser download';
    }

    try {
      String targetPath;
      if (Platform.isAndroid) {
        targetPath = '/storage/emulated/0/Download';
      } else if (Platform.isWindows) {
        final home = Platform.environment['USERPROFILE'] ?? '';
        targetPath = home.isNotEmpty ? '$home\\Downloads' : Directory.systemTemp.path;
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        targetPath = home.isNotEmpty ? '$home/Downloads' : Directory.systemTemp.path;
      } else if (Platform.isIOS) {
        targetPath = Directory.systemTemp.path; // sandbox
      } else {
        targetPath = Directory.systemTemp.path;
      }

      final dir = Directory(targetPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv, flush: true);
      return file.path;
    } catch (_) {
      final tmp = File('${Directory.systemTemp.path}/$fileName');
      await tmp.writeAsString(csv, flush: true);
      return tmp.path;
    }
  }

  // ---------- Latest Activity Log (safe child-iteration) ----------
  Future<Map<String, dynamic>?> _fetchLastActivityLog(String customerCode) async {
    final snap = await FirebaseDatabase.instance
        .ref('ActivityLogs/$customerCode')
        .get();

    Map<String, dynamic>? best;
    int bestMillis = -1;

    int _extractMillis(Map<String, dynamic> m) {
      final a = m['dateTimeMillis'];
      if (a is int) return a;
      final b = m['dateTime'];
      if (b is int) return b;
      if (b is String) {
        final n = int.tryParse(b);
        if (n != null && n > 1000000) return n;
      }
      return 0;
    }

    for (final child in snap.children) {
      final raw = child.value;
      if (raw is Map) {
        final Map<String, dynamic> m = {};
        (raw as Map).forEach((k, v) => m[k.toString()] = v);
        final ms = _extractMillis(m);
        if (ms > bestMillis) {
          bestMillis = ms;
          best = m;
        }
      }
    }
    return best;
  }

  // ---------- Extract customer code (recursive + normalization) ----------
  String _extractCustomerCode(Map<String, dynamic> flatOrNested, String fallbackId) {
    const candidates = [
      'customerCode','CustomerCode','Customer_Code','Customer Code',
      'Code','CustCode','custCode','CustomerID','Customer_Id',
      'clientCode','Client_Code'
    ];

    String? _recurse(Object? obj) {
      if (obj is Map) {
        for (final entry in obj.entries) {
          final k = entry.key.toString();
          final v = entry.value;
          if (candidates.contains(k)) {
            final s = v?.toString().trim();
            if (s != null && s.isNotEmpty) return s;
          }
          final deeper = _recurse(v);
          if (deeper != null && deeper.isNotEmpty) return deeper;
        }
      } else if (obj is List) {
        for (final item in obj) {
          final deeper = _recurse(item);
          if (deeper != null && deeper.isNotEmpty) return deeper;
        }
      }
      return null;
    }

    String code = (_recurse(flatOrNested) ?? fallbackId).trim();

    // Normalize (Firebase path-safe)
    code = code.replaceAll('.', '')
               .replaceAll('#', '')
               .replaceAll('\$', '')
               .replaceAll('[', '')
               .replaceAll(']', '')
               .trim();

    return code;
  }

  // ---------- Fetch entire Customers/Clients to table + last log ----------
  Future<List<List<String>>> _fetchCustomersAsTable() async {
    // Try "Customers" first
    DatabaseReference ref = FirebaseDatabase.instance.ref('Customers');
    DataSnapshot snap = await ref.get();

    // Fallback to "Clients" if empty/missing
    if (!snap.exists || snap.children.isEmpty) {
      ref = FirebaseDatabase.instance.ref('Clients');
      snap = await ref.get();
    }

    // If still no data, return header-only with a message row
    if (!snap.exists || snap.children.isEmpty) {
      return [
        ['id', 'message'],
        ['', 'No customers found under Customers or Clients'],
      ];
    }

    // Collect header keys (union of keys across records)
    final LinkedHashSet<String> headerSet = LinkedHashSet<String>();
    headerSet.add('id'); // node key

    // First pass: gather all keys (+ store raw flat rows)
    final List<Map<String, dynamic>> rowsRaw = [];

    for (final child in snap.children) {
      final id = child.key ?? '';
      final raw = child.value;

      final Map<String, dynamic> flat = {'id': id};

      if (raw is Map) {
        // one-level flatten: keep top-level keys as columns
        (raw as Map).forEach((k, v) {
          final key = k.toString();
          if (v is Map || v is List) {
            flat[key] = v.toString();
          } else {
            flat[key] = v?.toString();
          }
          headerSet.add(key);
        });

        // Keep the original raw object (for recursive code extraction)
        flat['_raw'] = raw;
      } else {
        // Non-map payload: store whole value as "value"
        flat['value'] = raw?.toString();
        headerSet.add('value');
        flat['_raw'] = raw;
      }

      rowsRaw.add(flat);
    }

    // Add extra columns for latest activity log (+ optional debug key)
    const extraCols = <String>[
      'LastLog_Date',
      'LastLog_Type',
      'LastLog_Message',
      'LastLog_Response',
      'LastLog_LookupKey', // optional; helps verify the key used
    ];
    headerSet.addAll(extraCols);

    // Enrich each flat row with its latest log values using the *customer code* key
    for (final flat in rowsRaw) {
      final id = (flat['id'] ?? '').toString();

      // Prefer the original nested raw structure if available
      final raw = flat.containsKey('_raw') ? flat['_raw'] : flat;
      final customerCode = _extractCustomerCode(
        raw is Map ? Map<String, dynamic>.from(raw as Map) : {'id': id},
        id,
      );

      // Try a few normalized variants
      final variants = <String>{
        customerCode,
        customerCode.trim(),
        customerCode.replaceAll(' ', ''),
        customerCode.toUpperCase(),
        customerCode.toLowerCase(),
      }.where((s) => s.isNotEmpty).toList();

      Map<String, dynamic>? log;
      for (final key in variants) {
        log = await _fetchLastActivityLog(key);
        if (log != null) {
          flat['LastLog_LookupKey'] = key; // optional debug column
          break;
        }
      }
      log ??= {};

      int ms = 0;
      final a = log['dateTimeMillis'];
      if (a is int) ms = a;
      final b = log['dateTime'];
      if (ms == 0 && b is int) ms = b;
      if (ms == 0 && b is String) {
        final n = int.tryParse(b);
        if (n != null && n > 1000000) ms = n;
      }

      flat['LastLog_Date']     = ms > 0 ? _fmtYmd(DateTime.fromMillisecondsSinceEpoch(ms)) : '';
      flat['LastLog_Type']     = (log['type'] ?? '').toString();
      flat['LastLog_Message']  = (log['message'] ?? '').toString();
      flat['LastLog_Response'] = ((log['Response']) ?? (log['response']) ?? '').toString();
    }

    // Build final header list (preserve insertion order of LinkedHashSet)
    final headers = headerSet.toList(growable: false);

    // Second pass: build rows in header order
    final List<List<String>> table = [];
    table.add(headers); // header row

    for (final m in rowsRaw) {
      final row = <String>[];
      for (final h in headers) {
        final v = m[h];
        row.add(v == null ? '' : v.toString());
      }
      table.add(row);
    }

    return table;
  }

  // ---------- Export handler ----------
  Future<void> _exportCsv(BuildContext context) async {
    try {
      final table = await _fetchCustomersAsTable();

      final sep = _eol();
      final csv = table
          .map((row) => row.map(_csvEscape).join(','))
          .join(sep);

      final now = DateTime.now();
      final fileName =
          'Customers_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.csv';

      final where = await _saveCsvCrossPlatform(fileName: fileName, csv: csv);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported $where')),
      );
    } catch (e, st) {
      debugPrint('Export failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Customers CSV')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _exportCsv(context),
          child: const Text('Export CSV'),
        ),
      ),
    );
  }
}
