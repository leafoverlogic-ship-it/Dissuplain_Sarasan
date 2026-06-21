import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  String? _error;

  // new user form
  final _idCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _roleCtl = TextEditingController();
  final _reportingCtl = TextEditingController();
  final _regionCtl = TextEditingController();
  final _areaCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenUsers();
  }

  @override
  void dispose() {
    _idCtl.dispose();
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _roleCtl.dispose();
    _reportingCtl.dispose();
    _regionCtl.dispose();
    _areaCtl.dispose();
    super.dispose();
  }

  void _listenUsers() {
    _db
        .ref('Users')
        .onValue
        .listen(
          (event) {
            final v = event.snapshot.value;
            final out = <Map<String, dynamic>>[];

            bool parseDisabled(dynamic raw) {
              if (raw is bool) return raw;
              if (raw is num) return raw != 0;
              if (raw is String) {
                final value = raw.trim().toLowerCase();
                return value == 'true' || value == '1' || value == 'yes' || value == 'disabled';
              }
              return false;
            }

            void addUser(Map<dynamic, dynamic> m, String key) {
              final id = (m['SalesPersonID'] ?? '').toString();
              if (id.isEmpty) return;

              out.add({
                'SalesPersonID': id,
                'SalesPersonName': (m['SalesPersonName'] ?? '').toString(),
                'phoneNumber': (m['phoneNumber'] ?? '').toString(),
                'emailAddress': (m['emailAddress'] ?? '').toString(),
                'loginPwd': (m['loginPwd'] ?? '').toString(),
                'salesPersonRoleID': (m['salesPersonRoleID'] ?? '').toString(),
                'ReportingPersonID': (m['ReportingPersonID'] ?? '').toString(),
                'regionID': (m['regionID'] ?? m['RegionID'] ?? m['assignedRegionID'] ?? '').toString(),
                'areaID': (m['areaID'] ?? m['AreaID'] ?? m['assignedAreaID'] ?? '').toString(),
                'disabled': parseDisabled(m['disabled']),
                '_key': key,
              });
            }

            if (v is Map) {
              v.forEach((key, val) {
                if (val is Map) addUser(Map<String, dynamic>.from(val), key.toString());
              });
            } else if (v is List) {
              for (int i = 0; i < v.length; i++) {
                final val = v[i];
                if (val is Map) addUser(Map<String, dynamic>.from(val), i.toString());
              }
            }

            out.sort(
              (a, b) => a['SalesPersonName'].toString().toLowerCase().compareTo(
                b['SalesPersonName'].toString().toLowerCase(),
              ),
            );
            setState(() {
              _users = out;
              _loading = false;
              _error = null;
            });
          },
          onError: (e) {
            setState(() {
              _error = '$e';
              _loading = false;
            });
          },
        );
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final id = user['SalesPersonID']?.toString() ?? '';
    if (id.isEmpty) return;

    final data = Map<String, dynamic>.from(user);
    data.remove('_key');
    await _db.ref('Users').child(id).set(data);
  }

  Future<void> _updateUser(String key, Map<String, dynamic> delta) async {
    final dbKey = key.trim().isNotEmpty ? key : '';
    if (dbKey.isEmpty) return;

    await _db.ref('Users').child(dbKey).update(delta);
  }

  Future<Map<String, String>> _resolveRoleOneTerritory(String rawRegion, String rawArea) async {
    final regionLookup = <String, String>{};
    final areaLookup = <String, String>{};

    Future<void> loadRegions() async {
      final snap = await _db.ref('Regions').get();
      final v = snap.value;
      void add(dynamic raw, String fallbackKey) {
        if (raw is Map) {
          final id = (raw['regionID'] ?? raw['regionId'] ?? raw['RegionID'] ?? raw['RegionId'] ?? fallbackKey).toString().trim();
          final name = (raw['regionName'] ?? raw['RegionName'] ?? raw['name'] ?? raw['Name'] ?? '').toString().trim();
          if (id.isNotEmpty) {
            regionLookup[id.toLowerCase()] = id;
            if (name.isNotEmpty) regionLookup[name.toLowerCase()] = id;
          }
        }
      }

      if (v is Map) {
        v.forEach((k, raw) => add(raw, k.toString()));
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) add(v[i], i.toString());
      }
    }

    Future<void> loadAreas() async {
      final snap = await _db.ref('Areas').get();
      final v = snap.value;
      void add(dynamic raw, String fallbackKey) {
        if (raw is Map) {
          final id = (raw['areaID'] ?? raw['areaId'] ?? raw['AreaID'] ?? raw['AreaId'] ?? fallbackKey).toString().trim();
          final name = (raw['areaName'] ?? raw['AreaName'] ?? raw['name'] ?? raw['Name'] ?? '').toString().trim();
          if (id.isNotEmpty) {
            areaLookup[id.toLowerCase()] = id;
            if (name.isNotEmpty) areaLookup[name.toLowerCase()] = id;
          }
        }
      }

      if (v is Map) {
        v.forEach((k, raw) => add(raw, k.toString()));
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) add(v[i], i.toString());
      }
    }

    await Future.wait([loadRegions(), loadAreas()]);

    final resolvedRegion = regionLookup[rawRegion.trim().toLowerCase()] ?? rawRegion.trim();
    final resolvedArea = areaLookup[rawArea.trim().toLowerCase()] ?? rawArea.trim();

    return {
      'regionID': resolvedRegion,
      'areaID': resolvedArea,
    };
  }

  Future<void> _createNewUser() async {
    final id = _idCtl.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SalesPersonID is required')),
      );
      return;
    }
    final name = _nameCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final email = _emailCtl.text.trim();
    final role = _roleCtl.text.trim();
    final reporting = _reportingCtl.text.trim();
    final data = {
      'SalesPersonID': id,
      'SalesPersonName': name,
      'phoneNumber': phone,
      'emailAddress': email,
      'salesPersonRoleID': role,
      'ReportingPersonID': reporting,
      'loginPwd': 'Welcome@123',
      'disabled': false,
    };
    if (role == '1') {
      final regionText = _regionCtl.text.trim();
      final areaText = _areaCtl.text.trim();
      if (regionText.isNotEmpty || areaText.isNotEmpty) {
        final resolved = await _resolveRoleOneTerritory(regionText, areaText);
        if (regionText.isNotEmpty) data['regionID'] = resolved['regionID'] ?? '';
        if (areaText.isNotEmpty) data['areaID'] = resolved['areaID'] ?? '';
      }
    }
    await _saveUser(data);
    _idCtl.clear();
    _nameCtl.clear();
    _phoneCtl.clear();
    _emailCtl.clear();
    _roleCtl.clear();
    _reportingCtl.clear();
    _regionCtl.clear();
    _areaCtl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created with default password Welcome@123'),
        ),
      );
    }
  }

  Widget _userCard(Map<String, dynamic> u) {
    final id = (u['SalesPersonID'] ?? '').toString();
    final dbKey = (u['_key'] ?? id).toString();
    final nameCtl = TextEditingController(text: u['SalesPersonName'] ?? '');
    final phoneCtl = TextEditingController(text: u['phoneNumber'] ?? '');
    final emailCtl = TextEditingController(text: u['emailAddress'] ?? '');
    final roleCtl = TextEditingController(text: u['salesPersonRoleID'] ?? '');
    final reportingCtl = TextEditingController(
      text: u['ReportingPersonID'] ?? '',
    );
    final regionCtl = TextEditingController(
      text: (u['regionID'] ?? u['RegionID'] ?? u['assignedRegionID'] ?? '').toString(),
    );
    final areaCtl = TextEditingController(
      text: (u['areaID'] ?? u['AreaID'] ?? u['assignedAreaID'] ?? '').toString(),
    );
    final passwordCtl = TextEditingController(text: (u['loginPwd'] ?? '').toString());
    final disabled = u['disabled'] == true;
    final roleIsOne = roleCtl.text.trim() == '1';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      elevation: 4,
      color: const Color(0xFFE0F2F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF26A69A), width: 1.2),
      ),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F2F1),
              Color(0xFFB2DFDB),
            ],
          ),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$id',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    Switch(
                      value: disabled,
                      onChanged: (v) async {
                        await _updateUser(dbKey, {'disabled': v});
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(disabled ? 'Disabled' : 'Enabled'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _fieldRow('Name', nameCtl),
            _fieldRow('Phone', phoneCtl, keyboardType: TextInputType.phone),
            _fieldRow(
              'Email',
              emailCtl,
              keyboardType: TextInputType.emailAddress,
            ),
            _fieldRow('Role ID', roleCtl),
            _fieldRow('Reporting Person ID', reportingCtl),
            _fieldRow('Password', passwordCtl, enabled: false),
            if (roleIsOne) ...[
              _fieldRow('Region ID', regionCtl),
              _fieldRow('Area ID', areaCtl),
            ],
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final update = <String, dynamic>{
                      'SalesPersonName': nameCtl.text.trim(),
                      'phoneNumber': phoneCtl.text.trim(),
                      'emailAddress': emailCtl.text.trim(),
                      'salesPersonRoleID': roleCtl.text.trim(),
                      'ReportingPersonID': reportingCtl.text.trim(),
                    };
                    if (roleCtl.text.trim() == '1') {
                      final regionText = regionCtl.text.trim();
                      final areaText = areaCtl.text.trim();
                      if (regionText.isNotEmpty || areaText.isNotEmpty) {
                        final resolved = await _resolveRoleOneTerritory(regionText, areaText);
                        if (regionText.isNotEmpty) update['regionID'] = resolved['regionID'] ?? '';
                        if (areaText.isNotEmpty) update['areaID'] = resolved['areaID'] ?? '';
                      }
                    }
                    await _updateUser(dbKey, update);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User updated')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    await _updateUser(dbKey, {'loginPwd': 'Welcome@123'});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset to Welcome@123'),
                        ),
                      );
                    }
                  },
                  child: const Text('Reset Password'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(
    String label,
    TextEditingController ctl, {
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctl,
              keyboardType: keyboardType,
              enabled: enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: CommonFooter(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CommonHeader(pageTitle: 'User Management'),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New User',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _idCtl,
                          decoration: const InputDecoration(
                            labelText: 'SalesPersonID',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _nameCtl,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _phoneCtl,
                          decoration: const InputDecoration(labelText: 'Phone'),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _emailCtl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _roleCtl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Role ID',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _reportingCtl,
                          decoration: const InputDecoration(
                            labelText: 'Reporting Person ID',
                          ),
                        ),
                      ),
                      if (_roleCtl.text.trim() == '1') ...[
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _regionCtl,
                            decoration: const InputDecoration(
                              labelText: 'Region ID',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _areaCtl,
                            decoration: const InputDecoration(
                              labelText: 'Area ID',
                            ),
                          ),
                        ),
                      ],
                      if (_roleCtl.text.trim() == '1') ...[
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _regionCtl,
                            decoration: const InputDecoration(
                              labelText: 'Region ID',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _areaCtl,
                            decoration: const InputDecoration(
                              labelText: 'Area ID',
                            ),
                          ),
                        ),
                      ],
                      ElevatedButton(
                        onPressed: _createNewUser,
                        child: const Text('Create (pwd: Welcome@123)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : ListView(children: _users.map(_userCard).toList()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
