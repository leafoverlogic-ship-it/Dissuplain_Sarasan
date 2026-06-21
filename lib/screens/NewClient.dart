import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';

// Repo-driven dropdown sources (same as ClientsSummary)
import '../../dataLayer/regions_repository.dart';
import '../../dataLayer/areas_repository.dart';
import '../../dataLayer/subareas_repository.dart';

import '../CommonHeader.dart';
import '../CommonFooter.dart';

class NewClientPage extends StatefulWidget {
  const NewClientPage({
    super.key,
    this.allowedRegionIds = const [],
    this.allowedAreaIds = const [],
    this.allowedSubareaIds = const [],
    // add these three optional params to keep older call sites compiling
    this.roleId,
    this.salesPersonName,
    this.allAccess,
  });

  /// Pass the same restricted lists you use in Client Summary / Beat Plan
  final List<String> allowedRegionIds;
  final List<String> allowedAreaIds;
  final List<String> allowedSubareaIds;

  // add these three fields
  final String? roleId;
  final String? salesPersonName;
  final bool? allAccess;

  @override
  State<NewClientPage> createState() => _NewClientPageState();
}

class _NewClientPageState extends State<NewClientPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseDatabase.instance;

  // ---------- Base fields ----------
  final _clientNameCtrl = TextEditingController(); // 30 (Institution Name)
  final _address1Ctrl = TextEditingController(); // 30
  final _address2Ctrl = TextEditingController(); // 30
  final _pinCodeCtrl = TextEditingController(); // 6 numeric

  // ---------- Contact Person Sections (2 copies) ----------
  final _contact1NameCtrl = TextEditingController(); // 30
  final _contact1PhoneCtrl = TextEditingController(); // 10 numeric
  final _contact1WhatsappCtrl = TextEditingController(); // 10 numeric
  bool _contact1WhatsappError = false;

  final _contact2NameCtrl = TextEditingController(); // 30
  final _contact2PhoneCtrl = TextEditingController(); // 10 numeric
  final _contact2WhatsappCtrl = TextEditingController(); // 10 numeric
  bool _contact2WhatsappError = false;

  // Derived/readonly
  final _salesPersonNameCtrl = TextEditingController(); // auto-filled

  final _customerCodeCtrl =
      TextEditingController(); // auto-generated (read-only)

  // ---------- New required fields ----------
  // Doctor
  final _docMobileNo1Ctrl = TextEditingController(); // 10 numeric
  final _docNameCtrl = TextEditingController(); // 30
  final _docMobileNo2Ctrl = TextEditingController(); // 10 numeric

  // Institution / Clinic
  final _instNameCtrl = TextEditingController(); // 30
  final _instAddr1Ctrl = TextEditingController(); // 30
  final _instAddr2Ctrl = TextEditingController(); // 30
  final _instLandmarkCtrl = TextEditingController(); // 30
  final _instPincodeCtrl = TextEditingController(); // 6 numeric

  // Pharmacy
  final _phNameCtrl = TextEditingController(); // 30
  final _phAddr1Ctrl = TextEditingController(); // 30
  final _phAddr2Ctrl = TextEditingController(); // 30
  final _phLandmarkCtrl = TextEditingController(); // 30
  final _phPinCtrl = TextEditingController(); // 6 numeric
  final _phPersonNameCtrl = TextEditingController(); // 30
  final _phMobile1Ctrl = TextEditingController(); // 10 numeric
  final _phMobile2Ctrl = TextEditingController(); // 10 numeric

  // GST
  final _gstNumberCtrl = TextEditingController(); // 15 (alphanumeric)
  // Business / Status
  String? _statusValue; // Active, NA, Hot, Warm, Cold, Prospect
  String? _visitDaysValue; // MON..SUN
  final _visitFreqDaysCtrl = TextEditingController(); // 3 numeric

  // ---------- Hierarchy & Category ----------
  String? _selectedRegionId;
  String? _selectedAreaId;
  String? _selectedAreaName; // City
  String? _selectedSubareaId;
  String? _selectedSubareaName; // Destination

  String? _selectedCategoryName;
  String? _selectedCategoryCode;

  // Sales person derived from SubAreas.assignedSE -> Users
  String? _assignedSEId;

  // Hidden Customer_ID
  int? _nextCustomerId;

  // Dates
  DateTime? _dateOfFirstCall;
  DateTime? _openingMonth; // stored as YYYY-MM
  DateTime? _dateOfOpening;

  bool _loading = true;
  String? _error;

  // ---------- Cached tables ----------
  final Map<String, String> _regions = {}; // regionID -> name
  final Map<String, Map<String, dynamic>> _areas =
      {}; // areaID -> {name, regionID}

  final Map<String, Map<String, dynamic>> _subareas =
      {}; // subareaID -> {name, areaID, assignedSE}

  final Map<String, String> _users = {}; // salesPersonID -> name
  final Map<String, String> _categories = {}; // categoryName -> categoryCode

  // Repo-backed streams (same approach as ClientsSummary)
  late final RegionsRepository _regionsRepo = RegionsRepository(db: _db);
  late final AreasRepository _areasRepo = AreasRepository(db: _db);
  late final SubAreasRepository _subAreasRepo = SubAreasRepository(db: _db);

  List<RegionEntry> _regionsR = const [];
  List<AreaEntry> _areasR = const [];
  List<SubAreaEntry> _subAreasR = const [];

  bool _lr = true, _la = true, _ls = true;
  String? _er, _ea, _es;

  // Helpers
  String _s(dynamic v) => (v == null) ? '' : v.toString().trim();

  @override
  void initState() {
    super.initState();

    if ((widget.salesPersonName ?? '').trim().isNotEmpty) {
      _salesPersonNameCtrl.text = widget.salesPersonName!.trim();
    }

    // --- Stream region/area/subarea from repositories (names shown, no "All") ---
    _regionsRepo.streamRegions().listen(
      (rows) {
        setState(() {
          _regionsR = rows;
          _lr = false;
        });

        _maybeAutoselectLocations();
      },
      onError: (e) => setState(() {
        _lr = false;
        _er = '$e';
      }),
    );

    _areasRepo.streamAreas().listen(
      (rows) {
        setState(() {
          _areasR = rows
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
        _maybeAutoselectLocations();
      },
      onError: (e) => setState(() {
        _la = false;
        _ea = '$e';
      }),
    );

    _subAreasRepo.streamSubAreas().listen(
      (rows) {
        setState(() {
          _subAreasR = rows
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
        _maybeAutoselectLocations();
      },
      onError: (e) => setState(() {
        _ls = false;
        _es = '$e';
      }),
    );

    // Keep your existing bootstrap for other data (users, categories, assignedSE, customer id, etc.)
    _bootstrap();
  }

  @override
  void dispose() {
    // Base
    _clientNameCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _pinCodeCtrl.dispose();

    // Contact Person Sections
    _contact1NameCtrl.dispose();
    _contact1PhoneCtrl.dispose();
    _contact1WhatsappCtrl.dispose();
    _contact2NameCtrl.dispose();
    _contact2PhoneCtrl.dispose();
    _contact2WhatsappCtrl.dispose();
    //_typeInstCtrl.dispose();

    _salesPersonNameCtrl.dispose();
    _customerCodeCtrl.dispose();

    // Doctor
    _docMobileNo1Ctrl.dispose();
    _docNameCtrl.dispose();
    _docMobileNo2Ctrl.dispose();

    // Institution/Clinic
    _instNameCtrl.dispose();
    _instAddr1Ctrl.dispose();
    _instAddr2Ctrl.dispose();
    _instLandmarkCtrl.dispose();
    _instPincodeCtrl.dispose();

    // Pharmacy
    _phNameCtrl.dispose();
    _phAddr1Ctrl.dispose();
    _phAddr2Ctrl.dispose();
    _phLandmarkCtrl.dispose();
    _phPinCtrl.dispose();
    _phPersonNameCtrl.dispose();
    _phMobile1Ctrl.dispose();
    _phMobile2Ctrl.dispose();

    // GST/Business
    _gstNumberCtrl.dispose();
    _visitFreqDaysCtrl.dispose();

    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await Future.wait([
        _loadRegions(),
        _loadAreas(),
        _loadSubareas(),
        _loadUsers(),
        _loadCategories(),
        _computeNextCustomerId(),
      ]);
    } catch (e) {
      _error = 'Failed to load data: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRegions() async {
    final snap = await _db.ref('Regions').get();
    final v = snap.value;
    if (v is Map) {
      v.forEach((_, raw) {
        if (raw is Map) {
          final id = _s(raw['regionID']);
          final name = _s(raw['regionName'] ?? raw['name']);
          if (id.isNotEmpty) _regions[id] = name;
        }
      });
    } else if (v is List) {
      for (final raw in v) {
        if (raw is Map) {
          final id = _s(raw['regionID']);
          final name = _s(raw['regionName'] ?? raw['name']);
          if (id.isNotEmpty) _regions[id] = name;
        }
      }
    }
  }

  Future<void> _loadAreas() async {
    final snap = await _db.ref('Areas').get();
    final v = snap.value;
    if (v is Map) {
      v.forEach((k, raw) {
        if (raw is Map) {
          final id = _s(
            raw['areaID'].toString().isNotEmpty ? raw['areaID'] : k,
          );

          final name = _s(raw['areaName'] ?? raw['name']);
          final regionId = _s(raw['regionID']);
          if (id.isNotEmpty) _areas[id] = {'name': name, 'regionID': regionId};
        }
      });
    } else if (v is List) {
      for (int i = 0; i < v.length; i++) {
        final raw = v[i];
        if (raw is Map) {
          final id = _s(raw['areaID'] ?? i);
          final name = _s(raw['areaName'] ?? raw['name']);
          final regionId = _s(raw['regionID']);
          if (id.isNotEmpty) _areas[id] = {'name': name, 'regionID': regionId};
        }
      }
    }
  }

  Future<void> _loadSubareas() async {
    final snap = await _db.ref('SubAreas').get();
    final v = snap.value;
    if (v is Map) {
      v.forEach((k, raw) {
        if (raw is Map) {
          final id = _s(
            raw['subareaID'].toString().isNotEmpty ? raw['subareaID'] : k,
          );

          final name = _s(raw['subareaName'] ?? raw['name']);
          final areaId = _s(raw['areaID']);
          final assignedSE = _s(raw['assignedSE']);
          if (id.isNotEmpty) {
            _subareas[id] = {
              'name': name,
              'areaID': areaId,
              'assignedSE': assignedSE,
            };
          }
        }
      });
    } else if (v is List) {
      for (int i = 0; i < v.length; i++) {
        final raw = v[i];
        if (raw is Map) {
          final id = _s(raw['subareaID'] ?? i);
          final name = _s(raw['subareaName'] ?? raw['name']);
          final areaId = _s(raw['areaID']);
          final assignedSE = _s(raw['assignedSE']);
          if (id.isNotEmpty) {
            _subareas[id] = {
              'name': name,
              'areaID': areaId,
              'assignedSE': assignedSE,
            };
          }
        }
      }
    }
  }

  Future<void> _loadUsers() async {
    final snap = await _db.ref('Users').get();
    final v = snap.value;
    if (v is Map) {
      v.forEach((_, raw) {
        if (raw is Map) {
          final id = _s(raw['SalesPersonID'] ?? raw['salesPersonID']);
          final name = _s(raw['SalesPersonName'] ?? raw['salesPersonName']);
          if (id.isNotEmpty) _users[id] = name;
        }
      });
    } else if (v is List) {
      for (final raw in v) {
        if (raw is Map) {
          final id = _s(raw['SalesPersonID'] ?? raw['salesPersonID']);
          final name = _s(raw['SalesPersonName'] ?? raw['salesPersonName']);
          if (id.isNotEmpty) _users[id] = name;
        }
      }
    }
  }

  Future<void> _loadCategories() async {
    final snap = await _db.ref('Categories').get();
    final v = snap.value;
    if (v is Map) {
      v.forEach((_, raw) {
        if (raw is Map) {
          final name = _s(raw['categoryName']);
          final code = _s(raw['categoryCode']);
          if (name.isNotEmpty && code.isNotEmpty) {
            _categories[name] = code;
          }
        }
      });
    } else if (v is List) {
      for (final raw in v) {
        if (raw is Map) {
          final name = _s(raw['categoryName']);
          final code = _s(raw['categoryCode']);
          if (name.isNotEmpty && code.isNotEmpty) {
            _categories[name] = code;
          }
        }
      }
    }
  }

  Future<void> _computeNextCustomerId() async {
    int maxId = 0;
    final snap = await _db.ref('Clients').get();
    final v = snap.value;

    void consider(dynamic raw) {
      if (raw is Map) {
        final cidStr = _s(
          raw['Customer_ID'] ?? raw['customer_id'] ?? raw['CustomerID'],
        );

        if (cidStr.isNotEmpty) {
          final cid = int.tryParse(cidStr) ?? 0;
          if (cid > maxId) maxId = cid;
        }
      }
    }

    if (v is Map) {
      v.forEach((_, raw) => consider(raw));
    } else if (v is List) {
      for (final raw in v) consider(raw);
    }

    _nextCustomerId = maxId + 1; // Next id per spec
  }

  // ---------- Repo-backed dropdown helpers (names shown, no "All") ----------
  bool _matchesAllowed(String value, Set<String> allow) {
    final v = _s(value).toLowerCase();
    return allow.isEmpty || allow.contains(v) || allow.contains(v.replaceAll(' ', ''));
  }

  List<DropdownMenuItem<String>> _regionItemsR() {
    final allow = widget.allowedRegionIds.map((e) => _s(e).toLowerCase()).toSet();

    final rows =
        _regionsR
            .where((r) => allow.isEmpty || _matchesAllowed(r.regionId, allow) || _matchesAllowed(r.regionName, allow))
            .toList()
          ..sort(
            (a, b) => a.regionName.toLowerCase().compareTo(
              b.regionName.toLowerCase(),
            ),
          );

    return rows
        .map(
          (r) => DropdownMenuItem(
            value: _s(r.regionId),
            child: Text(r.regionName),
          ),
        )
        .toList();
  }

  List<DropdownMenuItem<String>> _categoryItems() {
    final allowedCategories = [
      'Clinic',
      'Hospital',
      'Prescriber',
      'Standalone medical shop',
      'Physiotherapy centre',
      'Gym',
    ];
    return allowedCategories
        .map((name) => DropdownMenuItem<String>(value: name, child: Text(name)))
        .toList();
  }

  List<DropdownMenuItem<String>> _areaItemsR() {
    final allow = widget.allowedAreaIds.map((e) => _s(e).toLowerCase()).toSet();

    Iterable<AreaEntry> pool = _areasR.where(
      (a) => allow.isEmpty || _matchesAllowed(a.areaId, allow) || _matchesAllowed(a.areaName, allow),
    );

    if ((_selectedRegionId ?? '').isNotEmpty) {
      pool = pool.where((a) => _s(a.regionId) == _selectedRegionId);
    }
    final rows = pool.toList()
      ..sort(
        (a, b) => a.areaName.toLowerCase().compareTo(b.areaName.toLowerCase()),
      );

    return rows
        .map(
          (a) => DropdownMenuItem(value: _s(a.areaId), child: Text(a.areaName)),
        )
        .toList();
  }

  List<DropdownMenuItem<String>> _subAreaItemsR() {
    final allow = widget.allowedSubareaIds.map((e) => _s(e).toLowerCase()).toSet();

    Iterable<SubAreaEntry> pool = _subAreasR.where(
      (s) => allow.isEmpty || _matchesAllowed(s.subareaId, allow) || _matchesAllowed(s.subareaName, allow),
    );

    if ((_selectedRegionId ?? '').isNotEmpty) {
      pool = pool.where((s) => _s(s.regionId) == _selectedRegionId);
    }
    if ((_selectedAreaId ?? '').isNotEmpty) {
      pool = pool.where((s) => _s(s.areaId) == _selectedAreaId);
    }
    final rows = pool.toList()
      ..sort(
        (a, b) =>
            a.subareaName.toLowerCase().compareTo(b.subareaName.toLowerCase()),
      );

    return rows
        .map(
          (s) => DropdownMenuItem(
            value: _s(s.subareaId),
            child: Text(s.subareaName),
          ),
        )
        .toList();
  }

  // ---- Auto-select when a single option exists ----
  void _maybeAutoselectLocations() {
    if (_lr || _la || _ls) return; // wait until all loaded

    // Region
    final regItems = _regionItemsR();
    if ((_selectedRegionId ?? '').isEmpty && regItems.length == 1) {
      _selectedRegionId = regItems.first.value;
    }

    // Area
    final areaItems = _areaItemsR();
    if ((_selectedAreaId ?? '').isEmpty && areaItems.length == 1) {
      _selectedAreaId = areaItems.first.value;
      // also set Area name for CustomerCode generation
      final a = _areasR.firstWhere(
        (x) => _s(x.areaId) == _selectedAreaId,
        orElse: () => const AreaEntry(areaId: '', areaName: '', regionId: ''),
      );
      _selectedAreaName = a.areaName.isNotEmpty ? a.areaName : null;
    } else if (areaItems.every((i) => i.value != _selectedAreaId)) {
      _selectedAreaId = null;
      _selectedAreaName = null;
    }

    // Sub-area
    final subItems = _subAreaItemsR();
    if ((_selectedSubareaId ?? '').isEmpty && subItems.length == 1) {
      _selectedSubareaId = subItems.first.value;
      final s = _subAreasR.firstWhere(
        (x) => _s(x.subareaId) == _selectedSubareaId,
        orElse: () => const SubAreaEntry(
          subareaId: '',
          subareaName: '',
          areaId: '',
          regionId: '',
        ),
      );
      _selectedSubareaName = s.subareaName.isNotEmpty ? s.subareaName : null;

      // derive salesperson name if _subareas map has assignedSE (from bootstrap)
      final assigned = _s(_subareas[_selectedSubareaId]?['assignedSE']);
      _assignedSEId = assigned.isNotEmpty ? assigned : null;
      _salesPersonNameCtrl.text = (_assignedSEId != null)
          ? _s(_users[_assignedSEId!])
          : '';
    } else if (subItems.every((i) => i.value != _selectedSubareaId)) {
      _selectedSubareaId = null;
      _selectedSubareaName = null;
    }

    if (mounted) setState(() {});
  }

  // ---------- Dropdown change handlers ----------
  void _onRegionChanged(String? regionId) {
    setState(() {
      _selectedRegionId = regionId;
      _selectedAreaId = null;
      _selectedAreaName = null;
      _selectedSubareaId = null;
      _selectedSubareaName = null;
      _assignedSEId = null;
      _salesPersonNameCtrl.text = '';
      _customerCodeCtrl.text = '';
    });
  }

  void _onAreaChanged(String? areaId) {
    setState(() {
      _selectedAreaId = areaId;
      _selectedAreaName = (areaId != null) ? _s(_areas[areaId]?['name']) : null;
      _selectedSubareaId = null;
      _selectedSubareaName = null;
      _assignedSEId = null;
      _salesPersonNameCtrl.text = '';
      _customerCodeCtrl.text = '';
    });
    _tryGenerateCustomerCode();
  }

  void _onSubareaChanged(String? subId) {
    setState(() {
      _selectedSubareaId = subId;
      _selectedSubareaName = (subId != null)
          ? _s(_subareas[subId]?['name'])
          : null;

      final assigned = (subId != null)
          ? _s(_subareas[subId]?['assignedSE'])
          : '';

      _assignedSEId = assigned.isNotEmpty ? assigned : null;
      final spName = (_assignedSEId != null) ? _s(_users[_assignedSEId!]) : (widget.salesPersonName ?? '');
      _salesPersonNameCtrl.text = spName;
    });
  }

  // ---------- Category code mapping ----------
  String _getCategoryCode(String categoryName) {
    // First check if it exists in database-loaded categories
    if (_categories.containsKey(categoryName)) {
      return _categories[categoryName] ?? '';
    }
    // Default mappings for standard categories
    final defaultCodes = {
      'Clinic': 'CL',
      'Hospital': 'HO',
      'Prescriber': 'PR',
      'Standalone medical shop': 'SM',
      'Physiotherapy centre': 'PT',
      'Gym': 'GY',
    };
    return defaultCodes[categoryName] ?? '';
  }

  void _onCategoryChanged(String? name) {
    setState(() {
      _selectedCategoryName = name;
      _selectedCategoryCode = (name != null) ? _getCategoryCode(name) : null;
    });
    _tryGenerateCustomerCode();
  }

  // ---------- Code generation ----------
  String _threeLetters(String? areaName) {
    final s = _s(areaName).toUpperCase();
    if (s.length >= 3) return s.substring(0, 3);
    return s.padRight(3, 'X');
  }

  String _pad6(int n) => n.toString().padLeft(6, '0');

  void _tryGenerateCustomerCode() {
    if (_selectedAreaName != null &&
        _selectedAreaName!.isNotEmpty &&
        _selectedCategoryCode != null &&
        _selectedCategoryCode!.isNotEmpty &&
        _nextCustomerId != null) {
      final area3 = _threeLetters(_selectedAreaName);
      final cat = _selectedCategoryCode!;
      final next = _pad6(_nextCustomerId!);
      _customerCodeCtrl.text = '$area3$cat$next';
    }
  }

  // ---------- Dates ----------
  Future<void> _pickDateOfFirstCall() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dateOfFirstCall ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => _dateOfFirstCall = d);
  }

  Future<void> _pickOpeningMonth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _openingMonth ?? DateTime(now.year, now.month, 1),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Select Opening Month',
    );
    if (d != null) {
      setState(() => _openingMonth = DateTime(d.year, d.month, 1));
    }
  }

  Future<void> _pickDateOfOpening() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dateOfOpening ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _dateOfOpening = d);
  }

  String _formatMonthYear(DateTime? d) {
    if (d == null) return '';
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

    return '${months[d.month - 1]} ${d.year}';
  }

  // ---------- Input formatters ----------
  List<TextInputFormatter> _limit30() => [LengthLimitingTextInputFormatter(30)];
  List<TextInputFormatter> _digits10() => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];
  List<TextInputFormatter> _digits6() => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ];
  List<TextInputFormatter> _digits3() => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(3),
  ];
  List<TextInputFormatter> _gstAlnum15() => [
    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(15),
  ];

  // ---------- Save ----------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Required core selections
    if (_selectedRegionId == null ||
        _selectedAreaId == null ||
        _selectedSubareaId == null ||
        _selectedCategoryName == null ||
        _selectedCategoryCode == null ||
        _nextCustomerId == null ||
        _customerCodeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete Region, Area, Sub-Area, Category selections.',
          ),
        ),
      );
      return;
    }

    // Check at least one contact person section is filled
    final contact1Filled = _contact1NameCtrl.text.trim().isNotEmpty &&
        _contact1PhoneCtrl.text.trim().isNotEmpty;
    final contact2Filled = _contact2NameCtrl.text.trim().isNotEmpty &&
        _contact2PhoneCtrl.text.trim().isNotEmpty;

    if (!contact1Filled && !contact2Filled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill at least one complete Contact Person/Doctor section (name and phone number).',
          ),
        ),
      );
      return;
    }

    if (_clientNameCtrl.text.trim().isEmpty ||
        _address1Ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter Institution Name and Address 1 before saving.',
          ),
        ),
      );
      return;
    }

    if (_instNameCtrl.text.trim().isEmpty) {
      if (_phNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter either Institute Name or Pharmacy.'),
          ),
        );
        return;
      }
    } else {
      if (_address1Ctrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Institute Address 1.')),
        );
        return;
      }
    }

    final customerId = _nextCustomerId!;
    final customerKey = customerId.toString();

    final data = {
      // --- Mappings for Region/Area/Sub-Area ---
      'regionID': _selectedRegionId,
      'City': _selectedAreaName, // Area name
      'areaID': _selectedAreaId,
      'Destination': _selectedSubareaName, // Sub-area name
      'subareaID': _selectedSubareaId,

      // --- Sales Person derived ---
      'assignedSE': _assignedSEId,
      'SalesPersonName': _salesPersonNameCtrl.text.trim(),

      // --- Category & IDs ---
      'Category': _selectedCategoryName,
      'categoryCode': _selectedCategoryCode,
      'Customer_ID': customerId.toString(), // hidden numeric id
      'customerCode': _customerCodeCtrl.text,
      'DateOfFirstCall': _dateOfFirstCall?.toIso8601String(),
      'OpeningMonth': _openingMonth != null
          ? '${_openingMonth!.year}-${_openingMonth!.month.toString().padLeft(2, '0')}'
          : null,

      // --- Base fields (caps & lengths already enforced) ---
      'ClientName': _clientNameCtrl.text.trim(),
      'Address1': _address1Ctrl.text.trim(),
      'Address2': _address2Ctrl.text.trim(),
      'Contact_Person_1_Name': _contact1NameCtrl.text.trim(),
      'Contact_Person_1_Phone': _contact1PhoneCtrl.text.trim(),
      'Contact_Person_1_Whatsapp': _contact1WhatsappCtrl.text.trim(),
      'Contact_Person_2_Name': _contact2NameCtrl.text.trim(),
      'Contact_Person_2_Phone': _contact2PhoneCtrl.text.trim(),
      'Contact_Person_2_Whatsapp': _contact2WhatsappCtrl.text.trim(),
      'PinCode': _pinCodeCtrl.text.trim(),
      'DateOfOpening': _dateOfOpening?.toIso8601String(),

      // --- NEW: Doctor in Institution ---
      'Institution_OR_Clinic_Name': _instNameCtrl.text.trim(),
      'Institution_OR_Clinic_Address_1': _instAddr1Ctrl.text.trim(),
      'Institution_OR_Clinic_Address_2': _instAddr2Ctrl.text.trim(),
      'Institution_OR_Clinic_Landmark': _instLandmarkCtrl.text.trim(),
      'Institution_OR_Clinic_Pin_Code': _instPincodeCtrl.text.trim(),
      'Doc_Name': _docNameCtrl.text.trim(),
      'Doc_Mobile_No_1': _docMobileNo1Ctrl.text.trim(),
      'Doc_Mobile_No_2': _docMobileNo2Ctrl.text.trim(),

      // --- NEW: Pharmacy ---
      'Pharmacy_Name': _phNameCtrl.text.trim(),
      'Pharmacy_Address_1': _phAddr1Ctrl.text.trim(),
      'Pharmacy_Address_2': _phAddr2Ctrl.text.trim(),
      'Pharmacy_Landmark': _phLandmarkCtrl.text.trim(),
      'Pharmacy_Pin_Code': _phPinCtrl.text.trim(),
      'Pharmacy_Person_Name': _phPersonNameCtrl.text.trim(),
      'Pharmacy_Mobile_No_1': _phMobile1Ctrl.text.trim(),
      'Pharmacy_Mobile_No_2': _phMobile2Ctrl.text.trim(),

      // --- NEW: GST / Status / Business / Visit ---
      'GST_Number': _gstNumberCtrl.text.trim().toUpperCase(),
      'Status': (_statusValue == '(blank)') ? '' : (_statusValue ?? ''),
      'Visit_Days': (_visitDaysValue == '(blank)')
          ? ''
          : (_visitDaysValue ?? ''),

      'BUSINESS_SLAB': '',

        'BUSINESS_CAT': '',
      'VISIT_FREQUENCY_In_Days': _visitFreqDaysCtrl.text.trim(),

      // Meta
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await _db.ref('Clients/$customerKey').set(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client saved successfully')),
      );
      Navigator.of(context).pop(true); // return to list & refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Client')),
        body: Center(child: Text(_error!)),
        bottomNavigationBar: CommonFooter(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CommonHeader(
                  pageTitle: 'New Client',
                  userName: widget.salesPersonName ?? '',
                ),
                const SizedBox(height: 12),
                // ---- Hierarchy: Region > Area > Sub-Area ----
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                        ),

                        value: (_selectedRegionId ?? '').isEmpty
                            ? null
                            : _selectedRegionId,

                        items: _lr
                            ? const []
                            : (_er != null ? const [] : _regionItemsR()),
                        onChanged: _onRegionChanged,

                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Select Region' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Area',
                          border: OutlineInputBorder(),
                        ),

                        value: (_selectedAreaId ?? '').isEmpty
                            ? null
                            : _selectedAreaId,

                        items: _la
                            ? const []
                            : (_ea != null ? const [] : _areaItemsR()),
                        onChanged: _onAreaChanged,

                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Select Area' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'SubArea',
                    border: OutlineInputBorder(),
                  ),

                  value: (_selectedSubareaId ?? '').isEmpty
                      ? null
                      : _selectedSubareaId,

                  items: _ls
                      ? const []
                      : (_es != null ? const [] : _subAreaItemsR()),
                  onChanged: _onSubareaChanged,

                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select Sub-Area' : null,
                ),

                const SizedBox(height: 16),

                // ---- Sales Person (derived) ----
                TextFormField(
                  controller: _salesPersonNameCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Sales Person',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // ---- Category ----
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),

                  value: _selectedCategoryName,
                  items: _categoryItems(),
                  onChanged: _onCategoryChanged,

                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select Category' : null,
                ),

                const SizedBox(height: 16),

                // ---- Institution basic ----
                TextFormField(
                  controller: _clientNameCtrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Institution Name',
                    border: OutlineInputBorder(),
                  ),

                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter Institution Name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address1Ctrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Address 1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address2Ctrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Address 2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pinCodeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits6(),
                  decoration: const InputDecoration(
                    labelText: 'Pincode',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Contact Person Section 1 ----
                _SectionHeader(title: 'Contact Person / Doctor #1'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contact1NameCtrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Contact Person/Doctor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contact1PhoneCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits10(),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    TextFormField(
                      controller: _contact1WhatsappCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: _digits10(),
                      decoration: const InputDecoration(
                        labelText: 'Whatsapp Number',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.only(left: 12, right: 50, top: 12, bottom: 12),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: () {
                          if (_contact1PhoneCtrl.text.trim().isEmpty) {
                            setState(() => _contact1WhatsappError = true);
                          } else {
                            setState(() {
                              _contact1WhatsappCtrl.text = _contact1PhoneCtrl.text;
                              _contact1WhatsappError = false;
                            });
                          }
                        },
                        child: const Tooltip(
                          message: 'Copy phone number',
                          child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_contact1WhatsappError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'FILL PHONE NUMBER FIRST',
                      style: TextStyle(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),

                const SizedBox(height: 20),

                // ---- Contact Person Section 2 ----
                _SectionHeader(title: 'Contact Person / Doctor #2'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contact2NameCtrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Contact Person/Doctor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contact2PhoneCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits10(),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    TextFormField(
                      controller: _contact2WhatsappCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: _digits10(),
                      decoration: const InputDecoration(
                        labelText: 'Whatsapp Number',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.only(left: 12, right: 50, top: 12, bottom: 12),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: () {
                          if (_contact2PhoneCtrl.text.trim().isEmpty) {
                            setState(() => _contact2WhatsappError = true);
                          } else {
                            setState(() {
                              _contact2WhatsappCtrl.text = _contact2PhoneCtrl.text;
                              _contact2WhatsappError = false;
                            });
                          }
                        },
                        child: const Tooltip(
                          message: 'Copy phone number',
                          child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_contact2WhatsappError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'FILL PHONE NUMBER FIRST',
                      style: TextStyle(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),

                const SizedBox(height: 16),

                // ---- Doctor ----
                _SectionHeader(title: 'Doctor'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _docNameCtrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Doc Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _docMobileNo1Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits10(),
                        decoration: const InputDecoration(
                          labelText: 'Doc Mobile No 1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _docMobileNo2Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits10(),
                        decoration: const InputDecoration(
                          labelText: 'Doc Mobile No 2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ---- Institution / Clinic ----
                _SectionHeader(title: 'Institution / Clinic'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instNameCtrl,
                  inputFormatters: _limit30(),

                  decoration: const InputDecoration(
                    labelText: 'Institution Or Clinic Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instAddr1Ctrl,
                  inputFormatters: _limit30(),

                  decoration: const InputDecoration(
                    labelText: 'Institution Or Clinic Address 1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instAddr2Ctrl,
                  inputFormatters: _limit30(),

                  decoration: const InputDecoration(
                    labelText: 'Institution Or ClinicAddress 2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instLandmarkCtrl,
                  inputFormatters: _limit30(),

                  decoration: const InputDecoration(
                    labelText: 'Institution Or Clinic Landmark',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instPincodeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits6(),

                  decoration: const InputDecoration(
                    labelText: 'Institution Or Clinic Pincode',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // ---- Pharmacy ----
                _SectionHeader(title: 'Pharmacy'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phNameCtrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phAddr1Ctrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Address 1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phAddr2Ctrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Address 2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phLandmarkCtrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Landmark',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phPinCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits6(),
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Pincode',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phPersonNameCtrl,
                  inputFormatters: _limit30(),
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Person Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phMobile1Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits10(),
                        decoration: const InputDecoration(
                          labelText: 'Pharmacy Mobile No 1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phMobile2Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: _digits10(),
                        decoration: const InputDecoration(
                          labelText: 'PharmacyMobileNo2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ---- GST / Status / Visit / Business ----
                _SectionHeader(title: 'Business & Status'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _gstNumberCtrl,
                  inputFormatters: _gstAlnum15(),
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'GstNumber',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),

                  value: _statusValue,
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'Prospect',
                      child: Text('Prospect'),
                    ),
                    DropdownMenuItem(value: 'Hot', child: Text('Hot')),
                    DropdownMenuItem(value: 'Warm', child: Text('Warm')),
                    DropdownMenuItem(value: 'Cold', child: Text('Cold')),
                    DropdownMenuItem(value: 'NA', child: Text('NA')),
                  ],
                  onChanged: (v) => setState(() => _statusValue = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Visit Days',
                    border: OutlineInputBorder(),
                  ),

                  value: _visitDaysValue,
                  items: const [
                    DropdownMenuItem(value: 'MON', child: Text('MON')),
                    DropdownMenuItem(value: 'TUE', child: Text('TUE')),
                    DropdownMenuItem(value: 'WED', child: Text('WED')),
                    DropdownMenuItem(value: 'THU', child: Text('THU')),
                    DropdownMenuItem(value: 'FRI', child: Text('FRI')),
                    DropdownMenuItem(value: 'SAT', child: Text('SAT')),
                    DropdownMenuItem(value: 'SUN', child: Text('SUN')),
                    DropdownMenuItem(value: '', child: Text('')),
                  ],
                  onChanged: (v) => setState(() => _visitDaysValue = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _visitFreqDaysCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits3(),

                  decoration: const InputDecoration(
                    labelText: 'Visit Frequency In Days',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // ---- Dates ----
                Row(
                  children: [
                    Expanded(
                      child: _DateBox(
                        label: 'Date Of First Call',
                        value: _dateOfFirstCall == null
                            ? ''
                            : _dateOfFirstCall!
                                  .toIso8601String()
                                  .split('T')
                                  .first,

                        onTap: _pickDateOfFirstCall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateBox(
                        label: 'Opening Month',
                        value: _formatMonthYear(_openingMonth),
                        onTap: _pickOpeningMonth,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DateBox(
                  label: 'DateOfOpening',

                  value: _dateOfOpening == null
                      ? ''
                      : _dateOfOpening!.toIso8601String().split('T').first,
                  onTap: _pickDateOfOpening,
                ),

                const SizedBox(height: 16),

                // ---- Generated (read-only) ----
                TextFormField(
                  controller: _customerCodeCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Customer Code',
                    border: OutlineInputBorder(),

                    helperText:
                        'Auto: Area(3) + CategoryCode + 6-digit Customer_ID',
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Save Client'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Small helpers ----------
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),

        child: Row(
          children: [
            Expanded(child: Text(value.isEmpty ? 'Select' : value)),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}
