// lib/CommonHeader.dart
import 'package:flutter/material.dart';
import 'screens/Clients_Summary.dart';
import './screens/Admin.dart';
import 'screens/UserNamePwd.dart'; // <-- added fallback login
import 'screens/SalesRegisterPage.dart';
import 'app_session.dart';
import 'app_theme.dart';

class CommonHeader extends StatelessWidget implements PreferredSizeWidget {
  final String pageTitle;

  /// New: shows "Welcome <name>" if provided
  final String? userName;

  /// Logout callback (optional). If null, we fallback to UserNamePwdPage.
  final VoidCallback? onLogout;

  /// Context needed to keep access restrictions when navigating via header
  final String? roleId;
  final String? salesPersonName;
  final bool? allAccess;
  final List<String>? allowedRegionIds;
  final List<String>? allowedAreaIds;
  final List<String>? allowedSubareaIds;

  const CommonHeader({
    super.key,
    required this.pageTitle,
    this.userName,
    this.onLogout,
    this.roleId,
    this.salesPersonName,
    this.allAccess,
    this.allowedRegionIds,
    this.allowedAreaIds,
    this.allowedSubareaIds,
  });

  bool get _canViewSalesRegister {
    final sess = AppSession();
    final currentRoleId = (sess.roleId ?? '').trim();
    final currentSalesPersonId = (sess.salesPersonId ?? '').trim();
    return currentRoleId == '4' || currentSalesPersonId == 'SS-1132';
  }

  void _logout(BuildContext context) {
    if (onLogout != null) {
      onLogout!();
      return;
    }
    AppSession().clear();
    // Fallback: go to username/password login and clear stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UserNamePwdPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surface.withOpacity(
              theme.brightness == Brightness.dark ? 0.74 : 0.94,
            ),
            colorScheme.surfaceContainerHighest.withOpacity(
              theme.brightness == Brightness.dark ? 0.62 : 0.78,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.26 : 0.09,
            ),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.9)),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 720;
              final title = Column(
                crossAxisAlignment:
                    isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Text(
                    pageTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (userName != null && userName!.isNotEmpty)
                    Text(
                      'Welcome $userName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              );

              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: isCompact ? WrapAlignment.end : WrapAlignment.center,
                children: [
                  AppThemeToggleButton(compact: isCompact),
                  TextButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/Dissuplain_Image.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              );

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 18,
                  vertical: 10,
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/Sarasan_Logo.png',
                                width: 48,
                                height: 48,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: title),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actions,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Image.asset(
                            'assets/images/Sarasan_Logo.png',
                            width: 57,
                            height: 57,
                          ),
                          Expanded(child: Center(child: title)),
                          actions,
                        ],
                      ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Prefer props if provided, else fallback to AppSession
                    final sess = AppSession();

                    final rId = roleId ?? sess.roleId;
                    final sName =
                        salesPersonName ?? (sess.salesPersonName ?? '');
                    final aAcc = allAccess ?? (sess.allAccess ?? false);
                    final rIds =
                        allowedRegionIds ?? (sess.allowedRegionIds ?? const []);
                    final aIds =
                        allowedAreaIds ?? (sess.allowedAreaIds ?? const []);
                    final sIds =
                        allowedSubareaIds ??
                        (sess.allowedSubareaIds ?? const []);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClientsSummaryPage(
                          roleId:
                              rId ??
                              '5', // fallback safest role if truly missing
                          salesPersonName: sName,
                          allAccess: aAcc,
                          allowedRegionIds: rIds,
                          allowedAreaIds: aIds,
                          allowedSubareaIds: sIds,
                        ),
                      ),
                    );
                  },
                  style: menuButtonStyle(context),
                  child: const Text("Clients"),
                ),
                /*ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => Dashboard()));
                  },
                  style: menuButtonStyle,
                  child: const Text("Dashboard"),
                ),
                const SizedBox(width: 8),
                
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => Phone_Entry()));
                  },
                  style: menuButtonStyle,
                  child: const Text("Orders"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                  },
                  style: menuButtonStyle,
                  child: const Text("Attendance"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InsertData()));
                  },
                  style: menuButtonStyle,
                  child: const Text("Admin"),
                ),*/
                if (_canViewSalesRegister) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final sess = AppSession();
                      final rId = roleId ?? sess.roleId;
                      final sName =
                          salesPersonName ?? (sess.salesPersonName ?? '');
                      final aAcc = allAccess ?? (sess.allAccess ?? false);
                      final rIds =
                          allowedRegionIds ??
                          (sess.allowedRegionIds ?? const []);
                      final aIds =
                          allowedAreaIds ?? (sess.allowedAreaIds ?? const []);
                      final sIds =
                          allowedSubareaIds ??
                          (sess.allowedSubareaIds ?? const []);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SalesRegisterPage(
                            roleId: rId,
                            salesPersonName: sName,
                            allAccess: aAcc,
                            allowedRegionIds: rIds,
                            allowedAreaIds: aIds,
                            allowedSubareaIds: sIds,
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    style: menuButtonStyle(context),
                    child: const Text("Sales Register"),
                  ),
                  const SizedBox(width: 8),
                ],
                if ((roleId is int ? roleId : int.tryParse('$roleId')) == 4)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Admin()),
                      );
                    },
                    style: menuButtonStyle(context),
                    child: const Text("Admin"),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(132);
}

ButtonStyle menuButtonStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return ElevatedButton.styleFrom(
    backgroundColor: colorScheme.surface,
    foregroundColor: colorScheme.onSurface,
    elevation: 0,
    side: BorderSide(color: colorScheme.outlineVariant),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
