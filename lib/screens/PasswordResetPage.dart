import 'dart:ui';

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
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: theme.colorScheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark
          ? const Color(0xFF1A283F).withOpacity(0.76)
          : const Color(0xFFFFFFFF).withOpacity(0.75),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
      ),
    );
  }

  Widget _statusBanner({
    required String text,
    required bool success,
  }) {
    final isSuccess = success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFFECFDF3)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSuccess
                    ? const Color(0xFF166534)
                    : const Color(0xFF991B1B),
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF08111A), const Color(0xFF121E30)]
                : [const Color(0xFFE7F3EF), const Color(0xFFF9FBFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -70,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.30),
                        theme.colorScheme.primary.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -90,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.tertiary.withOpacity(0.24),
                        theme.colorScheme.tertiary.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.surface.withOpacity(
                              isDark ? 0.72 : 0.9,
                            ),
                            theme.colorScheme.surfaceContainerHighest.withOpacity(
                              isDark ? 0.56 : 0.74,
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.34 : 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant
                                          .withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Image.asset('assets/images/Sarasan_Logo.png'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Create New Password',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Update your credentials securely.',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  Chip(
                                    avatar: Icon(Icons.lock_reset, size: 16),
                                    label: Text('Password Safety'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    avatar: Icon(Icons.verified_user_outlined, size: 16),
                                    label: Text('Account Protection'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _employeeIdCtrl,
                                decoration: _inputDecoration(
                                  label: 'Employee ID',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newPasswordCtrl,
                                obscureText: !_showNewPassword,
                                decoration: _inputDecoration(
                                  label: 'New Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _showNewPassword = !_showNewPassword,
                                    ),
                                    icon: Icon(
                                      _showNewPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirmPasswordCtrl,
                                obscureText: !_showConfirmPassword,
                                decoration: _inputDecoration(
                                  label: 'Confirm New Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _showConfirmPassword =
                                          !_showConfirmPassword,
                                    ),
                                    icon: Icon(
                                      _showConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_error != null) ...[
                                _statusBanner(text: _error!, success: false),
                                const SizedBox(height: 12),
                              ],
                              if (_message != null) ...[
                                _statusBanner(text: _message!, success: true),
                                const SizedBox(height: 12),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _loading ? null : _resetPassword,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle_outline),
                                  label: Text(
                                    _loading
                                        ? 'Updating password...'
                                        : 'Save new password',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to login'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
