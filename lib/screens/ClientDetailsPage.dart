import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../dataLayer/customers_repository.dart'; // only for the widget param type
import '../../dataLayer/activity_logs_repository.dart';
import '../../dataLayer/regions_repository.dart';
import '../../dataLayer/areas_repository.dart';
import '../../dataLayer/subareas_repository.dart';

import '../CommonHeader.dart';
import '../CommonFooter.dart';
import '../app_session.dart';

class ClientDetailsPage extends StatefulWidget {
  final CustomerEntry client; // carries region/area/subarea IDs + customerCode
  const ClientDetailsPage({Key? key, required this.client}) : super(key: key);

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  bool get _noEditByRole {
    final r = (AppSession().roleId ?? '').trim();
    return r == '6' || r == '7' || r == '1';
  }

  final _db = FirebaseDatabase.instance;
  late final ActivityLogsRepository _logsRepo = ActivityLogsRepository(db: _db);

  // For name lookups
  late final RegionsRepository _regionsRepo = RegionsRepository(db: _db);
  late final AreasRepository _areasRepo = AreasRepository(db: _db);
  late final SubAreasRepository _subAreasRepo = SubAreasRepository(db: _db);

  // --- Salesperson lookups ---
  // subareaID -> assignedSE (SalesPersonID)
  final Map<String, String> _assignedSEBySubareaId = {};
  // SalesPersonID -> SalesPersonName
  final Map<String, String> _userNameById = {};

  String _salesPersonNameFromId(String id) {
    if (id.isEmpty) return '—';
    final name = _userNameById[_s(id)] ?? '';
    return name.isNotEmpty ? name : id; // fallback to ID if name not loaded yet
  }

  String _displaySalesPerson(Map<String, dynamic> m) {
    final direct = _s(m['Sales_Person']);
    if (direct.isNotEmpty) return direct;
    final legacy = _s(m['SalesPersonName']);
    if (legacy.isNotEmpty) return legacy;
    final subId = _s(m['subareaID']);
    if (subId.isEmpty) return '—';
    final assignedId = _assignedSEBySubareaId[_s(subId)] ?? '';
    return _salesPersonNameFromId(assignedId);
  }

  // id -> name maps
  final Map<String, String> _regionNames = {};
  final Map<String, String> _areaNames = {};
  final Map<String, String> _subareaNames = {};

  // Inline edit state
  final Map<String, bool> _editing = {}; // key -> isEditing
  final Map<String, TextEditingController> _ctrls = {}; // key -> controller
  final Map<String, String?> _dropdownValues = {}; // key -> selected value

  // ----- Helpers -----
  static String _s(dynamic v) => v?.toString().trim() ?? '';

  String _formatDateish(String key, String raw) {
    if (raw.isEmpty) return '—';

    String show(DateTime d) {
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
    }

    if (key == 'Opening_Month') {
      final parts = raw.split('-');
      if (parts.length >= 2) {
        final y = int.tryParse(parts[0]) ?? 0;
        final mo = int.tryParse(parts[1]) ?? 1;
        if (y > 0 && mo >= 1 && mo <= 12) {
          const m = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          return '${m[mo - 1]} $y';
        }
      }
      return raw;
    }

    final n = int.tryParse(raw);
    if (n != null && n > 1000000)
      return show(DateTime.fromMillisecondsSinceEpoch(n));

    final iso = DateTime.tryParse(raw);
    if (iso != null) return show(iso);

    return raw;
  }

  @override
  void initState() {
    super.initState();
    // Load names for lookups
    // Load salesperson mapping (from SubAreas.assignedSE) and Users (ID->Name)
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
            if (_s(sid).isNotEmpty) map[_s(sid)] = assigned;
          }
        });
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) {
          final raw = v[i];
          if (raw is Map) {
            final sid = _s(raw['subareaID'] ?? i.toString());
            final assigned = _s(raw['assignedSE']);
            if (_s(sid).isNotEmpty) map[_s(sid)] = assigned;
          }
        }
      }
      setState(() {
        _assignedSEBySubareaId
          ..clear()
          ..addAll(map);
      });
    });

    _db.ref('Users').onValue.listen((event) {
      final v = event.snapshot.value;
      final map = <String, String>{};
      if (v is Map) {
        v.forEach((k, raw) {
          if (raw is Map) {
            final m = Map<String, dynamic>.from(raw);
            final id = _s(
              m['SalesPersonID'] ?? m['salesPersonId'] ?? m['id'] ?? k,
            );
            final name = _s(
              m['SalesPersonName'] ?? m['salesPersonName'] ?? m['name'] ?? '',
            );
            if (id.isNotEmpty && name.isNotEmpty) map[id] = name;
          }
        });
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) {
          final raw = v[i];
          if (raw is Map) {
            final m = Map<String, dynamic>.from(raw);
            final id = _s(
              m['SalesPersonID'] ??
                  m['salesPersonId'] ??
                  m['id'] ??
                  i.toString(),
            );
            final name = _s(
              m['SalesPersonName'] ?? m['salesPersonName'] ?? m['name'] ?? '',
            );
            if (id.isNotEmpty && name.isNotEmpty) map[id] = name;
          }
        }
      }
      setState(() {
        _userNameById
          ..clear()
          ..addAll(map);
      });
    });

    _regionsRepo.streamRegions().listen((rows) {
      setState(() {
        _regionNames
          ..clear()
          ..addEntries(rows.map((r) => MapEntry(_s(r.regionId), r.regionName)));
      });
    });

    _areasRepo.streamAreas().listen((rows) {
      setState(() {
        _areaNames
          ..clear()
          ..addEntries(rows.map((a) => MapEntry(_s(a.areaId), a.areaName)));
      });
    });

    _subAreasRepo.streamSubAreas().listen((rows) {
      setState(() {
        _subareaNames
          ..clear()
          ..addEntries(
            rows.map((s) => MapEntry(_s(s.subareaId), s.subareaName)),
          );
      });
    });
  }

  // ----- CLIENT DETAILS FETCH (returns record + its Firebase key) -----
  Stream<Map<String, dynamic>?> _clientByCodeStream(String customerCode) {
    final q = _db
        .ref('Clients')
        .orderByChild('customerCode')
        .equalTo(customerCode);
    return q.onValue.map((event) {
      final v = event.snapshot.value;
      if (v is Map) {
        for (final e in v.entries) {
          if (e.value is Map) {
            final m = Map<String, dynamic>.from(e.value as Map);
            m['_key'] = e.key;
            return m;
          }
        }
      } else if (v is List) {
        for (int i = 0; i < v.length; i++) {
          final item = v[i];
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            m['_key'] = i.toString();
            return m;
          }
        }
      }
      return null;
    });
  }

  // ---------- business helpers ----------
  String _catForSlab(String? slab) {
    switch (slab) {
      case '<=500':
        return 'E';
      case '500-1000':
        return 'C';
      case '1000-2000':
        return 'B';
      case '2000-3000':
        return 'A';
      case '>3000':
        return 'A+';
      default:
        return '';
    }
  }

  // ---------- UI helpers (no boxes until editing) ----------
  static String _pretty(String key) {
    // replace underscores with spaces and Title Case the words
    final k = key.replaceAll('_', ' ');
    final parts = k.split(' ');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      final w = parts[i];
      if (w.isEmpty) continue;
      final lower = w.toLowerCase();
      final prettyWord = lower[0].toUpperCase() + lower.substring(1);
      if (i > 0) buf.write(' ');
      buf.write(prettyWord);
    }
    return buf.toString();
  }

  static String _today() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
  }

  static MapEntry<String, String> _pair(String k, String v) => MapEntry(k, v);

  // ---- Which keys are editable ----
  final Set<String> _editableKeys = {
    'GST_Number',
    'Status',
    'Visit_Days',
    //'BUSINESS_SLAB', //this is auto-generated, hence, cant be modified
    //'BUSINESS_CAT', //is derived & non-editable
    'VISIT_FREQUENCY_In_Days',
    'Date_of_1st_Call',
    'Opening_Month',
    'Type_of_Institution',
    'Date_of_Opening',
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
    'Followup Date',
  };

  bool _isEditable(String key) => !_noEditByRole && _editableKeys.contains(key);

  // ---- Editors per key ----
  Widget _editorFor(String key, String currentValue, String clientKey) {
    // Ensure controller seeded
    _ctrls.putIfAbsent(key, () => TextEditingController(text: currentValue));
    _ctrls[key]!.text = currentValue;

    // Dropdown cases
    if (key == 'Status') {
      // Seed once; don’t overwrite on rebuild
      _dropdownValues[key] ??= currentValue.isEmpty ? null : currentValue;

      const base = ['Active', 'NA', 'Prospect', '']; // allowed values
      final items = <DropdownMenuItem<String>>[
        // Ensure current DB value is selectable even if not in base list
        if (currentValue.isNotEmpty && !base.contains(currentValue))
          DropdownMenuItem(value: currentValue, child: Text(currentValue)),
        // Base items
        const DropdownMenuItem(value: 'Active', child: Text('Active')),
        const DropdownMenuItem(value: 'NA', child: Text('NA')),
        const DropdownMenuItem(value: 'Prospect', child: Text('Prospect')),
        const DropdownMenuItem(value: '', child: Text('')),
      ];

      return _wrapEditor(
        key,
        DropdownButtonFormField<String>(
          value: _dropdownValues[key],
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: items,
          onChanged: (v) => setState(() => _dropdownValues[key] = v),
        ),
        onSave: () async {
          final v = (_dropdownValues[key] ?? '').trim();
          try {
            await _db.ref('Clients/$clientKey').update({'Status': v});
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Status updated to "$v"')));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update Status: $e')),
            );
          }
          setState(() => _editing[key] = false);
        },
      );
    }

    if (key == 'Visit_Days') {
      // Seed once; don’t overwrite on rebuilds
      _dropdownValues[key] ??= currentValue.isEmpty ? null : currentValue;

      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

      // Keep your exact items; (optional) inject current DB value if it’s nonstandard
      final items = <DropdownMenuItem<String>>[
        if (currentValue.isNotEmpty &&
            !days.contains(currentValue) &&
            currentValue != '')
          DropdownMenuItem(value: currentValue, child: Text(currentValue)),
        ...days.map((d) => DropdownMenuItem(value: d, child: Text(d))),
        const DropdownMenuItem(value: '', child: Text('')),
      ];

      return _wrapEditor(
        key,
        DropdownButtonFormField<String>(
          value: _dropdownValues[key],
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: items,
          onChanged: (v) => setState(() => _dropdownValues[key] = v),
        ),
        onSave: () async {
          final v = (_dropdownValues[key] ?? '').trim();
          await _db.ref('Clients/$clientKey').update({'Visit_Days': v});
          setState(() => _editing[key] = false);
        },
      );
    }

    if (key == 'BUSINESS_SLAB') {
      _dropdownValues[key] = (currentValue.isEmpty) ? null : currentValue;
      const slabs = ['<=500', '500-1000', '1000-2000', '2000-3000', '>3000'];
      return _wrapEditor(
        key,
        DropdownButtonFormField<String>(
          value: _dropdownValues[key],
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            ...slabs.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            const DropdownMenuItem(value: '', child: Text('(blank)')),
          ],
          onChanged: (v) => setState(() => _dropdownValues[key] = v),
        ),
        onSave: () async {
          final slab = _dropdownValues[key] ?? '';
          final cat = _catForSlab(slab);
          await _db.ref('Clients/$clientKey').update({
            'BUSINESS_SLAB': slab,
            'BUSINESS_CAT': cat,
          });
          setState(() => _editing[key] = false);
        },
      );
    }

    // Date pickers
    if (key == 'Date_of_1st_Call' ||
        key == 'Date_of_Opening' ||
        key == 'Opening_Month' ||
        key == 'Followup Date') {
      return _wrapEditor(
        key,
        _DateInlinePicker(
          initial: currentValue,
          isMonthOnly: key == 'Opening_Month',
          onPicked: (formatted) async {
            if (key == 'Followup Date') {
              // 'YYYY-MM-DD' -> epoch midnight
              final parts = formatted.split('-');
              final y = int.tryParse(parts[0]) ?? 0;
              final mo = (parts.length > 1) ? int.tryParse(parts[1]) ?? 1 : 1;
              final d = (parts.length > 2) ? int.tryParse(parts[2]) ?? 1 : 1;
              final epoch = DateTime(y, mo, d).millisecondsSinceEpoch;
              await _db.ref('Clients/$clientKey').update({
                'followupDate': epoch,
              });
            } else {
              await _db.ref('Clients/$clientKey').update({key: formatted});
            }
            setState(() => _editing[key] = false);
          },
        ),
        onSave: null,
      );
    }

    // Text fields (with formatters for specific keys)
    List<TextInputFormatter> fmts = <TextInputFormatter>[];
    if (key.endsWith('_Pin_Code')) {
      fmts = <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ];
    } else if (key.endsWith('Mobile_No_1') || key.endsWith('Mobile_No_2')) {
      fmts = <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ];
    } else if (key == 'VISIT_FREQUENCY_In_Days') {
      fmts = <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ];
    } else if (key == 'GST_Number') {
      fmts = <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
        LengthLimitingTextInputFormatter(15),
      ];
    } else if (key == 'Type_of_Institution') {
      fmts = <TextInputFormatter>[LengthLimitingTextInputFormatter(25)];
    } else {
      fmts = <TextInputFormatter>[LengthLimitingTextInputFormatter(30)];
    }

    return _wrapEditor(
      key,
      TextFormField(
        controller: _ctrls[key],
        inputFormatters: fmts,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      onSave: () async {
        final v = _ctrls[key]!.text.trim();
        await _db.ref('Clients/$clientKey').update({key: v});
        setState(() => _editing[key] = false);
      },
    );
  }

  Widget _wrapEditor(
    String key,
    Widget editor, {
    Future<void> Function()? onSave,
  }) {
    return Row(
      children: [
        Expanded(child: editor),
        const SizedBox(width: 8),
        if (onSave != null)
          IconButton(
            icon: const Icon(Icons.check, size: 18),
            tooltip: 'Save',
            onPressed: onSave,
          ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Cancel',
          onPressed: () => setState(() => _editing[key] = false),
        ),
      ],
    );
  }

  // ========== UI ==========
  @override
  Widget build(BuildContext context) {
    final code = widget.client.customerCode ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CommonHeader(pageTitle: 'Client Details'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Summary'),
              ),
            ),
            Expanded(
              child: StreamBuilder<Map<String, dynamic>?>(
                stream: (code.isEmpty)
                    ? const Stream.empty()
                    : _clientByCodeStream(code),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Failed to load client: ${snap.error}'),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Loading client…'),
                      ),
                    );
                  }
                  final m = snap.data!;
                  final regionName = _regionNames[_s(m['regionID'])] ?? '—';
                  final areaName = _areaNames[_s(m['areaID'])] ?? '—';
                  final subName = _subareaNames[_s(m['subareaID'])] ?? '—';
                  final clientKey = _s(m['_key']);

                  Widget rowBuilder(String key, String value) {
                    final pretty = _pretty(key);
                    final isEdit = _editing[key] == true;
                    final isEditable = _isEditable(key);
                    Widget content;
                    if (isEdit && isEditable) {
                      content = _editorFor(key, value, clientKey);
                    } else {
                      content = Text(value.isEmpty ? '—' : value);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isNarrow = MediaQuery.of(ctx).size.width < 600;
                          if (isNarrow) {
                            // Mobile: stacked label and field
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pretty,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                content,
                                if (isEditable)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      icon: Icon(
                                        isEdit ? Icons.edit_off : Icons.edit,
                                        size: 18,
                                      ),
                                      tooltip: isEdit ? 'Stop editing' : 'Edit',
                                      onPressed: () => setState(() {
                                        if (!isEdit) {
                                          if (!_ctrls.containsKey(key)) {
                                            _ctrls[key] = TextEditingController(
                                              text: value,
                                            );
                                          } else {
                                            _ctrls[key]!.text = value;
                                          }
                                          if (key == 'Status' ||
                                              key == 'Visit_Days' ||
                                              key == 'BUSINESS_SLAB') {
                                            _dropdownValues[key] = value.isEmpty
                                                ? null
                                                : value;
                                          }
                                        }
                                        _editing[key] = !isEdit;
                                      }),
                                    ),
                                  ),
                              ],
                            );
                          }
                          // Wide: original two-column layout
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 220,
                                child: Text(
                                  pretty,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: content),
                              if (isEditable)
                                IconButton(
                                  icon: Icon(
                                    isEdit ? Icons.edit_off : Icons.edit,
                                    size: 18,
                                  ),
                                  tooltip: isEdit ? 'Stop editing' : 'Edit',
                                  onPressed: () => setState(() {
                                    if (!isEdit) {
                                      if (!_ctrls.containsKey(key)) {
                                        _ctrls[key] = TextEditingController(
                                          text: value,
                                        );
                                      } else {
                                        _ctrls[key]!.text = value;
                                      }
                                      if (key == 'Status' ||
                                          key == 'Visit_Days' ||
                                          key == 'BUSINESS_SLAB') {
                                        _dropdownValues[key] = value.isEmpty
                                            ? null
                                            : value;
                                      }
                                    }
                                    _editing[key] = !isEdit;
                                  }),
                                ),
                            ],
                          );
                        },
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _DetailsSection(
                          rows: [
                            _pair('customerCode', _s(m['customerCode'])),
                            _pair('Sales_Person', _displaySalesPerson(m)),
                            _pair('regionName', regionName),
                            _pair('areaName', areaName),
                            _pair('subareaName', subName),
                            _pair('Category', _s(m['Category'])),
                            _pair(
                              'Type_of_Institution',
                              _s(m['Type_of_Institution']),
                            ),
                            _pair(
                              'Opening_Month',
                              _formatDateish(
                                'Opening_Month',
                                _s(m['Opening_Month']),
                              ),
                            ),
                            _pair(
                              'Date_of_Opening',
                              _formatDateish(
                                'Date_of_Opening',
                                _s(m['Date_of_Opening']),
                              ),
                            ),
                            _pair(
                              'Followup Date',
                              _formatDateish(
                                'followupDate',
                                _s(m['followupDate']),
                              ),
                            ),
                            _pair('BUSINESS_SLAB', _s(m['BUSINESS_SLAB'])),
                            _pair('BUSINESS_CAT', _s(m['BUSINESS_CAT'])),
                            _pair('GST_Number', _s(m['GST_Number'])),
                            _pair(
                              'Date_of_1st_Call',
                              _formatDateish(
                                'Date_of_1st_Call',
                                _s(m['Date_of_1st_Call']),
                              ),
                            ),
                            _pair('Status', _s(m['Status'])),
                            _pair('Visit_Days', _s(m['Visit_Days'])),
                            _pair(
                              'VISIT_FREQUENCY_In_Days',
                              _s(m['VISIT_FREQUENCY_In_Days']),
                            ),
                          ],
                          itemBuilder: rowBuilder,
                        ),

                        _BlockSection(
                          title: 'Institution / Clinic',
                          rows: [
                            _pair(
                              'Institution_OR_Clinic_Name',
                              _s(m['Institution_OR_Clinic_Name']),
                            ),
                            _pair(
                              'Institution_OR_Clinic_Address_1',
                              _s(m['Institution_OR_Clinic_Address_1']),
                            ),
                            _pair(
                              'Institution_OR_Clinic_Address_2',
                              _s(m['Institution_OR_Clinic_Address_2']),
                            ),
                            _pair(
                              'Institution_OR_Clinic_Landmark',
                              _s(m['Institution_OR_Clinic_Landmark']),
                            ),
                            _pair(
                              'Institution_OR_Clinic_Pin_Code',
                              _s(m['Institution_OR_Clinic_Pin_Code']),
                            ),
                          ],
                          itemBuilder: rowBuilder,
                        ),

                        _BlockSection(
                          title: 'Doctor',
                          rows: [
                            _pair('Doc_Name', _s(m['Doc_Name'])),
                            _pair('Doc_Mobile_No_1', _s(m['Doc_Mobile_No_1'])),
                            _pair('Doc_Mobile_No_2', _s(m['Doc_Mobile_No_2'])),
                          ],
                          itemBuilder: rowBuilder,
                        ),

                        _BlockSection(
                          title: 'Pharmacy',
                          rows: [
                            _pair('Pharmacy_Name', _s(m['Pharmacy_Name'])),
                            _pair(
                              'Pharmacy_Address_1',
                              _s(m['Pharmacy_Address_1']),
                            ),
                            _pair(
                              'Pharmacy_Address_2',
                              _s(m['Pharmacy_Address_2']),
                            ),
                            _pair(
                              'Pharmacy_Landmark',
                              _s(m['Pharmacy_Landmark']),
                            ),
                            _pair(
                              'Pharmacy_Pin_Code',
                              _s(m['Pharmacy_Pin_Code']),
                            ),
                            _pair(
                              'Pharmacy_Person_Name',
                              _s(m['Pharmacy_Person_Name']),
                            ),
                            _pair(
                              'Pharmacy_Mobile_No_1',
                              _s(m['Pharmacy_Mobile_No_1']),
                            ),
                            _pair(
                              'Pharmacy_Mobile_No_2',
                              _s(m['Pharmacy_Mobile_No_2']),
                            ),
                          ],
                          itemBuilder: rowBuilder,
                        ),

                        _Section(
                          title: 'Activity Logs',
                          child: _ActivityLogs(
                            logsRepo: _logsRepo,
                            customerCode: code,
                            clientKey: clientKey,
                            visitDays: _s(m['Visit_Days']),
                            currentFollowupRaw: m['followupDate'],
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CommonFooter(),
    );
  }
}

// ------------------- UI building blocks -------------------

class _DetailsSection extends StatelessWidget {
  final List<MapEntry<String, String>> rows;
  final Widget Function(String key, String value)? itemBuilder;

  const _DetailsSection({required this.rows, this.itemBuilder, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map(
              (e) => itemBuilder != null
                  ? itemBuilder!(e.key, e.value)
                  : _defaultKvRow(context, e.key, e.value),
            )
            .toList(),
      ),
    );
  }

  Widget _defaultKvRow(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              _ClientDetailsPageState._pretty(key),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _BlockSection extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> rows;
  final Widget Function(String key, String value)? itemBuilder;

  const _BlockSection({
    required this.title,
    required this.rows,
    this.itemBuilder,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: Column(
        children: rows
            .map(
              (e) => itemBuilder != null
                  ? itemBuilder!(e.key, e.value)
                  : _defaultRow(context, e.key, e.value),
            )
            .toList(),
      ),
    );
  }

  Widget _defaultRow(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              _ClientDetailsPageState._pretty(key),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// -------------------- Activity logs widget with Follow-up Date --------------------

class _ActivityLogs extends StatefulWidget {
  final ActivityLogsRepository logsRepo;
  final String customerCode;

  // NEW:
  final String clientKey; // Clients/<clientKey>
  final String visitDays; // MON..SUN (or empty)
  final dynamic currentFollowupRaw; // existing followupDate (int or string)

  const _ActivityLogs({
    required this.logsRepo,
    required this.customerCode,
    required this.clientKey,
    required this.visitDays,
    required this.currentFollowupRaw,
    Key? key,
  }) : super(key: key);

  @override
  State<_ActivityLogs> createState() => _ActivityLogsState();
}

class _ActivityLogsState extends State<_ActivityLogs> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'New Call';
  DateTime _activityDateTime = DateTime.now();
  final TextEditingController _messageCtrl = TextEditingController();
  String? _response;

  // Follow-up
  DateTime _followupDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Prefill to next Visit_Days (default MON if blank)
    final vd = (widget.visitDays.isNotEmpty) ? widget.visitDays : 'MON';
    _followupDate = _nextWeekday(DateTime.now(), vd);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  // ---- follow-up helpers ----
  int _weekdayFromCode(String code) {
    switch (code.toUpperCase()) {
      case 'MON':
        return DateTime.monday;
      case 'TUE':
        return DateTime.tuesday;
      case 'WED':
        return DateTime.wednesday;
      case 'THU':
        return DateTime.thursday;
      case 'FRI':
        return DateTime.friday;
      case 'SAT':
        return DateTime.saturday;
      case 'SUN':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  DateTime _nextWeekday(DateTime from, String dayCode) {
    final target = _weekdayFromCode(dayCode);
    final delta = (target - from.weekday + 7) % 7;
    final add = (delta == 0) ? 7 : delta; // always NEXT occurrence
    return DateTime(from.year, from.month, from.day).add(Duration(days: add));
  }

  int _epochMidnight(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  DateTime? _parseFollowupRaw(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final n = int.tryParse(s);
    if (n != null && n > 1000000) return DateTime.fromMillisecondsSinceEpoch(n);

    final m = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(s);
    if (m != null) {
      const months = {
        'JAN': 1,
        'FEB': 2,
        'MAR': 3,
        'APR': 4,
        'MAY': 5,
        'JUN': 6,
        'JUL': 7,
        'AUG': 8,
        'SEP': 9,
        'OCT': 10,
        'NOV': 11,
        'DEC': 12,
      };
      final day = int.parse(m.group(1)!);
      final mon = months[m.group(2)!.toUpperCase()] ?? 1;
      final yr = int.parse(m.group(3)!);
      return DateTime(yr, mon, day);
    }

    return DateTime.tryParse(s); // ISO fallback
  }

  String _fmt(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dd = d.day.toString().padLeft(2, '0');
    final mon = m[d.month - 1];
    final yyyy = d.year.toString();
    return '$dd-$mon-$yyyy';
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _activityDateTime,
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_activityDateTime),
    );
    if (t == null) return;
    setState(() {
      _activityDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _submitLog() async {
    if (!_formKey.currentState!.validate()) return;

    await widget.logsRepo.addLog(
      customerCode: widget.customerCode,
      type: _type,
      message: _messageCtrl.text.trim(),
      dateTime: _activityDateTime,
      userId: (AppSession().salesPersonId ?? '').trim(),
      response: (_response ?? '').trim(),
    );

    // Move old followupDate -> lastFollowupDate, set new followupDatea
    final prev = _parseFollowupRaw(widget.currentFollowupRaw);
    final updates = <String, dynamic>{
      'followupDate': _epochMidnight(_followupDate),
    };
    if (prev != null) updates['lastFollowupDate'] = _epochMidnight(prev);

    await FirebaseDatabase.instance
        .ref('Clients/${widget.clientKey}')
        .update(updates);

    _messageCtrl.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Activity log added')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form
        Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  // Type
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      items: const [
                        DropdownMenuItem(
                          value: 'New Call',
                          child: Text('New Call'),
                        ),
                        DropdownMenuItem(
                          value: 'Follow Up Call',
                          child: Text('Follow Up Call'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'New Call'),
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Response
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _response,
                      items: const [
                        DropdownMenuItem(value: 'Hot', child: Text('Hot')),
                        DropdownMenuItem(value: 'Warm', child: Text('Warm')),
                        DropdownMenuItem(value: 'Cold', child: Text('Cold')),
                        DropdownMenuItem(
                          value: 'Stock Available',
                          child: Text('Stock Available'),
                        ),
                        DropdownMenuItem(
                          value: 'Delivery Done',
                          child: Text('Delivery Done'),
                        ),
                        DropdownMenuItem(
                          value: 'Shop Closed',
                          child: Text('Shop Closed'),
                        ),
                        DropdownMenuItem(
                          value: 'Doc Not Met',
                          child: Text('Doc Not Met'),
                        ),
                        DropdownMenuItem(
                          value: 'Payment Received',
                          child: Text('Payment Received'),
                        ),
                        DropdownMenuItem(
                          value: 'Order Received',
                          child: Text('Order Received'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _response = v),
                      decoration: const InputDecoration(
                        labelText: 'Response',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      // Optional: make it required
                      // validator: (v) => (v == null || v.isEmpty) ? 'Please select response' : null,
                    ),
                  ),

                  const SizedBox(width: 12),
                  // Date & Time
                  Expanded(
                    child: InkWell(
                      onTap: _pickDateTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date & Time',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _formatDT(_activityDateTime),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Follow-up Date
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _followupDate,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                    helpText: 'Select Follow-up Date',
                  );
                  if (d != null) setState(() => _followupDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Date',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _fmt(_followupDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Message
              TextFormField(
                controller: _messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter notes…',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a message'
                    : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Add Log',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(),

        // Live list
        StreamBuilder<List<ActivityLogEntry>>(
          stream: widget.logsRepo.streamForCustomer(widget.customerCode),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Failed to load logs: ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Loading logs…'),
              );
            }
            final logs = snap.data!;
            if (logs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No activity logs yet.'),
              );
            }
            return ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final l = logs[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text('${l.type}  •  ${_formatDT(l.dateTime)}'),
                  subtitle: Text(l.message),
                );
              },
            );
          },
        ),
      ],
    );
  }

  static String _formatDT(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final mm = months[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final nn = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $mm ${dt.year}, $hh:$nn';
  }
}

// ----------------- Small inline date/month editor used only while editing -----------------

class _DateInlinePicker extends StatefulWidget {
  final String initial; // 'YYYY-MM-DD' or 'YYYY-MM' or empty
  final bool isMonthOnly;
  final ValueChanged<String> onPicked;
  const _DateInlinePicker({
    required this.initial,
    required this.isMonthOnly,
    required this.onPicked,
  });

  @override
  State<_DateInlinePicker> createState() => _DateInlinePickerState();
}

class _DateInlinePickerState extends State<_DateInlinePicker> {
  String _value = '';

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    DateTime init;
    if (widget.isMonthOnly) {
      init = _parseMonth(_value) ?? DateTime(now.year, now.month, 1);
    } else {
      init = _parseDate(_value) ?? now;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: widget.isMonthOnly ? 'Select Opening Month' : null,
    );
    if (date != null) {
      setState(() {
        final yyyy = date.year.toString().padLeft(4, '0');
        final mm = date.month.toString().padLeft(2, '0');
        final dd = date.day.toString().padLeft(2, '0');
        _value = widget.isMonthOnly ? '$yyyy-$mm' : '$yyyy-$mm-$dd';
      });
      widget.onPicked(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _pick,
      child: InputDecorator(
        decoration: const InputDecoration(border: OutlineInputBorder()),
        child: Row(
          children: [
            Expanded(child: Text(_value.isEmpty ? 'Select' : _value)),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  // parse helpers
  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    final m1 = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (m1 != null) {
      final y = int.parse(m1.group(1)!);
      final m = int.parse(m1.group(2)!);
      final d = int.parse(m1.group(3)!);
      return DateTime(y, m, d);
    }
    return null;
  }

  DateTime? _parseMonth(String s) {
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(s);
    if (m != null) {
      final y = int.parse(m.group(1)!);
      final mm = int.parse(m.group(2)!);
      return DateTime(y, mm, 1);
    }
    return null;
  }
}
