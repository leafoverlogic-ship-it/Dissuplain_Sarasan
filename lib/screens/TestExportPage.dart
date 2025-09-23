import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Used only on web builds

class TestExportPage extends StatelessWidget {
  const TestExportPage({Key? key}) : super(key: key);

  // ---------- CSV/HTML helpers ----------
  String _csvEscape(String? s) {
    final v = (s ?? '').replaceAll('"', '""');
    return '"$v"';
  }

  String _htmlEscape(String? s) {
    final v = (s ?? '');
    return v
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _eol() {
    if (kIsWeb) return '\r\n';
    try {
      return Platform.isWindows ? '\r\n' : '\n';
    } catch (_) {
      return '\n';
    }
  }

  // ---------- Cross-platform saver (used for non-web CSV fallback) ----------
  Future<String> _saveCsvCrossPlatform({
    required String fileName,
    required String csv,
  }) async {
    if (kIsWeb) {
      // On web we don't use this helper (we stream a blob), but keep it safe.
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
        targetPath = home.isNotEmpty
            ? '$home\\Downloads'
            : Directory.systemTemp.path;
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        targetPath = home.isNotEmpty
            ? '$home/Downloads'
            : Directory.systemTemp.path;
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

  String _fmtYmd2(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtYmdHms(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  DateTime? _parseAnyDate(dynamic v) {
    if (v == null) return null;
    if (v is int) {
      if (v > 2000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) {
      final n = int.tryParse(v);
      if (n != null) {
        if (n > 2000000000) return DateTime.fromMillisecondsSinceEpoch(n);
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return null;
  }

  DateTime? _parseDateLoose(dynamic v) {
    if (v == null) return null;
    if (v is int) return _parseAnyDate(v);
    final s0 = v.toString().trim();
    if (s0.isEmpty) return null;
    try {
      return DateTime.parse(s0);
    } catch (_) {}
    final s = s0.replaceAll(RegExp(r'\s+'), ' ');

    final ymd = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$');
    final mY = ymd.firstMatch(s);
    if (mY != null) {
      final y = int.parse(mY.group(1)!);
      final m = int.parse(mY.group(2)!);
      final d = int.parse(mY.group(3)!);
      return DateTime(y, m, d);
    }

    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$');
    final mD = dmy.firstMatch(s);
    if (mD != null) {
      final a = int.parse(mD.group(1)!);
      final b = int.parse(mD.group(2)!);
      final c = int.parse(mD.group(3)!);
      final d = a;
      final m = b;
      final y = (c < 100) ? (2000 + c) : c;
      return DateTime(y, m, d);
    }

    final mon = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'sept': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final dMonY = RegExp(r'^(\d{1,2})[-\s]([A-Za-z]{3,5})[-\s](\d{2,4})$');
    final mMon = dMonY.firstMatch(s);
    if (mMon != null) {
      final dd = int.parse(mMon.group(1)!);
      final mm = mon[mMon.group(2)!.toLowerCase()];
      if (mm != null) {
        final yy = int.parse(mMon.group(3)!);
        final y = (yy < 100) ? (2000 + yy) : yy;
        return DateTime(y, mm, dd);
      }
    }
    return null;
  }

  String _normCode(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String _normKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // ---------- Users map: SalesPersonID -> SalesPersonName ----------
  Future<Map<String, String>> _fetchSalesMap() async {
    final snap = await FirebaseDatabase.instance.ref('Users').get();
    final map = <String, String>{};
    if (!snap.exists) return map;
    for (final child in snap.children) {
      final raw = child.value;
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id =
            (m['SalesPersonID'] ??
                    m['salesPersonID'] ??
                    m['salespersonId'] ??
                    m['SalesPersonId'] ??
                    m['UserID'] ??
                    m['userId'] ??
                    '')
                .toString()
                .trim();
        final name =
            (m['SalesPersonName'] ??
                    m['salesPersonName'] ??
                    m['name'] ??
                    m['Name'] ??
                    '')
                .toString()
                .trim();
        if (id.isNotEmpty && name.isNotEmpty) map[id] = name;
      }
    }
    return map;
  }

  // ---------- Deep pick helpers ----------
  String _pickDeep(Object? obj, List<String> keys) {
    final wanted = keys.map(_normKey).toSet();
    String? found;
    void walk(Object? o) {
      if (found != null) return;
      if (o is Map) {
        o.forEach((k, v) {
          final nk = _normKey(k.toString());
          if (wanted.contains(nk)) {
            final vs = (v ?? '').toString().trim();
            if (vs.isNotEmpty) {
              found = vs;
              return;
            }
          }
          walk(v);
        });
      } else if (o is List) {
        for (final item in o) {
          if (found != null) break;
          walk(item);
        }
      }
    }

    walk(obj);
    return found ?? '';
  }

  // ---------- SubAreas & Areas maps ----------
  Future<Map<String, Map<String, String>>> _fetchSubareaMap() async {
    final snap = await FirebaseDatabase.instance.ref('SubAreas').get();
    final map = <String, Map<String, String>>{};
    if (!snap.exists) return map;
    for (final child in snap.children) {
      final raw = child.value;
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw as Map);
        String id = _pickDeep(m, [
          'subareaID',
          'subAreaID',
          'SubAreaID',
          'subareaId',
          'subAreaId',
          'SubareaID',
        ]);
        if (id.isEmpty) id = (child.key ?? '').toString();
        final name = _pickDeep(m, [
          'subareaName',
          'SubAreaName',
          'subAreaName',
        ]);
        final areaId = _pickDeep(m, ['areaID', 'AreaID', 'areaId']);
        if (id.trim().isEmpty) continue;
        map[_normCode(id)] = {'subareaName': name, 'areaID': areaId};
      } else {
        final key = (child.key ?? '').toString();
        if (key.isNotEmpty)
          map[_normCode(key)] = {'subareaName': '', 'areaID': ''};
      }
    }
    return map;
  }

  Future<Map<String, String>> _fetchAreaMap() async {
    final snap = await FirebaseDatabase.instance.ref('Areas').get();
    final map = <String, String>{};
    if (!snap.exists) return map;
    for (final child in snap.children) {
      final raw = child.value;
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw as Map);
        String id = _pickDeep(m, ['areaID', 'AreaID', 'areaId']);
        if (id.isEmpty) id = (child.key ?? '').toString();
        final name = _pickDeep(m, ['areaName', 'AreaName', 'name']);
        if (id.trim().isEmpty) continue;
        map[_normCode(id)] = name;
      } else {
        final key = (child.key ?? '').toString();
        if (key.isNotEmpty) map[_normCode(key)] = '';
      }
    }
    return map;
  }

  // ---------- Clients info ----------
  Future<Map<String, Map<String, String>>> _fetchClientInfoMap() async {
    final snap = await FirebaseDatabase.instance.ref('Clients').get();
    final map = <String, Map<String, String>>{};
    if (!snap.exists) return map;

    for (final child in snap.children) {
      final id = child.key?.toString() ?? '';
      final raw = child.value;
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw as Map);

      final codes = <String>{
        id,
        (m['customerCode'] ?? '').toString(),
        (m['CustomerCode'] ?? '').toString(),
        (m['ClientCode'] ?? '').toString(),
        (m['clientCode'] ?? '').toString(),
        (m['Code'] ?? '').toString(),
        (m['CustCode'] ?? '').toString(),
        (m['custCode'] ?? '').toString(),
      }.where((s) => s.trim().isNotEmpty).map((s) => _normCode(s)).toSet();

      final docName = _pickDeep(m, [
        'Doc_Name',
        'Doc Name',
        'DoctorName',
        'Doctor Name',
        'Doctor',
        'DrName',
        'Dr Name',
      ]);
      final phName = _pickDeep(m, [
        'Pharmacy_Name',
        'Pharmacy Name',
        'ChemistName',
        'Chemist Name',
        'RetailerName',
        'Retailer Name',
        'ShopName',
        'Shop Name',
      ]);

      final instType = _pickDeep(m, [
        'TypeOfInstitution',
        'Type Of Institution',
        'Type of Institution',
        'InstitutionType',
        'Institution Type',
        'TypeOfInstitute',
        'Type Of Institute',
        'Type of Institute',
        'Type',
        'CustomerType',
        'Customer Type',
      ]);

      final instAddr1 = _pickDeep(m, [
        'Institute_Address1',
        'Institute Address 1',
        'Hospital_Address1',
        'Hospital Address 1',
        'Clinic_Address1',
        'Clinic Address 1',
        'Doctor_Address1',
        'Doctor Address 1',
        'Address1',
        'Address 1',
        'Addr1',
      ]);
      final instAddr2 = _pickDeep(m, [
        'Institute_Address2',
        'Institute Address 2',
        'Hospital_Address2',
        'Hospital Address 2',
        'Clinic_Address2',
        'Clinic Address 2',
        'Doctor_Address2',
        'Doctor Address 2',
        'Address2',
        'Address 2',
        'Addr2',
      ]);
      final instLand = _pickDeep(m, [
        'Institute_Landmark',
        'Institute Landmark',
        'Hospital_Landmark',
        'Hospital Landmark',
        'Clinic_Landmark',
        'Clinic Landmark',
        'Doctor_Landmark',
        'Doctor Landmark',
        'Landmark',
        'Nearest Landmark',
        'Near Landmark',
        'Land Mark',
      ]);
      final instMob1 = _pickDeep(m, [
        'Institute_Mobile1',
        'Institute Mobile 1',
        'Doc_Mobile1',
        'Doctor Mobile 1',
        'Mobile1',
        'Mobile No 1',
        'Mobile_No_1',
        'MobileNo1',
      ]);
      final instMob2 = _pickDeep(m, [
        'Institute_Mobile2',
        'Institute Mobile 2',
        'Doc_Mobile2',
        'Doctor Mobile 2',
        'Mobile2',
        'Mobile No 2',
        'Mobile_No_2',
        'MobileNo2',
      ]);

      final phAddr1 = _pickDeep(m, [
        'Pharmacy_Address1',
        'Pharmacy Address 1',
        'Chemist_Address1',
        'Chemist Address 1',
        'Retailer_Address1',
        'Retailer Address 1',
        'PharmacyAddress1',
        'Address1',
        'Address 1',
        'Addr1',
      ]);
      final phAddr2 = _pickDeep(m, [
        'Pharmacy_Address2',
        'Pharmacy Address 2',
        'Chemist_Address2',
        'Chemist Address 2',
        'Retailer_Address2',
        'Retailer Address 2',
        'PharmacyAddress2',
        'Address2',
        'Address 2',
        'Addr2',
      ]);
      final phLand = _pickDeep(m, [
        'Pharmacy_Landmark',
        'Pharmacy Landmark',
        'Chemist_Landmark',
        'Chemist Landmark',
        'Retailer_Landmark',
        'Retailer Landmark',
        'Landmark',
        'Nearest Landmark',
        'Near Landmark',
        'Land Mark',
      ]);
      final phMob1 = _pickDeep(m, [
        'Pharmacy_Mobile1',
        'Pharmacy Mobile 1',
        'Chemist_Mobile1',
        'Chemist Mobile 1',
        'Retailer_Mobile1',
        'Retailer Mobile 1',
        'PharmacyMobile1',
        'Mobile1',
        'Mobile No 1',
        'Mobile_No_1',
        'MobileNo1',
      ]);
      final phMob2 = _pickDeep(m, [
        'Pharmacy_Mobile2',
        'Pharmacy Mobile 2',
        'Chemist_Mobile2',
        'Chemist Mobile 2',
        'Retailer_Mobile2',
        'Retailer Mobile 2',
        'PharmacyMobile2',
        'Mobile2',
        'Mobile No 2',
        'Mobile_No_2',
        'MobileNo2',
      ]);

      final category = _pickDeep(m, [
        'Category',
        'category',
        'ClientCategory',
        'clientCategory',
        'CategoryName',
        'categoryName',
      ]);

      final followRaw = _pickDeep(m, [
        'followupDate',
        'FollowupDate',
        'FollowUpDate',
        'Follow-up Date',
        'Follow up Date',
        'NextFollowup',
        'Next Followup',
        'nextFollowup',
        'followup',
        'Followup',
        'NextVisit',
        'Next Visit',
        'Next Visit Date',
        'nextVisitDate',
        'nextVisit',
      ]);
      DateTime? fdt = _parseAnyDate(followRaw) ?? _parseDateLoose(followRaw);
      final followMs = fdt?.millisecondsSinceEpoch.toString() ?? '';

      final subareaId = _pickDeep(m, [
        'subareaID',
        'subAreaID',
        'SubAreaID',
        'subareaId',
        'subAreaId',
        'SubareaID',
        'sub_area_id',
      ]);

      final info = <String, String>{
        'Category': category,
        'Type of Institution': instType,
        'Doc_Name': docName,
        'Pharmacy_Name': phName,
        'Inst_Addr1': instAddr1,
        'Inst_Addr2': instAddr2,
        'Inst_Land': instLand,
        'Inst_Mob1': instMob1,
        'Inst_Mob2': instMob2,
        'Ph_Addr1': phAddr1,
        'Ph_Addr2': phAddr2,
        'Ph_Land': phLand,
        'Ph_Mob1': phMob1,
        'Ph_Mob2': phMob2,
        'FollowupMs': followMs,
        'FollowupRaw': followRaw,
        'SubAreaID': subareaId,
      };

      for (final c in codes) {
        map.putIfAbsent(c, () => info);
      }
    }
    return map;
  }

  // ---------- ActivityLogs → latest-by-createdAt per customerCode, filtered by follow-up <= today ----------
  Future<List<Map<String, String>>> _fetchLatestLogsPerCustomer() async {
    final logsRef = FirebaseDatabase.instance.ref('ActivityLogs');
    final logsSnap = await logsRef.get();
    final salesFuture = _fetchSalesMap();
    final clientFuture = _fetchClientInfoMap();
    final subareasFuture = _fetchSubareaMap();
    final areasFuture = _fetchAreaMap();

    final salesMap = await salesFuture;
    final clientInfo = await clientFuture;
    final subareas = await subareasFuture;
    final areas = await areasFuture;

    if (!logsSnap.exists || logsSnap.children.isEmpty) {
      return [];
    }

    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final Map<String, Map<String, String>> best = {};
    final Map<String, int> bestMs = {};

    for (final logNode in logsSnap.children) {
      final raw = logNode.value;

      String customerCode = '';
      String message = '';
      String type = '';
      String userId = '';
      String response = '';
      String createdMillis = '';

      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw as Map);

        customerCode = (m['customerCode'] ?? m['CustomerCode'] ?? '')
            .toString()
            .trim();

        for (final k in const [
          'message',
          'Message',
          'msg',
          'note',
          'details',
        ]) {
          final s = (m[k]?.toString() ?? '').trim();
          if (s.isNotEmpty) {
            message = s;
            break;
          }
        }
        for (final k in const ['type', 'Type', 'activityType']) {
          final s = (m[k]?.toString() ?? '').trim();
          if (s.isNotEmpty) {
            type = s;
            break;
          }
        }
        for (final k in const [
          'Response',
          'response',
          'CallResponse',
          'callResponse',
        ]) {
          final s = (m[k]?.toString() ?? '').trim();
          if (s.isNotEmpty) {
            response = s;
            break;
          }
        }
        for (final k in const [
          'userId',
          'UserID',
          'userID',
          'createdBy',
          'CreatedBy',
          'created_by',
          'enteredBy',
          'uid',
          'SalesPersonID',
        ]) {
          final s = (m[k]?.toString() ?? '').trim();
          if (s.isNotEmpty) {
            userId = s;
            break;
          }
        }

        final dtCreated = _parseAnyDate(m['createdAt']);
        final rawCreated = (m['createdAt'] ?? '').toString().trim();
        if (rawCreated.isNotEmpty) {
          final n = int.tryParse(rawCreated);
          if (n != null)
            createdMillis = (n > 2000000000 ? n : n * 1000).toString();
        }
        if (createdMillis.isEmpty && dtCreated != null) {
          createdMillis = dtCreated.millisecondsSinceEpoch.toString();
        }
      } else {
        message = raw?.toString() ?? '';
      }

      if (customerCode.isEmpty || createdMillis.isEmpty) continue;

      final custKey = _normCode(customerCode);

      final info = clientInfo[custKey];
      if (info == null) continue;
      final fms = int.tryParse(info['FollowupMs'] ?? '') ?? -1;
      if (fms <= 0) continue;
      final fdt = DateTime.fromMillisecondsSinceEpoch(fms);
      if (fdt.isAfter(endOfToday)) continue;

      final createdMs = int.tryParse(createdMillis) ?? 0;

      final docName = info['Doc_Name'] ?? '';
      final phName = info['Pharmacy_Name'] ?? '';
      final pickedIsDoc =
          docName.isNotEmpty ||
          (phName.isEmpty && (info['Inst_Addr1'] ?? '').isNotEmpty);

      final customerName = pickedIsDoc
          ? (docName.isNotEmpty ? docName : phName)
          : (phName.isNotEmpty ? phName : docName);
      final addr1 = pickedIsDoc
          ? (info['Inst_Addr1'] ?? '')
          : (info['Ph_Addr1'] ?? '');
      final addr2 = pickedIsDoc
          ? (info['Inst_Addr2'] ?? '')
          : (info['Ph_Addr2'] ?? '');
      final land = pickedIsDoc
          ? (info['Inst_Land'] ?? '')
          : (info['Ph_Land'] ?? '');
      final mob1 = pickedIsDoc
          ? (info['Inst_Mob1'] ?? '')
          : (info['Ph_Mob1'] ?? '');
      final mob2 = pickedIsDoc
          ? (info['Inst_Mob2'] ?? '')
          : (info['Ph_Mob2'] ?? '');

      final followStr = _fmtYmd2(fdt);

      final subId = info['SubAreaID'] ?? '';
      String destination = '';
      String city = '';
      if (subId.trim().isNotEmpty) {
        final sub = subareas[_normCode(subId)];
        if (sub != null) {
          destination = sub['subareaName'] ?? '';
          final areaId = sub['areaID'] ?? '';
          if (areaId.trim().isNotEmpty) city = areas[_normCode(areaId)] ?? '';
        }
      }

      final row = <String, String>{
        'Visit Date': createdMs > 0
            ? _fmtYmdHms(DateTime.fromMillisecondsSinceEpoch(createdMs))
            : '',
        'Sales Person': userId.isEmpty ? '' : (salesMap[userId] ?? ''),
        'Type of Call': type,
        'Category': info['Category'] ?? '',
        'Type of Institution': info['Type of Institution'] ?? '',
        'Destination': destination,
        'City': city,
        'Customer Name': customerName,
        'Address1': addr1,
        'Address2': addr2,
        'Landmark': land,
        'Mobile No 1': mob1,
        'Mobile No 2': mob2,
        'Order Type': 'NA',
        'Order Details': 'NA',
        'Order Amount': 'NA',
        'Visit Brief': message,
        'Call Response': response,
        'Followup Date': followStr,
      };

      final prevBest = bestMs[custKey] ?? -1;
      if (createdMs > prevBest) {
        best[custKey] = row;
        bestMs[custKey] = createdMs;
      }
    }

    final out = best.values.toList();
    out.sort(
      (a, b) => (b['Visit Date'] ?? '').compareTo(a['Visit Date'] ?? ''),
    );
    return out;
  }

  // ---------- Export ActivityLogs to Excel (web: .xls HTML, other: CSV) ----------
  Future<void> _exportActivityLogsExcel(BuildContext context) async {
    try {
      final rowsMaps = await _fetchLatestLogsPerCustomer();

      const headers = [
        'Visit Date',
        'Sales Person',
        'Type of Call',
        'Category',
        'Type of Institution',
        'Destination',
        'City',
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

      final dataRows = <List<String>>[
        headers,
        for (final m in rowsMaps) [for (final h in headers) m[h] ?? ''],
      ];

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      if (kIsWeb) {
        final buf = StringBuffer();
        buf.write(
          '<html><head><meta charset="UTF-8"></head><body><table border="1">',
        );
        buf.write('<tr>');
        for (final h in headers) {
          buf.write('<th>${_htmlEscape(h)}</th>');
        }
        buf.write('</tr>');
        for (int i = 1; i < dataRows.length; i++) {
          buf.write('<tr>');
          for (final cell in dataRows[i]) {
            buf.write('<td>${_htmlEscape(cell)}</td>');
          }
          buf.write('</tr>');
        }
        buf.write('</table></body></html>');

        final fileName = 'ActivityLogs_$stamp.xls';
        final blob = html.Blob([
          buf.toString(),
        ], 'application/vnd.ms-excel;charset=utf-8');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..download = fileName
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel exported via browser download')),
        );
      } else {
        final eol = _eol();
        final csv = <String>[];
        for (final row in dataRows) {
          csv.add(row.map(_csvEscape).join(','));
        }
        final fileName = 'ActivityLogs_$stamp.csv';
        final where = await _saveCsvCrossPlatform(
          fileName: fileName,
          csv: csv.join(eol),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV (Excel-readable) exported $where')),
        );
      }
    } catch (e, st) {
      debugPrint('Export ActivityLogs failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export ActivityLogs')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _exportActivityLogsExcel(context),
          child: const Text('Export ActivityLogs Excel'),
        ),
      ),
    );
  }
}
