import 'package:flutter/material.dart';
import '../app_session.dart';
import 'package:firebase_database/firebase_database.dart';
import '../dataLayer/users_repository.dart';
import 'Clients_Summary.dart';
import 'PasswordResetPage.dart';
import 'password_reset_utils.dart';

class UserNamePwdPage extends StatefulWidget {
  const UserNamePwdPage({Key? key}) : super(key: key);

  @override
  State<UserNamePwdPage> createState() => _UserNamePwdPageState();
}

class _UserNamePwdPageState extends State<UserNamePwdPage> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  bool _showCreatePasswordLink = false;
  bool _passwordVisible = false;
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

  Future<Map<String, dynamic>?> _findUserById(String id) async {
    final snap = await _db.ref('Users').get();
    final v = snap.value;

    if (v is Map) {
      for (final e in v.entries) {
        if (e.value is Map) {
          final m = Map<String, dynamic>.from(e.value as Map);
          if (_s(m['SalesPersonID']) == id) {
            return m;
          }
        }
      }
    } else if (v is List) {
      for (final item in v) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          if (_s(m['SalesPersonID']) == id) {
            return m;
          }
        }
      }
    }
    return null;
  }

  Future<Map<String, String>> _resolveRoleOneTerritory(
    String rawRegion,
    String rawArea,
  ) async {
    final regionLookup = <String, String>{};
    final areaLookup = <String, String>{};

    final regionSnap = await _db.ref('Regions').get();
    final regionValue = regionSnap.value;
    void addRegion(dynamic raw, String fallbackKey) {
      if (raw is Map) {
        final id = _s(
          raw['regionID'] ??
              raw['regionId'] ??
              raw['RegionID'] ??
              raw['RegionId'] ??
              fallbackKey,
        );
        final name = _s(
          raw['regionName'] ?? raw['RegionName'] ?? raw['name'] ?? raw['Name'],
        );
        if (id.isNotEmpty) {
          regionLookup[id.toLowerCase()] = id;
          if (name.isNotEmpty) regionLookup[name.toLowerCase()] = id;
        }
      }
    }

    if (regionValue is Map) {
      regionValue.forEach((k, raw) => addRegion(raw, k.toString()));
    } else if (regionValue is List) {
      for (var i = 0; i < regionValue.length; i++)
        addRegion(regionValue[i], i.toString());
    }

    final areaSnap = await _db.ref('Areas').get();
    final areaValue = areaSnap.value;
    void addArea(dynamic raw, String fallbackKey) {
      if (raw is Map) {
        final id = _s(
          raw['areaID'] ??
              raw['areaId'] ??
              raw['AreaID'] ??
              raw['AreaId'] ??
              fallbackKey,
        );
        final name = _s(
          raw['areaName'] ?? raw['AreaName'] ?? raw['name'] ?? raw['Name'],
        );
        if (id.isNotEmpty) {
          areaLookup[id.toLowerCase()] = id;
          if (name.isNotEmpty) areaLookup[name.toLowerCase()] = id;
        }
      }
    }

    if (areaValue is Map) {
      areaValue.forEach((k, raw) => addArea(raw, k.toString()));
    } else if (areaValue is List) {
      for (var i = 0; i < areaValue.length; i++)
        addArea(areaValue[i], i.toString());
    }

    final normalizedRegion =
        regionLookup[_s(rawRegion).toLowerCase()] ?? _s(rawRegion);
    final normalizedArea = areaLookup[_s(rawArea).toLowerCase()] ?? _s(rawArea);

    return {'region': normalizedRegion, 'area': normalizedArea};
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

  Future<void> _refreshCreatePasswordVisibility(String employeeId) async {
    final id = employeeId.trim();
    if (id.isEmpty) {
      if (mounted) {
        setState(() => _showCreatePasswordLink = false);
      }
      return;
    }

    final user = await _findUserById(id);
    if (!mounted) return;

    final storedPassword = _s(user?['loginPwd']);
    setState(() {
      _showCreatePasswordLink = shouldShowCreatePasswordOption(storedPassword);
    });
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

      final user = await _findUserById(id);
      if (user == null) {
        setState(() {
          _error = 'Invalid username or password';
          _loading = false;
        });
        return;
      }

      final storedPwd = _s(user['loginPwd']);
      if (isTemporaryDefaultPassword(pwd)) {
        setState(() {
          _error =
              'This password is temporary. Use Create new password to set your own password.';
          _loading = false;
        });
        return;
      }

      if (storedPwd != pwd) {
        setState(() {
          _error = 'Invalid username or password';
          _loading = false;
        });
        return;
      }

      if (!canAccessUser(user)) {
        setState(() {
          _error = 'This account has been disabled by an admin.';
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
        if (roleId == '1') {
          final rawRegionId = _s(
            user['regionID'] ?? user['RegionID'] ?? user['assignedRegionID'],
          );
          final rawAreaId = _s(
            user['areaID'] ?? user['AreaID'] ?? user['assignedAreaID'],
          );
          final resolved = await _resolveRoleOneTerritory(
            rawRegionId,
            rawAreaId,
          );
          if (resolved['region']!.isNotEmpty) regionIds = [resolved['region']!];
          if (resolved['area']!.isNotEmpty) areaIds = [resolved['area']!];
          subareaIds = await _subareasForSE(id);
        } else if (roleId == '3') {
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
              AppSession().clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const UserNamePwdPage()),
                (route) => false,
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

  InputDecoration _loginInputDecoration({
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final outline = isDark ? const Color(0xFF334155) : const Color(0xFFDDE4EE);

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: theme.colorScheme.primary),
      filled: true,
      fillColor: isDark ? const Color(0xFF172033) : const Color(0xFFFBFCFE),
      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.4),
      ),
    );
  }

  Widget _buildBrandPanel() {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0B1220)
            : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/Dissuplain_Image.png',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildMobileBrandImage() {
    final theme = Theme.of(context);
    return Container(
      height: 180,
      padding: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0B1220)
            : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(
        'assets/images/Dissuplain_Image.png',
        fit: BoxFit.contain,
        width: double.infinity,
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B1517) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel({required bool compact}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(compact ? 22 : 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.32 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Image.asset('assets/images/Sarasan_Logo.png'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sarasan',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dissuplain access',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 20),
            _buildMobileBrandImage(),
          ],
          SizedBox(height: compact ? 24 : 36),
          Text(
            'Welcome back',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with your employee credentials.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _userCtrl,
            onChanged: (value) => _refreshCreatePasswordVisibility(value),
            decoration: _loginInputDecoration(
              label: 'Employee ID',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pwdCtrl,
            obscureText: !_passwordVisible,
            decoration: _loginInputDecoration(
              label: 'Password',
              icon: Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _passwordVisible = !_passwordVisible);
                },
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  color: _passwordVisible ? Colors.green : Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(_error!),
          ],
          if (_showCreatePasswordLink) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PasswordResetPage(employeeId: _userCtrl.text.trim()),
                    ),
                  );
                },
                icon: const Icon(Icons.key_outlined, size: 18),
                label: const Text('Create new password'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF117A65),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                disabledBackgroundColor: theme.colorScheme.surfaceVariant,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _loading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Signing in...',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Sign in',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              'v1.5.4',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            final horizontalPadding = constraints.maxWidth < 420 ? 16.0 : 24.0;
            final verticalPadding = isWide ? 32.0 : 20.0;
            final availableHeight =
                constraints.maxHeight - (verticalPadding * 2);
            final minContentHeight = availableHeight > 0
                ? availableHeight
                : 0.0;
            final widePanelHeight = minContentHeight
                .clamp(620.0, 720.0)
                .toDouble();

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 980 : 460),
                    child: isWide
                        ? SizedBox(
                            height: widePanelHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _buildBrandPanel()),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 430,
                                  child: _buildLoginPanel(compact: false),
                                ),
                              ],
                            ),
                          )
                        : _buildLoginPanel(compact: true),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
