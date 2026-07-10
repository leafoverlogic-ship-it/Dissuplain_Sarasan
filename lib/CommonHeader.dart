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
    return (sess.roleId ?? '').trim().isNotEmpty;
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
    final normalizedTitle = pageTitle.toLowerCase();
    final isClientsActive = normalizedTitle.contains('client');
    final isSalesRegisterActive =
        normalizedTitle.contains('sales register') ||
        normalizedTitle.contains('sales');
    final isAdminActive = normalizedTitle.contains('admin');

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
                crossAxisAlignment: CrossAxisAlignment.center,
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
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surface.withOpacity(
                      theme.brightness == Brightness.dark ? 0.82 : 0.92,
                    ),
                    colorScheme.surfaceContainerHighest.withOpacity(
                      theme.brightness == Brightness.dark ? 0.68 : 0.76,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withOpacity(
                      theme.brightness == Brightness.dark ? 0.18 : 0.10,
                    ),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF14B8A6).withOpacity(0),
                          const Color(0xFF14B8A6).withOpacity(0.95),
                          const Color(0xFF14B8A6).withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _NavGlowButton(
                        label: 'Clients',
                        icon: Icons.groups_2_outlined,
                        active: isClientsActive,
                        onTap: () {
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
                              builder: (context) => ClientsSummaryPage(
                                roleId: rId ?? '5',
                                salesPersonName: sName,
                                allAccess: aAcc,
                                allowedRegionIds: rIds,
                                allowedAreaIds: aIds,
                                allowedSubareaIds: sIds,
                              ),
                            ),
                          );
                        },
                      ),
                      if (_canViewSalesRegister) ...[
                        const SizedBox(width: 8),
                        _NavGlowButton(
                          label: 'Sales Register',
                          icon: Icons.assessment_outlined,
                          active: isSalesRegisterActive,
                          onTap: () {
                            final sess = AppSession();
                            final rId = roleId ?? sess.roleId;
                            final sName =
                                salesPersonName ?? (sess.salesPersonName ?? '');
                            final aAcc = allAccess ?? (sess.allAccess ?? false);
                            final rIds =
                                allowedRegionIds ??
                                (sess.allowedRegionIds ?? const []);
                            final aIds =
                                allowedAreaIds ??
                                (sess.allowedAreaIds ?? const []);
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
                        ),
                      ],
                      if ((roleId is int ? roleId : int.tryParse('$roleId')) == 4) ...[
                        const SizedBox(width: 8),
                        _NavGlowButton(
                          label: 'Admin',
                          icon: Icons.admin_panel_settings_outlined,
                          active: isAdminActive,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => Admin()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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

class _NavGlowButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavGlowButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavGlowButton> createState() => _NavGlowButtonState();
}

class _NavGlowButtonState extends State<_NavGlowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teal = const Color(0xFF14B8A6);
    final activeOrHover = widget.active || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: activeOrHover
              ? teal.withOpacity(isDark ? 0.22 : 0.13)
              : theme.colorScheme.surface.withOpacity(isDark ? 0.84 : 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activeOrHover
                ? teal.withOpacity(isDark ? 0.9 : 0.7)
                : theme.colorScheme.outlineVariant,
          ),
          boxShadow: activeOrHover
              ? [
                  BoxShadow(
                    color: teal.withOpacity(isDark ? 0.34 : 0.20),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: activeOrHover ? teal : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: activeOrHover ? teal : theme.colorScheme.onSurface,
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
