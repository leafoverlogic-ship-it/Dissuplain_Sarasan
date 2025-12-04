import 'package:flutter/material.dart';
import '../app_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'Clients_Summary.dart';

class UserNamePwdPage extends StatefulWidget {
  const UserNamePwdPage({Key? key}) : super(key: key);

  @override
  State<UserNamePwdPage> createState() => _UserNamePwdPageState();
}

class _UserNamePwdPageState extends State<UserNamePwdPage> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _db = FirebaseDatabase.instance;
  String _s(dynamic v) => v?.toString().trim() ?? '';

  // ---- FIX: always return Map<String, dynamic> ----
  Future<Map<String, dynamic>?> _findUser(String id, String pwd) async {
    final snap = await _db.ref('Users').get();
    final v = snap.value;

    if (v is Map) {
      for (final e in v.entries) {
        if (e.value is Map) {
          final m = Map<String, dynamic>.from(e.value as Map);
          if (_s(m['SalesPersonID']) == id && _s(m['loginPwd']) == pwd) {
            return m; // typed correctly
          }
        }
      }
    } else if (v is List) {
      for (final item in v) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          if (_s(m['SalesPersonID']) == id && _s(m['loginPwd']) == pwd) {
            return m; // typed correctly
          }
        }
      }
    }
    return null;
  }

  Future<List<String>> _regionsForRM(String salesPersonId) async {
    final out = <String>[];
    final snap = await _db.ref('Regions').get();
    final v = snap.value;

    bool _matchManager(Map m) {
      for (final k in m.keys) {
        final kk = k.toString().toLowerCase();
        if (kk.contains('regionalmanager')) {
          if (_s(m[k]) == salesPersonId) return true;
        }
      }
      return false;
    }

    if (v is Map) {
      v.forEach((_, raw) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          if (_matchManager(m)) out.add(_s(m['regionID']));
        }
      });
    } else if (v is List) {
      for (final raw in v) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          if (_matchManager(m)) out.add(_s(m['regionID']));
        }
      }
    }
    return out.where((e) => e.isNotEmpty).toList();
  }

  Future<List<String>> _areasForAM(String salesPersonId) async {
    final out = <String>[];
    final snap = await _db.ref('Areas').get();
    final v = snap.value;

    bool _matchManager(Map m) {
      for (final k in m.keys) {
        final kk = k.toString().toLowerCase();
        if (kk.contains('areamanager')) {
          if (_s(m[k]) == salesPersonId) return true;
        }
      }
      return false;
    }

    if (v is Map) {
      v.forEach((_, raw) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          if (_matchManager(m)) out.add(_s(m['areaID']));
        }
      });
    } else if (v is List) {
      for (final raw in v) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          if (_matchManager(m)) out.add(_s(m['areaID']));
        }
      }
    }
    return out.where((e) => e.isNotEmpty).toList();
  }

  Future<List<String>> _subareasForSE(String salesPersonId) async {
    final out = <String>[];
    final snap = await _db.ref('SubAreas').get();
    final v = snap.value;

    if (v is Map) {
      v.forEach((k, raw) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          final sid = _s(
            m['subareaID'].toString().isNotEmpty ? m['subareaID'] : k,
          );
          if (_s(m['assignedSE']) == salesPersonId && sid.isNotEmpty) {
            out.add(sid);
          }
        }
      });
    } else if (v is List) {
      for (int i = 0; i < v.length; i++) {
        final raw = v[i];
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          final sid = _s(m['subareaID'] ?? i.toString());
          if (_s(m['assignedSE']) == salesPersonId && sid.isNotEmpty) {
            out.add(sid);
          }
        }
      }
    }
    return out;
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = _userCtrl.text.trim();
      final pwd = _pwdCtrl.text;
      if (id.isEmpty || pwd.isEmpty) {
        setState(() {
          _error = 'Enter username & password';
          _loading = false;
        });
        return;
      }

      final user = await _findUser(id, pwd);
      if (user == null) {
        setState(() {
          _error = 'Invalid username or password';
          _loading = false;
        });
        return;
      }

      final roleId = _s(user['salesPersonRoleID']);
      final name = _s(user['SalesPersonName']);
      final bool allAccess = (roleId == '4' || roleId == '5');

      List<String> regionIds = [];
      List<String> areaIds = [];
      List<String> subareaIds = [];

      if (!allAccess) {
        if (roleId == '3') {
          regionIds = await _regionsForRM(id);
        } else if (roleId == '2') {
          areaIds = await _areasForAM(id);
        } else {
          subareaIds = await _subareasForSE(id);
        }
      }

      if (!mounted) return;
      AppSession().setContext(
        roleId: roleId,
        salesPersonName: name,
        salesPersonId: id,
        allAccess: allAccess,
        allowedRegionIds: regionIds,
        allowedAreaIds: areaIds,
        allowedSubareaIds: subareaIds,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ClientsSummaryPage(
            roleId: roleId,
            salesPersonName: name,
            allAccess: allAccess,
            allowedRegionIds: regionIds,
            allowedAreaIds: areaIds,
            allowedSubareaIds: subareaIds,
            onLogout: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UserNamePwdPage()),
              );
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/Dissuplain_Image.png',
                    height: 120,
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'User Login',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pwdCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _loading ? 'Signing in…' : 'Sign in',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20), // spacing below Sign In
                  const Center(
                    child: Text(
                      'v1.1.11', // <-- your fixed version text. last pushed was v1.1.10
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
