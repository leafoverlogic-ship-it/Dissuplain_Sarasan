import 'package:flutter/material.dart';
import '../CommonHeader.dart';
import '../CommonFooter.dart';
import 'dart:ui';

import 'TerritoryManagerPage.dart';
import 'UserManagementPage.dart';
import 'ProductManagementPage.dart';
import 'AttendanceLogPage.dart';

class Admin extends StatelessWidget {
  const Admin({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cards = [
      _AdminActionCard(
        title: 'Territory Management',
        subtitle: 'Organize regions, areas, and subareas with a clear hierarchy.',
        icon: Icons.map_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TerritoryManagerPage()),
        ),
      ),
      _AdminActionCard(
        title: 'User Management',
        subtitle: 'Create and manage admins, users, and access roles.',
        icon: Icons.people_alt_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserManagementPage()),
        ),
      ),
      _AdminActionCard(
        title: 'Product Management',
        subtitle: 'Add or edit products that will appear in client order forms.',
        icon: Icons.inventory_2_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductManagementPage()),
        ),
      ),
      _AdminActionCard(
        title: 'Attendance Log',
        subtitle: 'Track present/absent by call activity with monthly calendars for each user.',
        icon: Icons.event_note_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AttendanceLogPage()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07111F) : const Color(0xFFF4F7FF),
      body: SafeArea(
        child: Column(
          children: [
            const CommonHeader(pageTitle: 'Admin'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF18253A), const Color(0xFF0F172A)]
                                  : [const Color(0xFFFFFFFF), const Color(0xFFEEF4FF)],
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose an admin task',
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Use the tiles below to manage territories, users, and products with a polished, glassy interface.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...cards.map((card) => Padding(padding: const EdgeInsets.only(bottom: 14), child: card)).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CommonFooter(),
    );
  }
}

class _AdminActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AdminActionCard> createState() => _AdminActionCardState();
}

class _AdminActionCardState extends State<_AdminActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()..scale(_hovered ? 1.01 : 1.0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF142235), const Color(0xFF101C2F)]
                  : [const Color(0xFFFFFFFF), const Color(0xFFF3F7FF)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hovered ? 0.12 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
