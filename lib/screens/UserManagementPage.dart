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
            void addUser(Map m) {
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
                'disabled': m['disabled'] == true,
                '_key': m['_key'], // optional
              });
            }

            if (v is Map) {
              v.forEach((_, val) {
                if (val is Map) addUser(val);
              });
            } else if (v is List) {
              for (final val in v) {
                if (val is Map) addUser(val);
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
    await _db.ref('Users').child(id).set(user);
  }

  Future<void> _updateUser(String id, Map<String, dynamic> delta) async {
    await _db.ref('Users').child(id).update(delta);
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
    final id = u['SalesPersonID'] ?? '';
    final nameCtl = TextEditingController(text: u['SalesPersonName'] ?? '');
    final phoneCtl = TextEditingController(text: u['phoneNumber'] ?? '');
    final emailCtl = TextEditingController(text: u['emailAddress'] ?? '');
    final roleCtl = TextEditingController(text: u['salesPersonRoleID'] ?? '');
    final reportingCtl = TextEditingController(
      text: u['ReportingPersonID'] ?? '',
    );
    final disabled = u['disabled'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
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
                        await _updateUser(id, {'disabled': v});
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
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _updateUser(id, {
                      'SalesPersonName': nameCtl.text.trim(),
                      'phoneNumber': phoneCtl.text.trim(),
                      'emailAddress': emailCtl.text.trim(),
                      'salesPersonRoleID': roleCtl.text.trim(),
                      'ReportingPersonID': reportingCtl.text.trim(),
                    });
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
                    await _updateUser(id, {'loginPwd': 'Welcome@123'});
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
    return Scaffold(
      backgroundColor: Colors.white,
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
