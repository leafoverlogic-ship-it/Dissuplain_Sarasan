import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'UserNamePwd.dart';
import 'password_reset_utils.dart';

class PasswordResetPage extends StatefulWidget {
  final String employeeId;

  const PasswordResetPage({Key? key, this.employeeId = ''}) : super(key: key);

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _db = FirebaseDatabase.instance;
  final _employeeIdCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _employeeIdCtrl.text = widget.employeeId;
  }

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final employeeId = _employeeIdCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    setState(() {
      _error = null;
      _message = null;
      _loading = true;
    });

    if (employeeId.isEmpty) {
      setState(() {
        _error = 'Enter the employee ID first.';
        _loading = false;
      });
      return;
    }

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _error = 'Enter both new password fields.';
        _loading = false;
      });
      return;
    }

    final validationError = validateNewPassword(newPassword);
    if (validationError != null) {
      setState(() {
        _error = validationError;
        _loading = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _error = 'Passwords do not match.';
        _loading = false;
      });
      return;
    }

    try {
      final snapshot = await _db.ref('Users').orderByChild('SalesPersonID').equalTo(employeeId).once();
      final value = snapshot.snapshot.value;
      final users = value is Map ? Map<String, dynamic>.from(value as Map) : <String, dynamic>{};

      String? keyToUpdate;
      for (final entry in users.entries) {
        final raw = entry.value;
        if (raw is Map) {
          final user = Map<String, dynamic>.from(raw as Map);
          if (user['SalesPersonID']?.toString().trim() == employeeId) {
            keyToUpdate = entry.key;
            break;
          }
        }
      }

      if (keyToUpdate == null) {
        setState(() {
          _error = 'Employee ID not found.';
          _loading = false;
        });
        return;
      }

      await _db.ref('Users').child(keyToUpdate).update({'loginPwd': newPassword});

      if (!mounted) return;
      setState(() {
        _message = 'Password updated successfully. Please sign in with your new password.';
        _loading = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserNamePwdPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to update password: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create new password'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _employeeIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_message != null)
                    Text(_message!, style: const TextStyle(color: Colors.green)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _loading ? 'Updating password…' : 'Save new password',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to login'),
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
