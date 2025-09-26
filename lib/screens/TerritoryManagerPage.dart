// TerritoryManagerPage_FIXED.dart
// Territory management page (Option A) with nested Region -> Area -> Subarea cards.
// Fixes:
// - Role-tolerant user mapping & populated RM (>=3), AM (>=2), SE (>=1) dropdowns
// - Incremental numeric IDs for Regions/Areas/SubAreas (max + 1)
// - regionalManagerID set to '' on create if none selected
// - Region deletion disabled (rename OK)
// - Mobile-friendly width constraint
//
// Firebase Realtime Database structure assumed:
// Regions/{regionId} : { regionId, regionName, regionalManagerID? }
// Areas/{areaID}     : { areaID, areaName, regionId, areaManagerID? }
// SubAreas/{subareaID}: { subareaID, subareaName, areaID, regionId, assignedSE? }
// Users/{userID}     : { userID, SalesPersonID?, SalesPersonName/name/displayName, RoleID/roleId/role }
//
// NOTE: Replace AppCommonHeader/AppCommonFooter with your shared widgets if desired.

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';

class TerritoryManagerPage extends StatefulWidget {
  const TerritoryManagerPage({super.key});

  @override
  State<TerritoryManagerPage> createState() => _TerritoryManagerPageState();
}

class _TerritoryManagerPageState extends State<TerritoryManagerPage> {
  // Live in-memory lists
  List<_Region> _regions = [];
  List<_Area> _areas = [];
  List<_Subarea> _subareas = [];
  List<_UserRow> _users = [];

  // Role-filtered buckets for assignments (tolerant >= thresholds)
  List<_UserRow> get _rms => _users.where((u) => (u.roleId ?? 0) >= 3).toList();
  List<_UserRow> get _ams => _users.where((u) => (u.roleId ?? 0) >= 2).toList();
  List<_UserRow> get _ses => _users.where((u) => (u.roleId ?? 0) >= 1).toList();

  String _q = '';

  @override
  void initState() {
    super.initState();
    _listenData();
  }

  void _listenData() {
    final db = FirebaseDatabase.instance;

    db.ref('Regions').onValue.listen((e) {
      final items = <_Region>[];
      for (final c in e.snapshot.children) {
        final m = (c.value ?? {}) as Map;
        items.add(
          _Region.fromMap(Map<String, dynamic>.from(m), idFallback: c.key),
        );
      }
      items.sort(
        (a, b) =>
            a.regionName.toLowerCase().compareTo(b.regionName.toLowerCase()),
      );
      if (mounted) setState(() => _regions = items);
    });

    db.ref('Areas').onValue.listen((e) {
      final items = <_Area>[];
      for (final c in e.snapshot.children) {
        final m = (c.value ?? {}) as Map;
        items.add(
          _Area.fromMap(Map<String, dynamic>.from(m), idFallback: c.key),
        );
      }
      items.sort(
        (a, b) => a.areaName.toLowerCase().compareTo(b.areaName.toLowerCase()),
      );
      if (mounted) setState(() => _areas = items);
    });

    db.ref('SubAreas').onValue.listen((e) {
      final items = <_Subarea>[];
      for (final c in e.snapshot.children) {
        final m = (c.value ?? {}) as Map;
        items.add(
          _Subarea.fromMap(Map<String, dynamic>.from(m), idFallback: c.key),
        );
      }
      items.sort(
        (a, b) =>
            a.subareaName.toLowerCase().compareTo(b.subareaName.toLowerCase()),
      );
      if (mounted) setState(() => _subareas = items);
    });

    db.ref('Users').onValue.listen((e) {
      final items = <_UserRow>[];
      for (final c in e.snapshot.children) {
        final m = (c.value ?? {}) as Map;
        items.add(
          _UserRow.fromMap(Map<String, dynamic>.from(m), idFallback: c.key),
        );
      }
      if (mounted) setState(() => _users = items);
    });
  }

  List<_Region> get _filteredRegions {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _regions;
    final regIds = <String>{};
    for (final r in _regions) {
      if (r.regionName.toLowerCase().contains(q)) regIds.add(r.regionId);
    }
    for (final a in _areas) {
      if (a.areaName.toLowerCase().contains(q)) regIds.add(a.regionId);
    }
    for (final s in _subareas) {
      if (s.subareaName.toLowerCase().contains(q)) regIds.add(s.regionId);
    }
    return _regions.where((r) => regIds.contains(r.regionId)).toList();
  }

  final BoxConstraints _kBtnConstraints = BoxConstraints.tightFor(
    width: 32,
    height: 32,
  );

  IconButton _editBtn(VoidCallback onPressed) => IconButton(
    icon: const Icon(Icons.edit, size: 18),
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: _kBtnConstraints,
    tooltip: 'Edit',
  );

  IconButton _checkBtn(VoidCallback onPressed) => IconButton(
    icon: const Icon(Icons.check, size: 18),
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: _kBtnConstraints,
    tooltip: 'Save',
  );

  IconButton _closeBtn(VoidCallback onPressed) => IconButton(
    icon: const Icon(Icons.close, size: 18),
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: _kBtnConstraints,
    tooltip: 'Cancel',
  );

  Widget _checkIcon({required VoidCallback onPressed}) {
    return IconButton(
      icon: const Icon(Icons.check),
      onPressed: onPressed,
      iconSize: 18,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      tooltip: 'Save',
    );
  }

  Widget _closeIcon({required VoidCallback onPressed}) {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: onPressed,
      iconSize: 18,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      tooltip: 'Cancel',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppCommonHeader(title: 'Territory Manager'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 640,
          ), // mobile-friendly width
          child: Column(
            children: [
              _toolbar(),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: _filteredRegions.map((r) {
                    final areas = _areas
                        .where((a) => a.regionId == r.regionId)
                        .toList();
                    return _RegionCard(
                      region: r,
                      areas: areas,
                      subareas: _subareas,
                      rms: _rms,
                      ams: _ams,
                      ses: _ses,
                      onRenameRegion: (name) =>
                          _saveRegion(r.copyWith(regionName: name)),
                      onAssignRM: (userId) => _saveRegion(
                        r.copyWith(regionalManagerID: userId ?? ''),
                      ),
                      onAddArea: () => _createArea(r),
                      // Region delete disabled per requirement: pass no-op
                      onRenameArea: (a, name) =>
                          _saveArea(a.copyWith(areaName: name)),
                      onAssignAM: (a, userId) =>
                          _saveArea(a.copyWith(areaManagerID: userId ?? '')),
                      onAddSubarea: (a) => _createSubarea(a),
                      onRenameSubarea: (s, name) =>
                          _saveSubarea(s.copyWith(subareaName: name)),
                      onAssignSE: (s, seId) =>
                          _saveSubarea(s.copyWith(assignedSE: seId ?? '')),
                    );
                  }).toList(),
                ),
              ),
              const AppCommonFooter(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRegion,
        icon: const Icon(Icons.add),
        label: const Text('Add Region'),
      ),
    );
  }

  Widget _toolbar() => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search region / area / subarea',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
      ],
    ),
  );

  // ---------- ID helpers: compute next incremental numeric id (max + 1) ----------

  Future<String> _nextNumericId(
    DatabaseReference ref,
    String idFieldName,
  ) async {
    // Read all children and compute max numeric id from child[idFieldName] or key
    final snap = await ref.get();
    int maxId = 0;
    if (snap.exists) {
      for (final c in snap.children) {
        dynamic raw;
        if (c.value is Map) {
          final m = Map<String, dynamic>.from(c.value as Map);
          raw =
              m[idFieldName] ??
              m[idFieldName[0].toUpperCase() + idFieldName.substring(1)] ??
              c.key;
        } else {
          raw = c.key;
        }
        final n = int.tryParse((raw ?? '').toString());
        if (n != null && n > maxId) maxId = n;
      }
    }
    return (maxId + 1).toString();
  }

  // ---------- CRUD helpers (Firebase) ----------

  Future<void> _createRegion() async {
    final name = await _promptName(context, 'New Region name');
    if (name == null || name.trim().isEmpty) return;
    final ref = FirebaseDatabase.instance.ref('Regions');
    final newId = await _nextNumericId(ref, 'regionId');
    await ref.child(newId).set({
      'regionId': newId,
      'regionName': name.trim(),
      'regionalManagerID': '', // default blank
    });
  }

  Future<void> _saveRegion(_Region r) async {
    await FirebaseDatabase.instance.ref('Regions/${r.regionId}').update({
      'regionName': r.regionName,
      'regionalManagerID': r.regionalManagerID ?? '',
    });
  }

  // Region deletion disabled per requirement
  Future<void> _deleteRegion(_Region r) async {
    // intentionally no-op
    _snack('Deleting regions is not allowed.');
  }

  Future<void> _createArea(_Region r) async {
    final name = await _promptName(
      context,
      'New Area name (Region: ${r.regionName})',
    );
    if (name == null || name.trim().isEmpty) return;
    final ref = FirebaseDatabase.instance.ref('Areas');
    final newId = await _nextNumericId(ref, 'areaID');
    await ref.child(newId).set({
      'areaID': newId,
      'areaName': name.trim(),
      'regionId': r.regionId,
      'areaManagerUserID': '', // default blank
    });
  }

  Future<void> _saveArea(_Area a) async {
    await FirebaseDatabase.instance.ref('Areas/${a.areaID}').update({
      'areaName': a.areaName,
      'regionId': a.regionId,
      'areaManagerUserID': a.areaManagerID ?? '',
    });
  }

  Future<void> _deleteArea(_Area a) async {
    final subsExist = _subareas.any((s) => s.areaID == a.areaID);
    if (subsExist) {
      _snack('Cannot delete area with existing subareas.');
      return;
    }
    await FirebaseDatabase.instance.ref('Areas/${a.areaID}').remove();
  }

  Future<void> _createSubarea(_Area a) async {
    final name = await _promptName(
      context,
      'New Subarea name (Area: ${a.areaName})',
    );
    if (name == null || name.trim().isEmpty) return;
    final ref = FirebaseDatabase.instance.ref('SubAreas');
    final newId = await _nextNumericId(ref, 'subareaID');
    await ref.child(newId).set({
      'subareaID': newId,
      'subareaName': name.trim(),
      'areaID': a.areaID,
      'regionId': a.regionId, // denormalized for fast queries
      'assignedSE': '', // default blank
    });
  }

  Future<void> _saveSubarea(_Subarea s) async {
    await FirebaseDatabase.instance.ref('SubAreas/${s.subareaID}').update({
      'subareaName': s.subareaName,
      'areaID': s.areaID,
      'regionId': s.regionId,
      'assignedSE': s.assignedSE ?? '',
    });
  }

  // ---------- UI utilities ----------

  Future<String?> _promptName(
    BuildContext context,
    String title, {
    String initialValue = '',
  }) async {
    final ctl = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ---------- Cards ----------

class _RegionCard extends StatefulWidget {
  final _Region region;
  final List<_Area> areas; // all areas (we filter inside)
  final List<_Subarea> subareas; // all subareas (passed down)
  final List<_UserRow> rms, ams, ses;

  final Future<void> Function(String newName) onRenameRegion;
  final Future<void> Function(String? userId) onAssignRM;
  final Future<void> Function() onAddArea;

  final Future<void> Function(_Area area, String newName) onRenameArea;
  final Future<void> Function(_Area area, String? userId) onAssignAM;
  final Future<void> Function(_Area area) onAddSubarea;

  final Future<void> Function(_Subarea s, String newName) onRenameSubarea;
  final Future<void> Function(_Subarea s, String? seId) onAssignSE;

  const _RegionCard({
    required this.region,
    required this.areas,
    required this.subareas,
    required this.rms,
    required this.ams,
    required this.ses,
    required this.onRenameRegion,
    required this.onAssignRM,
    required this.onAddArea,
    required this.onRenameArea,
    required this.onAssignAM,
    required this.onAddSubarea,
    required this.onRenameSubarea,
    required this.onAssignSE,
    super.key,
  });

  @override
  State<_RegionCard> createState() => _RegionCardState();
}

final BoxConstraints _kBtnConstraints = BoxConstraints.tightFor(
  width: 32,
  height: 32,
);

IconButton _editBtn(VoidCallback onPressed) => IconButton(
  icon: const Icon(Icons.edit, size: 18),
  onPressed: onPressed,
  padding: EdgeInsets.zero,
  visualDensity: VisualDensity.compact,
  constraints: _kBtnConstraints,
  tooltip: 'Edit',
);

IconButton _checkBtn(VoidCallback onPressed) => IconButton(
  icon: const Icon(Icons.check, size: 18),
  onPressed: onPressed,
  padding: EdgeInsets.zero,
  visualDensity: VisualDensity.compact,
  constraints: _kBtnConstraints,
  tooltip: 'Save',
);

IconButton _closeBtn(VoidCallback onPressed) => IconButton(
  icon: const Icon(Icons.close, size: 18),
  onPressed: onPressed,
  padding: EdgeInsets.zero,
  visualDensity: VisualDensity.compact,
  constraints: _kBtnConstraints,
  tooltip: 'Cancel',
);

Widget _checkIcon({required VoidCallback onPressed}) {
  return IconButton(
    icon: const Icon(Icons.check),
    onPressed: onPressed,
    iconSize: 18,
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    tooltip: 'Save',
  );
}

Widget _closeIcon({required VoidCallback onPressed}) {
  return IconButton(
    icon: const Icon(Icons.close),
    onPressed: onPressed,
    iconSize: 18,
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    tooltip: 'Cancel',
  );
}

class _RegionCardState extends State<_RegionCard> {
  bool _hoverName = false;
  bool _hoverMgr = false;
  bool _editingName = false;
  bool _editingMgr = false;
  final _nameCtl = TextEditingController();
  String? _pendingMgr;

  @override
  void initState() {
    super.initState();
    _nameCtl.text = widget.region.regionName;
    _pendingMgr = widget.region.regionalManagerID;
  }

  @override
  void didUpdateWidget(covariant _RegionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // keep controllers in sync if external changes happen
    if (!_editingName) _nameCtl.text = widget.region.regionName;
    if (!_editingMgr) _pendingMgr = widget.region.regionalManagerID;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    // Filter areas that belong to this region (this fixes the "blank on expand")
    final areasOfRegion =
        widget.areas.where((a) => a.regionId == region.regionId).toList()..sort(
          (a, b) =>
              a.areaName.toLowerCase().compareTo(b.areaName.toLowerCase()),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 1,
      child: ExpansionTile(
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // REGION NAME (hover to edit)
            MouseRegion(
              onEnter: (_) => setState(() => _hoverName = true),
              onExit: (_) => setState(() => _hoverName = false),
              child: Row(
                children: [
                  const Text(
                    'REGION  ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (_editingName)
                    Expanded(
                      child: TextField(
                        controller: _nameCtl,
                        autofocus: true,
                        onSubmitted: (v) async {
                          setState(() => _editingName = false);
                          await widget.onRenameRegion(v.trim());
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        widget.region.regionName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_editingName) ...[
                    _checkBtn(() async {
                      setState(() => _editingName = false);
                      await widget.onRenameRegion(_nameCtl.text.trim());
                    }),
                    _closeBtn(() {
                      setState(() {
                        _editingName = false;
                        _nameCtl.text = widget.region.regionName; // revert
                      });
                    }),
                  ] else
                    _editBtn(() => setState(() => _editingName = true)),
                  // keep your existing "Add Area" icon/button after this, unchanged
                ],
              ),
            ),
            const SizedBox(height: 4),
            // REGIONAL MANAGER (hover to edit -> dropdown + check)
            MouseRegion(
              onEnter: (_) => setState(() => _hoverMgr = true),
              onExit: (_) => setState(() => _hoverMgr = false),
              child: Row(
                children: [
                  const Text(
                    'Regional Manager: ',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (_editingMgr)
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: (_pendingMgr?.isEmpty ?? true)
                                  ? null
                                  : _pendingMgr,
                              items: widget.rms
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u
                                          .salesPersonID, // shows name, stores ID
                                      child: Text(u.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _pendingMgr = v),
                              isDense: true,
                            ),
                          ),
                          _checkBtn(() async {
                            setState(() => _editingMgr = false);
                            await widget.onAssignRM(_pendingMgr ?? '');
                          }),
                          _closeBtn(() {
                            setState(() {
                              _editingMgr = false;
                              _pendingMgr =
                                  widget.region.regionalManagerID; // revert
                            });
                          }),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        widget.rms
                            .firstWhere(
                              (u) =>
                                  u.salesPersonID ==
                                  (widget.region.regionalManagerID ?? ''),
                              orElse: () => _UserRow(
                                salesPersonID: '',
                                displayName: '',
                                userID: '0',
                              ),
                            )
                            .displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  _editBtn(() => setState(() => _editingMgr = true)),
                ],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Add Area',
              onPressed: widget.onAddArea,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: _kBtnConstraints,
            ),
            const Icon(Icons.expand_more), // keep the arrow
          ],
        ),
        // CHILDREN: AREA CARDS
        children: areasOfRegion
            .map(
              (a) => _AreaCard(
                area: a,
                subareas: widget.subareas,
                ams: widget.ams,
                ses: widget.ses,
                onRenameArea: (name) => widget.onRenameArea(a, name),
                onAssignAM: (userId) => widget.onAssignAM(a, userId),
                onAddSubarea: () => widget.onAddSubarea(a),
                onRenameSubarea: (s, name) => widget.onRenameSubarea(s, name),
                onAssignSE: (s, seId) => widget.onAssignSE(s, seId),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AreaCard extends StatefulWidget {
  final _Area area;
  final List<_Subarea> subareas; // all subareas (we filter inside)
  final List<_UserRow> ams, ses;

  final Future<void> Function(String newName) onRenameArea;
  final Future<void> Function(String? userId) onAssignAM;
  final Future<void> Function() onAddSubarea;

  final Future<void> Function(_Subarea s, String newName) onRenameSubarea;
  final Future<void> Function(_Subarea s, String? seId) onAssignSE;

  const _AreaCard({
    required this.area,
    required this.subareas,
    required this.ams,
    required this.ses,
    required this.onRenameArea,
    required this.onAssignAM,
    required this.onAddSubarea,
    required this.onRenameSubarea,
    required this.onAssignSE,
    super.key,
  });

  @override
  State<_AreaCard> createState() => _AreaCardState();
}

class _AreaCardState extends State<_AreaCard> {
  bool _hoverName = false;
  bool _hoverMgr = false;
  bool _editingName = false;
  bool _editingMgr = false;
  final _nameCtl = TextEditingController();
  String? _pendingMgr;

  @override
  void initState() {
    super.initState();
    _nameCtl.text = widget.area.areaName;
    _pendingMgr = widget.area.areaManagerID;
  }

  @override
  void didUpdateWidget(covariant _AreaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingName) _nameCtl.text = widget.area.areaName;
    if (!_editingMgr) _pendingMgr = widget.area.areaManagerID;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter subareas that belong to this area (fixes "blank on expand")
    final subs =
        widget.subareas.where((s) => s.areaID == widget.area.areaID).toList()
          ..sort(
            (a, b) => a.subareaName.toLowerCase().compareTo(
              b.subareaName.toLowerCase(),
            ),
          );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      elevation: 0,
      child: ExpansionTile(
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AREA NAME (hover to edit)
            MouseRegion(
              onEnter: (_) => setState(() => _hoverName = true),
              onExit: (_) => setState(() => _hoverName = false),
              child: Row(
                children: [
                  const Text(
                    'AREA  ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (_editingName)
                    Expanded(
                      child: TextField(
                        controller: _nameCtl,
                        autofocus: true,
                        onSubmitted: (v) async {
                          setState(() => _editingName = false);
                          await widget.onRenameArea(v.trim());
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        widget.area.areaName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_editingName) ...[
                    _checkBtn(() async {
                      setState(() => _editingName = false);
                      await widget.onRenameArea(_nameCtl.text.trim());
                    }),
                    _closeBtn(() {
                      setState(() {
                        _editingName = false;
                        _nameCtl.text = widget.area.areaName; // revert
                      });
                    }),
                  ] else
                    _editBtn(() => setState(() => _editingName = true)),
                  // keep your existing "Add Subarea" button after this
                ],
              ),
            ),

            const SizedBox(height: 4),
            // AREA MANAGER (hover -> dropdown + check)
            MouseRegion(
              onEnter: (_) => setState(() => _hoverMgr = true),
              onExit: (_) => setState(() => _hoverMgr = false),
              child: Row(
                children: [
                  const Text('Area Manager: ', style: TextStyle(fontSize: 13)),
                  if (_editingMgr)
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: (_pendingMgr?.isEmpty ?? true)
                                  ? null
                                  : _pendingMgr,
                              items: widget.ams
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u.salesPersonID,
                                      child: Text(u.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _pendingMgr = v),
                              isDense: true,
                            ),
                          ),
                          _checkBtn(() async {
                            setState(() => _editingMgr = false);
                            await widget.onAssignAM(_pendingMgr ?? '');
                          }),
                          _closeBtn(() {
                            setState(() {
                              _editingMgr = false;
                              _pendingMgr = widget.area.areaManagerID; // revert
                            });
                          }),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        widget.ams
                            .firstWhere(
                              (u) =>
                                  u.salesPersonID ==
                                  (widget.area.areaManagerID ?? ''),
                              orElse: () => _UserRow(
                                salesPersonID: '',
                                displayName: '',
                                userID: '0',
                              ),
                            )
                            .displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  _editBtn(() => setState(() => _editingMgr = true)),
                ],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Add Subarea',
              onPressed: widget.onAddSubarea,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: _kBtnConstraints,
            ),
            const Icon(Icons.expand_more),
          ],
        ),

        // CHILDREN: SUBAREA ROWS
        children: subs
            .map(
              (s) => _SubareaRow(
                sub: s,
                ses: widget.ses,
                onRename: (name) => widget.onRenameSubarea(s, name),
                onAssignSE: (v) => widget.onAssignSE(s, v),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SubareaRow extends StatefulWidget {
  final _Subarea sub;
  final List<_UserRow> ses;
  final Future<void> Function(String newName) onRename;
  final Future<void> Function(String? seId) onAssignSE;

  const _SubareaRow({
    required this.sub,
    required this.ses,
    required this.onRename,
    required this.onAssignSE,
    super.key,
  });

  @override
  State<_SubareaRow> createState() => _SubareaRowState();
}

class _SubareaRowState extends State<_SubareaRow> {
  bool _hoverName = false;
  bool _hoverSe = false;
  bool _editingName = false;
  bool _editingSe = false;
  final _nameCtl = TextEditingController();
  String? _pendingSe;

  @override
  void initState() {
    super.initState();
    _nameCtl.text = widget.sub.subareaName;
    _pendingSe = widget.sub.assignedSE;
  }

  @override
  void didUpdateWidget(covariant _SubareaRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingName) _nameCtl.text = widget.sub.subareaName;
    if (!_editingSe) _pendingSe = widget.sub.assignedSE;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // NAME with hover edit
          Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoverName = true),
              onExit: (_) => setState(() => _hoverName = false),
              child: // REPLACE the current "name" section with this:
              Row(
                children: [
                  if (_editingName)
                    Expanded(
                      child: TextField(
                        controller: _nameCtl,
                        autofocus: true,
                        onSubmitted: (v) async {
                          setState(() => _editingName = false);
                          await widget.onRename(v.trim());
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        widget.sub.subareaName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_editingName) ...[
                    _checkBtn(() async {
                      setState(() => _editingName = false);
                      await widget.onRename(_nameCtl.text.trim());
                    }),
                    _closeBtn(() {
                      setState(() {
                        _editingName = false;
                        _nameCtl.text = widget.sub.subareaName; // revert
                      });
                    }),
                  ] else
                    _editBtn(() => setState(() => _editingName = true)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // SE with hover edit -> dropdown + check
          Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoverSe = true),
              onExit: (_) => setState(() => _hoverSe = false),
              child: // REPLACE the current "Sales Executive" section with this:
              Row(
                children: [
                  const Text(
                    'Sales Executive: ',
                    style: TextStyle(fontSize: 13),
                  ),
                  Expanded(
                    child: _editingSe
                        ? Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: (_pendingSe?.isEmpty ?? true)
                                      ? null
                                      : _pendingSe,
                                  items: widget.ses
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u.salesPersonID, // store ID
                                          child: Text(
                                            u.displayName,
                                          ), // show name
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _pendingSe = v),
                                  isDense: true,
                                ),
                              ),
                              _checkBtn(() async {
                                setState(() => _editingSe = false);
                                await widget.onAssignSE(_pendingSe ?? '');
                              }),
                              _closeBtn(() {
                                setState(() {
                                  _editingSe = false;
                                  _pendingSe = widget.sub.assignedSE; // revert
                                });
                              }),
                            ],
                          )
                        : Text(
                            widget.ses
                                .firstWhere(
                                  (u) =>
                                      u.salesPersonID ==
                                      (widget.sub.assignedSE ?? ''),
                                  orElse: () => _UserRow(
                                    userID: '',
                                    salesPersonID: '',
                                    displayName: '',
                                  ),
                                )
                                .displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  if (!_editingSe)
                    _editBtn(() => setState(() => _editingSe = true)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> options;
  final ValueChanged<String?> onChanged;
  const _UserDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: (value == null || value!.isEmpty) ? null : value,
      items: options,
      onChanged: onChanged,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}

// ---------- Common header/footer (replace with your shared widgets if available) ----------

class AppCommonHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const AppCommonHeader({required this.title, super.key});
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) => AppBar(title: Text(title));
}

class AppCommonFooter extends StatelessWidget {
  const AppCommonFooter({super.key});
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    alignment: Alignment.center,
    child: Text('© ${DateTime.now().year}'),
  );
}

// ---------- Data models (local to this page; no app-wide collisions) ----------

String _s(Object? v) => (v?.toString() ?? '').trim();

int? _toInt(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return int.tryParse(s);
}

class _Region {
  final String regionId;
  final String regionName;
  final String? regionalManagerID;
  _Region({
    required this.regionId,
    required this.regionName,
    this.regionalManagerID,
  });
  factory _Region.fromMap(Map<String, dynamic> m, {String? idFallback}) {
    final id = _s(m['regionId'] ?? m['regionId'] ?? idFallback);
    final name = _s(m['regionName'] ?? m['RegionName'] ?? '');
    final rm = _s(m['regionalManagerID'] ?? m['RegionalManagerID'] ?? '');
    return _Region(
      regionId: id,
      regionName: name,
      regionalManagerID: rm.isEmpty ? null : rm,
    );
  }
  _Region copyWith({String? regionName, String? regionalManagerID}) => _Region(
    regionId: regionId,
    regionName: regionName ?? this.regionName,
    regionalManagerID: regionalManagerID ?? this.regionalManagerID,
  );
}

class _Area {
  final String areaID;
  final String areaName;
  final String regionId;
  final String? areaManagerID;
  _Area({
    required this.areaID,
    required this.areaName,
    required this.regionId,
    this.areaManagerID,
  });
  factory _Area.fromMap(Map<String, dynamic> m, {String? idFallback}) {
    final id = _s(m['areaID'] ?? m['AreaID'] ?? idFallback);
    final name = _s(m['areaName'] ?? m['AreaName'] ?? '');
    final rid = _s(m['regionId'] ?? m['regionId'] ?? '');
    final am = _s(
      m['areaManagerUserID'] ?? m['areaManagerID'] ?? m['AreaManagerID'] ?? '',
    );
    return _Area(
      areaID: id,
      areaName: name,
      regionId: rid,
      areaManagerID: am.isEmpty ? null : am,
    );
  }
  _Area copyWith({String? areaName, String? areaManagerID}) => _Area(
    areaID: areaID,
    areaName: areaName ?? this.areaName,
    regionId: regionId,
    areaManagerID: areaManagerID ?? this.areaManagerID,
  );
}

class _Subarea {
  final String subareaID;
  final String subareaName;
  final String areaID;
  final String regionId;
  final String? assignedSE; // SalesPersonID
  _Subarea({
    required this.subareaID,
    required this.subareaName,
    required this.areaID,
    required this.regionId,
    this.assignedSE,
  });
  factory _Subarea.fromMap(Map<String, dynamic> m, {String? idFallback}) {
    final id = _s(m['subareaID'] ?? m['SubAreaID'] ?? idFallback);
    final name = _s(m['subareaName'] ?? m['SubAreaName'] ?? '');
    final aid = _s(m['areaID'] ?? m['AreaID'] ?? '');
    final rid = _s(m['regionId'] ?? m['regionId'] ?? '');
    final se = _s(m['assignedSE'] ?? m['AssignedSE'] ?? '');
    return _Subarea(
      subareaID: id,
      subareaName: name,
      areaID: aid,
      regionId: rid,
      assignedSE: se.isEmpty ? null : se,
    );
  }
  _Subarea copyWith({String? subareaName, String? assignedSE}) => _Subarea(
    subareaID: subareaID,
    subareaName: subareaName ?? this.subareaName,
    areaID: areaID,
    regionId: regionId,
    assignedSE: assignedSE ?? this.assignedSE,
  );
}

class _UserRow {
  final String userID;
  final String? salesPersonID;
  final String displayName;
  final int? roleId;
  _UserRow({
    required this.userID,
    required this.displayName,
    this.salesPersonID,
    this.roleId,
  });
  factory _UserRow.fromMap(Map<String, dynamic> m, {String? idFallback}) {
    final uid = _s(m['userID'] ?? m['UserID'] ?? idFallback);
    final spid = _s(m['SalesPersonID'] ?? m['salesPersonID'] ?? '');
    final name = _s(
      m['SalesPersonName'] ??
          m['salesPersonName'] ??
          m['name'] ??
          m['displayName'] ??
          '',
    );
    final role = _toInt(
      m['salesPersonRoleID'] ??
          m['RoleID'] ??
          m['roleId'] ??
          m['role'] ??
          m['Role_Id'],
    );
    return _UserRow(
      userID: uid,
      displayName: name,
      salesPersonID: spid.isEmpty ? null : spid,
      roleId: role,
    );
  }
}
