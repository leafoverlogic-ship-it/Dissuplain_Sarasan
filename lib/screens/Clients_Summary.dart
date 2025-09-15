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

    _regionsRepo.streamRegions().listen((rows) {
      setState(() {
        _regions = rows;
        _lr = false;
      });
    }, onError: (e) => setState(() {
      _lr = false;
      _er = '$e';
    }));

    _areasRepo.streamAreas().listen((rows) {
      setState(() {
        _areas = rows.map((a) => AreaEntry(
          areaId: _s(a.areaId),
          areaName: a.areaName,
          regionId: _s(a.regionId),
        )).toList();
        _la = false;
      });
    }, onError: (e) => setState(() {
      _la = false;
      _ea = '$e';
    }));

    _subAreasRepo.streamSubAreas().listen((rows) {
      setState(() {
        _subAreas = rows.map((s) => SubAreaEntry(
          subareaId: _s(s.subareaId),
          subareaName: s.subareaName,
          areaId: _s(s.areaId),
          regionId: _s(s.regionId),
        )).toList();
        _ls = false;
      });
    }, onError: (e) => setState(() {
      _ls = false;
      _es = '$e';
    }));

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

    _customersRepo.streamCustomers().listen((rows) {
      setState(() {
        _clients = rows;
        _lc = false;
      });
    }, onError: (e) => setState(() {
      _lc = false;
      _ec = '$e';
    }));

    _usersRepo.streamUsers().listen((rows) {
      setState(() {
        _users = rows;
        _lu = false;
      });
    }, onError: (e) => setState(() {
      _lu = false;
      _eu = '$e';
    }));
  }

  // Filtering helpers (as in your base code)
  bool _isClientVisible(Map<String, dynamic> m) {
    final role = (widget.roleId ?? '').trim();
    final regionId = (m['regionID'] ?? m['regionId'] ?? '').toString();
    final areaId = (m['areaID'] ?? m['areaId'] ?? '').toString();
    final subareaId = (m['subareaID'] ?? m['subareaId'] ?? '').toString();

    if (role == '4' || role == '5' || role == '6' || role == '7') return true;

    if (role == '3') {
      final allowed = widget.allowedRegionIds ?? const [];
      if (allowed.isEmpty) return false;
      return allowed.contains(regionId);
    }

    if (role == '2') {
      final allowed = widget.allowedAreaIds ?? const [];
      if (allowed.isEmpty) return false;
      return allowed.contains(areaId);
    }

    if (role == '1') {
      final allowed = widget.allowedSubareaIds ?? const [];
      if (allowed.isEmpty) return false;
      return allowed.contains(subareaId);
    }

    final regOK =
        (widget.allowedRegionIds?.isEmpty ?? true) ||
        (widget.allowedRegionIds?.contains(regionId) ?? false);

    final areaOK =
        (widget.allowedAreaIds?.isEmpty ?? true) ||
        (widget.allowedAreaIds?.contains(areaId) ?? false);

    final subOK =
        (widget.allowedSubareaIds?.isEmpty ?? true) ||
        (widget.allowedSubareaIds?.contains(subareaId) ?? false);
    return regOK && areaOK && subOK;
  }

  // Region/area/subarea/lookup functions (as in your starter code)
  String _regionName(String id) => _regions
      .firstWhere(
        (r) => _s(r.regionId) == id,
        orElse: () => const RegionEntry(regionId: '', regionName: '—'),
      ).regionName;
  String _areaName(String id) => _areas
      .firstWhere(
        (a) => _s(a.areaId) == id,
        orElse: () => const AreaEntry(areaId: '', areaName: '—', regionId: ''),
      ).areaName;
  String _subareaName(String id) => _subAreas
      .firstWhere(
        (s) => _s(s.subareaId) == id,
        orElse: () => const SubAreaEntry(
          subareaId: '',
          subareaName: '—',
          areaId: '',
          regionId: '',
        ),
      ).subareaName;

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

  // Last activity log fetch
  Future<Map<String, dynamic>?> _fetchLastActivityLog(String? customerCode) async {
    if (customerCode == null || customerCode.isEmpty) return null;

    final ref = FirebaseDatabase.instance.ref('ActivityLogs/$customerCode');
    final snap = await ref.get();

    Map<String, dynamic>? best;
    int bestMillis = -1;
    int _ms(Map<String, dynamic> m) {
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
        final t = _ms(m);
        if (t > bestMillis) { bestMillis = t; best = m; }
      }
    }
    return best;
  }

  Future<String> _salesPersonNameForSubarea(String? subareaId) async {
    if (subareaId == null || subareaId.trim().isEmpty) return '—';
    String assignedId = '';
    for (final key in const ['assignedSE', 'assignedSe', 'assignedse']) {
      final s = await FirebaseDatabase.instance
          .ref('SubAreas/$subareaId/$key')
          .get();
      final v = (s.value ?? '').toString().trim();
      if (v.isNotEmpty) { assignedId = v; break; }
    }
    if (assignedId.isEmpty) return '—';
    final nameSnap = await FirebaseDatabase.instance
        .ref('Users/$assignedId/Name')
        .get();
    final nm = (nameSnap.value ?? '').toString().trim();
    return nm.isEmpty ? assignedId : nm;
  }

  Future<String> _subareaNameById(String? subareaId) async {
    if (subareaId == null || subareaId.trim().isEmpty) return '—';
    final s = await FirebaseDatabase.instance
        .ref('SubAreas/$subareaId/SubArea_Name')
        .get();
    return (s.value ?? '—').toString().trim();
  }

  Future<String> _areaNameViaSubarea(String? subareaId) async {
    if (subareaId == null || subareaId.trim().isEmpty) return '—';
    final areaIdSnap = await FirebaseDatabase.instance
        .ref('SubAreas/$subareaId/areaID')
        .get();
    final areaId = (areaIdSnap.value ?? '').toString().trim();
    if (areaId.isEmpty) return '—';
    final areaNameSnap = await FirebaseDatabase.instance
        .ref('Areas/$areaId/Area_Name')
        .get();
    return (areaNameSnap.value ?? '—').toString().trim();
  }

  String _pickCustomerName(String? docName, String? pharmacyName) {
    final dn = (docName ?? '').trim();
    if (dn.isNotEmpty) return dn;
    final pn = (pharmacyName ?? '').trim();
    return pn;
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

  bool _isFollowupDueOrOlder(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    return dd.isBefore(today) || dd.isAtSameMomentAs(today);
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
    final rows = pool.toList();
    rows.sort((a, b) => _fmtYmd(a.followupDate).compareTo(_fmtYmd(b.followupDate)));
    return rows;
  }

  // CSV Builders and Savers
  String _csvEscape(String? s) {
    final v = (s ?? '').replaceAll('"', '""');
    return '"$v"';
  }
  String _eol() {
    if (kIsWeb) return '\r\n';
    try { return Platform.isWindows ? '\r\n' : '\n'; } catch (_) { return '\n'; }
  }
  Future<String> _saveCsvCrossPlatform({required String fileName, required String csv}) async {
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
        targetPath = Directory.systemTemp.path;
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
    try {
      final table = await buildBeatPlanCsvLinesDueOrToday(_filteredClients());
      final sep = _eol();
      final csv = table.map((row) => row.map(_csvEscape).join(',')).join(sep);
      final now = DateTime.now();
      final fileName = 'Clients_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.csv';
      final where = await _saveCsvCrossPlatform(fileName: fileName, csv: csv);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported $where')),
      );
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<List<List<String>>> buildBeatPlanCsvLinesDueOrToday(List<CustomerEntry> allClients) async {
    final due = allClients.where((c) => _isFollowupDueOrOlder(c.followupDate)).toList(growable: false);
    final rows = <List<String>>[
      [
        'Visit Date','Sales Person','Type Of Call','Category','Type of Institution','Destination','City',
        'Customer Code','Customer Name','Address1','Address2','Landmark',
        'Mobile No 1','Mobile No 2','Order Type','Order Details','Order Amount',
        'Visit Brief','Call Response','Followup Date',
      ],
    ];

    for (final c in due) {
      Map<String, dynamic>? lastLog;
      try { lastLog = await _fetchLastActivityLog(c.customerCode); } catch (_) {}

      final visitDateStr = lastLog != null && lastLog['dateTimeMillis'] != null
          ? _fmtYmd(lastLog['dateTimeMillis']) : '';
      final salesPerson = await _salesPersonNameForSubarea(c.subareaId);
      final typeOfCall = lastLog?['type'] ?? '';
      final category = c.category ?? '';
      final typeOfInstitution = c.typeOfInstitution ?? '';
      final destination = await _subareaNameById(c.subareaId);
      final city = await _areaNameViaSubarea(c.subareaId);
      final code = c.customerCode ?? '';
      final customerName = _pickCustomerName(c.docName, c.pharmacyName);

      final isDoc = (c.docName ?? '').isNotEmpty;
      final address1 = isDoc ? (c.instituteOrClinicAddress1 ?? '') : (c.pharmacyAddress1 ?? '');
      final address2 = isDoc ? (c.instituteOrClinicAddress2 ?? '') : (c.pharmacyAddress2 ?? '');
      final landmark = isDoc ? (c.instituteOrClinicLandmark ?? '') : (c.pharmacyLandmark ?? '');
      final mobile1 = isDoc ? (c.docMobileNo1 ?? '') : (c.pharmacyMobileNo1 ?? '');
      final mobile2 = isDoc ? (c.docMobileNo2 ?? '') : (c.pharmacyMobileNo2 ?? '');
      final orderType = 'NA'; // Per your requirements
      final orderDetails = 'NA';
      final orderAmount = 'NA';
      final visitBrief = lastLog?['message'] ?? '';
      final callResponse = lastLog?['Response'] ?? lastLog?['response'] ?? '';
      final followupStr = _fmtYmd(c.followupDate);

      rows.add([
        visitDateStr,salesPerson,typeOfCall,category,typeOfInstitution,destination,city,
        code,customerName,address1,address2,landmark,mobile1,mobile2,
        orderType,orderDetails,orderAmount,
        visitBrief,callResponse,followupStr
      ]);
    }
    return rows;
  }

  // UI
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
                    ? const [DropdownMenuItem(value: '', child: Text('Loading...'))]
                    : (_er != null
                          ? const [DropdownMenuItem(value: '', child: Text('Error'))]
                          : _regionItems()),
                onChanged: (id) => setState(() {
                  _regionId = id ?? ''; _areaId = ''; _subareaId = '';
                }),
              ),
              _rowDropdown(
                label: 'Area',
                value: _areaId,
                items: _la
                    ? const [DropdownMenuItem(value: '', child: Text('Loading...'))]
                    : (_ea != null
                          ? const [DropdownMenuItem(value: '', child: Text('Error'))]
                          : _areaItems()),
                onChanged: (id) => setState(() {
                  _areaId = id ?? ''; _subareaId = '';
                }),
              ),
              _rowDropdown(
                label: 'Sub-Area',
                value: _subareaId,
                items: _ls
                    ? const [DropdownMenuItem(value: '', child: Text('Loading...'))]
                    : (_es != null
                          ? const [DropdownMenuItem(value: '', child: Text('Error'))]
                          : _subAreaItems()),
                onChanged: (id) => setState(() { _subareaId = id ?? ''; }),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(Icons.people_alt_outlined, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Beat Plan (${clients.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: () => _exportCsv(context),
                    child: const Text('Export CSV'),
                  ),
                ]),
              ),
              if (_ec != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Failed to load clients: $_ec', style: const TextStyle(color: Colors.red)),
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

  // Dropdown helpers as your original code:
  List<DropdownMenuItem<String>> _regionItems() {
    final allowed = widget.allowedRegionIds.toSet();
    final rows =
        _regions.where((r) => allowed.contains(_s(r.regionId))).toList();
    rows.sort((a, b) => a.regionName.toLowerCase().compareTo(b.regionName.toLowerCase()));
    return [
      const DropdownMenuItem(value: '', child: Text('All')),
      ...rows.map((r) => DropdownMenuItem(value: _s(r.regionId), child: Text(r.regionName))),
    ];
  }
  List<DropdownMenuItem<String>> _areaItems() {
    final allowed = widget.allowedAreaIds.toSet();
    Iterable<AreaEntry> pool = _areas.where((a) => allowed.contains(_s(a.areaId)));
    if (_regionId.isNotEmpty)
      pool = pool.where((a) => _s(a.regionId) == _regionId);
    final rows = pool.toList();
    rows.sort((a, b) => a.areaName.toLowerCase().compareTo(b.areaName.toLowerCase()));
    return [
      const DropdownMenuItem(value: '', child: Text('All')),
      ...rows.map((a) => DropdownMenuItem(value: _s(a.areaId), child: Text(a.areaName))),
    ];
  }
  List<DropdownMenuItem<String>> _subAreaItems() {
    final allowed = widget.allowedSubareaIds.toSet();
    Iterable<SubAreaEntry> pool = _subAreas.where((s) => allowed.contains(_s(s.subareaId)));
    if (_regionId.isNotEmpty)
      pool = pool.where((s) => _s(s.regionId) == _regionId);
    if (_areaId.isNotEmpty) pool = pool.where((s) => _s(s.areaId) == _areaId);
    final rows = pool.toList();
    rows.sort((a, b) => a.subareaName.toLowerCase().compareTo(b.subareaName.toLowerCase()));
    return [
      const DropdownMenuItem(value: '', child: Text('All')),
      ...rows.map((s) => DropdownMenuItem(value: _s(s.subareaId), child: Text(s.subareaName))),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  // Client display card logic (as per your original code)
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
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ClientDetailsPage(client: c),
        ));
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
                Expanded(child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                )),
                const SizedBox(width: 8),
                Text(code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('$region | $area | $sub', style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                Text(category, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('Business Slab: $slab', style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                Text(status, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('Business Cat: $bcat', style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Previous Order Value:', style: TextStyle(fontSize: 14)),
                    SizedBox(height: 2),
                    Text('Previous Order Date:', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Followup date: $follow',
                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                Text(spName, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
