import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // Web only

import '../../dataLayer/regions_repository.dart';
import '../../dataLayer/areas_repository.dart';
import '../../dataLayer/subareas_repository.dart';
import '../../dataLayer/customers_repository.dart';
import '../../dataLayer/users_repository.dart';

import '../CommonHeader.dart';
import '../CommonFooter.dart';
import 'ClientDetailsPage.dart';
import 'NewClient.dart';

// Utility
String _s(dynamic v) => v?.toString().trim() ?? '';

class ClientsSummaryPage extends StatefulWidget {
  final String roleId;
  final String salesPersonName;
  final bool allAccess;
  final List<String> allowedRegionIds;
  final List<String> allowedAreaIds;
  final List<String> allowedSubareaIds;
  final VoidCallback? onLogout;

  const ClientsSummaryPage({
    Key? key,
    required this.roleId,
    required this.salesPersonName,
    required this.allAccess,
    required this.allowedRegionIds,
    required this.allowedAreaIds,
    required this.allowedSubareaIds,
    this.onLogout,
  }) : super(key: key);

  @override
  State<ClientsSummaryPage> createState() => _ClientsSummaryPageState();
}

class _ClientsSummaryPageState extends State<ClientsSummaryPage> {
  String _regionId = '';
  String _areaId = '';
  String _subareaId = '';

  final _db = FirebaseDatabase.instance;
  late final _regionsRepo = RegionsRepository(db: _db);
  late final _areasRepo = AreasRepository(db: _db);
  late final _subAreasRepo = SubAreasRepository(db: _db);
  late final _customersRepo = CustomersRepository(db: _db);
  late final _usersRepo = UsersRepository(db: _db);

  List<RegionEntry> _regions = const [];
  List<AreaEntry> _areas = const [];
  List<SubAreaEntry> _subAreas = const [];
  List<CustomerEntry> _clients = const [];
  List<UserEntry> _users = const [];

  // subareaID -> assignedSE
  Map<String, String> _assignedSEBySubareaId = {};

  bool _lr = true, _la = true, _ls = true, _lc = true, _lu = true;
  String? _er, _ea, _es, _ec, _eu;

  @override
  void initState() {
    super.initState();

    _regionsRepo.streamRegions().listen(
      (rows) {
        setState(() {
          _regions = rows;
          _lr = false;
        });
      },
      onError: (e) => setState(() {
        _lr = false;
        _er = '$e';
      }),
    );

    _areasRepo.streamAreas().listen(
      (rows) {
        setState(() {
          _areas = rows
              .map(
                (a) => AreaEntry(
                  areaId: _s(a.areaId),
                  areaName: a.areaName,
                  regionId: _s(a.regionId),
                ),
              )
              .toList();
          _la = false;
        });
      },
      onError: (e) => setState(() {
        _la = false;
        _ea = '$e';
      }),
    );

    _subAreasRepo.streamSubAreas().listen(
      (rows) {
        setState(() {
          _subAreas = rows
              .map(
                (s) => SubAreaEntry(
                  subareaId: _s(s.subareaId),
                  subareaName: s.subareaName,
                  areaId: _s(s.areaId),
                  regionId: _s(s.regionId),
                ),
              )
              .toList();
          _ls = false;
        });
      },
      onError: (e) => setState(() {
        _ls = false;
        _es = '$e';
      }),
    );

    // SubareaID -> assignedSE
    _db.ref('SubAreas').onValue.listen((event) {
      final map = <String, String>{};
      final v = event.snapshot.value;
      if (v is Map) {
        v.forEach((k, raw) {
          if (raw is Map) {
            final sid = _s(
              raw['subareaID'].toString().isNotEmpty ? raw['subareaID'] : k,
            );
            final assigned = _s(raw['assignedSE']);
            if (sid.isNotEmpty) map[sid] = assigned;
          }
        });
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) {
          final raw = v[i];
          if (raw is Map) {
            final sid = _s(raw['subareaID'] ?? i.toString());
            final assigned = _s(raw['assignedSE']);
            if (sid.isNotEmpty) map[sid] = assigned;
          }
        }
      }
      setState(() => _assignedSEBySubareaId = map);
    });

    _customersRepo.streamCustomers().listen(
      (rows) {
        setState(() {
          _clients = rows;
          _lc = false;
        });
      },
      onError: (e) => setState(() {
        _lc = false;
        _ec = '$e';
      }),
    );

    _usersRepo.streamUsers().listen(
      (rows) {
        setState(() {
          _users = rows;
          _lu = false;
        });
      },
      onError: (e) => setState(() {
        _lu = false;
        _eu = '$e';
      }),
    );
  }

  // Region/area/subarea/lookup functions (as in your starter code)
  String _regionName(String id) => _regions
      .firstWhere(
        (r) => _s(r.regionId) == id,
        orElse: () => const RegionEntry(regionId: '', regionName: '—'),
      )
      .regionName;
  String _areaName(String id) => _areas
      .firstWhere(
        (a) => _s(a.areaId) == id,
        orElse: () => const AreaEntry(areaId: '', areaName: '—', regionId: ''),
      )
      .areaName;
  String _subareaName(String id) => _subAreas
      .firstWhere(
        (s) => _s(s.subareaId) == id,
        orElse: () => const SubAreaEntry(
          subareaId: '',
          subareaName: '—',
          areaId: '',
          regionId: '',
        ),
      )
      .subareaName;

  String _salesPersonName(String subareaId) {
    final assignedId = _assignedSEBySubareaId[subareaId] ?? '';
    final user = _users.firstWhere(
      (u) => _s(u.salesPersonId) == assignedId,
      orElse: () => const UserEntry(
        salesPersonId: '',
        salesPersonName: '—',
        emailAddress: '',
        phoneNumber: '',
        salesPersonRoleId: '',
        reportingPersonId: '',
        loginPwd: '',
      ),
    );
    return user.salesPersonName;
  }

  // normalize helper (reuse yours if you already have one)
  String _norm(String? s) => (s ?? '').trim();
  final Map<String, Map<String, dynamic>> _clientByCode = {};
  final Map<String, Map<String, dynamic>> _latestLogByCode = {};
  String _normCode(String? s) => (s ?? '').trim().toLowerCase();

  String _pickAny(Map m, List<String> ks) {
    for (final k in ks) {
      final v = (m[k]?.toString() ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _fmtYmd(dynamic raw) {
    if (raw == null) return '—';
    if (raw is DateTime) {
      return '${raw.year}-${raw.month.toString().padLeft(2, '0')}-${raw.day.toString().padLeft(2, '0')}';
    }
    if (raw is int && raw > 1000000) {
      final d = DateTime.fromMillisecondsSinceEpoch(raw);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    final s = _s(raw);
    if (s.isEmpty) return '—';
    return s;
  }

  String _eol() {
    if (kIsWeb) return '\r\n';
    try {
      return Platform.isWindows ? '\r\n' : '\n';
    } catch (_) {
      return '\n';
    }
  }

  String _csvEscape(String? s) {
    final v = (s ?? '').replaceAll('"', '""');
    return '"$v"';
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

  Future<List<Map<String, String>>> _buildFilteredClientRows() async {
    // existing lookups (sales person etc.)...
    await _ensureLatestLogsLoaded();

    final list = _filteredClients();
    final neededCodes = <String>{for (final c in list) _norm(c.customerCode)}
      ..removeWhere((e) => e.isEmpty);
    await _ensureClientDetailsLoaded(neededCodes);
    return list.map((c) {
      final code = (c.customerCode ?? '').trim();
      final codeKey = _normCode(code);
      final Map<String, dynamic>? m = _clientByCode[code];

      String customerName = '';
      String address1 = '';
      String address2 = '';
      String landmark = '';
      String mobile1 = '';
      String mobile2 = '';
      String OrderType = 'NA';
      String OrderDetails = 'NA';
      String OrderAmount = 'NA';

      if (m != null) {
        final docName = _pickAny(m, ['Doc_Name', 'DoctorName', 'Doctor_Name']);
        final pharmacyName = _pickAny(m, ['Pharmacy_Person_Name']);
        final isDoc = docName.isNotEmpty;
        customerName = isDoc ? docName : pharmacyName;

        address1 = isDoc
            ? _pickAny(m, ['Institution_OR_Clinic_Address_1'])
            : _pickAny(m, ['Pharmacy_Address_1']);
        address2 = isDoc
            ? _pickAny(m, ['Institution_OR_Clinic_Address_2'])
            : _pickAny(m, ['Pharmacy_Address_2']);
        landmark = isDoc
            ? _pickAny(m, [
                'Institution_OR_Clinic_Landmark',
                'nstitution_OR_Clinic_Landmark',
              ]) // include typo variant
            : _pickAny(m, ['Pharmacy_Landmark']);

        // As per your mapping (even if unusual): pharmacy “mobiles” come from Pharmacy_Address_1/2
        mobile1 = isDoc
            ? _pickAny(m, ['Doc_Mobile_No_1'])
            : _pickAny(m, ['Pharmacy_Mobile_No_1']);
        mobile2 = isDoc
            ? _pickAny(m, ['Doc_Mobile_No_2'])
            : _pickAny(m, ['Pharmacy_Mobile_No_2']);
      }

      // Existing columns you already return:
      final row = <String, String>{
        'Category': c.category ?? '',
        'Type of Institution': c.typeOfInstitution ?? '',
        'Customer Code': code,
        'Followup Date': (() {
          final dt = _parseAnyDate(c.followupDate);
          return dt == null ? (c.followupDate?.toString() ?? '') : _fmtYmd(dt);
        })(),
      };

      // NEW: fill from latest ActivityLog for this customer
      final log = _latestLogByCode[codeKey];
      if (log != null) {
        final whenMs = (log['__whenMs'] as int?) ?? 0;
        final visitDate = whenMs > 0
            ? _fmtYmd(DateTime.fromMillisecondsSinceEpoch(whenMs))
            : (() {
                final ca = _parseAnyDate(log['createdAt']);
                return ca == null ? '' : _fmtYmd(ca);
              })();

        row['Visit Date'] = visitDate;
        row['Type Of Call'] = (log['type'] ?? '').toString();
        row['Visit Brief'] = (log['message'] ?? '').toString();
        row['Call Response'] = (log['response'] ?? '').toString();
      } else {
        row['Visit Date'] = '';
        row['Type Of Call'] = '';
        row['Visit Brief'] = '';
        row['Call Response'] = '';
      }
      row['Destination'] = _subareaName(c.subareaId);
      row['City'] = _areaName(c.areaId);
      row['Sales Person'] = _salesPersonName(c.subareaId);

      row['Customer Name'] = customerName;
      row['Address1'] = address1;
      row['Address2'] = address2;
      row['Landmark'] = landmark;
      row['Mobile No 1'] = mobile1;
      row['Mobile No 2'] = mobile2;
      row['Order Type'] = OrderType;
      row['Order Details'] = OrderDetails;
      row['Order Amount'] = OrderAmount;

      return row;
    }).toList();
  }

  Future<void> _openFilteredClientsTable() async {
    final rows = await _buildFilteredClientRows();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FilteredClientsTablePage(
          rows: rows,
          headers: const [
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
          ],
        ),
      ),
    );
  }

  // Filtering and sorting as in your code
  List<CustomerEntry> _filteredClients() {
    Iterable<CustomerEntry> pool = _clients;
    if (!widget.allAccess) {
      if (widget.roleId == '3') {
        final regs = widget.allowedRegionIds.toSet();
        pool = pool.where((c) => regs.contains(_s(c.regionId)));
      } else if (widget.roleId == '2') {
        final ars = widget.allowedAreaIds.toSet();
        pool = pool.where((c) => ars.contains(_s(c.areaId)));
      } else if (widget.roleId == '1') {
        final subs = widget.allowedSubareaIds.toSet();
        pool = pool.where((c) => subs.contains(_s(c.subareaId)));
      }
    }
    // Apply current dropdown selections (if any)
    if (_regionId.isNotEmpty) {
      pool = pool.where((c) => _s(c.regionId) == _regionId);
    }
    if (_areaId.isNotEmpty) {
      pool = pool.where((c) => _s(c.areaId) == _areaId);
    }
    if (_subareaId.isNotEmpty) {
      pool = pool.where((c) => _s(c.subareaId) == _subareaId);
    }
    final rows = pool.toList();
    rows.sort(
      (a, b) => _fmtYmd(a.followupDate).compareTo(_fmtYmd(b.followupDate)),
    );
    return rows;
  }

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

  Future<void> _ensureClientDetailsLoaded(Set<String> neededCodes) async {
    // if already cached all needed codes, skip
    final missing = neededCodes
        .where((c) => !_clientByCode.containsKey(c))
        .toList();
    if (missing.isEmpty) return;

    final snap = await FirebaseDatabase.instance.ref('Clients').get();
    if (!snap.exists) return;

    for (final child in snap.children) {
      final raw = child.value;
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw as Map);
      final code = _norm(m['customerCode']?.toString());
      if (code.isEmpty) continue;
      _clientByCode[code] =
          m; // cache full map; we'll pick only needed fields later
    }
  }

  Future<void> _ensureLatestLogsLoaded() async {
    if (_latestLogByCode.isNotEmpty) return;

    final snap = await FirebaseDatabase.instance.ref('ActivityLogs').get();
    if (!snap.exists) return;

    for (final node in snap.children) {
      final raw = node.value;
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw as Map);

      final codeKey = _normCode(
        (m['customerCode'] ?? m['CustomerCode'])?.toString(),
      );
      if (codeKey.isEmpty) continue;

      // Pick a timestamp: prefer dateTimeMillis, else parse createdAt
      int whenMs = 0;
      final msStr = (m['dateTimeMillis'] ?? m['dateMillis'])?.toString();
      final msParsed = int.tryParse(msStr ?? '');
      if (msParsed != null && msParsed > 0) {
        whenMs = (msParsed < 20000000000) ? msParsed * 1000 : msParsed;
      } else {
        final ca = _parseAnyDate(m['createdAt']);
        if (ca != null) whenMs = ca.millisecondsSinceEpoch;
      }
      if (whenMs <= 0) continue;

      final prev = _latestLogByCode[codeKey];
      final prevWhen = prev == null ? 0 : (prev['__whenMs'] as int? ?? 0);
      if (whenMs > prevWhen) {
        _latestLogByCode[codeKey] = {
          '__whenMs': whenMs, // internal helper
          'createdAt': m['createdAt'],
          'type': m['type'],
          'message': m['message'],
          'response': m['response'],
        };
      }
    }
  }

  Future<void> _exportFilteredClientCsv(BuildContext context) async {
    try {
      final List<Map<String, String>> rows = await _buildFilteredClientRows();
      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing to export')));
        return;
      }

      // Use your usual headers (take order from your table/component)
      final List<String> headers = [
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

      // Compose CSV string
      final StringBuffer sb = StringBuffer();
      sb.writeln(headers.map((h) => _csvEscape(h)).join(','));
      for (final row in rows) {
        sb.writeln(headers.map((h) => _csvEscape(row[h])).join(','));
      }

      final now = DateTime.now();
      final fileName =
          'BeatPlan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      final csvData = sb.toString();

      // Save and export using robust logic
      final where = await _saveCsvCrossPlatform(
        fileName: fileName,
        csv: csvData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported CSV: $where')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportClientsRawSelectedColumnsCsv() async {
    try {
      final snap = await FirebaseDatabase.instance.ref('Clients').get();
      if (!snap.exists || snap.children.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No Clients to export')));
        return;
      }

      const headers = [
        'Customer_ID',
        'Date_of_1st_Call',
        'Opening_Month',
        'Date_of_Opening',
        'Sales_Person',
        'Category',
        'City',
        'Destination',
        'Type_of_Institution',
        'Institution_OR_Clinic_Name',
        'Institution_OR_Clinic_Address_1',
        'Institution_OR_Clinic_Address_2',
        'Institution_OR_Clinic_Landmark',
        'Institution_OR_Clinic_Pin_Code',
        'Doc_Name',
        'Doc_Mobile_No_1',
        'Doc_Mobile_No_2',
        'Pharmacy_Name',
        'Pharmacy_Address_1',
        'Pharmacy_Address_2',
        'Pharmacy_Landmark',
        'Pharmacy_Pin_Code',
        'Pharmacy_Person_Name',
        'Pharmacy_Mobile_No_1',
        'Pharmacy_Mobile_No_2',
        'GST_Number',
        'Status',
        'Visit_Days',
        'BUSINESS_SLAB',
        'BUSINESS_CAT',
        'VISIT_FREQUENCY_In_Days',
        'customerCode',
      ];

      String _csvCell(String? s) {
        final v = (s ?? '').replaceAll('"', '""');
        return '"$v"';
      }

      String _fmtDate(dynamic v) {
        if (v == null) return '';
        final s = v.toString().trim();
        if (s.isEmpty) return '';
        final n = int.tryParse(s);
        if (n != null) {
          final ms = (n < 20000000000) ? n * 1000 : n; // seconds → ms
          final d = DateTime.fromMillisecondsSinceEpoch(ms);
          return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        }
        final d = DateTime.tryParse(s);
        if (d != null) {
          return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        }
        return s;
      }

      final sb = StringBuffer();
      sb.writeln(headers.join(','));

      for (final child in snap.children) {
        final v = child.value;
        if (v is! Map) continue;
        final m = Map<String, dynamic>.from(v as Map);

        final row = headers
            .map((h) {
              final val = m[h];
              // format only for date-like fields
              if (h == 'Date_of_1st_Call' ||
                  h == 'Opening_Month' ||
                  h == 'Date_of_Opening') {
                return _csvCell(_fmtDate(val));
              }
              return _csvCell(val?.toString());
            })
            .join(',');
        sb.writeln(row);
      }

      final csv = '\uFEFF${sb.toString()}'; // BOM for Excel
      final now = DateTime.now();
      final filename =
          'Clients_Selected_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';

      if (kIsWeb) {
        final dataUrl =
            'data:text/csv;charset=utf-8,${Uri.encodeComponent(csv)}';
        final a = html.AnchorElement(href: dataUrl)
          ..download = filename
          ..style.display = 'none';
        html.document.body?.append(a);
        a.click();
        a.remove();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported $filename')));
      } else {
        // TODO: add native saving if you need mobile/desktop
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV ready (non-web): $filename')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Widget build(BuildContext context) {
    final clients = _filteredClients();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              CommonHeader(
                pageTitle: 'Beat Plan',
                userName: widget.salesPersonName,
                onLogout: widget.onLogout,
              ),
              _rowDropdown(
                label: 'Region',
                value: _regionId,
                items: _lr
                    ? const [
                        DropdownMenuItem(value: '', child: Text('Loading...')),
                      ]
                    : (_er != null
                          ? const [
                              DropdownMenuItem(value: '', child: Text('Error')),
                            ]
                          : _regionItems()),
                onChanged: (id) => setState(() {
                  _regionId = id ?? '';
                  _areaId = '';
                  _subareaId = '';
                }),
              ),
              _rowDropdown(
                label: 'Area',
                value: _areaId,
                items: _la
                    ? const [
                        DropdownMenuItem(value: '', child: Text('Loading...')),
                      ]
                    : (_ea != null
                          ? const [
                              DropdownMenuItem(value: '', child: Text('Error')),
                            ]
                          : _areaItems()),
                onChanged: (id) => setState(() {
                  _areaId = id ?? '';
                  _subareaId = '';
                }),
              ),
              _rowDropdown(
                label: 'Sub-Area',
                value: _subareaId,
                items: _ls
                    ? const [
                        DropdownMenuItem(value: '', child: Text('Loading...')),
                      ]
                    : (_es != null
                          ? const [
                              DropdownMenuItem(value: '', child: Text('Error')),
                            ]
                          : _subAreaItems()),
                onChanged: (id) => setState(() {
                  _subareaId = id ?? '';
                }),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 18,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Beat Plan (${clients.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),

                    /*ElevatedButton.icon(
                      onPressed: _openFilteredClientsTable,
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Show Filtered Clients'),
                    ),*/
                    ElevatedButton(
                      onPressed: () async {
                        await _exportFilteredClientCsv(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Export',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    if (widget.roleId == "4") ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _exportClientsRawSelectedColumnsCsv,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.file_download),
                        label: const Text(
                          'Export Clients Master',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_ec != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Failed to load clients: $_ec',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else if (_lc)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Loading clients...'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: clients.length,
                  itemBuilder: (_, i) => _clientPlate(clients[i]),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NewClientPage(
                allowedRegionIds: widget.allowedRegionIds,
                allowedAreaIds: widget.allowedAreaIds,
                allowedSubareaIds: widget.allowedSubareaIds,
              ),
            ),
          );
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: CommonFooter(),
    );
  }

  List<DropdownMenuItem<String>> _regionItems() {
  final String role = widget.roleId?.toString() ?? '';
  final bool unrestricted = (role == '4' || role == '5' || role == '6' || role == '7' || (widget.allAccess ?? false));

  final Set<String> allowedRegions = (widget.allowedRegionIds ?? const <String>[])
      .map((e) => _s(e))
      .toSet();
  final Set<String> allowedAreas = (widget.allowedAreaIds ?? const <String>[])
      .map((e) => _s(e))
      .toSet();
  final Set<String> allowedSubs = (widget.allowedSubareaIds ?? const <String>[])
      .map((e) => _s(e))
      .toSet();

  Iterable<RegionEntry> pool = _regions;

  if (unrestricted) {
    pool = _regions;
  } else if (role == '2') {
    // Area Manager
    if (allowedRegions.isNotEmpty) {
      pool = _regions.where((r) => allowedRegions.contains(_s(r.regionId)));
    } else if (allowedAreas.isNotEmpty) {
      final regIds = _areas
          .where((a) => allowedAreas.contains(_s(a.areaId)))
          .map((a) => _s(a.regionId))
          .toSet();
      pool = _regions.where((r) => regIds.contains(_s(r.regionId)));
    }
  } else if (role == '1') {
    // Sales Exec
    if (allowedSubs.isNotEmpty) {
      final areaIds = _subAreas
          .where((s) => allowedSubs.contains(_s(s.subareaId)))
          .map((s) => _s(s.areaId))
          .toSet();
      final regIds = _areas
          .where((a) => areaIds.contains(_s(a.areaId)))
          .map((a) => _s(a.regionId))
          .toSet();
      pool = _regions.where((r) => regIds.contains(_s(r.regionId)));
    } else {
      pool = const <RegionEntry>[];
    }
  } else {
    if (allowedRegions.isNotEmpty) {
      pool = _regions.where((r) => allowedRegions.contains(_s(r.regionId)));
    }
  }

  // Remove any with empty id or name and de-duplicate by id
  final seen = <String>{};
  final rows = pool.where((r) {
    final id = _s(r.regionId);
    final name = (_s(r.regionName));
    if (id.isEmpty || name.isEmpty) return false;
    if (seen.contains(id)) return false;
    seen.add(id);
    return true;
  }).toList()
    ..sort((a, b) => a.regionName.toLowerCase().compareTo(b.regionName.toLowerCase()));

  final items = <DropdownMenuItem<String>>[];

  // Show "All" only for unrestricted roles and only if there is more than 1 option
  if (unrestricted && rows.length > 1) {
    items.add(const DropdownMenuItem(value: '', child: Text('All')));
  }

  items.addAll(rows.map((r) => DropdownMenuItem(
        value: _s(r.regionId),
        child: Text(r.regionName),
      )));

  return items;
}


  List<DropdownMenuItem<String>> _areaItems() {
    // Role-aware area options; respect selected region if any
    final String role = widget.roleId?.toString() ?? '';
    final Set<String> allowedAreas = (widget.allowedAreaIds ?? const <String>[])
        .map((e) => _s(e))
        .toSet();
    final Set<String> allowedSubs =
        (widget.allowedSubareaIds ?? const <String>[])
            .map((e) => _s(e))
            .toSet();

    Iterable<AreaEntry> pool = _areas;

    if (role == '4' ||
        role == '5' ||
        role == '6' ||
        role == '7' ||
        (widget.allAccess ?? false)) {
      // unrestricted: all areas, optionally filter by selected region
      if (_regionId.isNotEmpty) {
        pool = pool.where((a) => _s(a.regionId) == _regionId);
      }
    } else if (role == '2') {
      // Area Manager: only allowed areas
      if (allowedAreas.isNotEmpty) {
        pool = pool.where((a) => allowedAreas.contains(_s(a.areaId)));
      }
      if (_regionId.isNotEmpty) {
        pool = pool.where((a) => _s(a.regionId) == _regionId);
      }
    } else if (role == '1') {
      // Sales Exec: areas derived from their allowed subareas
      if (allowedSubs.isNotEmpty) {
        final areaIds = _subAreas
            .where((s) => allowedSubs.contains(_s(s.subareaId)))
            .map((s) => _s(s.areaId))
            .toSet();
        pool = pool.where((a) => areaIds.contains(_s(a.areaId)));
      }
      if (_regionId.isNotEmpty) {
        pool = pool.where((a) => _s(a.regionId) == _regionId);
      }
    }

    final rows = pool.toList()
      ..sort(
        (a, b) => a.areaName.toLowerCase().compareTo(b.areaName.toLowerCase()),
      );

    return [
      const DropdownMenuItem(value: '', child: Text('All')),
      ...rows.map(
        (a) => DropdownMenuItem(value: _s(a.areaId), child: Text(a.areaName)),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _subAreaItems() {
    // Role-aware sub-area options; respect selected area if any
    final String role = widget.roleId?.toString() ?? '';
    final Set<String> allowedSubs =
        (widget.allowedSubareaIds ?? const <String>[])
            .map((e) => _s(e))
            .toSet();
    final Set<String> allowedAreas = (widget.allowedAreaIds ?? const <String>[])
        .map((e) => _s(e))
        .toSet();

    Iterable<SubAreaEntry> pool = _subAreas;

    if (role == '4' ||
        role == '5' ||
        role == '6' ||
        role == '7' ||
        (widget.allAccess ?? false)) {
      // Unrestricted: all subareas; optionally narrow by selected area
      if (_areaId.isNotEmpty) {
        pool = pool.where((s) => _s(s.areaId) == _areaId);
      }
    } else if (role == '2') {
      // Area Manager:
      // Prefer explicit allowed subareas; otherwise derive from allowed areas.
      if (allowedSubs.isNotEmpty) {
        pool = pool.where((s) => allowedSubs.contains(_s(s.subareaId)));
      } else if (allowedAreas.isNotEmpty) {
        pool = pool.where((s) => allowedAreas.contains(_s(s.areaId)));
      }
      if (_areaId.isNotEmpty) {
        pool = pool.where((s) => _s(s.areaId) == _areaId);
      }
    } else if (role == '1') {
      // Sales Exec: only explicitly allowed subareas
      if (allowedSubs.isNotEmpty) {
        pool = pool.where((s) => allowedSubs.contains(_s(s.subareaId)));
      } else {
        pool = const <SubAreaEntry>[];
      }
      if (_areaId.isNotEmpty) {
        pool = pool.where((s) => _s(s.areaId) == _areaId);
      }
    }

    final rows = pool.toList()
      ..sort(
        (a, b) =>
            a.subareaName.toLowerCase().compareTo(b.subareaName.toLowerCase()),
      );

    return [
      const DropdownMenuItem(value: '', child: Text('All')),
      ...rows.map(
        (s) => DropdownMenuItem(
          value: _s(s.subareaId),
          child: Text(s.subareaName),
        ),
      ),
    ];
  }

  Widget _rowDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                hintText: 'Select $label',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientPlate(CustomerEntry c) {
    final title = (c.instituteOrClinicName?.isNotEmpty == true)
        ? c.instituteOrClinicName!
        : (c.pharmacyName?.isNotEmpty == true ? c.pharmacyName! : '(No name)');
    final code = c.customerCode ?? '—';
    final category = c.category ?? '—';
    final status = c.status ?? '—';
    final slab = c.businessSlab ?? '';
    final bcat = c.businessCat ?? '';
    final region = _regionName(c.regionId);
    final area = _areaName(c.areaId);
    final sub = _subareaName(c.subareaId);
    final spName = _salesPersonName(c.subareaId);
    final follow = _fmtYmd(c.followupDate);

    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ClientDetailsPage(client: c)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(blurRadius: 2, spreadRadius: 0, color: Color(0x14000000)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$region | $area | $sub',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Text(category, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Business Slab: $slab',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Text(status, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Business Cat: $bcat',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Previous Order Value:',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Previous Order Date:',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Followup date: $follow',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                Text(spName, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FilteredClientsTablePage extends StatelessWidget {
  final List<Map<String, String>> rows;
  final List<String> headers; // allow caller to specify columns
  const FilteredClientsTablePage({
    Key? key,
    required this.rows,
    required this.headers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hCtrl = ScrollController();
    final vCtrl = ScrollController();

    return Scaffold(
      appBar: AppBar(title: const Text('Filtered Clients')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: rows.isEmpty
            ? const Center(child: Text('No clients match the filter.'))
            : Scrollbar(
                controller: hCtrl,
                thumbVisibility: true,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: hCtrl,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: headers.length * 220.0,
                    ),
                    child: Scrollbar(
                      controller: vCtrl,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: vCtrl,
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columns: headers
                              .map((h) => DataColumn(label: Text(h)))
                              .toList(),
                          rows: rows
                              .map(
                                (r) => DataRow(
                                  cells: headers
                                      .map((h) => DataCell(Text(r[h] ?? '')))
                                      .toList(),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
