import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// Web download
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ⬇️ Adjust this path for your project (e.g., '../dataLayer/customers_repository.dart')
import '../dataLayer/customers_repository.dart';

class ExportViaClients extends StatefulWidget {
  const ExportViaClients({Key? key}) : super(key: key);

  @override
  State<ExportViaClients> createState() => _ExportViaClientsState();
}

class _ExportViaClientsState extends State<ExportViaClients> {
  bool _working = false;
  String? _error;

  // ---- DUMMY FILTER HOOK (replace later) ----
  List<CustomerEntry> _filteredClients() {
    // Return empty list = no extra filtering
    return <CustomerEntry>[];
  }

  // Map your CustomerEntry to its customerCode (update when you wire it)
  String _customerCodeFromEntry(CustomerEntry entry) {
    // e.g., return entry.customerCode;
    return '';
  }

  // ---- helpers ----
  String _pick(Map<String, dynamic> m, String key) {
    final v = m[key];
    return v == null ? '' : v.toString().trim();
  }

  String _pickAny(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  String _fmtYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseAnyDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final n = int.tryParse(s);
    if (n != null) {
      final ms = (n < 20000000000) ? n * 1000 : n; // seconds->ms heuristic
      try { return DateTime.fromMillisecondsSinceEpoch(ms); } catch (_) {}
    }
    return DateTime.tryParse(s);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
      return 'downloaded via browser';
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
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv, flush: true);
      return file.path;
    } catch (_) {
      final tmp = File('${Directory.systemTemp.path}/$fileName');
      await tmp.writeAsString(csv, flush: true);
      return tmp.path;
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final db = FirebaseDatabase.instance;

      // Fetch in parallel
      final clientsF = db.ref('Clients').get();
      final subareasF = db.ref('SubAreas').get();
      final areasF = db.ref('Areas').get();
      final usersF = db.ref('Users').get();
      final logsF = db.ref('ActivityLogs').get();

      final clientsSnap = await clientsF;
      final subareasSnap = await subareasF;
      final areasSnap = await areasF;
      final usersSnap = await usersF;
      final logsSnap = await logsF;

      if (!clientsSnap.exists || clientsSnap.children.isEmpty) {
        throw 'No data found in Clients table.';
      }

      // SubAreas: subareaID -> name, areaID, assignedSE
      final subareaNameById = <String, String>{};
      final areaIdBySubareaId = <String, String>{};
      final assignedSeBySubareaId = <String, String>{};
      if (subareasSnap.exists) {
        for (final s in subareasSnap.children) {
          final raw = s.value;
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw as Map);
          final sid = _pickAny(m, ['subareaID','SubAreaID','SubareaID']).isNotEmpty
              ? _pickAny(m, ['subareaID','SubAreaID','SubareaID'])
              : (s.key ?? '');
          if (sid.isEmpty) continue;
          subareaNameById[sid] = _pickAny(m, ['subareaName','SubareaName','SubAreaName']);
          areaIdBySubareaId[sid] = _pickAny(m, ['areaID','AreaID']);
          assignedSeBySubareaId[sid] = _pickAny(m, ['assignedSE','AssignedSE','assignedSe']);
        }
      }

      // Areas: areaID -> areaName
      final areaNameById = <String, String>{};
      if (areasSnap.exists) {
        for (final a in areasSnap.children) {
          final raw = a.value;
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw as Map);
          final aid = _pickAny(m, ['areaID','AreaID']).isNotEmpty
              ? _pickAny(m, ['areaID','AreaID'])
              : (a.key ?? '');
          if (aid.isEmpty) continue;
          areaNameById[aid] = _pickAny(m, ['areaName','AreaName']);
        }
      }

      // Users: SalesPersonID -> SalesPersonName
      final userNameById = <String, String>{};
      if (usersSnap.exists) {
        for (final u in usersSnap.children) {
          final raw = u.value;
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw as Map);
          final uid = _pickAny(m, ['SalesPersonID','salesPersonID','SalespersonID']);
          final uname = _pickAny(m, ['SalesPersonName','salesPersonName','SalespersonName']);
          if (uid.isNotEmpty) userNameById[uid] = uname;
        }
      }

      // Latest ActivityLog by customerCode (normalized)
      final latestLog = <String, Map<String, dynamic>>{};
      if (logsSnap.exists) {
        for (final node in logsSnap.children) {
          final raw = node.value;
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw as Map);
          final code = _pickAny(m, ['customerCode','CustomerCode']).trim().toLowerCase();
          if (code.isEmpty) continue;

          int whenMs = 0;
          final dtMillisStr = _pickAny(m, ['dateTimeMillis','dateMillis','CreatedMs']);
          final dtMillis = int.tryParse(dtMillisStr);
          if (dtMillis != null && dtMillis > 0) {
            whenMs = (dtMillis < 20000000000) ? dtMillis * 1000 : dtMillis;
          } else {
            final createdAt = _pickAny(m, ['createdAt','CreatedAt']);
            final dt = _parseAnyDate(createdAt);
            if (dt != null) whenMs = dt.millisecondsSinceEpoch;
          }
          if (whenMs <= 0) continue;

          final prev = latestLog[code];
          if (prev == null || whenMs > (prev['__whenMs'] as int? ?? 0)) {
            latestLog[code] = {
              '__whenMs': whenMs,
              'createdAt': _pickAny(m, ['createdAt','CreatedAt']),
              'type': _pickAny(m, ['type','Type','CallType']),
              'message': _pickAny(m, ['message','Message','visitBrief','VisitBrief','brief','Brief']),
              'response': _pickAny(m, ['response','Response','callResponse','CallResponse']),
            };
          }
        }
      }

      // Optional filter from _filteredClients()
      final fcList = _filteredClients();
      final allow = <String>{
        for (final e in fcList) _customerCodeFromEntry(e).trim().toLowerCase()
      }..removeWhere((c) => c.isEmpty);
      final useAllow = allow.isNotEmpty;

      final today = _dateOnly(DateTime.now());

      // Columns in EXACT order requested
      const headers = [
        'Visit Date',
        'Sales Person',
        'Type Of Call',
        'Category',
        'Type of Institution',
        'Destination',
        'City',
        'Customer Code',
        'Customer Name',
        'Address1',
        'Address2',
        'Landmark',
        'Mobile No 1',
        'Mobile No 2',
        'Order Type',
        'Order Details',
        'Order Amount',
        'Visit Brief',
        'Call Response',
        'Followup Date',
      ];

      final data = <List<String>>[];
      data.add(headers);

      for (final child in clientsSnap.children) {
        final raw = child.value;
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw as Map);

        final customerCode = _pick(m, 'customerCode').trim();
        final codeKey = customerCode.toLowerCase();
        if (useAllow && !allow.contains(codeKey)) continue;

        final followupDt = _parseAnyDate(_pick(m, 'followupDate'));
        if (followupDt == null || _dateOnly(followupDt).isAfter(today)) continue;

        final subareaId = _pickAny(m, ['subareaID','SubAreaID','SubareaID']);
        final destination = subareaNameById[subareaId] ?? '';
        final areaId = areaIdBySubareaId[subareaId] ?? '';
        final city = areaNameById[areaId] ?? '';

        // Sales Person via assignedSE -> Users
        final assignedSe = assignedSeBySubareaId[subareaId] ?? '';
        final salesPersonName = userNameById[assignedSe] ?? '';

        // Doctor vs Pharmacy dependent fields
        final docName = _pickAny(m, ['Doc_Name','DoctorName','Doctor_Name']);
        final pharmacyName = _pickAny(m, ['Pharmacy_Name','ShopName','RetailerName']);
        final isDoc = docName.isNotEmpty;
        final customerName = isDoc ? docName : pharmacyName;

        final address1 = isDoc
            ? _pickAny(m, ['Institution_OR_Clinic_Address_1'])
            : _pickAny(m, ['Pharmacy_Address_1']);
        final address2 = isDoc
            ? _pickAny(m, ['Institution_OR_Clinic_Address_2'])
            : _pickAny(m, ['Pharmacy_Address_2']);
        final landmark = isDoc
            ? _pickAny(m, ['Institution_OR_Clinic_Landmark','nstitution_OR_Clinic_Landmark'])
            : _pickAny(m, ['Pharmacy_Landmark']);
        final mobile1 = isDoc
            ? _pickAny(m, ['Doc_Mobile_No_1'])
            : _pickAny(m, ['Pharmacy_Address_1']); // as per your mapping
        final mobile2 = isDoc
            ? _pickAny(m, ['Doc_Mobile_No_2'])
            : _pickAny(m, ['Pharmacy_Address_2']); // as per your mapping

        // Latest log for this customer
        final log = latestLog[codeKey];
        String visitDate = '';
        String typeOfCall = '';
        String visitBrief = '';
        String callResponse = '';
        if (log != null) {
          final whenMs = (log['__whenMs'] as int?) ?? 0;
          visitDate = whenMs > 0
              ? _fmtYmd(DateTime.fromMillisecondsSinceEpoch(whenMs))
              : (_parseAnyDate(log['createdAt']) != null
                  ? _fmtYmd(_parseAnyDate(log['createdAt'])!)
                  : '');
          typeOfCall = (log['type'] ?? '').toString();
          visitBrief = (log['message'] ?? '').toString();
          callResponse = (log['response'] ?? '').toString();
        }

        final rowMap = <String, String>{
          'Visit Date': visitDate,
          'Sales Person': salesPersonName,
          'Type Of Call': typeOfCall,
          'Category': _pick(m, 'Category'),
          'Type of Institution': _pick(m, 'Type_of_Institution'),
          'Destination': destination,
          'City': city,
          'Customer Code': customerCode,
          'Customer Name': customerName,
          'Address1': address1,
          'Address2': address2,
          'Landmark': landmark,
          'Mobile No 1': mobile1,
          'Mobile No 2': mobile2,
          'Order Type': 'NA',
          'Order Details': 'NA',
          'Order Amount': 'NA',
          'Visit Brief': visitBrief,
          'Call Response': callResponse,
          'Followup Date': _fmtYmd(_dateOnly(followupDt)),
        };

        data.add([for (final h in headers) rowMap[h] ?? '']);
      }

      // Turn into CSV
      final eol = _eol();
      final csv = data.map((r) => r.map(_csvEscape).join(',')).join(eol);

      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'DueClients_$stamp.csv';

      final where = await _saveCsvCrossPlatform(fileName: fileName, csv: csv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported CSV: $where')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Due/Overdue Clients')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _working ? null : () => _exportCsv(context),
              icon: const Icon(Icons.download),
              label: Text(_working ? 'Exporting…' : 'Export CSV'),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            const Text(
              'Generates a CSV of clients with Followup Date ≤ today, joined with '
              'Destination/City, Sales Person, and latest Activity Log.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
