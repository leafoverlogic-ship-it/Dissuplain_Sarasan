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
  List<Map<String, dynamic>> _subareasRaw = const [];
  Map<String, String> _regionNameById = const {};
  Map<String, String> _areaNameById = const {};
  Map<String, String> _areaRegionByAreaId = const {};
  Map<String, Set<String>> _regionIdsByUser = const {};
  Map<String, Set<String>> _areaIdsByUser = const {};
  bool _loading = true;
  String? _error;
  bool _showUserSearch = false;
  bool _isFullScreen = false;
  String _userSearchTerm = '';
  final _userSearchCtl = TextEditingController();
  final _userSearchFocus = FocusNode();

  // new user form
  final _idCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _roleCtl = TextEditingController();
  final _reportingCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenTerritoryData();
    _listenUsers();
  }

  @override
  void dispose() {
    _userSearchCtl.dispose();
    _userSearchFocus.dispose();
    _idCtl.dispose();
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _roleCtl.dispose();
    _reportingCtl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v?.toString().trim() ?? '';

  String _joinTerritoryNames(Set<String> ids, Map<String, String> nameMap) {
    if (ids.isEmpty) return '';
    final names =
        ids
            .map((id) => nameMap[id] ?? id)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.join(', ');
  }

  void _listenTerritoryData() {
    _db.ref('Regions').onValue.listen((event) {
      final map = <String, String>{};
      final v = event.snapshot.value;
      if (v is Map) {
        v.forEach((k, raw) {
          if (raw is Map) {
            final id = _s(
              raw['regionID'] ?? raw['regionId'] ?? raw['RegionID'] ?? k,
            );
            final name = _s(
              raw['regionName'] ?? raw['RegionName'] ?? raw['name'],
            );
            if (id.isNotEmpty) map[id] = name.isNotEmpty ? name : id;
          }
        });
      } else if (v is List) {
        for (int i = 0; i < v.length; i++) {
          final raw = v[i];
          if (raw is Map) {
            final id = _s(
              raw['regionID'] ??
                  raw['regionId'] ??
                  raw['RegionID'] ??
                  i.toString(),
            );
            final name = _s(
              raw['regionName'] ?? raw['RegionName'] ?? raw['name'],
            );
            if (id.isNotEmpty) map[id] = name.isNotEmpty ? name : id;
          }
        }
      }
      if (!mounted) return;
      setState(() => _regionNameById = map);
    });

    _db.ref('Areas').onValue.listen((event) {
      final areaNames = <String, String>{};
      final areaRegions = <String, String>{};
      final v = event.snapshot.value;
      void add(dynamic raw, String fallbackKey) {
        if (raw is! Map) return;
        final id = _s(
          raw['areaID'] ?? raw['areaId'] ?? raw['AreaID'] ?? fallbackKey,
        );
        final name = _s(raw['areaName'] ?? raw['AreaName'] ?? raw['name']);
        final regionId = _s(
          raw['regionID'] ?? raw['regionId'] ?? raw['RegionID'],
        );
        if (id.isEmpty) return;
        areaNames[id] = name.isNotEmpty ? name : id;
        areaRegions[id] = regionId;
      }

      if (v is Map) {
        v.forEach((k, raw) => add(raw, k.toString()));
      } else if (v is List) {
        for (int i = 0; i < v.length; i++) {
          add(v[i], i.toString());
        }
      }

      if (!mounted) return;
      setState(() {
        _areaNameById = areaNames;
        _areaRegionByAreaId = areaRegions;
        _rebuildTerritoryAssignments();
      });
    });

    _db.ref('SubAreas').onValue.listen((event) {
      final rows = <Map<String, dynamic>>[];
      final v = event.snapshot.value;
      void add(dynamic raw, String fallbackKey) {
        if (raw is! Map) return;
        rows.add(Map<String, dynamic>.from(raw)..['_key'] = fallbackKey);
      }

      if (v is Map) {
        v.forEach((k, raw) => add(raw, k.toString()));
      } else if (v is List) {
        for (int i = 0; i < v.length; i++) {
          add(v[i], i.toString());
        }
      }

      if (!mounted) return;
      setState(() {
        _subareasRaw = rows;
        _rebuildTerritoryAssignments();
      });
    });
  }

  void _rebuildTerritoryAssignments() {
    final regionIdsByUser = <String, Set<String>>{};
    final areaIdsByUser = <String, Set<String>>{};

    for (final raw in _subareasRaw) {
      final assigned = _s(raw['assignedSE']);
      if (assigned.isEmpty) continue;
      final areaId = _s(raw['areaID'] ?? raw['AreaID']);
      final regionIdFromSub = _s(
        raw['regionID'] ?? raw['regionId'] ?? raw['RegionID'],
      );
      final regionId = regionIdFromSub.isNotEmpty
          ? regionIdFromSub
          : (_areaRegionByAreaId[areaId] ?? '');

      if (areaId.isNotEmpty) {
        (areaIdsByUser[assigned] ??= <String>{}).add(areaId);
      }
      if (regionId.isNotEmpty) {
        (regionIdsByUser[assigned] ??= <String>{}).add(regionId);
      }
    }

    _areaIdsByUser = areaIdsByUser;
    _regionIdsByUser = regionIdsByUser;
  }

  bool _matchesUserSearch(Map<String, dynamic> user) {
    final q = _userSearchTerm.trim().toLowerCase();
    if (q.isEmpty) return true;

    final candidates = <String>[
      (user['SalesPersonID'] ?? '').toString(),
      (user['SalesPersonName'] ?? '').toString(),
      (user['salesPersonRoleID'] ?? '').toString(),
      (user['ReportingPersonID'] ?? '').toString(),
      (user['phoneNumber'] ?? '').toString(),
      (user['emailAddress'] ?? '').toString(),
      (user['loginPwd'] ?? '').toString(),
      (user['regionID'] ?? user['RegionID'] ?? user['assignedRegionID'] ?? '')
          .toString(),
      (user['areaID'] ?? user['AreaID'] ?? user['assignedAreaID'] ?? '')
          .toString(),
    ];

    return candidates.any((value) => value.toLowerCase().contains(q));
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_userSearchTerm.trim().isEmpty) return _users;
    return _users.where(_matchesUserSearch).toList();
  }

  Widget _buildUserSearchControl() {
    final theme = Theme.of(context);
    final maxSearchWidth = (MediaQuery.of(context).size.width - 64)
        .clamp(220.0, 420.0)
        .toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: _showUserSearch ? maxSearchWidth : 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: _showUserSearch
              ? TextField(
                  controller: _userSearchCtl,
                  focusNode: _userSearchFocus,
                  onChanged: (value) {
                    setState(() => _userSearchTerm = value);
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Search Name, Role ID, Reporting ID, Phone, Email, Password, Region ID, Area ID',
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _userSearchCtl.clear();
                        setState(() {
                          _userSearchTerm = '';
                          _showUserSearch = false;
                        });
                        _userSearchFocus.unfocus();
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                )
              : IconButton(
                  tooltip: 'Search users',
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() => _showUserSearch = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _userSearchFocus.requestFocus();
                    });
                  },
                ),
        ),
      ],
    );
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
                return value == 'true' ||
                    value == '1' ||
                    value == 'yes' ||
                    value == 'disabled';
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
                'regionID':
                    (m['regionID'] ??
                            m['RegionID'] ??
                            m['assignedRegionID'] ??
                            '')
                        .toString(),
                'areaID':
                    (m['areaID'] ?? m['AreaID'] ?? m['assignedAreaID'] ?? '')
                        .toString(),
                'createdAt': m['createdAt'],
                'disabled': parseDisabled(m['disabled']),
                '_key': key,
              });
            }

            if (v is Map) {
              v.forEach((key, val) {
                if (val is Map)
                  addUser(Map<String, dynamic>.from(val), key.toString());
              });
            } else if (v is List) {
              for (int i = 0; i < v.length; i++) {
                final val = v[i];
                if (val is Map)
                  addUser(Map<String, dynamic>.from(val), i.toString());
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

  Future<void> _deleteUser(String key, String userId) async {
    final dbKey = key.trim().isNotEmpty ? key : '';
    if (dbKey.isEmpty) return;

    await _db.ref('Users').child(dbKey).remove();
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
      'createdAt': ServerValue.timestamp,
      'disabled': false,
    };
    await _saveUser(data);
    _idCtl.clear();
    _nameCtl.clear();
    _phoneCtl.clear();
    _emailCtl.clear();
    _roleCtl.clear();
    _reportingCtl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created with default password Welcome@123'),
        ),
      );
    }
  }

  Widget _userCard(Map<String, dynamic> u) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final id = (u['SalesPersonID'] ?? '').toString();
    final dbKey = (u['_key'] ?? id).toString();
    final nameCtl = TextEditingController(text: u['SalesPersonName'] ?? '');
    final phoneCtl = TextEditingController(text: u['phoneNumber'] ?? '');
    final emailCtl = TextEditingController(text: u['emailAddress'] ?? '');
    final roleCtl = TextEditingController(text: u['salesPersonRoleID'] ?? '');
    final reportingCtl = TextEditingController(
      text: u['ReportingPersonID'] ?? '',
    );
    final passwordCtl = TextEditingController(
      text: (u['loginPwd'] ?? '').toString(),
    );
    final disabled = u['disabled'] == true;
    final roleIsOne = roleCtl.text.trim() == '1';
    final assignedRegionNames = _joinTerritoryNames(
      _regionIdsByUser[id] ?? <String>{},
      _regionNameById,
    );
    final assignedAreaNames = _joinTerritoryNames(
      _areaIdsByUser[id] ?? <String>{},
      _areaNameById,
    );
    final cardBase = isDark ? colorScheme.surface : const Color(0xFFE0F2F1);
    final cardAccent = isDark
        ? colorScheme.outlineVariant
        : const Color(0xFF26A69A);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      elevation: 4,
      color: cardBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cardAccent, width: 1.2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest,
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
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
              _displayRow(
                'Region',
                assignedRegionNames.isEmpty ? '—' : assignedRegionNames,
              ),
              _displayRow(
                'Area',
                assignedAreaNames.isEmpty ? '—' : assignedAreaNames,
              ),
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
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext dialogContext) => AlertDialog(
                        title: const Text('Delete User'),
                        content: Text(
                          'Are you sure you want to delete user "$id" (${nameCtl.text.trim()})?\n\nThis action cannot be undone. The user will be completely removed from the database.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && mounted) {
                      await _deleteUser(dbKey, id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User deleted successfully'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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

  Widget _displayRow(String label, String value) {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
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
      bottomNavigationBar: _isFullScreen ? null : CommonFooter(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isFullScreen)
              const CommonHeader(pageTitle: 'User Management'),
            if (!_isFullScreen)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New User',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
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
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _phoneCtl,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _emailCtl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
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
                        ElevatedButton(
                          onPressed: _createNewUser,
                          child: const Text('Create (pwd: Welcome@123)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (!_isFullScreen) const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(_isFullScreen ? 10 : 16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 760;
                              if (compact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: _FullScreenToggleButton(
                                        fullScreen: _isFullScreen,
                                        onTap: () => setState(
                                          () => _isFullScreen = !_isFullScreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildUserSearchControl(),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  _FullScreenToggleButton(
                                    fullScreen: _isFullScreen,
                                    onTap: () => setState(
                                      () => _isFullScreen = !_isFullScreen,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildUserSearchControl()),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          if (_filteredUsers.isEmpty)
                            const Expanded(
                              child: Center(child: Text('No Users Found')),
                            )
                          else
                            Expanded(
                              child: ListView(
                                children: _filteredUsers
                                    .map(_userCard)
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenToggleButton extends StatelessWidget {
  final bool fullScreen;
  final VoidCallback onTap;

  const _FullScreenToggleButton({
    required this.fullScreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = fullScreen ? 'Minimize' : 'Full Screen';
    final icon = fullScreen
        ? Icons.fullscreen_exit_rounded
        : Icons.fullscreen_rounded;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
